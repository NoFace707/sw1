import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/ai/domain/mobile_ai.dart';
import 'package:mobile/features/ai/data/mobile_voice_transcriber.dart';
import 'package:mobile/features/ai/presentation/ai_assistant_sheet.dart';
import 'package:mobile/features/viewer/domain/viewer_models.dart';

const _project = UmlProjectSummary(
  id: 'project-1',
  name: 'Ventas',
  access: ProjectAccess.editor,
  updatedAt: null,
  revision: 4,
);

const _snapshot = UmlSnapshot(
  project: _project,
  diagrams: [UmlDiagram(id: 'diagram-1', name: 'Clases', type: 'class')],
  elements: [UmlElement(id: 'element-1', name: 'Pedido', metaclass: 'Class')],
  relationships: [],
  nodes: [
    UmlDiagramNode(
      id: 'node-1',
      diagramId: 'diagram-1',
      elementId: 'element-1',
      bounds: Rect.fromLTWH(20, 20, 180, 90),
    ),
  ],
  edges: [],
  loadedFromOffline: false,
);

class _FakeEngine implements MobileAiEngine {
  _FakeEngine(this.responses);

  final List<MobileAiResponse> responses;
  final List<MobileAiRequest> requests = [];

  @override
  String get id => 'fake';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<MobileAiResponse> propose(
    MobileAiRequest request, {
    MobileAiCancellation? cancellation,
    void Function(String token)? onToken,
  }) async {
    requests.add(request);
    return responses.removeAt(0);
  }
}

class _StreamingEngine implements MobileAiEngine {
  final gate = Completer<void>();

  @override
  String get id => 'streaming';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<MobileAiResponse> propose(
    MobileAiRequest request, {
    MobileAiCancellation? cancellation,
    void Function(String token)? onToken,
  }) async {
    onToken?.call('{"operations":[],' * 2);
    await gate.future;
    return const MobileAiResponse(
      id: 'streamed',
      origin: MobileAiOrigin.local,
      model: 'local-test',
      operations: [],
      questions: ['¿Qué deseas modelar?'],
    );
  }
}

class _FakeVoiceTranscriber implements MobileVoiceTranscriber {
  final String text = 'crea una clase Cliente';
  int starts = 0;
  int stops = 0;

  @override
  Future<void> start() async => starts++;

