# uml-model-interchange Specification

## Purpose

Permitir que los modelos salgan y entren del producto mediante formatos XMI actuales, con validación explícita y compatibilidad comprobable con Sparx Enterprise Architect.

## Requirements

### Requirement: Perfil normativo de intercambio
El sistema SHALL importar y exportar modelos usando UML 2.5.1 sobre XMI 2.5.1, con namespaces y metamodelos identificables, y SHALL incluir información UML Diagram Interchange cuando el contenido visual pueda representarse mediante el estándar.

#### Scenario: Exportación normativa válida
- **WHEN** el usuario exporta un proyecto con el perfil OMG UML 2.5.1/XMI 2.5.1
- **THEN** el sistema genera un archivo XML bien formado con identidades, paquetes, elementos, relaciones y diagramas soportados que supera el validador de conformidad del producto

#### Scenario: Importación normativa
- **WHEN** el usuario importa un XMI 2.5.1 válido que usa elementos soportados de UML 2.5.1
- **THEN** el sistema crea un proyecto o paquete equivalente y presenta sus elementos y diagramas sin cambiar el archivo original

### Requirement: Perfil de Sparx Enterprise Architect
El sistema SHALL ofrecer un perfil de intercambio UML 2.5.1 basado en XMI 2.1 que pueda importarse en Sparx Enterprise Architect 17.2 y SHALL aceptar archivos XMI 2.1 exportados por esa versión para el subconjunto UML soportado.

#### Scenario: Abrir exportación en Enterprise Architect
- **WHEN** el usuario exporta con el perfil Enterprise Architect e importa el archivo en Sparx Enterprise Architect 17.2
- **THEN** Enterprise Architect abre el paquete, reconoce los elementos y relaciones soportados y muestra los diagramas cuya presentación sea intercambiable

#### Scenario: Importar desde Enterprise Architect
- **WHEN** el usuario importa un XMI 2.1 producido por Sparx Enterprise Architect 17.2
- **THEN** el sistema reconstruye el contenido UML soportado y reporta por separado las extensiones propietarias que no interpretó

#### Scenario: Ida y vuelta
- **WHEN** un fixture de compatibilidad se exporta a Enterprise Architect, se vuelve a exportar desde esa herramienta y se reimporta
- **THEN** las identidades semánticas comparables, nombres, propiedades esenciales y relaciones del subconjunto soportado permanecen equivalentes

### Requirement: Selección explícita de perfil
La interfaz SHALL explicar la diferencia entre el perfil normativo XMI 2.5.1 y el perfil Enterprise Architect XMI 2.1 antes de generar el archivo, y MUST registrar en el archivo o sus metadatos el perfil seleccionado.

#### Scenario: Elegir destino
- **WHEN** el usuario inicia una exportación
- **THEN** puede seleccionar «OMG XMI 2.5.1» o «Sparx Enterprise Architect (XMI 2.1)» y ve una descripción breve de compatibilidad

### Requirement: Importación transaccional y segura
El sistema MUST analizar y validar el XML antes de modificar un proyecto, MUST rechazar entidades externas y construcciones XML peligrosas, y SHALL aplicar la importación como una nueva versión recuperable.

#### Scenario: Archivo malformado
- **WHEN** el usuario selecciona un XML/XMI malformado o con una entidad externa prohibida
- **THEN** el sistema rechaza el archivo sin modificar el proyecto y muestra el motivo

#### Scenario: Falla durante la conversión
- **WHEN** ocurre un error después de comenzar a interpretar un archivo
- **THEN** el proyecto permanece en su versión anterior y el sistema no deja contenido parcialmente importado

### Requirement: Informe de compatibilidad y pérdidas
Antes de confirmar una importación y después de una exportación, el sistema SHALL presentar un informe de errores, advertencias, extensiones desconocidas y elementos visuales o semánticos que no puedan conservarse exactamente.

#### Scenario: Extensión propietaria desconocida
- **WHEN** un XMI contiene una extensión de proveedor no soportada
- **THEN** el informe identifica su ubicación, la conserva como dato opaco cuando sea seguro o declara su omisión, y permite al usuario decidir si continúa

#### Scenario: Pérdida de disposición visual
- **WHEN** el modelo semántico puede importarse pero la disposición del diagrama no puede reconstruirse
- **THEN** el sistema informa la pérdida visual y crea una disposición automática sin afirmar que el resultado es idéntico

### Requirement: Identidades estables en reimportación
El sistema SHALL conservar identificadores XMI y correspondencias externas cuando sea posible para reducir duplicados y mantener referencias en intercambios repetidos.

#### Scenario: Reimportar una versión conocida
- **WHEN** el usuario reimporta un paquete previamente intercambiado y los identificadores externos coinciden
- **THEN** el sistema ofrece actualizar o crear una copia y muestra el alcance de los cambios antes de aplicarlos
