## 1. Inventario y decisión de migración

- [x] 1.1 Registrar todos los imports, rutas, apps Django, servicios Docker, assets y dependencias alcanzables desde los puntos de entrada de backend, React y Flutter; verificar que cada archivo quede clasificado como conservar, adaptar o retirar y que no existan referencias no evaluadas.
- [x] 1.2 Inspeccionar de forma no destructiva el estado de PostgreSQL y las migraciones aplicadas, decidir entre migración incremental o recreación local, y verificar que la decisión documenta cómo preservar usuarios o que cuenta con autorización explícita antes de descartar datos.

## 2. Backend Django y contrato de autenticación

- [x] 2.1 Simplificar `settings.py`, autenticación DRF y rutas raíz a Django/DRF/SimpleJWT/CORS/PostgreSQL, retirando referencias a cookies JWT, backup, correo, Celery, Channels y módulos ausentes; verificar con `python manage.py check` que Django inicia sin errores de configuración o imports.
- [x] 2.2 Reducir el modelo y las migraciones al usuario necesario para autenticación, con correo normalizado y único y sin tablas de perfil/RBAC/bitácora; verificar mediante migración en una base de prueba que dos variantes de mayúsculas del mismo correo no pueden producir cuentas duplicadas y que las contraseñas quedan hasheadas.
- [x] 2.3 Implementar el registro activo e inmediato con campos requeridos, validación mínima y respuesta `{ user, access, refresh }`; verificar con pruebas API los casos correcto, correo duplicado, datos inválidos y ausencia de contraseña en la respuesta.
- [x] 2.4 Implementar inicio de sesión, renovación, perfil autenticado y cierre idempotente usando header Bearer; verificar con pruebas API credenciales válidas/inválidas, access vencido con refresh válido, sesión irrecuperable y acceso anónimo rechazado a `/api/auth/me/`.

## 3. Sesión y navegación web React

- [x] 3.1 Crear una capa única de almacenamiento que use `localStorage` con «Recordarme» y `sessionStorage` sin la opción, limpie el almacén alternativo y descarte claves heredadas ambiguas; verificar con pruebas del módulo que usuario/tokens siguen la modalidad elegida y que nunca se persiste la contraseña.
- [x] 3.2 Adaptar el cliente HTTP, servicio de autenticación y `AuthContext` para leer la modalidad activa, restaurar perfil, renovar una sola vez ante `401` y limpiar ambos almacenes al fallar o cerrar sesión; verificar con pruebas de solicitudes simuladas los flujos de restauración, renovación y limpieza aunque falle el servidor.
- [x] 3.3 Actualizar login y registro para incluir «Recordarme» en login, consumir el contrato final, autoautenticar el registro y redirigir siempre a `/`; verificar que ambos formularios muestran errores del API, bloquean envíos repetidos y llevan a inicio tras éxito.
- [x] 3.4 Reorganizar las rutas para dejar `/login` y `/register` públicas y `/` protegida, con loader durante restauración y redirección de usuarios autenticados o rutas obsoletas; verificar manualmente acceso directo sin sesión, regreso con sesión válida y ausencia de parpadeo de contenido protegido.
- [x] 3.5 Simplificar `HomePage` y sus componentes a bienvenida, datos básicos y cierre de sesión, eliminando enlaces o textos de dashboard/farmacia; verificar que un usuario autenticado solo ve el inicio previsto y que cerrar sesión regresa a `/login`.

## 4. Flujo móvil Flutter

- [x] 4.1 Adaptar modelo y servicio Flutter al payload reducido y hacer que registro devuelva una `AuthSession` igual que login; verificar con pruebas unitarias respuestas válidas, errores del backend y ausencia de campos heredados de roles/permisos.
- [x] 4.2 Simplificar `AuthSessionManager` para guardar, restaurar, renovar y limpiar tokens con `SharedPreferences`, eliminando imports y llamadas a tratamientos/notificaciones inexistentes; verificar con pruebas que restaura una sesión válida, renueva access vencido y limpia una sesión inválida o al cerrar sesión.
- [x] 4.3 Ajustar splash, login y registro para reemplazar la navegación por `HomePage` después del éxito y volver a `LoginPage` al salir; verificar con widget tests los destinos con sesión válida, sin sesión, tras registro y tras logout.
- [x] 4.4 Simplificar la pantalla móvil de inicio a bienvenida, datos básicos y cierre de sesión sin referencias de dashboard, roles o plantilla; verificar con widget test que renderiza al usuario autenticado y no expone opciones administrativas.

## 5. Eliminación de estructura heredada

- [x] 5.1 Eliminar de React páginas, rutas, componentes, hooks, servicios, datos y assets de administración, dashboard, backups, recuperación/verificación, farmacia, productos y escáner que hayan quedado sin referencias; verificar con `rg` que no persisten imports/rutas heredados y con `npm run build` que el frontend compila.
- [x] 5.2 Reducir `frontend/package.json` a paquetes realmente importados y regenerar su lockfile con npm; verificar con instalación limpia y `npm run build` que no faltan dependencias ni quedan paquetes funcionales heredados.
- [x] 5.3 Eliminar de Flutter páginas de verificación/recuperación, Firebase y configuración generada no usada, además de dependencias sin imports reales, conservando el scaffolding de plataforma; regenerar el lockfile y verificar con `flutter pub get`, `flutter analyze` y `flutter test`.
- [x] 5.4 Eliminar del backend RBAC, permisos, auditoría, rate limiting propio, KPIs, semillas/recursos de farmacia, Celery y configuraciones heredadas una vez retiradas sus referencias; verificar con búsqueda de símbolos, `python manage.py check`, migraciones y suite backend que no quedan imports rotos.
- [x] 5.5 Simplificar `backend/requirements.txt`, Dockerfile/entrypoint, `docker-compose.yml` y `.env.example` a PostgreSQL, backend y frontend; verificar con instalación de requisitos y `docker compose config` que no existen servicios, volúmenes ni variables huérfanas de Redis, worker, beat o backups.

## 6. Verificación integral

- [x] 6.1 Ejecutar todas las pruebas backend, las pruebas/build de React y `flutter analyze`/`flutter test`, y verificar que los tres conjuntos terminan correctamente sin imports, archivos generados o dependencias faltantes.
- [x] 6.2 Levantar PostgreSQL, Django y React con Docker Compose y verificar por API y navegador registro, login, refresh, perfil, logout, redirecciones protegidas y rechazo de credenciales inválidas.
- [x] 6.3 Verificar en un navegador real que una sesión con «Recordarme» sobrevive al cierre/reapertura, una sesión sin marcarlo no sobrevive al fin de la sesión del navegador y ninguna modalidad almacena la contraseña.
- [x] 6.4 Ejecutar la app Flutter contra el mismo backend y verificar registro con entrada directa a inicio, restauración al reabrir, renovación de token y cierre de sesión, documentando cualquier limitación de plataforma o entorno encontrada.