  @override
  Future<String> stopAndTranscribe(String projectId) async {
    stops++;
    expect(projectId, 'project-1');
    return text;
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}

Widget _app({
  required MobileAiEngine engine,
  required ApplyAiProposal apply,
  ProjectAccess access = ProjectAccess.editor,
  MobileVoiceTranscriber? voiceTranscriber,
}) {
  return MaterialApp(
    home: Scaffold(
      body: AiAssistantSheet(
        engine: engine,
        snapshot: _snapshot,
        diagramId: 'diagram-1',
        selectedElementIds: const ['element-1'],
        access: access,
        applyProposal: apply,
        supportsLocal: true,
        voiceTranscriber: voiceTranscriber,
      ),
    ),
  );
}

Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const ValueKey('ai-prompt-input')), text);
  await tester.tap(find.byKey(const ValueKey('ai-send')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('dicta a texto editable sin enviar una propuesta', (
    tester,
  ) async {
    final engine = _FakeEngine([]);
    final voice = _FakeVoiceTranscriber();
    await tester.pumpWidget(
      _app(
        engine: engine,
        voiceTranscriber: voice,
        apply: (proposal, selected) async => _snapshot,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('ai-voice-input')));
    await tester.pump();
    expect(find.textContaining('Grabando'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ai-voice-input')));
    await tester.pumpAndSettle();

    final input = tester.widget<TextField>(
      find.byKey(const ValueKey('ai-prompt-input')),
    );
    expect(input.controller!.text, 'crea una clase Cliente');
    expect(engine.requests, isEmpty);
    expect(voice.starts, 1);
    expect(voice.stops, 1);
  });

  testWidgets('muestra avance mientras la IA local genera', (tester) async {
    final engine = _StreamingEngine();
    await tester.pumpWidget(
      _app(engine: engine, apply: (proposal, selected) async => _snapshot),
    );

    await tester.enterText(
      find.byKey(const ValueKey('ai-prompt-input')),
      'Hola',
    );
    await tester.tap(find.byKey(const ValueKey('ai-send')));
    await tester.pump();

    expect(find.byKey(const ValueKey('ai-generation-progress')), findsOne);
    expect(find.textContaining('Generando en el dispositivo'), findsOne);

    engine.gate.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('¿Qué deseas modelar?'), findsWidgets);
  });

  testWidgets('hace preguntas antes de mostrar operaciones confirmables', (
    tester,
  ) async {
    final engine = _FakeEngine([
      const MobileAiResponse(
        id: 'questions',
        origin: MobileAiOrigin.remote,
        model: 'test',
        operations: [],
        questions: ['¿Factura debe relacionarse con Pedido?'],
      ),
      const MobileAiResponse(
        id: 'proposal-1',
        origin: MobileAiOrigin.remote,
        model: 'test',
        operations: [
          MobileAiOperation(
            id: 'op-1',
            entityType: 'UmlElement',
            action: 'create',
            value: {'metaclass': 'Class', 'name': 'Factura'},
            explanation: 'Añade la entidad solicitada.',
          ),
        ],
      ),
    ]);
    var applyCalls = 0;
    await tester.pumpWidget(
      _app(
        engine: engine,
        apply: (proposal, selected) async {
          applyCalls++;
          return _snapshot;
        },
      ),
    );

    await _send(tester, 'Añade una factura');
    expect(find.textContaining('¿Factura debe'), findsWidgets);
    expect(find.byKey(const ValueKey('ai-confirm')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('ai-confirm')))
          .onPressed,
      isNull,
    );
    expect(applyCalls, 0);
    expect(_snapshot.project.revision, 4);

    await _send(tester, 'Sí, mediante una asociación uno a muchos');
    expect(find.byKey(const ValueKey('ai-operation-op-1')), findsOneWidget);
    expect(engine.requests, hasLength(2));
    expect(
      engine.requests.last.prompt,
      allOf(contains('Añade una factura'), contains('uno a muchos')),
    );
    expect(applyCalls, 0);
  });

  testWidgets(
    'selección parcial elimina dependientes y aplica solo lo elegido',
    (tester) async {
      final engine = _FakeEngine([
        const MobileAiResponse(
          id: 'proposal-2',
          origin: MobileAiOrigin.remote,
          model: 'test',
          operations: [
            MobileAiOperation(
              id: 'element',
              entityType: 'UmlElement',
              action: 'create',
              value: {'metaclass': 'Class', 'name': 'Factura'},
            ),
            MobileAiOperation(
              id: 'node',
              entityType: 'DiagramNode',
              action: 'create',
              value: {'diagram': 'diagram-1', 'element': 'new-element'},
              dependsOn: ['element'],
            ),
            MobileAiOperation(
              id: 'rename',
              entityType: 'Diagram',
              entityId: 'diagram-1',
              action: 'update',
              value: {'name': 'Modelo de ventas'},
            ),
          ],
        ),
      ]);
      Set<String>? applied;
      await tester.pumpWidget(
        _app(
          engine: engine,
          apply: (proposal, selected) async {
            applied = Set.of(selected);
            return _snapshot;
          },
        ),
      );
      await _send(tester, 'Añade Factura y renombra el diagrama');

      final elementTile = find.byKey(const ValueKey('ai-operation-element'));
      await tester.tap(
        find.descendant(of: elementTile, matching: find.byType(Checkbox)),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('ai-operation-node')),
            )
            .value,
        isFalse,
      );
      expect(find.text('Confirmar 1 cambio(s)'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('ai-confirm')));
      await tester.pumpAndSettle();
      expect(applied, {'rename'});
    },
  );

  testWidgets('lector puede conversar y revisar pero no confirmar', (
    tester,
  ) async {
    final engine = _FakeEngine([
      const MobileAiResponse(
        id: 'proposal-3',
        origin: MobileAiOrigin.remote,
        model: 'test',
        operations: [
          MobileAiOperation(
            id: 'op',
            entityType: 'Diagram',
            action: 'create',
            value: {'name': 'Nuevo', 'diagram_type': 'class'},
          ),
        ],
      ),
    ]);
    await tester.pumpWidget(
      _app(
        engine: engine,
        access: ProjectAccess.viewer,
        apply: (proposal, selected) async => _snapshot,
      ),
    );
    await _send(tester, 'Crea un diagrama');

    expect(find.byKey(const ValueKey('ai-reader-notice')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('ai-confirm')))
          .onPressed,
      isNull,
    );
  });
}
