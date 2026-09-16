import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Background, ConnectionMode, Controls, MiniMap, ReactFlow, useEdgesState, useNodesState } from "@xyflow/react";
import { toPng, toSvg } from "html-to-image";
import "@xyflow/react/dist/style.css";
import { requestJsonWithAuthRetry } from "../../services/apiClient.js";
import { UML_DIAGRAM_TYPES, diagramProfile } from "./diagramRegistry.js";
import { downloadInterchange, interchangeProfiles, previewInterchange } from "../interchange/interchangeApi.js";
import { importProjectFile } from "../projects/projectsApi.js";
import { useOnlineStatus } from "../sync/useOnlineStatus.js";
import { cacheSnapshot, getCachedSnapshot } from "../sync/offlineDb.js";
import { useProjectCollaboration } from "../collaboration/useProjectCollaboration.js";
import CollaborationPanel from "../collaboration/CollaborationPanel.jsx";
import FormatInspector from "./FormatInspector.jsx";
import ModelingPalette from "./ModelingPalette.jsx";
import { EdgeMarkerDefinitions, edgeTypes } from "./ConnectorEdge.jsx";
import { nodeTypes } from "./DiagramNodes.jsx";
import { isVisualItem, normalizeVisualEdgeProperties, relationshipPresentation, shapeDefinition, visualEdgeProperties, visualNodeProperties } from "./visualRegistry.js";
import { umlElementDefinition } from "./umlRegistry.js";
import { normalizeClassAttributes, requiredClassHeight } from "./classAttributes.js";

function flowNodeFromApi(item, elements) {
  const element = elements.find((candidate) => String(candidate.id) === String(item.element));
  const visual = isVisualItem(item.properties);
  return {
    id: String(item.id),
    type: visual ? "visual" : "uml",
    position: { x: Number(item.x || 0), y: Number(item.y || 0) },
    data: visual
      ? { label: item.properties.label || "Figura", elementId: null, visualProperties: item.properties, properties: item.properties }
      : { label: element?.name || "Vista", elementId: item.element, metaclass: element?.metaclass || "", properties: element?.properties || {} },
    style: { width: Number(item.width || 180), height: Number(item.height || 80) },
  };
}

function flowEdgeFromApi(item, relationships = []) {
  const visual = isVisualItem(item.properties);
  const relationship = relationships.find((candidate) => String(candidate.id) === String(item.relationship));
  const visualProperties = visual ? normalizeVisualEdgeProperties(item.properties) : null;
  const semanticPresentation = relationshipPresentation(relationship?.relationship_type, item.properties?.presentation || {});
  const presentation = visual ? visualProperties : { ...semanticPresentation, ...(item.properties?.presentation || {}), style: { ...semanticPresentation.style, ...(item.properties?.presentation?.style || {}) } };
  return {
    id: String(item.id),
    type: "modeler",
    source: String(item.source_node),
    target: String(item.target_node),
    sourceHandle: presentation.sourceHandle || "bottom",
    targetHandle: presentation.targetHandle || "top",
    className: "modeler-edge",
    label: presentation.label || item.properties?.label || "",
    data: { relationshipId: item.relationship || null, relationshipType: relationship?.relationship_type || null, visualProperties, rawProperties: item.properties || {}, presentation },
  };
}

function safeFilename(value) {
  return value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-zA-Z0-9_-]+/g, "-").replace(/^-|-$/g, "").toLowerCase() || "modelo";
}

function downloadDataUrl(dataUrl, filename) {
  const link = document.createElement("a");
  link.download = filename;
  link.href = dataUrl;
  link.click();
}

function apiErrorMessage(cause, fallback) {
  if (cause?.detail) return cause.detail;
  const fieldError = cause && typeof cause === "object"
    ? Object.entries(cause).find(([key, value]) => key !== "status" && (Array.isArray(value) || typeof value === "string"))
    : null;
  if (!fieldError) return fallback;
  const [field, value] = fieldError;
  return `${field}: ${Array.isArray(value) ? value.join(" ") : value}`;
}

