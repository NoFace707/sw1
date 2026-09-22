## Context

Este cambio extiende dos cambios OpenSpec todavía activos. `add-authentication-home-flow` define la sesión Flutter y sustituye el inicio provisional; `add-collaborative-ai-uml-modeler` define en Django/PostgreSQL el modelo semántico UML 2.5.1, membresías e invitaciones, snapshots, log de operaciones, conflictos, historial, WebSocket y propuestas de IA que usa el cliente web. El orden de implementación será autenticación, modelador web compartido y, finalmente, este cliente móvil. No se duplicarán identidades, permisos ni un segundo formato de proyecto para Flutter.

El teléfono es un compañero de consulta y asistencia, no otro lienzo. Debe representar los catorce tipos de diagrama, pero toda mutación móvil se expresará como una propuesta estructurada de IA, se validará con reglas deterministas y requerirá confirmación. La app debe conservar utilidad offline, donde el dispositivo es temporalmente la autoridad de una réplica y una cola de operaciones, pero PostgreSQL recupera la autoridad canónica al sincronizar.

La primera IA local objetivo será `Qwen2.5-Coder-1.5B-Instruct-GGUF` `Q4_K_M`. El archivo oficial ronda 1,12 GB, por lo que se descargará con consentimiento y no se incluirá en la aplicación. Flutter ya usa Dart 3.9.2; la integración nativa se aislará tras un adaptador para fijar una versión compatible de `llama_cpp_dart`/`llama.cpp` y permitir sustituirla si las pruebas físicas de Android o iOS lo exigen. La generación de backend tendrá un perfil cerrado: Spring Boot 4.1.x, Java 21, Maven y PostgreSQL.

## Goals / Non-Goals

**Goals:**

- Reutilizar un único contrato de proyecto, diagrama, operación, conflicto, permiso e invitación entre web, móvil y backend.
- Dar una experiencia táctil de lectura fluida sin exponer herramientas de edición manual.
- Ejecutar el mismo flujo revisable de propuestas con IA remota o local y conservar su origen en el historial.
- Mantener proyectos seleccionados, reglas, propuestas, operaciones y artefactos útiles sin red, con sincronización idempotente al reconectar.
- Proteger el modelo semántico con un sistema experto explicable que funcione incluso sin IA generativa.
- Producir backends Spring reproducibles mediante un modelo intermedio, reglas y plantillas; usar la IA para interpretar intención, no para escribir archivos arbitrarios.
- Verificar en servidor que los backends generados compilan y superan pruebas antes de calificarlos como funcionales/verificados.

**Non-Goals:**

- Dibujar, arrastrar, redimensionar, conectar o editar manualmente diagramas desde móvil.
- Portar `@xyflow/react`, el editor React o toda su interfaz a Flutter.
- Entrenar o ajustar modelos, hospedar un proveedor de IA propio o garantizar el mismo rendimiento local en todos los teléfonos.
- Ejecutar compilación Java completa dentro de Flutter; offline solo habrá generación determinista y validación estática.
- Generar frontend, infraestructura cloud o reglas de negocio no expresadas en UML y no cubiertas por una plantilla.
- Resolver en este cambio la importación/exportación XMI, que pertenece al modelador compartido y será consumida por el proyecto móvil a través del backend.

## Decisions

### 1. Contratos compartidos y orden explícito de cambios

Django seguirá siendo la autoridad de usuarios, proyectos, membresías, invitaciones, revisiones y artefactos. Flutter consumirá los endpoints y el protocolo definidos por `add-collaborative-ai-uml-modeler`: snapshots normalizados, operaciones desde revisión, tickets WebSocket, historial e invitaciones. Se ampliarán esos contratos únicamente con manifiestos de IA/reglas/plantillas, trabajos de generación y artefactos descargables.

Las operaciones móviles conservarán el esquema común y añadirán un origen distinguible, por ejemplo `ai-mobile-api` o `ai-mobile-local`, sin crear un canal privilegiado. El servidor volverá a comprobar membresía, permiso, revisión base, límites y reglas antes de asignar una revisión. Los contratos se versionarán y tendrán fixtures compartidos; una app con una versión incompatible deberá conservar lectura y pedir actualización, no interpretar datos silenciosamente.

Alternativa considerada: crear una API móvil simplificada y convertir después a operaciones web. Se descarta porque duplicaría reglas, favorecería divergencias y haría más difícil resolver conflictos e identificar autores.

### 2. Arquitectura Flutter por capacidades y sin comandos manuales

