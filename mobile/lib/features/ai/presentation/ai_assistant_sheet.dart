import 'dart:async';

import 'package:flutter/material.dart';

import '../../viewer/domain/viewer_models.dart';
import '../data/mobile_voice_transcriber.dart';
import '../domain/ai_context_builder.dart';
import '../domain/mobile_ai.dart';

typedef ApplyAiProposal =
    Future<UmlSnapshot> Function(
      MobileAiResponse proposal,
      Set<String> selectedOperationIds,
    );

class AiAssistantSheet extends StatefulWidget {
  const AiAssistantSheet({
    super.key,
    required this.engine,
    required this.snapshot,
    required this.diagramId,
    required this.selectedElementIds,
    required this.access,
    required this.applyProposal,
    this.supportsLocal = false,
    this.voiceTranscriber,
  });

  final MobileAiEngine engine;
  final UmlSnapshot snapshot;
  final String? diagramId;
  final List<String> selectedElementIds;
  final ProjectAccess access;
  final ApplyAiProposal applyProposal;
  final bool supportsLocal;
  final MobileVoiceTranscriber? voiceTranscriber;

  @override
  State<AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends State<AiAssistantSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_AiChatMessage>[
    const _AiChatMessage(
      fromUser: false,
      text:
          'Describe el cambio que quieres hacer en el modelo. Primero verás una propuesta; nada se aplicará sin tu confirmación.',
    ),
  ];
  MobileAiMode _mode = MobileAiMode.automatic;
  MobileAiResponse? _proposal;
  Set<String> _selected = {};
  MobileAiCancellation? _cancellation;
  Timer? _progressTimer;
  Timer? _recordingTimer;
  bool _requesting = false;
  bool _applying = false;
  bool _recording = false;
  bool _transcribing = false;
  int _elapsedSeconds = 0;
  int _streamedCharacters = 0;
  int _lastProgressPaint = 0;
  String? _error;

