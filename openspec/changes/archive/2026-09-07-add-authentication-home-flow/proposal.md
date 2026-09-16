## Why

El repositorio reutiliza una base de otro dominio que ya contiene partes de autenticación, pero también conserva paneles administrativos, roles, auditoría, copias de seguridad, dependencias y recursos que no corresponden al alcance universitario actual. Se necesita consolidar un flujo simple y coherente de registro e inicio de sesión para React y Flutter, con una sesión recordable en el navegador y una única pantalla de inicio posterior al acceso.

## What Changes

- Adaptar el registro para crear usuarios activos en PostgreSQL y devolver una sesión válida, permitiendo entrar inmediatamente a la pantalla de inicio.
- Unificar el inicio de sesión por correo y contraseña para los clientes React y Flutter.
- Incorporar en React una opción «Recordarme» que persista la sesión entre cierres del navegador; cuando no se seleccione, la sesión durará solo durante la pestaña/sesión del navegador. No se almacenará la contraseña.
- Proteger la pantalla de inicio y redirigir a ella después de registrarse o iniciar sesión; los visitantes sin sesión serán enviados al acceso.
- Restaurar sesiones válidas al abrir nuevamente la aplicación web o móvil y permitir cerrar sesión.
- Simplificar la autenticación a controles básicos adecuados para el proyecto: contraseñas con hash de Django, validación mínima, JWT y validación de correo único, sin exigir verificación por correo, recuperación de contraseña, bloqueo por intentos, RBAC ni bitácora de seguridad.
- **BREAKING**: eliminar el dashboard/panel administrativo y sus rutas, servicios, componentes y endpoints, porque la pantalla de inicio será el único destino autenticado inicial.
- **BREAKING**: eliminar módulos, recursos y dependencias heredados que no sean alcanzables desde el flujo autenticación-inicio, incluyendo copias de seguridad, KPIs, roles/permisos, bitácora, archivos de farmacia y servicios auxiliares como Celery, Redis, Channels, Firebase y notificaciones cuando no tengan otro uso real.
- Mantener la estructura base de Django, React, Flutter, PostgreSQL, configuración de red/entorno y los componentes visuales compartidos que sí sean necesarios para el flujo final.

## Capabilities

### New Capabilities

- `user-authentication`: Registro, inicio/cierre de sesión, restauración de sesión y comportamiento de «Recordarme» para los clientes web y móvil.
- `authenticated-home`: Navegación protegida y redirección a una pantalla de inicio simple como destino único después de autenticarse.

### Modified Capabilities

Ninguna; el repositorio todavía no contiene especificaciones base de capacidades.

## Impact

- Backend Django/DRF: modelos y migraciones de usuario/perfil, serializadores, vistas y rutas de autenticación, configuración JWT/CORS y conexión PostgreSQL.
- Frontend React: enrutamiento, contexto y servicios de autenticación, almacenamiento de sesión, páginas de acceso/registro/inicio y componentes compartidos.
- Aplicación Flutter: servicio y modelo de autenticación, persistencia/restauración de sesión, navegación splash/acceso/registro/inicio y cliente HTTP.
- Infraestructura: `requirements.txt`, `pubspec.yaml`, paquetes npm, Docker Compose, variables de entorno y configuración asociada deberán reducirse al conjunto realmente utilizado.
- La eliminación debe hacerse a partir de referencias verificadas para no borrar infraestructura base ni recursos compartidos que aún utilicen los tres clientes.
