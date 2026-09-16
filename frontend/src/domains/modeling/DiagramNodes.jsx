import { Handle, NodeResizer, Position } from "@xyflow/react";
import { useEffect, useRef } from "react";
import ShapeRenderer from "./ShapeRenderer.jsx";
import { shapeDefinition } from "./visualRegistry.js";
import { umlElementDefinition } from "./umlRegistry.js";

const HANDLE_POSITIONS = [["top", Position.Top], ["right", Position.Right], ["bottom", Position.Bottom], ["left", Position.Left]];

function ConnectionHandles({ data, enabled }) {
  return HANDLE_POSITIONS.map(([id, position]) => <Handle key={id} id={id} type={["right", "bottom"].includes(id) ? "source" : "target"} position={position} isConnectable={enabled} isConnectableStart={enabled} isConnectableEnd={enabled} className={`modeler-handle ${enabled ? "modeler-handle-enabled" : ""}`} aria-label={`Conectar desde ${id}`} onPointerDown={() => data.onConnectionStart?.(data.nodeId, id)} onPointerUp={() => data.onConnectionEnd?.(data.nodeId, id)} onClick={() => data.onConnectionClick?.(data.nodeId, id)} />);
}

function InlineLabel({ data, className = "" }) {
  const inputRef = useRef(null);
  useEffect(() => { if (data.editing) inputRef.current?.select(); }, [data.editing]);
  if (!data.editing) return <span className={className}>{data.label}</span>;
  return <input ref={inputRef} className="nodrag nowheel max-w-full rounded border border-blue-500 bg-white px-1 py-0.5 text-center text-sm font-semibold outline-none" value={data.draft} onChange={(event) => data.onDraftChange(event.target.value)} onBlur={data.onCommit} onKeyDown={(event) => { event.stopPropagation(); if (event.key === "Enter") data.onCommit(); if (event.key === "Escape") data.onCancel(); }} aria-label="Nombre de la figura" />;
}

