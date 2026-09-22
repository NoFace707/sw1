## Why

La pantalla de inicio autenticada necesita convertirse en la función central del producto: un entorno web para crear modelos UML útiles en trabajos universitarios y compartirlos sin quedar encerrados en una sola herramienta. La propuesta debe combinar edición semántica, interoperabilidad comprobable con Sparx Enterprise Architect, colaboración, continuidad offline y asistencia de IA sobre la base de autenticación ya planificada.

## What Changes

- Convertir el inicio web autenticado en un espacio de proyectos y un editor visual UML 2.5.1, manteniendo el acceso a perfil y cierre de sesión.
- Permitir crear y editar los catorce tipos habituales de diagramas UML 2.5.1: clases, objetos, componentes, estructura compuesta, paquetes, despliegue, perfiles, casos de uso, actividades, máquinas de estados, secuencia, comunicación, visión general de interacción y temporización.
- Mantener un modelo semántico compartido: los elementos UML no serán solo figuras; podrán reutilizarse en varios diagramas, conservar relaciones y validarse según su tipo.
- Organizar modelos con enfoque MDA mediante niveles CIM, PIM y PSM, incluyendo trazabilidad entre elementos relacionados; la transformación automática y generación de código no forman parte de esta primera entrega.
- Importar y exportar paquetes/modelos mediante un perfil normativo OMG UML 2.5.1 + XMI 2.5.1, incluyendo información de presentación compatible con UML Diagram Interchange cuando sea representable.
- Añadir un perfil de interoperabilidad para Sparx Enterprise Architect basado en UML 2.5.1 sobre XMI 2.1, con pruebas de ida y vuelta y un informe visible de elementos no soportados o potencialmente perdidos.
- Permitir crear grupos de trabajo mediante códigos de invitación revocables y con vencimiento, para que usuarios autenticados se unan a un proyecto como colaboradores.
- Incorporar edición colaborativa en tiempo real, presencia de participantes, sincronización de cambios y recuperación ante reconexiones sin sobrescribir silenciosamente el trabajo de otros.
- Ofrecer un modo offline instalable como PWA: abrir proyectos almacenados localmente, editar, guardar una cola de cambios y sincronizar al recuperar conexión.
- Incorporar un asistente de IA capaz de proponer diagramas o cambios desde lenguaje natural, explicar modelos, detectar inconsistencias y sugerir correcciones; el usuario deberá revisar y confirmar cualquier cambio antes de aplicarlo.
- Incorporar dictado compartido para web y móvil mediante Whisper ejecutado localmente en el backend, sin requerir una API de transcripción externa.
- Añadir historial/versiones recuperables del modelo para respaldar importaciones, acciones masivas de IA, sincronización y colaboración.
- Simplificar el flujo principal con creación inmediata de un proyecto y su primer diagrama, edición inline y una paleta lateral inspirada en herramientas de diagramación general.
- Incorporar figuras auxiliares visuales (general, flechas y entidad-relación) sin presentarlas como semántica UML ni incluirlas silenciosamente en XMI.
- Reducir la interfaz visible a las acciones cotidianas de modelado e intercambio, conservando internamente historial, snapshots, MDA y recuperación para compatibilidad.
- Mantener el perfil de Enterprise Architect oculto hasta completar una validación real de ida y vuelta con la versión 17.2.
- Rediseñar el editor como una superficie compacta inspirada en draw.io, con paleta buscable, inspector contextual plegable, estado inferior y administración emergente de colaboradores.
- Renderizar con SVG una biblioteca ampliada de figuras General, Flujo y Entidad-Relación, compartiendo la misma geometría entre miniatura y lienzo.
- Convertir las flechas en conectores persistentes unidos a cuatro puntos por figura, con rutas, líneas, marcadores UML/ER e interacción por arrastre o selección de extremos.
- Ampliar exclusivamente la biblioteca UML de los catorce diagramas con clasificadores, nodos estructurales, acciones, pseudoestados y elementos de interacción/temporización, conservando su metaclase y propiedades semánticas.
- Limitar esta entrega a la aplicación React web y su API Django/PostgreSQL; la app Flutter queda fuera de este cambio.

## Capabilities

### New Capabilities

- `uml-modeling-workspace`: Gestión de proyectos, repositorio semántico UML 2.5.1, editor visual para los tipos de diagrama y organización/trazabilidad MDA.
- `uml-model-interchange`: Importación, exportación, validación y reporte de compatibilidad para XMI 2.5.1 y el perfil XMI 2.1 de Sparx Enterprise Architect.
- `collaborative-modeling`: Grupos de trabajo por código de invitación, permisos de proyecto, presencia, edición concurrente e historial recuperable.
- `offline-modeling`: Instalación PWA, almacenamiento local, cola de operaciones y reconciliación al volver a estar en línea.
- `ai-modeling-assistant`: Generación, modificación, explicación y validación asistidas por IA con vista previa y confirmación humana.

### Modified Capabilities

Ninguna; `authenticated-home` pertenece todavía al cambio activo `add-authentication-home-flow` y no está archivada como especificación base. Este cambio se apoyará en ella y reemplazará únicamente el contenido provisional de bienvenida por el espacio de modelado.

## Impact

- Depende de que el flujo web de `add-authentication-home-flow` proporcione usuarios autenticados, ruta protegida y cierre de sesión.
- React incorporará un shell de aplicación, explorador de proyectos/modelos, lienzo de diagramas, inspector de propiedades, presencia colaborativa, estado offline, importación/exportación y panel de IA.
- Django añadirá modelos y APIs para proyectos, membresías, invitaciones, elementos/relaciones UML, diagramas, versiones, operaciones sincronizables y solicitudes de IA.
- PostgreSQL será la fuente de verdad del modelo y su historial; el navegador mantendrá una réplica local en IndexedDB para trabajo offline.
- La colaboración requerirá un canal en tiempo real y una estrategia determinista de concurrencia/reconciliación, además del API HTTP existente.
- El intercambio XMI necesitará parsers/serializadores XML, validadores, fixtures de conformidad OMG y archivos de prueba importados/exportados con Sparx Enterprise Architect.
- La IA requerirá un adaptador de proveedor configurable en backend, límites de contexto/costo, salida estructurada y registro de la propuesta antes de modificar el modelo.
- El alcance es considerable; las tareas deberán construir primero el modelo semántico y los diagramas estructurales/de comportamiento básicos, y después completar las notaciones especializadas sin degradar el contrato común.
