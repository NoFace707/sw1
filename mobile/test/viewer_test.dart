import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/auth/data/models/auth_user.dart';
import 'package:mobile/features/home/presentation/pages/home_page.dart';
import 'package:mobile/features/viewer/data/viewer_repository.dart';
import 'package:mobile/features/viewer/domain/viewer_models.dart';
import 'package:mobile/features/viewer/presentation/pages/uml_viewer_page.dart';
import 'package:mobile/features/viewer/presentation/widgets/uml_notation.dart';

const project = UmlProjectSummary(
  id: 'project-1',
  name: 'Comercio',
  access: ProjectAccess.editor,
  updatedAt: null,
  revision: 12,
);

const diagramTypes = <String>[
  'class',
  'object',
  'component',
  'composite_structure',
  'package',
  'deployment',
  'profile',
  'use_case',
  'activity',
  'state_machine',
  'sequence',
  'communication',
  'interaction_overview',
  'timing',
];

const metaclasses = <String>[
  'Class',
  'Object',
  'Component',
  'Port',
  'Package',
  'Node',
  'Profile',
  'UseCase',
  'Action',
  'State',
  'Lifeline',
  'Interaction',
  'DecisionNode',
  'TimeObservation',
];

UmlSnapshot fixture({ViewerSyncState state = ViewerSyncState.updated}) {
  final diagrams = <UmlDiagram>[];
  final elements = <UmlElement>[];
  final nodes = <UmlDiagramNode>[];
  for (var index = 0; index < diagramTypes.length; index++) {
    diagrams.add(
      UmlDiagram(
        id: 'diagram-$index',
        name: 'Diagrama $index',
        type: diagramTypes[index],
      ),
    );
    elements.add(
      UmlElement(
        id: 'element-$index',
        name: index == 0 ? 'Pedido' : 'Elemento $index',
        metaclass: metaclasses[index],
        mdaLevel: 'PIM',
        properties: index == 0
            ? const {
                'attributes': ['id: UUID', 'total: Decimal'],
              }
            : const {},
      ),
    );
    nodes.add(
      UmlDiagramNode(
        id: 'node-$index',
        diagramId: 'diagram-$index',
        elementId: 'element-$index',
        bounds: const Rect.fromLTWH(80, 60, 180, 96),
      ),
    );
  }
  elements.add(
    const UmlElement(
      id: 'unknown',
      name: 'Extensión',
      metaclass: 'VendorWidget',
      properties: {'vendor': 'safe'},
    ),
  );
  nodes.add(
    const UmlDiagramNode(
      id: 'unknown-node',
      diagramId: 'diagram-0',
      elementId: 'unknown',
      bounds: Rect.fromLTWH(360, 190, 180, 96),
    ),
  );
  nodes.add(
    const UmlDiagramNode(
      id: 'second-representation',
      diagramId: 'diagram-1',
      elementId: 'element-0',
      bounds: Rect.fromLTWH(330, 80, 180, 96),
    ),
  );
  return UmlSnapshot(
    project: project.copyWith(syncState: state),
    diagrams: diagrams,
    elements: elements,
    relationships: const [
      UmlRelationship(
        id: 'relationship-1',
        type: 'Dependency',
        sourceId: 'element-0',
        targetId: 'unknown',
      ),
    ],
    nodes: nodes,
    edges: const [
      UmlDiagramEdge(
        id: 'edge-1',
        diagramId: 'diagram-0',
        sourceNodeId: 'node-0',
        targetNodeId: 'unknown-node',
        relationshipId: 'relationship-1',
      ),
    ],
    loadedFromOffline: state == ViewerSyncState.offline,
  );
}

class FakeViewerRepository implements ViewerRepository {
  FakeViewerRepository(this.snapshot);
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

class UnavailableViewerRepository implements ViewerRepository {
  @override
  Future<List<UmlProjectSummary>> loadProjects({bool refresh = true}) async => [
    project,
  ];

  @override
  Future<UmlSnapshot> loadSnapshot(
    UmlProjectSummary project, {
    bool preferRemote = true,
  }) {
    throw const ViewerRepositoryException(
      'Este proyecto no fue preparado para uso sin conexión.',
      offlineCopyMissing: true,
    );
  }

