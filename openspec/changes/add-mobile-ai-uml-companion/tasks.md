## 1. Prerrequisitos y contratos compartidos

- [ ] 1.1 Aplicar y verificar `add-authentication-home-flow` antes de este cambio, comprobando con pruebas backend, build React y `flutter test` que la sesión móvil llega al inicio autenticado.
- [ ] 1.2 Aplicar y verificar `add-collaborative-ai-uml-modeler`, comprobando que proyectos, permisos, invitaciones, snapshots, operaciones, conflictos, historial, WebSocket e IA remota funcionan desde web.
- [ ] 1.3 Inventariar imports, rutas, servicios y dependencias actuales de `mobile` y documentar qué se conserva, adapta o retira; verificar que ningún archivo marcado para retirar siga alcanzable desde `main.dart` o configuración nativa.
- [ ] 1.4 Versionar los esquemas compartidos de snapshot, registro UML, operación, conflicto, propuesta IA, reglas, blueprint y artefacto; verificar cada JSON Schema con ejemplos válidos e inválidos.
- [ ] 1.5 Añadir fixtures contractuales consumibles por Python y Dart para proyectos, los catorce diagramas, permisos y operaciones; verificar que ambos deserializadores producen IDs, revisiones y tipos equivalentes.
- [ ] 1.6 Definir compatibilidad y respuesta de degradación para versiones de contrato desconocidas; verificar que Flutter conserva solo lectura y muestra actualización requerida sin perder el snapshot local.

## 2. API y persistencia backend para móvil

- [ ] 2.1 Añadir migraciones aditivas para manifiestos, versiones de reglas/plantillas, trabajos de generación y artefactos; verificar migración hacia adelante/atrás sobre una base de prueba sin alterar proyectos existentes.
- [ ] 2.2 Implementar el endpoint de listado móvil de proyectos con permiso, fecha y estado de acceso; verificar filtrado por membresía y ausencia de datos de proyectos ajenos.
- [ ] 2.3 Implementar el endpoint de snapshot normalizado con semántica, geometría, estilos, referencias y revisión; verificar respuestas para fixtures de cada familia UML.
- [ ] 2.4 Implementar endpoints incrementales de operaciones e historial reutilizando el pipeline colaborativo; verificar idempotencia, orden de revisión y atribución `ai-mobile-api`/`ai-mobile-local`.
- [ ] 2.5 Publicar manifiestos versionados de registro UML, reglas, modelo GGUF y plantillas con hash y compatibilidad; verificar rechazo de versiones/hash no autorizados.
- [ ] 2.6 Aplicar la matriz propietario/editor/lector a todos los endpoints móviles; verificar con pruebas parametrizadas lectura, IA, confirmación, exportación, invitaciones e historial.
- [ ] 2.7 Añadir límites configurables para snapshots, colas, propuestas y artefactos móviles; verificar respuestas claras y sin escrituras parciales al excederlos.

## 3. Base Flutter y almacenamiento estructurado

- [ ] 3.1 Reorganizar Flutter por capacidades `projects`, `viewer`, `collaboration`, `offline`, `ai`, `expert` y `generation`, conservando autenticación; verificar `flutter analyze` sin imports huérfanos.
- [ ] 3.2 Añadir dependencias fijadas para HTTP/WebSocket, Drift/SQLite, rutas de soporte, conectividad, descarga reanudable, hash, ZIP y compartir; verificar resolución limpia de dependencias y builds Android/iOS.
- [ ] 3.3 Implementar DTOs y mapeadores de los contratos compartidos con manejo de tipos desconocidos; verificar round-trip contra los fixtures JSON.
- [x] 3.4 Crear el esquema Drift para cuentas lógicas, proyectos, snapshots, reglas, propuestas, operaciones, conflictos, manifiestos y artefactos; verificar migración y restricciones mediante pruebas de base temporal.
- [x] 3.5 Implementar repositorios locales/remotos y casos de uso sin exponer mutaciones manuales desde el visor; verificar mediante prueba de arquitectura o imports que solo el flujo confirmado de operaciones puede escribir el modelo.
- [x] 3.6 Aislar consultas y rutas internas por `user_id`/`project_id` y cerrar repositorios al cambiar sesión; verificar que una segunda cuenta no enumera ni abre datos de la primera.
- [x] 3.7 Implementar observación de conectividad y estado `online`, `offline`, `syncing`, `pending` y `conflict`; verificar transiciones simulando pérdida y recuperación de red.

