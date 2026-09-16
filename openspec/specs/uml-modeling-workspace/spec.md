# uml-modeling-workspace Specification

## Purpose

Proporcionar un espacio web de proyectos y un editor semántico que permita construir, organizar y validar modelos y diagramas conformes con UML 2.5.1.

## Requirements

### Requirement: Inicio como espacio de modelado
El sistema SHALL presentar al usuario autenticado sus proyectos UML recientes y acciones para crear, abrir, importar o unirse a un proyecto, sustituyendo el contenido provisional de bienvenida.

#### Scenario: Usuario sin proyectos
- **WHEN** un usuario autenticado abre el inicio y todavía no participa en proyectos
- **THEN** el sistema muestra un estado vacío con acciones para crear, importar o unirse mediante código

#### Scenario: Usuario con proyectos
- **WHEN** un usuario autenticado abre el inicio y participa en uno o más proyectos
- **THEN** el sistema muestra los proyectos que puede abrir con su nombre, última modificación y estado de sincronización

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
