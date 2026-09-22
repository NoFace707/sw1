# Casos de Uso - Proyecto SW1: Plataforma de Modelado UML Colaborativo

## Actores Principales

| Actor | Descripción |
|-------|-------------|
| **Persona No Registrada** | Usuario que aún no tiene cuenta en el sistema |
| **Usuario Registrado** | Persona con cuenta activa que puede autenticarse |
| **Propietario del Proyecto** | Usuario que creó un proyecto y tiene control total sobre él |
| **Colaborador Editor** | Usuario invitado que puede editar diagramas del proyecto |
| **Colaborador Lector** | Usuario invitado con acceso de solo lectura al proyecto |
| **Proveedor de IA** | Servicio externo que procesa solicitudes de modelado inteligente |
| **Navegador/PWA** | Cliente local que maneja almacenamiento offline y sincronización |
| **Sparx Enterprise Architect** | Herramienta externa para intercambio de modelos XMI |

---

## 1. AUTENTICACIÓN Y GESTIÓN DE CUENTA

| CU | Nombre | Actor(es) | Descripción |
|----|--------|-----------|-------------|
| CU-01 | Registrar usuario | Persona No Registrada | El sistema permite el registro de un nuevo usuario con nombre, apellido, correo electrónico y contraseña. El correo debe ser único y normalizado. La contraseña se almacena hasheada. |
| CU-02 | Iniciar sesión | Persona No Registrada, Navegador/PWA | El usuario ingresa correo y contraseña para autenticarse. El sistema valida las credenciales y establece una sesión renovable. |
| CU-03 | Recordar sesión | Usuario Registrado, Navegador/PWA | El usuario selecciona "Recordarme" para que la sesión persista al cerrar y abrir el navegador. La sesión se renueva automáticamente mientras sea válida. |
| CU-04 | Restaurar sesión | Navegador/PWA, Usuario Registrado | Al iniciar la aplicación, el navegador verifica si existe una sesión válida almacenada. Si es válida, restaura el acceso al usuario. Si expiró, solicita autenticación nuevamente. |
| CU-05 | Cerrar sesión | Usuario Registrado | El usuario solicita cerrar sesión. El sistema elimina todas las credenciales y datos de usuario del cliente, independientemente de la respuesta del servidor. |
| CU-06 | Rechazar correo duplicado | Persona No Registrada | El sistema detecta si el correo electrónico ya está registrado (incluyendo diferencias de mayúsculas) y muestra un mensaje indicando que la cuenta ya existe. |
| CU-07 | Validar datos de registro | Persona No Registrada | El sistema valida que todos los campos obligatorios estén completos y cumplan con los formatos esperados antes de crear la cuenta. |

---

## 2. NAVEGACIÓN Y PANTALLA DE INICIO

| CU | Nombre | Actor(es) | Descripción |
|----|--------|-----------|-------------|
| CU-08 | Acceder a pantalla de inicio autenticada | Usuario Registrado | Tras un login exitoso, el usuario es redirigido automáticamente a la pantalla de inicio protegida. |
| CU-09 | Redirigir no autenticados | Persona No Registrada | Un usuario sin sesión que intenta acceder a rutas protegidas es redirigido a la pantalla de inicio de sesión. |
| CU-10 | Redirigir autenticados desde rutas públicas | Usuario Registrado | Si un usuario con sesión activa accede a login o registro, el sistema lo redirige a la pantalla de inicio. |
| CU-11 | Mostrar indicador de carga | Navegador/PWA | Mientras se verifica una sesión almacenada, el sistema muestra un indicador de carga sin revelar contenido protegido. |
| CU-12 | Manejar rutas administrativas eliminadas | Usuario Registrado | Si alguien intenta acceder a una ruta administrativa que ya no existe, el sistema lo conduce a la ruta vigente correspondiente. |

---

## 3. GESTIÓN DE PROYECTOS

