import 'dart:convert';
import 'dart:io';

import '../../../core/auth/auth_session_manager.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../domain/viewer_models.dart';

abstract class ViewerRepository {
  Future<List<UmlProjectSummary>> loadProjects({bool refresh = true});

  Future<UmlSnapshot> loadSnapshot(
    UmlProjectSummary project, {
    bool preferRemote = true,
  });

  Stream<int> watchRemoteRevisions(String projectId) => const Stream.empty();
}

abstract class ViewerReplicaStore {
  Future<List<UmlProjectSummary>> loadProjects(String userId);
  Future<void> saveProjects(String userId, List<UmlProjectSummary> projects);
  Future<bool> hasSnapshot(String userId, String projectId);
  Future<UmlSnapshot?> loadSnapshot(String userId, String projectId);
  Future<void> saveSnapshot(String userId, UmlSnapshot snapshot);
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
  Future<void> saveProjects(
    String userId,
    List<UmlProjectSummary> projects,
  ) async {}

  @override
  Future<void> saveSnapshot(String userId, UmlSnapshot snapshot) async {}
}

class ViewerRepositoryException implements Exception {
  const ViewerRepositoryException(
    this.message, {
    this.offlineCopyMissing = false,
  });
  final String message;
  final bool offlineCopyMissing;

  @override
  String toString() => message;
}

class MobileViewerRepository implements ViewerRepository {
  MobileViewerRepository({
    required this.userId,
    ApiClient? apiClient,
    Future<String?> Function()? accessTokenProvider,
    ViewerReplicaStore? replicaStore,
  }) : _apiClient = apiClient ?? ApiClient(),
       _accessTokenProvider =
           accessTokenProvider ?? AuthSessionManager.getAccessToken,
       _replicaStore = replicaStore ?? const EmptyViewerReplicaStore();

  final String userId;
  final ApiClient _apiClient;
  final Future<String?> Function() _accessTokenProvider;
  final ViewerReplicaStore _replicaStore;

  @override
  Future<List<UmlProjectSummary>> loadProjects({bool refresh = true}) async {
    if (refresh) {
      try {
        final token = await _requiredToken();
        final response = await _apiClient.get(
          '/api/modeling/projects/',
          accessToken: token,
        );
        final data = _decode(response.bodyBytes);
        if (response.statusCode < 200 ||
            response.statusCode >= 300 ||
            data is! List) {
          throw const ViewerRepositoryException(
            'No se pudo actualizar la lista de proyectos.',
          );
        }
        final projects = data
            .whereType<Map>()
            .map((item) {
              return UmlProjectSummary.fromJson(
                item.map((key, value) => MapEntry('$key', value)),
              );
            })
            .toList(growable: false);
        final decorated = <UmlProjectSummary>[];
        for (final project in projects) {
          decorated.add(
            project.copyWith(
              availableOffline: await _replicaStore.hasSnapshot(
                userId,
                project.id,
              ),
              syncState: ViewerSyncState.updated,
            ),
          );
        }
        await _replicaStore.saveProjects(userId, decorated);
        return decorated;
      } catch (_) {
        // La caché sigue disponible cuando la red o la sesión remota fallan.
      }
    }
    final cached = (await _replicaStore.loadProjects(userId))
        .map((project) => project.copyWith(syncState: ViewerSyncState.offline))
        .toList(growable: false);
    if (cached.isNotEmpty) return cached;
    throw const ViewerRepositoryException(
      'No hay proyectos disponibles y no se pudo conectar.',
    );
  }

  @override
  Future<UmlSnapshot> loadSnapshot(
    UmlProjectSummary project, {
    bool preferRemote = true,
  }) async {
    if (preferRemote) {
      try {
        final snapshot = await _loadRemoteSnapshot(project);
        await _replicaStore.saveSnapshot(userId, snapshot);
        return snapshot;
      } catch (_) {
        // Se intenta la réplica de solo lectura debajo.
      }
    }
    final replica = await _replicaStore.loadSnapshot(userId, project.id);
    if (replica == null) {
      throw const ViewerRepositoryException(
        'Este proyecto no fue preparado para uso sin conexión.',
        offlineCopyMissing: true,
      );
    }
    return UmlSnapshot.fromJson(
      replica.toJson(),
      fallbackProject: project,
      loadedFromOffline: true,
    );
  }