## 4. Inicio de proyectos y visor UML móvil

- [x] 4.1 Sustituir el inicio provisional por listado/búsqueda de proyectos con permiso, última modificación y estado local; verificar actualización online y apertura de un proyecto autorizado.
- [x] 4.2 Implementar selección de diagramas y carga desde snapshot remoto o réplica local; verificar mensajes correctos cuando un proyecto no fue preparado para offline.
- [x] 4.3 Construir la superficie read-only con `InteractiveViewer` y renderizado propio de nodos, aristas, etiquetas y geometría; verificar paneo/zoom sin modificar coordenadas del fixture.
- [x] 4.4 Implementar notación para clases, objetos, paquetes y casos de uso; verificar golden tests y propiedades semánticas de los cuatro tipos.
- [x] 4.5 Implementar notación para componentes, despliegue, estructura compuesta y perfiles; verificar golden tests y propiedades semánticas de los cuatro tipos.
- [x] 4.6 Implementar notación para actividades y máquinas de estados; verificar golden tests de nodos, transiciones, guardas y regiones soportadas.
- [x] 4.7 Implementar notación para secuencia, comunicación, visión general de interacción y temporización; verificar golden tests de lifelines, mensajes y ejes temporales soportados.
- [x] 4.8 Añadir marcador preservador para metaclases/estilos desconocidos; verificar que el ID y propiedades sobreviven a abrir, cerrar y sincronizar aunque no exista renderizador.
- [x] 4.9 Implementar ajuste a pantalla, navegación equivalente a minimapa, selección, inspector y salto por referencias; verificar interacción táctil en tamaños compactos y accesibilidad básica.
- [x] 4.10 Implementar búsqueda por nombre/tipo y centrado del resultado en su diagrama; verificar resultados entre múltiples diagramas y referencias compartidas.
- [x] 4.11 Eliminar u ocultar cualquier acción de crear, arrastrar, redimensionar, conectar, renombrar o borrar; verificar con widget tests que gestos largos/arrastre no cambian el snapshot.
- [x] 4.12 Mostrar revisión y estados actualizado/offline/pendiente/conflicto; verificar que una revisión WebSocket nueva no se presenta como edición local.

## 5. Colaboración e invitaciones

- [ ] 5.1 Implementar unión por código pegado o escrito; verificar éxito, vencido, agotado, revocado y desconocido sin filtrar datos del proyecto.
- [ ] 5.2 Implementar listado de miembros y representación de roles propietario/editor/lector; verificar que acciones visibles coinciden con la matriz de permisos.
- [ ] 5.3 Implementar creación de invitación con rol, vencimiento y usos para propietarios; verificar que el código solo aparece tras confirmación del servidor.
- [ ] 5.4 Integrar compartir y revocar invitaciones sin incluir tokens de sesión; verificar el payload entregado a la hoja de compartir y la revocación inmediata.
- [ ] 5.5 Integrar ticket WebSocket, presencia y recepción de operaciones, con recuperación REST desde la última revisión; verificar reconexión sin omitir ni duplicar cambios.
- [ ] 5.6 Mostrar historial con autor, origen IA, operaciones y revisiones; verificar que una propuesta móvil confirmada aparece igual en web y móvil.
- [ ] 5.7 Manejar retiro de acceso en vivo cerrando sincronización y bloqueando confirmaciones; verificar que el proyecto deja de abrirse online y la copia local sigue las reglas de recuperación.

## 6. Sistema experto UML, MDA y Spring