| CU | Nombre | Actor(es) | Descripción |
|----|--------|-----------|-------------|
| CU-13 | Crear nuevo proyecto | Propietario del Proyecto | El usuario crea un proyecto UML nuevo con nombre y configuración inicial. El usuario se convierte automáticamente en propietario. |
| CU-14 | Abrir proyecto existente | Usuario Registrado | El usuario selecciona un proyecto de la lista de proyectos recientes o busca uno para abrir el editor de modelado. |
| CU-15 | Ver proyectos recientes | Usuario Registrado | La pantalla de inicio muestra la lista de proyectos a los que el usuario tiene acceso, ordenados por última actividad. |
| CU-16 | Eliminar proyecto | Propietario del Proyecto | Solo el propietario puede eliminar un proyecto. El sistema solicita confirmación y elimina todos los datos asociados. |
| CU-17 | Transferir propiedad | Propietario del Proyecto, Colaborador Editor | El propietario puede transferir la titularidad del proyecto a otro colaborador editor, renunciando a sus privilegios de propietario. |

---

## 4. MODELADO UML

| CU | Nombre | Actor(es) | Descripción |
|----|--------|-----------|-------------|
| CU-18 | Crear diagrama de clases | Colaborador Editor, Propietario del Proyecto | El usuario crea un nuevo diagrama de clases dentro del proyecto, con su propio lienzo y paleta de herramientas. |
| CU-19 | Crear diagrama de casos de uso | Colaborador Editor, Propietario del Proyecto | El usuario crea un diagrama de casos de uso para representar funcionalidades del sistema desde la perspectiva del usuario. |
| CU-20 | Crear diagrama de secuencia | Colaborador Editor, Propietario del Proyecto | El usuario crea un diagrama de secuencia para modelar interacciones temporizadas entre objetos. |
| CU-21 | Crear diagrama de actividades | Colaborador Editor, Propietario del Proyecto | El usuario crea un diagrama de actividades para modelar flujos de trabajo y procesos. |
| CU-22 | Crear diagrama de estados | Colaborador Editor, Propietario del Proyecto | El usuario crea un diagrama de máquinas de estados para modelar el ciclo de vida de un objeto. |
| CU-23 | Agregar elemento UML | Colaborador Editor, Propietario del Proyecto | El usuario arrastra un elemento desde la paleta hacia el lienzo para crear una clase, actor, caso de uso, objeto, etc. |
| CU-24 | Conectar elementos | Colaborador Editor, Propietario del Proyecto | El usuario establece relaciones entre elementos (asociación, herencia, dependencia, etc.) usando herramientas de conexión. |
| CU-25 | Editar propiedades de elemento | Colaborador Editor, Propietario del Proyecto | El usuario selecciona un elemento y modifica sus propiedades (nombre, atributos, operaciones, estereotipos) en un panel de propiedades. |
| CU-26 | Mover y redimensionar elementos | Colaborador Editor, Propietario del Proyecto | El usuario arrastra elementos para reposararlos o redimensionarlos visualmente en el diagrama. |
| CU-27 | Copiar y pegar elementos | Colaborador Editor, Propietario del Proyecto | El usuario selecciona elementos y los copia/pega dentro del mismo diagrama o entre diagramas del proyecto. |
| CU-28 | Eliminar elemento de diagrama | Colaborador Editor, Propietario del Proyecto | El usuario elimina la representación visual de un elemento del diagrama. El elemento semántico permanece en el modelo si tiene otras representaciones. |
| CU-29 | Eliminar elemento del modelo | Colaborador Editor, Propietario del Proyecto | El usuario elimina un elemento del modelo semántico. El sistema muestra el impacto antes de confirmar y elimina o marca como inválidas todas las representaciones dependientes. |
| CU-30 | Deshacer operación | Colaborador Editor, Propietario del Proyecto | El usuario revierte su última operación de edición. La acción solo afecta cambios locales, no los realizados por otros colaboradores. |
| CU-31 | Rehacer operación | Colaborador Editor, Propietario del Proyecto | El usuario re-aplica una operación que había sido deshecha. |
| CU-32 | Hacer zoom y paneo | Colaborador Editor, Propietario del Proyecto | El usuario ajusta el nivel de zoom del diagrama y se desplaza por el lienzo para navegar entre áreas de trabajo. |
| CU-33 | Seleccionar múltiples elementos | Colaborador Editor, Propietario del Proyecto | El usuario selecciona varios elementos simultáneamente para realizar operaciones grupales (mover, copiar, eliminar). |
| CU-34 | Validar restricciones UML | Colaborador Editor, Propietario del Proyecto, Colaborador Lector | El usuario ejecuta la validación del modelo para identificar errores estructurales y advertencias UML. Los errores impiden exportar. |
| CU-35 | Cambiar tipo de diagrama | Colaborador Editor, Propietario del Proyecto | El usuario cambia el tipo de un diagrama existente. El sistema verifica compatibilidad y rechaza conversiones destructivas. |

