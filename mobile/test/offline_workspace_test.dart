import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/data/models/auth_user.dart';
import 'package:mobile/features/home/presentation/pages/home_page.dart';
import 'package:mobile/features/offline/data/connectivity_service.dart';
import 'package:mobile/features/offline/data/drift_viewer_replica_store.dart';
import 'package:mobile/features/offline/data/offline_database.dart';
import 'package:mobile/features/viewer/data/viewer_repository.dart';
import 'package:mobile/features/viewer/domain/viewer_models.dart';

const _project = UmlProjectSummary(
  id: 'project-1',
  name: 'Proyecto offline',
  access: ProjectAccess.editor,
  updatedAt: null,
  revision: 3,
);

UmlSnapshot _snapshot() => UmlSnapshot(
  project: _project,
  diagrams: const [UmlDiagram(id: 'diagram-1', name: 'Clases', type: 'class')],
  elements: const [
    UmlElement(id: 'element-1', name: 'Pedido', metaclass: 'Class'),
  ],
  relationships: const [],
  nodes: const [
    UmlDiagramNode(
      id: 'node-1',
      diagramId: 'diagram-1',
      elementId: 'element-1',
      bounds: Rect.fromLTWH(10, 10, 180, 90),
    ),
  ],
  edges: const [],
  loadedFromOffline: false,
  syncedAt: DateTime.utc(2026, 9, 15, 12, 30),
);

const _registry = <String, dynamic>{
  'version': 'uml-2.5.1-subset-2',
  'diagram_types': ['class'],
};

const _rules = <String, dynamic>{
  'version': 'uml-expert-rules-1',
  'registry_version': 'uml-2.5.1-subset-2',
  'checksum': 'abc123',
  'rules': [],
};

class _OfflineRepository
    implements ViewerRepository, OfflineCapableViewerRepository {
  _OfflineRepository({this.offlineGate});

  final Completer<void>? offlineGate;
  UmlProjectSummary project = _project;
  final connectivity = StreamController<MobileConnectivityState>.broadcast();

  @override
  Future<List<UmlProjectSummary>> loadProjects({bool refresh = true}) async => [
    project,
  ];

  @override
  Future<UmlSnapshot> loadSnapshot(
    UmlProjectSummary project, {
    bool preferRemote = true,
  }) async => _snapshot();

  @override
  Stream<int> watchRemoteRevisions(String projectId) => const Stream.empty();

  @override
  Future<UmlProjectSummary> setOfflineAvailability(
    UmlProjectSummary project,
    bool enabled,
  ) async {
    await offlineGate?.future;
    this.project = project.copyWith(availableOffline: enabled);
    return this.project;
  }

  @override
  Future<int> offlineProjectBytes() async => 512;

  @override
  Stream<MobileConnectivityState> watchConnectivity() async* {
    yield MobileConnectivityState.online;
    yield* connectivity.stream;
  }

  @override
  Future<void> close() async {
    await connectivity.close();
  }
}

class _OfflineConnectivity implements ConnectivityService {
  @override
  Future<MobileConnectivityState> current() async =>
      MobileConnectivityState.offline;

  @override
  Stream<MobileConnectivityState> watch() =>
      Stream.value(MobileConnectivityState.offline);
}

class _OnlineConnectivity implements ConnectivityService {
  @override
  Future<MobileConnectivityState> current() async =>
      MobileConnectivityState.online;

  @override
  Stream<MobileConnectivityState> watch() =>
      Stream.value(MobileConnectivityState.online);
}

class _FailIfCalledApiClient extends ApiClient {
  int calls = 0;

  @override
  Future<http.Response> get(
    String path, {
    String? accessToken,
    Duration? timeout,
  }) async {
    calls += 1;
    throw StateError('No debe acceder a la red en modo offline.');
  }
}