  Future<UmlSnapshot> _loadRemoteSnapshot(UmlProjectSummary project) async {
    final token = await _requiredToken();
    final projectResponse = await _apiClient.get(
      '/api/modeling/projects/${project.id}/',
      accessToken: token,
    );
    final diagramsResponse = await _apiClient.get(
      '/api/modeling/projects/${project.id}/diagrams/',
      accessToken: token,
    );
    final elementsResponse = await _apiClient.get(
      '/api/modeling/projects/${project.id}/elements/',
      accessToken: token,
    );
    final relationshipsResponse = await _apiClient.get(
      '/api/modeling/projects/${project.id}/relationships/',
      accessToken: token,
    );
    final responses = [
      projectResponse,
      diagramsResponse,
      elementsResponse,
      relationshipsResponse,
    ];
    if (responses.any(
      (response) => response.statusCode < 200 || response.statusCode >= 300,
    )) {
      throw const ViewerRepositoryException('No se pudo cargar el proyecto.');
    }
    final projectData = _jsonMap(_decode(projectResponse.bodyBytes));
    final diagrams = _jsonList(_decode(diagramsResponse.bodyBytes));
    final elements = _jsonList(_decode(elementsResponse.bodyBytes));
    final relationships = _jsonList(_decode(relationshipsResponse.bodyBytes));
    final nodes = <Map<String, dynamic>>[];
    final edges = <Map<String, dynamic>>[];
    for (final diagram in diagrams) {
      final diagramId = '${diagram['id'] ?? ''}';
      final nodeResponse = await _apiClient.get(
        '/api/modeling/projects/${project.id}/diagrams/$diagramId/nodes/',
        accessToken: token,
      );
      final edgeResponse = await _apiClient.get(
        '/api/modeling/projects/${project.id}/diagrams/$diagramId/edges/',
        accessToken: token,
      );
      if (nodeResponse.statusCode < 200 ||
          nodeResponse.statusCode >= 300 ||
          edgeResponse.statusCode < 200 ||
          edgeResponse.statusCode >= 300) {
        throw const ViewerRepositoryException(
          'No se pudo cargar la geometría del diagrama.',
        );
      }
      nodes.addAll(_jsonList(_decode(nodeResponse.bodyBytes)));
      edges.addAll(_jsonList(_decode(edgeResponse.bodyBytes)));
    }
    return UmlSnapshot.fromJson({
      'project': projectData,
      'revision': projectData['revision'],
      'synced_at': DateTime.now().toIso8601String(),
      'payload': {
        'project': projectData,
        'diagrams': diagrams,
        'elements': elements,
        'relationships': relationships,
        'diagram_nodes': nodes,
        'diagram_edges': edges,
      },
    }, fallbackProject: project);
  }

  @override
  Stream<int> watchRemoteRevisions(String projectId) async* {
    final token = await _requiredToken();
    final ticketResponse = await _apiClient.post(
      '/api/modeling/projects/$projectId/sync/ticket/',
      accessToken: token,
    );
    final ticketPayload = _jsonMap(_decode(ticketResponse.bodyBytes));
    final ticket = ticketPayload['ticket'];
    if (ticketResponse.statusCode < 200 ||
        ticketResponse.statusCode >= 300 ||
        ticket is! String ||
        ticket.isEmpty) {
      throw const ViewerRepositoryException(
        'No se pudo observar las revisiones remotas.',
      );
    }
    final base = Uri.parse(AppConfig.apiBaseUrl);
    final socketUri = base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws/projects/$projectId/',
      queryParameters: {'ticket': ticket},
    );
    final socket = await WebSocket.connect(socketUri.toString());
    try {
      await for (final raw in socket) {
        if (raw is! String) continue;
        final payload = jsonDecode(raw);
        if (payload is! Map || payload['event'] != 'operation.confirmed') {
          continue;
        }
        final operation = payload['operation'];
        if (operation is! Map) continue;
        final revision = operation['server_revision'];
        if (revision is num) yield revision.toInt();
      }
    } finally {
      await socket.close();
    }
  }

  Future<String> _requiredToken() async {
    final token = await _accessTokenProvider();
    if (token == null || token.isEmpty) {
      throw const ViewerRepositoryException('La sesión no está disponible.');
    }
    return token;
  }
}

Object? _decode(List<int> bytes) => jsonDecode(utf8.decode(bytes));

Map<String, dynamic> _jsonMap(Object? value) => value is Map
    ? value.map((key, value) => MapEntry('$key', value))
    : const <String, dynamic>{};

List<Map<String, dynamic>> _jsonList(Object? value) {
  final list = value is Map && value['results'] is List
      ? value['results']
      : value;
  return list is List
      ? list
            .whereType<Map>()
            .map((item) => item.map((key, value) => MapEntry('$key', value)))
            .toList()
      : const [];
}
