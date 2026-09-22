## Context

El repositorio actual no contiene un motor de diagramas ni modelos de dominio para UML. La aplicación React solo tiene páginas heredadas y el cambio activo `add-authentication-home-flow` propone reducirlas a login, registro e inicio protegido; este cambio depende de ese contrato y sustituye el contenido provisional de inicio. El backend Django/PostgreSQL será la autoridad de datos. Aunque el cambio anterior retira Channels y Redis por no tener uso, esta capacidad los volverá a incorporar con una justificación concreta: difusión de operaciones colaborativas y presencia.

El estándar objetivo será UML 2.5.1. OMG publica el metamodelo UML 2.5.1, sus tipos primitivos, perfil estándar y UML Diagram Interchange como artefactos XMI normativos. OMG también publica XMI 2.5.1. Sparx Enterprise Architect 17.2 declara soporte para XMI 1.1, 1.2, 2.1, 2.4, 2.4.2 y 2.5.1, pero documenta UML 2.x/XMI 2.1 como formato principal de importación e intercambio. Por ello no se intentará usar un único archivo para dos expectativas distintas.

Referencias normativas y de interoperabilidad:

- [OMG UML 2.5.1](https://www.omg.org/spec/UML/2.5.1)
- [OMG XMI 2.5.1](https://www.omg.org/spec/XMI/2.5.1)
- [OMG MOF y MDA](https://www.omg.org/mof/)
- [Sparx Enterprise Architect: intercambio XMI](https://www.sparxsystems.com/enterprise_architect_user_guide/17.2/model_exchange/importexport.html)
- [Sparx Enterprise Architect: publicación de modelos](https://www.sparxsystems.com/enterprise_architect_user_guide/17.2/model_exchange/publishmodelpackage.html)

## Goals / Non-Goals

**Goals:**

- Construir un modelo semántico común que alimente lienzo, colaboración, offline, XMI e IA.
- Entregar cobertura funcional de los catorce tipos de diagramas declarados, compartiendo primitives de edición y agregando reglas/presentación específicas por tipo.
- Mantener PostgreSQL como estado canónico y un log ordenado de operaciones como protocolo común de colaboración y sincronización offline.
- Hacer que la pérdida de información durante intercambio sea visible y comprobable mediante fixtures de ida y vuelta con Enterprise Architect.
- Mantener toda mutación de IA dentro del mismo validador, permisos, log de operaciones e historial que las ediciones humanas.

**Non-Goals:**

- Implementar la totalidad textual de cada restricción del metamodelo UML o certificar formalmente conformidad OMG.
- Reproducir extensiones privadas de Enterprise Architect, su formato Native XEA/XML o una disposición visual idéntica cuando XMI no la transporte de forma interoperable.
- Transformar automáticamente CIM/PIM a PSM, generar código o hacer ingeniería inversa de código fuente.
- Ejecutar colaboración o IA mientras el navegador está offline.
- Añadir estas funciones a Flutter en este cambio.
- Ofrecer cifrado de extremo a extremo o aislamiento multiempresa; se aplicarán permisos de proyecto sobre la autenticación existente.

## Decisions

### 1. Modelo semántico normalizado con propiedades extensibles

El backend incorporará entidades separadas para `Project`, `ProjectMembership`, `InviteCode`, `UmlPackage`, `UmlElement`, `UmlRelationship`, `Diagram`, `DiagramNode`, `DiagramEdge`, `ModelOperation`, `ProjectSnapshot`, `SyncConflict` y `AiProposal`. Los campos comunes e identidades serán columnas relacionales; propiedades variables por metaclase y metadatos de proveedor se almacenarán en JSONB con esquemas validados.

`UmlElement` y `UmlRelationship` representan semántica. `DiagramNode` y `DiagramEdge` representan vistas y geometría. Esta separación permite que una clase aparezca en varios diagramas y que eliminar una figura no elimine automáticamente el elemento. Los identificadores serán UUID generados por cliente para que funcionen offline, complementados por un mapa de identificadores XMI externos.

Un registro versionado de metaclases definirá elementos, relaciones, propiedades y restricciones admitidas por cada tipo de diagrama. React usará el mismo registro publicado por la API para construir paletas e inspector; el backend seguirá siendo la validación autoritativa.

Alternativa considerada: guardar cada proyecto como un único JSON. Facilitaría prototipar, pero vuelve costosas la autorización, búsqueda, referencias compartidas, importaciones parciales y validación concurrente. Se descarta como fuente de verdad; los snapshots sí podrán usar una representación JSON compacta.

### 2. Lienzo React basado en nodos, conexiones y SVG personalizado

El frontend usará `@xyflow/react` para paneo, zoom, selección, arrastre, conexiones y nodos/aristas personalizados. Las notaciones UML se dibujarán con componentes React/SVG propios y un sistema de puertos/ruteo. Diagramas de secuencia, temporización, actividad y estados añadirán capas y reglas especializadas sobre el mismo modelo de vistas.

La entrega avanzará por familias, sin declarar completado el cambio hasta cubrir las catorce:

1. Base, clases, objetos, paquetes y casos de uso.
2. Componentes, despliegue, estructura compuesta y perfiles.
3. Actividades y máquinas de estados.
4. Secuencia, comunicación, visión general de interacción y temporización.

Deshacer/rehacer no manipulará memoria local de forma aislada: generará operaciones inversas atribuibles. Si una inversión choca con cambios posteriores de terceros se tratará como conflicto normal.

Alternativa considerada: desarrollar canvas/SVG desde cero. Se descarta por el coste de accesibilidad, selección, zoom y conexiones. También se descarta modelar solo imágenes, porque impediría XMI, validación e IA estructurada.

### 3. UML 2.5.1 y MDA como metadatos explícitos

La conformidad se implementará como un subconjunto declarado del metamodelo UML 2.5.1 que crecerá con las cuatro familias anteriores. Cada tipo de diagrama tendrá fixtures positivos y negativos. Los niveles MDA `CIM`, `PIM`, `PSM` y `UNSPECIFIED` se aplicarán a paquetes/modelos; las realizaciones entre niveles serán relaciones de trazabilidad con navegación bidireccional. No se inferirá un nivel sin decisión del usuario.

Alternativa considerada: tratar MDA como etiquetas libres. Se descarta porque no permitiría validación ni trazabilidad consistente en XMI.

### 4. Dos perfiles XMI, un modelo intermedio

Importación y exportación pasarán por un modelo intermedio independiente del XML. Los adaptadores serán:

- `omg-xmi-2.5.1`: namespaces UML 2.5.1 y XMI 2.5.1, PrimitiveTypes/StandardProfile y UMLDI cuando exista correspondencia.
- `sparx-ea-xmi-2.1`: serialización UML 2.5.1 compatible con la ruta UML 2.x/XMI 2.1 de Enterprise Architect, más lectura controlada de extensiones `xmi:Extension` de Sparx necesarias para diagramas.

El parser Python usará análisis XML sin entidades externas (`defusedxml`) y validación estructural; `lxml` podrá usarse solo con red, DTD y resolución externa deshabilitadas. La importación se preparará en memoria/área temporal, producirá un informe y se aplicará dentro de una transacción que crea snapshot y operaciones. Las extensiones desconocidas pequeñas podrán preservarse como XML opaco sanitizado; contenido inseguro o excesivo se omitirá con advertencia.

Los fixtures cubrirán cada metaclase admitida y un proyecto de referencia por familia. La aceptación de Enterprise Architect exige dos pruebas manuales registradas con versión 17.2: web → XMI → EA y EA → XMI → web. La equivalencia se medirá sobre elementos, relaciones y propiedades esenciales; la geometría se compara solo donde UMLDI o extensiones Sparx estén soportadas.

Alternativa considerada: exportar únicamente XMI 2.5.1 y esperar que Enterprise Architect lo interprete. Se descarta porque la documentación de Sparx privilegia XMI 2.1 para el intercambio UML 2.x y la compatibilidad debe ser demostrable, no implícita.

### 5. Log de operaciones para colaboración y offline

Toda mutación del modelo se expresará como una operación con `operation_id` UUID, proyecto, autor, origen (`user`, `import`, `ai`, `restore`), `base_revision`, entidad/ruta afectada, acción, valor anterior/nuevo y fecha del cliente. El servidor asignará una revisión monotónica dentro de una transacción PostgreSQL y rechazará operaciones no autorizadas o inválidas.

Reglas de concurrencia:

- IDs nuevos evitan colisiones de creación.
- Cambios sobre entidades/rutas distintas se aplican aunque partan de la misma revisión.
- Reenvíos con el mismo `operation_id` son idempotentes.
- Cambios incompatibles sobre la misma propiedad se ordenan por revisión de servidor; el valor aceptado se vuelve canónico, el alternativo queda en `SyncConflict` y ambos permanecen en el historial.
- Eliminación frente a edición crea conflicto recuperable en vez de recrear o perder silenciosamente contenido.

Django Channels autenticará WebSockets mediante un ticket efímero obtenido por REST y difundirá operaciones confirmadas/presencia por grupos de proyecto. Redis será el channel layer en despliegue; una capa en memoria podrá usarse solo para pruebas locales de un proceso. El socket nunca será la fuente de verdad: tras desconexión el cliente pide operaciones desde su última revisión.

Alternativa considerada: introducir un CRDT binario como fuente primaria. Se descarta porque complicaría la validación UML autoritativa, proyección relacional, XMI y atribución; el log de operaciones satisface la escala académica objetivo y hace visibles los conflictos semánticos.

### 6. Invitaciones almacenadas como secretos verificables

El código mostrado al propietario se generará aleatoriamente y se guardará solo como hash, asociado a proyecto, rol inicial, vencimiento, usos máximos y revocación. La unión consumirá el uso y creará membresía en una transacción bloqueada para evitar exceder el límite. Propietario, editor y lector serán los únicos roles del proyecto.

Alternativa considerada: enlaces permanentes sin vencimiento. Se descarta porque son difíciles de revocar y se filtran con facilidad, incluso en un proyecto universitario.

### 7. PWA y réplica local en IndexedDB

`vite-plugin-pwa`/Workbox almacenará el shell y recursos estáticos; IndexedDB, mediante Dexie, guardará por usuario proyectos habilitados, snapshot base, última revisión, operaciones pendientes, conflictos y borradores de prompts. La clave lógica siempre incluirá `user_id` y `project_id`. El service worker no cacheará respuestas privadas del API de forma genérica.

Al reconectar, el cliente renueva autenticación, descarga operaciones desde la última revisión, rebasa su cola sobre el estado remoto y envía operaciones en orden. Los conflictos utilizan las mismas reglas del servidor. Si se retiró el permiso, la cola queda local y se ofrece exportarla como archivo de recuperación JSON, no XMI canónico sin validación de servidor.

Alternativa considerada: cachear todo con el service worker. Se descarta porque mezcla usuarios y carece de transacciones/consultas apropiadas para operaciones.

### 8. IA como productor de propuestas, no como editor privilegiado

El backend expondrá un adaptador de proveedor configurable por `AI_BASE_URL`, `AI_API_KEY` y `AI_MODEL`, con un contrato de salida JSON estructurado. El contexto se construirá en servidor desde la selección autorizada y un resumen mínimo de referencias. La respuesta se validará contra el registro UML y se guardará como `AiProposal`; React mostrará diferencias y permitirá aceptar operaciones individuales.

Al aplicar, el backend vuelve a validar permisos, revisión y reglas UML y envía las operaciones aceptadas por el mismo pipeline colaborativo. Nunca se permitirá que texto del modelo invoque herramientas, revele secretos o ejecute código. Si no hay proveedor configurado, el editor manual y la validación determinista siguen disponibles.

Alternativa considerada: permitir que la IA escriba directamente en PostgreSQL o devuelva XML XMI. Se descarta por falta de control, dificultad de validar diferencias y riesgo de corromper el modelo.

### 9. Snapshots, límites y observabilidad

Se creará snapshot antes de importaciones, restauraciones y lotes de IA, y periódicamente después de un número configurable de operaciones. El historial de operaciones seguirá siendo la fuente para atribución; snapshots aceleran apertura y recuperación.

Límites iniciales configurables: archivo XMI de 10 MB, 2.000 elementos semánticos por proyecto, 10 colaboradores conectados y lotes de IA de 200 operaciones. Los excesos se rechazan con mensajes claros en vez de degradar silenciosamente. Se registrarán métricas técnicas de importación, sync y proveedor IA sin almacenar tokens ni códigos de invitación.

### 10. Voz como entrada transcrita, no como capacidad del modelo UML

Web y Flutter capturarán audio únicamente bajo acción explícita del usuario. Django expondrá un endpoint autenticado por proyecto que aceptará formatos de audio permitidos y, sin persistirlos, los reenviará como `multipart/form-data` a una ruta Whisper compatible `/audio/transcriptions`. URL, clave, modelo, timeout y tamaño máximo serán configurables por separado de la IA generativa, con posibilidad de reutilizar la clave general solo cuando el despliegue lo decida.

La transcripción devuelta se insertará como borrador editable y nunca creará una propuesta ni una operación por sí sola. Esta separación permite usar proveedores distintos para voz y razonamiento, evita exponer claves en web/móvil y mantiene la confirmación humana existente. La primera entrega requiere conexión; no incorpora Whisper dentro del dispositivo.

El despliegue predeterminado ejecutará `faster-whisper` dentro del backend con CPU e inferencia `int8`. El modelo multilingüe se descargará una sola vez, se conservará en un volumen Docker y se precargará al iniciar el servidor para que una petición web o móvil no tenga que esperar la descarga. El audio se escribirá únicamente en un archivo temporal durante la inferencia y se eliminará en un bloque de limpieza. El adaptador remoto compatible con `/audio/transcriptions` seguirá disponible mediante configuración explícita, pero no será obligatorio ni el valor predeterminado.

## Risks / Trade-offs

- [Cubrir catorce diagramas en una sola entrega es un alcance grande] → Implementar por familias sobre un metamodelo y protocolo comunes, con fixtures/aceptación por cada tipo antes de marcarlo completo.
- [XMI permite variaciones y extensiones por proveedor] → Mantener perfiles separados, un informe de pérdidas y fixtures reales de Enterprise Architect; no prometer fidelidad visual total.
- [XMI 2.5.1 normativo y XMI 2.1 de Sparx pueden divergir] → Convertir ambos al mismo modelo intermedio y verificar equivalencia semántica, sin copiar ciegamente XML entre perfiles.
- [La regla de servidor para el mismo campo no evita conflictos semánticos] → Conservar alternativa, autor y revisión en `SyncConflict`, notificarla y ofrecer resolución explícita.
- [IndexedDB puede borrarse o quedarse sin cuota] → Mostrar estado de persistencia, detectar errores y advertir que el servidor sigue siendo la copia canónica cuando existe sincronización.
- [Un usuario offline puede conservar datos tras perder permisos] → Separar por identidad, impedir sincronización/visualización para otras cuentas y documentar que no hay revocación remota instantánea de copias ya descargadas.
- [La IA puede alucinar UML o consumir presupuesto] → Salida estructurada, validación determinista, límites, contexto mínimo y confirmación humana obligatoria.
- [Channels/Redis contradicen la limpieza del cambio anterior] → Aplicar primero autenticación y luego introducirlos como dependencias nuevas con pruebas específicas, evitando conservar configuración heredada no utilizada.
- [Snapshots e historial pueden crecer] → Compactación y retención configurables, manteniendo siempre puntos protegidos de importación/IA/restauración.

## Migration Plan

1. Aplicar y verificar `add-authentication-home-flow`; no comenzar este cambio sobre rutas/admin heredadas inestables.
2. Añadir esquema de proyectos, membresías, modelo UML, operaciones y snapshots mediante migraciones aditivas y pruebas de permisos.
3. Implementar el registro UML y el editor por familias, habilitando cada tipo solo al superar sus pruebas de paleta, semántica, guardado y validación.
4. Incorporar el log de operaciones HTTP, luego WebSocket/presencia y finalmente IndexedDB/PWA usando el mismo protocolo.
5. Implementar importación/exportación normativa y después el adaptador Sparx con fixtures y pruebas manuales de Enterprise Architect 17.2.
6. Añadir invitaciones e IA cuando el pipeline de permisos, operaciones, validación e historial esté estable.
7. Activar límites, compactación, documentación de compatibilidad y pruebas integrales multiusuario/offline.
8. Para rollback, deshabilitar rutas del modelador y WebSocket mediante flags, conservar tablas/snapshots y volver al inicio simple; las migraciones destructivas de estos datos requerirán una decisión posterior separada.

## Revisión de usabilidad y estabilización

- El contenedor de desarrollo instalará Daphne y registrará su `runserver` ASGI para atender HTTP y WebSocket con la misma aplicación.
- La presencia enviará heartbeat cada diez segundos; cada mensaje vuelve a comprobar la membresía y permite retirar acceso a una sesión abierta.
- Crear un proyecto desde el inicio generará atómicamente `Proyecto sin título` y un diagrama de clases `Diagrama 1`, excepto cuando la creación sea parte de una importación.
- Las figuras UML conservarán su elemento semántico. Las figuras General y Entidad-Relación serán `DiagramNode` sin elemento, y las flechas auxiliares serán `DiagramEdge` sin relación; su `properties` contendrá un contrato visual limitado y validado.
- La interfaz ocultará historial, MDA, validación, propiedades JSON y recuperación, pero no eliminará sus datos ni APIs.
- PNG y SVG se generarán desde el lienzo actual. El intercambio estructurado visible usará OMG XMI 2.5.1.
- El perfil Sparx permanecerá detrás de `VITE_ENABLE_EA_INTERCHANGE=false` hasta superar fixtures reales de Enterprise Architect 17.2.

### 10. Editor compacto, geometrías SVG y conectores

El shell de edición tendrá tres zonas variables alrededor del lienzo: paleta izquierda de 240 px, inspector contextual derecho de 256 px y barra inferior de estado. La cabecera de 48 px concentra navegación, nombre editable bajo demanda, selector de diagrama, creación mediante diálogo e intercambio. En anchos reducidos, paleta e inspector se superponen al lienzo y pueden cerrarse.

La geometría visual se centraliza en un renderizador SVG usado tanto por las miniaturas como por los nodos. `DiagramNode.properties` mantiene un contrato cerrado para las bibliotecas `general`, `flowchart` y `er`; círculo y conectores circulares conservan proporción, mientras elipse y figuras angulares admiten dimensiones independientes sin rotar su etiqueta.

La paleta UML tendrá un catálogo independiente por tipo de diagrama. Las variantes que comparten metaclase —clase abstracta/activa, interfaz provista, tipos de línea de vida y clases de `Pseudostate`— se crean con propiedades semánticas iniciales en vez de inventar metaclases visuales. Sus tamaños y proporciones se resuelven desde un registro frontend único y el backend publica la lista autoritativa ampliada como `uml-2.5.1-subset-2`.

Cada nodo expone handles `top`, `right`, `bottom` y `left`. Las aristas usan un componente compartido con ruteo recto, ortogonal o curvo, línea continua/discontinua y marcadores de flecha, triángulo, rombo, círculo y cardinalidades ER. La presentación de una relación UML se guarda dentro de `DiagramEdge.properties.presentation`; las aristas visuales usan el mismo contrato directamente con `kind=visual`. Las propiedades antiguas `arrowStart`, `arrowEnd` y `dashed` se normalizan al leer, sin migración de datos.

La creación admite arrastre entre handles y una alternativa explícita de seleccionar origen y destino con dos clics. Esta segunda ruta evita que un zoom o solapamiento deje la herramienta activa sin respuesta y conserva el tipo de conector elegido hasta `Escape` o la selección del cursor.
