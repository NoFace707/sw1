## 1. Prerrequisitos y base técnica

- [x] 1.1 Confirmar que `add-authentication-home-flow` está aplicado o que existe un contrato equivalente de registro, login, refresh, perfil, logout y ruta web protegida; verificar con pruebas API y navegación que un usuario autenticado llega a `/` antes de modificar el inicio.
- [x] 1.2 Crear la app/módulos Django del modelador y la estructura React por dominios (`projects`, `model`, `diagrams`, `sync`, `interchange`, `ai`); verificar que `python manage.py check`, las pruebas backend y `npm run build` siguen pasando con el scaffolding vacío.
- [x] 1.3 Añadir dependencias mínimas del editor, XML seguro, PWA, IndexedDB, Channels y Redis, y actualizar Docker Compose/variables de entorno; verificar con instalaciones limpias, `docker compose config` y conexión de salud a PostgreSQL/Redis.
- [x] 1.4 Configurar suites backend y frontend con fixtures reutilizables y pruebas de contrato, manteniendo las pruebas de autenticación existentes; verificar que un comando documentado ejecuta ambas suites desde cero.

## 2. Dominio de proyectos y modelo UML

- [x] 2.1 Implementar modelos/migraciones para proyecto, membresía e invitación con UUID, propietario y roles `owner/editor/viewer`; verificar constraints de un propietario, membresía única y borrado protegido mediante pruebas de modelo.
- [x] 2.2 Implementar modelos/migraciones para paquetes, elementos, relaciones, diagramas, nodos y aristas separando semántica de presentación; verificar que un elemento puede tener varias vistas y que borrar una vista no elimina el elemento.
- [x] 2.3 Implementar modelos/migraciones para operaciones, snapshots, conflictos, identificadores externos y propuestas de IA; verificar unicidad de `operation_id`, revisión monotónica y persistencia de origen/autor con pruebas transaccionales.
- [x] 2.4 Crear el registro versionado de metaclases, propiedades, relaciones y paletas UML 2.5.1; verificar fixtures positivos/negativos para todos los tipos declarados y que backend/frontend reciben la misma versión del registro.
- [x] 2.5 Implementar validación autoritativa de identidad, referencias, propiedades obligatorias y compatibilidad de relaciones; verificar que errores bloqueantes y advertencias se clasifican y localizan en pruebas del validador.
- [x] 2.6 Implementar el pipeline transaccional de operaciones idempotentes con `base_revision`, valores anterior/nuevo y reglas de conflicto; verificar cambios independientes, reenvíos, mismo campo y eliminar-frente-a-editar mediante pruebas concurrentes.
- [x] 2.7 Implementar snapshots periódicos y protegidos antes de importación, IA y restauración; verificar reconstrucción equivalente desde snapshot más operaciones y restauración como nueva revisión sin borrar historial.

## 3. APIs y espacio inicial de proyectos

- [x] 3.1 Crear APIs de listar, crear, abrir, renombrar y eliminar proyectos con control de membresía; verificar que cada rol recibe solo las operaciones permitidas y que usuarios ajenos obtienen respuesta no reveladora.
- [x] 3.2 Crear APIs de paquetes, elementos, relaciones, diagramas, operaciones desde revisión e historial; verificar paginación, revisión consistente y rechazo de payloads UML inválidos con pruebas API.
- [x] 3.3 Reemplazar el inicio provisional por la lista de proyectos recientes y acciones crear/importar/unirse; verificar estados vacío, cargando, error y lista poblada en pruebas de componentes y navegador.
- [x] 3.4 Crear el shell del editor con explorador de modelo, pestañas de diagramas, paleta contextual, lienzo, inspector, historial y barra de estado; verificar navegación con teclado básica, layouts responsivos y carga de un fixture de proyecto.

## 4. Motor visual UML 2.5.1

