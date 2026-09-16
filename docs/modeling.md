# Modelador UML colaborativo

## Arranque

1. Copia `.env.example` a `.env` y ajusta PostgreSQL, Redis y `DJANGO_ALLOWED_HOSTS`.
2. Ejecuta `docker compose up -d --build`.
3. Abre `http://localhost:5180`, registra una cuenta y pulsa «Nuevo proyecto» para entrar directamente al primer diagrama.
4. `npm run verify` ejecuta `manage.py check`, las pruebas Django, las pruebas Node y el build PWA.

El backend Django/PostgreSQL conserva el modelo semántico UML. React/React Flow conserva las vistas de presentación; una misma clase puede aparecer en varios diagramas. Channels + Redis emiten presencia y eventos del proyecto. IndexedDB se separa por `userId` y `projectId`.

## Operaciones y revisiones

Cada mutación confirmada usa `operation_id`, `base_revision`, valores anterior/nuevo y una revisión de servidor monotónica. Reenviar el mismo `operation_id` es idempotente. Las colisiones de un mismo campo quedan en `SyncConflict`. Hay snapshots manuales, periódicos y automáticos antes de importar, aplicar IA o restaurar. Restaurar crea una nueva operación y no borra el historial. Los movimientos de nodos offline se encolan como actualizaciones de posición; un `401` exige renovar sesión y un `403` conserva la operación en el archivo de recuperación.

## UML e intercambio

El registro compartido se sirve en `GET /api/modeling/registry/` y está versionado como `uml-2.5.1-subset-2`. Se exponen catorce tipos de diagrama UML 2.5.1 y una paleta ampliada de elementos específicos por tipo. La exportación ofrece:

La matriz ejecutable de cobertura está en `frontend/src/domains/modeling/coverageMatrix.js` y relaciona cada tipo con metaclases, relaciones, propiedades, validación y fixture. La columna `complete` se calcula a partir de todas las celdas obligatorias; por diseño, una fila con cualquier capacidad pendiente nunca puede aparecer como completa.

| Familia | Tipos registrados | Estado actual |
| --- | --- | --- |
| Estructura | class, object, component, composite_structure, package, deployment, profile | Catálogo ampliado, variantes semánticas y vistas persistidas |
| Comportamiento | use_case, activity, state_machine | Acciones, nodos, regiones y pseudoestados especializados |
| Interacción | sequence, communication, interaction_overview, timing | Líneas de vida estereotipadas, fragmentos, observaciones y restricciones |

- `omg-xmi-2.5.1`: namespaces OMG UML/XMI.
- `sparx-ea-xmi-2.1`: perfil experimental para Sparx Enterprise Architect, oculto mientras no exista aceptación real con EA 17.2.

La interfaz pública ofrece OMG XMI 2.5.1. El perfil de Sparx solo aparece si se inicia el frontend con `VITE_ENABLE_EA_INTERCHANGE=true`; no debe habilitarse hasta completar las pruebas reales con EA 17.2. Las figuras auxiliares General/Entidad–Relación y sus flechas se conservan en el lienzo y en colaboración, pero no se presentan como semántica UML en XMI; el diálogo de exportación avisa cuando existen omisiones.

El parser usa `defusedxml`, desactiva entidades externas y rechaza archivos mayores de 10 MiB. Desde inicio, `POST /api/modeling/projects/import/` valida e importa atómicamente para no dejar proyectos vacíos. Dentro del editor se usa `preview=true` y `mode=update` para mostrar coincidencias y advertencias antes de confirmar la fusión. Cancelar no muta el proyecto.

En Enterprise Architect: `Publish/Import-Export/Import Package from XMI`, selecciona XMI 2.1 y el archivo descargado; para comparar el flujo inverso usa `Export Package to XMI` y carga el archivo desde el diálogo de importación del modelador con el perfil Sparx.

Para preparar evidencia reproducible de interoperabilidad se incluye un comparador semántico en `backend/src/modeling/interchange_compare.py`, junto con el manifiesto de fixtures de Enterprise Architect en `docs/enterprise-architect/fixtures-manifest.md`. La aceptación funcional y el arnés E2E multi-navegador están documentados en `docs/acceptance/uml-acceptance-checklist.md` y `frontend/e2e/README.md`.

## IA

Configura `AI_BASE_URL`, `AI_API_KEY` opcional, `AI_MODEL`, `AI_TIMEOUT_SECONDS` y `AI_MAX_OPERATIONS`. Los límites generales son `XMI_MAX_BYTES`, `MAX_PROJECT_ELEMENTS`, `MAX_PROJECT_RELATIONSHIPS`, `MAX_COLLABORATORS`, `MODEL_SNAPSHOT_INTERVAL` y `SNAPSHOT_RETENTION`. Sin URL, la IA queda deshabilitada sin afectar el editor manual. El contexto enviado se limita al proyecto autorizado, la selección y el registro UML. La respuesta debe ser JSON estructurado; se valida y se muestra como propuesta. `POST /api/modeling/projects/:id/ai/explain/` devuelve explicación, advertencias y sugerencias validadas sin mutar el modelo. Solo la confirmación explícita crea operaciones con origen `ai`, después de un snapshot.

## Invitaciones y colaboración

Los códigos se generan criptográficamente, se almacena únicamente su hash y el secreto completo se muestra una sola vez. Pueden vencer, limitar usos o revocarse, y la UI distingue esos estados. Los tickets WebSocket duran 60 segundos y son de un solo uso; el servidor vuelve a comprobar la membresía en cada heartbeat de 10 segundos. El cliente reintenta la conexión con backoff y elimina la presencia que no recibe actualización durante 30 segundos. Los lectores pueden observar, pero no mutar. En la pantalla de proyectos se debe pulsar «Preparar para offline» para habilitar una réplica local; sin esa marca no se abre el proyecto inicialmente en modo avión.

## Límites conocidos

La aplicación cubre un subconjunto semántico ampliado de UML 2.5.1 y una exportación XMI interoperable básica. Las reglas avanzadas particulares de cada notación, reconciliación offline completa, fixtures generados por EA y aceptación manual con Enterprise Architect siguen siendo trabajo pendiente del cambio OpenSpec.
