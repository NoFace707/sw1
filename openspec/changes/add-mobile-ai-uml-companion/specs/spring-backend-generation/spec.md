## Purpose

Transformar un modelo UML suficientemente completo en un proyecto backend Spring Boot Java reproducible, descargable y verificable, usando IA para interpretar intención y plantillas para producir código estable.

## ADDED Requirements

### Requirement: Alcance del backend generado
El generador SHALL producir inicialmente un proyecto Maven para Spring Boot 4.1.x y Java 21 con Spring Web, Data JPA, Jakarta Validation, PostgreSQL, entidades, DTOs, repositorios, servicios, controladores REST, manejo global de errores, configuración, migración inicial, Dockerfile y pruebas.

#### Scenario: Modelo CRUD suficiente
- **WHEN** el proyecto contiene clases persistentes, atributos, identificadores y relaciones válidas
- **THEN** el generador produce un backend con operaciones CRUD coherentes y configuración documentada para PostgreSQL

#### Scenario: Función fuera del perfil
- **WHEN** el modelo solicita una tecnología o función sin plantilla soportada
- **THEN** el informe la marca como no generada en lugar de producir código ficticio o incompleto silenciosamente

### Requirement: Derivación desde UML
El generador SHALL derivar estructura de diagramas de clases y SHALL usar casos de uso, secuencias, estados y restricciones disponibles para sugerir endpoints, operaciones y validaciones, conservando trazabilidad entre elementos UML y archivos generados.

#### Scenario: Clase y asociación
- **WHEN** dos clases persistentes tienen una asociación con multiplicidades soportadas
- **THEN** el proyecto generado contiene entidades y mapeo JPA correspondiente, DTOs sin ciclos y una referencia de trazabilidad

#### Scenario: Información insuficiente
- **WHEN** falta identificador, tipo de atributo, multiplicidad necesaria o decisión que impide generar código válido
- **THEN** el sistema experto solicita aclaración y no marca el artefacto como listo

### Requirement: Generación híbrida y determinista
La IA SHALL proponer nombres, intención y mapeos, mientras versiones fijas de reglas y plantillas MUST construir el árbol final. Con las mismas entradas, perfil y versiones, el resultado SHALL ser reproducible salvo metadatos explícitos.

#### Scenario: Repetir generación
- **WHEN** el usuario genera dos veces desde la misma revisión y configuración
- **THEN** ambos árboles de código son equivalentes después de excluir marcas de tiempo declaradas

#### Scenario: Salida de IA no válida
- **WHEN** la IA propone una clase, dependencia o fragmento fuera del esquema permitido
- **THEN** el sistema la rechaza y no inserta texto arbitrario en el proyecto

### Requirement: Artefacto versionado y seguro
Cada generación SHALL crear un artefacto nuevo asociado a revisión, usuario, motor IA, reglas y plantillas, y SHALL empaquetarlo como ZIP con rutas relativas seguras sin sobrescribir generaciones anteriores.

#### Scenario: Descargar ZIP
- **WHEN** finaliza una generación válida
- **THEN** el usuario puede guardar o compartir un ZIP que no contiene secretos, rutas absolutas ni entradas que escapen del directorio del proyecto

### Requirement: Verificación en línea
Con conexión, el servidor SHALL compilar el proyecto en un entorno aislado, ejecutar sus pruebas y devolver logs acotados; solo SHALL marcarlo verificado si ambos pasos terminan correctamente.

#### Scenario: Build correcto
- **WHEN** Maven compila y todas las pruebas generadas pasan
- **THEN** el artefacto se marca verificado con versiones de Java, Spring Boot y herramientas utilizadas

#### Scenario: Build fallido
- **WHEN** la compilación o una prueba falla
- **THEN** el artefacto queda no verificado, conserva logs diagnósticos y permite pedir a la IA una propuesta de reparación sin reemplazarlo

### Requirement: Generación offline
Sin conexión y con IA local disponible, la aplicación SHALL poder generar el mismo perfil mediante reglas y plantillas locales y SHALL ejecutar validación estructural, pero MUST etiquetar el resultado como pendiente de compilación hasta verificarlo en servidor o entorno Java compatible.

#### Scenario: Generar offline
- **WHEN** el usuario genera desde una revisión local válida
- **THEN** obtiene un ZIP reproducible con reporte estático y estado «pendiente de verificación»

#### Scenario: Verificar después de reconectar
- **WHEN** el usuario sincroniza la revisión y envía un artefacto offline pendiente
- **THEN** el servidor reproduce o inspecciona la generación, compila, prueba y actualiza su estado sin alterar el ZIP original

### Requirement: Funciones opcionales solo si están modeladas
Autenticación, reglas de negocio complejas y endpoints no CRUD SHALL generarse únicamente cuando el modelo las describa y exista una plantilla declarada; despliegue cloud y frontend SHALL permanecer fuera del perfil inicial.

#### Scenario: Autenticación no modelada
- **WHEN** el modelo no contiene requisitos o perfil de autenticación soportado
- **THEN** el backend generado no inventa usuarios, JWT ni políticas de acceso y lo declara en el reporte