  @override
  Stream<int> watchRemoteRevisions(String projectId) => const Stream.empty();
}

void main() {
  test('reconoce todas las figuras visuales aceptadas por el backend', () {
    for (final entry in supportedVisualShapes.entries) {
      for (final shape in entry.value) {
        final node = UmlDiagramNode(
          id: '${entry.key}-$shape',
          diagramId: 'diagram-0',
          elementId: null,
          bounds: const Rect.fromLTWH(0, 0, 180, 100),
          properties: {
            'kind': 'visual',
            'library': entry.key,
            'shape': shape,
            'label': shape,
          },
        );
        expect(isSupportedVisualNode(node), isTrue, reason: node.id);
      }
    }
  });

  testWidgets('cilindro, nota y texto se muestran como figuras compatibles', (
    tester,
  ) async {
    const shapes = ['cylinder', 'note', 'text'];
    await tester.binding.setSurfaceSize(const Size(620, 150));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: const ValueKey('visual-shapes-golden'),
            child: ColoredBox(
              color: Colors.white,
              child: Row(
                children: [
                  for (final shape in shapes)
                    SizedBox(
                      width: 200,
                      height: 130,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: UmlNodeView(
                          node: UmlDiagramNode(
                            id: 'visual-$shape',
                            diagramId: 'diagram-0',
                            elementId: null,
                            bounds: const Rect.fromLTWH(0, 0, 180, 110),
                            properties: {
                              'kind': 'visual',
                              'library': 'general',
                              'shape': shape,
                              'label': shape == 'text'
                                  ? 'Texto libre'
                                  : shape == 'note'
                                  ? 'Nota'
                                  : 'Base de datos',
                              'style': {
                                'fill': '#f8fafc',
                                'stroke': '#475569',
                                'strokeWidth': 2,
                                'fontSize': 14,
                                'textColor': '#0f172a',
                              },
                            },
                          ),
                          element: null,
                          diagramType: 'class',
                          selected: false,
                          onTap: () {},
                          onLongPress: () {},
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Notación no compatible'), findsNothing);
    await expectLater(
      find.byKey(const ValueKey('visual-shapes-golden')),
      matchesGoldenFile('goldens/visual_shapes.png'),
    );
  });

  test(
    'snapshot conserva los catorce tipos y metaclases desconocidas en round-trip',
    () {
      final original = fixture();
      final restored = UmlSnapshot.fromJson(
        original.toJson(),
        fallbackProject: project,
        loadedFromOffline: true,
      );
      expect(
        restored.diagrams.map((item) => item.type).toSet(),
        diagramTypes.toSet(),
      );
      expect(restored.elementById('unknown')?.properties, {'vendor': 'safe'});
      expect(
        restored.nodesFor('diagram-0').map((item) => item.id),
        contains('unknown-node'),
      );
      expect(restored.loadedFromOffline, isTrue);
    },
  );

  testWidgets(
    'notaciones de las cuatro familias mantienen una baseline visual',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final snapshot = fixture();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: const ValueKey('notation-golden'),
              child: ColoredBox(
                color: Colors.white,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.9,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: diagramTypes.length,
                  itemBuilder: (context, index) => UmlNodeView(
                    node: snapshot.nodes[index],
                    element: snapshot.elements[index],
                    diagramType: diagramTypes[index],
                    selected: false,
                    onTap: () {},
                    onLongPress: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byKey(const ValueKey('notation-golden')),
        matchesGoldenFile('goldens/uml_notations.png'),
      );
    },
  );

  testWidgets(
    'visor navega sin alterar geometría y expone inspector y marcador desconocido',
    (tester) async {
      final snapshot = fixture();
      final before = snapshot.nodes.map((node) => node.bounds).toList();
      await tester.pumpWidget(
        MaterialApp(
          home: UmlViewerPage(
            project: project,
            repository: FakeViewerRepository(snapshot),
            initialSnapshot: snapshot,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('read-only-interactive-viewer')),
        findsOneWidget,
      );
      expect(find.text('Notación no compatible'), findsOneWidget);
      expect(find.text('Revisión 12'), findsOneWidget);
      expect(find.text('Actualizado'), findsOneWidget);

      await tester.drag(
        find.byKey(const ValueKey('read-only-interactive-viewer')),
        const Offset(80, 45),
      );
      await tester.pump();
      expect(snapshot.nodes.map((node) => node.bounds).toList(), before);

      await tester.tap(find.byKey(const ValueKey('uml-node-node-0')));
      await tester.pumpAndSettle();
      expect(find.text('Nivel MDA: PIM'), findsOneWidget);
      expect(find.textContaining('Solo lectura'), findsOneWidget);
    },
  );

  testWidgets(
    'búsqueda por nombre centra una representación en otro diagrama',
    (tester) async {
      final snapshot = fixture();
      await tester.pumpWidget(
        MaterialApp(
          home: UmlViewerPage(
            project: project,
            repository: FakeViewerRepository(snapshot),
            initialSnapshot: snapshot,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('viewer-search')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'Pedido');
      await tester.pumpAndSettle();
      expect(find.textContaining('Diagrama 1'), findsOneWidget);
      await tester.tap(find.textContaining('Diagrama 1'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('uml-node-second-representation')),
        findsOneWidget,
      );
    },
  );

  testWidgets('estado offline se distingue de una edición local pendiente', (
    tester,
  ) async {
    final snapshot = fixture(state: ViewerSyncState.offline);
    await tester.pumpWidget(
      MaterialApp(
        home: UmlViewerPage(
          project: project,
          repository: FakeViewerRepository(snapshot),
          initialSnapshot: snapshot,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Pendiente'), findsNothing);
  });

  testWidgets('explica cuando no existe una réplica local preparada', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UmlViewerPage(
          project: project,
          repository: UnavailableViewerRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Este proyecto no fue preparado para uso sin conexión.'),
      findsOneWidget,
    );
  });

  testWidgets('inicio busca y abre un proyecto autorizado', (tester) async {
    final snapshot = fixture();
    final repository = FakeViewerRepository(snapshot);
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
    expect(find.text('Comercio'), findsOneWidget);
    expect(find.text('Editor'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('project-search')),
      'Comercio',
    );
    await tester.tap(find.byKey(const ValueKey('project-project-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('uml-viewer-page')), findsOneWidget);
  });

  testWidgets('una revisión remota se anuncia sin marcarla pendiente local', (
    tester,
  ) async {
    final snapshot = fixture();
    final revisions = StreamController<int>();
    addTearDown(revisions.close);
    await tester.pumpWidget(
      MaterialApp(
        home: UmlViewerPage(
          project: project,
          repository: FakeViewerRepository(snapshot),
          initialSnapshot: snapshot,
          remoteRevisions: revisions.stream,
        ),
      ),
    );
    await tester.pumpAndSettle();
    revisions.add(13);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('remote-revision-notice')),
      findsOneWidget,
    );
    expect(find.textContaining('No es una edición local'), findsOneWidget);
    expect(find.text('Pendiente'), findsNothing);
  });
}
