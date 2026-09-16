import { umlMetaclassesFor, umlPaletteFor } from "./umlRegistry.js";

export const UML_DIAGRAM_TYPES = [
  ["class", "Clases"],
  ["object", "Objetos"],
  ["component", "Componentes"],
  ["composite_structure", "Estructura compuesta"],
  ["package", "Paquetes"],
  ["deployment", "Despliegue"],
  ["profile", "Perfiles"],
  ["use_case", "Casos de uso"],
  ["activity", "Actividades"],
  ["state_machine", "Máquinas de estados"],
  ["sequence", "Secuencia"],
  ["communication", "Comunicación"],
  ["interaction_overview", "Visión general de interacción"],
  ["timing", "Temporización"],
];

export const MDA_LEVELS = [
  ["UNSPECIFIED", "No especificado"],
  ["CIM", "CIM"],
  ["PIM", "PIM"],
  ["PSM", "PSM"],
];

function profile(diagramType, relationships, properties) {
  return { elements: umlMetaclassesFor(diagramType), palette: umlPaletteFor(diagramType), relationships, properties };
}

export const DIAGRAM_PROFILES = {
  class: {
    ...profile("class", ["Association", "Aggregation", "Composition", "Generalization", "Dependency", "Realization"], {
      Class: ["stereotype", "attributes", "operations", "is_abstract", "is_active", "presentation"], Actor: ["stereotype", "documentation"], Interface: ["operations", "stereotype"], Enumeration: ["literals"], DataType: ["attributes", "operations"], PrimitiveType: ["documentation"], Signal: ["attributes"], Package: ["stereotype", "documentation"], Comment: ["body"], Constraint: ["specification"],
    }),
  },
  object: {
    ...profile("object", ["Association", "Dependency"], { Object: ["classifier", "slots"], InstanceSpecification: ["classifier", "slots"], Class: ["attributes", "operations"], Package: ["stereotype", "documentation"], Comment: ["body"], Constraint: ["specification"] }),
  },
  package: {
    ...profile("package", ["Dependency", "Trace"], { Package: ["stereotype", "documentation"], Model: ["viewpoint", "documentation"], Profile: ["version", "documentation"], Comment: ["body"] }),
  },
  use_case: {
    ...profile("use_case", ["Association", "Include", "Extend", "Generalization"], { Actor: ["stereotype", "documentation"], UseCase: ["stereotype", "extension_points", "documentation"], Package: ["stereotype", "documentation"], Comment: ["body"], Constraint: ["specification"] }),
  },
  component: {
    ...profile("component", ["Dependency", "Realization", "Association"], { Component: ["stereotype", "provided", "required"], Interface: ["operations", "stereotype", "presentation"], Port: ["type", "provided", "required"], Artifact: ["file_name", "version"], Package: ["stereotype", "documentation"], Comment: ["body"] }),
  },
  deployment: {
    ...profile("deployment", ["Dependency", "Association"], { Node: ["environment", "deployed_components"], Device: ["operating_system"], ExecutionEnvironment: ["runtime"], DeploymentSpecification: ["deployment_location"], Component: ["stereotype", "provided", "required"], Artifact: ["file_name", "version"], Comment: ["body"] }),
  },
  composite_structure: {
    ...profile("composite_structure", ["Association", "Dependency"], { Class: ["stereotype", "attributes", "operations"], Part: ["type", "multiplicity"], Port: ["type", "provided", "required"], Connector: ["source", "target"], Collaboration: ["roles"], CollaborationUse: ["type", "role_bindings"], Comment: ["body"] }),
  },
  profile: {
    ...profile("profile", ["Extension", "Generalization"], { Profile: ["version", "documentation"], Class: ["stereotype", "attributes", "operations"], Stereotype: ["base_class", "tags"], Enumeration: ["literals"], DataType: ["attributes", "operations"], Extension: ["metaclass", "is_required"], Comment: ["body"] }),
  },
  activity: {
    ...profile("activity", ["ControlFlow", "ObjectFlow"], { Activity: ["preconditions", "postconditions"], Action: ["inputs", "outputs", "local_preconditions"], CallBehaviorAction: ["behavior", "arguments"], CallOperationAction: ["operation", "target"], SendSignalAction: ["signal"], AcceptEventAction: ["triggers"], ObjectNode: ["type", "state"], ActivityParameterNode: ["type", "direction"], CentralBufferNode: ["type", "upper_bound"], DataStoreNode: ["type", "state"], ActivityPartition: ["represents", "dimension"], InterruptibleActivityRegion: ["interrupting_edges"], DecisionNode: ["decision_input"], MergeNode: [], InitialNode: [], ActivityFinalNode: [], FlowFinalNode: [], ForkNode: [], JoinNode: ["join_spec"], Comment: ["body"] }),
  },
  state_machine: {
    ...profile("state_machine", ["Transition"], { StateMachine: ["regions"], State: ["entry", "do", "exit"], FinalState: [], Pseudostate: ["kind"], Region: ["substates"], Comment: ["body"] }),
  },
  sequence: {
    ...profile("sequence", ["Message"], { Actor: ["stereotype"], Lifeline: ["represents", "order", "stereotype"], Interaction: ["arguments", "return_value"], ExecutionSpecification: ["start", "finish"], CombinedFragment: ["operator", "guard", "fragments"], InteractionUse: ["refers_to", "arguments"], StateInvariant: ["invariant"], Continuation: ["setting"], DestructionOccurrenceSpecification: ["message"], Gate: ["message"], Comment: ["body"] }),
  },
  communication: {
    ...profile("communication", ["Message", "Association"], { Lifeline: ["represents", "order", "stereotype"], Object: ["classifier", "slots"], Interaction: ["arguments", "return_value"], Comment: ["body"] }),
  },
  interaction_overview: {
    ...profile("interaction_overview", ["ControlFlow"], { Interaction: ["refers_to", "arguments"], InteractionUse: ["refers_to", "arguments"], Activity: ["preconditions", "postconditions"], DecisionNode: ["decision_input"], MergeNode: [], InitialNode: [], ActivityFinalNode: [], FlowFinalNode: [], ForkNode: [], JoinNode: ["join_spec"], Comment: ["body"] }),
  },
  timing: {
    ...profile("timing", ["Message", "Transition"], { Lifeline: ["represents", "order"], State: ["entry", "do", "exit"], StateInvariant: ["invariant"], TimeObservation: ["event", "time_expression"], DurationObservation: ["events", "duration"], TimeConstraint: ["specification"], DurationConstraint: ["specification"], Interaction: ["arguments", "return_value"], Comment: ["body"] }),
  },
};

