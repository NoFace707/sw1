import { useMemo, useState } from "react";
import { ConnectorPreview } from "./ConnectorEdge.jsx";
import { UmlPreview } from "./DiagramNodes.jsx";
import ShapeRenderer from "./ShapeRenderer.jsx";
import { ARROW_SHAPES, ER_CONNECTORS, ER_SHAPES, FLOWCHART_SHAPES, GENERAL_SHAPES, relationshipPresentation } from "./visualRegistry.js";

function ShapeButton({ item, active, onClick, dragData, preview }) {
  return <button type="button" draggable={Boolean(dragData)} onDragStart={dragData ? (event) => { event.dataTransfer.effectAllowed = "copy"; event.dataTransfer.setData("application/x-modeler-shape", JSON.stringify(dragData)); } : undefined} onClick={onClick} className={`group grid min-h-[76px] place-items-center gap-1 rounded-md border p-1.5 text-center text-[10px] leading-tight transition ${active ? "border-blue-500 bg-blue-50 text-blue-800 ring-1 ring-blue-300" : "border-transparent bg-white text-slate-600 hover:border-blue-300 hover:bg-blue-50/50"}`} title={dragData ? "Arrastra al lienzo o haz clic para insertar" : "Selecciona y arrastra entre dos puntos azules"}>
    <span className="grid h-10 w-14 place-items-center">{preview}</span><span className="line-clamp-2">{item.label}</span>
  </button>;
}

function ShapeItem({ item, library, onAddVisual }) {
  return <ShapeButton item={item} dragData={{ type: "visual", library, shape: item.shape, label: item.label }} onClick={() => onAddVisual(library, item.shape, item.label)} preview={<div className="h-9 w-14"><ShapeRenderer compact shape={item.shape} style={{ fill: "#fff", stroke: "#475569", strokeWidth: 1.5 }}/></div>} />;
}

function Group({ title, children, open, onToggle }) {
  return <section className="border-b border-slate-200 pb-2"><button type="button" className="flex w-full items-center justify-between px-1 py-2 text-[11px] font-bold uppercase tracking-wider text-slate-500" onClick={onToggle}><span>{title}</span><span aria-hidden="true">{open ? "−" : "+"}</span></button>{open && <div className="grid grid-cols-3 gap-1">{children}</div>}</section>;
}

export default function ModelingPalette({ umlElements = [], umlRelationships = [], onAddUml, onAddVisual, activeConnector, onSelectConnector }) {
  const [query, setQuery] = useState("");
  const [open, setOpen] = useState({ uml: true, general: true, flowchart: false, arrows: true, er: false });
  const normalized = query.trim().toLowerCase();
  const matches = (label) => !normalized || label.toLowerCase().includes(normalized);
  const umlItems = useMemo(() => umlElements.filter((item) => matches(`${item.label} ${item.metaclass}`)), [umlElements, normalized]);
  const toggle = (name) => setOpen((current) => ({ ...current, [name]: !current[name] }));
  const relationItems = umlRelationships.map((relationshipType) => ({ relationshipType, label: relationshipType, ...relationshipPresentation(relationshipType).style })).filter((item) => matches(item.label));

  return <aside className="modeler-palette w-60 shrink-0 overflow-y-auto border-r border-slate-200 bg-slate-50 p-2.5">
    <label className="sr-only" htmlFor="shape-search">Buscar figuras</label><input id="shape-search" value={query} onChange={(event) => setQuery(event.target.value)} className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-xs outline-none focus:border-blue-500" placeholder="Buscar figuras…" />
    <div className="mt-2 space-y-1">
      <Group title="UML" open={open.uml || Boolean(normalized)} onToggle={() => toggle("uml")}>
        {umlItems.map((item) => <ShapeButton key={item.key} item={item} dragData={{ type: "uml", definition: item }} onClick={() => onAddUml(item)} preview={<UmlPreview metaclass={item.metaclass} properties={item.properties}/>}/>) }
        {relationItems.map((item) => <ShapeButton key={item.relationshipType} item={item} active={activeConnector?.kind === "uml" && activeConnector.type === item.relationshipType} onClick={() => onSelectConnector({ kind: "uml", type: item.relationshipType, label: item.label })} preview={<ConnectorPreview definition={item}/>}/>) }
      </Group>
      <Group title="General" open={open.general || Boolean(normalized)} onToggle={() => toggle("general")}>{GENERAL_SHAPES.filter((item) => matches(item.label)).map((item) => <ShapeItem key={item.shape} item={item} library="general" onAddVisual={onAddVisual}/>)}</Group>
      <Group title="Flujo" open={open.flowchart || Boolean(normalized)} onToggle={() => toggle("flowchart")}>{FLOWCHART_SHAPES.filter((item) => matches(item.label)).map((item) => <ShapeItem key={item.shape} item={item} library="flowchart" onAddVisual={onAddVisual}/>)}</Group>
      <Group title="Conectores" open={open.arrows || Boolean(normalized)} onToggle={() => toggle("arrows")}>{ARROW_SHAPES.filter((item) => matches(item.label)).map((item) => <ShapeButton key={item.shape} item={item} active={activeConnector?.kind === "visual" && activeConnector.type === item.shape} onClick={() => onSelectConnector({ kind: "visual", type: item.shape, label: item.label })} preview={<ConnectorPreview definition={item}/>}/>)}</Group>
      <Group title="Entidad–Relación" open={open.er || Boolean(normalized)} onToggle={() => toggle("er")}>{ER_SHAPES.filter((item) => matches(item.label)).map((item) => <ShapeItem key={item.shape} item={item} library="er" onAddVisual={onAddVisual}/>)}{ER_CONNECTORS.filter((item) => matches(item.label)).map((item) => <ShapeButton key={item.shape} item={item} active={activeConnector?.kind === "visual" && activeConnector.type === item.shape} onClick={() => onSelectConnector({ kind: "visual", type: item.shape, label: item.label })} preview={<ConnectorPreview definition={item}/>}/>)}</Group>
    </div>
    <p className="mt-3 px-1 text-[10px] leading-4 text-slate-500">Arrastra figuras al lienzo. Elige un conector y arrastra entre los puntos azules de dos figuras.</p>
  </aside>;
}
