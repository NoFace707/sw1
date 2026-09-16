const MARKER_OPTIONS = [
  ["none", "Ninguno"], ["arrow", "Flecha"], ["arrow-open", "Flecha abierta"], ["triangle", "Triángulo"],
  ["diamond", "Rombo vacío"], ["diamond-filled", "Rombo lleno"], ["circle", "Círculo"], ["one", "Uno"],
  ["zero-one", "Cero o uno"], ["many", "Muchos"], ["one-many", "Uno a muchos"], ["zero-many", "Cero a muchos"],
];

function FieldLabel({ children }) { return <span className="text-[10px] font-bold uppercase tracking-wide text-slate-500">{children}</span>; }

export default function FormatInspector({ selectedNode, selectedEdge, nodes, editingNodeId, renameDraft, onBeginRename, onRenameChange, onRenameCommit, onRenameCancel, onNodeStyle, onClassAttributes, onEdgeStyle, canEdit = false, onClose }) {
  const node = selectedNode ? nodes.find((item) => item.id === selectedNode.id) || selectedNode : null;
  const nodeStyle = node?.data?.visualProperties?.style || {};
  const edgeStyle = selectedEdge?.data?.presentation?.style || {};
  const isClass = node?.type === "uml" && node?.data?.metaclass === "Class";
  const savedAttributes = normalizeClassAttributes(node?.data?.properties?.attributes);
  const attributeSignature = JSON.stringify(savedAttributes);
  const [attributeDrafts, setAttributeDrafts] = useState(savedAttributes);
  useEffect(() => { setAttributeDrafts(savedAttributes); }, [node?.id, attributeSignature]);
  const saveAttributes = (next) => { setAttributeDrafts(next); onClassAttributes?.(next); };
  return <aside className="modeler-inspector w-64 shrink-0 overflow-y-auto border-l border-slate-200 bg-white p-3 shadow-sm">
    <div className="flex items-center justify-between"><h2 className="text-xs font-bold uppercase tracking-widest text-slate-500">Formato</h2><button type="button" onClick={onClose} className="rounded p-1 text-slate-500 hover:bg-slate-100" aria-label="Cerrar inspector">×</button></div>
    {node && <div className="mt-4 grid gap-4">
      <label className="grid gap-1"><FieldLabel>Nombre</FieldLabel><input className="w-full rounded-md border border-slate-300 px-2 py-1.5 text-sm focus:border-blue-500 focus:outline-none" value={editingNodeId === node.id ? renameDraft : node.data.label} onFocus={() => onBeginRename(node)} onChange={(event) => onRenameChange(event.target.value)} onBlur={onRenameCommit} onKeyDown={(event) => { if (event.key === "Enter") event.currentTarget.blur(); if (event.key === "Escape") onRenameCancel(); }}/></label>
      {isClass && <section className="grid gap-2 border-t border-slate-200 pt-3" aria-label="Atributos de la clase">
        <div className="flex items-center justify-between"><FieldLabel>Atributos</FieldLabel><span className="text-[10px] text-slate-400">{attributeDrafts.length}</span></div>
        {attributeDrafts.length === 0 && <p className="rounded bg-slate-50 px-2 py-2 text-[11px] text-slate-500">La clase no tiene atributos.</p>}
        <div className="grid gap-1.5">{attributeDrafts.map((attribute, index) => <div key={index} className="flex items-center gap-1">
          <input disabled={!canEdit} aria-label={`Atributo ${index + 1}`} className="min-w-0 flex-1 rounded border border-slate-300 px-2 py-1.5 font-mono text-[11px] outline-none focus:border-blue-500 disabled:bg-slate-50" value={attribute} placeholder="+ nombre: Tipo" onChange={(event) => setAttributeDrafts((current) => current.map((item, itemIndex) => itemIndex === index ? event.target.value : item))} onBlur={(event) => saveAttributes(commitClassAttribute(attributeDrafts, index, event.target.value))} onKeyDown={(event) => { if (event.key === "Enter") event.currentTarget.blur(); if (event.key === "Escape") setAttributeDrafts(savedAttributes); }}/>
          <button disabled={!canEdit} type="button" aria-label={`Eliminar atributo ${index + 1}`} title="Eliminar atributo" className="grid h-7 w-7 place-items-center rounded text-rose-600 hover:bg-rose-50 disabled:opacity-40" onMouseDown={(event) => event.preventDefault()} onClick={() => saveAttributes(removeClassAttribute(attributeDrafts, index))}>×</button>
        </div>)}</div>
        <button disabled={!canEdit} type="button" className="rounded-md border border-dashed border-blue-300 px-2 py-1.5 text-xs font-semibold text-blue-700 hover:bg-blue-50 disabled:opacity-40" onMouseDown={(event) => event.preventDefault()} onClick={() => saveAttributes(addClassAttribute(attributeDrafts))}>+ Añadir atributo</button>
      </section>}
      {node.type === "visual" && <><div className="border-t border-slate-200 pt-3"><FieldLabel>Apariencia</FieldLabel></div><label className="flex items-center justify-between text-xs">Fondo<input type="color" value={nodeStyle.fill || "#ffffff"} onChange={(event) => onNodeStyle("fill", event.target.value)}/></label><label className="flex items-center justify-between text-xs">Borde<input type="color" value={nodeStyle.stroke || "#475569"} onChange={(event) => onNodeStyle("stroke", event.target.value)}/></label><label className="flex items-center justify-between text-xs">Texto<input type="color" value={nodeStyle.textColor || "#0f172a"} onChange={(event) => onNodeStyle("textColor", event.target.value)}/></label><label className="grid gap-1 text-xs"><span>Grosor</span><select className="rounded border border-slate-300 px-2 py-1.5" value={nodeStyle.strokeWidth || 2} onChange={(event) => onNodeStyle("strokeWidth", Number(event.target.value))}>{[1,2,3,4].map((value) => <option key={value} value={value}>{value} px</option>)}</select></label></>}
    </div>}
    {selectedEdge && <div className="mt-4 grid gap-3">
      <div className="rounded-md bg-blue-50 px-2 py-2 text-xs font-semibold text-blue-800">{selectedEdge.data?.relationshipType || selectedEdge.data?.visualProperties?.shape || "Conector"}</div>
      <label className="flex items-center justify-between text-xs">Color<input type="color" value={edgeStyle.stroke || "#475569"} onChange={(event) => onEdgeStyle("stroke", event.target.value)}/></label>
      <label className="grid gap-1 text-xs"><span>Grosor</span><select className="rounded border border-slate-300 px-2 py-1.5" value={edgeStyle.strokeWidth || 2} onChange={(event) => onEdgeStyle("strokeWidth", Number(event.target.value))}>{[1,2,3,4].map((value) => <option key={value} value={value}>{value} px</option>)}</select></label>
      <label className="grid gap-1 text-xs"><span>Ruta</span><select className="rounded border border-slate-300 px-2 py-1.5" value={edgeStyle.routing || "orthogonal"} onChange={(event) => onEdgeStyle("routing", event.target.value)}><option value="straight">Recta</option><option value="orthogonal">Ortogonal</option><option value="curved">Curva</option></select></label>
      <label className="grid gap-1 text-xs"><span>Línea</span><select className="rounded border border-slate-300 px-2 py-1.5" value={edgeStyle.lineStyle || "solid"} onChange={(event) => onEdgeStyle("lineStyle", event.target.value)}><option value="solid">Continua</option><option value="dashed">Discontinua</option></select></label>
      <label className="grid gap-1 text-xs"><span>Inicio</span><select className="rounded border border-slate-300 px-2 py-1.5" value={edgeStyle.startMarker || "none"} onChange={(event) => onEdgeStyle("startMarker", event.target.value)}>{MARKER_OPTIONS.map(([value,label]) => <option key={value} value={value}>{label}</option>)}</select></label>
      <label className="grid gap-1 text-xs"><span>Final</span><select className="rounded border border-slate-300 px-2 py-1.5" value={edgeStyle.endMarker || "none"} onChange={(event) => onEdgeStyle("endMarker", event.target.value)}>{MARKER_OPTIONS.map(([value,label]) => <option key={value} value={value}>{label}</option>)}</select></label>
    </div>}
  </aside>;
}
import { useEffect, useState } from "react";
import { addClassAttribute, commitClassAttribute, normalizeClassAttributes, removeClassAttribute } from "./classAttributes.js";
