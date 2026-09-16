# offline-modeling Specification

## Purpose

Mantener disponibles los proyectos UML recientes y permitir ediciones confiables sin conexión, sincronizándolas de forma explícita cuando el navegador recupere la red.

## Requirements

### Requirement: Aplicación web instalable y disponible sin conexión
La aplicación SHALL poder instalarse como PWA y SHALL cargar su shell de modelado sin red después de una visita en línea satisfactoria.

#### Scenario: Abrir PWA sin red
- **WHEN** un usuario que ya cargó la aplicación abre la PWA sin conexión
- **THEN** el shell inicia, muestra el estado offline y ofrece los proyectos disponibles localmente

#### Scenario: Primera visita sin red
- **WHEN** el navegador nunca almacenó la aplicación y se intenta abrir sin conexión
- **THEN** el sistema muestra el error estándar de disponibilidad sin prometer acceso a contenido no descargado

### Requirement: Copia local de proyectos autorizados
El navegador SHALL almacenar localmente los proyectos que el usuario haya abierto y autorizado para uso offline, junto con la identidad del usuario y la última revisión sincronizada. Un usuario distinto en el mismo navegador MUST NOT acceder a esa copia desde la aplicación.

#### Scenario: Abrir proyecto almacenado
- **WHEN** el usuario autenticado previamente queda sin red y abre un proyecto marcado para offline
- **THEN** el sistema carga la última revisión local con su estado de sincronización

#### Scenario: Cambiar de usuario
- **WHEN** otra cuenta inicia sesión en el mismo navegador
- **THEN** la aplicación no muestra ni abre proyectos offline pertenecientes a la cuenta anterior

### Requirement: Cola offline de operaciones
Las ediciones confirmadas sin conexión SHALL guardarse como operaciones ordenadas e idempotentes antes de reflejarse como guardadas localmente, y SHALL sobrevivir a recargas o cierre del navegador.

#### Scenario: Editar sin conexión
- **WHEN** el usuario modifica un proyecto disponible offline
- **THEN** el cambio aparece en el lienzo, queda en la cola persistente y el estado indica que está pendiente de sincronización

#### Scenario: Cuota local insuficiente
- **WHEN** el navegador no puede persistir una operación por falta de espacio o bloqueo del almacenamiento
- **THEN** el sistema informa que el cambio no está guardado y evita marcarlo como seguro

### Requirement: Sincronización al reconectar
Al recuperar conexión y una sesión válida, el cliente SHALL enviar las operaciones pendientes en orden, recibir las operaciones remotas faltantes y alcanzar el estado confirmado por el servidor sin duplicar cambios.

#### Scenario: Reconexión sin conflictos
- **WHEN** un cliente con cambios offline se reconecta y no existen ediciones incompatibles
- **THEN** el sistema confirma la cola, incorpora cambios remotos y marca el proyecto como sincronizado

#### Scenario: Sesión vencida al reconectar
- **WHEN** el cliente recupera red pero no puede renovar su sesión
- **THEN** conserva la cola local, solicita autenticación y no envía cambios hasta validar la identidad y el permiso

#### Scenario: Permiso retirado mientras estaba offline
- **WHEN** el usuario se reconecta y ya no tiene permiso de edición
- **THEN** el servidor rechaza la cola, el cliente conserva una copia exportable de sus cambios y explica que no puede incorporarlos al proyecto

### Requirement: Conflictos offline visibles
La sincronización SHALL combinar operaciones independientes y SHALL presentar al usuario los cambios incompatibles que no puedan resolverse sin pérdida, conservando alternativas recuperables.

#### Scenario: Conflicto después de trabajo offline
- **WHEN** una operación local y una remota modifican de forma incompatible la misma propiedad base
- **THEN** el sistema marca el conflicto, muestra ambas alternativas y no descarta silenciosamente ninguna

### Requirement: Funciones dependientes de red
En modo offline, el sistema SHALL indicar que invitaciones, presencia en vivo, importaciones procesadas por servidor y asistencia de IA están temporalmente no disponibles, sin impedir la edición local soportada.

#### Scenario: Solicitar IA sin conexión
- **WHEN** el usuario abre el asistente de IA mientras está offline
- **THEN** el sistema conserva opcionalmente el borrador del prompt y explica que debe reconectarse para enviarlo
