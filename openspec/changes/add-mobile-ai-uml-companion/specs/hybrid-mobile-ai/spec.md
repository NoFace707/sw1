## Purpose

Proporcionar asistencia móvil continua mediante una API cuando haya red y un modelo GGUF local cuando no la haya, manteniendo el mismo contrato de propuestas revisables.

## ADDED Requirements

### Requirement: Selección de motor de IA
La aplicación SHALL ofrecer modos automático, API y local. Automático MUST preferir la API con conexión y configuración disponible, y MUST usar el motor local cuando esté instalado y la API no esté disponible.

#### Scenario: Modo automático conectado
- **WHEN** existe conexión y el servicio remoto responde
- **THEN** la solicitud se procesa por API y la interfaz identifica el motor usado

#### Scenario: Modo automático sin conexión
- **WHEN** no existe conexión pero el modelo local está instalado y es compatible
- **THEN** la solicitud se procesa íntegramente en el dispositivo

#### Scenario: Ningún motor disponible
- **WHEN** no hay API accesible ni modelo local utilizable
- **THEN** el proyecto permanece visible en solo lectura y la aplicación explica cómo habilitar un motor

### Requirement: Modelo local objetivo
El primer perfil local SHALL ejecutar `Qwen2.5-Coder-1.5B-Instruct-GGUF` con cuantización `Q4_K_M` mediante un runtime `llama.cpp` compatible con Flutter, preservando nombre, versión, licencia, origen y hash del archivo.

#### Scenario: Cargar modelo verificado
- **WHEN** el archivo instalado coincide con el manifiesto y el dispositivo supera los requisitos configurados
- **THEN** la aplicación carga el modelo y muestra que la IA local está disponible

#### Scenario: Archivo alterado
- **WHEN** el hash, tamaño o metadatos no coinciden con el manifiesto
- **THEN** la aplicación rechaza la carga, conserva el visor y ofrece reparar o descargar nuevamente

### Requirement: Gestión de descarga del modelo
El modelo SHALL descargarse solo con consentimiento explícito, mostrando tamaño y recomendación de red/energía; la descarga SHALL poder pausarse, reanudarse, verificarse, actualizarse y eliminarse sin borrar proyectos.

#### Scenario: Descarga interrumpida
- **WHEN** la aplicación pierde red o se cierra durante la descarga
- **THEN** conserva el progreso seguro y permite reanudar sin reiniciar bytes ya verificados

#### Scenario: Eliminar modelo
- **WHEN** el usuario elimina el modelo local
- **THEN** se libera su almacenamiento y la aplicación mantiene proyectos, colas y acceso a IA por API

### Requirement: Inferencia responsable con recursos
La inferencia local MUST ejecutarse fuera del hilo de interfaz, SHALL mostrar progreso o tokens, SHALL poder cancelarse y SHALL evitar cargar el modelo si memoria, arquitectura o almacenamiento no cumplen el perfil mínimo.

#### Scenario: Dispositivo insuficiente
- **WHEN** la comprobación indica recursos incompatibles
- **THEN** la aplicación impide una carga que probablemente cierre el proceso y recomienda API o solo lectura

#### Scenario: Cancelar generación
- **WHEN** el usuario cancela una inferencia local
- **THEN** el runtime libera la sesión correspondiente y ninguna operación parcial modifica el modelo

### Requirement: Propuestas estructuradas de edición
Tanto la IA remota como la local SHALL devolver una propuesta estructurada con operaciones, supuestos, advertencias y revisión base; ninguna operación SHALL aplicarse hasta la confirmación del usuario y validación experta.

#### Scenario: Aceptar parcialmente
- **WHEN** una propuesta contiene varias operaciones
- **THEN** el usuario puede revisar y aceptar solo las válidas que desea antes de actualizar su copia

#### Scenario: Respuesta local inválida
- **WHEN** el modelo local devuelve texto o estructura que no cumple el contrato
- **THEN** el sistema experto intenta una reparación acotada o rechaza la respuesta sin modificar el proyecto

### Requirement: Contexto local limitado
La aplicación SHALL enviar a cada motor solo el diagrama, selección y referencias mínimas necesarias, y MUST NOT incluir tokens, códigos de invitación, secretos ni proyectos no seleccionados.

#### Scenario: Solicitud sobre un elemento
- **WHEN** el usuario pide modificar un elemento seleccionado
- **THEN** el prompt contiene ese submodelo y dependencias requeridas, no el repositorio completo

### Requirement: Dictado móvil mediante Whisper compartido
La aplicación SHALL permitir grabar una instrucción con el micrófono en Android e iOS y SHALL usar el endpoint autenticado compartido para transcribirla con Whisper local en el backend sin una clave externa obligatoria. El audio SHALL ser temporal, MUST eliminarse después del intento y el texto MUST poder editarse antes de enviarlo a cualquier motor de IA.

#### Scenario: Dictar una instrucción
- **WHEN** el usuario concede permiso, graba y detiene el audio mientras tiene conexión
- **THEN** la aplicación muestra el estado de transcripción e inserta el texto resultante en el campo del chat sin crear ni aplicar una propuesta

#### Scenario: Dictado sin conexión o permiso
- **WHEN** no existe conexión, se deniega el micrófono o falla la transcripción
- **THEN** la aplicación conserva el texto previo, informa el problema y mantiene disponibles la escritura y las capacidades locales