export const STRUCTURAL_FIXTURES = {
  class: { diagram_type: "class", elements: [{ metaclass: "Class", name: "Customer", properties: { attributes: ["id: UUID"], operations: ["register()"] } }, { metaclass: "Class", name: "Order", properties: { attributes: ["total: Decimal"] } }] },
  object: { diagram_type: "object", elements: [{ metaclass: "Object", name: "customer01", properties: { classifier: "Customer", slots: ["id = 1"] } }] },
  package: { diagram_type: "package", elements: [{ metaclass: "Package", name: "Sales", properties: { documentation: "Sales bounded context" } }] },
  use_case: { diagram_type: "use_case", elements: [{ metaclass: "Actor", name: "Customer" }, { metaclass: "UseCase", name: "Place order", properties: { extension_points: ["payment"] } }] },
  component: { diagram_type: "component", elements: [{ metaclass: "Component", name: "Order Service", properties: { provided: ["OrderApi"], required: ["UserApi"] } }, { metaclass: "Interface", name: "OrderApi", properties: { operations: ["createOrder()"] } }] },
  deployment: { diagram_type: "deployment", elements: [{ metaclass: "Node", name: "Application Server", properties: { environment: "production" } }, { metaclass: "Artifact", name: "orders.jar", properties: { file_name: "orders.jar", version: "1.0" } }] },
  composite_structure: { diagram_type: "composite_structure", elements: [{ metaclass: "Class", name: "Checkout", properties: { parts: ["payment: PaymentPort"] } }, { metaclass: "Port", name: "payment", properties: { type: "PaymentPort", required: ["authorize()"] } }] },
  profile: { diagram_type: "profile", elements: [{ metaclass: "Profile", name: "PersistenceProfile", properties: { version: "1.0" } }, { metaclass: "Stereotype", name: "Entity", properties: { base_class: "Class" } }] },
  activity: { diagram_type: "activity", elements: [{ metaclass: "Activity", name: "Checkout", properties: { preconditions: ["cart not empty"] } }, { metaclass: "Action", name: "Authorize payment", properties: { inputs: ["PaymentRequest"], outputs: ["Receipt"] } }, { metaclass: "DecisionNode", name: "Approved?", properties: { decision_input: "payment status" } }, { metaclass: "InitialNode", name: "Start" }, { metaclass: "ActivityFinalNode", name: "End" }] },
  state_machine: { diagram_type: "state_machine", elements: [{ metaclass: "State", name: "Pending", properties: { entry: "notify()", do: "wait()", exit: "clearTimer()" } }, { metaclass: "State", name: "Paid" }, { metaclass: "FinalState", name: "Completed" }, { metaclass: "Pseudostate", name: "Start", properties: { kind: "initial" } }, { metaclass: "Region", name: "Order lifecycle", properties: { substates: ["Pending", "Paid"] } }] },
  sequence: { diagram_type: "sequence", elements: [{ metaclass: "Lifeline", name: "Customer", properties: { represents: "customer01", order: 1 } }, { metaclass: "Lifeline", name: "OrderService", properties: { represents: "Order Service", order: 2 } }, { metaclass: "Interaction", name: "Place order", properties: { arguments: ["cart"] } }, { metaclass: "CombinedFragment", name: "alt payment", properties: { operator: "alt", guard: "authorized", fragments: ["confirm"] } }] },
  communication: { diagram_type: "communication", elements: [{ metaclass: "Lifeline", name: "Customer", properties: { represents: "customer01", order: 1 } }, { metaclass: "Lifeline", name: "OrderService", properties: { represents: "Order Service", order: 2 } }, { metaclass: "Interaction", name: "createOrder()", properties: { arguments: ["cart"] } }] },
  interaction_overview: { diagram_type: "interaction_overview", elements: [{ metaclass: "Interaction", name: "Checkout flow", properties: { refers_to: "Place order" } }, { metaclass: "Activity", name: "Validate cart", properties: { preconditions: ["cart loaded"] } }, { metaclass: "DecisionNode", name: "Payment?", properties: { decision_input: "payment status" } }] },
  timing: { diagram_type: "timing", elements: [{ metaclass: "Lifeline", name: "Order", properties: { represents: "order01", order: 1 } }, { metaclass: "TimeObservation", name: "Payment accepted", properties: { event: "payment.accepted", time_expression: "t+120ms" } }, { metaclass: "State", name: "Paid", properties: { entry: "emit()" } }] },
};

export function diagramProfile(diagramType) {
  return DIAGRAM_PROFILES[diagramType] || { elements: [], palette: [], relationships: [], properties: {} };
}
