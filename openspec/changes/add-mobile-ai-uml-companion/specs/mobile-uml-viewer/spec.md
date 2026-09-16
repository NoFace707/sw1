## Purpose

Ofrecer en Flutter una vista cómoda y navegable de los proyectos y diagramas UML 2.5.1 sin trasladar al teléfono las herramientas manuales de diseño del cliente web.

## ADDED Requirements

### Requirement: Inicio móvil de proyectos
El cliente móvil SHALL mostrar los proyectos UML a los que pertenece el usuario, con nombre, permiso, última modificación y estado local/sincronizado, y SHALL permitir abrirlos o buscarlos.

#### Scenario: Lista sincronizada
- **WHEN** un usuario autenticado abre el inicio con conexión
- **THEN** la aplicación actualiza y muestra únicamente los proyectos donde tiene membresía

#### Scenario: Proyecto retirado
- **WHEN** un proyecto deja de estar autorizado para el usuario
- **THEN** la aplicación deja de ofrecer acceso en línea y marca cualquier copia offline según las reglas de sincronización

### Requirement: Visualización de diagramas UML 2.5.1
La aplicación SHALL renderizar en modo lectura los catorce tipos soportados por el modelador web: clases, objetos, componentes, estructura compuesta, paquetes, despliegue, perfiles, casos de uso, actividades, máquinas de estados, secuencia, comunicación, visión general de interacción y temporización.

#### Scenario: Abrir un diagrama soportado
- **WHEN** el usuario selecciona un diagrama disponible
- **THEN** la aplicación muestra sus elementos, relaciones, etiquetas y geometría conservando la semántica recibida

#### Scenario: Notación todavía no compatible
- **WHEN** el diagrama contiene una extensión visual que la versión móvil no puede representar
- **THEN** la aplicación conserva el proyecto, muestra una representación alternativa o marcador y explica la limitación

### Requirement: Navegación adaptada a pantalla táctil
El visor SHALL permitir zoom, desplazamiento, ajuste a pantalla, minimapa o navegación equivalente, selección, búsqueda y salto entre referencias sin mover ni alterar elementos.

#### Scenario: Inspeccionar un elemento
- **WHEN** el usuario toca un elemento
- **THEN** la aplicación muestra sus propiedades, relaciones, nivel MDA y diagramas relacionados sin entrar en modo de edición manual

#### Scenario: Buscar elemento
- **WHEN** el usuario busca por nombre o tipo y elige un resultado
- **THEN** el visor abre el diagrama correspondiente y centra la representación cuando exista

### Requirement: Ausencia de edición manual
El cliente móvil SHALL NOT ofrecer acciones de crear, mover, redimensionar, conectar, renombrar o eliminar directamente elementos o vistas. Toda mutación solicitada desde móvil MUST proceder de una propuesta de IA confirmada.

#### Scenario: Gesto sobre un elemento
- **WHEN** el usuario mantiene o arrastra una figura en el visor
- **THEN** la aplicación conserva su geometría y ofrece únicamente acciones de consulta o solicitar cambio a la IA

#### Scenario: Cambio aplicado por IA
- **WHEN** el usuario confirma una propuesta válida de IA
- **THEN** la operación se aplica mediante el protocolo colaborativo y el visor actualiza la revisión mostrada

### Requirement: Indicadores de revisión y estado
El visor SHALL mostrar la revisión abierta y si el contenido está actualizado, almacenado offline, pendiente de sincronización o tiene conflictos.

#### Scenario: Llegan cambios remotos
- **WHEN** otro colaborador confirma cambios mientras el diagrama está abierto
- **THEN** el visor actualiza la revisión o avisa que existe una versión nueva sin confundirla con una edición local