void main() {
  test('la réplica Drift aísla proyectos y snapshots por usuario', () async {
    final database = OfflineDatabase.forTesting(NativeDatabase.memory());
    final store = DriftViewerReplicaStore(database: database);
    addTearDown(database.close);

    await store.saveProjects('user-a', const [_project]);
    await store.saveProjects('user-b', const [
      UmlProjectSummary(
        id: 'project-2',
        name: 'Proyecto privado',
        access: ProjectAccess.owner,
        updatedAt: null,
        revision: 1,
      ),
    ]);
    await store.saveOfflineBundle('user-a', _snapshot(), _registry, _rules);

    expect((await store.loadProjects('user-a')).single.id, 'project-1');
    expect((await store.loadProjects('user-b')).single.id, 'project-2');
    expect(await store.hasSnapshot('user-a', 'project-1'), isTrue);
    expect(await store.hasSnapshot('user-b', 'project-1'), isFalse);
    expect(await store.loadSnapshot('user-b', 'project-1'), isNull);
    await store.close();
    expect(() => store.loadProjects('user-a'), throwsA(isA<StateError>()));
  });

  test('la réplica conserva estados pendiente y conflicto', () async {
    final database = OfflineDatabase.forTesting(NativeDatabase.memory());
    final store = DriftViewerReplicaStore(database: database);
    addTearDown(database.close);

    await store.saveProjects('user-a', const [
      UmlProjectSummary(
        id: 'pending',
        name: 'Pendiente',
        access: ProjectAccess.editor,
        updatedAt: null,
        revision: 2,
        syncState: ViewerSyncState.pending,
      ),
      UmlProjectSummary(
        id: 'conflict',
        name: 'Conflicto',
        access: ProjectAccess.editor,
        updatedAt: null,
        revision: 4,
        syncState: ViewerSyncState.conflict,
      ),
    ]);

    final states = {
      for (final project in await store.loadProjects('user-a'))
        project.id: project.syncState,
    };
    expect(states['pending'], ViewerSyncState.pending);
    expect(states['conflict'], ViewerSyncState.conflict);

    final repository = MobileViewerRepository(
      userId: 'user-a',
      apiClient: _FailIfCalledApiClient(),
      accessTokenProvider: () async => 'token',
      replicaStore: store,
      connectivityService: _OfflineConnectivity(),
    );
    final cached = {
      for (final project in await repository.loadProjects())
        project.id: project.syncState,
    };
    expect(cached['pending'], ViewerSyncState.pending);
    expect(cached['conflict'], ViewerSyncState.conflict);
  });

  test(
    'guardar y eliminar el bundle offline es atómico e idempotente',
    () async {
      final database = OfflineDatabase.forTesting(NativeDatabase.memory());
      final store = DriftViewerReplicaStore(database: database);
      addTearDown(database.close);

      await store.saveOfflineBundle('user-a', _snapshot(), _registry, _rules);
      await store.saveOfflineBundle('user-a', _snapshot(), _registry, _rules);

      final restored = await store.loadSnapshot('user-a', 'project-1');
      expect(restored, isNotNull);
      expect(restored!.loadedFromOffline, isTrue);
      expect(restored.project.revision, 3);
      expect(restored.elements.single.name, 'Pedido');
      expect(
        (await store.loadRegistry('user-a', 'project-1'))?['version'],
        'uml-2.5.1-subset-2',
      );
      expect(
        (await store.loadRules('user-a', 'project-1'))?['version'],
        'uml-expert-rules-1',
      );
      expect(await store.projectBytes('user-a'), greaterThan(0));

      await store.removeOfflineBundle('user-a', 'project-1');
      expect(await store.hasSnapshot('user-a', 'project-1'), isFalse);
      expect(await store.loadSnapshot('user-a', 'project-1'), isNull);
      expect(await store.projectBytes('user-a'), 0);
    },
  );

  test('modo offline abre la réplica sin iniciar llamadas remotas', () async {
    final database = OfflineDatabase.forTesting(NativeDatabase.memory());
    final store = DriftViewerReplicaStore(database: database);
    final apiClient = _FailIfCalledApiClient();
    addTearDown(database.close);
    await store.saveOfflineBundle('user-a', _snapshot(), _registry, _rules);
    final repository = MobileViewerRepository(
      userId: 'user-a',
      apiClient: apiClient,
      accessTokenProvider: () async => 'token',
      replicaStore: store,
      connectivityService: _OfflineConnectivity(),
    );

    final restored = await repository.loadSnapshot(_project);

    expect(restored.loadedFromOffline, isTrue);
    expect(apiClient.calls, 0);
  });

  test(
    'preparar offline guarda snapshot, registro y reglas compatibles',
    () async {
      final database = OfflineDatabase.forTesting(NativeDatabase.memory());
      final store = DriftViewerReplicaStore(database: database);
      addTearDown(database.close);
      final client = MockClient((request) async {
        final path = request.url.path;
        final payload = switch (path) {
          '/api/modeling/projects/project-1/' => _project.toJson(),
          '/api/modeling/projects/project-1/diagrams/' => [
            {'id': 'diagram-1', 'name': 'Clases', 'diagram_type': 'class'},
          ],
          '/api/modeling/projects/project-1/elements/' => [
            {'id': 'element-1', 'name': 'Pedido', 'metaclass': 'Class'},
          ],
          '/api/modeling/projects/project-1/relationships/' => <Object>[],
          '/api/modeling/projects/project-1/diagrams/diagram-1/nodes/' => [
            {
              'id': 'node-1',
              'diagram': 'diagram-1',
              'element': 'element-1',
              'x': 10,
              'y': 10,
              'width': 180,
              'height': 90,
            },
          ],
          '/api/modeling/projects/project-1/diagrams/diagram-1/edges/' =>
            <Object>[],
          '/api/modeling/registry/' => _registry,
          '/api/modeling/expert-rules/' => _rules,
          _ => throw StateError('Ruta inesperada: $path'),
        };
        return http.Response(jsonEncode(payload), 200);
      });
      final repository = MobileViewerRepository(
        userId: 'user-a',
        apiClient: ApiClient(client: client, baseUrl: 'http://test'),
        accessTokenProvider: () async => 'token',
        replicaStore: store,
        connectivityService: _OnlineConnectivity(),
      );

      final prepared = await repository.setOfflineAvailability(_project, true);

      expect(prepared.availableOffline, isTrue);
      expect(await store.hasSnapshot('user-a', 'project-1'), isTrue);
      expect(
        (await store.loadRules('user-a', 'project-1'))?['checksum'],
        'abc123',
      );
    },
  );

  testWidgets('inicio permite preparar y eliminar una copia offline', (
    tester,
  ) async {
    final repository = _OfflineRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          user: const AuthUser(
            id: 1,
            firstName: 'Ana',
            lastName: 'Pérez',
            email: 'ana@example.com',
          ),
          viewerRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('offline-project-1')));
    await tester.pumpAndSettle();
    expect(repository.project.availableOffline, isTrue);
    expect(find.textContaining('disponible sin conexión'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('offline-project-1')));
    await tester.pumpAndSettle();
    expect(repository.project.availableOffline, isFalse);
  });

  testWidgets('inicio refleja pérdida y recuperación de conectividad', (
    tester,
  ) async {
    final repository = _OfflineRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          user: const AuthUser(
            id: 1,
            firstName: 'Ana',
            lastName: 'Pérez',
            email: 'ana@example.com',
          ),
          viewerRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('connectivity-online')), findsOneWidget);

    repository.connectivity.add(MobileConnectivityState.offline);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('connectivity-offline')), findsOneWidget);

    repository.connectivity.add(MobileConnectivityState.online);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('connectivity-online')), findsOneWidget);
  });

  testWidgets('preparación offline expone el estado sincronizando', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repository = _OfflineRepository(offlineGate: gate);
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          user: const AuthUser(
            id: 1,
            firstName: 'Ana',
            lastName: 'Pérez',
            email: 'ana@example.com',
          ),
          viewerRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('offline-project-1')));
    await tester.pump();
    expect(find.text('Sincronizando'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Actualizado'), findsOneWidget);
  });
}
