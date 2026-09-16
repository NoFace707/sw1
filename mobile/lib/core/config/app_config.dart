class AppConfig {
  AppConfig._();

  static const _apiBaseUrlFromEnv = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get apiBaseUrl {
    if (_apiBaseUrlFromEnv.isNotEmpty) {
      return _apiBaseUrlFromEnv;
    }

    return 'http://192.168.0.9:8000';
  }

  static const appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'Modelador UML',
  );
}