Flutter se organizará por capacidades de proyectos, visor, colaboración, offline/sync, IA híbrida, sistema experto y generación/artefactos. Cada capacidad separará presentación, casos de uso, repositorios y adaptadores de infraestructura. La capa de estado del visor no expondrá comandos de mutación manual; su única entrada de cambios será la aplicación confirmada de `ModelOperation` validada.

La navegación autenticada llevará al listado de proyectos. Desde un proyecto se podrá abrir el visor, inspeccionar elementos, consultar historial/miembros, administrar invitaciones cuando corresponda, conversar con la IA y generar/descargar artefactos. Las acciones se ocultarán o deshabilitarán según el permiso, pero el backend seguirá siendo el control autoritativo.

### 3. Snapshot de visualización y renderizador Flutter de solo lectura

El backend publicará una representación normalizada que combine semántica, nodos/aristas de diagrama, geometría, estilos admitidos, referencias y revisión. Flutter no interpretará SVG/HTML emitido por web ni portará React Flow. El visor usará `InteractiveViewer` y renderizado propio con `CustomPainter`, widgets o paths SVG según la notación, sobre un registro compartido de tipos UML.

El registro mapeará los catorce tipos y sus figuras/aristas a renderizadores móviles. Selección, panel de propiedades, búsqueda, centrado, ajuste a pantalla, zoom y paneo serán gestos de consulta. Una extensión visual desconocida se mostrará como marcador preservando identificador y propiedades; nunca se eliminará del snapshot por no poder dibujarla.

Alternativa considerada: recibir una imagen estática del servidor. Se descarta porque impediría buscar, inspeccionar, navegar referencias, distinguir cambios y usar submodelos como contexto de IA.

### 4. La IA produce diferencias; el usuario y el pipeline aplican operaciones

Se definirá una interfaz `MobileAiEngine` con implementaciones remota y local. Ambas recibirán una solicitud saneada con intención, selección, submodelo mínimo, revisión base y reglas aplicables; devolverán el mismo esquema de propuesta con operaciones, supuestos, advertencias y preguntas pendientes.

La interfaz mostrará una diferencia semántica y visual, permitirá aceptar operaciones individuales compatibles y requerirá confirmación final. El sistema experto validará y podrá reparar de forma acotada antes de habilitarla. Con conexión, la confirmación se envía al pipeline colaborativo. Offline, se aplica a la réplica local y se guarda en una cola idempotente. Una cancelación, respuesta parcial o JSON inválido no produce ninguna operación.

El modo automático preferirá API cuando esté accesible y usará local al no estarlo. Los modos forzados permitirán elegir. El motor y sus versiones quedarán registrados en la propuesta y el historial.

### 5. Runtime local aislado y modelo descargable verificado

`LocalLlamaEngine` encapsulará `llama_cpp_dart` y la biblioteca nativa `llama.cpp`; ninguna pantalla dependerá de su API concreta. Se fijarán la versión Dart, la revisión de `llama.cpp`, ABI y opciones de compilación verificadas. El primer objetivo de aceptación serán Android arm64 e iOS arm64 en dispositivos físicos. El uso de una versión preliminar futura del paquete requerirá una actualización deliberada del SDK, no una resolución accidental de dependencias.

La entrada por voz será independiente del motor Qwen: Flutter capturará un archivo temporal con permiso explícito y lo enviará al endpoint autenticado de transcripción compartido. Django ejecutará Whisper localmente y devolverá solo texto, sin exigir una segunda clave de API; un proveedor remoto podrá configurarse como alternativa. La app eliminará el archivo temporal al terminar, insertará la transcripción como borrador editable y no la enviará automáticamente al motor remoto o local. En esta entrega el dictado requiere conexión con el backend y su ausencia no bloquea el chat escrito ni la IA local.

Un manifiesto firmado/versionado, entregado por backend y con copia mínima incluida, contendrá nombre del modelo, URL oficial permitida, licencia Apache 2.0, cuantización `Q4_K_M`, tamaño, SHA-256, plantilla de chat, contexto y compatibilidad. El gestor descargará el GGUF a almacenamiento de soporte de la app con archivo parcial, reanudación y reemplazo atómico después de verificarlo. El usuario podrá eliminar modelo y archivos parciales sin borrar proyectos.

Antes de cargar se comprobarán arquitectura de 64 bits, almacenamiento libre, memoria estimada y perfil compatible. Como base de aceptación se exigirá un dispositivo de al menos 4 GB de RAM y 2,5 GB libres, sujeto a medición real; la app advertirá sobre batería/temperatura y podrá negar la carga cuando el sistema reporte presión de memoria. Habrá una sola inferencia local activa, ejecutada en isolate/hilo nativo, con streaming, cancelación y liberación de contexto. Si falla, la app conserva visor y sistema experto.