  @override
  void dispose() {
    _cancellation?.cancel();
    unawaited(_cancellation?.close());
    _progressTimer?.cancel();
    _recordingTimer?.cancel();
    if (_recording) unawaited(widget.voiceTranscriber?.cancel());
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _requesting || _applying || _recording || _transcribing) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _messages.add(_AiChatMessage(fromUser: true, text: text));
      _controller.clear();
      _proposal = null;
      _selected = {};
      _error = null;
      _requesting = true;
      _elapsedSeconds = 0;
      _streamedCharacters = 0;
      _lastProgressPaint = 0;
    });
    _scrollToEnd();
    final cancellation = MobileAiCancellation();
    _cancellation = cancellation;
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _requesting) {
        setState(() => _elapsedSeconds++);
      }
    });
    try {
      final response = await widget.engine.propose(
        MobileAiRequest(
          projectId: widget.snapshot.project.id,
          prompt: _conversationPrompt(),
          baseRevision: widget.snapshot.project.revision,
          permission: widget.access.name,
          selection: widget.selectedElementIds,
          mode: _mode,
          context: AiContextBuilder().build(
            snapshot: widget.snapshot,
            diagramId: widget.diagramId,
            selectedElementIds: widget.selectedElementIds,
          ),
        ),
        cancellation: cancellation,
        onToken: _onLocalToken,
      );
      if (!mounted) return;
      setState(() {
        _proposal = response;
        _selected = response.operations.map((item) => item.id).toSet();
        _messages.add(
          _AiChatMessage(
            fromUser: false,
            text: response.questions.isNotEmpty
                ? 'Necesito aclarar esto antes de proponer cambios:\n${response.questions.map((item) => '• $item').join('\n')}'
                : response.operations.isEmpty
                ? 'No encontré cambios seguros para proponer. Puedes precisar la solicitud.'
                : 'Preparé ${response.operations.length} cambio(s). Revísalos y confirma solo los que quieras aplicar.',
          ),
        );
      });
    } on MobileAiException catch (error) {
      if (!mounted) return;
      setState(() {
        if (error.code != 'cancelled') _error = error.message;
        if (error.code == 'cancelled') {
          _messages.add(
            const _AiChatMessage(
              fromUser: false,
              text: 'Solicitud cancelada. El proyecto no fue modificado.',
            ),
          );
        }
      });
    } on TimeoutException {
      if (mounted) {
        setState(() => _error = 'La IA tardó demasiado en responder.');
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = '$error'
              .replaceFirst('Bad state: ', '')
              .replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      _progressTimer?.cancel();
      _progressTimer = null;
      await cancellation.close();
      if (identical(_cancellation, cancellation)) _cancellation = null;
      if (mounted) {
        setState(() => _requesting = false);
        _scrollToEnd();
      }
    }
  }

  Future<void> _startRecording() async {
    final transcriber = widget.voiceTranscriber;
    if (transcriber == null || _requesting || _applying || _transcribing) {
      return;
    }
    setState(() => _error = null);
    try {
      await transcriber.start();
      if (!mounted) {
        await transcriber.cancel();
        return;
      }
      setState(() => _recording = true);
      _recordingTimer?.cancel();
      _recordingTimer = Timer(
        const Duration(seconds: 60),
        () => unawaited(_stopRecording()),
      );
    } on MobileAiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo iniciar el micrófono.');
      }
    }
  }

  Future<void> _stopRecording() async {
    final transcriber = widget.voiceTranscriber;
    if (transcriber == null || !_recording || _transcribing) return;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    setState(() {
      _recording = false;
      _transcribing = true;
      _error = null;
    });
    try {
      final text = await transcriber.stopAndTranscribe(
        widget.snapshot.project.id,
      );
      if (!mounted) return;
      final current = _controller.text.trim();
      _controller.text = current.isEmpty ? text : '$current $text';
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    } on MobileAiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo transcribir el audio.');
      }
    } finally {
      if (mounted) setState(() => _transcribing = false);
    }
  }

  void _onLocalToken(String token) {
    _streamedCharacters += token.length;
    if (!mounted || _streamedCharacters - _lastProgressPaint < 24) {
      return;
    }
    _lastProgressPaint = _streamedCharacters;
    setState(() {});
  }

  String get _progressLabel {
    final elapsed = _elapsedSeconds == 1
        ? '1 segundo'
        : '$_elapsedSeconds segundos';
    if (_streamedCharacters == 0) {
      return _mode == MobileAiMode.local
          ? 'Cargando el modelo local… $elapsed'
          : 'Preparando la respuesta… $elapsed';
    }
    return 'Generando en el dispositivo… '
        '$_streamedCharacters caracteres · $elapsed';
  }

  String _conversationPrompt() {
    final transcript = _messages
        .skip(1)
        .map(
          (message) =>
              '${message.fromUser ? 'Usuario' : 'Asistente'}: ${message.text}',
        )
        .join('\n');
    return 'Conversación sobre el proyecto UML:\n$transcript';
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _toggleOperation(MobileAiOperation operation, bool selected) {
    final proposal = _proposal;
    if (proposal == null) return;
    final byId = {for (final item in proposal.operations) item.id: item};
    setState(() {
      if (selected) {
        void include(String id) {
          final item = byId[id];
          if (item == null || !_selected.add(id)) return;
          for (final dependency in item.dependsOn) {
            include(dependency);
          }
        }

        include(operation.id);
      } else {
        _selected.remove(operation.id);
        var changed = true;
        while (changed) {
          changed = false;
          for (final item in proposal.operations) {
            if (_selected.contains(item.id) &&
                item.dependsOn.any((id) => !_selected.contains(id))) {
              _selected.remove(item.id);
              changed = true;
            }
          }
        }
      }
    });
  }

  Set<String> get _missingDependencies {
    final proposal = _proposal;
    if (proposal == null) return const {};
    final available = proposal.operations.map((item) => item.id).toSet();
    return {
      for (final operation in proposal.operations)
        if (_selected.contains(operation.id))
          ...operation.dependsOn.where(
            (id) => !available.contains(id) || !_selected.contains(id),
          ),
    };
  }

  bool get _canApply {
    final proposal = _proposal;
    return proposal != null &&
        proposal.canConfirm &&
        proposal.operations.isNotEmpty &&
        widget.access != ProjectAccess.viewer &&
        _selected.isNotEmpty &&
        _missingDependencies.isEmpty &&
        !_requesting &&
        !_applying;
  }

  Future<void> _apply() async {
    final proposal = _proposal;
    if (proposal == null || !_canApply) return;
    setState(() {
      _applying = true;
      _error = null;
    });
    try {
      final snapshot = await widget.applyProposal(proposal, _selected);
      if (!mounted) return;
      Navigator.of(context).pop(snapshot);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _applying = false;
        _error = '$error'
            .replaceFirst('ViewerRepositoryException: ', '')
            .replaceFirst('Bad state: ', '')
            .replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: .92,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.indigo),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Asistente UML',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          widget.selectedElementIds.isEmpty
                              ? 'Alcance: diagrama y proyecto actual'
                              : 'Alcance: selección actual y sus relaciones',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<MobileAiMode>(
                      key: const ValueKey('ai-mode-selector'),
                      initialValue: _mode,
                      isDense: true,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Motor'),
                      items: [
                        const DropdownMenuItem(
                          value: MobileAiMode.automatic,
                          child: Text('Automático'),
                        ),
                        const DropdownMenuItem(
                          value: MobileAiMode.api,
                          child: Text('API'),
                        ),
                        if (widget.supportsLocal)
                          const DropdownMenuItem(
                            value: MobileAiMode.local,
                            child: Text('Local'),
                          ),
                      ],
                      onChanged: _requesting || _applying
                          ? null
                          : (value) => setState(
                              () => _mode = value ?? MobileAiMode.automatic,
                            ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: _applying
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                key: const ValueKey('ai-conversation'),
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  for (final message in _messages)
                    _MessageBubble(message: message),
                  if (_requesting)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Chip(
                          avatar: const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          label: Text(
                            _progressLabel,
                            key: const ValueKey('ai-generation-progress'),
                          ),
                        ),
                      ),
                    ),
                  if (_proposal != null) _proposalReview(_proposal!),
                  if (_error != null)
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: ListTile(
                        leading: const Icon(Icons.error_outline),
                        title: Text(_error!, key: const ValueKey('ai-error')),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                10,
                12,
                10 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.voiceTranscriber != null) ...[
                    IconButton.filledTonal(
                      key: const ValueKey('ai-voice-input'),
                      tooltip: _recording
                          ? 'Detener y transcribir'
                          : 'Dictar por voz',
                      onPressed: _requesting || _applying || _transcribing
                          ? null
                          : _recording
                          ? _stopRecording
                          : _startRecording,
                      icon: _transcribing
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(_recording ? Icons.stop : Icons.mic),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: TextField(
                      key: const ValueKey('ai-prompt-input'),
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      enabled:
                          !_requesting &&
                          !_applying &&
                          !_recording &&
                          !_transcribing,
                      decoration: const InputDecoration(
                        hintText:
                            'Ej.: añade una clase Factura y relaciónala con Pedido',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_requesting)
                    IconButton.filledTonal(
                      key: const ValueKey('ai-cancel-request'),
                      tooltip: 'Cancelar solicitud',
                      onPressed: _cancellation?.cancel,
                      icon: const Icon(Icons.stop),
                    )
                  else
                    IconButton.filled(
                      key: const ValueKey('ai-send'),
                      tooltip: 'Enviar',
                      onPressed:
                          _applying || _recording || _transcribing
                          ? null
                          : _send,
                      icon: const Icon(Icons.send),
                    ),
                ],
              ),
            ),
            if (_recording || _transcribing)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _recording
                        ? 'Grabando… toca detener para transcribir (máximo 60 s).'
                        : 'Whisper está convirtiendo el audio a texto…',
                    key: const ValueKey('ai-voice-status'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _proposalReview(MobileAiResponse proposal) {
    final missing = _missingDependencies;
    return Card(
      key: const ValueKey('ai-proposal-preview'),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.difference_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vista previa · ${proposal.origin.name} · ${proposal.model}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (proposal.assumptions.isNotEmpty)
              _NoticeList(
                title: 'Supuestos',
                icon: Icons.psychology_alt_outlined,
                items: proposal.assumptions,
              ),
            if (proposal.warnings.isNotEmpty)
              _NoticeList(
                title: 'Advertencias',
                icon: Icons.warning_amber_outlined,
                items: proposal.warnings,
              ),
            if (proposal.diagnostics.isNotEmpty)
              _NoticeList(
                title: 'Validación y reparaciones',
                icon: Icons.rule_outlined,
                items: proposal.diagnostics
                    .map(
                      (item) =>
                          '${item.severity.toUpperCase()}: ${item.message}'
                          '${item.repair == null ? '' : ' · Reparación: ${item.repair}'}',
                    )
                    .toList(growable: false),
              ),
            if (proposal.questions.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Responde las preguntas en el chat para generar una propuesta confirmable.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            for (final operation in proposal.operations)
              _operationTile(operation),
            if (missing.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Faltan dependencias seleccionadas: ${missing.join(', ')}',
                  key: const ValueKey('ai-missing-dependencies'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (widget.access == ProjectAccess.viewer)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Tu rol es lector: puedes consultar la IA y revisar propuestas, pero no confirmarlas.',
                  key: ValueKey('ai-reader-notice'),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _applying
                      ? null
                      : () => setState(() {
                          _proposal = null;
                          _selected = {};
                        }),
                  child: const Text('Descartar'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const ValueKey('ai-confirm'),
                  onPressed: _canApply ? _apply : null,
                  icon: _applying
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    _applying
                        ? 'Aplicando…'
                        : 'Confirmar ${_selected.length} cambio(s)',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _operationTile(MobileAiOperation operation) {
    final before = _beforeValue(operation);
    final visual = {
      'DiagramNode',
      'DiagramEdge',
    }.contains(operation.entityType);
    final unknownDependencies = operation.dependsOn
        .where(
          (id) =>
              !(_proposal?.operations.any((item) => item.id == id) ?? false),
        )
        .toList(growable: false);
    return Card.outlined(
      margin: const EdgeInsets.only(top: 10),
      child: CheckboxListTile(
        key: ValueKey('ai-operation-${operation.id}'),
        value: _selected.contains(operation.id),
        onChanged: unknownDependencies.isNotEmpty
            ? null
            : (value) => _toggleOperation(operation, value == true),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          '${visual ? 'Visual' : 'Semántico'} · ${_actionLabel(operation.action)} ${operation.entityType}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (operation.explanation.isNotEmpty) Text(operation.explanation),
            Text('Antes: ${before ?? 'No existe'}'),
            Text(
              operation.action == 'delete'
                  ? 'Después: eliminado'
                  : 'Después: ${operation.value}',
            ),
            if (operation.dependsOn.isNotEmpty)
              Text('Requiere: ${operation.dependsOn.join(', ')}'),
            if (unknownDependencies.isNotEmpty)
              Text(
                'No seleccionable: faltan ${unknownDependencies.join(', ')}.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic>? _beforeValue(MobileAiOperation operation) {
    final id = operation.entityId;
    if (id == null) return null;
    return switch (operation.entityType) {
      'UmlElement' =>
        widget.snapshot.elements
            .where((item) => item.id == id)
            .map((item) => item.toJson())
            .firstOrNull,
      'UmlRelationship' =>
        widget.snapshot.relationships
            .where((item) => item.id == id)
            .map((item) => item.toJson())
            .firstOrNull,
      'Diagram' =>
        widget.snapshot.diagrams
            .where((item) => item.id == id)
            .map((item) => item.toJson())
            .firstOrNull,
      'DiagramNode' =>
        widget.snapshot.nodes
            .where((item) => item.id == id)
            .map((item) => item.toJson())
            .firstOrNull,
      'DiagramEdge' =>
        widget.snapshot.edges
            .where((item) => item.id == id)
            .map((item) => item.toJson())
            .firstOrNull,
      _ => null,
    };
  }
}

class _AiChatMessage {
  const _AiChatMessage({required this.fromUser, required this.text});
  final bool fromUser;
  final String text;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final _AiChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.fromUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: message.fromUser
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(message.text),
      ),
    );
  }
}

class _NoticeList extends StatelessWidget {
  const _NoticeList({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$title:\n${items.map((item) => '• $item').join('\n')}',
            ),
          ),
        ],
      ),
    );
  }
}

String _actionLabel(String action) => switch (action) {
  'create' => 'crear',
  'update' => 'actualizar',
  'delete' => 'eliminar',
  _ => action,
};
