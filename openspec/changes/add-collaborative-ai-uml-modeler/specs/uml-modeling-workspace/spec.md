## Purpose

Proporcionar un espacio web de proyectos y un editor semántico que permita construir, organizar y validar modelos y diagramas conformes con UML 2.5.1.

## ADDED Requirements

### Requirement: Inicio como espacio de modelado
El sistema SHALL presentar al usuario autenticado sus proyectos UML recientes y acciones para crear, abrir, importar o unirse a un proyecto, sustituyendo el contenido provisional de bienvenida.

#### Scenario: Usuario sin proyectos
- **WHEN** un usuario autenticado abre el inicio y todavía no participa en proyectos
- **THEN** el sistema muestra un estado vacío con acciones para crear, importar o unirse mediante código

#### Scenario: Usuario con proyectos
- **WHEN** un usuario autenticado abre el inicio y participa en uno o más proyectos
- **THEN** el sistema muestra los proyectos que puede abrir con su nombre, última modificación y estado de sincronización

#### Scenario: Creación inmediata
- **WHEN** el usuario pulsa «Nuevo proyecto»
- **THEN** el sistema crea atómicamente un proyecto sin título con un diagrama de clases inicial y abre directamente su lienzo

### Requirement: Proyecto y modelo semántico compartido
Cada proyecto SHALL contener paquetes, elementos UML, relaciones y diagramas identificados de forma estable. Un mismo elemento semántico MUST poder aparecer en varios diagramas sin duplicar su identidad ni perder sus propiedades.

#### Scenario: Reutilizar un elemento
- **WHEN** el usuario agrega a otro diagrama una clase que ya existe en el proyecto
- **THEN** ambas representaciones apuntan al mismo elemento y un cambio de nombre se refleja en las dos

#### Scenario: Eliminar una representación
- **WHEN** el usuario elimina una figura de un diagrama sin solicitar eliminar el elemento del modelo
- **THEN** el elemento permanece disponible en el proyecto y en sus otras representaciones

#### Scenario: Eliminar un elemento semántico
- **WHEN** el usuario confirma la eliminación de un elemento del modelo
- **THEN** el sistema elimina o marca como inválidas sus representaciones y relaciones dependientes, mostrando el impacto antes de confirmar

### Requirement: Tipos de diagramas UML 2.5.1
El editor SHALL permitir crear los catorce tipos de diagramas UML 2.5.1: clases, objetos, componentes, estructura compuesta, paquetes, despliegue, perfiles, casos de uso, actividades, máquinas de estados, secuencia, comunicación, visión general de interacción y temporización.

#### Scenario: Crear cualquier tipo soportado
- **WHEN** el usuario crea un diagrama y selecciona uno de los catorce tipos declarados
- **THEN** el sistema abre un lienzo con la paleta de elementos y relaciones válidos para ese tipo

#### Scenario: Cambiar a un tipo incompatible
- **WHEN** el usuario intenta cambiar un diagrama existente a un tipo incompatible con sus elementos
- **THEN** el sistema evita la conversión destructiva y explica qué contenido impide el cambio

### Requirement: Edición visual del diagrama
El editor SHALL permitir agregar, seleccionar, mover, redimensionar, conectar, editar, copiar y eliminar representaciones; también SHALL ofrecer zoom, paneo, selección múltiple, deshacer y rehacer.

#### Scenario: Crear y conectar elementos
- **WHEN** el usuario arrastra elementos desde la paleta y crea una relación permitida entre ellos
- **THEN** el lienzo y el modelo semántico reflejan los nuevos elementos y la relación

#### Scenario: Deshacer una operación
- **WHEN** el usuario ejecuta deshacer después de una edición local confirmada
- **THEN** el editor revierte esa operación sin revertir cambios posteriores de otros colaboradores

#### Scenario: Relación no permitida
- **WHEN** el usuario intenta crear una relación inválida para los tipos de origen o destino
- **THEN** el editor rechaza la relación y muestra una explicación breve