---

## 5. MODELANDO COLABORATIVO

| CU | Nombre | Actor(es) | Descripción |
|----|--------|-----------|-------------|
| CU-36 | Generar código de invitación | Propietario del Proyecto | El propietario genera un código de invitación con permiso inicial (editor o lector), fecha de vencimiento y límite de usos. |
| CU-37 | Unirse a proyecto con código | Usuario Registrado | Un usuario ingresa un código de invitación válido para unirse a un proyecto. El código se valida y se consume. |
| CU-38 | Rechazar código inválido | Usuario Registrado | El sistema rechaza códigos vencidos, agotados o revocados sin revelar información privada del proyecto. |
| CU-39 | Ver colaboradores conectados | Propietario del Proyecto, Colaborador Editor, Colaborador Lector | Los usuarios ven en tiempo real qué colaboradores están conectados al proyecto actualmente. |
| CU-40 | Editar concurrentemente | Propietario del Proyecto, Colaborador Editor | Múltiples editores modifican el mismo diagrama simultáneamente. Las operaciones convergen al mismo estado determinista. |
| CU-41 | Resolver conflicto de edición | Propietario del Proyecto, Colaborador Editor | Cuando dos editores modifican la misma propiedad, el sistema aplica una regla determinista, conserva ambas alternativas en el historial y notifica a los usuarios. |
| CU-42 | Retirar colaborador | Propietario del Proyecto | El propietario retira el acceso de un colaborador. Si el colaborador tiene sesión abierta, el servidor rechaza sus operaciones y cierra o degrada su canal. |
| CU-43 | Cambiar permisos de colaborador | Propietario del Proyecto | El propietario cambia el nivel de permiso de un colaborador (de lector a editor o viceversa). |
| CU-44 | Ver historial de operaciones | Propietario del Proyecto, Colaborador Editor, Colaborador Lector | Los usuarios pueden consultar el historial de cambios del proyecto, viendo autor, fecha, origen y resumen de cada operación. |
| CU-45 | Restaurar versión anterior | Propietario del Proyecto | El propietario selecciona una versión del historial y la restaura como nueva revisión, preservando el historial posterior para auditoría. |

---

## 6. ASISTENTE DE IA

| CU | Nombre | Actor(es) | Descripción |
|----|--------|-----------|-------------|
| CU-46 | Generar diagrama desde lenguaje natural | Colaborador Editor, Propietario del Proyecto, Proveedor de IA | El usuario describe en lenguaje natural qué quiere modelar y la IA propone un diagrama completo con elementos y relaciones. |
| CU-47 | Proponer modificaciones a diagrama | Colaborador Editor, Propietario del Proyecto, Proveedor de IA | El usuario solicita a la IA que agregue, actualice o elimine elementos de un diagrama existente. La IA presenta una vista previa con supuestos y advertencias. |
| CU-48 | Explicar elemento UML | Colaborador Editor, Colaborador Lector, Proveedor de IA | El usuario selecciona un elemento y solicita una explicación de su significado, uso y relaciones con otros elementos. |
| CU-49 | Sugerir correcciones de consistencia | Colaborador Editor, Propietario del Proyecto, Proveedor de IA | La IA analiza el modelo y sugiere correcciones para inconsistencias UML o problemas de trazabilidad MDA. |
| CU-50 | Rechazar operaciones de IA | Colaborador Editor, Propietario del Proyecto | El usuario revisa las propuestas de la IA y puede aceptar, rechazar o modificar parcialmente las operaciones antes de aplicarlas. |
| CU-51 | Ver trazabilidad de operaciones IA | Colaborador Editor, Propietario del Proyecto | El sistema mantiene un registro completo de todas las operaciones generadas por la IA, incluyendo qué usuario las confirmó. |