- [x] 4.1 Integrar el lienzo de nodos/SVG con zoom, paneo, selección, selección múltiple, mover, redimensionar, conectar, copiar, eliminar y autoencuadre; verificar cada interacción con pruebas de componente y un escenario end-to-end.
- [x] 4.2 Conectar todas las ediciones del lienzo e inspector al pipeline de operaciones y crear deshacer/rehacer mediante operaciones inversas; verificar que no se revierten cambios posteriores de otro autor y que los conflictos quedan visibles.
- [x] 4.3 Implementar clases, objetos, paquetes y casos de uso con sus elementos, relaciones, notación y propiedades esenciales; verificar creación, edición, guardado, reapertura y validación mediante un fixture por tipo.
- [x] 4.4 Implementar componentes, despliegue, estructura compuesta y perfiles con sus elementos, relaciones, notación y propiedades esenciales; verificar creación, edición, guardado, reapertura y validación mediante un fixture por tipo.
- [x] 4.5 Implementar actividades y máquinas de estados con nodos, transiciones, guardas y regiones soportadas; verificar creación, edición, guardado, reapertura y validación mediante un fixture por tipo.
- [x] 4.6 Implementar secuencia y comunicación con participantes, mensajes, orden y fragmentos soportados; verificar que ambos diagramas conservan el orden semántico y reabren de forma equivalente en sus fixtures.
- [x] 4.7 Implementar visión general de interacción y temporización con sus vistas y restricciones temporales soportadas; verificar creación, edición, guardado, reapertura y validación mediante un fixture por tipo.
- [x] 4.8 Implementar eliminación diferenciada de vista frente a elemento semántico, mostrando análisis de impacto; verificar que cancelar no modifica nada y confirmar actualiza todas las vistas/relaciones afectadas.
- [x] 4.9 Implementar clasificación CIM/PIM/PSM/no especificado y trazabilidad navegable entre niveles; verificar enlaces PIM→PSM, navegación inversa y reporte de elementos sin clasificar.
- [x] 4.10 Crear una matriz de cobertura que relacione cada tipo de diagrama con metaclases, relaciones, propiedades, validaciones y fixtures implementados; verificar que ninguna capacidad se marca completa mientras exista una celda obligatoria pendiente.

## 5. Invitaciones, colaboración e historial

- [x] 5.1 Implementar generación criptográfica, hash, vencimiento, límite de usos y revocación de códigos de invitación en una transacción; verificar códigos válidos, expirados, agotados, revocados y consumos simultáneos.
- [x] 5.2 Crear UI para generar/copiar/revocar invitaciones, unirse con código y administrar miembros/roles; verificar que propietario, editor, lector y usuario ajeno ven únicamente acciones autorizadas.
- [x] 5.3 Implementar tickets WebSocket efímeros, consumidores Channels y autorización continua por membresía; verificar conexión válida, ticket reutilizado/vencido, acceso retirado y proyecto ajeno.
- [x] 5.4 Difundir operaciones confirmadas por grupos de proyecto y recuperar faltantes por revisión después de reconectar; verificar con dos clientes que cambios independientes convergen y reenvíos no se duplican.
- [x] 5.5 Implementar presencia efímera con usuario, diagrama/selección y timeout; verificar entrada, cambio de foco, desconexión limpia y desaparición tras pérdida abrupta de conexión.
- [x] 5.6 Implementar UI de conflictos con alternativas, autor/revisión y resolución como nueva operación; verificar mismo campo y eliminar-frente-a-editar sin pérdida silenciosa.
- [x] 5.7 Implementar historial consultable y restauración exclusiva del propietario como nueva revisión; verificar atribución de usuario/importación/IA/restauración y que una restauración puede deshacerse mediante otra revisión.

## 6. Modo offline y sincronización

- [x] 6.1 Configurar manifest, iconos, service worker y precache del shell como PWA sin cachear respuestas privadas del API; verificar instalación y carga del shell offline mediante auditoría PWA y prueba de navegador.
- [x] 6.2 Implementar IndexedDB separado por usuario/proyecto para snapshot, revisión, cola, conflictos y borradores; verificar aislamiento entre dos cuentas, persistencia tras recarga y manejo de error de cuota.
- [x] 6.3 Permitir marcar/abrir proyectos para offline y editar contra la réplica local con indicador guardado/pendiente/conflicto; verificar reapertura sin red y supervivencia de operaciones tras cerrar el navegador.
- [x] 6.4 Implementar sincronización de operaciones remotas y cola local al reconectar con reintentos idempotentes; verificar reconexión sin conflicto, access renovado y convergencia con otro cliente.
- [x] 6.5 Implementar reconciliación visible de conflictos offline usando las mismas reglas del servidor; verificar alternativas conservadas y resolución posterior sincronizada en pruebas con dos ramas desde una revisión común.
- [x] 6.6 Conservar la cola y exigir reautenticación si vence la sesión, y generar un archivo de recuperación si se retiró el permiso; verificar que ningún cambio se envía bajo otra identidad ni se pierde al recibir `401/403`.
- [x] 6.7 Deshabilitar con explicación presencia, invitaciones, importación de servidor e IA durante offline y conservar borradores de prompts; verificar que el modelado local continúa disponible.

## 7. Intercambio OMG XMI 2.5.1