### Requirement: Paleta visual agrupada
El editor SHALL presentar una paleta lateral buscable con grupos UML, General, Flechas y Entidad-Relación, y SHALL permitir colocar figuras mediante clic o arrastre.

#### Scenario: Figura UML
- **WHEN** el usuario coloca una figura del grupo UML
- **THEN** se crean el elemento semántico y su vista con las reglas del tipo de diagrama actual

#### Scenario: Figura auxiliar
- **WHEN** el usuario coloca una figura General o Entidad-Relación
- **THEN** se guarda como vista visual sin elemento UML y se conserva al recargar y colaborar

### Requirement: Edición directa y acciones simples
El editor SHALL permitir renombrar proyectos, diagramas y figuras de forma directa y SHALL mostrar como acciones principales únicamente guardar como imagen, importar y exportar.

#### Scenario: Renombrar una figura
- **WHEN** el usuario hace doble clic o pulsa F2 sobre una figura editable
- **THEN** Enter o pérdida de foco guarda, Escape cancela y un error restaura el nombre anterior

#### Scenario: Guardar como imagen
- **WHEN** el usuario elige PNG o SVG
- **THEN** descarga el diagrama completo sin controles ni indicadores de selección

### Requirement: Propiedades y validación UML
El sistema SHALL permitir editar las propiedades relevantes de cada elemento UML y SHALL validar restricciones estructurales del subconjunto implementado, diferenciando errores que impiden exportar de advertencias informativas.

#### Scenario: Modelo válido
- **WHEN** el usuario solicita validar un modelo sin inconsistencias detectables
- **THEN** el sistema informa que la validación fue satisfactoria y permite exportarlo

#### Scenario: Inconsistencia UML
- **WHEN** el modelo contiene una referencia rota, nombre obligatorio ausente o relación semánticamente incompatible
- **THEN** el sistema identifica el elemento afectado, explica el problema y ofrece navegación hacia él

### Requirement: Organización MDA
El sistema SHALL permitir clasificar paquetes o modelos como CIM, PIM o PSM y SHALL permitir crear vínculos de trazabilidad entre elementos de niveles distintos.

#### Scenario: Trazabilidad de PIM a PSM
- **WHEN** el usuario vincula un elemento PIM con su realización PSM
- **THEN** el sistema conserva una relación navegable en ambas direcciones y la incluye en las exportaciones que la puedan representar

#### Scenario: Elemento sin nivel MDA
- **WHEN** el usuario crea un elemento en un paquete que no tiene nivel MDA
- **THEN** el sistema permite editarlo y lo reporta como no clasificado sin asignar un nivel automáticamente

### Requirement: Guardado e historial local de edición
El editor SHALL guardar automáticamente las operaciones confirmadas y SHALL mostrar si el proyecto está guardado, pendiente de sincronización o en conflicto.

#### Scenario: Guardado normal
- **WHEN** un usuario conectado confirma una edición válida
- **THEN** el sistema la persiste y actualiza el indicador a guardado sin requerir una acción manual

#### Scenario: Falla de guardado
- **WHEN** una edición no puede persistirse por una falla temporal
- **THEN** el sistema conserva la operación localmente, muestra estado pendiente y permite reintentar sin perder el cambio

### Requirement: Editor compacto y contextual
El editor SHALL mantener el lienzo como superficie principal mediante una cabecera compacta, paleta plegable, inspector que solo aparece con selección y barra inferior de estado. Los campos de texto SHALL aparecer únicamente durante una edición o dentro de un diálogo solicitado.

#### Scenario: Abrir el editor sin selección
- **WHEN** un usuario abre un diagrama a 1366×768 sin seleccionar contenido
- **THEN** ve un lienzo amplio, la paleta de figuras y controles mínimos sin formularios permanentes ni inspector vacío

