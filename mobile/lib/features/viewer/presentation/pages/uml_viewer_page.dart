import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../ai/data/mobile_ai_session_factory.dart';
import '../../../ai/data/mobile_voice_transcriber.dart';
import '../../../ai/domain/ai_context_builder.dart';
import '../../../ai/domain/expert_evaluator.dart';
import '../../../ai/domain/mobile_ai.dart';
import '../../../ai/presentation/ai_assistant_sheet.dart';
import '../../data/viewer_repository.dart';
import '../../domain/viewer_models.dart';
import '../widgets/uml_notation.dart';

class UmlViewerPage extends StatefulWidget {
  const UmlViewerPage({
    super.key,
    required this.project,
    required this.repository,
    this.initialSnapshot,
    this.remoteRevisions,
    this.aiEngine,
    this.applyAiProposal,
    this.supportsLocalAi,
    this.voiceTranscriber,
  });

  final UmlProjectSummary project;
  final ViewerRepository repository;
  final UmlSnapshot? initialSnapshot;
  final Stream<int>? remoteRevisions;
  final MobileAiEngine? aiEngine;
  final ApplyAiProposal? applyAiProposal;
  final bool? supportsLocalAi;
  final MobileVoiceTranscriber? voiceTranscriber;

  @override
  State<UmlViewerPage> createState() => _UmlViewerPageState();
}

