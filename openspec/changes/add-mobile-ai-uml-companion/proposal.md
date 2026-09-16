## Why

El cliente móvil debe complementar al modelador web sin intentar reproducir un lienzo de diseño incómodo en pantalla pequeña: permitirá consultar proyectos, colaborar e indicar cambios en lenguaje natural para que la IA los proponga. Además, debe seguir siendo útil sin conexión mediante un modelo local y un sistema experto, y convertir los modelos UML en un backend Spring Boot utilizable.

## What Changes

- Convertir el inicio Flutter autenticado en una lista de proyectos UML compartida con el cliente web.
- Permitir abrir y explorar en modo lectura los catorce tipos de diagramas UML 2.5.1 mediante zoom, desplazamiento, búsqueda, navegación entre elementos y consulta de propiedades.
- **BREAKING**: no ofrecer herramientas móviles de dibujo, arrastre, conexión ni edición manual; toda modificación semántica o visual del modelo desde móvil deberá originarse en una propuesta de IA revisada y confirmada por el usuario.
- Consumir en línea el mismo asistente de IA por API definido para web, manteniendo permisos, historial, validación UML y operaciones colaborativas.
- Incorporar inferencia local offline mediante un adaptador intercambiable cuya primera implementación objetivo será `llama_cpp_dart` con `Qwen2.5-Coder-1.5B-Instruct-GGUF` cuantizado `Q4_K_M`.
- Descargar el modelo local de forma opcional y verificable, sin incluir sus aproximadamente 1,12 GB dentro de la instalación inicial; permitir pausar, reanudar, comprobar integridad, actualizar y eliminar el modelo.
- Detectar compatibilidad y recursos del dispositivo antes de cargar IA local, ejecutar inferencia fuera del hilo de interfaz y ofrecer degradación clara a modo solo lectura si el dispositivo no puede ejecutarla.
- Añadir un sistema experto determinista que aporte reglas UML 2.5.1, MDA, consistencia, preguntas de aclaración y validación de operaciones tanto a la IA remota como a la local.
- Mantener proyectos seleccionados, diagramas, metadatos, invitaciones pendientes, propuestas y operaciones aceptadas en modo offline, sincronizándolos al recuperar sesión y conectividad.
- Permitir desde móvil unirse mediante código y, cuando el usuario sea propietario, generar, compartir, revocar y configurar códigos de invitación para su grupo.
- Permitir que la IA genere desde el modelo UML un proyecto backend Maven en Spring Boot 4.1.x y Java 21 con API REST, entidades JPA, PostgreSQL, validación, repositorios, servicios, controladores, manejo de errores, configuración, Dockerfile y pruebas.
- Combinar IA con generación determinista por plantillas: la IA resolverá intención y mapeos, mientras el sistema experto y las plantillas producirán una estructura repetible y validable.
- Permitir descargar/compartir el backend generado como ZIP. En línea, el servidor deberá compilar y ejecutar las pruebas antes de marcarlo como verificado; offline, se generará una versión reproducible pendiente de verificación remota al reconectar.
- Mantener la generación de autenticación, reglas de negocio complejas, despliegue cloud y frontend fuera del resultado salvo que el modelo UML las describa explícitamente y exista una plantilla soportada.

## Capabilities

### New Capabilities

- `mobile-uml-viewer`: Inicio móvil de proyectos y visualización navegable, pero no editable manualmente, de diagramas UML 2.5.1.
- `mobile-project-collaboration`: Unión e invitación de colaboradores desde móvil, aplicación de permisos y recepción/sincronización de cambios compartidos.
- `mobile-offline-workspace`: Caché local de proyectos y operaciones, acceso offline y sincronización recuperable al reconectar.
- `hybrid-mobile-ai`: Selección automática o manual entre IA por API e inferencia local con Qwen2.5-Coder 1.5B Q4_K_M, incluyendo gestión del modelo y propuestas confirmables.
- `expert-modeling-guidance`: Motor de reglas UML/MDA que valida, explica y restringe las propuestas de IA antes de convertirlas en operaciones.
- `spring-backend-generation`: Generación, empaquetado y verificación de un backend Spring Boot Java derivado del modelo UML.

### Modified Capabilities

Ninguna; las capacidades relacionadas siguen en cambios OpenSpec activos y todavía no existen como especificaciones base. Este cambio depende de `add-authentication-home-flow` y `add-collaborative-ai-uml-modeler`, reutilizando sus contratos de usuario, proyecto, permisos, operaciones, historial e IA.

## Impact

- Flutter añadirá navegación de proyectos, renderizador read-only de diagramas, almacenamiento local estructurado, sincronización, invitaciones, chat/propuestas de IA, gestión del modelo GGUF y exportación de ZIP.
- Android e iOS necesitarán integración nativa de `llama.cpp`, ABI/arquitecturas soportadas, permisos/almacenamiento, descarga en segundo plano y pruebas sobre dispositivos físicos; desktop/web Flutter no forman parte de la aceptación local inicial.
- El backend Django añadirá endpoints móviles de snapshots/diagramas, sincronización, invitaciones, inferencia remota, verificación de artefactos y descarga del backend generado, reutilizando autorización e historial del modelador web.
- PostgreSQL conservará propuestas, operaciones aceptadas, trabajos de generación y reportes; los archivos ZIP tendrán almacenamiento y vencimiento configurables.
- La generación Spring se fijará inicialmente en Spring Boot 4.1.x, Java 21 y Maven, usando PostgreSQL y paquetes Jakarta; versiones futuras se incorporarán como perfiles de plantilla, no como texto libre del modelo.
- El modelo local oficial Qwen GGUF usa licencia Apache 2.0; se conservarán atribución, URL, versión, cuantización, tamaño y hash del artefacto descargado.
- La capacidad local es limitada: se enviará al modelo solo el submodelo necesario, se usarán prompts compactos y el sistema experto deberá poder rechazar o reparar salidas inválidas sin depender de conexión.
