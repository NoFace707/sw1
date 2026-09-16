import { requestJsonWithAuthRetry } from "../../services/apiClient.js";
import { cacheProject, cacheSnapshot, getPendingOperations, markOperation, saveOfflineConflict } from "./offlineDb.js";

export async function syncProject({ userId, projectId }) {
  const [project, packages, elements, relationships, diagrams] = await Promise.all([
    requestJsonWithAuthRetry(`/api/modeling/projects/${projectId}/`),
    requestJsonWithAuthRetry(`/api/modeling/projects/${projectId}/packages/`),
    requestJsonWithAuthRetry(`/api/modeling/projects/${projectId}/elements/`),
    requestJsonWithAuthRetry(`/api/modeling/projects/${projectId}/relationships/`),
    requestJsonWithAuthRetry(`/api/modeling/projects/${projectId}/diagrams/`),
  ]);
  await cacheProject(userId, project);
  const pending = await getPendingOperations(userId, projectId);
  let currentRevision = project.revision;
  for (const item of pending) {
    try {
      const payload = { operation_id: item.operationId, entity_type: item.entityType, entity_id: item.entityId, action: item.action, path: item.path || "", base_revision: item.baseRevision ?? currentRevision, previous_value: item.previousValue, new_value: item.newValue };
      let response;
      let lastError;
      for (let attempt = 0; attempt < 3; attempt += 1) {
        try { response = await requestJsonWithAuthRetry(`/api/modeling/projects/${projectId}/operations/`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload) }); break; }
        catch (error) { lastError = error; if (attempt < 2) await new Promise((resolve) => setTimeout(resolve, 250 * (attempt + 1))); }
      }
      if (!response) throw lastError;
      if (Number.isFinite(Number(response.server_revision))) currentRevision = Number(response.server_revision);
      await markOperation(userId, projectId, item.operationId, "synced", { syncedAt: Date.now() });
    } catch (error) {
      const status = error?.status === 401 ? "requires_reauth" : error?.status === 403 ? "permission_revoked" : "conflict";
      if (status === "conflict") {
        await saveOfflineConflict(userId, projectId, { conflictId: item.operationId, operationId: item.operationId, entityType: item.entityType, entityId: item.entityId, path: item.path || "", rejectedValue: item.newValue, detail: error?.detail || "La operación entra en conflicto con cambios remotos." });
      }
      if (error?.detail || error?.code || error?.status) await markOperation(userId, projectId, item.operationId, status, { error, failedAt: Date.now() });
      throw error;
    }
  }
  const diagramViews = await Promise.all((diagrams || []).map(async (diagram) => {
    const [diagramNodes, diagramEdges] = await Promise.all([
      requestJsonWithAuthRetry(`/api/modeling/projects/${projectId}/diagrams/${diagram.id}/nodes/`),
      requestJsonWithAuthRetry(`/api/modeling/projects/${projectId}/diagrams/${diagram.id}/edges/`),
    ]);
    return { diagramId: diagram.id, nodes: diagramNodes, edges: diagramEdges };
  }));
  const operations = await requestJsonWithAuthRetry(`/api/modeling/projects/${projectId}/operations/?after_revision=${currentRevision}`);
  const snapshot = {
    revision: operations.revision,
    payload: {
      project,
      packages,
      elements,
      relationships,
      diagrams,
      diagramNodes: diagramViews.flatMap((item) => item.nodes),
      diagramEdges: diagramViews.flatMap((item) => item.edges),
      operations: operations.operations,
    },
  };
  await cacheSnapshot(userId, projectId, snapshot);
  return { project, operations: operations.operations, revision: operations.revision };
}
