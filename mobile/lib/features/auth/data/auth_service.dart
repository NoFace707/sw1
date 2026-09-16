import '../../../core/network/api_client.dart';
import 'models/auth_user.dart';

class AuthService {
  AuthService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<AuthSession> login({required String email, required String password}) {
    return _createSession('/api/auth/login/', {
      'email': email.trim(),
      'password': password,
    });
  }

  Future<AuthSession> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) {
    return _createSession('/api/auth/register/', {
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'email': email.trim(),
      'password': password,
    });
  }

  Future<AuthSession> _createSession(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _apiClient.post(path, body: body);
      final data = _apiClient.parseJsonMap(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthServiceException(
          _extractError(data, 'No se pudo autenticar.'),
        );
      }
      final access = data['access'];
      final refresh = data['refresh'];
      final user = data['user'];
      if (access is! String ||
          access.isEmpty ||
          refresh is! String ||
          refresh.isEmpty ||
          user is! Map<String, dynamic>) {
        throw const AuthServiceException('Respuesta inválida del servidor.');
      }
      return AuthSession(
        user: AuthUser.fromJson(user),
        accessToken: access,
        refreshToken: refresh,
      );
    } on AuthServiceException {
      rethrow;
    } catch (_) {
      throw const AuthServiceException('No se pudo conectar con el servidor.');
    }
  }

  Future<AuthUser> getProfile(String accessToken) async {
    final response = await _apiClient.get(
      '/api/auth/me/',
      accessToken: accessToken,
    );
    final data = _apiClient.parseJsonMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthServiceException(_extractError(data, 'Sesión inválida.'));
    }
    return AuthUser.fromJson(data);
  }

  Future<String> refreshToken(String refreshToken) async {
    final response = await _apiClient.post(
      '/api/auth/refresh/',
      body: {'refresh': refreshToken},
    );
    final data = _apiClient.parseJsonMap(response);
    final access = data['access'];
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        access is! String ||
        access.isEmpty) {
      throw AuthServiceException(
        _extractError(data, 'No se pudo renovar la sesión.'),
      );
    }
    return access;
  }

  Future<void> logout({String? accessToken}) async {
    final response = await _apiClient.post(
      '/api/auth/logout/',
      accessToken: accessToken,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const AuthServiceException('No se pudo cerrar la sesión remota.');
    }
  }

  String _extractError(Map<String, dynamic> data, String fallback) {
    final detail = data['detail'];
    if (detail is String && detail.trim().isNotEmpty) return detail.trim();
    for (final value in data.values) {
      if (value is List && value.isNotEmpty) return value.first.toString();
      if (value is String && value.isNotEmpty) return value;
    }
    return fallback;
  }
}

class AuthServiceException implements Exception {
  const AuthServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}