- [x] 6.1 Definir el formato declarativo de reglas con condición, severidad, evidencia, pregunta, reparación y mapeo; verificarlo contra su JSON Schema.
- [x] 6.2 Crear la base inicial versionada para identidad, tipos y relaciones UML 2.5.1, trazabilidad MDA, permisos, límites y mapeos Spring; verificar cobertura de cada requisito mediante un catálogo de reglas.
- [x] 6.3 Implementar el evaluador autoritativo Python con diagnósticos ordenados y reparaciones permitidas; verificar fixtures positivos, negativos y resultados deterministas.
- [ ] 6.4 Implementar el evaluador Dart equivalente y almacenamiento atómico de actualizaciones firmadas; verificar los mismos fixtures y conservación de la versión anterior ante actualización inválida.
- [x] 6.5 Implementar detección previa de datos faltantes y generación de preguntas/supuestos; verificar casos ambiguos de multiplicidad, identificador, tipo y nivel MDA.
- [x] 6.6 Implementar validación de propuestas por identidad, permiso, revisión, tipos, relaciones y límites; verificar que operaciones inválidas no habilitan confirmación.
- [ ] 6.7 Implementar reparación determinista limitada a normalización, derivados y orden de dependencias; verificar que toda reparación se explica y se revalida.
- [x] 6.8 Añadir diagnóstico offline sin modelo generativo y UI de regla/severidad/evidencia/corrección; verificar recomendaciones con el GGUF ausente.

## 7. IA remota y revisión de propuestas

- [x] 7.1 Definir `MobileAiEngine`, solicitud saneada y respuesta estructurada comunes a motores API/local; verificar contract tests con propuestas, preguntas, advertencias y errores.
- [x] 7.2 Implementar el constructor de contexto mínimo desde selección y referencias, excluyendo tokens, invitaciones, secretos y otros proyectos; verificar snapshots del prompt saneado.
- [x] 7.3 Implementar `RemoteAiEngine` sobre la API compartida y registrar proveedor/modelo/origen; verificar éxito, indisponibilidad, timeout y cancelación sin mutaciones.
- [x] 7.4 Implementar conversación y preguntas aclaratorias antes de solicitar operaciones; verificar que una intención incompleta no se convierte directamente en cambio.
- [x] 7.5 Implementar vista de diferencias semánticas/visuales, supuestos, advertencias y reparaciones; verificar previsualización sin alterar la revisión abierta.
- [x] 7.6 Permitir selección parcial de operaciones compatibles y confirmación explícita; verificar que dependencias no seleccionables se explican y que solo el subconjunto final se envía.
- [x] 7.7 Aplicar propuestas online mediante el pipeline colaborativo y refrescar el visor; verificar permiso de editor, rechazo de lector, revisión nueva e historial atribuido.
- [x] 7.8 Manejar JSON inválido, respuesta parcial y cancelación descartando el lote; verificar que snapshot, cola e historial permanecen intactos.
- [x] 7.9 Añadir dictado Android/iOS con grabación temporal, permiso de micrófono, subida autenticada al endpoint Whisper compartido y texto editable previo al envío; verificar éxito, permiso denegado, modo offline, refresh de sesión, error remoto y eliminación del archivo.
- [x] 7.10 Corregir la interoperabilidad multipart de voz móvil declarando `audio/mp4`, aceptando variantes AAC/M4A seguras en Django y cubriendo el payload móvil real para eliminar respuestas `400` antes de Whisper.

## 8. Modelo Qwen y motor local

- [ ] 8.1 Fijar una versión de `llama_cpp_dart`, revisión de `llama.cpp`, ABI y opciones compatibles con Dart 3.9.2, Android arm64 e iOS arm64; verificar compilación de un harness e inferencia mínima en dispositivos físicos.
- [ ] 8.2 Implementar `LocalLlamaEngine` detrás de `MobileAiEngine` sin filtrar APIs nativas a la UI; verificar que un motor falso y el real superan el mismo contrato.
- [x] 8.3 Publicar y consumir el manifiesto de `Qwen2.5-Coder-1.5B-Instruct-GGUF` `Q4_K_M` con origen, licencia, tamaño, SHA-256, chat template y contexto; verificar rechazo de metadatos alterados.
- [x] 8.4 Implementar consentimiento, descarga parcial, pausa, reanudación, progreso y reemplazo atómico del GGUF; verificar recuperación tras cortar red y cerrar la app.
- [x] 8.5 Implementar verificación de hash y acciones de reparar/actualizar/eliminar modelo sin tocar proyectos; verificar archivo corrupto, actualización fallida y liberación de espacio.
- [x] 8.6 Implementar comprobación de arquitectura, memoria, almacenamiento y perfil mínimo antes de cargar; verificar bloqueo seguro en dispositivos/perfiles insuficientes.
- [ ] 8.7 Ejecutar una sola inferencia en isolate/hilo nativo con streaming, progreso, cancelación y liberación; verificar que la UI sigue respondiendo y no queda una sesión tras cancelar.
- [x] 8.8 Configurar prompts compactos y salida JSON para Qwen, seguida del evaluador experto; verificar propuestas válidas y rechazo/reparación de salidas mal formadas.
- [ ] 8.9 Implementar modos automático/API/local y fallback solo lectura; verificar la matriz conexión, API disponible, GGUF instalado y dispositivo incompatible.
- [ ] 8.10 Medir memoria, latencia, batería y temperatura en los dispositivos de aceptación y ajustar límites documentados; verificar que resultados y umbrales quedan registrados por plataforma.

