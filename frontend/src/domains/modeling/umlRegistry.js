const element = (key, metaclass, label, options = {}) => ({
  key,
  metaclass,
  label,
  width: 180,
  height: 90,
  properties: {},
  ...options,
});

export const UML_ELEMENT_DEFINITIONS = {
  Class: element("Class", "Class", "Clase", { height: 110 }),
  "Class.fields": element("Class.fields", "Class", "Clase con atributos", { height: 130, properties: { presentation: "classifier-with-attributes", attributes: ["+ atributo1: Tipo", "+ atributo2: Tipo", "+ atributo3: Tipo"] } }),
  "Class.abstract": element("Class.abstract", "Class", "Clase abstracta", { height: 110, properties: { is_abstract: true } }),
  "Class.active": element("Class.active", "Class", "Clase activa", { height: 110, properties: { is_active: true } }),
  Interface: element("Interface", "Interface", "Interfaz", { height: 100 }),
  "Interface.lollipop": element("Interface.lollipop", "Interface", "Interfaz provista", { width: 110, height: 80, properties: { presentation: "lollipop" } }),
  Enumeration: element("Enumeration", "Enumeration", "Enumeración", { height: 110 }),
  DataType: element("DataType", "DataType", "Tipo de dato"),
  PrimitiveType: element("PrimitiveType", "PrimitiveType", "Tipo primitivo"),
  Signal: element("Signal", "Signal", "Señal"),
  Package: element("Package", "Package", "Paquete", { width: 190, height: 110 }),
  Model: element("Model", "Model", "Modelo", { width: 190, height: 110 }),
  Profile: element("Profile", "Profile", "Perfil", { width: 190, height: 110 }),
  Comment: element("Comment", "Comment", "Comentario", { width: 170, height: 100 }),
  Constraint: element("Constraint", "Constraint", "Restricción", { width: 170, height: 90 }),
  Object: element("Object", "Object", "Objeto", { height: 100 }),
  InstanceSpecification: element("InstanceSpecification", "InstanceSpecification", "Instancia", { height: 100 }),
  Component: element("Component", "Component", "Componente", { width: 180, height: 100 }),
  Artifact: element("Artifact", "Artifact", "Artefacto", { width: 160, height: 100 }),
  Port: element("Port", "Port", "Puerto", { width: 64, height: 64, keepAspectRatio: true }),
  Part: element("Part", "Part", "Parte", { width: 160, height: 80 }),
  Connector: element("Connector", "Connector", "Conector", { width: 64, height: 64, keepAspectRatio: true }),
  Collaboration: element("Collaboration", "Collaboration", "Colaboración", { width: 180, height: 90 }),
  CollaborationUse: element("CollaborationUse", "CollaborationUse", "Uso de colaboración", { width: 180, height: 90 }),
  Node: element("Node", "Node", "Nodo", { width: 180, height: 110 }),
  Device: element("Device", "Device", "Dispositivo", { width: 180, height: 110 }),
  ExecutionEnvironment: element("ExecutionEnvironment", "ExecutionEnvironment", "Entorno de ejecución", { width: 190, height: 110 }),
  DeploymentSpecification: element("DeploymentSpecification", "DeploymentSpecification", "Especificación de despliegue", { width: 190, height: 110 }),
  Stereotype: element("Stereotype", "Stereotype", "Estereotipo", { height: 110 }),
  Extension: element("Extension", "Extension", "Extensión", { height: 90 }),
  Actor: element("Actor", "Actor", "Actor", { width: 100, height: 150 }),
  UseCase: element("UseCase", "UseCase", "Caso de uso", { width: 180, height: 100 }),
  Activity: element("Activity", "Activity", "Actividad", { width: 190, height: 100 }),
  Action: element("Action", "Action", "Acción", { width: 170, height: 80 }),
  CallBehaviorAction: element("CallBehaviorAction", "CallBehaviorAction", "Llamar comportamiento", { width: 180, height: 80 }),
  CallOperationAction: element("CallOperationAction", "CallOperationAction", "Llamar operación", { width: 180, height: 80 }),
  SendSignalAction: element("SendSignalAction", "SendSignalAction", "Enviar señal", { width: 170, height: 80 }),
  AcceptEventAction: element("AcceptEventAction", "AcceptEventAction", "Aceptar evento", { width: 170, height: 80 }),
  ObjectNode: element("ObjectNode", "ObjectNode", "Nodo de objeto", { width: 150, height: 70 }),
  ActivityParameterNode: element("ActivityParameterNode", "ActivityParameterNode", "Parámetro de actividad", { width: 140, height: 60 }),
  CentralBufferNode: element("CentralBufferNode", "CentralBufferNode", "Búfer central", { width: 160, height: 70 }),
  DataStoreNode: element("DataStoreNode", "DataStoreNode", "Almacén de datos", { width: 160, height: 76 }),
  ActivityPartition: element("ActivityPartition", "ActivityPartition", "Partición", { width: 220, height: 180 }),
  InterruptibleActivityRegion: element("InterruptibleActivityRegion", "InterruptibleActivityRegion", "Región interrumpible", { width: 220, height: 160 }),
  DecisionNode: element("DecisionNode", "DecisionNode", "Decisión", { width: 90, height: 90, keepAspectRatio: true }),
  MergeNode: element("MergeNode", "MergeNode", "Fusión", { width: 90, height: 90, keepAspectRatio: true }),
  InitialNode: element("InitialNode", "InitialNode", "Inicio", { width: 64, height: 64, keepAspectRatio: true }),
  ActivityFinalNode: element("ActivityFinalNode", "ActivityFinalNode", "Fin de actividad", { width: 70, height: 70, keepAspectRatio: true }),
  FlowFinalNode: element("FlowFinalNode", "FlowFinalNode", "Fin de flujo", { width: 70, height: 70, keepAspectRatio: true }),
  ForkNode: element("ForkNode", "ForkNode", "Bifurcación", { width: 150, height: 36 }),
  JoinNode: element("JoinNode", "JoinNode", "Unión", { width: 150, height: 36 }),
  StateMachine: element("StateMachine", "StateMachine", "Máquina de estados", { width: 220, height: 160 }),
  State: element("State", "State", "Estado", { width: 180, height: 110 }),
  FinalState: element("FinalState", "FinalState", "Estado final", { width: 70, height: 70, keepAspectRatio: true }),
  Region: element("Region", "Region", "Región", { width: 220, height: 150 }),
  "Pseudostate.initial": element("Pseudostate.initial", "Pseudostate", "Estado inicial", { width: 64, height: 64, keepAspectRatio: true, properties: { kind: "initial" } }),
  "Pseudostate.choice": element("Pseudostate.choice", "Pseudostate", "Elección", { width: 80, height: 80, keepAspectRatio: true, properties: { kind: "choice" } }),
  "Pseudostate.junction": element("Pseudostate.junction", "Pseudostate", "Unión lógica", { width: 60, height: 60, keepAspectRatio: true, properties: { kind: "junction" } }),
  "Pseudostate.fork": element("Pseudostate.fork", "Pseudostate", "Bifurcación de estado", { width: 150, height: 36, properties: { kind: "fork" } }),
  "Pseudostate.join": element("Pseudostate.join", "Pseudostate", "Unión de estado", { width: 150, height: 36, properties: { kind: "join" } }),
  "Pseudostate.entryPoint": element("Pseudostate.entryPoint", "Pseudostate", "Punto de entrada", { width: 64, height: 64, keepAspectRatio: true, properties: { kind: "entryPoint" } }),
  "Pseudostate.exitPoint": element("Pseudostate.exitPoint", "Pseudostate", "Punto de salida", { width: 64, height: 64, keepAspectRatio: true, properties: { kind: "exitPoint" } }),
  "Pseudostate.shallowHistory": element("Pseudostate.shallowHistory", "Pseudostate", "Historia superficial", { width: 64, height: 64, keepAspectRatio: true, properties: { kind: "shallowHistory" } }),
  "Pseudostate.deepHistory": element("Pseudostate.deepHistory", "Pseudostate", "Historia profunda", { width: 64, height: 64, keepAspectRatio: true, properties: { kind: "deepHistory" } }),
  "Pseudostate.terminate": element("Pseudostate.terminate", "Pseudostate", "Terminación", { width: 64, height: 64, keepAspectRatio: true, properties: { kind: "terminate" } }),
  Lifeline: element("Lifeline", "Lifeline", "Línea de vida", { width: 130, height: 260 }),
  "Lifeline.actor": element("Lifeline.actor", "Lifeline", "Actor (línea de vida)", { width: 130, height: 280, properties: { stereotype: "actor" } }),
  "Lifeline.boundary": element("Lifeline.boundary", "Lifeline", "Frontera", { width: 130, height: 260, properties: { stereotype: "boundary" } }),
  "Lifeline.control": element("Lifeline.control", "Lifeline", "Control", { width: 130, height: 260, properties: { stereotype: "control" } }),
  "Lifeline.entity": element("Lifeline.entity", "Lifeline", "Entidad", { width: 130, height: 260, properties: { stereotype: "entity" } }),
  "Lifeline.database": element("Lifeline.database", "Lifeline", "Base de datos", { width: 130, height: 260, properties: { stereotype: "database" } }),
  Interaction: element("Interaction", "Interaction", "Interacción", { width: 230, height: 160 }),
  ExecutionSpecification: element("ExecutionSpecification", "ExecutionSpecification", "Ejecución", { width: 60, height: 150 }),
  CombinedFragment: element("CombinedFragment", "CombinedFragment", "Fragmento combinado", { width: 240, height: 170, properties: { operator: "alt" } }),
  InteractionUse: element("InteractionUse", "InteractionUse", "Uso de interacción", { width: 210, height: 100 }),
  StateInvariant: element("StateInvariant", "StateInvariant", "Invariante de estado", { width: 170, height: 80 }),
  Continuation: element("Continuation", "Continuation", "Continuación", { width: 150, height: 60 }),
  DestructionOccurrenceSpecification: element("DestructionOccurrenceSpecification", "DestructionOccurrenceSpecification", "Destrucción", { width: 64, height: 64, keepAspectRatio: true }),
  Gate: element("Gate", "Gate", "Puerta", { width: 64, height: 64, keepAspectRatio: true }),
  TimeObservation: element("TimeObservation", "TimeObservation", "Observación de tiempo", { width: 170, height: 80 }),
  DurationObservation: element("DurationObservation", "DurationObservation", "Observación de duración", { width: 190, height: 80 }),
  TimeConstraint: element("TimeConstraint", "TimeConstraint", "Restricción temporal", { width: 180, height: 80 }),
  DurationConstraint: element("DurationConstraint", "DurationConstraint", "Restricción de duración", { width: 190, height: 80 }),
};