#### Scenario: Ancho reducido
- **WHEN** el editor se abre a 1024×768
- **THEN** la paleta y el inspector pueden plegarse y, al abrirse, se superponen sin reducir el lienzo a un área inutilizable

### Requirement: Biblioteca de figuras SVG
El editor SHALL compartir un renderizador SVG entre paleta y lienzo para figuras General, Flujo y Entidad-Relación. El backend SHALL aceptar únicamente bibliotecas, figuras y claves visuales declaradas.

#### Scenario: Elipse geométrica
- **WHEN** el usuario inserta y redimensiona una elipse
- **THEN** el lienzo utiliza geometría SVG elíptica, mantiene la etiqueta horizontal y conserva ancho y alto independientes tras recargar

#### Scenario: Círculo proporcional
- **WHEN** el usuario redimensiona un círculo o conector circular de flujo
- **THEN** ancho y alto cambian con la misma proporción y la miniatura coincide con el nodo

#### Scenario: Propiedad visual arbitraria
- **WHEN** un cliente envía una biblioteca, figura, marcador o clave visual no declarada
- **THEN** el backend rechaza el payload sin modificar el diagrama

### Requirement: Conectores unidos a figuras
El editor SHALL exponer cuatro puntos de conexión por figura y SHALL persistir nodo/lado de origen y destino. SHALL ofrecer rutas recta, ortogonal y curva; líneas continua y discontinua; y marcadores visuales, UML y Entidad-Relación.

#### Scenario: Crear y mover un conector
- **WHEN** el usuario une dos puntos mediante arrastre o selecciona origen y destino y luego mueve una figura
- **THEN** el conector permanece unido a los lados guardados y conserva tipo, ruta, línea y marcadores tras recargar

#### Scenario: Editar un conector
- **WHEN** el usuario selecciona una arista y cambia color, grosor, ruta, línea o extremos
- **THEN** el inspector guarda la presentación sin cambiar la identidad semántica de una relación UML

#### Scenario: Relación UML
- **WHEN** el usuario elige agregación, composición, generalización, dependencia, realización, include, extend, flujo, transición o mensaje
- **THEN** el editor aplica la combinación declarada de línea, marcadores y etiqueta y el backend conserva la relación UML

#### Scenario: Compatibilidad visual anterior
- **WHEN** se abre una arista guardada con `arrowStart`, `arrowEnd` o `dashed`
- **THEN** el cliente la representa con el contrato nuevo sin requerir una migración de base de datos

### Requirement: Catálogo UML específico por diagrama
El editor SHALL ofrecer para cada uno de los catorce tipos un catálogo UML ampliado y SHALL crear cada figura como elemento semántico permitido por el registro. Las variantes de una misma metaclase SHALL conservar su significado mediante propiedades iniciales y no mediante figuras auxiliares.

#### Scenario: Variante semántica
- **WHEN** el usuario inserta una clase abstracta, una interfaz provista, un pseudoestado especializado o una línea de vida estereotipada
- **THEN** el sistema guarda la metaclase UML correspondiente junto con sus propiedades de variante, dimensiones iniciales y una vista reconocible

#### Scenario: Paleta según el tipo
- **WHEN** el usuario cambia entre diagramas estructurales, de comportamiento o de interacción
- **THEN** la paleta muestra únicamente el catálogo UML declarado para ese tipo y el backend acepta todas sus metaclases

#### Scenario: Clase con atributos y actor
- **WHEN** el usuario abre la paleta UML de un diagrama de clases
- **THEN** puede insertar un Actor y una clase preconfigurada con cabecera y al menos un atributo visible en su compartimento

#### Scenario: Administrar atributos de una clase
- **WHEN** el usuario selecciona una Clase UML y edita, añade o elimina filas desde el inspector
- **THEN** el compartimento se actualiza, la figura crece cuando es necesario y la lista persiste como propiedades del elemento para todos los colaboradores
