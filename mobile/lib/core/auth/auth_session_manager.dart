import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/auth_service.dart';
import '../../features/auth/data/models/auth_user.dart';

class AuthSessionManager {
  AuthSessionManager._();

  static const _keyAccess = 'auth_access_token';
  static const _keyRefresh = 'auth_refresh_token';
  static const _keyUser = 'auth_user_json';

  static Future<void> saveSession(AuthSession session) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_keyAccess, session.accessToken);
    await preferences.setString(_keyRefresh, session.refreshToken);
    await preferences.setString(_keyUser, jsonEncode(session.user.toJson()));
  }

  static Future<void> clearSession() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_keyAccess);
    await preferences.remove(_keyRefresh);
    await preferences.remove(_keyUser);
  }

  static Future<AuthSession?> restoreClientSession({
    AuthService? authService,
  }) async {
    final service = authService ?? AuthService();
    final preferences = await SharedPreferences.getInstance();
    var access = (preferences.getString(_keyAccess) ?? '').trim();
    final refresh = (preferences.getString(_keyRefresh) ?? '').trim();
    if (access.isEmpty || refresh.isEmpty) {
      await clearSession();
      return null;
    }

    try {
      final user = await service.getProfile(access);
      final session = AuthSession(
        user: user,
        accessToken: access,
        refreshToken: refresh,
      );
      await saveSession(session);
      return session;
    } catch (_) {
      try {
        access = await service.refreshToken(refresh);
        final user = await service.getProfile(access);
        final session = AuthSession(
          user: user,
          accessToken: access,
          refreshToken: refresh,
        );
        await saveSession(session);
        return session;
      } catch (_) {
        await clearSession();
        return null;
      }
    }
  }

  static Future<AuthUser?> getStoredUser() async {
    final raw = (await SharedPreferences.getInstance()).getString(_keyUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      final value = jsonDecode(raw);
      return value is Map<String, dynamic> ? AuthUser.fromJson(value) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getAccessToken() async {
    final value = (await SharedPreferences.getInstance())
        .getString(_keyAccess)
        ?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static Future<String?> refreshAccessToken({AuthService? authService}) async {
    final preferences = await SharedPreferences.getInstance();
    final refresh = (preferences.getString(_keyRefresh) ?? '').trim();
    if (refresh.isEmpty) return null;
    try {
      final access = await (authService ?? AuthService()).refreshToken(refresh);
      await preferences.setString(_keyAccess, access);
      return access;
    } catch (_) {
      return null;
    }
  }

  static Future<void> logoutAndClear({AuthService? authService}) async {
    final service = authService ?? AuthService();
    final access = await getAccessToken();
    try {
      await service.logout(accessToken: access);
    } catch (_) {
      // La sesión local siempre se elimina aunque el servidor no esté disponible.
    } finally {
      await clearSession();
    }
  }
}