## 9. Trabajo offline y sincronización

- [x] 9.1 Implementar marcar/desmarcar proyecto para offline con descarga transaccional de snapshot, registro y reglas; verificar que una interrupción no deja una copia utilizable incompleta.
- [x] 9.2 Abrir y navegar la última revisión local mostrando fecha de sincronización; verificar modo avión y ausencia de llamadas remotas bloqueantes.
- [x] 9.3 Persistir propuestas locales confirmadas como operaciones UUID idempotentes antes de proyectarlas; verificar reinicio forzado sin pérdida ni doble aplicación.
- [x] 9.4 Implementar proyección local y estado pendiente para operaciones IA aceptadas; verificar actualización del visor sin afirmar sincronización.
- [ ] 9.5 Implementar descarga incremental, rebase y envío ordenado de la cola al reconectar; verificar cambios en propiedades distintas alcanzando la revisión canónica.
- [ ] 9.6 Persistir y presentar conflictos de misma propiedad y eliminación frente a edición; verificar conservación de ambas alternativas y resolución autorizada.
- [ ] 9.7 Manejar permiso de edición retirado conservando la cola y exportando recuperación; verificar que ninguna operación se fuerza al servidor.
- [ ] 9.8 Guardar invitaciones offline solo como borradores y enviarlas al reconectar; verificar que nunca se muestra un código real antes de respuesta del servidor.
- [ ] 9.9 Calcular espacio de proyectos, GGUF, parciales y ZIP y permitir borrarlos por separado; verificar falta de espacio y limpieza sin datos cruzados.
- [ ] 9.10 Probar sincronización bajo cierres, red intermitente, tokens renovados y cambio de cuenta; verificar que no hay pérdida, duplicación ni exposición entre usuarios.

## 10. Blueprint y generación Spring determinista

- [ ] 10.1 Implementar y versionar `BackendBlueprint` con entidades, atributos, IDs, asociaciones, DTOs, endpoints, validaciones, transiciones y trazabilidad UML; verificar esquema y ejemplos completos/incompletos.
- [ ] 10.2 Derivar entidades y relaciones JPA desde clases, tipos, identificadores y multiplicidades soportadas; verificar fixtures uno-a-uno, uno-a-muchos y muchos-a-muchos sin ciclos DTO.
- [ ] 10.3 Derivar sugerencias soportadas desde casos de uso, secuencia, estados y restricciones; verificar trazabilidad y reporte explícito de semántica no generable.
- [ ] 10.4 Integrar preguntas expertas cuando faltan ID, tipo, multiplicidad o decisión obligatoria; verificar que no se crea un artefacto listo mientras haya bloqueos.
- [ ] 10.5 Crear el paquete versionado de plantillas Maven/Spring Boot 4.1.x/Java 21 con Wrapper, dependencias y configuración PostgreSQL/Flyway; verificar proyecto mínimo compilable.
- [ ] 10.6 Generar entidades, DTOs, mappers, repositorios, servicios y CRUD REST; verificar pruebas doradas y compilación del fixture de dominio.
- [ ] 10.7 Generar Jakarta Validation, manejo global de errores, configuración, migración inicial, Dockerfile, documentación y pruebas; verificar estructura y comportamiento del proyecto ejemplo.
- [ ] 10.8 Restringir autenticación y comportamientos no CRUD a perfiles explícitamente modelados/soportados; verificar que un modelo sin autenticación no recibe usuarios, JWT ni políticas inventadas.
- [ ] 10.9 Implementar trazabilidad UML→blueprint→archivo/símbolo y reporte de omitidos; verificar navegación de cada elemento generado a su origen.
- [ ] 10.10 Implementar árbol reproducible, normalización de nombres y empaquetado ZIP sin rutas absolutas, `..`, enlaces ni secretos; verificar hashes iguales en dos generaciones y casos Zip Slip.
- [ ] 10.11 Implementar en Flutter generación local desde blueprint/reglas/plantillas y estado `pending_verification`; verificar ZIP offline y reporte estático con red deshabilitada.