- [x] 7.1 Definir el modelo intermedio de intercambio y mapeos bidireccionales para cada metaclase/relación soportada; verificar equivalencia semántica de ida y vuelta con fixtures de los catorce diagramas.
- [x] 7.2 Implementar parser XML seguro con entidades externas, DTD y red deshabilitados, además de límite de 10 MB; verificar rechazo de XXE, XML malformado, archivo excesivo y referencias rotas sin cambiar el proyecto.
- [x] 7.3 Implementar lector UML 2.5.1/XMI 2.5.1 y UMLDI, produciendo informe previo de errores, advertencias y pérdidas; verificar importación transaccional y disposición automática cuando falte presentación.
- [x] 7.4 Implementar escritor OMG UML 2.5.1/XMI 2.5.1 con namespaces, identificadores y UMLDI soportado; verificar XML bien formado, validación interna y reimportación semánticamente equivalente.
- [x] 7.5 Implementar UI de importar, revisar informe, confirmar/cancelar y seleccionar actualizar o copiar al reimportar identificadores conocidos; verificar que cancelar/fallar conserva la revisión anterior y confirmar crea snapshot recuperable.

## 8. Compatibilidad con Sparx Enterprise Architect

- [ ] 8.1 Obtener y versionar fixtures XMI 2.1 producidos por Sparx Enterprise Architect 17.2 para cada familia de diagramas, sin incluir datos sensibles; verificar que cada fixture abre en EA y documenta su versión/opciones de exportación.
- [x] 8.2 Implementar lector del perfil Sparx UML 2.5.1/XMI 2.1 y extensiones mínimas de diagramas, preservando extensiones desconocidas seguras como datos opacos; verificar importación de fixtures y reporte explícito de omisiones.
- [x] 8.3 Implementar escritor del perfil Sparx Enterprise Architect XMI 2.1 y selector de destino diferenciado del perfil OMG; verificar namespaces/metadatos y reimportación en la aplicación.
- [ ] 8.4 Ejecutar web→XMI→Enterprise Architect 17.2 para los fixtures de las cuatro familias y verificar que EA abre paquetes, elementos, relaciones y diagramas soportados, registrando cualquier pérdida visual.
- [ ] 8.5 Ejecutar Enterprise Architect 17.2→XMI→web y una ida y vuelta completa; verificar por comparación automatizada que identidades comparables, nombres, propiedades esenciales y relaciones permanecen equivalentes.
- [x] 8.6 Publicar la matriz de compatibilidad OMG/Sparx y el informe de limitaciones visible desde la UI; verificar que el usuario conoce el perfil y pérdidas posibles antes de exportar.

## 9. Asistente de IA

- [x] 9.1 Implementar adaptador backend configurable por URL, clave y modelo, con timeout, límites y modo deshabilitado; verificar proveedor simulado exitoso, no configurado, error, límite y timeout sin modificar modelos.
- [x] 9.2 Construir contexto mínimo autorizado desde proyecto/diagrama/selección, excluyendo tokens, códigos y proyectos ajenos; verificar mediante pruebas de privacidad el payload exacto enviado al proveedor simulado.
- [x] 9.3 Definir esquema estructurado de propuestas y convertir su salida a operaciones validadas por el registro UML; verificar generación válida, JSON inválido, metaclase desconocida y más de 200 operaciones.
- [x] 9.4 Crear panel de prompt y vista previa de diferencias con supuestos, advertencias y selección parcial; verificar crear diagrama, modificar selección, cancelar y aceptar parcialmente sin aplicación prematura.
- [x] 9.5 Aplicar operaciones confirmadas mediante el pipeline colaborativo y snapshot previo, atribuidas al usuario y marcadas como IA; verificar permisos, conflictos de revisión, historial y restauración.
- [x] 9.6 Implementar explicación de modelos y sugerencias de consistencia diferenciadas del validador determinista; verificar respuestas basadas en el contexto autorizado y bloqueo de sugerencias que no superan validación.
- [x] 9.7 Permitir explicación a lectores pero bloquear la aplicación de cambios, y degradar limpiamente offline o sin proveedor; verificar permisos y que el editor manual nunca depende de la IA.

## 10. Límites, integración y entrega

- [x] 10.1 Aplicar límites configurables de tamaño XMI, elementos, colaboradores y operaciones IA, más compactación/retención de snapshots; verificar respuestas claras en límites y conservación de snapshots protegidos.
- [x] 10.2 Ejecutar pruebas de autorización sobre todas las APIs, descargas y canales WebSocket para propietario/editor/lector/ajeno; verificar que no existe lectura o mutación transversal entre proyectos.
- [ ] 10.3 Ejecutar pruebas end-to-end con dos navegadores en línea, uno desconectado y reconectado, incluyendo conflictos, historial e invitación; verificar convergencia final y ausencia de operaciones duplicadas o perdidas.
- [x] 10.4 Ejecutar `python manage.py check`, migraciones desde base vacía, suite backend, suite frontend, `npm run build` y `docker compose config`; verificar que todos terminan correctamente en un entorno limpio.
- [x] 10.5 Documentar arquitectura, formato de operación, matriz UML, perfiles XMI, procedimiento Enterprise Architect, modo offline, variables IA y limitaciones; verificar que otro integrante puede levantar el sistema y completar un intercambio guiándose solo por la documentación.
- [ ] 10.6 Realizar aceptación funcional de los catorce diagramas, MDA, invitaciones, colaboración, offline, ambos perfiles XMI e IA; verificar cada escenario de las cinco especificaciones y adjuntar evidencia de los casos manuales de Enterprise Architect.

