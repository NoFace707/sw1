## Purpose

Aplicar conocimiento determinista de UML, MDA y generación de software para orientar a ambos motores de IA y evitar que una salida plausible pero inválida corrompa el proyecto.

## ADDED Requirements

### Requirement: Base de conocimiento versionada
El sistema experto SHALL usar reglas versionadas para metaclases, relaciones, propiedades, restricciones UML 2.5.1, trazabilidad MDA y mapeos de generación Spring, y SHALL registrar qué versión evaluó cada propuesta.

#### Scenario: Actualizar reglas
- **WHEN** la aplicación descarga una versión compatible y firmada de la base de conocimiento
- **THEN** conserva la versión anterior hasta validar la nueva y registra cuál usa en cada proyecto offline

### Requirement: Preguntas y planificación previa
Antes de pedir una mutación a la IA, el sistema experto SHALL detectar información obligatoria ausente y SHALL formular preguntas concretas o declarar supuestos revisables.

#### Scenario: Relación ambigua
- **WHEN** el usuario pide relacionar dos clases sin indicar multiplicidad ni propiedad
- **THEN** el sistema solicita esos datos o presenta supuestos explícitos antes de construir operaciones

### Requirement: Validación de propuestas
Toda propuesta local o remota MUST pasar por reglas de identidad, permisos, tipos UML, relaciones, revisión base y límites antes de poder confirmarse.

#### Scenario: Relación UML inválida
- **WHEN** la IA propone una relación no permitida entre los tipos indicados
- **THEN** el sistema experto la rechaza o propone una corrección explicada y no habilita su aplicación original

#### Scenario: Operación sin permiso
- **WHEN** un lector recibe una propuesta mutante
- **THEN** el sistema puede explicarla pero la marca como no aplicable

### Requirement: Reparación acotada y explicable
El sistema experto MAY normalizar nombres, completar valores derivados o reordenar operaciones solo mediante reglas deterministas, y SHALL mostrar cada reparación antes de confirmar.

#### Scenario: Dependencia fuera de orden
- **WHEN** la IA propone crear una relación antes de sus elementos
- **THEN** el sistema reordena las operaciones, explica el ajuste y vuelve a validarlas

### Requirement: Diagnóstico sin IA generativa
La aplicación SHALL poder ejecutar offline validaciones y recomendaciones basadas en reglas aunque el modelo local no esté instalado.

#### Scenario: Solo sistema experto disponible
- **WHEN** el usuario abre un proyecto offline sin runtime generativo
- **THEN** puede solicitar validación y recibe problemas deterministas, pero no se inventan nuevas operaciones de diseño

### Requirement: Evidencia de decisión
Cada diagnóstico SHALL identificar regla, severidad, elemento afectado y corrección sugerida, diferenciando hechos deterministas de sugerencias de IA.

#### Scenario: Consultar advertencia
- **WHEN** el usuario abre una advertencia experta
- **THEN** ve qué regla la produjo, por qué aplica y qué cambiaría una corrección propuesta

