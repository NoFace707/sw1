import '../../viewer/domain/viewer_models.dart';
import '../../ai/domain/mobile_ai.dart';

abstract class ViewerReplicaStore {
  Future<List<UmlProjectSummary>> loadProjects(String userId);
  Future<void> saveProjects(String userId, List<UmlProjectSummary> projects);
  Future<bool> hasSnapshot(String userId, String projectId);
  Future<UmlSnapshot?> loadSnapshot(String userId, String projectId);
  Future<Map<String, dynamic>?> loadRegistry(String userId, String projectId);
  Future<Map<String, dynamic>?> loadRules(String userId, String projectId);
  Future<void> saveSnapshot(String userId, UmlSnapshot snapshot);
  Future<void> saveOfflineBundle(
    String userId,
    UmlSnapshot snapshot,
    Map<String, dynamic> registry,
    Map<String, dynamic> rules,
  );
  Future<void> removeOfflineBundle(String userId, String projectId);
  Future<int> projectBytes(String userId);
  Future<void> saveLocalProposal(
    String userId,
    String projectId,
    MobileAiResponse proposal,
  );
  Future<UmlSnapshot> confirmLocalProposal(
    String userId,
    String projectId,
    MobileAiResponse proposal,
    Iterable<String> selectedOperationIds,
  );
  Future<List<Map<String, dynamic>>> pendingOperations(
    String userId,
    String projectId,
  );
  Future<void> close();
}

class EmptyViewerReplicaStore implements ViewerReplicaStore {
  const EmptyViewerReplicaStore();

  @override
  Future<bool> hasSnapshot(String userId, String projectId) async => false;

  @override
  Future<List<UmlProjectSummary>> loadProjects(String userId) async => const [];

  @override
  Future<UmlSnapshot?> loadSnapshot(String userId, String projectId) async =>
      null;

  @override
  Future<Map<String, dynamic>?> loadRegistry(
    String userId,
    String projectId,
  ) async => null;

  @override
  Future<Map<String, dynamic>?> loadRules(
    String userId,
    String projectId,
  ) async => null;

  @override
  Future<void> saveProjects(
    String userId,
    List<UmlProjectSummary> projects,
  ) async {}

  @override
  Future<void> saveSnapshot(String userId, UmlSnapshot snapshot) async {}

  @override
  Future<void> saveOfflineBundle(
    String userId,
    UmlSnapshot snapshot,
    Map<String, dynamic> registry,
    Map<String, dynamic> rules,
  ) async {}

  @override
  Future<void> removeOfflineBundle(String userId, String projectId) async {}

  @override
  Future<int> projectBytes(String userId) async => 0;

  @override
  Future<void> saveLocalProposal(
    String userId,
    String projectId,
    MobileAiResponse proposal,
  ) async {}

  @override
  Future<UmlSnapshot> confirmLocalProposal(
    String userId,
    String projectId,
    MobileAiResponse proposal,
    Iterable<String> selectedOperationIds,
  ) => throw StateError('No hay almacenamiento offline.');

  @override
  Future<List<Map<String, dynamic>>> pendingOperations(
    String userId,
    String projectId,
  ) async => const [];

  @override
  Future<void> close() async {}
}
