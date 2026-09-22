import '../../viewer/domain/viewer_models.dart';
import '../../ai/domain/mobile_ai.dart';
import 'offline_database.dart';
import '../domain/viewer_replica_store.dart';

class DriftViewerReplicaStore implements ViewerReplicaStore {
  static OfflineDatabase? _sharedDatabase;

  DriftViewerReplicaStore({OfflineDatabase? database})
    : database = database ?? (_sharedDatabase ??= OfflineDatabase());

  final OfflineDatabase database;
  bool _closed = false;

  void _ensureOpen() {
    if (_closed) throw StateError('El repositorio offline ya fue cerrado.');
  }

  @override
  Future<bool> hasSnapshot(String userId, String projectId) {
    _ensureOpen();
    return database.hasSnapshot(userId, projectId);
  }

  @override
  Future<List<UmlProjectSummary>> loadProjects(String userId) {
    _ensureOpen();
    return database.loadProjectList(userId);
  }

  @override
  Future<UmlSnapshot?> loadSnapshot(String userId, String projectId) {
    _ensureOpen();
    return database.loadSnapshot(userId, projectId);
  }

  @override
  Future<Map<String, dynamic>?> loadRegistry(String userId, String projectId) {
    _ensureOpen();
    return database.loadRegistry(userId, projectId);
  }

  @override
  Future<Map<String, dynamic>?> loadRules(String userId, String projectId) {
    _ensureOpen();
    return database.loadRules(userId, projectId);
  }

  @override
  Future<void> saveProjects(String userId, List<UmlProjectSummary> projects) {
    _ensureOpen();
    return database.saveProjectList(userId, projects);
  }

  @override
  Future<void> saveSnapshot(String userId, UmlSnapshot snapshot) {
    _ensureOpen();
    return database.refreshSnapshotIfEnabled(userId, snapshot);
  }

  @override
  Future<void> saveOfflineBundle(
    String userId,
    UmlSnapshot snapshot,
    Map<String, dynamic> registry,
    Map<String, dynamic> rules,
  ) {
    _ensureOpen();
    return database.saveOfflineBundle(
      userId,
      OfflineBundle(snapshot: snapshot, registry: registry, rules: rules),
    );
  }

  @override
  Future<void> removeOfflineBundle(String userId, String projectId) {
    _ensureOpen();
    return database.removeOfflineBundle(userId, projectId);
  }

  @override
  Future<int> projectBytes(String userId) {
    _ensureOpen();
    return database.projectBytes(userId);
  }

  @override
  Future<void> saveLocalProposal(
    String userId,
    String projectId,
    MobileAiResponse proposal,
  ) {
    _ensureOpen();
    return database.saveLocalProposal(userId, projectId, proposal);
  }

  @override
  Future<UmlSnapshot> confirmLocalProposal(
    String userId,
    String projectId,
    MobileAiResponse proposal,
    Iterable<String> selectedOperationIds,
  ) {
    _ensureOpen();
    return database.confirmLocalProposal(
      userId: userId,
      projectId: projectId,
      proposal: proposal,
      selectedOperationIds: selectedOperationIds,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> pendingOperations(
    String userId,
    String projectId,
  ) {
    _ensureOpen();
    return database.pendingOperations(userId, projectId);
  }

  @override
  Future<void> close() async {
    _closed = true;
  }
}
