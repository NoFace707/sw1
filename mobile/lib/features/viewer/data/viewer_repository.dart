import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/auth/auth_session_manager.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../offline/data/connectivity_service.dart';
import '../../offline/data/drift_viewer_replica_store.dart';
import '../../offline/domain/viewer_replica_store.dart';
import '../../ai/domain/mobile_ai.dart';
import '../domain/viewer_models.dart';

abstract class ViewerRepository {
  Future<List<UmlProjectSummary>> loadProjects({bool refresh = true});

  Future<UmlSnapshot> loadSnapshot(
    UmlProjectSummary project, {
    bool preferRemote = true,
  });

  Stream<int> watchRemoteRevisions(String projectId) => const Stream.empty();
}

abstract class OfflineCapableViewerRepository {
  Future<UmlProjectSummary> setOfflineAvailability(
    UmlProjectSummary project,
    bool enabled,
  );

  Future<int> offlineProjectBytes();

  Stream<MobileConnectivityState> watchConnectivity();

  Future<void> close();
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

class MobileViewerRepository
    implements ViewerRepository, OfflineCapableViewerRepository {
  MobileViewerRepository({
    required this.userId,
    ApiClient? apiClient,
    Future<String?> Function()? accessTokenProvider,
    Future<String?> Function()? accessTokenRefresher,
    ViewerReplicaStore? replicaStore,
    ConnectivityService? connectivityService,
  }) : _apiClient = apiClient ?? ApiClient(),
       _accessTokenProvider =
           accessTokenProvider ?? AuthSessionManager.getAccessToken,
       _accessTokenRefresher =
           accessTokenRefresher ?? AuthSessionManager.refreshAccessToken,
       _replicaStore = replicaStore ?? DriftViewerReplicaStore(),
       _connectivityService =
           connectivityService ?? DeviceConnectivityService();

  final String userId;
  final ApiClient _apiClient;
  final Future<String?> Function() _accessTokenProvider;
  final Future<String?> Function()? _accessTokenRefresher;
  final ViewerReplicaStore _replicaStore;
  final ConnectivityService _connectivityService;

  @override
  Future<List<UmlProjectSummary>> loadProjects({bool refresh = true}) async {
    if (refresh &&
        await _connectivityService.current() ==
            MobileConnectivityState.offline) {
      refresh = false;
    }
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
        .map(
          (project) => project.copyWith(
            syncState: switch (project.syncState) {
              ViewerSyncState.pending ||
              ViewerSyncState.conflict => project.syncState,
              _ => ViewerSyncState.offline,
            },
          ),
        )
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
    final canUseRemote =
        preferRemote &&
        await _connectivityService.current() == MobileConnectivityState.online;
    if (canUseRemote) {
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
  Future<UmlProjectSummary> setOfflineAvailability(
    UmlProjectSummary project,
    bool enabled,
  ) async {
    if (!enabled) {
      await _replicaStore.removeOfflineBundle(userId, project.id);
      return project.copyWith(
        availableOffline: false,
        syncState: ViewerSyncState.updated,
      );
    }

    final token = await _requiredToken();
    final snapshotFuture = _loadRemoteSnapshot(project);
    final registryFuture = _apiClient.get(
      '/api/modeling/registry/',
      accessToken: token,
    );
    final rulesFuture = _apiClient.get(
      '/api/modeling/expert-rules/',
      accessToken: token,
    );
    final snapshot = await snapshotFuture;
    final registryResponse = await registryFuture;
    final rulesResponse = await rulesFuture;
    if (registryResponse.statusCode < 200 ||
        registryResponse.statusCode >= 300 ||
        rulesResponse.statusCode < 200 ||
        rulesResponse.statusCode >= 300) {
      throw const ViewerRepositoryException(
        'No se pudieron descargar el registro UML y las reglas offline.',
      );
    }
    final registry = _jsonMap(_decode(registryResponse.bodyBytes));
    final rules = _jsonMap(_decode(rulesResponse.bodyBytes));
    if (registry['version'] == null ||
        rules['version'] == null ||
        rules['registry_version'] != registry['version']) {
      throw const ViewerRepositoryException(
        'El registro UML y las reglas offline no son compatibles.',
      );
    }
    await _replicaStore.saveOfflineBundle(userId, snapshot, registry, rules);
    return project.copyWith(
      availableOffline: true,
      revision: snapshot.project.revision,
      syncState: ViewerSyncState.updated,
    );
  }

  @override
  Future<int> offlineProjectBytes() => _replicaStore.projectBytes(userId);

  Future<Map<String, dynamic>?> loadOfflineRules(String projectId) =>
      _replicaStore.loadRules(userId, projectId);

  Future<Map<String, dynamic>?> loadOfflineRegistry(String projectId) =>
      _replicaStore.loadRegistry(userId, projectId);

  Future<bool> isOnline() async =>
      await _connectivityService.current() == MobileConnectivityState.online;

  Future<void> saveLocalProposal(String projectId, MobileAiResponse proposal) =>
      _replicaStore.saveLocalProposal(userId, projectId, proposal);

  Future<UmlSnapshot> confirmLocalProposal(
    String projectId,
    MobileAiResponse proposal,
    Iterable<String> selectedOperationIds,
  ) => _replicaStore.confirmLocalProposal(
    userId,
    projectId,
    proposal,
    selectedOperationIds,
  );

  Future<UmlSnapshot> applyRemoteAiProposal(
    UmlProjectSummary project,
    MobileAiResponse proposal,
    Iterable<String> selectedOperationIds,
  ) async {
    if (proposal.id.trim().isEmpty) {
      throw const ViewerRepositoryException(
        'La propuesta remota no tiene un identificador válido.',
      );
    }
    final selected = selectedOperationIds.toSet();
    if (selected.isEmpty) {
      throw const ViewerRepositoryException(
        'Selecciona al menos un cambio antes de confirmar.',
      );
    }
    late final http.Response response;
    try {
      response = await _postAuthorized(
        '/api/modeling/projects/${project.id}/ai/proposals/${proposal.id}/apply/',
        body: {'operation_ids': selected.toList(growable: false)},
        timeout: const Duration(seconds: 30),
      );
    } on TimeoutException {
      throw const ViewerRepositoryException(
        'El servidor tardó demasiado en aplicar la propuesta. Actualiza el proyecto antes de reintentar para comprobar si fue confirmada.',
      );
    }
    final payload = _jsonMap(_decode(response.bodyBytes));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ViewerRepositoryException(
        '${payload['detail'] ?? 'No se pudo aplicar la propuesta de IA.'}',
      );
    }
    final snapshot = await _loadRemoteSnapshot(project);
    await _replicaStore.saveSnapshot(userId, snapshot);
    return snapshot;
  }

  Future<http.Response> _postAuthorized(
    String path, {
    required Map<String, dynamic> body,
    Duration? timeout,
  }) async {
    var token = await _requiredToken();
    var response = await _apiClient.post(
      path,
      accessToken: token,
      body: body,
      timeout: timeout,
    );
    final refresher = _accessTokenRefresher;
    if (response.statusCode != 401 || refresher == null) {
      return response;
    }
    token = (await refresher()) ?? '';
    if (token.isEmpty) {
      throw const ViewerRepositoryException(
        'La sesión venció. Inicia sesión nuevamente para confirmar cambios.',
      );
    }
    response = await _apiClient.post(
      path,
      accessToken: token,
      body: body,
      timeout: timeout,
    );
    return response;
  }

  @override
  Stream<MobileConnectivityState> watchConnectivity() {
    return _connectivityService.watch();
  }

  @override
  Future<void> close() => _replicaStore.close();

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
