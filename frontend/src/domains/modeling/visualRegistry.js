const DEFAULT_NODE_STYLE = { fill: "#ffffff", stroke: "#475569", strokeWidth: 2, fontSize: 14, textColor: "#0f172a" };

export const GENERAL_SHAPES = [
  { shape: "text", label: "Texto", width: 160, height: 48 },
  { shape: "rectangle", label: "Rectángulo", width: 180, height: 90 },
  { shape: "rounded-rectangle", label: "Redondeado", width: 180, height: 90 },
  { shape: "ellipse", label: "Elipse", width: 180, height: 110 },
  { shape: "circle", label: "Círculo", width: 110, height: 110, keepAspectRatio: true },
  { shape: "diamond", label: "Rombo", width: 150, height: 110 },
  { shape: "triangle", label: "Triángulo", width: 140, height: 120 },
  { shape: "parallelogram", label: "Paralelogramo", width: 180, height: 90 },
  { shape: "hexagon", label: "Hexágono", width: 180, height: 90 },
  { shape: "cylinder", label: "Cilindro", width: 160, height: 120 },
  { shape: "document", label: "Documento", width: 170, height: 110 },
  { shape: "note", label: "Nota", width: 160, height: 110 },
  { shape: "cloud", label: "Nube", width: 180, height: 110 },
  { shape: "callout", label: "Llamada", width: 180, height: 105 },
];

export const FLOWCHART_SHAPES = [
  { shape: "process", label: "Proceso", width: 180, height: 90 },
  { shape: "terminator", label: "Inicio / fin", width: 180, height: 80 },
  { shape: "decision", label: "Decisión", width: 150, height: 110 },
  { shape: "data", label: "Entrada / salida", width: 180, height: 90 },
  { shape: "database", label: "Base de datos", width: 160, height: 120 },
  { shape: "flow-document", label: "Documento", width: 170, height: 110 },
  { shape: "manual-input", label: "Entrada manual", width: 180, height: 90 },
  { shape: "preparation", label: "Preparación", width: 180, height: 90 },
  { shape: "delay", label: "Demora", width: 170, height: 90 },
  { shape: "connector", label: "Conector", width: 80, height: 80, keepAspectRatio: true },
  { shape: "off-page-connector", label: "Fuera de página", width: 110, height: 120 },
  { shape: "subprocess", label: "Subproceso", width: 180, height: 90 },
];

export const ER_SHAPES = [
  { shape: "entity", label: "Entidad", width: 180, height: 90 },
  { shape: "weak-entity", label: "Entidad débil", width: 180, height: 90 },
  { shape: "attribute", label: "Atributo", width: 170, height: 90 },
  { shape: "key-attribute", label: "Atributo clave", width: 170, height: 90 },
  { shape: "multivalued-attribute", label: "Multivaluado", width: 170, height: 90 },
  { shape: "derived-attribute", label: "Derivado", width: 170, height: 90 },
  { shape: "relationship", label: "Relación", width: 150, height: 110 },
  { shape: "identifying-relationship", label: "Identificación", width: 150, height: 110 },
];

export const ARROW_SHAPES = [
  { shape: "line", label: "Línea", startMarker: "none", endMarker: "none", routing: "straight", lineStyle: "solid" },
  { shape: "arrow", label: "Flecha", startMarker: "none", endMarker: "arrow", routing: "straight", lineStyle: "solid" },
  { shape: "double-arrow", label: "Doble flecha", startMarker: "arrow", endMarker: "arrow", routing: "straight", lineStyle: "solid" },
  { shape: "dashed", label: "Discontinua", startMarker: "none", endMarker: "none", routing: "straight", lineStyle: "dashed" },
  { shape: "dashed-arrow", label: "Flecha discontinua", startMarker: "none", endMarker: "arrow", routing: "straight", lineStyle: "dashed" },
  { shape: "orthogonal", label: "Ortogonal", startMarker: "none", endMarker: "arrow", routing: "orthogonal", lineStyle: "solid" },
  { shape: "curved", label: "Curva", startMarker: "none", endMarker: "arrow", routing: "curved", lineStyle: "solid" },
];

