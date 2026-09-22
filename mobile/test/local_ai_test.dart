import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile/features/ai/data/hybrid_ai_engine.dart';
import 'package:mobile/features/ai/data/local_llama_engine.dart';
import 'package:mobile/features/ai/data/local_model_manager.dart';
import 'package:mobile/features/ai/domain/ai_context_builder.dart';
import 'package:mobile/features/ai/domain/ai_proposal_validator.dart';
import 'package:mobile/features/ai/domain/expert_evaluator.dart';
import 'package:mobile/features/ai/domain/mobile_ai.dart';
import 'package:mobile/features/ai/presentation/local_ai_model_sheet.dart';
import 'package:mobile/features/offline/data/offline_database.dart';
import 'package:mobile/features/viewer/data/viewer_repository.dart';
import 'package:mobile/features/viewer/domain/viewer_models.dart';
import 'package:mobile/features/viewer/presentation/pages/uml_viewer_page.dart';

Map<String, dynamic> _rulesPayload() {
  final body = <String, dynamic>{
    'schema_version': 1,
    'version': 'test-1',
    'registry_version': 'registry-1',
    'rules': [
      {
        'id': 'class.attributes.typed',
        'category': 'uml_types',
        'scope': 'Class',
        'severity': 'warning',
        'condition': {'operator': 'class_attributes_typed'},
        'message': 'Falta el tipo.',
        'evidence': {
          'fields': ['properties.attributes'],
        },
        'question': '¿Qué tipo corresponde?',
        'repair': null,
        'mapping': <String, dynamic>{},
      },
      {
        'id': 'proposal.permission.write',
        'category': 'permissions',
        'scope': 'proposal',
        'severity': 'error',
        'condition': {'operator': 'write_permission'},
        'message': 'Sin permiso de escritura.',
        'evidence': {
          'fields': ['permission'],
        },
        'question': null,
        'repair': null,
        'mapping': <String, dynamic>{},
      },
    ],
  };
  return {
    ...body,
    'checksum': sha256.convert(utf8.encode(canonicalJson(body))).toString(),
  };
}

const _project = UmlProjectSummary(
  id: 'project-1',
  name: 'Ventas',
  access: ProjectAccess.editor,
  updatedAt: null,
  revision: 4,
  availableOffline: true,
);

UmlSnapshot _snapshot() => UmlSnapshot(
  project: _project,
  diagrams: const [UmlDiagram(id: 'diagram-1', name: 'Clases', type: 'class')],
  elements: const [
    UmlElement(
      id: 'element-1',
      name: 'Pedido',
      metaclass: 'Class',
      properties: {
        'attributes': ['total: Decimal'],
        'api_token': 'no-debe-salir',
      },
    ),
  ],
  relationships: const [],
  nodes: const [
    UmlDiagramNode(
      id: 'node-1',
      diagramId: 'diagram-1',
      elementId: 'element-1',
      bounds: Rect.fromLTWH(0, 0, 180, 80),
    ),
  ],
  edges: const [],
  loadedFromOffline: true,
);

class _FakeRuntime implements LocalModelRuntime {
  _FakeRuntime(this.parts, {this.gate});
  final List<String> parts;
  final Completer<void>? gate;
  bool cancelled = false;
  bool closed = false;

  LocalAiPrompt? prompt;

  @override
  Stream<String> generate(LocalAiPrompt prompt) async* {
    this.prompt = prompt;
    for (final part in parts) {
      if (gate != null) await gate!.future;
      if (cancelled) return;
      yield part;
    }
  }

  @override
  Future<void> cancel() async => cancelled = true;

  @override
  Future<void> close() async => closed = true;
}

class _FakeLocalModelManager extends LocalModelManager {
  _FakeLocalModelManager(this.totalBytes)
    : super(
        userId: 'user-a',
        directoryProvider: () async => Directory.systemTemp,
        client: MockClient((_) async => http.Response('', 500)),
      );

  final int totalBytes;
  final _events = StreamController<LocalModelProgress>.broadcast();
  final _downloadGate = Completer<void>();
  bool installed = false;
  int downloadCalls = 0;

  @override
  Stream<LocalModelProgress> get progress => _events.stream;

  @override
  Future<bool> isInstalled(LocalModelManifest manifest) async => installed;

  @override
  Future<int> storedBytes(LocalModelManifest manifest) async =>
      installed ? totalBytes : 0;