function UmlArtwork({ data, compact = false }) {
  const type = data.metaclass;
  const properties = data.properties || {};
  const definition = umlElementDefinition(type, properties);
  const stroke = "#334155";
  const fill = "#ffffff";
  const label = compact ? <span className="text-[8px] font-semibold">{definition.label.slice(0, 4)}</span> : <InlineLabel data={data} className="font-semibold" />;
  if (type === "UseCase") return <ShapeRenderer shape="ellipse" style={{ fill, stroke, strokeWidth: 2, fontSize: 14 }} compact={compact}>{label}</ShapeRenderer>;
  if (["Action", "CallBehaviorAction", "CallOperationAction"].includes(type)) return <div className="relative h-full w-full"><ShapeRenderer shape="rounded-rectangle" style={{ fill, stroke, strokeWidth: 2, fontSize: 14 }} compact={compact}>{label}</ShapeRenderer>{type !== "Action" && <span className="absolute bottom-1 right-2 text-[10px] font-bold" aria-hidden="true">{type === "CallBehaviorAction" ? "↻" : "⚙"}</span>}</div>;
  if (type === "SendSignalAction") return <ShapeRenderer shape="pentagon-right" style={{ fill, stroke, strokeWidth: 2, fontSize: 13 }} compact={compact}>{label}</ShapeRenderer>;
  if (type === "AcceptEventAction") return <div className="relative h-full w-full"><svg className="absolute inset-0 h-full w-full" viewBox="0 0 180 90" preserveAspectRatio="none" aria-hidden="true"><path d="M3 3 H135 L177 45 L135 87 H3 L36 45 Z" fill={fill} stroke={stroke} strokeWidth="2" vectorEffect="non-scaling-stroke"/></svg><div className="absolute inset-3 grid place-items-center text-center">{label}</div></div>;
  if (type === "Actor") return <div className="grid h-full w-full place-items-center"><svg className="h-[70%] w-[45%]" viewBox="0 0 70 110" aria-hidden="true"><circle cx="35" cy="15" r="12" fill="white" stroke={stroke} strokeWidth="3"/><path d="M35 27 V65 M10 42 H60 M35 65 L13 101 M35 65 L57 101" fill="none" stroke={stroke} strokeWidth="3" strokeLinecap="round"/></svg>{!compact && <div className="absolute bottom-1 left-1 right-1 text-center text-xs font-semibold"><InlineLabel data={data}/></div>}</div>;
  if (["DecisionNode", "MergeNode"].includes(type) || (type === "Pseudostate" && properties.kind === "choice")) return <ShapeRenderer shape="diamond" style={{ fill, stroke, strokeWidth: 2, fontSize: 10 }} compact={compact}>{compact ? null : label}</ShapeRenderer>;
  if (type === "InitialNode" || (type === "Pseudostate" && [undefined, "initial"].includes(properties.kind))) return <div className="grid h-full w-full place-items-center"><span className="block h-8 w-8 rounded-full bg-slate-800" />{!compact && <span className="absolute top-[72%] text-[10px]"><InlineLabel data={data}/></span>}</div>;
  if (type === "Pseudostate" && properties.kind === "junction") return <div className="grid h-full w-full place-items-center"><span className="block h-5 w-5 rounded-full bg-slate-800" /></div>;
  if (["ForkNode", "JoinNode"].includes(type) || (type === "Pseudostate" && ["fork", "join"].includes(properties.kind))) return <div className="grid h-full w-full place-items-center"><span className="block h-2.5 w-[88%] rounded-sm bg-slate-800" />{!compact && <span className="absolute top-[70%] text-[9px]"><InlineLabel data={data}/></span>}</div>;
  if (type === "Pseudostate" && ["entryPoint", "exitPoint", "shallowHistory", "deepHistory"].includes(properties.kind)) {
    const symbol = properties.kind === "entryPoint" ? "→" : properties.kind === "exitPoint" ? "×" : properties.kind === "deepHistory" ? "H*" : "H";
    return <div className="grid h-full w-full place-items-center"><span className="grid h-9 w-9 place-items-center rounded-full border-2 border-slate-700 bg-white text-[11px] font-bold">{symbol}</span></div>;
  }
  if (type === "Pseudostate" && properties.kind === "terminate") return <div className="grid h-full w-full place-items-center text-4xl font-light text-slate-800">×</div>;
  if (["ActivityFinalNode", "FinalState"].includes(type)) return <div className="grid h-full w-full place-items-center"><span className="grid h-10 w-10 place-items-center rounded-full border-[3px] border-slate-700"><span className="h-6 w-6 rounded-full bg-slate-700" /></span>{!compact && <span className="absolute top-[76%] text-[10px]"><InlineLabel data={data}/></span>}</div>;
  if (type === "FlowFinalNode") return <div className="grid h-full w-full place-items-center"><span className="grid h-10 w-10 place-items-center rounded-full border-2 border-slate-700 text-2xl font-light">×</span></div>;
  if (["Package", "Profile", "Model"].includes(type)) return <div className="relative h-full w-full"><svg className="absolute inset-0 h-full w-full" viewBox="0 0 180 100" preserveAspectRatio="none"><path d="M3 20 V3 H70 L82 20 H177 V97 H3 Z" fill={fill} stroke={stroke} strokeWidth="2" vectorEffect="non-scaling-stroke"/></svg><div className="absolute inset-x-3 bottom-2 top-6 grid place-items-center text-center"><div>{type !== "Package" && <span className="block text-[9px]">«{type.toLowerCase()}»</span>}{label}</div></div></div>;
  if (["Comment", "Constraint"].includes(type)) return <ShapeRenderer shape="note" style={{ fill: type === "Constraint" ? "#fffbea" : fill, stroke, strokeWidth: 2, fontSize: 12 }} compact={compact}><div>{type === "Constraint" && <span className="block text-[9px]">{"{constraint}"}</span>}{label}</div></ShapeRenderer>;
  if (type === "Component") return <div className="relative h-full w-full rounded-sm border-2 border-slate-600 bg-white"><div className="absolute -left-2 top-4 grid gap-1"><span className="h-3 w-5 border-2 border-slate-600 bg-white"/><span className="h-3 w-5 border-2 border-slate-600 bg-white"/></div><div className="grid h-full place-items-center text-center">{label}<span className="block text-[9px] font-normal">«component»</span></div></div>;
  if (type === "Interface" && properties.presentation === "lollipop") return <div className="grid h-full w-full place-items-center"><span className="block h-9 w-9 rounded-full border-2 border-slate-700 bg-white"/><span className="h-5 border-l-2 border-slate-700"/>{!compact && <span className="text-[10px] font-semibold"><InlineLabel data={data}/></span>}</div>;
  if (type === "Port") return <div className="grid h-full w-full place-items-center"><span className="grid h-9 w-9 place-items-center border-2 border-slate-700 bg-white text-[8px]">port</span>{!compact && <span className="absolute top-[76%] text-[9px]"><InlineLabel data={data}/></span>}</div>;
  if (type === "Connector") return <div className="grid h-full w-full place-items-center"><span className="grid h-8 w-8 place-items-center rounded-full border-2 border-slate-700 bg-white text-lg">↔</span></div>;
  if (["Collaboration", "CollaborationUse"].includes(type)) return <ShapeRenderer shape="ellipse" style={{ fill, stroke, strokeWidth: 2, fontSize: 12, dashed: true }} compact={compact}><div>{type === "CollaborationUse" && <span className="block text-[8px]">«use»</span>}{label}</div></ShapeRenderer>;
  if (["Node", "Device", "ExecutionEnvironment"].includes(type)) return <div className="relative h-full w-full"><div className="absolute inset-x-2 bottom-1 top-3 border-2 border-slate-600 bg-white"/><div className="absolute left-5 right-0 top-0 h-3 skew-x-[-35deg] border-2 border-b-0 border-slate-600 bg-slate-50"/><div className="absolute inset-3 grid place-items-center text-center">{label}<span className="block text-[9px]">«{type === "ExecutionEnvironment" ? "executionEnvironment" : type.toLowerCase()}»</span></div></div>;
  if (["Artifact", "DeploymentSpecification"].includes(type)) return <ShapeRenderer shape="note" style={{ fill, stroke, strokeWidth: 2, fontSize: 13 }} compact={compact}><div>{!compact && <span className="block text-[9px]">«{type === "Artifact" ? "artifact" : "deployment spec"}»</span>}{label}</div></ShapeRenderer>;
  if (["ObjectNode", "ActivityParameterNode", "CentralBufferNode", "DataStoreNode"].includes(type)) return <div className={`grid h-full w-full place-items-center border-2 border-slate-700 bg-white text-center ${type === "DataStoreNode" ? "border-x-4" : ""}`}><div>{type === "CentralBufferNode" && <span className="block text-[8px]">«centralBuffer»</span>}{type === "DataStoreNode" && <span className="block text-[8px]">«datastore»</span>}{label}</div></div>;
  if (["ActivityPartition", "InterruptibleActivityRegion", "StateMachine"].includes(type)) return <div className={`relative h-full w-full border-2 bg-white ${type === "InterruptibleActivityRegion" ? "border-dashed border-slate-600" : "border-slate-700"}`}><div className="absolute left-0 top-0 border-b border-r border-slate-600 bg-slate-50 px-2 py-1 text-[9px]">{type === "ActivityPartition" ? "partition" : type === "StateMachine" ? "state machine" : "interruptible"}</div><div className="grid h-full place-items-center p-6 text-center">{label}</div></div>;
  if (type === "Lifeline") {
    const stereotype = properties.stereotype;
    const symbol = stereotype === "boundary" ? "◯│" : stereotype === "control" ? "◯⌄" : stereotype === "entity" ? "◯―" : stereotype === "database" ? "▱" : null;
    return <div className="relative h-full w-full"><div className="mx-auto grid h-12 w-[88%] place-items-center border-2 border-slate-600 bg-white text-center">{symbol && <span className="text-sm leading-none">{symbol}</span>}{stereotype && <span className="text-[8px]">«{stereotype}»</span>}{label}</div><div className="mx-auto w-px border-l-2 border-dashed border-slate-500" style={{ height: "calc(100% - 3rem)" }}/></div>;
  }
  if (type === "ExecutionSpecification") return <div className="grid h-full w-full place-items-center"><div className="h-[92%] w-5 border-2 border-slate-600 bg-white"/></div>;
  if (["Interaction", "CombinedFragment", "InteractionUse", "Region"].includes(type)) return <div className={`relative h-full w-full border-2 bg-white ${type === "Region" ? "border-dashed border-slate-500" : "border-slate-600"}`}><span className="absolute left-0 top-0 border-b border-r border-slate-600 bg-slate-50 px-2 py-0.5 text-[9px]">{type === "CombinedFragment" ? properties.operator || "alt" : type === "InteractionUse" ? "ref" : type}</span><div className="grid h-full place-items-center p-5 text-center">{label}</div></div>;
  if (type === "StateInvariant") return <ShapeRenderer shape="hexagon" style={{ fill, stroke, strokeWidth: 2, fontSize: 12 }} compact={compact}>{label}</ShapeRenderer>;
  if (type === "Continuation") return <ShapeRenderer shape="rounded-rectangle" style={{ fill, stroke, strokeWidth: 2, fontSize: 12 }} compact={compact}>{label}</ShapeRenderer>;
  if (type === "DestructionOccurrenceSpecification") return <div className="grid h-full w-full place-items-center text-4xl font-light text-slate-800">×</div>;
  if (type === "Gate") return <div className="grid h-full w-full place-items-center"><span className="grid h-8 w-8 place-items-center rounded-full border-2 border-slate-700 bg-white text-[9px]">gate</span></div>;
  if (["TimeObservation", "DurationObservation", "TimeConstraint", "DurationConstraint"].includes(type)) return <div className="relative grid h-full w-full place-items-center border-y-2 border-slate-600 bg-white px-5 text-center"><span className="absolute left-1 top-1 text-sm" aria-hidden="true">{type.includes("Duration") ? "↔" : "◷"}</span>{type.includes("Constraint") && <span className="absolute right-1 top-1 text-[9px]">{"{t}"}</span>}{label}</div>;
  const attributes = Array.isArray(data.properties?.attributes) ? data.properties.attributes
    : Array.isArray(data.properties?.slots) ? data.properties.slots
      : Array.isArray(data.properties?.tags) ? data.properties.tags : [];
  const operations = Array.isArray(data.properties?.operations) ? data.properties.operations : [];
  const stereotype = { Interface: "interface", Enumeration: "enumeration", DataType: "dataType", PrimitiveType: "primitive", Signal: "signal", Stereotype: "stereotype", Extension: "extension" }[type];
  return <div className={`grid h-full w-full overflow-hidden border-2 border-slate-600 bg-white text-slate-800 ${["State", "Activity"].includes(type) ? "rounded-xl" : "rounded-sm"} ${properties.is_active ? "border-x-[6px]" : ""}`}><div className={`grid min-h-10 place-items-center px-2 py-1 text-center ${["Object", "InstanceSpecification"].includes(type) ? "underline" : ""} ${properties.is_abstract ? "italic" : ""}`}>{stereotype && <span className="block text-[9px] font-normal no-underline">«{stereotype}»</span>}{label}{!compact && <span className="block text-[9px] font-normal text-slate-500 no-underline">{type}</span>}</div>{!compact && (attributes.length > 0 || operations.length > 0) && <><div className="border-t border-slate-400 px-2 py-1 text-[10px]">{attributes.map((item, index) => <div key={`${index}-${item}`}>{item}</div>)}</div>{operations.length > 0 && <div className="border-t border-slate-400 px-2 py-1 text-[10px]">{operations.map((item, index) => <div key={`${index}-${item}`}>{item}</div>)}</div>}</>}</div>;
}

