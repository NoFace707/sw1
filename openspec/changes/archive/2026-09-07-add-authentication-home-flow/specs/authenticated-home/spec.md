## Purpose

Definir una navegación sencilla en la que toda autenticación exitosa conduce a una única pantalla de inicio protegida, sin dashboard ni panel administrativo.

## ADDED Requirements

### Requirement: Inicio como destino autenticado
El sistema SHALL dirigir a la pantalla de inicio a cualquier usuario que complete correctamente un registro o inicio de sesión, tanto en web como en móvil.

#### Scenario: Redirección después del inicio de sesión
- **WHEN** un usuario inicia sesión correctamente
- **THEN** el cliente reemplaza la pantalla de acceso por la pantalla de inicio

#### Scenario: Redirección después del registro
- **WHEN** una persona completa correctamente el registro y recibe su sesión
- **THEN** el cliente la autentica y muestra directamente la pantalla de inicio

### Requirement: Acceso protegido a inicio
La pantalla de inicio SHALL requerir una sesión válida. Mientras se comprueba una sesión guardada, el cliente MUST mostrar un estado de carga y MUST evitar mostrar transitoriamente contenido protegido o el formulario incorrecto.

#### Scenario: Visitante sin sesión
- **WHEN** una persona sin sesión válida intenta abrir la ruta o pantalla de inicio
- **THEN** el cliente la dirige a la pantalla de inicio de sesión

#### Scenario: Usuario con sesión válida
- **WHEN** un usuario autenticado abre la aplicación o navega a inicio
- **THEN** el cliente muestra la pantalla de inicio y los datos básicos de ese usuario

#### Scenario: Sesión en comprobación
- **WHEN** el cliente todavía está validando o restaurando una sesión guardada
- **THEN** muestra un indicador de carga sin revelar la pantalla protegida

### Requirement: Rutas públicas de autenticación
Las pantallas de inicio de sesión y registro SHALL ser accesibles sin sesión. Un usuario que ya esté autenticado y visite cualquiera de ellas MUST ser redirigido a inicio.

#### Scenario: Usuario autenticado abre el acceso
- **WHEN** un usuario con sesión válida navega a inicio de sesión o registro
- **THEN** el cliente lo redirige a la pantalla de inicio

### Requirement: Ausencia de dashboard
La experiencia final SHALL usar la pantalla de inicio como único destino autenticado inicial y SHALL NOT exponer rutas, enlaces ni controles correspondientes al dashboard o panel administrativo heredado.

#### Scenario: Navegación autenticada
- **WHEN** un usuario revisa las opciones disponibles en la pantalla de inicio
- **THEN** no encuentra accesos a dashboard, administración, roles, bitácora, KPIs ni copias de seguridad

#### Scenario: Ruta administrativa heredada
- **WHEN** una persona intenta abrir una ruta administrativa eliminada
- **THEN** el cliente la conduce a una ruta vigente sin renderizar el panel heredado