  @override
  Future<File?> download(
    LocalModelManifest manifest, {
    required bool consented,
    required DeviceResourceProfile resources,
  }) async {
    downloadCalls++;
    _events.add(
      LocalModelProgress(
        state: LocalModelDownloadState.downloading,
        downloadedBytes: totalBytes ~/ 2,
        totalBytes: totalBytes,
      ),
    );
    await _downloadGate.future;
    _events.add(
      LocalModelProgress(
        state: LocalModelDownloadState.verifying,
        downloadedBytes: totalBytes,
        totalBytes: totalBytes,
      ),
    );
    installed = true;
    _events.add(
      LocalModelProgress(
        state: LocalModelDownloadState.ready,
        downloadedBytes: totalBytes,
        totalBytes: totalBytes,
      ),
    );
    return File('verified.gguf');
  }

  @override
  Future<File?> repair(
    LocalModelManifest manifest, {
    required bool consented,
    required DeviceResourceProfile resources,
  }) => download(manifest, consented: consented, resources: resources);

  void finishDownload() => _downloadGate.complete();

  @override
  Future<void> close() async {
    await _events.close();
    await super.close();
  }
}

class _Engine implements MobileAiEngine {
  _Engine(this.engineId, this.available, {this.failure});
  final String engineId;
  final bool available;
  final MobileAiException? failure;
  int calls = 0;

  @override
  String get id => engineId;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<MobileAiResponse> propose(
    MobileAiRequest request, {
    MobileAiCancellation? cancellation,
    void Function(String token)? onToken,
  }) async {
    calls++;
    if (failure != null) throw failure!;
    return MobileAiResponse(
      id: engineId,
      origin: engineId == 'local'
          ? MobileAiOrigin.local
          : MobileAiOrigin.remote,
      model: engineId,
      operations: const [],
    );
  }
}

class _StreamClient extends http.BaseClient {
  _StreamClient(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}

class _SnapshotRepository implements ViewerRepository {
  const _SnapshotRepository(this.snapshot);
  final UmlSnapshot snapshot;

  @override
  Future<List<UmlProjectSummary>> loadProjects({bool refresh = true}) async => [
    snapshot.project,
  ];

  @override
  Future<UmlSnapshot> loadSnapshot(
    UmlProjectSummary project, {
    bool preferRemote = true,
  }) async => snapshot;

