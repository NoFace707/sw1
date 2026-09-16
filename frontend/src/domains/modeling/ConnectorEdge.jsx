import { BaseEdge, getBezierPath, getSmoothStepPath, getStraightPath } from "@xyflow/react";

export const MARKERS = ["arrow", "arrow-open", "triangle", "diamond", "diamond-filled", "circle", "one", "zero-one", "many", "one-many", "zero-many"];

export function EdgeMarkerDefinitions() {
  return <svg aria-hidden="true" className="pointer-events-none absolute h-0 w-0"><defs>
    <marker id="modeler-arrow" viewBox="0 0 12 12" refX="10" refY="6" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M1 1 L11 6 L1 11 Z" fill="context-stroke"/></marker>
    <marker id="modeler-arrow-open" viewBox="0 0 12 12" refX="10" refY="6" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M1 1 L11 6 L1 11" fill="none" stroke="context-stroke" strokeWidth="1.6"/></marker>
    <marker id="modeler-triangle" viewBox="0 0 14 14" refX="12" refY="7" markerWidth="8" markerHeight="8" orient="auto-start-reverse"><path d="M1 1 L13 7 L1 13 Z" fill="white" stroke="context-stroke" strokeWidth="1.5"/></marker>
    <marker id="modeler-diamond" viewBox="0 0 16 12" refX="15" refY="6" markerWidth="9" markerHeight="8" orient="auto-start-reverse"><path d="M1 6 L8 1 L15 6 L8 11 Z" fill="white" stroke="context-stroke" strokeWidth="1.4"/></marker>
    <marker id="modeler-diamond-filled" viewBox="0 0 16 12" refX="15" refY="6" markerWidth="9" markerHeight="8" orient="auto-start-reverse"><path d="M1 6 L8 1 L15 6 L8 11 Z" fill="context-stroke"/></marker>
    <marker id="modeler-circle" viewBox="0 0 12 12" refX="10" refY="6" markerWidth="8" markerHeight="8" orient="auto-start-reverse"><circle cx="6" cy="6" r="4" fill="white" stroke="context-stroke" strokeWidth="1.5"/></marker>
    <marker id="modeler-one" viewBox="0 0 12 16" refX="10" refY="8" markerWidth="9" markerHeight="11" orient="auto-start-reverse"><path d="M9 1 V15" stroke="context-stroke" strokeWidth="1.7"/></marker>
    <marker id="modeler-zero-one" viewBox="0 0 20 16" refX="18" refY="8" markerWidth="14" markerHeight="11" orient="auto-start-reverse"><circle cx="5" cy="8" r="4" fill="white" stroke="context-stroke" strokeWidth="1.5"/><path d="M15 1 V15" stroke="context-stroke" strokeWidth="1.7"/></marker>
    <marker id="modeler-many" viewBox="0 0 16 18" refX="14" refY="9" markerWidth="11" markerHeight="13" orient="auto-start-reverse"><path d="M1 1 L14 9 L1 17 M14 9 H1" fill="none" stroke="context-stroke" strokeWidth="1.5"/></marker>
    <marker id="modeler-one-many" viewBox="0 0 23 18" refX="21" refY="9" markerWidth="15" markerHeight="13" orient="auto-start-reverse"><path d="M2 1 V17 M8 1 L21 9 L8 17 M21 9 H8" fill="none" stroke="context-stroke" strokeWidth="1.5"/></marker>
    <marker id="modeler-zero-many" viewBox="0 0 26 18" refX="24" refY="9" markerWidth="17" markerHeight="13" orient="auto-start-reverse"><circle cx="5" cy="9" r="4" fill="white" stroke="context-stroke" strokeWidth="1.5"/><path d="M11 1 L24 9 L11 17 M24 9 H11" fill="none" stroke="context-stroke" strokeWidth="1.5"/></marker>
  </defs></svg>;
}

function markerUrl(marker) { return marker && marker !== "none" ? `url(#modeler-${marker})` : undefined; }

export function ConnectorPreview({ definition }) {
  const dashed = definition.lineStyle === "dashed";
  return <svg className="h-9 w-14 overflow-visible" viewBox="0 0 56 36" aria-hidden="true"><path d={definition.routing === "curved" ? "M3 29 C18 2 37 2 53 29" : definition.routing === "orthogonal" ? "M3 28 H28 V8 H53" : "M3 18 H53"} fill="none" stroke="#475569" strokeWidth="2" strokeDasharray={dashed ? "5 4" : undefined}/><path d={definition.endMarker !== "none" ? "M45 12 L53 18 L45 24" : ""} fill="none" stroke="#475569" strokeWidth="2"/></svg>;
}

export function ModelerEdge(props) {
  const presentation = props.data?.presentation || {};
  const edgeStyle = presentation.style || {};
  const routing = edgeStyle.routing || "orthogonal";
  const pathResult = routing === "curved" ? getBezierPath(props) : routing === "straight" ? getStraightPath(props) : getSmoothStepPath({ ...props, borderRadius: 8 });
  const [path, labelX, labelY] = pathResult;
  return <BaseEdge id={props.id} path={path} labelX={labelX} labelY={labelY} label={props.label || presentation.label} markerStart={markerUrl(edgeStyle.startMarker)} markerEnd={markerUrl(edgeStyle.endMarker)} interactionWidth={18} style={{ stroke: edgeStyle.stroke || "#475569", strokeWidth: Number(edgeStyle.strokeWidth || 2), strokeDasharray: edgeStyle.lineStyle === "dashed" ? "7 6" : undefined, ...(props.selected ? { filter: "drop-shadow(0 0 3px #2563eb)" } : {}) }} />;
}

export const edgeTypes = { modeler: ModelerEdge };