## 11. Estabilización y simplificación de uso

- [x] 11.1 Servir el backend mediante Daphne/ASGI, añadir heartbeat, corregir invitaciones y actualizar clientes por operaciones confirmadas; verificar presencia y edición visible entre dos navegadores.
- [x] 11.2 Crear proyecto y primer diagrama atómicamente, habilitar renombrado directo de proyecto/diagrama/figura y simplificar la interfaz visible; verificar persistencia, cancelación y rollback de errores.
- [x] 11.3 Implementar paleta lateral UML/General/Flechas/Entidad-Relación, drag-and-drop y contratos visuales validados; verificar persistencia, colaboración y omisión explícita en XMI.
- [x] 11.4 Añadir PNG/SVG, importación atómica desde inicio, fusión confirmada desde editor y perfil EA oculto por flag; verificar archivos, errores sin proyectos huérfanos y resumen de fusión.
- [ ] 11.5 Completar aceptación E2E Chromium/Firefox y validar ida y vuelta real con Enterprise Architect 17.2; habilitar el perfil solo si supera los criterios documentados.
- [x] 11.6 Estabilizar la lectura bloqueante de Redis con redis-py 8 para que un WebSocket inactivo supere el intervalo de sondeo sin desconectarse; verificar conexión sostenida, heartbeat posterior y ausencia de `Timeout reading from redis` en los logs.

## 12. Editor compacto tipo draw.io

- [x] 12.1 Reorganizar el editor con cabecera de 48 px, paleta lateral, diálogo de diagrama, colaboradores emergentes, inspector contextual plegable y estado inferior; verificar ausencia de formularios permanentes y comportamiento adaptable.
- [x] 12.2 Implementar el renderizador SVG compartido y las bibliotecas General, Flujo y Entidad-Relación con dimensiones iniciales y proporciones correctas; verificar catálogo y contratos en pruebas frontend/backend.
- [x] 12.3 Implementar conectores persistentes con cuatro handles, rutas, estilos, marcadores UML/ER, edición contextual, eliminación y compatibilidad con propiedades antiguas; verificar creación y reapertura E2E.
- [x] 12.4 Conservar semántica, colaboración, historial e intercambio, omitiendo figuras auxiliares solo de XMI y manteniéndolas en PNG/SVG; verificar suites existentes y advertencias de exportación.
- [ ] 12.5 Completar aceptación visual manual de todas las figuras y conexiones en 1024×768, 1366×768 y 1920×1080, además del escenario E2E de arrastre desde los cuatro lados sin solapamiento.
- [x] 12.6 Ampliar exclusivamente el catálogo UML de los catorce diagramas con variantes semánticas, tamaños y geometrías específicas; verificar registro backend, 24 pruebas frontend, build y creación E2E de variantes.
- [x] 12.7 Añadir Actor y una clase con compartimento de atributos preconfigurado a la paleta del diagrama de clases; verificar persistencia semántica, render y cobertura automatizada.
- [x] 12.8 Permitir editar, añadir y eliminar atributos de cualquier Clase UML desde el inspector, con crecimiento automático, validación backend, persistencia y sincronización; verificar pruebas unitarias, API y E2E Chromium.

## 13. Entrada por voz para el asistente

- [x] 13.1 Añadir transcripción autenticada por proyecto mediante un proveedor Whisper compatible, con configuración independiente, formatos permitidos, límite de tamaño y descarte inmediato del audio; verificar éxito, autorización, configuración ausente, tipo inválido, exceso de tamaño y error remoto sin mutaciones.
- [x] 13.2 Añadir grabación web con permiso explícito, estados grabando/transcribiendo, límite temporal y texto editable antes de enviar; verificar cancelación, error de micrófono y que transcribir no crea propuestas.
- [x] 13.3 Documentar variables y ejecutar suites backend/frontend y build web relacionados con voz.
- [x] 13.4 Integrar `faster-whisper` local en Docker con CPU `int8`, modelo multilingüe, caché persistente, precarga, archivo temporal eliminado y fallback remoto opcional; verificar inferencia simulada, limpieza, configuración, suite backend y consumo sin cambios desde web/móvil.