export default function EditorShell({ project, userId = "session", onProjectChange, onBack }) {
  const online = useOnlineStatus();
  const collaboration = useProjectCollaboration(project.id, online);
  const canEdit = online && project.membership_role !== "viewer";
  const [diagrams, setDiagrams] = useState([]);
  const [selectedDiagram, setSelectedDiagram] = useState("");
  const [elements, setElements] = useState([]);
  const [relationships, setRelationships] = useState([]);
  const [nodes, setNodes, onNodesChangeInternal] = useNodesState([]);
  const [edges, setEdges, onEdgesChange] = useEdgesState([]);
  const [selectedNode, setSelectedNode] = useState(null);
  const [selectedEdge, setSelectedEdge] = useState(null);
  const [status, setStatus] = useState("Cargando…");
  const [diagramType, setDiagramType] = useState("class");
  const [diagramName, setDiagramName] = useState("Diagrama nuevo");
  const [projectName, setProjectName] = useState(project.name);
  const [editingProjectName, setEditingProjectName] = useState(false);
  const [editingDiagramId, setEditingDiagramId] = useState("");
  const [diagramNameDraft, setDiagramNameDraft] = useState("");
  const [editingNodeId, setEditingNodeId] = useState("");
  const [renameDraft, setRenameDraft] = useState("");
  const [renameOriginal, setRenameOriginal] = useState("");
  const [activeConnector, setActiveConnector] = useState(null);
  const [importFile, setImportFile] = useState(null);
  const [importReport, setImportReport] = useState(null);
  const [exportOpen, setExportOpen] = useState(false);
  const [imageMenuOpen, setImageMenuOpen] = useState(false);
  const [diagramDialogOpen, setDiagramDialogOpen] = useState(false);
  const [collaborationOpen, setCollaborationOpen] = useState(false);
  const [paletteOpen, setPaletteOpen] = useState(true);
  const [inspectorOpen, setInspectorOpen] = useState(true);
  const flowInstance = useRef(null);
  const canvasRef = useRef(null);
  const pendingConnection = useRef(null);
  const clickedConnection = useRef(null);
  const lastNativeConnectionAt = useRef(0);
  const classAttributeSaveQueue = useRef(Promise.resolve());
  const classAttributeSaveId = useRef(0);
  const currentDiagram = useMemo(() => diagrams.find((item) => String(item.id) === String(selectedDiagram)), [diagrams, selectedDiagram]);
  const currentProfile = useMemo(() => diagramProfile(currentDiagram?.diagram_type), [currentDiagram?.diagram_type]);
  const auxiliaryCount = useMemo(() => nodes.filter((node) => node.type === "visual").length + edges.filter((edge) => edge.data?.visualProperties).length, [nodes, edges]);

  useEffect(() => { setProjectName(project.name); }, [project.name]);
  useEffect(() => { setActiveConnector(null); }, [currentDiagram?.diagram_type]);

  const loadCanvas = useCallback(async (diagramId, loadedElements = elements, loadedDiagrams = diagrams, loadedRelationships = relationships) => {
    if (!diagramId) { setNodes([]); setEdges([]); return; }
    const [loadedNodes, loadedEdges] = await Promise.all([
      requestJsonWithAuthRetry(`/api/modeling/projects/${project.id}/diagrams/${diagramId}/nodes/`),
      requestJsonWithAuthRetry(`/api/modeling/projects/${project.id}/diagrams/${diagramId}/edges/`),
    ]);
    setNodes(loadedNodes.map((item) => flowNodeFromApi(item, loadedElements)));
    setEdges(loadedEdges.map((item) => flowEdgeFromApi(item, loadedRelationships)));
    cacheSnapshot(userId, project.id, { revision: project.revision, payload: { diagrams: loadedDiagrams, elements: loadedElements, relationships: loadedRelationships, diagramNodes: loadedNodes, diagramEdges: loadedEdges } }).catch(() => {});
  }, [project.id, project.revision, userId, elements, diagrams, relationships, setEdges, setNodes]);

  const loadModel = useCallback(async (preferredDiagram = selectedDiagram) => {
    const [loadedDiagrams, loadedElements, loadedRelationships] = await Promise.all([
      requestJsonWithAuthRetry(`/api/modeling/projects/${project.id}/diagrams/`),
      requestJsonWithAuthRetry(`/api/modeling/projects/${project.id}/elements/`),
      requestJsonWithAuthRetry(`/api/modeling/projects/${project.id}/relationships/`),
    ]);
    setDiagrams(loadedDiagrams);
    setElements(loadedElements);
    setRelationships(loadedRelationships);
    const nextDiagram = loadedDiagrams.some((item) => String(item.id) === String(preferredDiagram)) ? preferredDiagram : (loadedDiagrams[0]?.id || "");
    setSelectedDiagram(nextDiagram);
    await loadCanvas(nextDiagram, loadedElements, loadedDiagrams, loadedRelationships);
    setStatus("Guardado");
  }, [project.id, selectedDiagram, loadCanvas]);

  useEffect(() => {
    if (online) {
      loadModel("").catch(() => setStatus("No se pudo cargar el modelo"));
      return;
    }
    getCachedSnapshot(userId, project.id).then((snapshot) => {
      const payload = snapshot?.payload;
      setDiagrams(payload?.diagrams || []);
      setElements(payload?.elements || []);
      setRelationships(payload?.relationships || []);
      const next = payload?.diagrams?.[0]?.id || "";
      setSelectedDiagram(next);
      setNodes((payload?.diagramNodes || []).filter((item) => String(item.diagram) === String(next)).map((item) => flowNodeFromApi(item, payload?.elements || [])));
      setEdges((payload?.diagramEdges || []).filter((item) => String(item.diagram) === String(next)).map((item) => flowEdgeFromApi(item, payload?.relationships || [])));
      setStatus(payload ? "Offline · copia local de solo lectura" : "Sin copia local del modelo");
    }).catch(() => setStatus("No se pudo abrir la copia local"));
  }, [online, project.id, userId]);

  useEffect(() => {
    const latest = collaboration.events[0];
    if (latest?.event !== "operation.confirmed" || !online) return;
    Promise.all([
      requestJsonWithAuthRetry(`/api/modeling/projects/${project.id}/`),
      loadModel(selectedDiagram),
    ]).then(([updatedProject]) => {
      onProjectChange?.(updatedProject);
      setProjectName(updatedProject.name);
      setStatus("Actualizado por colaboración");
    }).catch(() => setStatus("No se pudo aplicar el cambio colaborativo"));
  }, [collaboration.events, online]);

  useEffect(() => {
    function handleKeyboard(event) {
      if (event.key === "F2" && selectedNode && !editingNodeId) { event.preventDefault(); beginNodeRename(selectedNode); }
      if (event.key === "Escape" && !editingNodeId) { clickedConnection.current = null; pendingConnection.current = null; setSelectedNode(null); setSelectedEdge(null); setActiveConnector(null); setStatus("Herramienta de selección activa"); }
    }
    window.addEventListener("keydown", handleKeyboard);
    return () => window.removeEventListener("keydown", handleKeyboard);
  }, [selectedNode, editingNodeId]);

  const renderedNodes = useMemo(() => nodes.map((node) => ({
    ...node,
    data: {
      ...node.data,
      editing: node.id === editingNodeId,
      draft: node.id === editingNodeId ? renameDraft : node.data.label,
      onDraftChange: setRenameDraft,
      onCommit: commitNodeRename,
      onCancel: cancelNodeRename,
      connectable: canEdit,
      nodeId: node.id,
      onConnectionStart: (nodeId, handle) => { pendingConnection.current = { nodeId, handle }; },
      onConnectionEnd: (nodeId, handle) => {
        const source = pendingConnection.current;
        pendingConnection.current = null;
        if (!source || source.nodeId === nodeId) return;
        window.setTimeout(() => {
          if (Date.now() - lastNativeConnectionAt.current < 250) return;
          connectNodes({ source: source.nodeId, sourceHandle: source.handle, target: nodeId, targetHandle: handle });
        }, 0);
      },
      onConnectionClick: (nodeId, handle) => {
        const source = clickedConnection.current;
        if (!source) {
          clickedConnection.current = { nodeId, handle };
          setStatus("Origen seleccionado · haz clic en un punto de la figura destino");
          return;
        }
        clickedConnection.current = null;
        if (source.nodeId === nodeId) {
          setStatus("Elige una figura destino distinta");
          return;
        }
        connectNodes({ source: source.nodeId, sourceHandle: source.handle, target: nodeId, targetHandle: handle });
      },
    },
  })), [nodes, editingNodeId, renameDraft, canEdit, activeConnector]);

  useEffect(() => {
    function handleAtPoint(event) {
      const direct = event.target?.closest?.(".modeler-handle");
      if (direct) return direct;
      return [...document.querySelectorAll(".modeler-handle")].find((handle) => {
        const box = handle.getBoundingClientRect();
        return event.clientX >= box.left - 4 && event.clientX <= box.right + 4 && event.clientY >= box.top - 4 && event.clientY <= box.bottom + 4;
      });
    }
    function beginConnection(event) {
      const sourceHandle = handleAtPoint(event);
      if (!sourceHandle) return;
      pendingConnection.current = {
        nodeId: sourceHandle.getAttribute("data-nodeid"),
        handle: sourceHandle.getAttribute("data-handleid"),
      };
    }
    function finishConnection(event) {
      const source = pendingConnection.current;
      pendingConnection.current = null;
      const targetHandle = handleAtPoint(event);
      const targetNodeId = targetHandle?.getAttribute("data-nodeid");
      const targetHandleId = targetHandle?.getAttribute("data-handleid");
      if (!source || !targetNodeId || source.nodeId === targetNodeId) return;
      window.setTimeout(() => {
        if (Date.now() - lastNativeConnectionAt.current < 250) return;
        connectNodes({ source: source.nodeId, sourceHandle: source.handle, target: targetNodeId, targetHandle: targetHandleId });
      }, 0);
    }
    window.addEventListener("pointerdown", beginConnection, true);
    window.addEventListener("pointerup", finishConnection, true);
    return () => {
      window.removeEventListener("pointerdown", beginConnection, true);
      window.removeEventListener("pointerup", finishConnection, true);
    };
  }, [canEdit, activeConnector, nodes, relationships, selectedDiagram]);

  function selectDiagram(diagramId) {
    clickedConnection.current = null;
    pendingConnection.current = null;
    setSelectedDiagram(diagramId);
    setSelectedNode(null);
    setSelectedEdge(null);
    if (online) loadCanvas(diagramId).catch(() => setStatus("No se pudo abrir el diagrama"));
  }

  async function createDiagram(event) {
    event.preventDefault();
    if (!canEdit || !diagramName.trim()) return;
    try {
      const created = await requestJsonWithAuthRetry(`/api/modeling/projects/${project.id}/diagrams/`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name: diagramName.trim(), diagram_type: diagramType }) });
      setDiagrams((current) => [...current, created]);
      setSelectedDiagram(created.id);
      setNodes([]); setEdges([]); setDiagramName(`Diagrama ${diagrams.length + 2}`); setDiagramDialogOpen(false); setStatus("Diagrama creado");
    } catch (cause) { setStatus(cause?.detail || "No se pudo crear el diagrama"); }
  }

  function startDiagramRename(diagram) { if (!canEdit) return; setEditingDiagramId(String(diagram.id)); setDiagramNameDraft(diagram.name); }
  async function commitDiagramRename(diagram) {
    const name = diagramNameDraft.trim();
    if (!name) { setStatus("El nombre del diagrama es obligatorio"); return; }
    setEditingDiagramId("");
    const previous = diagram.name;
    setDiagrams((current) => current.map((item) => item.id === diagram.id ? { ...item, name } : item));
    try { await requestJsonWithAuthRetry(`/api/modeling/projects/${project.id}/diagrams/${diagram.id}/`, { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name }) }); setStatus("Diagrama renombrado"); }
    catch (cause) { setDiagrams((current) => current.map((item) => item.id === diagram.id ? { ...item, name: previous } : item)); setStatus(cause?.detail || "No se pudo renombrar el diagrama"); }
  }

  async function commitProjectName() {
    const name = projectName.trim();
    setEditingProjectName(false);
    if (!name) { setProjectName(project.name); setStatus("El nombre del proyecto es obligatorio"); return; }
    if (name === project.name || project.membership_role !== "owner") return;
    try {
      const updated = await requestJsonWithAuthRetry(`/api/modeling/projects/${project.id}/`, { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name }) });
      onProjectChange?.(updated); setProjectName(updated.name); setStatus("Proyecto renombrado");
    } catch (cause) { setProjectName(project.name); setStatus(cause?.detail || "No se pudo renombrar el proyecto"); }
  }

  function centerPosition() {
    const bounds = canvasRef.current?.getBoundingClientRect();
    if (flowInstance.current && bounds) return flowInstance.current.screenToFlowPosition({ x: bounds.left + bounds.width / 2, y: bounds.top + bounds.height / 2 });
    return { x: 100 + nodes.length * 24, y: 100 + nodes.length * 24 };
  }

  async function addUmlElement(item, position = centerPosition()) {
    if (!canEdit || !currentDiagram) return;
    const definition = typeof item === "string" ? umlElementDefinition(item) : item;
    const { metaclass, label, properties = {}, width = 180, height = 90 } = definition;
    setStatus("Guardando…");
    try {
      const element = await requestJsonWithAuthRetry(`/api/modeling/projects/${project.id}/elements/`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ metaclass, name: `${label} ${elements.length + 1}`, properties }) });
      const view = await requestJsonWithAuthRetry(`/api/modeling/projects/${project.id}/diagrams/${selectedDiagram}/nodes/`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ element: element.id, x: position.x, y: position.y, width, height }) });
      setElements((current) => [...current, element]);
      setNodes((current) => [...current, flowNodeFromApi(view, [...elements, element])]);
      setStatus("Figura añadida · doble clic para renombrar");
    } catch (cause) { setStatus(cause?.detail || "No se pudo añadir la figura UML"); }
  }

  async function addVisual(library, shape, label, position = centerPosition()) {
    if (!canEdit || !currentDiagram) return;
    setStatus("Guardando…");
    const properties = visualNodeProperties(library, shape, label);
    const definition = shapeDefinition(library, shape);
    try {
      const view = await requestJsonWithAuthRetry(`/api/modeling/projects/${project.id}/diagrams/${selectedDiagram}/nodes/`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ element: null, x: position.x, y: position.y, width: definition.width, height: definition.height, properties }) });
      setNodes((current) => [...current, flowNodeFromApi(view, elements)]);
      setStatus("Figura añadida · doble clic para renombrar");
    } catch (cause) { setStatus(cause?.detail || "No se pudo añadir la figura"); }
  }

  function handleDrop(event) {
    event.preventDefault();
    if (!canEdit || !flowInstance.current) return;
    try {
      const item = JSON.parse(event.dataTransfer.getData("application/x-modeler-shape"));
      const position = flowInstance.current.screenToFlowPosition({ x: event.clientX, y: event.clientY });
      if (item.type === "uml") addUmlElement(item.definition || item.metaclass, position);
      if (item.type === "visual") addVisual(item.library, item.shape, item.label, position);
    } catch { /* El arrastre no pertenece a la paleta. */ }
  }

  async function connectNodes(connection) {
    if (!canEdit || !connection.source || !connection.target) return;
    if (connection.source === connection.target) { setStatus("Elige dos figuras distintas para crear la conexión"); return; }
    lastNativeConnectionAt.current = Date.now();
    const connector = activeConnector || { kind: "visual", type: "arrow", label: "Flecha" };
    setStatus("Guardando conector…");
    try {
      if (connector.kind === "visual") {
        const properties = visualEdgeProperties(connector.type, { sourceHandle: connection.sourceHandle, targetHandle: connection.targetHandle });
        const created = await requestJsonWithAuthRetry(`/api/modeling/projects/${project.id}/diagrams/${selectedDiagram}/edges/`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ source_node: connection.source, target_node: connection.target, relationship: null, properties }) });
        setEdges((current) => [...current, flowEdgeFromApi(created, relationships)]);
      } else {
        const source = nodes.find((node) => node.id === connection.source)?.data?.elementId;
        const target = nodes.find((node) => node.id === connection.target)?.data?.elementId;
        if (!source || !target) { setStatus("Las relaciones UML solo conectan figuras UML; elige un conector visual para figuras auxiliares"); return; }
        const relationship = await requestJsonWithAuthRetry(`/api/modeling/projects/${project.id}/relationships/`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ relationship_type: connector.type, source, target }) });
        const presentation = relationshipPresentation(connector.type, { sourceHandle: connection.sourceHandle, targetHandle: connection.targetHandle });
        const created = await requestJsonWithAuthRetry(`/api/modeling/projects/${project.id}/diagrams/${selectedDiagram}/edges/`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ source_node: connection.source, target_node: connection.target, relationship: relationship.id, properties: { presentation } }) });
        const nextRelationships = [...relationships, relationship];
        setRelationships(nextRelationships);
        setEdges((current) => [...current, flowEdgeFromApi(created, nextRelationships)]);
      }
      setStatus(activeConnector ? `${connector.label} guardado · la herramienta sigue activa` : "Flecha guardada");
    } catch (cause) { setStatus(apiErrorMessage(cause, "No se pudo conectar las figuras")); }
  }

  function beginNodeRename(node) {
    if (!canEdit) return;
    setSelectedNode(node); setEditingNodeId(node.id); setRenameDraft(node.data.label); setRenameOriginal(node.data.label);
  }
  function cancelNodeRename() { setNodes((current) => current.map((node) => node.id === editingNodeId ? { ...node, data: { ...node.data, label: renameOriginal } } : node)); setRenameDraft(""); setEditingNodeId(""); }
  async function commitNodeRename() {
    if (!editingNodeId) return;
    const name = renameDraft.trim();
    if (!name) { setStatus("El nombre de la figura es obligatorio"); return; }
    const node = nodes.find((item) => item.id === editingNodeId);
    if (!node) return;
    const nodeId = editingNodeId;
    setEditingNodeId("");
    setNodes((current) => current.map((item) => item.id === nodeId ? { ...item, data: { ...item.data, label: name, visualProperties: item.data.visualProperties ? { ...item.data.visualProperties, label: name } : item.data.visualProperties } } : item));
    try {
      if (node.data.elementId) {
        await requestJsonWithAuthRetry(`/api/modeling/projects/${project.id}/elements/${node.data.elementId}/`, { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name }) });
        setElements((current) => current.map((item) => String(item.id) === String(node.data.elementId) ? { ...item, name } : item));
        setNodes((current) => current.map((item) => String(item.data.elementId) === String(node.data.elementId) ? { ...item, data: { ...item.data, label: name } } : item));
      } else {
        await requestJsonWithAuthRetry(`/api/modeling/projects/${project.id}/diagrams/${selectedDiagram}/nodes/${node.id}/`, { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ properties: { ...node.data.visualProperties, label: name } }) });
      }
      setStatus("Nombre guardado");
    } catch (cause) {
      setNodes((current) => current.map((item) => item.id === nodeId ? { ...item, data: { ...item.data, label: renameOriginal } } : item));
      setStatus(cause?.detail || "No se pudo guardar el nombre; se restauró el anterior");
    }
  }

  const onNodesChange = useCallback((changes) => {
    onNodesChangeInternal(changes);
    if (!canEdit) return;
    changes.filter((change) => change.type === "position" && change.position && change.dragging === false).forEach((change) => {
      requestJsonWithAuthRetry(`/api/modeling/projects/${project.id}/diagrams/${selectedDiagram}/nodes/${change.id}/`, { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ x: change.position.x, y: change.position.y }) }).catch(() => setStatus("No se pudo guardar la posición"));
    });
    changes.filter((change) => change.type === "dimensions" && change.dimensions && change.resizing === false).forEach((change) => {
      requestJsonWithAuthRetry(`/api/modeling/projects/${project.id}/diagrams/${selectedDiagram}/nodes/${change.id}/`, { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ width: change.dimensions.width, height: change.dimensions.height }) }).catch(() => setStatus("No se pudo guardar el tamaño"));
    });
  }, [canEdit, onNodesChangeInternal, project.id, selectedDiagram]);

  async function handleDelete({ nodes: deletedNodes, edges: deletedEdges }) {
    if (!canEdit) return;
    try {
      await Promise.all(deletedEdges.map((edge) => requestJsonWithAuthRetry(`/api/modeling/projects/${project.id}/diagrams/${selectedDiagram}/edges/${edge.id}/`, { method: "DELETE" })));
      await Promise.all(deletedEdges.filter((edge) => edge.data?.relationshipId).map((edge) => requestJsonWithAuthRetry(`/api/modeling/projects/${project.id}/relationships/${edge.data.relationshipId}/`, { method: "DELETE" })));
      await Promise.all(deletedNodes.map((node) => node.data?.elementId
        ? requestJsonWithAuthRetry(`/api/modeling/projects/${project.id}/elements/${node.data.elementId}/`, { method: "DELETE" })
        : requestJsonWithAuthRetry(`/api/modeling/projects/${project.id}/diagrams/${selectedDiagram}/nodes/${node.id}/`, { method: "DELETE" })));
      setElements((current) => current.filter((element) => !deletedNodes.some((node) => String(node.data?.elementId) === String(element.id))));
      setRelationships((current) => current.filter((relationship) => !deletedEdges.some((edge) => String(edge.data?.relationshipId) === String(relationship.id))));
      setSelectedNode(null); setSelectedEdge(null);
      setStatus("Selección eliminada");
    } catch (cause) { setStatus(cause?.detail || "No se pudo eliminar la selección"); await loadModel(selectedDiagram).catch(() => {}); }
  }

  async function updateVisualAppearance(field, value) {
    const node = nodes.find((item) => item.id === selectedNode?.id);
    if (!canEdit || !node?.data?.visualProperties) return;
    const properties = { ...node.data.visualProperties, style: { ...node.data.visualProperties.style, [field]: value } };
    setNodes((current) => current.map((item) => item.id === node.id ? { ...item, data: { ...item.data, visualProperties: properties, properties } } : item));
    try {
      await requestJsonWithAuthRetry(`/api/modeling/projects/${project.id}/diagrams/${selectedDiagram}/nodes/${node.id}/`, { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ properties }) });
      setStatus("Apariencia guardada");
    } catch (cause) {
      setStatus(cause?.detail || "No se pudo guardar la apariencia");
      await loadCanvas(selectedDiagram).catch(() => {});
    }
  }

  function updateClassAttributes(nextAttributes) {
    const node = nodes.find((item) => item.id === selectedNode?.id);
    if (!canEdit || node?.type !== "uml" || node.data?.metaclass !== "Class" || !node.data?.elementId) return;
    const attributes = normalizeClassAttributes(nextAttributes);
    const elementId = node.data.elementId;
    const properties = { ...(node.data.properties || {}), attributes };
    const heightByNode = new Map(nodes.filter((item) => String(item.data?.elementId) === String(elementId)).map((item) => [item.id, requiredClassHeight(item.style?.height, attributes.length, Array.isArray(item.data?.properties?.operations) ? item.data.properties.operations.length : 0)]));
    setElements((current) => current.map((item) => String(item.id) === String(elementId) ? { ...item, properties } : item));
    setNodes((current) => current.map((item) => String(item.data?.elementId) === String(elementId) ? { ...item, data: { ...item.data, properties }, style: { ...item.style, height: heightByNode.get(item.id) || item.style?.height } } : item));
    setStatus("Guardando atributos…");
    const saveId = ++classAttributeSaveId.current;
    classAttributeSaveQueue.current = classAttributeSaveQueue.current.catch(() => {}).then(async () => {
      try {
        const updated = await requestJsonWithAuthRetry(`/api/modeling/projects/${project.id}/elements/${elementId}/`, { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ properties }) });
        await Promise.all([...heightByNode.entries()].map(([nodeId, height]) => requestJsonWithAuthRetry(`/api/modeling/projects/${project.id}/diagrams/${selectedDiagram}/nodes/${nodeId}/`, { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ height }) })));
        if (saveId === classAttributeSaveId.current) {
          setElements((current) => current.map((item) => String(item.id) === String(elementId) ? updated : item));
          setNodes((current) => current.map((item) => String(item.data?.elementId) === String(elementId) ? { ...item, data: { ...item.data, properties: updated.properties || properties } } : item));
          setStatus("Atributos guardados");
        }
      } catch (cause) {
        if (saveId === classAttributeSaveId.current) {
          setStatus(cause?.detail || "No se pudieron guardar los atributos");
          await loadModel(selectedDiagram).catch(() => {});
        }
      }
    });
  }

  async function updateEdgeAppearance(field, value) {
    const edge = edges.find((item) => item.id === selectedEdge?.id);
    if (!canEdit || !edge) return;
    const visual = Boolean(edge.data?.visualProperties);
    const currentProperties = edge.data?.rawProperties || {};
    const currentPresentation = edge.data?.presentation || {};
    const presentation = { ...currentPresentation, style: { ...(currentPresentation.style || {}), [field]: value } };
    const properties = visual ? { ...normalizeVisualEdgeProperties(currentProperties), style: presentation.style } : { ...currentProperties, presentation };
    const optimistic = { ...edge, data: { ...edge.data, rawProperties: properties, visualProperties: visual ? properties : null, presentation } };
    setEdges((current) => current.map((item) => item.id === edge.id ? optimistic : item));
    setSelectedEdge(optimistic);
    try {
      const updated = await requestJsonWithAuthRetry(`/api/modeling/projects/${project.id}/diagrams/${selectedDiagram}/edges/${edge.id}/`, { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ properties }) });
      const normalized = flowEdgeFromApi(updated, relationships);
      setEdges((current) => current.map((item) => item.id === edge.id ? normalized : item));
      setSelectedEdge(normalized); setStatus("Conector actualizado");
    } catch (cause) { setStatus(cause?.detail || "No se pudo actualizar el conector"); await loadCanvas(selectedDiagram).catch(() => {}); }
  }

  async function saveImage(format) {
    const surface = canvasRef.current;
    if (!surface || !currentDiagram) return;
    setImageMenuOpen(false); setExportOpen(false); setStatus(`Generando ${format.toUpperCase()}…`);
    try {
      await flowInstance.current?.fitView({ padding: 0.15, duration: 0 });
      const options = {
        backgroundColor: "#ffffff",
        cacheBust: true,
        pixelRatio: format === "png" ? 2 : 1,
        filter: (element) => !element?.classList?.contains("react-flow__controls") && !element?.classList?.contains("react-flow__minimap") && !element?.classList?.contains("react-flow__panel"),
      };
      const dataUrl = format === "png" ? await toPng(surface, options) : await toSvg(surface, options);
      downloadDataUrl(dataUrl, `${safeFilename(projectName)}-${safeFilename(currentDiagram.name)}.${format}`);
      setStatus(`Imagen ${format.toUpperCase()} guardada`);
    } catch { setStatus("No se pudo generar la imagen"); }
  }

  async function exportXmi() {
    try {
      const profile = interchangeProfiles[0].id;
      const blob = await downloadInterchange(project.id, profile);
      const url = URL.createObjectURL(blob);
      downloadDataUrl(url, `${safeFilename(projectName)}.xmi`);
      setTimeout(() => URL.revokeObjectURL(url), 1_000);
      setExportOpen(false); setStatus("Modelo XMI exportado");
    } catch (cause) { setStatus(cause?.detail || "No se pudo exportar el modelo"); }
  }

  async function previewFile(event) {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) return;
    try {
      setStatus("Analizando importación…");
      const report = await previewInterchange(project.id, file, interchangeProfiles[0].id, "update");
      setImportFile(file); setImportReport(report); setStatus("Revisa el resumen antes de fusionar");
    } catch (cause) { setStatus(cause?.detail || cause?.errors?.[0] || "El archivo no es válido"); }
  }

  async function confirmImport() {
    if (!importFile) return;
    try {
      await importProjectFile(project.id, importFile, interchangeProfiles[0].id, "update");
      setImportFile(null); setImportReport(null); await loadModel(selectedDiagram); setStatus("Importación fusionada");
    } catch (cause) { setStatus(cause?.detail || cause?.errors?.[0] || "No se pudo fusionar la importación"); }
  }

  return <main className="flex h-screen min-h-[640px] flex-col overflow-hidden bg-slate-100 text-slate-800">
    <header className="relative z-30 flex h-12 shrink-0 items-center gap-2 border-b border-slate-200 bg-white px-2 text-sm shadow-sm">
      <button className="rounded-md p-2 font-semibold text-slate-600 hover:bg-slate-100" type="button" onClick={onBack} aria-label="Volver a proyectos">←</button>
      <div className="flex min-w-0 max-w-64 items-center gap-1 border-r border-slate-200 pr-2">{editingProjectName ? <input autoFocus aria-label="Nombre del proyecto" className="min-w-0 flex-1 rounded border border-blue-500 px-2 py-1 font-bold outline-none" value={projectName} onChange={(event) => setProjectName(event.target.value)} onBlur={commitProjectName} onKeyDown={(event) => { if (event.key === "Enter") event.currentTarget.blur(); if (event.key === "Escape") { setProjectName(project.name); setEditingProjectName(false); } }}/> : <button type="button" className="truncate px-1 font-bold text-slate-900" onDoubleClick={() => project.membership_role === "owner" && setEditingProjectName(true)} title={projectName}>{projectName}</button>}{project.membership_role === "owner" && !editingProjectName && <button type="button" className="rounded p-1 text-slate-400 hover:bg-slate-100" onClick={() => setEditingProjectName(true)} aria-label="Renombrar proyecto">✎</button>}</div>
      <div className="flex min-w-0 items-center gap-1">{editingDiagramId && currentDiagram ? <input autoFocus aria-label="Nombre del diagrama" className="w-44 rounded border border-blue-500 px-2 py-1 outline-none" value={diagramNameDraft} onChange={(event) => setDiagramNameDraft(event.target.value)} onBlur={() => commitDiagramRename(currentDiagram)} onKeyDown={(event) => { if (event.key === "Enter") event.currentTarget.blur(); if (event.key === "Escape") setEditingDiagramId(""); }}/> : <select aria-label="Diagrama actual" className="max-w-48 rounded-md border border-slate-300 bg-white px-2 py-1.5" value={selectedDiagram} onChange={(event) => selectDiagram(event.target.value)}>{diagrams.map((diagram) => <option key={diagram.id} value={diagram.id}>{diagram.name}</option>)}</select>}{canEdit && currentDiagram && !editingDiagramId && <button type="button" className="rounded p-1.5 text-slate-400 hover:bg-slate-100" onClick={() => startDiagramRename(currentDiagram)} aria-label="Renombrar diagrama">✎</button>}<button type="button" disabled={!canEdit} className="rounded-md border border-slate-300 px-2 py-1 font-bold text-blue-700 hover:bg-blue-50 disabled:opacity-40" onClick={() => { setDiagramName(`Diagrama ${diagrams.length + 1}`); setDiagramDialogOpen(true); }} aria-label="Nuevo diagrama">+</button></div>
      <div className="ml-auto flex items-center gap-1"><div className="relative"><button className="rounded-md px-2 py-1.5 font-semibold hover:bg-slate-100" type="button" onClick={() => setImageMenuOpen((open) => !open)}>Imagen</button>{imageMenuOpen && <div className="absolute right-0 z-40 mt-2 w-36 rounded-lg border border-slate-200 bg-white p-1 shadow-xl"><button className="w-full rounded px-3 py-2 text-left hover:bg-slate-50" type="button" onClick={() => saveImage("png")}>PNG</button><button className="w-full rounded px-3 py-2 text-left hover:bg-slate-50" type="button" onClick={() => saveImage("svg")}>SVG</button></div>}</div><label className={`cursor-pointer rounded-md px-2 py-1.5 font-semibold hover:bg-slate-100 ${!canEdit ? "pointer-events-none opacity-40" : ""}`}>Importar<input className="hidden" type="file" accept=".xmi,.xml" onChange={previewFile}/></label><button className="rounded-md px-2 py-1.5 font-semibold hover:bg-slate-100" type="button" onClick={() => setExportOpen(true)}>Exportar</button><div className="relative"><button className={`flex items-center gap-1 rounded-md px-2 py-1 font-semibold ${collaboration.connection === "online" ? "text-emerald-700" : "text-slate-500"} hover:bg-slate-100`} type="button" onClick={() => setCollaborationOpen((open) => !open)} aria-label="Abrir colaboración"><span className="flex -space-x-1">{collaboration.presence.slice(0, 4).map((person, index) => <span key={person.user_id} className="grid h-6 w-6 place-items-center rounded-full border-2 border-white bg-blue-600 text-[9px] font-bold text-white" title={`Colaborador ${person.user_id}`}>{String(person.user_id).slice(0, 2).toUpperCase() || index + 1}</span>)}{collaboration.presence.length === 0 && <span className="grid h-6 w-6 place-items-center rounded-full bg-slate-200 text-[10px]">●</span>}</span><span className="hidden sm:inline">Personas</span>{collaboration.presence.length > 0 && <span className="text-[10px]">{collaboration.presence.length}</span>}</button>{collaborationOpen && <div className="absolute right-0 z-40 mt-2 max-h-[75vh] w-80 overflow-y-auto rounded-xl border border-slate-200 bg-white p-4 shadow-2xl"><CollaborationPanel projectId={project.id} role={project.membership_role} compact/></div>}</div></div>
    </header>
    <div className="z-20 flex h-10 shrink-0 items-center gap-2 border-b border-slate-200 bg-white px-2 text-xs">
      <button type="button" className={`rounded px-2 py-1.5 ${paletteOpen ? "bg-slate-100 font-semibold" : ""}`} onClick={() => setPaletteOpen((open) => !open)} aria-label="Mostrar u ocultar figuras">Figuras</button><button type="button" className={`rounded px-2 py-1.5 ${!activeConnector ? "bg-blue-50 font-semibold text-blue-700" : "hover:bg-slate-100"}`} onClick={() => { clickedConnection.current = null; pendingConnection.current = null; setActiveConnector(null); setStatus("Herramienta de selección activa"); }}>Cursor</button>{activeConnector ? <span className="rounded bg-blue-50 px-2 py-1 font-semibold text-blue-700">Conector: {activeConnector.label}</span> : <span className="text-slate-400">Elige una relación o flecha en la paleta</span>}<span className="ml-auto hidden text-slate-400 md:inline">Doble clic o F2 para renombrar · Escape vuelve al cursor</span><button type="button" className="rounded px-2 py-1.5 hover:bg-slate-100" onClick={() => setInspectorOpen((open) => !open)}>Formato</button>
    </div>
    <div className="relative flex min-h-0 flex-1">
      {currentDiagram && paletteOpen && <ModelingPalette umlElements={currentProfile.palette} umlRelationships={currentProfile.relationships} onAddUml={addUmlElement} onAddVisual={addVisual} activeConnector={activeConnector} onSelectConnector={(connector) => { clickedConnection.current = null; pendingConnection.current = null; setActiveConnector(connector); setStatus(`${connector.label}: arrastra o selecciona dos puntos azules`); }}/>} 
      <section className="flex min-w-0 flex-1 flex-col">
        {currentDiagram ? <div ref={canvasRef} className="min-h-0 flex-1 bg-white" onDrop={handleDrop} onDragOver={(event) => { event.preventDefault(); event.dataTransfer.dropEffect = "copy"; }}><ReactFlow nodes={renderedNodes} edges={edges} nodeTypes={nodeTypes} edgeTypes={edgeTypes} connectionMode={ConnectionMode.Loose} onInit={(instance) => { flowInstance.current = instance; }} onNodesChange={onNodesChange} onEdgesChange={onEdgesChange} onConnect={connectNodes} onDelete={handleDelete} nodesDraggable={canEdit} nodesConnectable={canEdit} deleteKeyCode={canEdit ? ["Backspace", "Delete"] : null} onSelectionChange={({ nodes: selectedNodes, edges: selectedEdges }) => { const node = selectedNodes[0] || null; const edge = selectedEdges[0] || null; setSelectedNode(node); setSelectedEdge(edge); if (node || edge) setInspectorOpen(true); }} onNodeClick={(_, node) => { setSelectedNode(node); setSelectedEdge(null); setInspectorOpen(true); collaboration.send("presence.focus", { diagram_id: selectedDiagram, element_id: node.id }); }} onEdgeClick={(_, edge) => { setSelectedEdge(edge); setSelectedNode(null); setInspectorOpen(true); }} onNodeDoubleClick={(_, node) => beginNodeRename(node)} onPaneClick={() => { clickedConnection.current = null; pendingConnection.current = null; setSelectedNode(null); setSelectedEdge(null); }} fitView><EdgeMarkerDefinitions/><MiniMap pannable zoomable/><Controls/><Background gap={20} size={1}/></ReactFlow></div> : <div className="grid flex-1 place-items-center p-8 text-center text-slate-500"><div><p className="text-lg font-semibold text-slate-700">Crea tu primer diagrama</p><button type="button" disabled={!canEdit} className="mt-3 rounded-md bg-blue-600 px-4 py-2 font-semibold text-white disabled:opacity-40" onClick={() => setDiagramDialogOpen(true)}>Nuevo diagrama</button></div></div>}
      </section>
      {inspectorOpen && (selectedNode || selectedEdge) && <FormatInspector selectedNode={selectedNode} selectedEdge={selectedEdge} nodes={nodes} editingNodeId={editingNodeId} renameDraft={renameDraft} onBeginRename={beginNodeRename} onRenameChange={setRenameDraft} onRenameCommit={commitNodeRename} onRenameCancel={cancelNodeRename} onNodeStyle={updateVisualAppearance} onClassAttributes={updateClassAttributes} onEdgeStyle={updateEdgeAppearance} canEdit={canEdit} onClose={() => setInspectorOpen(false)}/>} 
    </div>
    <footer className="flex h-7 shrink-0 items-center gap-3 border-t border-slate-200 bg-white px-3 text-[11px] text-slate-500"><span className={online ? "text-emerald-700" : "text-amber-700"}>● {online ? "En línea" : "Offline"}</span><span>Colaboración: {collaboration.connection}</span><span className="ml-auto max-w-[55vw] truncate" title={status}>{status}</span></footer>
    {diagramDialogOpen && <div className="fixed inset-0 z-50 grid place-items-center bg-slate-900/35 p-4"><form className="w-full max-w-sm rounded-xl bg-white p-5 shadow-2xl" onSubmit={createDiagram}><h2 className="text-lg font-bold">Nuevo diagrama</h2><label className="mt-4 grid gap-1 text-sm font-semibold">Nombre<input autoFocus className="rounded-md border border-slate-300 px-3 py-2 font-normal outline-none focus:border-blue-500" value={diagramName} onChange={(event) => setDiagramName(event.target.value)}/></label><label className="mt-3 grid gap-1 text-sm font-semibold">Tipo<select className="rounded-md border border-slate-300 px-3 py-2 font-normal" value={diagramType} onChange={(event) => setDiagramType(event.target.value)}>{UML_DIAGRAM_TYPES.map(([value,label]) => <option key={value} value={value}>{label}</option>)}</select></label><div className="mt-5 flex justify-end gap-2"><button type="button" className="rounded-md px-3 py-2" onClick={() => setDiagramDialogOpen(false)}>Cancelar</button><button disabled={!canEdit || !diagramName.trim()} className="rounded-md bg-blue-600 px-3 py-2 font-semibold text-white disabled:opacity-40" type="submit">Crear</button></div></form></div>}
    {importReport && <div className="fixed inset-0 z-40 grid place-items-center bg-slate-900/40 p-4"><div className="w-full max-w-lg rounded-2xl bg-white p-6 shadow-2xl"><h2 className="text-xl font-bold">Confirmar fusión</h2><p className="mt-2 text-sm text-slate-500">Se actualizarán las coincidencias dentro del proyecto actual.</p><div className="mt-5 grid grid-cols-3 gap-3 text-center"><div className="rounded-xl bg-slate-50 p-3"><strong className="block text-xl">{importReport.elements?.length || 0}</strong><span className="text-xs">elementos</span></div><div className="rounded-xl bg-slate-50 p-3"><strong className="block text-xl">{importReport.matches?.length || 0}</strong><span className="text-xs">coincidencias</span></div><div className="rounded-xl bg-amber-50 p-3"><strong className="block text-xl">{importReport.warnings?.length || 0}</strong><span className="text-xs">advertencias</span></div></div>{importReport.warnings?.length > 0 && <ul className="mt-4 max-h-32 list-disc overflow-auto pl-5 text-xs text-amber-700">{importReport.warnings.slice(0, 8).map((warning, index) => <li key={index}>{typeof warning === "string" ? warning : warning.message || warning.code}</li>)}</ul>}<div className="mt-6 flex justify-end gap-2"><button className="rounded-lg px-4 py-2" type="button" onClick={() => { setImportFile(null); setImportReport(null); }}>Cancelar</button><button className="rounded-lg bg-teal-700 px-4 py-2 font-semibold text-white" type="button" onClick={confirmImport}>Fusionar importación</button></div></div></div>}
    {exportOpen && <div className="fixed inset-0 z-40 grid place-items-center bg-slate-900/40 p-4"><div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-2xl"><h2 className="text-xl font-bold">Exportar</h2><p className="mt-2 text-sm text-slate-500">Elige el formato que necesitas.</p>{auxiliaryCount > 0 && <p className="mt-4 rounded-lg bg-amber-50 p-3 text-xs text-amber-800">Hay {auxiliaryCount} figura(s) o flecha(s) auxiliares. Se verán en PNG/SVG, pero no se exportarán como semántica UML en XMI.</p>}<div className="mt-5 grid gap-2"><button className="rounded-lg border border-slate-300 px-4 py-3 text-left font-semibold" type="button" onClick={() => saveImage("png")}>Imagen PNG</button><button className="rounded-lg border border-slate-300 px-4 py-3 text-left font-semibold" type="button" onClick={() => saveImage("svg")}>Imagen SVG</button><button className="rounded-lg border border-slate-300 px-4 py-3 text-left font-semibold" type="button" onClick={exportXmi}>Modelo UML XMI 2.5.1</button></div><button className="mt-5 w-full rounded-lg px-4 py-2 text-sm" type="button" onClick={() => setExportOpen(false)}>Cancelar</button></div></div>}
  </main>;
}