export const UML_PALETTE_KEYS = {
  class: ["Class", "Class.fields", "Class.abstract", "Class.active", "Actor", "Interface", "Enumeration", "DataType", "PrimitiveType", "Signal", "Package", "Comment", "Constraint"],
  object: ["Object", "InstanceSpecification", "Class", "Package", "Comment", "Constraint"],
  component: ["Component", "Interface.lollipop", "Interface", "Port", "Artifact", "Package", "Comment"],
  composite_structure: ["Class", "Part", "Port", "Connector", "Collaboration", "CollaborationUse", "Comment"],
  package: ["Package", "Model", "Profile", "Comment"],
  deployment: ["Node", "Device", "ExecutionEnvironment", "Artifact", "DeploymentSpecification", "Component", "Comment"],
  profile: ["Profile", "Stereotype", "Class", "Enumeration", "DataType", "Extension", "Comment"],
  use_case: ["Actor", "UseCase", "Package", "Comment", "Constraint"],
  activity: ["Activity", "Action", "CallBehaviorAction", "CallOperationAction", "SendSignalAction", "AcceptEventAction", "ObjectNode", "ActivityParameterNode", "CentralBufferNode", "DataStoreNode", "ActivityPartition", "InterruptibleActivityRegion", "DecisionNode", "MergeNode", "InitialNode", "ActivityFinalNode", "FlowFinalNode", "ForkNode", "JoinNode", "Comment"],
  state_machine: ["StateMachine", "State", "FinalState", "Region", "Pseudostate.initial", "Pseudostate.choice", "Pseudostate.junction", "Pseudostate.fork", "Pseudostate.join", "Pseudostate.entryPoint", "Pseudostate.exitPoint", "Pseudostate.shallowHistory", "Pseudostate.deepHistory", "Pseudostate.terminate", "Comment"],
  sequence: ["Lifeline", "Lifeline.actor", "Lifeline.boundary", "Lifeline.control", "Lifeline.entity", "Lifeline.database", "Interaction", "ExecutionSpecification", "CombinedFragment", "InteractionUse", "StateInvariant", "Continuation", "DestructionOccurrenceSpecification", "Gate", "Comment"],
  communication: ["Lifeline", "Lifeline.actor", "Lifeline.boundary", "Lifeline.control", "Lifeline.entity", "Object", "Interaction", "Comment"],
  interaction_overview: ["Interaction", "InteractionUse", "Activity", "DecisionNode", "MergeNode", "InitialNode", "ActivityFinalNode", "FlowFinalNode", "ForkNode", "JoinNode", "Comment"],
  timing: ["Lifeline", "State", "StateInvariant", "TimeObservation", "DurationObservation", "TimeConstraint", "DurationConstraint", "Interaction", "Comment"],
};

