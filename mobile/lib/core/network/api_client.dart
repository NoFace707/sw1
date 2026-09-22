import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';

class ApiClient {
  ApiClient({
    http.Client? client,
    String? baseUrl,
    Duration requestTimeout = const Duration(seconds: 4),
  }) : _client = client ?? http.Client(),
       _requestTimeout = requestTimeout,
       _baseUrl = (baseUrl ?? AppConfig.apiBaseUrl).replaceFirst(
         RegExp(r'/$'),
         '',
       );

  final http.Client _client;
  final String _baseUrl;
  final Duration _requestTimeout;

  Uri _uri(String path) =>
      Uri.parse('$_baseUrl${path.startsWith('/') ? path : '/$path'}');

  Future<http.Response> get(
    String path, {
    String? accessToken,
    Duration? timeout,
  }) {
    return _client
        .get(
          _uri(path),
          headers: {
            'Accept': 'application/json',
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
        )
        .timeout(timeout ?? _requestTimeout);
  }

  Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
    String? accessToken,
    Duration? timeout,
  }) {
    return _client
        .post(
          _uri(path),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode(body ?? const <String, dynamic>{}),
        )
        .timeout(timeout ?? _requestTimeout);
  }

  Future<http.Response> postMultipart(
    String path, {
    required String fileField,
    required String filename,
    required List<int> bytes,
    String? fileContentType,
    Map<String, String> fields = const {},
    String? accessToken,
    Duration? timeout,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path));
    request.headers.addAll({
      'Accept': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    });
    request.fields.addAll(fields);
    request.files.add(
      http.MultipartFile.fromBytes(
        fileField,
        bytes,
        filename: filename,
        contentType: fileContentType == null
            ? null
            : MediaType.parse(fileContentType),
      ),
    );
    final streamed = await _client
        .send(request)
        .timeout(timeout ?? _requestTimeout);
    return http.Response.fromStream(
      streamed,
    ).timeout(timeout ?? _requestTimeout);
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
