# collaborative-modeling Specification

## Purpose

Permitir que grupos autenticados compartan proyectos mediante códigos de invitación y editen un mismo modelo de forma concurrente, trazable y recuperable.

## Requirements

### Requirement: Membresía y permisos de proyecto
Cada proyecto SHALL tener un propietario y SHALL admitir colaboradores con permiso de edición o solo lectura. Solo el propietario MUST poder cambiar permisos, retirar miembros, transferir propiedad o eliminar el proyecto.

#### Scenario: Colaborador editor
- **WHEN** un miembro con permiso de edición abre el proyecto
- **THEN** puede modificar modelos y diagramas pero no administrar propiedad ni miembros

#### Scenario: Colaborador lector
- **WHEN** un miembro con permiso de solo lectura abre el proyecto
- **THEN** puede navegar, validar y exportar, pero el sistema rechaza cualquier operación de modificación

### Requirement: Código de invitación
El propietario SHALL poder generar un código de invitación asociado a un único proyecto, con permiso inicial, fecha de vencimiento y límite de usos configurables, y SHALL poder revocarlo.

#### Scenario: Unirse con código válido
- **WHEN** un usuario autenticado presenta un código vigente con usos disponibles
- **THEN** el sistema lo agrega al proyecto con el permiso definido y consume un uso del código

#### Scenario: Código inválido, vencido o revocado
- **WHEN** un usuario presenta un código desconocido, vencido, agotado o revocado
- **THEN** el sistema rechaza la unión sin revelar información privada del proyecto

#### Scenario: Regenerar invitación
- **WHEN** el propietario revoca un código y genera otro
- **THEN** el código anterior deja de funcionar y el nuevo aplica sus propias restricciones

### Requirement: Presencia en tiempo real
Mientras un proyecto esté abierto en línea, el sistema SHALL mostrar qué colaboradores están conectados y, cuando sea posible, qué diagrama o elemento están editando.

#### Scenario: Colaborador entra al proyecto
- **WHEN** un segundo colaborador abre el mismo proyecto
- **THEN** los participantes conectados ven su presencia sin recargar la página

#### Scenario: Colaborador pierde conexión
- **WHEN** un colaborador se desconecta o deja de enviar presencia
- **THEN** el sistema lo marca como desconectado después del intervalo configurado sin perder sus cambios confirmados

### Requirement: Convergencia de edición concurrente
Las operaciones concurrentes válidas SHALL converger al mismo estado para todos los clientes conectados. El sistema MUST ordenar o combinar operaciones mediante revisiones estables y MUST NOT sobrescribir silenciosamente ediciones incompatibles sobre la misma propiedad.

#### Scenario: Cambios simultáneos independientes
- **WHEN** dos usuarios modifican elementos diferentes desde la misma revisión
- **THEN** ambos cambios se conservan y todos los clientes convergen al mismo modelo

#### Scenario: Conflicto sobre la misma propiedad
- **WHEN** dos usuarios cambian simultáneamente la misma propiedad a valores incompatibles
- **THEN** el sistema aplica una regla determinista, conserva ambas alternativas en el historial y notifica el conflicto a los usuarios afectados

#### Scenario: Operación duplicada
- **WHEN** un cliente reenvía una operación ya confirmada por pérdida de conexión
- **THEN** el sistema la reconoce como duplicada y no vuelve a aplicarla

### Requirement: Historial y restauración
El sistema SHALL mantener un historial atribuible de operaciones y versiones del proyecto, SHALL crear puntos recuperables antes de importaciones o acciones masivas de IA y SHALL permitir al propietario restaurar una versión como una nueva revisión.

#### Scenario: Consultar historial
- **WHEN** un miembro abre el historial
- **THEN** ve revisiones con autor, fecha, origen y resumen de cambios conforme a su permiso

#### Scenario: Restaurar versión
- **WHEN** el propietario confirma restaurar una versión anterior
- **THEN** el sistema crea una nueva revisión con ese contenido, preservando el historial posterior para auditoría y posible recuperación

### Requirement: Autorización en tiempo real y API
Toda lectura, escritura, presencia, invitación y descarga SHALL comprobar la membresía y permiso del usuario tanto en solicitudes HTTP como en el canal en tiempo real.

#### Scenario: Acceso retirado durante una sesión
- **WHEN** el propietario retira a un colaborador que mantiene el proyecto abierto
- **THEN** el servidor rechaza nuevas operaciones, cierra o degrada su canal y el cliente informa que perdió acceso
