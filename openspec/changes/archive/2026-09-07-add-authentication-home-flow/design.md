## Context

El repositorio ya tiene implementaciones parciales de autenticación en Django, React y Flutter, pero están acopladas a una plantilla anterior. React guarda siempre usuario y JWT en `localStorage`, por lo que hoy no distingue «Recordarme»; el registro activa usuarios solo en modo `DEBUG`; las rutas autenticadas separan usuarios comunes de un panel administrativo. Flutter ya posee splash, formularios y persistencia con `SharedPreferences`, aunque `AuthSessionManager` importa un servicio de tratamientos/notificaciones que no existe. Django referencia además una app `backup` inexistente y conserva RBAC, auditoría, KPIs, Celery, Redis y Channels.

No hay especificaciones base ni pruebas backend/frontend; la única prueba Flutter es la plantilla inicial. La base se considera preproducción/universitaria, de modo que puede simplificarse la migración inicial siempre que se documente cómo recrear la base local. Véanse `proposal.md` y las especificaciones de `user-authentication` y `authenticated-home` para el comportamiento requerido.

## Goals / Non-Goals

**Goals:**

- Dejar una sola API de autenticación consumible de la misma manera por React y Flutter.
- Mantener únicamente la seguridad básica que evita contraseñas en texto plano y acceso anónimo a recursos protegidos.
- Hacer explícita y comprobable la diferencia entre sesión web temporal y recordada.
- Reducir cada proyecto a un conjunto coherente de archivos y dependencias que compile sin referencias huérfanas.
- Conservar el scaffolding de plataforma de Flutter y la infraestructura mínima de Django, React, PostgreSQL y Docker.

**Non-Goals:**

- Verificación de correo, recuperación de contraseña, segundo factor, bloqueo por intentos, auditoría o revocación avanzada de JWT.
- Roles, permisos, backoffice, dashboard, KPIs, copias de seguridad o funciones del dominio de farmacia.
- Diseñar las funciones futuras de la pantalla de inicio; por ahora será un punto de entrada autenticado con datos básicos del usuario y cierre de sesión.
- Cambiar React o Flutter por otra tecnología, ni sustituir PostgreSQL.

## Decisions

### 1. Contrato JWT único y sencillo

Django conservará `djangorestframework-simplejwt` y expondrá solamente registro, inicio de sesión, renovación, perfil actual y cierre de sesión. Registro e inicio devolverán `{ user, access, refresh }`; renovación devolverá un nuevo `access`; perfil requerirá `Authorization: Bearer <access>`. Cierre de sesión será idempotente y los clientes siempre limpiarán su estado local.

Se usará el usuario estándar de Django con correo normalizado y único a nivel de validación y base de datos. El registro creará la cuenta activa, usará `create_user` para aplicar hash a la contraseña y devolverá inmediatamente tokens. El payload público del usuario se limitará a identificador, nombre, apellido y correo.

Alternativa considerada: conservar simultáneamente cookies JWT y headers Bearer. Se descarta porque duplica estados, complica CORS/CSRF y no aporta valor al cliente móvil ni al alcance académico. También se descarta usar sesiones Django porque obligaría a contratos diferentes entre navegador y Flutter.

### 2. «Recordarme» selecciona el almacenamiento web

React encapsulará el acceso a sesión en un único servicio:

- Con «Recordarme»: `user`, `access` y `refresh` se guardan en `localStorage`.
- Sin «Recordarme»: los mismos valores se guardan en `sessionStorage`.
- La contraseña nunca se guarda.
- Al cambiar de modalidad se limpia primero el almacenamiento alternativo para impedir estados duplicados.
- En el primer arranque de la versión nueva se limpian o migran las claves heredadas de `localStorage`; si no existe una marca inequívoca de modalidad, se invalidan para no convertir silenciosamente una sesión anterior en recordada.

El cliente HTTP leerá primero la modalidad activa, adjuntará el access token y, ante `401`, intentará una sola renovación compartida para evitar solicitudes paralelas. Si la renovación falla, se borrará toda la sesión.

Alternativa considerada: guardar el correo o la contraseña para rellenar el formulario. Se descarta porque «Recordarme» se interpreta como persistencia de sesión y almacenar la contraseña sería un riesgo innecesario.

### 3. Persistencia móvil separada, con el mismo contrato

Flutter mantendrá `SharedPreferences` para usuario y tokens, restaurará la sesión desde el splash y renovará el access token antes de expulsar al usuario. No se agregará un checkbox «Recordarme» móvil porque el requisito lo limita al navegador y la convención móvil es conservar la sesión hasta cerrar sesión. Se eliminarán del administrador de sesión las llamadas a notificaciones/tratamientos inexistentes.

Alternativa considerada: incorporar almacenamiento seguro nuevo. Se pospone por el alcance universitario y porque supondría una dependencia adicional; la limitación se documentará como riesgo.

### 4. Navegación con inicio protegido y sin dashboard

En React, `/login` y `/register` serán públicas y `/` quedará dentro de `ProtectedRoute`. `AuthProvider` resolverá restauración/renovación antes de decidir la ruta. Un usuario autenticado que llegue a login o registro irá a `/`; una ruta desconocida también resolverá hacia el flujo vigente según el estado de sesión.