class _UmlViewerPageState extends State<UmlViewerPage> {
  final TransformationController _transformation = TransformationController();
  UmlSnapshot? _snapshot;
  String? _diagramId;
  String? _selectedNodeId;
  String? _error;
  bool _loading = true;
  bool _showMiniMap = true;
  Size _viewport = Size.zero;
  int? _remoteRevision;
  StreamSubscription<int>? _revisionSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.initialSnapshot != null) {
      _acceptSnapshot(widget.initialSnapshot!);
    } else {
      _load();
    }
    _revisionSubscription = widget.remoteRevisions?.listen(
      (revision) {
        if (!mounted ||
            revision <=
                (_snapshot?.project.revision ?? widget.project.revision)) {
          return;
        }
        setState(() => _remoteRevision = revision);
      },
      onError: (_) {
        // El visor continúa operativo aunque el canal en tiempo real no esté.
      },
    );
  }

  @override
  void dispose() {
    _revisionSubscription?.cancel();
    _transformation.dispose();
    super.dispose();
  }

  Future<void> _load({bool preferRemote = true}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await widget.repository.loadSnapshot(
        widget.project,
        preferRemote: preferRemote,
      );
      if (mounted) _acceptSnapshot(snapshot);
    } on ViewerRepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No se pudo abrir el proyecto.';
        });
      }
    }
  }

  void _acceptSnapshot(UmlSnapshot snapshot) {
    setState(() {
      _snapshot = snapshot;
      _diagramId = snapshot.diagrams.any((item) => item.id == _diagramId)
          ? _diagramId
          : snapshot.diagrams.firstOrNull?.id;
      _selectedNodeId = null;
      _loading = false;
      _error = null;
      _remoteRevision = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitToScreen());
  }

  UmlDiagram? get _diagram => _snapshot?.diagramById(_diagramId);

  List<UmlDiagramNode> get _nodes =>
      _diagramId == null ? const [] : _snapshot!.nodesFor(_diagramId!);

  List<UmlDiagramEdge> get _edges =>
      _diagramId == null ? const [] : _snapshot!.edgesFor(_diagramId!);

  Rect get _bounds => _diagramId == null
      ? const Rect.fromLTWH(0, 0, 800, 600)
      : _snapshot!.boundsFor(_diagramId!);

  void _fitToScreen() {
    if (_viewport.isEmpty || _diagramId == null) return;
    final bounds = _bounds;
    final scale = math
        .min(_viewport.width / bounds.width, _viewport.height / bounds.height)
        .clamp(.1, 1.6)
        .toDouble();
    final dx = (_viewport.width - bounds.width * scale) / 2;
    final dy = (_viewport.height - bounds.height * scale) / 2;
    _transformation.value = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setTranslationRaw(dx, dy, 0);
  }

  void _centerNode(UmlDiagramNode node) {
    final bounds = _bounds;
    const scale = 1.15;
    final localCenter = node.bounds.center - bounds.topLeft;
    _transformation.value = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setTranslationRaw(
        _viewport.width / 2 - localCenter.dx * scale,
        _viewport.height / 2 - localCenter.dy * scale,
        0,
      );
    setState(() => _selectedNodeId = node.id);
  }

  Future<void> _search() async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    final result = await showSearch<ViewerSearchResult?>(
      context: context,
      delegate: _ViewerSearchDelegate(snapshot),
    );
    if (!mounted || result == null) return;
    setState(() {
      _diagramId = result.diagram.id;
      _selectedNodeId = result.node.id;
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _centerNode(result.node),
    );
  }

  void _inspect(UmlDiagramNode node) {
    setState(() => _selectedNodeId = node.id);
    final element = _snapshot!.elementById(node.elementId);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _InspectorSheet(
        snapshot: _snapshot!,
        node: node,
        element: element,
        onNavigate: (targetNode, diagram) {
          Navigator.pop(context);
          setState(() {
            _diagramId = diagram.id;
            _selectedNodeId = targetNode.id;
          });
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _centerNode(targetNode),
          );
        },
      ),
    );
  }

  Future<void> _openAiAssistant() async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    MobileAiSession? session;
    MobileVoiceTranscriber? voiceTranscriber;
    var ownsVoiceTranscriber = false;
    try {
      if (widget.aiEngine != null) {
        session = MobileAiSession(engine: widget.aiEngine!);
      } else if (widget.repository is MobileViewerRepository) {
        session = await MobileAiSessionFactory.createForProject(
          widget.repository as MobileViewerRepository,
          widget.project.id,
        );
      } else {
        throw const ViewerRepositoryException(
          'El asistente de IA no está disponible en este origen de datos.',
        );
      }
      if (!mounted) return;
      voiceTranscriber = widget.voiceTranscriber;
      if (voiceTranscriber == null && widget.repository is MobileViewerRepository) {
        final repository = widget.repository as MobileViewerRepository;
        voiceTranscriber = WhisperVoiceTranscriber(
          accessTokenProvider: AuthSessionManager.getAccessToken,
          accessTokenRefresher: AuthSessionManager.refreshAccessToken,
          online: repository.isOnline,
        );
        ownsVoiceTranscriber = true;
      }
      final selectedElementIds = [
        if (_selectedNodeId != null)
          ..._nodes
              .where((node) => node.id == _selectedNodeId)
              .map((node) => node.elementId)
              .whereType<String>(),
      ];
      final result = await showModalBottomSheet<UmlSnapshot>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => AiAssistantSheet(
          engine: session!.engine,
          snapshot: snapshot,
          diagramId: _diagramId,
          selectedElementIds: selectedElementIds,
          access: widget.project.access,
          supportsLocal:
              widget.supportsLocalAi ?? session.engine.id == 'hybrid',
          applyProposal:
              widget.applyAiProposal ??
              (proposal, selected) => _applyAiProposal(proposal, selected),
          voiceTranscriber: voiceTranscriber,
        ),
      );
      if (mounted && result != null) _acceptSnapshot(result);
    } on ViewerRepositoryException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (ownsVoiceTranscriber) await voiceTranscriber?.dispose();
      await session?.dispose();
    }
  }

  Future<UmlSnapshot> _applyAiProposal(
    MobileAiResponse proposal,
    Set<String> selected,
  ) async {
    final repository = widget.repository;
    if (repository is! MobileViewerRepository) {
      throw const ViewerRepositoryException(
        'Este origen de datos no admite cambios de IA.',
      );
    }
    if (widget.project.access == ProjectAccess.viewer) {
      throw const ViewerRepositoryException(
        'Tu rol de lector no permite confirmar cambios.',
      );
    }
    if (proposal.origin == MobileAiOrigin.remote) {
      return repository.applyRemoteAiProposal(
        widget.project,
        proposal,
        selected,
      );
    }
    await repository.saveLocalProposal(widget.project.id, proposal);
    return repository.confirmLocalProposal(
      widget.project.id,
      proposal,
      selected,
    );
  }

  Future<void> _openOfflineDiagnostics() async {
    final snapshot = _snapshot;
    final repository = widget.repository;
    if (snapshot == null || repository is! MobileViewerRepository) return;
    try {
      final rulesPayload = await repository.loadOfflineRules(widget.project.id);
      final registry = await repository.loadOfflineRegistry(widget.project.id);
      if (rulesPayload == null) {
        throw const FormatException(
          'Prepara este proyecto para uso offline antes de ejecutar el diagnóstico.',
        );
      }
      final aiContext = AiContextBuilder().build(
        snapshot: snapshot,
        diagramId: _diagramId,
        selectedElementIds: [
          if (_selectedNodeId != null)
            ..._nodes
                .where((node) => node.id == _selectedNodeId)
                .map((node) => node.elementId)
                .whereType<String>(),
        ],
      );
      final diagnostics = ExpertEvaluator(ExpertRuleSet.verified(rulesPayload))
          .evaluate({
            ...aiContext,
            'registry': registry ?? const <String, dynamic>{},
            'permission': widget.project.access.name,
          });
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => _OfflineDiagnosticsSheet(diagnostics: diagnostics),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('uml-viewer-page'),
      appBar: AppBar(
        title: Text(widget.project.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            key: const ValueKey('viewer-ai-assistant'),
            tooltip: 'Pedir cambios a la IA',
            onPressed: _snapshot == null ? null : _openAiAssistant,
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          IconButton(
            key: const ValueKey('viewer-offline-diagnostics'),
            tooltip: 'Diagnóstico UML offline',
            onPressed: _snapshot == null ? null : _openOfflineDiagnostics,
            icon: const Icon(Icons.auto_awesome_outlined),
          ),
          IconButton(
            key: const ValueKey('viewer-search'),
            tooltip: 'Buscar elemento',
            onPressed: _snapshot == null ? null : _search,
            icon: const Icon(Icons.search),
          ),
          IconButton(
            key: const ValueKey('viewer-fit'),
            tooltip: 'Ajustar a pantalla',
            onPressed: _fitToScreen,
            icon: const Icon(Icons.fit_screen),
          ),
          IconButton(
            key: const ValueKey('viewer-minimap'),
            tooltip: _showMiniMap ? 'Ocultar navegación' : 'Mostrar navegación',
            onPressed: () => setState(() => _showMiniMap = !_showMiniMap),
            icon: Icon(_showMiniMap ? Icons.map : Icons.map_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_snapshot != null) _ViewerStatusBar(snapshot: _snapshot!),
          if (_remoteRevision != null)
            MaterialBanner(
              key: const ValueKey('remote-revision-notice'),
              content: Text(
                'Hay una nueva revisión remota: $_remoteRevision. No es una edición local.',
              ),
              leading: const Icon(Icons.sync),
              actions: [
                TextButton(
                  onPressed: _load,
                  child: const Text('Actualizar visor'),
                ),
              ],
            ),
          if (_snapshot != null && _snapshot!.diagrams.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: DropdownButtonFormField<String>(
                key: const ValueKey('diagram-selector'),
                initialValue: _diagramId,
                decoration: const InputDecoration(
                  labelText: 'Diagrama',
                  prefixIcon: Icon(Icons.account_tree_outlined),
                  isDense: true,
                ),
                items: _snapshot!.diagrams.map((diagram) {
                  return DropdownMenuItem(
                    value: diagram.id,
                    child: Text(
                      '${diagram.name} · ${_diagramLabel(diagram.type)}',
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _diagramId = value;
                    _selectedNodeId = null;
                  });
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _fitToScreen(),
                  );
                },
              ),
            ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const ValueKey('viewer-error'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _load,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (_snapshot!.diagrams.isEmpty) {
      return const Center(
        child: Text('Este proyecto todavía no contiene diagramas.'),
      );
    }
    if (_diagram == null) return const SizedBox.shrink();
    if (_nodes.isEmpty) {
      return const Center(
        child: Text('El diagrama no contiene representaciones visibles.'),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        final bounds = _bounds;
        return Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0xFFF1F5F9),
                child: InteractiveViewer(
                  key: const ValueKey('read-only-interactive-viewer'),
                  transformationController: _transformation,
                  constrained: false,
                  minScale: .1,
                  maxScale: 4,
                  boundaryMargin: const EdgeInsets.all(600),
                  panEnabled: true,
                  scaleEnabled: true,
                  child: SizedBox(
                    width: bounds.width,
                    height: bounds.height,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: UmlEdgesPainter(
                              nodes: _nodes,
                              edges: _edges,
                              relationships: _snapshot!.relationships,
                              origin: bounds.topLeft,
                            ),
                          ),
                        ),
                        for (final node in _nodes)
                          Positioned(
                            key: ValueKey('uml-node-${node.id}'),
                            left: node.bounds.left - bounds.left,
                            top: node.bounds.top - bounds.top,
                            width: node.bounds.width,
                            height: node.bounds.height,
                            child: UmlNodeView(
                              node: node,
                              element: _snapshot!.elementById(node.elementId),
                              diagramType: _diagram!.type,
                              selected: node.id == _selectedNodeId,
                              onTap: () => _inspect(node),
                              onLongPress: _openAiAssistant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_showMiniMap)
              Positioned(
                right: 12,
                bottom: 12,
                child: Semantics(
                  label: 'Vista general del diagrama',
                  child: GestureDetector(
                    onTap: _fitToScreen,
                    child: SizedBox(
                      key: const ValueKey('viewer-minimap-panel'),
                      width: 132,
                      height: 86,
                      child: CustomPaint(
                        painter: UmlMiniMapPainter(
                          bounds: bounds,
                          nodes: _nodes,
                          selectedNodeId: _selectedNodeId,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OfflineDiagnosticsSheet extends StatelessWidget {
  const _OfflineDiagnosticsSheet({required this.diagnostics});

  final List<MobileAiDiagnostic> diagnostics;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 620),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                'Diagnóstico UML offline',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'Funciona con reglas locales; no necesita descargar ni ejecutar el modelo Qwen.',
              ),
              const Divider(height: 28),
              if (diagnostics.isEmpty)
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                  title: Text(
                    'No se encontraron problemas en el alcance revisado.',
                  ),
                ),
              for (final diagnostic in diagnostics)
                Card(
                  child: ListTile(
                    leading: Icon(
                      diagnostic.severity == 'error'
                          ? Icons.error_outline
                          : Icons.warning_amber_outlined,
                      color: diagnostic.severity == 'error'
                          ? Colors.red
                          : Colors.orange,
                    ),
                    title: Text(diagnostic.message),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${diagnostic.severity.toUpperCase()} · ${diagnostic.ruleId}',
                        ),
                        if (diagnostic.evidence.isNotEmpty)
                          Text('Evidencia: ${diagnostic.evidence}'),
                        if (diagnostic.question != null)
                          Text('Pregunta: ${diagnostic.question}'),
                        if (diagnostic.repair != null)
                          Text('Corrección segura: ${diagnostic.repair}'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewerStatusBar extends StatelessWidget {
  const _ViewerStatusBar({required this.snapshot});
  final UmlSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final state = snapshot.loadedFromOffline
        ? switch (snapshot.project.syncState) {
            ViewerSyncState.pending ||
            ViewerSyncState.conflict => snapshot.project.syncState,
            _ => ViewerSyncState.offline,
          }
        : snapshot.project.syncState;
    final (label, icon, color) = switch (state) {
      ViewerSyncState.updated => (
        'Actualizado',
        Icons.cloud_done_outlined,
        Colors.green,
      ),
      ViewerSyncState.offline => (
        'Offline',
        Icons.cloud_off_outlined,
        Colors.blueGrey,
      ),
      ViewerSyncState.syncing => ('Sincronizando', Icons.sync, Colors.blue),
      ViewerSyncState.pending => (
        'Pendiente',
        Icons.cloud_upload_outlined,
        Colors.orange,
      ),
      ViewerSyncState.conflict => (
        'Conflicto',
        Icons.warning_amber_rounded,
        Colors.red,
      ),
    };
    return Material(
      color: color.withValues(alpha: .1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              key: const ValueKey('viewer-sync-state'),
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
            if (snapshot.loadedFromOffline && snapshot.syncedAt != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Copia del ${_shortDateTime(snapshot.syncedAt!)}',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ] else
              const Spacer(),
            Text(
              'Revisión ${snapshot.project.revision}',
              key: const ValueKey('viewer-revision'),
            ),
          ],
        ),
      ),
    );
  }
}

String _shortDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

class _InspectorSheet extends StatelessWidget {
  const _InspectorSheet({
    required this.snapshot,
    required this.node,
    required this.element,
    required this.onNavigate,
  });

  final UmlSnapshot snapshot;
  final UmlDiagramNode node;
  final UmlElement? element;
  final void Function(UmlDiagramNode node, UmlDiagram diagram) onNavigate;

  @override
  Widget build(BuildContext context) {
    final related = _relatedRepresentations();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 520),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                element?.name ??
                    '${node.properties['label'] ?? 'Elemento visual'}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(element?.metaclass ?? 'Notación visual no compatible'),
              if (element?.mdaLevel != null)
                Text('Nivel MDA: ${element!.mdaLevel}'),
              const Divider(height: 28),
              if ((element?.properties ?? node.properties).isEmpty)
                const Text('Sin propiedades adicionales.'),
              for (final entry
                  in (element?.properties ?? node.properties).entries)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.key),
                  subtitle: Text(_displayValue(entry.value)),
                ),
              if (related.isNotEmpty) ...[
                const Divider(height: 28),
                const Text(
                  'Referencias y otras representaciones',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                for (final item in related)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.open_in_new),
                    title: Text(item.$2.name),
                    subtitle: Text(_diagramLabel(item.$3.type)),
                    onTap: () => onNavigate(item.$1, item.$3),
                  ),
              ],
              const SizedBox(height: 8),
              const Text(
                'Solo lectura · los cambios requieren una propuesta de IA confirmada.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<(UmlDiagramNode, UmlElement, UmlDiagram)> _relatedRepresentations() {
    if (element == null) return const [];
    final result = <(UmlDiagramNode, UmlElement, UmlDiagram)>[];
    final relatedIds = <String>{element!.id};
    for (final relation in snapshot.relationships) {
      if (relation.sourceId == element!.id) relatedIds.add(relation.targetId);
      if (relation.targetId == element!.id) relatedIds.add(relation.sourceId);
    }
    for (final candidate in snapshot.nodes) {
      if (candidate.id == node.id ||
          candidate.elementId == null ||
          !relatedIds.contains(candidate.elementId)) {
        continue;
      }
      final targetElement = snapshot.elementById(candidate.elementId);
      final diagram = snapshot.diagramById(candidate.diagramId);
      if (targetElement != null && diagram != null) {
        result.add((candidate, targetElement, diagram));
      }
    }
    return result;
  }
}

class _ViewerSearchDelegate extends SearchDelegate<ViewerSearchResult?> {
  _ViewerSearchDelegate(this.snapshot);
  final UmlSnapshot snapshot;

  List<ViewerSearchResult> get _results {
    final normalized = query.trim().toLowerCase();
    final results = <ViewerSearchResult>[];
    for (final node in snapshot.nodes) {
      final element = snapshot.elementById(node.elementId);
      final diagram = snapshot.diagramById(node.diagramId);
      if (element == null || diagram == null) continue;
      if (normalized.isEmpty ||
          element.name.toLowerCase().contains(normalized) ||
          element.metaclass.toLowerCase().contains(normalized)) {
        results.add(
          ViewerSearchResult(element: element, diagram: diagram, node: node),
        );
      }
    }
    return results;
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        onPressed: () => query = '',
        icon: const Icon(Icons.clear),
        tooltip: 'Limpiar',
      ),
  ];

  @override
  Widget? buildLeading(BuildContext context) =>
      BackButton(onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _resultList();

  @override
  Widget buildSuggestions(BuildContext context) => _resultList();

  Widget _resultList() {
    final results = _results;
    if (results.isEmpty) {
      return const Center(child: Text('No se encontraron elementos.'));
    }
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        return ListTile(
          leading: const Icon(Icons.account_tree_outlined),
          title: Text(result.element.name),
          subtitle: Text(
            '${result.element.metaclass} · ${result.diagram.name}',
          ),
          onTap: () => close(context, result),
        );
      },
    );
  }
}

String _displayValue(Object? value) {
  if (value is List) return value.join(', ');
  if (value is Map) {
    return value.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(', ');
  }
  return '$value';
}

String _diagramLabel(String value) =>
    const {
      'class': 'Clases',
      'object': 'Objetos',
      'component': 'Componentes',
      'composite_structure': 'Estructura compuesta',
      'package': 'Paquetes',
      'deployment': 'Despliegue',
      'profile': 'Perfiles',
      'use_case': 'Casos de uso',
      'activity': 'Actividades',
      'state_machine': 'Máquina de estados',
      'sequence': 'Secuencia',
      'communication': 'Comunicación',
      'interaction_overview': 'Visión general de interacción',
      'timing': 'Temporización',
    }[value] ??
    'Tipo no compatible';
