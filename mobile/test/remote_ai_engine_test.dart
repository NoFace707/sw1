import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/ai/data/remote_ai_engine.dart';
import 'package:mobile/features/ai/domain/mobile_ai.dart';

const _request = MobileAiRequest(
  projectId: 'project-1',
  prompt: 'Añade Factura',
  baseRevision: 4,
  permission: 'editor',
  context: {
    'project': {'id': 'project-1', 'revision': 4},
    'diagram': {'id': 'diagram-1', 'name': 'Clases'},
  },
);

void main() {
  test('RemoteAiEngine devuelve propuesta, modelo y origen remoto', () async {
    final engine = RemoteAiEngine(
      accessTokenProvider: () async => 'token',
      online: () async => true,
      apiClient: ApiClient(
        baseUrl: 'http://test',
        client: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer token');
          final body = jsonDecode(request.body);
          expect(body['diagram_id'], 'diagram-1');
          expect(body['base_revision'], 4);
          return http.Response(
            '{"id":"proposal-1","model":"uml-api","proposal":{"operations":[{"id":"op-1","entity_type":"UmlElement","action":"create","value":{"metaclass":"Class","name":"Factura"}}],"questions":[],"assumptions":["Clase persistente"],"warnings":[]}}',
            201,
          );
        }),
      ),
    );

    final response = await engine.propose(_request);

    expect(response.id, 'proposal-1');
    expect(response.origin, MobileAiOrigin.remote);
    expect(response.model, 'uml-api');
    expect(response.operations.single.value['name'], 'Factura');
  });

  test('RemoteAiEngine informa indisponibilidad sin llamar a la API', () async {
    var calls = 0;
    final engine = RemoteAiEngine(
      accessTokenProvider: () async => 'token',
      online: () async => false,
      apiClient: ApiClient(
        baseUrl: 'http://test',
        client: MockClient((request) async {
          calls++;
          return http.Response('{}', 500);
        }),
      ),
    );

    await expectLater(
      engine.propose(_request),
      throwsA(
        isA<MobileAiException>().having(
          (error) => error.code,
          'code',
          'offline',
        ),
      ),
    );
    expect(calls, 0);
  });

  test('RemoteAiEngine convierte timeout en error recuperable', () async {
    final engine = RemoteAiEngine(
      accessTokenProvider: () async => 'token',
      online: () async => true,
      requestTimeout: const Duration(milliseconds: 2),
      apiClient: ApiClient(
        baseUrl: 'http://test',
        requestTimeout: const Duration(milliseconds: 2),
        client: MockClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return http.Response('{}', 200);
        }),
      ),
    );

    await expectLater(
      engine.propose(_request),
      throwsA(
        isA<MobileAiException>().having(
          (error) => error.code,
          'code',
          'timeout',
        ),
      ),
    );
  });

  test('RemoteAiEngine cancela y no altera la solicitud', () async {
    final response = Completer<http.Response>();
    final cancellation = MobileAiCancellation();
    addTearDown(cancellation.close);
    final contextBefore = _request.context.toString();
    final engine = RemoteAiEngine(
      accessTokenProvider: () async => 'token',
      online: () async => true,
      apiClient: ApiClient(
        baseUrl: 'http://test',
        requestTimeout: const Duration(seconds: 1),
        client: MockClient((request) => response.future),
      ),
    );

    final pending = engine.propose(_request, cancellation: cancellation);
    await Future<void>.delayed(Duration.zero);
    cancellation.cancel();

    await expectLater(
      pending,
      throwsA(
        isA<MobileAiException>().having(
          (error) => error.code,
          'code',
          'cancelled',
        ),
      ),
    );
    expect(_request.context.toString(), contextBefore);
    if (!response.isCompleted) response.complete(http.Response('{}', 499));
  });
}
