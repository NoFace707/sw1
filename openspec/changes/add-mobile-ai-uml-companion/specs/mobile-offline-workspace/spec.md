## Purpose

Permitir consulta y cambios asistidos recuperables en proyectos descargados cuando el teléfono no tenga conexión, sin mezclar identidades ni perder operaciones al sincronizar.

## ADDED Requirements

### Requirement: Disponibilidad offline seleccionable
El usuario SHALL poder marcar proyectos para uso offline y la aplicación SHALL almacenar una revisión completa compatible con el visor móvil, sus metadatos y reglas expertas necesarias.

#### Scenario: Abrir proyecto descargado
- **WHEN** el usuario queda sin red y abre un proyecto preparado para offline
- **THEN** la aplicación muestra la última revisión local y su fecha de sincronización

#### Scenario: Proyecto no descargado
- **WHEN** el usuario intenta abrir sin red un proyecto que nunca preparó para offline
- **THEN** la aplicación explica que el contenido no está disponible y no crea una copia vacía

### Requirement: Aislamiento local por usuario
Las copias, prompts, propuestas, modelos locales y artefactos generados SHALL asociarse a la identidad que los creó. Otra cuenta en el mismo dispositivo MUST NOT verlos desde la aplicación.

#### Scenario: Cambio de cuenta
- **WHEN** una segunda cuenta inicia sesión en el dispositivo
- **THEN** la aplicación oculta los proyectos y artefactos offline de la cuenta anterior

### Requirement: Operaciones de IA offline
Una propuesta producida localmente y confirmada por un editor SHALL guardarse como operaciones idempotentes sobre una revisión base y SHALL actualizar la copia local sin afirmar que ya está sincronizada.

#### Scenario: Confirmar propuesta local
- **WHEN** el usuario acepta operaciones válidas de la IA local
- **THEN** el visor refleja el resultado, la cola persiste tras cerrar la app y el estado indica pendiente

#### Scenario: Cierre inesperado
- **WHEN** la aplicación se cierra después de confirmar pero antes de sincronizar
- **THEN** al volver a abrir conserva la operación y no la aplica dos veces

### Requirement: Reconciliación al reconectar
Al recuperar conexión y sesión, el cliente SHALL descargar revisiones remotas, enviar su cola en orden y mostrar cualquier conflicto sin descartar alternativas.

#### Scenario: Sincronización sin conflicto
- **WHEN** los cambios locales afectan propiedades distintas de los cambios remotos
- **THEN** el servidor conserva ambos y el cliente alcanza la revisión canónica

#### Scenario: Conflicto semántico
- **WHEN** una operación local choca con otra remota sobre la misma propiedad o elemento eliminado
- **THEN** la aplicación muestra ambas alternativas y exige una resolución autorizada

#### Scenario: Permiso retirado
- **WHEN** el usuario ya no puede editar al reconectar
- **THEN** la cola no se envía como válida y la aplicación ofrece conservar o exportar una copia de recuperación

### Requirement: Gestión de almacenamiento offline
La aplicación SHALL informar el espacio ocupado por proyectos, modelo IA y artefactos, SHALL permitir eliminarlos por separado y MUST detectar falta de almacenamiento antes de prometer una descarga o guardado.

#### Scenario: Espacio insuficiente
- **WHEN** no existe espacio suficiente para el proyecto, modelo o ZIP solicitado
- **THEN** la aplicación no inicia o revierte limpiamente la operación y ofrece liberar contenido local

### Requirement: Acciones dependientes del servidor
Sin conexión, nuevas invitaciones y verificaciones de compilación SHALL quedar deshabilitadas o como borradores pendientes, y MUST NOT mostrarse como completadas hasta recibir confirmación del servidor.

#### Scenario: Preparar invitación offline
- **WHEN** el propietario configura una invitación sin red
- **THEN** la aplicación conserva un borrador y explica que el código real se generará al reconectar

