import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = (baseUrl ?? AppConfig.apiBaseUrl).replaceFirst(
        RegExp(r'/$'),
        '',
      );

  final http.Client _client;
  final String _baseUrl;

  Uri _uri(String path) =>
      Uri.parse('$_baseUrl${path.startsWith('/') ? path : '/$path'}');

  Future<http.Response> get(String path, {String? accessToken}) {
    return _client.get(
      _uri(path),
      headers: {
        'Accept': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
    );
  }

  Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
    String? accessToken,
  }) {
    return _client.post(
      _uri(path),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body ?? const <String, dynamic>{}),
    );
  }

  Map<String, dynamic> parseJsonMap(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}