---

## 7. INTERCAMBIO DE MODELOS (XMI)

| CU | Nombre | Actor(es) | Descripción |
|----|--------|-----------|-------------|
| CU-52 | Exportar modelo a XMI normativo | Colaborador Editor, Propietario del Proyecto | El usuario exporta el modelo a formato XMI 2.5.1 normativo UML. El sistema genera XML bien formado con identidades estables. |
| CU-53 | Exportar para Sparx Enterprise Architect | Colaborador Editor, Propietario del Proyecto | El usuario exporta el modelo en perfil XMI 2.1 compatible con Sparx Enterprise Architect 17.2. |
| CU-54 | Seleccionar perfil de exportación | Colaborador Editor, Propietario del Proyecto | Antes de exportar, el usuario selecciona explícitamente el perfil (normativo o EA) y el sistema explica las diferencias. |
| CU-55 | Importar modelo XMI | Colaborador Editor, Propietario del Proyecto | El usuario importa un archivo XMI al proyecto. El sistema valida el XML antes de modificar el proyecto y aplica la importación como nueva versión recuperable. |
| CU-56 | Rechazar archivo malformado | Colaborador Editor, Propietario del Proyecto | Si el archivo XMI importado tiene errores de formato, el sistema lo rechaza sin modificar el proyecto y muestra el motivo del rechazo. |
| CU-57 | Ver informe de compatibilidad | Colaborador Editor, Propietario del Proyecto | Después de importar o exportar, el sistema muestra un informe con errores, advertencias, extensiones desconocidas y pérdidas detectadas. |
| CU-58 | Manejar extensión propietaria desconocida | Colaborador Editor, Propietario del Proyecto | Cuando se encuentra una extensión propietaria desconocida, el sistema la conserva como dato opaco o declara su omisión, y el usuario decide si continúa. |
| CU-59 | Preservar identidades en reimportación | Colaborador Editor, Propietario del Proyecto | Al reimportar un archivo XMI previamente exportado, el sistema conserva identificadores XMI y correspondencias externas para minimizar duplicados. |

---

## 8. MODO OFFLINE

| CU | Nombre | Actor(es) | Descripción |
|----|--------|-----------|-------------|
| CU-60 | Instalar PWA | Navegador/PWA, Usuario Registrado | El usuario instala la aplicación como PWA para acceder al shell de modelado sin conexión después de una visita en línea exitosa. |
| CU-61 | Editar sin conexión | Colaborador Editor, Propietario del Proyecto, Navegador/PWA | El usuario realiza ediciones en modo offline. Las operaciones se almacenan en una cola ordenada e idempotente que sobrevive recargas y cierre del navegador. |
| CU-62 | Sincronizar al reconectar | Navegador/PWA, Colaborador Editor, Propietario del Proyecto | Al recuperar la conexión, el sistema envía las operaciones pendientes en orden, recibe las remotas faltantes y alcanza estado confirmado sin duplicar. |
| CU-63 | Manejar conflicto offline | Navegador/PWA, Colaborador Editor | Cuando hay conflictos entre cambios locales y remotos, el sistema marca ambas alternativas, las muestra al usuario y no descarta silenciosamente ninguna. |
| CU-64 | Detectar funciones no disponibles offline | Navegador/PWA, Usuario Registrado | En modo offline, el sistema indica que funciones como invitaciones, presencia en tiempo real, IA e importaciones server-side no están disponibles temporalmente. |
| CU-65 | Manejar sesión vencida al reconectar | Navegador/PWA, Usuario Registrado | Si la sesión expiró mientras el usuario estaba offline, el sistema conserva la cola local, solicita autenticación y no envía cambios hasta validar la identidad. |
| CU-66 | Manejar permiso retirado offline | Navegador/PWA, Propietario del Proyecto, Colaborador Editor | Si el propietario retira el permiso de un colaborador mientras este está offline, el servidor rechaza la cola al sincronizar pero el cliente conserva una copia exportable. |
| CU-67 | Gestionar cuota local insuficiente | Navegador/PWA, Usuario Registrado | Cuando el almacenamiento local es insuficiente, el sistema informa que el cambio no se guardó y evita marcarlo como seguro. |

