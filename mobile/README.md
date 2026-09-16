
## Estructura real del proyecto

```text
mobile/
|-- assets/
|   `-- app/
|       `-- icon.png
|-- lib/
|   |-- app.dart
|   |-- main.dart
|   |-- core/
|   |   |-- auth/
|   |   |   `-- auth_session_manager.dart
|   |   |-- config/
|   |   |   `-- app_config.dart
|   |   |-- network/
|   |   |   `-- api_client.dart
|   |   `-- theme/
|   |       `-- app_theme.dart
|   `-- features/
|       |-- auth/
|       |   |-- data/
|       |   |   |-- auth_service.dart
|       |   |   `-- models/
|       |   |       `-- auth_user.dart
|       |   `-- presentation/
|       |       |-- pages/
|       |       |   |-- forgot_password_page.dart
|       |       |   |-- login_page.dart
|       |       |   |-- register_page.dart
|       |       |   |-- reset_password_page.dart
|       |       |   |-- splash_page.dart
|       |       |   `-- verify_email_page.dart
|       |       `-- widgets/
|       |           `-- background_blobs.dart
|       `-- home/
|           `-- presentation/
|               `-- pages/
|                   `-- customer_home_page.dart
|-- test/
|   `-- widget_test.dart
|-- android/
|-- ios/
|-- web/
|-- windows/
|-- macos/
`-- linux/
```


## Configuracion de entorno

`API_BASE_URL` se puede definir en runtime:

```bash
flutter run --dart-define=API_BASE_URL=http://TUIP:8000
```

Si no se define, se usan defaults por plataforma en `app_config.dart`.



## Comandos utiles

```bash
flutter pub get
flutter analyze
flutter test
```


## Inicio rapido al clonar el repositorio

1. Instalar prerequisitos:
	- Flutter SDK (version estable)
	- Android Studio o VS Code con extensiones de Flutter y Dart
	- Un emulador Android o dispositivo fisico con depuracion USB
2. Validar entorno Flutter:

```bash
flutter doctor
```

3. Entrar al modulo mobile e instalar dependencias:

```bash
cd mobile
flutter pub get
```

4. Levantar backend antes de abrir la app movil (desde la raiz del repo):
	- Si usan Docker Compose del proyecto, iniciar servicios y confirmar que backend responda en puerto 8000.
	- Si levantan backend manualmente, verificar que el endpoint /api/auth/login/ este accesible.
5. Ejecutar la app:

```bash
flutter run --dart-define=API_BASE_URL=http://TU_IP_LOCAL:8000
```


## Recomendaciones para probar mobile

- Usar siempre una IP de red local para dispositivo fisico (ejemplo 192.168.x.x), no localhost.
- En emulador Android puedes usar 10.0.2.2 para apuntar al host.
- Verificar que firewall o antivirus no bloqueen el puerto 8000.
- Confirmar que el usuario de prueba tenga rol cliente, porque la app movil filtra acceso por rol.
- Ejecutar chequeos basicos antes de subir cambios:

```bash
flutter analyze
flutter test
```


## Checklist sugerido para nuevos integrantes

- Clonar repositorio y abrir carpeta mobile.
- Ejecutar flutter doctor y resolver advertencias.
- Ejecutar flutter pub get.
- Levantar backend del proyecto.
- Lanzar la app con API_BASE_URL apuntando al backend activo.
- Validar flujos: splash, login, registro, recuperar contrasena y perfil cliente.


## Solucion de problemas comunes

### 1) `flutter run` termina con error

- Revisar dispositivos detectados:

```bash
flutter devices
```

- Si no aparece ninguno, iniciar emulador o conectar telefono con depuracion USB.
- Validar entorno:

```bash
flutter doctor
```


### 2) La app abre pero no conecta al backend

- Confirmar que backend esta levantado en puerto 8000.
- Verificar `API_BASE_URL` al ejecutar:

```bash
flutter run --dart-define=API_BASE_URL=http://TU_IP_LOCAL:8000
```

- En telefono fisico usar IP local (ejemplo `192.168.x.x`), no `localhost`.
- En emulador Android usar `http://10.0.2.2:8000`.
- Asegurar que firewall permita conexiones entrantes al puerto 8000.


### 3) Cambie assets/icono/logo y no se ve reflejado

- Ejecutar:

```bash
flutter pub get
```

- Si es icono launcher, regenerar:

```bash
dart run flutter_launcher_icons
```

- Si persiste, limpiar y recompilar:

```bash
flutter clean
flutter pub get
flutter run --dart-define=API_BASE_URL=http://TU_IP_LOCAL:8000
```


### 4) Error de autenticacion al iniciar sesion

- Confirmar credenciales correctas.
- Verificar que el usuario tenga rol `cliente`.
- Si el usuario es nuevo, confirmar verificacion de correo antes de login.


### 5) Fallan pruebas o analisis

- Ejecutar en este orden:

```bash
flutter pub get
flutter analyze
flutter test
```

- Si hay fallas por cambios de textos/branding, actualizar expectativas en `test/widget_test.dart`.




