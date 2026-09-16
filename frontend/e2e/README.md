# E2E multi-navegador

Este harness prepara la verificación que requiere dos motores de navegador (`chromium` y `firefox`) y dos clientes independientes por prueba. No se ejecuta en la suite Node básica porque necesita `@playwright/test` y los navegadores instalados.

## Preparación

```powershell
npm install -D @playwright/test
npx playwright install chromium firefox
npm run build
npm run test:e2e
```

La configuración levanta el frontend de preview y Django con SQLite de prueba. Los usuarios y el proyecto son sintéticos y se crean exclusivamente en la base local.

## Escenarios que debe ampliar la aceptación

- Cambios independientes y operación duplicada.
- Conflicto de la misma propiedad e historial.
- Invitación válida, revocada, agotada y cambio de rol.
- Edición offline, reconexión, `401/403` y archivo de recuperación.
- Exportación/importación OMG y comparación con `python -m modeling.interchange_compare archivo_a.xmi archivo_b.xmi`.

La ejecución del harness aporta evidencia para 10.3, pero no la marca automáticamente en `tasks.md`.
