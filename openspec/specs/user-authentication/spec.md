# user-authentication Specification

## Purpose
Proporcionar un acceso de usuarios simple y compartido por web y móvil, con registro inmediato, sesiones restaurables y persistencia opcional en el navegador.

## Requirements

### Requirement: Registro de usuario
El sistema SHALL permitir que una persona se registre con nombre, apellido, correo electrónico y contraseña. El correo MUST normalizarse y ser único, la contraseña MUST almacenarse mediante el mecanismo de hash del servidor y la cuenta creada MUST quedar activa sin verificación por correo.

#### Scenario: Registro correcto
- **WHEN** una persona envía todos los datos válidos con un correo no registrado
- **THEN** el sistema crea una cuenta activa, devuelve el usuario y una sesión utilizable, y no devuelve la contraseña

#### Scenario: Correo ya registrado
- **WHEN** una persona intenta registrarse con un correo que ya pertenece a otra cuenta, sin importar diferencias de mayúsculas
- **THEN** el sistema rechaza la solicitud con un mensaje que identifica el correo duplicado y no crea otra cuenta

#### Scenario: Datos de registro inválidos
- **WHEN** falta un campo obligatorio, el correo no tiene formato válido o la contraseña no cumple la longitud mínima configurada
- **THEN** el sistema rechaza el registro e informa los campos que deben corregirse

### Requirement: Inicio de sesión
El sistema SHALL permitir iniciar sesión con correo electrónico y contraseña en los clientes web y móvil, y MUST entregar los datos básicos del usuario junto con credenciales de sesión renovables cuando las credenciales sean válidas.

#### Scenario: Credenciales válidas
- **WHEN** un usuario activo presenta un correo y contraseña correctos
- **THEN** el sistema inicia su sesión y devuelve la información necesaria para autenticar solicitudes posteriores

#### Scenario: Credenciales inválidas
- **WHEN** el correo no existe o la contraseña no coincide
- **THEN** el sistema rechaza el acceso con un mensaje genérico y no crea una sesión

### Requirement: Opción Recordarme en el navegador
El cliente web SHALL mostrar una opción «Recordarme». Si está seleccionada, MUST conservar la sesión tras cerrar y volver a abrir el navegador; si no está seleccionada, MUST limitar la sesión al almacenamiento de la sesión actual del navegador. En ningún caso SHALL persistir la contraseña ingresada.

#### Scenario: Usuario elige Recordarme
- **WHEN** un usuario inicia sesión con «Recordarme» seleccionado y vuelve a abrir el navegador mientras su sesión siga siendo renovable
- **THEN** el cliente restaura la sesión sin pedir nuevamente las credenciales

#### Scenario: Usuario no elige Recordarme
- **WHEN** un usuario inicia sesión sin «Recordarme» y finaliza la sesión del navegador
- **THEN** el siguiente acceso al sitio solicita nuevamente sus credenciales

#### Scenario: Contraseña no persistida
- **WHEN** el cliente guarda cualquier modalidad de sesión
- **THEN** el almacenamiento administrado por la aplicación contiene solo datos de usuario y credenciales de sesión, nunca la contraseña

### Requirement: Restauración y renovación de sesión
Los clientes web y móvil SHALL comprobar al iniciar si existe una sesión guardada, SHALL recuperar el usuario cuando sea válida y SHALL intentar renovarla cuando la credencial de acceso haya expirado pero la credencial de renovación siga vigente.

#### Scenario: Sesión guardada válida
- **WHEN** se abre el cliente con una sesión válida almacenada
- **THEN** el usuario continúa autenticado sin atravesar nuevamente el formulario de acceso

#### Scenario: Sesión renovable
- **WHEN** la credencial de acceso expiró y la credencial de renovación es válida
- **THEN** el sistema renueva el acceso y conserva al usuario autenticado

#### Scenario: Sesión inválida o vencida
- **WHEN** la sesión guardada no puede validarse ni renovarse
- **THEN** el cliente elimina todos sus datos locales de sesión y muestra el acceso

### Requirement: Cierre de sesión
El sistema SHALL permitir cerrar sesión desde web y móvil, y el cliente MUST eliminar las credenciales y los datos de usuario almacenados independientemente de que el servidor responda correctamente.

#### Scenario: Cierre de sesión correcto
- **WHEN** un usuario selecciona cerrar sesión
- **THEN** el cliente elimina la sesión local y conduce al usuario a la pantalla de acceso

#### Scenario: Servidor no disponible durante el cierre
- **WHEN** el usuario cierra sesión y el servidor no puede atender la solicitud
- **THEN** el cliente igualmente elimina la sesión local y bloquea el acceso a contenido autenticado