export function umlPaletteFor(diagramType) {
  return (UML_PALETTE_KEYS[diagramType] || []).map((key) => UML_ELEMENT_DEFINITIONS[key]).filter(Boolean);
}

export function umlMetaclassesFor(diagramType) {
  return [...new Set(umlPaletteFor(diagramType).map((item) => item.metaclass))];
}

export function umlElementDefinition(metaclass, properties = {}) {
  if (metaclass === "Pseudostate" && properties.kind) return UML_ELEMENT_DEFINITIONS[`Pseudostate.${properties.kind}`] || UML_ELEMENT_DEFINITIONS["Pseudostate.initial"];
  if (metaclass === "Lifeline" && properties.stereotype) return UML_ELEMENT_DEFINITIONS[`Lifeline.${properties.stereotype}`] || UML_ELEMENT_DEFINITIONS.Lifeline;
  if (metaclass === "Class" && properties.presentation === "classifier-with-attributes") return UML_ELEMENT_DEFINITIONS["Class.fields"];
  if (metaclass === "Class" && properties.is_abstract) return UML_ELEMENT_DEFINITIONS["Class.abstract"];
  if (metaclass === "Class" && properties.is_active) return UML_ELEMENT_DEFINITIONS["Class.active"];
  if (metaclass === "Interface" && properties.presentation === "lollipop") return UML_ELEMENT_DEFINITIONS["Interface.lollipop"];
  return UML_ELEMENT_DEFINITIONS[metaclass] || element(metaclass, metaclass, metaclass);
}
