## Purpose

Permitir que los usuarios administren su participación e inviten a su grupo desde el teléfono respetando los permisos y el historial del modelador compartido.

## ADDED Requirements

### Requirement: Unirse mediante código
Un usuario autenticado SHALL poder ingresar o pegar un código de invitación y unirse al proyecto cuando el código esté vigente y tenga usos disponibles.

#### Scenario: Código válido
- **WHEN** el usuario envía un código válido con conexión
- **THEN** la aplicación confirma el proyecto y permiso obtenidos y lo incorpora a su lista

#### Scenario: Código inválido
- **WHEN** el código es desconocido, vencido, agotado o revocado
- **THEN** la aplicación informa que no puede usarse sin revelar datos privados del proyecto

### Requirement: Administrar invitaciones desde móvil
El propietario SHALL poder generar códigos con permiso inicial, vencimiento y límite de usos, compartirlos mediante las opciones del dispositivo y revocarlos.

#### Scenario: Crear y compartir código
- **WHEN** el propietario configura una invitación válida
- **THEN** la aplicación muestra el código una vez creado y permite compartirlo sin incluir tokens de sesión

#### Scenario: Usuario sin propiedad
- **WHEN** un editor o lector abre la administración del grupo
- **THEN** puede consultar los miembros permitidos pero no generar, revocar ni cambiar invitaciones o permisos

### Requirement: Miembros y permisos
La aplicación SHALL reflejar los roles propietario, editor y lector, y SHALL aplicar los mismos permisos que web para consulta, IA, exportación, invitaciones e historial.

#### Scenario: Lector solicita una modificación por IA
- **WHEN** un usuario de solo lectura intenta confirmar una propuesta que modifica el modelo
- **THEN** la aplicación y el servidor rechazan la aplicación manteniendo disponible la explicación

### Requirement: Actualizaciones colaborativas
Con conexión, el cliente SHALL recibir revisiones confirmadas y presencia de colaboradores; las operaciones de IA aceptadas desde móvil SHALL atribuirse al usuario y difundirse como cualquier otra operación.

#### Scenario: Operación móvil confirmada
- **WHEN** un editor confirma una propuesta de IA válida
- **THEN** los demás clientes reciben la operación con autor, origen IA y nueva revisión

#### Scenario: Acceso retirado en vivo
- **WHEN** el propietario retira al usuario mientras tiene el proyecto abierto
- **THEN** el cliente detiene la sincronización, impide confirmar propuestas e informa la pérdida de acceso

### Requirement: Historial compatible con web
El cliente móvil SHALL permitir consultar revisiones, autores y origen de cambios, y SHALL dejar las restauraciones sujetas a los mismos permisos y confirmaciones que web.

#### Scenario: Consultar cambio asistido
- **WHEN** el usuario abre una revisión creada desde móvil
- **THEN** ve que fue asistida por IA, quién la confirmó y qué operaciones contiene