## 11. Verificación remota de backends

- [ ] 11.1 Implementar creación/listado/descarga de trabajos y artefactos inmutables asociados a revisión, usuario, motor, reglas y plantillas; verificar que regenerar crea una versión nueva.
- [ ] 11.2 Implementar trabajador aislado que regenera únicamente desde blueprint y plantillas confiables; verificar que ignora/rechaza ZIP o archivos ejecutables enviados por cliente.
- [ ] 11.3 Configurar JDK 21, Maven, caché/repositorios permitidos y límites de CPU, memoria, tiempo, red y logs; verificar terminación controlada de un build excesivo.
- [ ] 11.4 Ejecutar compilación y pruebas generadas, registrando versiones y hashes; verificar transiciones `queued`→`building`→`verified` y `failed` con logs acotados.
- [ ] 11.5 Reproducir al reconectar una generación offline desde blueprint/versiones y comparar hashes sin sobrescribir el ZIP original; verificar estados coincidente y versión incompatible.
- [ ] 11.6 Implementar propuesta de reparación sobre errores de build como artefacto nuevo revisable; verificar que el fallido permanece descargable e inmutable.
- [ ] 11.7 Probar aislamiento, autorización, cuotas, rutas seguras, secretos y contenido de logs/ZIP; verificar que otro usuario o proyecto no accede al trabajo ni artefacto.

## 12. Integración, aceptación y documentación

- [ ] 12.1 Ejecutar pruebas end-to-end de login→proyectos→visor para los catorce tipos online/offline; verificar golden baselines, búsqueda, inspector y ausencia de edición manual.
- [ ] 12.2 Ejecutar una sesión con propietario, editor y lector entre React y Flutter; verificar invitación, presencia, propuesta IA, atribución, historial, conflicto y retiro de acceso.
- [ ] 12.3 Ejecutar edición móvil completa por API y por Qwen local, incluida aceptación parcial y cancelación; verificar que ninguna mutación evita reglas, permisos o confirmación.
- [ ] 12.4 Ejecutar generación Spring online y offline desde un modelo de referencia; verificar Maven tests, arranque con PostgreSQL y CRUD REST del artefacto marcado `verified`.
- [ ] 12.5 Validar recuperación tras red intermitente, cierre forzado, almacenamiento insuficiente y GGUF corrupto; verificar que visor, colas y proyectos permanecen recuperables.
- [ ] 12.6 Ejecutar `python manage.py check`, suite Django, build/lint React requerido por integración, `flutter analyze`, `flutter test` y builds móviles; verificar todos los comandos sin errores nuevos.
- [ ] 12.7 Documentar instalación, descarga/licencia del modelo, requisitos por dispositivo, privacidad del prompt, modos IA, offline, invitaciones y significado de `pending_verification`/`verified`; verificar los flujos siguiendo solo la documentación.
- [ ] 12.8 Documentar el perfil Spring soportado, trazabilidad, límites y funciones omitidas, además del procedimiento de actualizar reglas/modelo/plantillas; verificar revisión contra manifiestos y versiones implementadas.
- [ ] 12.9 Registrar la matriz final de aceptación en Android arm64 e iOS arm64 y cualquier exclusión medida; verificar aprobación de todos los escenarios de las seis especificaciones antes de cerrar el cambio.
