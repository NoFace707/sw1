# Fixtures Sparx Enterprise Architect 17.2

Este directorio queda reservado para fixtures XMI 2.1 exportados desde Enterprise Architect 17.2. No se deben inventar archivos ni copiar modelos con datos personales: cada fixture debe ser un proyecto sintético creado para esta validación.

## Convención

| Familia | Archivo esperado | Diagramas mínimos | Estado | Evidencia |
| --- | --- | --- | --- | --- |
| Estructura | `structure-ea-17.2.xmi` | class, object, component, composite_structure, package, deployment, profile | Pendiente de EA | URL/hash del archivo |
| Comportamiento | `behavior-ea-17.2.xmi` | use_case, activity, state_machine | Pendiente de EA | URL/hash del archivo |
| Interacción | `interaction-ea-17.2.xmi` | sequence, communication, interaction_overview, timing | Pendiente de EA | URL/hash del archivo |
| Mixto | `mixed-ea-17.2.xmi` | una selección de las cuatro familias | Pendiente de EA | URL/hash del archivo |

## Metadatos obligatorios por fixture

- Enterprise Architect `17.2` y build exacto.
- Fecha de exportación, perfil UML/XMI elegido y opciones de diagramas/UMLDI.
- Nombre del proyecto sintético y ausencia de datos sensibles.
- Hash SHA-256 del archivo.
- Resultado de apertura en EA 17.2 y observaciones de pérdidas visuales.

## Procedimiento

1. Crear el modelo sintético usando los fixtures estructurales del registro del proyecto.
2. En EA usar `Publish → Import/Export → Export Package to XMI`, seleccionando XMI 2.1.
3. Guardar el XMI y completar los metadatos anteriores.
4. Reabrir el archivo en EA antes de incorporarlo al repositorio.
5. Ejecutar el comparador semántico del proyecto después del ciclo EA → web.

Hasta que los archivos y la evidencia estén disponibles, las tareas OpenSpec 8.1, 8.4 y 8.5 deben permanecer pendientes.