Alternativa considerada: empaquetar el GGUF dentro del binario. Se descarta por tamaño de instalación, actualizaciones y compatibilidad variable de dispositivos.

### 6. Persistencia estructurada y sincronización offline

`SharedPreferences` seguirá limitado a la sesión heredada. Se añadirá SQLite, preferentemente mediante Drift, para cuentas lógicas, proyectos habilitados, snapshots, revisiones, reglas, propuestas, operaciones pendientes, conflictos, manifiestos y metadatos de artefactos. Los GGUF y ZIP vivirán como archivos en el directorio de soporte y la base almacenará rutas internas y hashes.

Cada clave local incluirá `user_id` y `project_id`; cambiar de cuenta cerrará repositorios y ocultará los datos anteriores. Marcar un proyecto offline descargará de forma transaccional snapshot, registro UML y reglas compatibles. Las operaciones confirmadas tendrán UUID, revisión base y estado; primero se persisten y después se proyectan, de modo que reiniciar no las duplique.

Al reconectar, el cliente renovará sesión, solicitará operaciones posteriores a su revisión, rebasará la cola sobre el estado remoto y la enviará en orden. Los conflictos se guardarán y mostrarán con ambas alternativas. Si el permiso fue retirado, la cola no se fuerza: se conserva y puede exportarse como recuperación. Invitaciones offline serán borradores; solo el servidor puede emitir un código real.

### 7. Sistema experto declarativo y compartido

La base de conocimiento será un paquete JSON declarativo versionado por esquema UML, nivel MDA y perfil Spring. Incluirá condiciones, severidad, mensaje, evidencia, preguntas, reparaciones permitidas y mapeos. Django y Dart implementarán evaluadores equivalentes y ejecutarán los mismos fixtures; el servidor seguirá siendo autoritativo para operaciones sincronizadas.

El motor se usará en cuatro puntos: preparar preguntas/supuestos antes del prompt, limitar el contexto y operaciones permitidas, validar/reparar la salida estructurada y construir el modelo intermedio Spring. Las reparaciones se limitarán a transformaciones declaradas —normalización, valores derivados y orden de dependencias— y se mostrarán al usuario. Sin modelo generativo, el evaluador todavía podrá diagnosticar y sugerir correcciones, pero no inventará cambios.

Alternativa considerada: incorporar todas las reglas solo al prompt. Se descarta porque un modelo pequeño puede ignorarlas y no permitiría resultados deterministas ni explicables offline.

### 8. Modelo intermedio y plantillas para Spring Boot

La generación tendrá un `BackendBlueprint` JSON validado y versionado. El sistema experto lo derivará principalmente de clases, atributos, identificadores, asociaciones y multiplicidades; casos de uso, secuencias, estados y restricciones podrán añadir endpoints, comandos, validaciones y transiciones soportadas. Cada entrada conservará IDs UML para trazarla a archivos y símbolos Java. La IA podrá proponer nombres y resolver intención, pero no insertar código, dependencias ni rutas fuera del esquema permitido.

Un paquete de plantillas versionado convertirá el blueprint al árbol Maven para Spring Boot 4.1.x/Java 21 con Web, Data JPA, Jakarta Validation, PostgreSQL, Flyway, DTOs, repositorios, servicios, controladores, manejo de errores, configuración, Dockerfile, Maven Wrapper y pruebas JUnit/Mockito e integración soportada. La misma combinación de revisión, blueprint, reglas, plantillas y opciones producirá el mismo contenido y hashes; las marcas de tiempo quedarán fuera del árbol reproducible.

El empaquetador validará nombres y rutas, evitará `..`, enlaces, rutas absolutas y secretos, y creará un ZIP nuevo sin sobrescribir anteriores. Las funciones no soportadas aparecerán en un reporte. Si falta un identificador, tipo o multiplicidad imprescindible, la generación se detendrá con preguntas concretas.

Alternativa considerada: pedir al modelo que genere libremente todos los archivos. Se descarta porque Qwen 1.5B no puede garantizar compilación, seguridad de rutas ni reproducibilidad y porque sería imposible distinguir capacidades soportadas de código plausible.

### 9. Verificación remota reproducible y artefactos inmutables

Online, Django enviará el blueprint y versiones a un trabajador aislado que regenerará el árbol desde plantillas confiables, ejecutará Maven y pruebas con límites de CPU, memoria, tiempo y salida, y no ejecutará un ZIP arbitrario aportado por el dispositivo. La descarga de dependencias se realizará desde repositorios configurados antes de bloquear la red de la fase de prueba. Un artefacto será `verified` solo si generación, compilación y pruebas terminan correctamente; se registrarán JDK, Spring, Maven, hashes y logs acotados.