export const ER_CONNECTORS = [
  { shape: "er-one", label: "Uno a uno", startMarker: "one", endMarker: "one", routing: "orthogonal", lineStyle: "solid" },
  { shape: "er-zero-one", label: "Cero o uno", startMarker: "zero-one", endMarker: "one", routing: "orthogonal", lineStyle: "solid" },
  { shape: "er-many", label: "Muchos", startMarker: "one", endMarker: "many", routing: "orthogonal", lineStyle: "solid" },
  { shape: "er-one-many", label: "Uno a muchos", startMarker: "one", endMarker: "one-many", routing: "orthogonal", lineStyle: "solid" },
  { shape: "er-zero-many", label: "Cero a muchos", startMarker: "one", endMarker: "zero-many", routing: "orthogonal", lineStyle: "solid" },
];

const SHAPE_GROUPS = { general: GENERAL_SHAPES, flowchart: FLOWCHART_SHAPES, er: ER_SHAPES };

export function shapeDefinition(library, shape) {
  return SHAPE_GROUPS[library]?.find((item) => item.shape === shape) || { shape, label: "Figura", width: 180, height: 90 };
}

export function visualNodeProperties(library, shape, label) {
  const definition = shapeDefinition(library, shape);
  return { kind: "visual", library, shape, label: label || definition.label, style: { ...DEFAULT_NODE_STYLE } };
}

export function connectorDefinition(shape) {
  return [...ARROW_SHAPES, ...ER_CONNECTORS].find((item) => item.shape === shape) || ARROW_SHAPES[1];
}

export function visualEdgeProperties(shape, handles = {}) {
  const definition = connectorDefinition(shape);
  return {
    kind: "visual", library: "arrows", shape, label: "",
    sourceHandle: handles.sourceHandle || "bottom", targetHandle: handles.targetHandle || "top",
    style: { stroke: "#475569", strokeWidth: 2, routing: definition.routing, lineStyle: definition.lineStyle, startMarker: definition.startMarker, endMarker: definition.endMarker },
  };
}

export function normalizeVisualEdgeProperties(properties = {}) {
  if (properties.kind !== "visual") return properties;
  const definition = connectorDefinition(properties.shape);
  const legacy = properties.style || {};
  return {
    ...properties,
    sourceHandle: properties.sourceHandle || "bottom",
    targetHandle: properties.targetHandle || "top",
    style: {
      stroke: legacy.stroke || "#475569", strokeWidth: Number(legacy.strokeWidth || 2),
      routing: legacy.routing || definition.routing,
      lineStyle: legacy.lineStyle || (legacy.dashed ? "dashed" : definition.lineStyle),
      startMarker: legacy.startMarker || (legacy.arrowStart ? "arrow" : definition.startMarker),
      endMarker: legacy.endMarker || (legacy.arrowEnd ? "arrow" : definition.endMarker),
    },
  };
}

export function relationshipPresentation(relationshipType, handles = {}) {
  const map = {
    Association: ["none", "none", "solid"], Aggregation: ["diamond", "none", "solid"], Composition: ["diamond-filled", "none", "solid"],
    Generalization: ["none", "triangle", "solid"], Dependency: ["none", "arrow-open", "dashed"], Realization: ["none", "triangle", "dashed"],
    Include: ["none", "arrow-open", "dashed"], Extend: ["none", "arrow-open", "dashed"], ControlFlow: ["none", "arrow", "solid"],
    ObjectFlow: ["none", "arrow-open", "solid"], Transition: ["none", "arrow", "solid"], Message: ["none", "arrow-open", "solid"],
    Trace: ["none", "arrow-open", "dashed"], Extension: ["none", "triangle", "solid"],
  };
  const [startMarker, endMarker, lineStyle] = map[relationshipType] || map.Association;
  const label = relationshipType === "Include" ? "«include»" : relationshipType === "Extend" ? "«extend»" : "";
  return { sourceHandle: handles.sourceHandle || "bottom", targetHandle: handles.targetHandle || "top", label, style: { stroke: "#334155", strokeWidth: 2, routing: relationshipType === "Message" ? "straight" : "orthogonal", lineStyle, startMarker, endMarker } };
}

export function isVisualItem(properties) { return properties?.kind === "visual"; }
