import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../domain/mobile_ai.dart';

class RemoteAiEngine implements MobileAiEngine {
  RemoteAiEngine({
    required this.accessTokenProvider,
    required this.online,
    this.accessTokenRefresher,
    this.requestTimeout = const Duration(seconds: 90),
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient();

  final Future<String?> Function() accessTokenProvider;
  final Future<String?> Function()? accessTokenRefresher;
  final Future<bool> Function() online;
  final Duration requestTimeout;
  final ApiClient _apiClient;

  @override
  String get id => 'remote-api';

  @override
  Future<bool> isAvailable() => online();

  @override
  Future<MobileAiResponse> propose(
    MobileAiRequest request, {
    MobileAiCancellation? cancellation,
    void Function(String token)? onToken,
  }) async {
    if (cancellation?.isCancelled == true) {
      throw const MobileAiException('Solicitud cancelada.', code: 'cancelled');
    }
    if (!await online()) {
      throw const MobileAiException(
        'No hay conexión para usar la IA por API.',
        code: 'offline',
      );
    }
    final token = await accessTokenProvider();
    if (token == null || token.isEmpty) {
      throw const MobileAiException(
        'La sesión remota no está disponible.',
        code: 'unauthenticated',
      );
    }
    late final http.Response response;
    try {
      Future<http.Response> send(String accessToken) {
        final pending = _apiClient.post(
          '/api/modeling/projects/${request.projectId}/ai/proposals/',
          accessToken: accessToken,
          timeout: requestTimeout,
          body: {
            'prompt': request.prompt,
            'selection': request.selection,
            'base_revision': request.baseRevision,
            if (request.context['diagram'] is Map)
              'diagram_id': '${(request.context['diagram'] as Map)['id']}',
          },
        );
        return cancellation == null
            ? pending
            : Future.any([
                pending,
                cancellation.onCancel.first.then(
                  (_) => throw const MobileAiException(
                    'Solicitud cancelada.',
                    code: 'cancelled',
                  ),
                ),
              ]);
      }

      var currentToken = token;
      var currentResponse = await send(currentToken);
      if (currentResponse.statusCode == 401 && accessTokenRefresher != null) {
        currentToken = (await accessTokenRefresher!.call()) ?? '';
        if (currentToken.isNotEmpty) currentResponse = await send(currentToken);
      }
      response = currentResponse;
    } on TimeoutException {
      throw const MobileAiException(
        'La IA remota tardó demasiado en responder.',
        code: 'timeout',
      );
    }
    if (cancellation?.isCancelled == true) {
      throw const MobileAiException('Solicitud cancelada.', code: 'cancelled');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const MobileAiException(
        'La IA remota devolvió una respuesta inválida.',
        code: 'invalid_json',
      );
    }
    final payload = decoded is Map
        ? decoded.map((key, value) => MapEntry('$key', value))
        : const <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MobileAiException(
        '${payload['detail'] ?? 'La IA remota no está disponible.'}',
        code: '${payload['code'] ?? 'remote_unavailable'}',
      );
    }
    try {
      return MobileAiResponse.fromJson(
        {
          ...payload,
          'model': '${payload['model'] ?? 'configured-api-provider'}',
        },
        origin: MobileAiOrigin.remote,
        model: '${payload['model'] ?? 'configured-api-provider'}',
      );
    } on FormatException catch (error) {
      throw MobileAiException(
        'Respuesta remota inválida: ${error.message}',
        code: 'invalid_json',
      );
    }
  }
}
