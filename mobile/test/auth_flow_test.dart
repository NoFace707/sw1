import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/auth/auth_session_manager.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/data/auth_service.dart';
import 'package:mobile/features/auth/data/models/auth_user.dart';
import 'package:mobile/features/auth/presentation/pages/login_page.dart';
import 'package:mobile/features/auth/presentation/pages/register_page.dart';
import 'package:mobile/features/auth/presentation/pages/splash_page.dart';
import 'package:mobile/features/home/presentation/pages/home_page.dart';

const user = AuthUser(
  id: 1,
  firstName: 'Ana',
  lastName: 'Pérez',
  email: 'ana@example.com',
);
const session = AuthSession(
  user: user,
  accessToken: 'access',
  refreshToken: 'refresh',
);

class FakeAuthService extends AuthService {
  FakeAuthService({
    this.failProfile = false,
    this.failRefresh = false,
    this.failLogout = false,
  });
  final bool failProfile;
  final bool failRefresh;
  final bool failLogout;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async => session;
  @override
  Future<AuthSession> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async => session;
  @override
  Future<AuthUser> getProfile(String accessToken) async {
    if (failProfile && accessToken == 'old') {
      throw const AuthServiceException('expired');
    }
    if (failProfile && failRefresh) throw const AuthServiceException('invalid');
    return user;
  }

  @override
  Future<String> refreshToken(String refreshToken) async {
    if (failRefresh) throw const AuthServiceException('invalid');
    return 'new';
  }

  @override
  Future<void> logout({String? accessToken}) async {
    if (failLogout) throw const AuthServiceException('offline');
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'AuthService interpreta login y registro con el payload reducido',
    () async {
      final client = MockClient(
        (request) async => http.Response(
          '{"user":{"id":1,"first_name":"Ana","last_name":"Pérez","email":"ana@example.com"},"access":"a","refresh":"r"}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      final service = AuthService(
        apiClient: ApiClient(client: client, baseUrl: 'http://test'),
      );
      expect(
        (await service.login(
          email: 'ana@example.com',
          password: 'password',
        )).user.email,
        user.email,
      );
      expect(
        (await service.register(
          firstName: 'Ana',
          lastName: 'Pérez',
          email: user.email,
          password: 'password',
        )).accessToken,
        'a',
      );
    },
  );

  test('restaura, renueva y limpia sesiones inválidas', () async {
    SharedPreferences.setMockInitialValues({
      'auth_access_token': 'old',
      'auth_refresh_token': 'refresh',
      'auth_user_json': '{}',
    });
    final renewed = await AuthSessionManager.restoreClientSession(
      authService: FakeAuthService(failProfile: true),
    );
    expect(renewed?.accessToken, 'new');

    SharedPreferences.setMockInitialValues({
      'auth_access_token': 'old',
      'auth_refresh_token': 'bad',
      'auth_user_json': '{}',
    });
    final invalid = await AuthSessionManager.restoreClientSession(
      authService: FakeAuthService(failProfile: true, failRefresh: true),
    );
    expect(invalid, isNull);
    expect(await AuthSessionManager.getAccessToken(), isNull);
  });

  testWidgets('splash sin sesión reemplaza por login', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: SplashPage(authService: FakeAuthService())),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('login-page')), findsOneWidget);
  });

  testWidgets('login y registro entran directamente a inicio', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginPage(authService: FakeAuthService())),
    );
    await tester.enterText(
      find.byKey(const ValueKey('email-field')),
      user.email,
    );
    await tester.enterText(
      find.byKey(const ValueKey('password-field')),
      'password',
    );
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-page')), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        home: RegisterPage(authService: FakeAuthService()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('first-name-field')),
      'Ana',
    );
    await tester.enterText(
      find.byKey(const ValueKey('last-name-field')),
      'Pérez',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-email-field')),
      user.email,
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-password-field')),
      'password',
    );
    await tester.tap(find.byKey(const ValueKey('register-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-page')), findsOneWidget);
  });

  testWidgets(
    'inicio muestra datos, no roles, y logout limpia aunque falle servidor',
    (tester) async {
      await AuthSessionManager.saveSession(session);
      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(
            user: user,
            authService: FakeAuthService(failLogout: true),
          ),
        ),
      );
      expect(find.text(user.email), findsOneWidget);
      expect(find.textContaining('rol'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('logout-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('login-page')), findsOneWidget);
      expect(await AuthSessionManager.getAccessToken(), isNull);
    },
  );
}