---

## 9. ORGANIZACIÓN MDA

| CU | Nombre | Actor(es) | Descripción |
|----|--------|-----------|-------------|
| CU-68 | Clasificar paquete como CIM | Colaborador Editor, Propietario del Proyecto | El usuario clasifica un paquete o modelo como CIM (Computational Independent Model) para organización de niveles de abstracción. |
| CU-69 | Clasificar paquete como PIM | Colaborador Editor, Propietario del Proyecto | El usuario clasifica un paquete como PIM (Platform Independent Model) para modelado independiente de plataforma. |
| CU-70 | Clasificar paquete como PSM | Colaborador Editor, Propietario del Proyecto | El usuario clasifica un paquete como PSM (Platform Specific Model) para modelado dependiente de plataforma concreta. |
| CU-71 | Crear trazabilidad entre niveles MDA | Colaborador Editor, Propietario del Proyecto | El usuario crea vínculos de trazabilidad entre elementos de diferentes niveles MDA para documentar la transformación de modelos. |
| CU-72 | Editar elemento sin clasificación MDA | Colaborador Editor, Propietario del Proyecto | El usuario puede editar un elemento sin nivel MDA asignado. El sistema lo reporta como no clasificado sin asignar nivel automáticamente. |

---

## 10. GUARDADO Y PERSISTENCIA

| CU | Nombre | Actor(es) | Descripción |
|----|--------|-----------|-------------|
| CU-73 | Guardado automático | Navegador/PWA, Colaborador Editor | Las operaciones confirmadas se guardan automáticamente con un indicador de estado (guardado, pendiente, conflicto). |
| CU-74 | Manejar falla de guardado | Navegador/PWA, Colaborador Editor | Si falla el guardado, el sistema conserva la operación localmente, muestra estado pendiente y permite reintentar. |
| CU-75 | Identificar inconsistencia UML | Colaborador Editor, Propietario del Proyecto, Colaborador Lector | El sistema identifica el elemento afectado por una inconsistencia, explica el problema y ofrece navegación directa hacia él. |

---

## Resumen por Actor

| Actor | Casos de Uso Asociados |
|-------|------------------------|
| Persona No Registrada | CU-01, CU-02, CU-06, CU-07 |
| Usuario Registrado | CU-02, CU-03, CU-04, CU-05, CU-08, CU-09, CU-10, CU-15, CU-37, CU-38, CU-60, CU-64, CU-65, CU-67 |
| Propietario del Proyecto | CU-13, CU-16, CU-17, CU-18-CU-35, CU-36, CU-39-CU-45, CU-46-CU-51, CU-52-CU-59, CU-61-CU-63, CU-66, CU-68-CU-75 |
| Colaborador Editor | CU-18-CU-35, CU-39-CU-45, CU-46-CU-51, CU-52-CU-59, CU-61-CU-63, CU-68-CU-75 |
| Colaborador Lector | CU-34, CU-39, CU-44, CU-48 |
| Proveedor de IA | CU-46, CU-47, CU-48, CU-49 |
| Navegador/PWA | CU-02, CU-03, CU-04, CU-11, CU-60-CU-67, CU-73, CU-74 |
| Sparx Enterprise Architect | CU-53 |

---

## Total de Casos de Uso: 75
