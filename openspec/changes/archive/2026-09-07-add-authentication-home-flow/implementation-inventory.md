## Inventario de alcanzabilidad

Revisión realizada desde los puntos de entrada `backend/src/manage.py`, `frontend/src/main.jsx`, `mobile/lib/main.dart` y `docker-compose.yml`. No existe `.codegraph/`; se inspeccionaron imports, rutas, apps registradas, manifiestos y configuración nativa con `rg`.

### Backend

- **Conservar/adaptar:** `manage.py`, `config/settings.py`, `config/urls.py`, `config/asgi.py`, `config/wsgi.py`, `core/apps.py`, `core/urls.py`, `core/views.py`, `core/serializers.py`, migraciones, `core/management/commands/wait_for_db.py`, `requirements.txt`, Dockerfile y entrypoint.
- **Retirar tras actualizar entradas:** `config/celery.py`, import de Celery en `config/__init__.py`, autenticación por cookie, `core/audit.py`, `core/security.py`, `core/rbac.py`, `core/permissions.py`, `core/kpis_views.py`, modelos de perfil/roles/bitácora, comandos seed y media de farmacia.
- **Referencias inválidas:** `backup` figura en `INSTALLED_APPS` y rutas pero la app no existe.
- **Dependencias a retirar:** Pillow, requests, packaging, Celery/Redis, django-celery-beat, croniter, Channels/channels-redis y Daphne. El flujo final necesita Django, DRF, SimpleJWT, CORS, python-dotenv y psycopg.

### React

- **Conservar/adaptar:** entrada Vite, `App.jsx`, contexto, cliente/servicio auth, login, registro, inicio, `ProtectedRoute`, loader, shell de autenticación, utilidades y componentes UI alcanzados.
- **Retirar tras actualizar rutas:** páginas/componentes/hooks/servicios/datos de administración, dashboard, backups, recuperación/verificación, layouts heredados, `ProductCard`, escáner y asset de farmacia.
- **Dependencias a conservar:** React, React DOM, React Router, `class-variance-authority`, `clsx`, `tailwind-merge` y toolchain Vite/Tailwind.
- **Dependencias a retirar:** Stripe, html5-qrcode, jsPDF/autotable, Leaflet/react-leaflet y Recharts.

### Flutter

- **Conservar/adaptar:** scaffolding de plataformas, `main.dart`, `app.dart`, tema, configuración/red, modelo/servicio/gestor auth, splash, login, registro, inicio, blobs visuales y asset de icono.
- **Retirar tras actualizar imports:** recuperación/reset/verificación, `firebase_options.dart`, `firebase.json`, configuración Google Services y dependencias/plugins no alcanzados.
- **Dependencias a conservar:** Flutter, `google_fonts`, `http`, `shared_preferences`, lints y generador de iconos.
- **Dependencias a retirar:** Cupertino Icons, SVG, Stripe, PDF/printing, path provider, image picker, notificaciones/timezone, Firebase, record, mapas/geolocalización, WebSocket y permission handler.

### Infraestructura

- **Conservar/adaptar:** PostgreSQL, backend y frontend, volumen `postgres_data`, variables de conexión, puertos y CORS.
- **Retirar:** Redis, worker, beat, volumen `redis_data` y montaje de backups.
- No existe `.env` local. `docker compose ps --all` no encontró contenedores y `docker volume ls --filter name=sw1` no encontró volúmenes asociados.

## Decisión de migración

Se usará una migración inicial limpia/recreable para el entorno local porque no existe contenedor ni volumen PostgreSQL del proyecto que contenga usuarios. No se ejecutó ninguna eliminación de datos. Si posteriormente se conecta una base externa o aparece un volumen no inspeccionado, no se recreará: deberá conservarse `auth_user` y aplicarse una migración incremental separada después de auditar correos duplicados sin distinción de mayúsculas.

La base local se recreará con `docker compose up` y `python manage.py migrate`; esta decisión no autoriza eliminar una base externa ni un volumen futuro.
