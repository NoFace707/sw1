import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/ai/data/remote_ai_engine.dart';
import 'package:mobile/features/ai/domain/mobile_ai.dart';
import 'package:mobile/features/offline/domain/viewer_replica_store.dart';
import 'package:mobile/features/viewer/data/viewer_repository.dart';
import 'package:mobile/features/viewer/domain/viewer_models.dart';

void main() {
  test('IA por API propone, confirma y recarga la revisión canónica', () async {
    var accessToken = 'expired';
    var refreshes = 0;
    var proposalCalls = 0;
    var applyCalls = 0;

    final client = MockClient((request) async {
      final authorized = request.headers['authorization'] == 'Bearer fresh';
      if (!authorized) return http.Response('{"detail":"Token vencido"}', 401);
      final path = request.url.path;
      if (request.method == 'POST' && path.endsWith('/ai/proposals/')) {
        proposalCalls++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['diagram_id'], 'diagram-1');
        expect(body['base_revision'], 1);
        return http.Response(
          jsonEncode({
            'id': 'proposal-1',
            'model': 'api-model',
            'proposal': {
              'operations': [
                {
                  'id': 'create-client',
                  'entity_type': 'UmlElement',
                  'entity_id': '11111111-1111-4111-8111-111111111111',
                  'action': 'create',
                  'value': {
                    'metaclass': 'Actor',
                    'name': 'Cliente',
                    'properties': {},
                  },
                },
              ],
              'questions': [],
              'assumptions': ['Se agrega al diagrama actual.'],
              'warnings': [],
              'diagnostics': [],
            },
          }),
          201,
        );
      }
      if (request.method == 'POST' && path.endsWith('/proposal-1/apply/')) {
        applyCalls++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['operation_ids'], ['create-client']);
        return http.Response('{"proposal_id":"proposal-1","revision":2}', 200);
      }
      if (request.method == 'GET' &&
          path == '/api/modeling/projects/project-1/') {
        return http.Response(
          '{"id":"project-1","name":"Ventas","membership_role":"editor","revision":2}',
          200,
        );
      }
      if (request.method == 'GET' && path.endsWith('/diagrams/')) {
        return http.Response(
          '[{"id":"diagram-1","name":"Casos de uso","diagram_type":"use_case","properties":{}}]',
          200,
        );
      }
      if (request.method == 'GET' && path.endsWith('/elements/')) {
        return http.Response(
          '[{"id":"11111111-1111-4111-8111-111111111111","metaclass":"Actor","name":"Cliente","properties":{}}]',
          200,
        );
      }
      if (request.method == 'GET' && path.endsWith('/relationships/')) {
        return http.Response('[]', 200);
      }
      if (request.method == 'GET' && path.endsWith('/nodes/')) {
        return http.Response(
          '[{"id":"node-1","diagram":"diagram-1","element":"11111111-1111-4111-8111-111111111111","x":120,"y":140,"width":100,"height":120,"properties":{}}]',
          200,
        );
      }
      if (request.method == 'GET' && path.endsWith('/edges/')) {
        return http.Response('[]', 200);
      }
      return http.Response('{"detail":"Ruta inesperada: $path"}', 404);
    });
    final api = ApiClient(baseUrl: 'http://test', client: client);
    Future<String?> tokenProvider() async => accessToken;
    Future<String?> refreshToken() async {
      refreshes++;
      accessToken = 'fresh';
      return accessToken;
    }

    final engine = RemoteAiEngine(
      accessTokenProvider: tokenProvider,
      accessTokenRefresher: refreshToken,
      online: () async => true,
      apiClient: api,
    );
    final request = MobileAiRequest(
      projectId: 'project-1',
      prompt: 'Añade un actor Cliente',
      baseRevision: 1,
      permission: 'editor',
      context: const {
        'project': {'id': 'project-1', 'revision': 1},
        'diagram': {'id': 'diagram-1', 'name': 'Casos de uso'},
      },
    );

    final proposal = await engine.propose(request);
    expect(proposal.canConfirm, isTrue);
    expect(proposal.operations.single.value['name'], 'Cliente');
    expect(refreshes, 1);

    accessToken = 'expired-apply';
    final repository = MobileViewerRepository(
      userId: '7',
      apiClient: api,
      accessTokenProvider: tokenProvider,
      accessTokenRefresher: refreshToken,
      replicaStore: const EmptyViewerReplicaStore(),
    );
    const project = UmlProjectSummary(
      id: 'project-1',
      name: 'Ventas',
      access: ProjectAccess.editor,
      updatedAt: null,
      revision: 1,
    );
    final snapshot = await repository.applyRemoteAiProposal(project, proposal, {
      'create-client',
    });

    expect(refreshes, 2);
    expect(proposalCalls, 1);
    expect(applyCalls, 1);
    expect(snapshot.project.revision, 2);
    expect(snapshot.elements.single.name, 'Cliente');
    expect(snapshot.nodes.single.elementId, snapshot.elements.single.id);
  });
}
