## Purpose

Asistir a los usuarios en la creación y comprensión de modelos UML mediante propuestas estructuradas de IA que nunca modifiquen el proyecto sin revisión humana.

## ADDED Requirements

### Requirement: Crear una propuesta desde lenguaje natural
El asistente SHALL aceptar una descripción del sistema y SHALL devolver una propuesta estructurada de elementos, relaciones y diagramas UML 2.5.1 aplicable al proyecto actual.

#### Scenario: Generar un diagrama nuevo
- **WHEN** el usuario solicita un diagrama de un tipo soportado y aporta suficiente contexto
- **THEN** el asistente presenta una vista previa con elementos, relaciones, supuestos y advertencias antes de modificar el proyecto

#### Scenario: Solicitud ambigua
- **WHEN** faltan datos que cambiarían materialmente el modelo propuesto
- **THEN** el asistente solicita aclaraciones o presenta los supuestos explícitos en lugar de inventarlos silenciosamente

### Requirement: Proponer modificaciones sobre un modelo
El asistente SHALL poder recibir como contexto el modelo o selección autorizada y proponer operaciones de agregar, actualizar o eliminar sin aplicar ninguna hasta la confirmación del usuario.

#### Scenario: Revisar y aceptar parcialmente
- **WHEN** el usuario recibe una propuesta con varias operaciones
- **THEN** puede inspeccionar el impacto, aceptar o rechazar operaciones individuales y aplicar solo las confirmadas como una versión recuperable

#### Scenario: Cancelar propuesta
- **WHEN** el usuario cancela una propuesta de IA
- **THEN** el modelo permanece sin cambios y la propuesta no se convierte en operaciones colaborativas

### Requirement: Explicación y validación asistida
El asistente SHALL poder explicar elementos o diagramas seleccionados y sugerir correcciones para inconsistencias UML o de trazabilidad MDA, diferenciando sus sugerencias de los errores deterministas del validador.

#### Scenario: Explicar un diagrama
- **WHEN** el usuario pide explicar un diagrama existente
- **THEN** el asistente describe sus participantes, relaciones y flujo basándose únicamente en el contexto autorizado que recibió

#### Scenario: Sugerencia incorrecta o no validable
- **WHEN** una propuesta de IA viola una restricción comprobable del modelo
- **THEN** el sistema la marca como inválida y no permite aplicarla hasta corregirla

### Requirement: Control humano y trazabilidad
Toda operación originada por IA MUST mostrar su origen, prompt o resumen, usuario solicitante y diferencias propuestas; una acción aceptada SHALL atribuirse al usuario que la confirmó y quedar en el historial.

#### Scenario: Aplicar propuesta
- **WHEN** el usuario confirma operaciones válidas de la IA
- **THEN** el sistema crea una nueva revisión atribuida al usuario e identificada como asistida por IA

### Requirement: Privacidad y alcance del contexto
El sistema MUST enviar al proveedor de IA solo el proyecto, diagrama o selección necesarios para la solicitud y MUST NOT incluir proyectos ajenos, códigos de invitación, tokens de sesión ni secretos de configuración.

#### Scenario: Asistencia sobre una selección
- **WHEN** el usuario solicita ayuda sobre elementos seleccionados
- **THEN** el contexto enviado se limita a esos elementos y a las referencias mínimas necesarias, y la interfaz informa el alcance

#### Scenario: Usuario sin permiso de edición
- **WHEN** un colaborador de solo lectura solicita generar cambios
- **THEN** puede recibir explicación o sugerencias, pero el sistema no le permite aplicar modificaciones

### Requirement: Disponibilidad y fallos del proveedor
La aplicación SHALL seguir permitiendo modelado manual cuando la IA no esté configurada, alcance un límite, falle o tarde demasiado, y SHALL mostrar un error recuperable sin alterar el modelo.

#### Scenario: Proveedor no disponible
- **WHEN** la solicitud de IA falla o excede el tiempo límite
- **THEN** el sistema conserva el prompt para reintento, informa la falla y deja el modelo intacto

