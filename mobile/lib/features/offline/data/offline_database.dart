import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../ai/domain/mobile_ai.dart';
import '../../viewer/domain/viewer_models.dart';

part 'offline_database.g.dart';

class LocalAccounts extends Table {
  TextColumn get userId => text()();
  TextColumn get email => text().nullable()();
  DateTimeColumn get lastOpenedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {userId};
}

class LocalProjects extends Table {
  TextColumn get userId => text()();
  TextColumn get projectId => text()();
  TextColumn get summaryJson => text()();
  TextColumn get snapshotJson => text().nullable()();
  TextColumn get registryJson => text().nullable()();
  TextColumn get rulesJson => text().nullable()();
  IntColumn get revision => integer().withDefault(const Constant(0))();
  TextColumn get syncState => text().withDefault(const Constant('updated'))();
  BoolColumn get offlineEnabled =>
      boolean().withDefault(const Constant(false))();
  IntColumn get byteSize => integer().withDefault(const Constant(0))();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {userId, projectId};
}

class LocalRules extends Table {
  TextColumn get userId => text()();
  TextColumn get projectId => text()();
  TextColumn get version => text()();
  TextColumn get checksum => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {userId, projectId, version};
}

class LocalProposals extends Table {
  TextColumn get userId => text()();
  TextColumn get projectId => text()();
  TextColumn get proposalId => text()();
  TextColumn get payloadJson => text()();
  TextColumn get state => text().withDefault(const Constant('draft'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {userId, projectId, proposalId};
}

class LocalOperations extends Table {
  TextColumn get userId => text()();
  TextColumn get projectId => text()();
  TextColumn get operationId => text()();
  IntColumn get baseRevision => integer()();
  TextColumn get payloadJson => text()();
  TextColumn get state => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {userId, projectId, operationId};
}

class LocalConflicts extends Table {
  TextColumn get userId => text()();
  TextColumn get projectId => text()();
  TextColumn get conflictId => text()();
  TextColumn get payloadJson => text()();
  TextColumn get state => text().withDefault(const Constant('open'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {userId, projectId, conflictId};
}

class LocalManifests extends Table {
  TextColumn get userId => text()();
  TextColumn get projectId => text().withDefault(const Constant(''))();
  TextColumn get kind => text()();
  TextColumn get version => text()();
  TextColumn get checksum => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {userId, projectId, kind};
}

class LocalArtifacts extends Table {
  TextColumn get userId => text()();
  TextColumn get projectId => text()();
  TextColumn get artifactId => text()();
  TextColumn get kind => text()();
  TextColumn get path => text()();
  TextColumn get checksum => text()();
  IntColumn get byteSize => integer().withDefault(const Constant(0))();
  TextColumn get state => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {userId, projectId, artifactId};
}

class LocalInvitationDrafts extends Table {
  TextColumn get userId => text()();
  TextColumn get projectId => text()();
  TextColumn get draftId => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {userId, projectId, draftId};
}

class OfflineBundle {
  const OfflineBundle({
    required this.snapshot,
    required this.registry,
    required this.rules,
  });

  final UmlSnapshot snapshot;
  final Map<String, dynamic> registry;
  final Map<String, dynamic> rules;
}

@DriftDatabase(
  tables: [
    LocalAccounts,
    LocalProjects,
    LocalRules,
    LocalProposals,
    LocalOperations,
    LocalConflicts,
    LocalManifests,
    LocalArtifacts,
    LocalInvitationDrafts,
  ],
)
class OfflineDatabase extends _$OfflineDatabase {
  OfflineDatabase() : super(_openConnection());

  OfflineDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  Future<void> touchAccount(String userId, {String? email}) async {
    await into(localAccounts).insertOnConflictUpdate(
      LocalAccountsCompanion.insert(
        userId: userId,
        email: Value(email),
        lastOpenedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> saveProjectList(
    String userId,
    List<UmlProjectSummary> projects,
  ) async {
    await transaction(() async {
      await touchAccount(userId);
      for (final project in projects) {
        final existing = await _project(userId, project.id);
        final availableOffline = existing?.offlineEnabled ?? false;
        final storedState = viewerSyncStateFromJson(
          existing?.syncState ?? project.syncState.name,
        );
        final retainedState = switch (storedState) {
          ViewerSyncState.pending || ViewerSyncState.conflict => storedState,
          _ => ViewerSyncState.updated,
        };
        final summary = project.copyWith(
          availableOffline: availableOffline,
          syncState: retainedState,
        );
        await into(localProjects).insertOnConflictUpdate(
          LocalProjectsCompanion.insert(
            userId: userId,
            projectId: project.id,
            summaryJson: jsonEncode(summary.toJson()),
            snapshotJson: Value(existing?.snapshotJson),
            registryJson: Value(existing?.registryJson),
            rulesJson: Value(existing?.rulesJson),
            revision: Value(project.revision),
            syncState: Value(summary.syncState.name),
            offlineEnabled: Value(availableOffline),
            byteSize: Value(existing?.byteSize ?? 0),
            syncedAt: Value(existing?.syncedAt),
            updatedAt: Value(project.updatedAt),
          ),
        );
      }
    });
  }

  Future<List<UmlProjectSummary>> loadProjectList(String userId) async {
    final rows =
        await (select(localProjects)
              ..where((table) => table.userId.equals(userId))
              ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]))
            .get();
    return rows
        .map((row) {
          final summary = UmlProjectSummary.fromJson(_jsonMap(row.summaryJson));
          return summary.copyWith(
            availableOffline: row.offlineEnabled && row.snapshotJson != null,
            syncState: viewerSyncStateFromJson(row.syncState),
          );
        })
        .toList(growable: false);
  }

  Future<bool> hasSnapshot(String userId, String projectId) async {
    final row = await _project(userId, projectId);
    return row?.offlineEnabled == true && row?.snapshotJson != null;
  }

  Future<UmlSnapshot?> loadSnapshot(String userId, String projectId) async {
    final row = await _project(userId, projectId);
    if (row == null || !row.offlineEnabled || row.snapshotJson == null) {
      return null;
    }
    final summary = UmlProjectSummary.fromJson(_jsonMap(row.summaryJson));
    return UmlSnapshot.fromJson(
      _jsonMap(row.snapshotJson!),
      fallbackProject: summary,
      loadedFromOffline: true,
    );
  }

  Future<Map<String, dynamic>?> loadRegistry(
    String userId,
    String projectId,
  ) async {
    final row = await _project(userId, projectId);
    if (row == null || !row.offlineEnabled || row.registryJson == null) {
      return null;
    }
    return _jsonMap(row.registryJson);
  }

  Future<Map<String, dynamic>?> loadRules(
    String userId,
    String projectId,
  ) async {
    final row = await _project(userId, projectId);
    if (row == null || !row.offlineEnabled || row.rulesJson == null) {
      return null;
    }
    return _jsonMap(row.rulesJson);
  }

  Future<void> refreshSnapshotIfEnabled(
    String userId,
    UmlSnapshot snapshot,
  ) async {
    final existing = await _project(userId, snapshot.project.id);
    if (existing == null || !existing.offlineEnabled) return;
    await saveOfflineBundle(
      userId,
      OfflineBundle(
        snapshot: snapshot,
        registry: _jsonMap(existing.registryJson),
        rules: _jsonMap(existing.rulesJson),
      ),
    );
  }

  Future<void> saveOfflineBundle(String userId, OfflineBundle bundle) async {
    final snapshotJson = jsonEncode(bundle.snapshot.toJson());
    final registryJson = jsonEncode(bundle.registry);
    final rulesJson = jsonEncode(bundle.rules);
    final byteSize =
        utf8.encode(snapshotJson).length +
        utf8.encode(registryJson).length +
        utf8.encode(rulesJson).length;
    final syncedAt = bundle.snapshot.syncedAt ?? DateTime.now().toUtc();
    final rulesVersion = '${bundle.rules['version'] ?? 'unknown'}';
    final rulesChecksum = '${bundle.rules['checksum'] ?? ''}';
    final registryVersion = '${bundle.registry['version'] ?? 'unknown'}';

    await transaction(() async {
      await touchAccount(userId);
      final summary = bundle.snapshot.project.copyWith(
        availableOffline: true,
        syncState: ViewerSyncState.updated,
      );
      await into(localProjects).insertOnConflictUpdate(
        LocalProjectsCompanion.insert(
          userId: userId,
          projectId: summary.id,
          summaryJson: jsonEncode(summary.toJson()),
          snapshotJson: Value(snapshotJson),
          registryJson: Value(registryJson),
          rulesJson: Value(rulesJson),
          revision: Value(summary.revision),
          syncState: const Value('updated'),
          offlineEnabled: const Value(true),
          byteSize: Value(byteSize),
          syncedAt: Value(syncedAt),
          updatedAt: Value(summary.updatedAt),
        ),
      );
      await (delete(localRules)..where(
            (table) =>
                table.userId.equals(userId) &
                table.projectId.equals(summary.id),
          ))
          .go();
      await into(localRules).insert(
        LocalRulesCompanion.insert(
          userId: userId,
          projectId: summary.id,
          version: rulesVersion,
          checksum: rulesChecksum,
          payloadJson: rulesJson,
          updatedAt: Value(syncedAt),
        ),
      );
      await into(localManifests).insertOnConflictUpdate(
        LocalManifestsCompanion.insert(
          userId: userId,
          projectId: Value(summary.id),
          kind: 'uml-registry',
          version: registryVersion,
          checksum: '',
          payloadJson: registryJson,
          updatedAt: Value(syncedAt),
        ),
      );
    });
  }

  Future<void> removeOfflineBundle(String userId, String projectId) async {
    await transaction(() async {
      await (update(localProjects)..where(
            (table) =>
                table.userId.equals(userId) & table.projectId.equals(projectId),
          ))
          .write(
            const LocalProjectsCompanion(
              snapshotJson: Value(null),
              registryJson: Value(null),
              rulesJson: Value(null),
              offlineEnabled: Value(false),
              byteSize: Value(0),
              syncedAt: Value(null),
              syncState: Value('updated'),
            ),
          );
      await (delete(localRules)..where(
            (table) =>
                table.userId.equals(userId) & table.projectId.equals(projectId),
          ))
          .go();
      await (delete(localManifests)..where(
            (table) =>
                table.userId.equals(userId) & table.projectId.equals(projectId),
          ))
          .go();
    });
  }

  Future<int> projectBytes(String userId) async {
    final expression = localProjects.byteSize.sum();
    final query = selectOnly(localProjects)
      ..addColumns([expression])
      ..where(localProjects.userId.equals(userId));
    return (await query.getSingle()).read(expression) ?? 0;
  }

  Future<void> saveLocalProposal(
    String userId,
    String projectId,
    MobileAiResponse proposal,
  ) async {
    await into(localProposals).insertOnConflictUpdate(
      LocalProposalsCompanion.insert(
        userId: userId,
        projectId: projectId,
        proposalId: proposal.id,
        payloadJson: jsonEncode(proposal.toJson()),
        state: const Value('ready'),
      ),
    );
  }

  Future<UmlSnapshot> confirmLocalProposal({
    required String userId,
    required String projectId,
    required MobileAiResponse proposal,
    required Iterable<String> selectedOperationIds,
  }) async {
    if (!proposal.canConfirm) {
      throw StateError('La propuesta contiene preguntas o errores pendientes.');
    }
    final selected = selectedOperationIds.toSet();
    final operations = proposal.operations
        .where((item) => selected.isEmpty || selected.contains(item.id))
        .toList(growable: false);
    if (operations.isEmpty) {
      throw StateError('No hay operaciones seleccionadas.');
    }
    final known = operations.map((item) => item.id).toSet();
    for (final operation in operations) {
      final missing = operation.dependsOn.where(
        (dependency) => !known.contains(dependency),
      );
      if (missing.isNotEmpty) {
        throw StateError('Falta una operación requerida por ${operation.id}.');
      }
    }

    return transaction(() async {
      final row = await _project(userId, projectId);
      if (row == null || row.snapshotJson == null || !row.offlineEnabled) {
        throw StateError('El proyecto no está disponible sin conexión.');
      }
      var snapshotMap = _jsonMap(row.snapshotJson);
      final alreadyStored = <String>{};
      for (final operation in operations) {
        final existing =
            await (select(localOperations)..where(
                  (table) =>
                      table.userId.equals(userId) &
                      table.projectId.equals(projectId) &
                      table.operationId.equals(operation.id),
                ))
                .getSingleOrNull();
        if (existing != null) {
          alreadyStored.add(operation.id);
          continue;
        }
        // La operación durable se inserta antes de tocar la proyección local.
        await into(localOperations).insert(
          LocalOperationsCompanion.insert(
            userId: userId,
            projectId: projectId,
            operationId: operation.id,
            baseRevision: row.revision,
            payloadJson: jsonEncode({
              'operation_id': operation.id,
              'origin': 'ai',
              'entity_type': operation.entityType,
              'entity_id': operation.entityId,
              'action': operation.action,
              'path': operation.path,
              'base_revision': row.revision,
              'new_value': operation.value,
            }),
            state: const Value('pending'),
          ),
        );
        snapshotMap = _projectOperation(snapshotMap, operation);
      }
      if (alreadyStored.length != operations.length) {
        final projected = UmlSnapshot.fromJson(
          snapshotMap,
          loadedFromOffline: true,
        );
        final pendingProject = projected.project.copyWith(
          availableOffline: true,
          syncState: ViewerSyncState.pending,
        );
        snapshotMap = {
          ...snapshotMap,
          'project': pendingProject.toJson(),
          'payload': {
            ..._dynamicMap(snapshotMap['payload']),
            'project': pendingProject.toJson(),
          },
        };
        await (update(localProjects)..where(
              (table) =>
                  table.userId.equals(userId) &
                  table.projectId.equals(projectId),
            ))
            .write(
              LocalProjectsCompanion(
                snapshotJson: Value(jsonEncode(snapshotMap)),
                summaryJson: Value(jsonEncode(pendingProject.toJson())),
                syncState: const Value('pending'),
                updatedAt: Value(DateTime.now().toUtc()),
              ),
            );
      }
      await into(localProposals).insertOnConflictUpdate(
        LocalProposalsCompanion.insert(
          userId: userId,
          projectId: projectId,
          proposalId: proposal.id.isEmpty ? const Uuid().v4() : proposal.id,
          payloadJson: jsonEncode(proposal.toJson()),
          state: const Value('accepted'),
        ),
      );
      final updated = await _project(userId, projectId);
      return UmlSnapshot.fromJson(
        _jsonMap(updated!.snapshotJson),
        fallbackProject: UmlProjectSummary.fromJson(
          _jsonMap(updated.summaryJson),
        ),
        loadedFromOffline: true,
      );
    });
  }

  Future<List<Map<String, dynamic>>> pendingOperations(
    String userId,
    String projectId,
  ) async {
    final rows =
        await (select(localOperations)
              ..where(
                (table) =>
                    table.userId.equals(userId) &
                    table.projectId.equals(projectId) &
                    table.state.equals('pending'),
              )
              ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]))
            .get();
    return rows.map((row) => _jsonMap(row.payloadJson)).toList(growable: false);
  }

  Future<LocalProject?> _project(String userId, String projectId) {
    return (select(localProjects)..where(
          (table) =>
              table.userId.equals(userId) & table.projectId.equals(projectId),
        ))
        .getSingleOrNull();
  }
}

Map<String, dynamic> _projectOperation(
  Map<String, dynamic> snapshot,
  MobileAiOperation operation,
) {
  final result = jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
  final payload = _dynamicMap(result['payload']).isNotEmpty
      ? _dynamicMap(result['payload'])
      : result;
  final collectionKey = switch (operation.entityType) {
    'UmlPackage' => 'packages',
    'UmlElement' => 'elements',
    'UmlRelationship' => 'relationships',
    'Diagram' => 'diagrams',
    'DiagramNode' => 'diagram_nodes',
    'DiagramEdge' => 'diagram_edges',
    _ => throw StateError('Entidad local no compatible.'),
  };
  final items =
      (payload[collectionKey] is List
              ? List<Object?>.from(payload[collectionKey] as List)
              : <Object?>[])
          .whereType<Map>()
          .map(_dynamicMap)
          .toList();
  final entityId = operation.entityId ?? '${operation.value['id'] ?? ''}';
  if (operation.action != 'create' && entityId.isEmpty) {
    throw StateError('La operación requiere entity_id.');
  }
  final index = items.indexWhere((item) => '${item['id']}' == entityId);
  switch (operation.action) {
    case 'create':
      final id = entityId.isEmpty ? const Uuid().v4() : entityId;
      if (!items.any((item) => '${item['id']}' == id)) {
        items.add({'id': id, ...operation.value});
      }
      break;
    case 'update':
      if (index < 0) throw StateError('La entidad a actualizar no existe.');
      items[index] = {...items[index], ...operation.value, 'id': entityId};
      break;
    case 'delete':
      if (index >= 0) items.removeAt(index);
      break;
  }
  payload[collectionKey] = items;
  if (operation.entityType == 'UmlElement' && operation.action == 'delete') {
    final relationships = (payload['relationships'] as List? ?? const [])
        .whereType<Map>()
        .map(_dynamicMap)
        .where(
          (item) =>
              '${item['source'] ?? item['source_id']}' != entityId &&
              '${item['target'] ?? item['target_id']}' != entityId,
        )
        .toList();
    payload['relationships'] = relationships;
    payload['diagram_nodes'] = (payload['diagram_nodes'] as List? ?? const [])
        .whereType<Map>()
        .map(_dynamicMap)
        .where((item) => '${item['element'] ?? item['element_id']}' != entityId)
        .toList();
  }
  result['payload'] = payload;
  return result;
}

LazyDatabase _openConnection() => LazyDatabase(() async {
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  final file = File(
    '${directory.path}${Platform.pathSeparator}uml_companion.sqlite',
  );
  return NativeDatabase.createInBackground(file);
});

Map<String, dynamic> _jsonMap(String? raw) {
  if (raw == null || raw.isEmpty) return const {};
  final decoded = jsonDecode(raw);
  return decoded is Map
      ? decoded.map((key, value) => MapEntry('$key', value))
      : const {};
}

Map<String, dynamic> _dynamicMap(Object? value) => value is Map
    ? value.map((key, value) => MapEntry('$key', value))
    : <String, dynamic>{};