Offline, Flutter usará el paquete local de plantillas para producir el ZIP y validaciones de estructura/esquema, pero lo marcará `pending_verification`. Al reconectar enviará blueprint, revisión y versiones; el servidor reproducirá y verificará una generación hermana, conservará el ZIP original y comparará hashes cuando las versiones coincidan. Una reparación crea un artefacto nuevo y nunca sobrescribe el anterior.

### 10. Invitaciones y colaboración reutilizan la autoridad web

Unirse, listar miembros y administrar invitaciones usarán las mismas transacciones y permisos del modelador web. El código solo se revela en la respuesta de creación, nunca se añade a prompts, telemetría o caché genérica. La hoja de compartir del sistema recibe únicamente el texto/código elegido por el propietario. WebSocket difundirá presencia y revisiones, mientras REST recuperará cualquier operación perdida.

## Risks / Trade-offs

- [El GGUF de aproximadamente 1,12 GB y su memoria de ejecución excluyen teléfonos modestos] → Descarga opcional, comprobación previa, una sola sesión, contexto reducido, cancelación y degradación a API/sistema experto/solo lectura.
- [`llama_cpp_dart` y sus APIs nativas pueden cambiar antes de estabilizarse] → Adaptador propio, versiones y binarios fijados, fixtures de contrato y pruebas en dispositivos físicos antes de habilitar cada plataforma.
- [Un modelo de 1,5B puede producir propuestas incompletas] → Esquema cerrado, preguntas previas, reglas deterministas, reparaciones acotadas, plantillas y confirmación humana.
- [La inferencia local consume batería y puede elevar temperatura] → Mostrar estado, advertir condiciones, permitir cancelación y reducir contexto/tokens; no iniciar si el sistema reporta recursos insuficientes.
- [La copia offline no puede revocarse instantáneamente al retirar permisos] → Aislamiento por cuenta, bloqueo al reconectar y comunicación clara; no se promete borrado remoto de datos ya descargados.
- [Los contratos móviles pueden quedar atrás respecto al editor web] → Registro/esquemas versionados, fixtures compartidos y fallback de solo lectura para tipos desconocidos.
- [Generar código «funcional» excede la capacidad de una validación estática móvil] → Separar `pending_verification` de `verified` y exigir compilación/pruebas aisladas en servidor para la segunda etiqueta.
- [Compilar proyectos generados expone al servidor a código hostil o costoso] → Regenerar solo desde blueprint y plantillas confiables, no ejecutar archivos arbitrarios, y aplicar cuotas y límites de recursos/red/logs.
- [Plantillas Spring y dependencias envejecen] → Perfiles versionados y actualizaciones explícitas con pruebas doradas; no aceptar versiones libres solicitadas por el modelo.
- [Mantener evaluadores de reglas en Dart y Python puede divergir] → Formato declarativo común, semántica pequeña y suite compartida de entradas/resultados.

## Migration Plan

1. Aplicar y verificar `add-authentication-home-flow`, seguido por `add-collaborative-ai-uml-modeler`; congelar las primeras versiones de contratos, registro UML y fixtures.
2. Añadir en Django endpoints/versiones para snapshot móvil, manifiestos, reglas, blueprints, trabajos de verificación y artefactos, manteniéndolos detrás de flags.
3. Sustituir el inicio Flutter provisional por proyectos e implementar repositorios, SQLite y visor de solo lectura antes de habilitar cualquier IA.
4. Incorporar miembros, unión/invitaciones y recepción de revisiones; probar permisos y pérdida de acceso.
5. Implementar el evaluador experto Dart/Python con fixtures comunes y después el flujo de propuestas remotas confirmables.
6. Integrar descarga, hash, compatibilidad y `LocalLlamaEngine`; habilitar por plataforma solo después de pruebas físicas de memoria, cancelación y recuperación.
7. Añadir cola offline, rebase, conflictos y recuperación, probando cierres forzados y cambios de cuenta.
8. Implementar `BackendBlueprint`, plantillas Spring y ZIP local; luego el trabajador de compilación/pruebas y reconciliación de verificaciones.
9. Ejecutar aceptación integral en Android/iOS y con dos clientes web: invitación, edición IA online/offline, conflicto, historial y backend verificado.
10. Para rollback, desactivar IA local, generación y sincronización móvil por flags en ese orden; conservar SQLite/archivos y tablas/artefactos hasta confirmar que no se requieren. Ningún rollback eliminará datos automáticamente.
