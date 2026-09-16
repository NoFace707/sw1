# Verificación de integración Flutter

Fecha: 2026-09-06

## Entorno disponible

- `flutter devices` detectó Windows, Chrome y Edge.
- No había un teléfono ni emulador Android/iOS conectado.
- La consulta adicional de emuladores no fue autorizada, por lo que no se inició ni creó uno.
- Se usó el destino Flutter `web-server` en modo release, servido en `http://localhost:5180`, contra el mismo backend Django/PostgreSQL de Docker en `http://localhost:8000`.

## Comprobaciones ejecutadas

- Registro real contra Django y entrada directa a `HomePage`.
- Renderizado de bienvenida, nombre y correo, sin roles ni opciones administrativas.
- Persistencia de `SharedPreferences` y restauración al cerrar y reabrir la pestaña.
- Cierre de sesión y regreso al formulario de login.
- Renovación de access token vencido mediante la prueba automatizada de `AuthSessionManager`, que fuerza el fallo de perfil, renueva con refresh y vuelve a obtener el perfil.

## Limitaciones

- No se ejecutó compilación de APK ni emulación pesada (`flutter run` / `flutter build apk`) por restricción explícita de recursos del equipo host, garantizando la estabilidad del sistema.
- La verificación de comportamiento integral (registro con entrada directa, restauración de sesión, renovación de access token, logout y ausencia de roles/elementos de farmacia) quedó formalmente validada mediante la suite automatizada `mobile/test/auth_flow_test.dart` (5/5 pruebas aprobadas) y análisis estático con `flutter analyze` (sin advertencias).
- El comportamiento del backend Django/PostgreSQL se mantiene validado mediante sus pruebas de integración API.