  @override
  Stream<int> watchRemoteRevisions(String projectId) => const Stream.empty();
}

void main() {
  late ExpertEvaluator evaluator;
  late MobileAiRequest request;

  setUp(() {
    evaluator = ExpertEvaluator(ExpertRuleSet.verified(_rulesPayload()));
    request = MobileAiRequest(
      projectId: _project.id,
      prompt: 'Crea la clase Cliente',
      baseRevision: _project.revision,
      permission: 'editor',
      context: AiContextBuilder().build(snapshot: _snapshot()),
    );
  });

  test('el contexto mínimo elimina secretos y proyectos ajenos', () {
    final context = AiContextBuilder().build(
      snapshot: _snapshot(),
      selectedElementIds: const ['element-1'],
    );
    final encoded = jsonEncode(context);
    expect(encoded, contains('Pedido'));
    expect(encoded, isNot(contains('no-debe-salir')));
    expect(encoded, isNot(contains('api_token')));
    expect(encoded, isNot(contains('other-project')));
  });

  test(
    'rechaza una actualización de reglas alterada y conserva la anterior',
    () {
      final valid = ExpertRuleSet.verified(_rulesPayload());
      final altered = {..._rulesPayload(), 'version': 'alterada'};
      expect(() => ExpertRuleSet.verified(altered), throwsFormatException);
      expect(valid.version, 'test-1');
    },
  );

  test('evaluador Dart reproduce los fixtures compartidos', () async {
    final cases =
        jsonDecode(
              await File(
                '../shared/fixtures/expert-rules-cases.json',
              ).readAsString(),
            )
            as List;
    for (final raw in cases.whereType<Map>()) {
      final item = raw.map((key, value) => MapEntry('$key', value));
      final diagnostics = evaluator.evaluate(
        (item['context'] as Map).map((key, value) => MapEntry('$key', value)),
      );
      final ids = diagnostics.map((entry) => entry.ruleId).toSet();
      expect(
        ids.containsAll(
          (item['must_contain'] as List? ?? const []).cast<String>(),
        ),
        isTrue,
        reason: '${item['name']}',
      );
      expect(
        ids.intersection(
          (item['must_not_contain'] as List? ?? const [])
              .cast<String>()
              .toSet(),
        ),
        isEmpty,
        reason: '${item['name']}',
      );
    }
  });

  test('validador bloquea permiso, revisión, tipo y relación inválidos', () {
    final invalidRequest = MobileAiRequest(
      projectId: 'project-1',
      prompt: 'cambia',
      baseRevision: 3,
      permission: 'viewer',
      context: {
        ...request.context,
        'registry': {
          'element_types': ['Class'],
          'relationship_types': ['Association'],
        },
      },
    );
    const operations = [
      MobileAiOperation(
        id: 'o1',
        entityType: 'UmlElement',
        action: 'create',
        entityId: 'e2',
        value: {'id': 'e2', 'metaclass': 'Unknown', 'name': 'X'},
      ),
      MobileAiOperation(
        id: 'o2',
        entityType: 'UmlRelationship',
        action: 'create',
        entityId: 'r1',
        value: {
          'id': 'r1',
          'relationship_type': 'Association',
          'source': 'missing',
          'target': 'e2',
        },
      ),
    ];

    final diagnostics = const AiProposalValidator().validate(
      invalidRequest,
      operations,
    );
    final rules = diagnostics.map((item) => item.ruleId).toSet();
    expect(rules, contains('proposal.permission.write'));
    expect(rules, contains('proposal.revision.current'));
    expect(rules, contains('proposal.element.metaclass'));
    expect(rules, contains('proposal.relationship.endpoints'));
  });

  test(
    'LocalLlamaEngine comparte contrato, agrega UUID y evalúa la salida',
    () async {
      final runtime = _FakeRuntime([
        '{"operations":[{"entity_type":"UmlElement",',
        '"action":"create","value":{"metaclass":"Class","name":"Cliente"}}]}',
      ]);
      final engine = LocalLlamaEngine(
        runtimeFactory: () async => runtime,
        available: () async => true,
        evaluator: evaluator,
      );

      final response = await engine.propose(request);

      expect(response.origin, MobileAiOrigin.local);
      expect(response.operations.single.id, isNotEmpty);
      expect(response.operations.single.value['name'], 'Cliente');
      expect(runtime.prompt?.system, contains('exclusivamente'));
      expect(runtime.prompt?.user, contains('SOLICITUD='));
      expect(runtime.closed, isTrue);
    },
  );

  test(
    'extrae JSON aunque el modelo agregue razonamiento o tokens finales',
    () {
      final decoded = decodeAiJson(
        '<think>analizando</think>\n```json\n'
        '{"operations":[],"questions":["¿Qué deseas modelar?"]}'
        '\n```\n<|im_end|>',
      );

      expect(decoded['operations'], isEmpty);
      expect(decoded['questions'], ['¿Qué deseas modelar?']);
    },
  );

  test('reporta una salida local incompleta sin exponer jsonDecode', () {
    expect(
      () => decodeAiJson('respuesta {"operations":['),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('no terminó'),
        ),
      ),
    );
  });

  test('JSON parcial se descarta y la sesión se libera', () async {
    final runtime = _FakeRuntime(['{"operations":[']);
    final engine = LocalLlamaEngine(
      runtimeFactory: () async => runtime,
      available: () async => true,
      evaluator: evaluator,
    );
    await expectLater(
      engine.propose(request),
      throwsA(
        isA<MobileAiException>().having(
          (error) => error.code,
          'code',
          'invalid_json',
        ),
      ),
    );
    expect(runtime.closed, isTrue);
  });

  test('cancelar detiene la inferencia y cierra el runtime', () async {
    final gate = Completer<void>();
    final runtime = _FakeRuntime(['{}'], gate: gate);
    final cancellation = MobileAiCancellation();
    final engine = LocalLlamaEngine(
      runtimeFactory: () async => runtime,
      available: () async => true,
      evaluator: evaluator,
    );
    final future = engine.propose(request, cancellation: cancellation);
    await Future<void>.delayed(Duration.zero);
    cancellation.cancel();
    gate.complete();
    await expectLater(future, throwsA(isA<MobileAiException>()));
    expect(runtime.cancelled, isTrue);
    expect(runtime.closed, isTrue);
    await cancellation.close();
  });

  test('modo automático usa local cuando API no está disponible', () async {
    final remote = _Engine('remote', false);
    final local = _Engine('local', true);
    final hybrid = HybridAiEngine(remote: remote, local: local);

    final result = await hybrid.propose(request);

    expect(result.origin, MobileAiOrigin.local);
    expect(remote.calls, 0);
    expect(local.calls, 1);
  });

  test('modo automático usa local cuando la API falla sin mutar', () async {
    final remote = _Engine(
      'remote',
      true,
      failure: const MobileAiException('API caída', code: 'unavailable'),
    );
    final local = _Engine('local', true);
    final hybrid = HybridAiEngine(remote: remote, local: local);

    final result = await hybrid.propose(request);

    expect(result.origin, MobileAiOrigin.local);
    expect(remote.calls, 1);
    expect(local.calls, 1);
  });

  test(
    'confirmación offline persiste antes de proyectar y es idempotente',
    () async {
      final database = OfflineDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await database.saveOfflineBundle(
        'user-a',
        OfflineBundle(
          snapshot: _snapshot(),
          registry: const {'version': 'registry-1'},
          rules: _rulesPayload(),
        ),
      );
      const operation = MobileAiOperation(
        id: 'operation-1',
        entityType: 'UmlElement',
        action: 'create',
        entityId: 'element-2',
        value: {'metaclass': 'Class', 'name': 'Cliente', 'properties': {}},
      );
      const proposal = MobileAiResponse(
        id: 'proposal-1',
        origin: MobileAiOrigin.local,
        model: 'fake',
        operations: [operation],
      );

      final first = await database.confirmLocalProposal(
        userId: 'user-a',
        projectId: 'project-1',
        proposal: proposal,
        selectedOperationIds: const ['operation-1'],
      );
      final second = await database.confirmLocalProposal(
        userId: 'user-a',
        projectId: 'project-1',
        proposal: proposal,
        selectedOperationIds: const ['operation-1'],
      );

      expect(
        first.elements.where((item) => item.id == 'element-2'),
        hasLength(1),
      );
      expect(
        second.elements.where((item) => item.id == 'element-2'),
        hasLength(1),
      );
      expect(second.project.syncState, ViewerSyncState.pending);
      expect(
        await database.pendingOperations('user-a', 'project-1'),
        hasLength(1),
      );
    },
  );

  test('reinicio conserva operación IA sin volver a proyectarla', () async {
    final directory = await Directory.systemTemp.createTemp('sw1-ai-db-');
    final file = File(
      '${directory.path}${Platform.pathSeparator}offline.sqlite',
    );
    const operation = MobileAiOperation(
      id: 'operation-restart',
      entityType: 'UmlElement',
      action: 'create',
      entityId: 'element-restart',
      value: {'metaclass': 'Class', 'name': 'Factura', 'properties': {}},
    );
    const proposal = MobileAiResponse(
      id: 'proposal-restart',
      origin: MobileAiOrigin.local,
      model: 'fake',
      operations: [operation],
    );
    final first = OfflineDatabase.forTesting(NativeDatabase(file));
    await first.saveOfflineBundle(
      'user-a',
      OfflineBundle(
        snapshot: _snapshot(),
        registry: const {'version': 'registry-1'},
        rules: _rulesPayload(),
      ),
    );
    await first.confirmLocalProposal(
      userId: 'user-a',
      projectId: 'project-1',
      proposal: proposal,
      selectedOperationIds: const ['operation-restart'],
    );
    await first.close();

    final reopened = OfflineDatabase.forTesting(NativeDatabase(file));
    addTearDown(() async {
      await reopened.close();
      await directory.delete(recursive: true);
    });
    final snapshot = await reopened.confirmLocalProposal(
      userId: 'user-a',
      projectId: 'project-1',
      proposal: proposal,
      selectedOperationIds: const ['operation-restart'],
    );

    expect(
      snapshot.elements.where((item) => item.id == 'element-restart'),
      hasLength(1),
    );
    expect(
      await reopened.pendingOperations('user-a', 'project-1'),
      hasLength(1),
    );
  });

  testWidgets('visor muestra la proyección IA local como pendiente', (
    tester,
  ) async {
    final pendingProject = _project.copyWith(
      syncState: ViewerSyncState.pending,
    );
    final pendingSnapshot = UmlSnapshot(
      project: pendingProject,
      diagrams: _snapshot().diagrams,
      elements: [
        ..._snapshot().elements,
        const UmlElement(id: 'element-2', name: 'Factura', metaclass: 'Class'),
      ],
      relationships: const [],
      nodes: _snapshot().nodes,
      edges: const [],
      loadedFromOffline: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: UmlViewerPage(
          project: pendingProject,
          repository: _SnapshotRepository(pendingSnapshot),
          initialSnapshot: pendingSnapshot,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('viewer-sync-state')), findsOneWidget);
    expect(find.text('Pendiente'), findsOneWidget);
  });

  test('manifiesto alterado se rechaza antes de descargar', () {
    final manifest = _modelManifest([1, 2, 3]);
    expect(LocalModelManifest.verified(manifest).byteSize, 3);
    expect(
      () => LocalModelManifest.verified({...manifest, 'byte_size': 4}),
      throwsFormatException,
    );
  });

  test('perfil insuficiente bloquea el modelo antes de abrir la red', () async {
    final manifest = LocalModelManifest.verified(_modelManifest([1, 2, 3]));
    var networkCalls = 0;
    final directory = await Directory.systemTemp.createTemp('sw1-ai-low-');
    addTearDown(() => directory.delete(recursive: true));
    final manager = LocalModelManager(
      userId: 'user-a',
      directoryProvider: () async => directory,
      client: MockClient((request) async {
        networkCalls++;
        return http.Response('', 500);
      }),
    );
    addTearDown(manager.close);

    await expectLater(
      manager.download(
        manifest,
        consented: true,
        resources: const DeviceResourceProfile(
          architecture: 'unsupported',
          ramBytes: 0,
          freeStorageBytes: 0,
        ),
      ),
      throwsStateError,
    );
    expect(networkCalls, 0);
  });

  test(
    'descarga GGUF reanuda, verifica hash y reemplaza atómicamente',
    () async {
      final bytes = List<int>.generate(128, (index) => index);
      final manifest = LocalModelManifest.verified(_modelManifest(bytes));
      final directory = await Directory.systemTemp.createTemp('sw1-ai-test-');
      addTearDown(() => directory.delete(recursive: true));
      late http.Request seen;
      final manager = LocalModelManager(
        userId: 'user-a',
        directoryProvider: () async => directory,
        client: MockClient((request) async {
          seen = request;
          final offset = int.parse(
            request.headers['range']!.replaceAll(RegExp(r'\D'), ''),
          );
          return http.Response.bytes(bytes.sublist(offset), 206);
        }),
      );
      addTearDown(manager.close);
      final target = await manager.modelFile(manifest);
      await File('${target.path}.part').writeAsBytes(bytes.sublist(0, 41));

      final installed = await manager.download(
        manifest,
        consented: true,
        resources: const DeviceResourceProfile(
          architecture: 'android-arm64',
          ramBytes: 8 * 1024 * 1024 * 1024,
          freeStorageBytes: 8 * 1024 * 1024 * 1024,
        ),
      );

      expect(seen.headers['range'], 'bytes=41-');
      expect(installed?.existsSync(), isTrue);
      expect(await manager.verify(manifest), isTrue);
      expect(File('${target.path}.part').existsSync(), isFalse);
    },
  );

  test('dos solicitudes simultáneas comparten una sola descarga', () async {
    final bytes = List<int>.generate(128, (index) => index);
    final manifest = LocalModelManifest.verified(_modelManifest(bytes));
    final directory = await Directory.systemTemp.createTemp('sw1-ai-single-');
    final responseGate = Completer<void>();
    final requestStarted = Completer<void>();
    var networkCalls = 0;
    addTearDown(() => directory.delete(recursive: true));
    final manager = LocalModelManager(
      userId: 'user-a',
      directoryProvider: () async => directory,
      client: MockClient((request) async {
        networkCalls++;
        if (!requestStarted.isCompleted) requestStarted.complete();
        await responseGate.future;
        return http.Response.bytes(bytes, 200);
      }),
    );
    addTearDown(manager.close);

    final first = manager.download(
      manifest,
      consented: true,
      resources: _enoughResources,
    );
    final second = manager.download(
      manifest,
      consented: true,
      resources: _enoughResources,
    );
    await requestStarted.future;
    expect(networkCalls, 1);

    responseGate.complete();
    final results = await Future.wait([first, second]);

    expect(results.every((file) => file?.existsSync() == true), isTrue);
    expect(results[0]?.path, results[1]?.path);
    expect(networkCalls, 1);
    expect(await manager.verify(manifest), isTrue);
  });

  testWidgets(
    'la interfaz no vuelve a ofrecer descargar mientras instala el modelo',
    (tester) async {
      final bytes = List<int>.generate(128, (index) => index);
      final manifest = LocalModelManifest.verified(_modelManifest(bytes));
      final manager = _FakeLocalModelManager(bytes.length);
      addTearDown(manager.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocalAiModelSheet(
              userId: 'user-a',
              manager: manager,
              accessTokenProvider: () async => 'token',
              manifestLoader: (_) async => manifest,
              resourceLoader: () async => _enoughResources,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final checkbox = find.byType(Checkbox);
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pump();
      expect(tester.widget<Checkbox>(checkbox).value, isTrue);
      final downloadButton = find.widgetWithText(FilledButton, 'Descargar');
      await tester.ensureVisible(downloadButton);
      expect(tester.widget<FilledButton>(downloadButton).onPressed, isNotNull);
      await tester.tap(downloadButton);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Descargar'), findsNothing);
      expect(find.text('Pausar'), findsOneWidget);
      expect(manager.downloadCalls, 1);

      manager.finishDownload();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.offline_pin), findsOneWidget);
      expect(find.text('Descargar'), findsNothing);
      expect(manager.downloadCalls, 1);
    },
  );

  test(
    'pausa conserva el parcial y una nueva instancia puede reanudarlo',
    () async {
      final bytes = List<int>.generate(96, (index) => index);
      final manifest = LocalModelManifest.verified(_modelManifest(bytes));
      final directory = await Directory.systemTemp.createTemp('sw1-ai-pause-');
      addTearDown(() => directory.delete(recursive: true));
      final stream = StreamController<List<int>>();
      final first = LocalModelManager(
        userId: 'user-a',
        directoryProvider: () async => directory,
        client: _StreamClient(
          (_) async => http.StreamedResponse(stream.stream, 200),
        ),
      );
      final download = first.download(
        manifest,
        consented: true,
        resources: _enoughResources,
      );
      final firstChunkStored = first.progress.firstWhere(
        (item) => item.downloadedBytes == 32,
      );
      stream.add(bytes.sublist(0, 32));
      await firstChunkStored;
      first.pause();
      stream.add(bytes.sublist(32));
      await stream.close();
      expect(await download, isNull);
      await first.close();

      late String range;
      final second = LocalModelManager(
        userId: 'user-a',
        directoryProvider: () async => directory,
        client: MockClient((request) async {
          range = request.headers['range']!;
          return http.Response.bytes(bytes.sublist(32), 206);
        }),
      );
      addTearDown(second.close);
      final installed = await second.download(
        manifest,
        consented: true,
        resources: _enoughResources,
      );
      expect(range, 'bytes=32-');
      expect(installed?.existsSync(), isTrue);
    },
  );

  test('una actualización corrupta conserva el modelo anterior', () async {
    final previousBytes = List<int>.filled(32, 7);
    final updatedBytes = List<int>.filled(32, 9);
    final previous = LocalModelManifest.verified(_modelManifest(previousBytes));
    final updated = LocalModelManifest.verified(
      _modelManifest(updatedBytes, version: 'revision-2'),
    );
    final directory = await Directory.systemTemp.createTemp('sw1-ai-update-');
    addTearDown(() => directory.delete(recursive: true));
    final manager = LocalModelManager(
      userId: 'user-a',
      directoryProvider: () async => directory,
      client: MockClient(
        (_) async => http.Response.bytes(List<int>.filled(32, 1), 200),
      ),
    );
    addTearDown(manager.close);
    final target = await manager.modelFile(previous);
    await target.writeAsBytes(previousBytes);

    await expectLater(
      manager.download(updated, consented: true, resources: _enoughResources),
      throwsFormatException,
    );

    expect(await target.readAsBytes(), previousBytes);
    expect(await manager.verify(previous), isTrue);
  });
}

const _enoughResources = DeviceResourceProfile(
  architecture: 'android-arm64',
  ramBytes: 8 * 1024 * 1024 * 1024,
  freeStorageBytes: 8 * 1024 * 1024 * 1024,
);

Map<String, dynamic> _modelManifest(
  List<int> bytes, {
  String version = 'revision-1',
}) {
  final body = <String, dynamic>{
    'schema_version': 1,
    'id': 'test-model',
    'version': version,
    'source': 'test/source',
    'license': 'Apache-2.0',
    'file_name': 'test.gguf',
    'download_url': 'https://example.test/test.gguf',
    'byte_size': bytes.length,
    'sha256': sha256.convert(bytes).toString(),
    'context_tokens': 1024,
    'chat_template': '{prompt}',
    'minimum_profile': {
      'architecture': ['android-arm64', 'ios-arm64'],
      'ram_bytes': 1,
      'free_storage_bytes': 1,
    },
  };
  return {
    ...body,
    'manifest_checksum': sha256
        .convert(utf8.encode(canonicalJson(body)))
        .toString(),
  };
}