export function UmlPreview({ metaclass, properties = {} }) { return <div className="h-10 w-14"><UmlArtwork data={{ metaclass, label: umlElementDefinition(metaclass, properties).label, properties }} compact /></div>; }

export function UmlNode({ data, selected }) {
  const definition = umlElementDefinition(data.metaclass, data.properties);
  const keepAspectRatio = Boolean(definition.keepAspectRatio);
  return <div className="diagram-node relative h-full w-full"><NodeResizer isVisible={selected} minWidth={keepAspectRatio ? 56 : 90} minHeight={keepAspectRatio ? 56 : 50} keepAspectRatio={keepAspectRatio} color="#2563eb"/><ConnectionHandles data={data} enabled={data.connectable}/><UmlArtwork data={data}/></div>;
}

export function VisualNode({ data, selected }) {
  const definition = shapeDefinition(data.visualProperties?.library, data.visualProperties?.shape);
  return <div className="diagram-node relative h-full w-full"><NodeResizer isVisible={selected} minWidth={60} minHeight={40} keepAspectRatio={Boolean(definition.keepAspectRatio)} color="#2563eb"/><ConnectionHandles data={data} enabled={data.connectable}/><ShapeRenderer shape={data.visualProperties?.shape} style={data.visualProperties?.style}><InlineLabel data={data}/>{data.visualProperties?.library === "er" && <span className="mt-1 block text-[8px] uppercase text-slate-400">ER</span>}</ShapeRenderer></div>;
}

export const nodeTypes = { uml: UmlNode, visual: VisualNode };