En Flutter, `SplashPage` elegirá `HomePage` o `LoginPage`; tanto login como registro reemplazarán la pila por `HomePage` tras recibir tokens. Cerrar sesión reemplazará la pila por `LoginPage`.

La pantalla de inicio no simulará un dashboard: mostrará un saludo/datos básicos, un texto de bienvenida y cerrar sesión. Se retirarán referencias visuales a farmacia, administración y arquitectura de plantilla.

### 5. Limpieza guiada por alcanzabilidad

La implementación hará primero un inventario de imports, rutas, apps registradas y dependencias; después actualizará los puntos de entrada y solo entonces borrará lo que quede sin referencias. El resultado previsto es:

- **Backend — conservar/adaptar:** `manage.py`, configuración mínima (`settings.py`, `urls.py`, WSGI/ASGI simple), app `core`, autenticación JWT, migraciones y `wait_for_db`.
- **Backend — retirar:** RBAC, permisos, auditoría, rate limiting propio, KPIs, semillas de roles/usuarios, recursos de farmacia, Celery, Redis, Channels/Daphne, referencias a `backup`, correo/verificación/reset y configuración asociada.
- **React — conservar/adaptar:** entrada Vite, `App`, `AuthContext`, cliente/API de auth, login, registro, inicio, `ProtectedRoute`, loader y componentes UI realmente importados.
- **React — retirar:** páginas/rutas/componentes/hooks/servicios de administración, dashboard, backups, roles, bitácora, recuperación/verificación, `ProductCard`, escáner, imagen de farmacia y paquetes que queden sin imports (`Stripe`, scanner, PDF, mapas y gráficos, entre otros).
- **Flutter — conservar/adaptar:** scaffolding nativo, `main`, `app`, tema, configuración/API, modelo/servicio/gestor de auth, splash, login, registro, inicio y los assets genéricos necesarios.
- **Flutter — retirar:** verificación/reset/recuperación, Firebase y configuración generada, notificaciones y todas las dependencias sin imports reales. Los directorios generados de Android/iOS/web/desktop no se eliminan por ser parte del soporte multiplataforma.
- **Infraestructura — conservar/adaptar:** servicios Docker de PostgreSQL, backend y frontend, volúmenes necesarios y `.env.example`; eliminar worker, beat, Redis y volúmenes/comandos de backups.

Los lockfiles se regenerarán con los gestores correspondientes después de ajustar manifiestos; no se editarán manualmente para simular dependencias instaladas.

### 6. Migración de datos para un proyecto preproducción

El modelo final no necesitará `PerfilUsuario`, roles personalizados ni bitácora. Se actualizará la migración inicial o se añadirá una migración de eliminación según el estado real de la base local al comenzar la aplicación del cambio:

- Si la base es descartable y solo contiene datos de plantilla, se recreará desde cero con una migración inicial limpia.
- Si existen usuarios que deban conservarse, se creará una migración incremental que mantenga `auth_user`, elimine solo tablas heredadas y garantice la unicidad normalizada del correo antes de aplicar la restricción.

La elección no cambia la API ni las tareas funcionales; antes de ejecutar una recreación destructiva deberá verificarse el contenido y contar con autorización explícita.

## Risks / Trade-offs

- [JWT en almacenamiento web accesible a JavaScript aumenta el impacto de XSS] → Mantener UI sin HTML arbitrario, no almacenar contraseñas y aceptar el riesgo dentro del alcance académico.
- [Tokens móviles en `SharedPreferences` no ofrecen el aislamiento de un almacén seguro] → Documentar la limitación y encapsular el almacenamiento para poder sustituirlo después.
- [Eliminar módulos heredados puede romper imports ocultos o configuración Docker] → Actualizar puntos de entrada primero, buscar referencias residuales y ejecutar checks/builds en las tres capas antes de borrar definitivamente.
- [Unicidad de correo sensible a mayúsculas puede variar según PostgreSQL y validación] → Normalizar a minúsculas antes de guardar y respaldar la regla con una restricción/índice compatible con la versión de Django usada.
- [Los JWT emitidos antes del logout siguen siendo válidos hasta expirar] → Usar expiraciones razonables; la revocación/blacklist queda fuera del alcance declarado.
- [Una base existente puede depender de migraciones heredadas] → Inspeccionar la base antes de elegir entre migración incremental y recreación; no borrar datos automáticamente.

## Migration Plan

1. Registrar el inventario final de referencias y confirmar si la base PostgreSQL local contiene usuarios que deban preservarse.
2. Simplificar backend y migraciones manteniendo temporalmente el contrato de respuesta `{ user, access, refresh }`.
3. Adaptar React y Flutter al contrato final y validar los flujos antes de retirar endpoints/pantallas heredados.
4. Eliminar archivos y dependencias sin referencias, regenerar lockfiles y simplificar Docker/entorno.
5. Ejecutar migraciones/checks, pruebas de API, build React y análisis/pruebas Flutter; realizar pruebas manuales de sesión temporal y recordada en navegador.
6. Si es necesario revertir, restaurar los archivos/manifiestos desde control de versiones y usar la copia o base anterior; no se intentará reconstruir tablas eliminadas sin respaldo.
