import Dexie from "dexie";

export const offlineDb = new Dexie("uml-modeler-offline");

offlineDb.version(1).stores({
  projects: "[userId+projectId], userId, projectId, updatedAt",
  snapshots: "[userId+projectId], userId, projectId, revision",
  operations: "[userId+projectId+operationId], userId, projectId, operationId, status",
  conflicts: "[userId+projectId+conflictId], userId, projectId, conflictId",
  promptDrafts: "[userId+projectId], userId, projectId, updatedAt",
});

offlineDb.version(2).stores({
  projects: "[userId+projectId], userId, projectId, updatedAt, offlineEnabled",
  snapshots: "[userId+projectId], userId, projectId, revision",
  operations: "[userId+projectId+operationId], userId, projectId, operationId, status",
  conflicts: "[userId+projectId+conflictId], userId, projectId, conflictId",
  promptDrafts: "[userId+projectId], userId, projectId, updatedAt",
});

function runStorage(operation) {
  return operation().catch((cause) => {
    if (cause?.name === "QuotaExceededError" || cause?.code === "QuotaExceededError") {
      const error = new Error("El almacenamiento offline está lleno. Libera espacio e inténtalo de nuevo.");
      error.code = "offline_storage_full";
      error.cause = cause;
      throw error;
    }
    throw cause;
  });
}

export async function clearUserOfflineData(userId) {
  await Promise.all([
    offlineDb.projects.where("userId").equals(String(userId)).delete(),
    offlineDb.snapshots.where("userId").equals(String(userId)).delete(),
    offlineDb.operations.where("userId").equals(String(userId)).delete(),
    offlineDb.conflicts.where("userId").equals(String(userId)).delete(),
    offlineDb.promptDrafts.where("userId").equals(String(userId)).delete(),
  ]);
}

export async function queueOperation(operation) {
  return runStorage(() => offlineDb.operations.put({ ...operation, status: "pending", queuedAt: Date.now() }));
}

export async function cacheProject(userId, project, options = {}) {
  const normalizedUserId = String(userId);
  const projectId = String(project.id);
  const previous = await offlineDb.projects.get([normalizedUserId, projectId]);
  const offlineEnabled = options.offlineEnabled ?? previous?.offlineEnabled ?? false;
  return runStorage(() => offlineDb.projects.put({ userId: normalizedUserId, projectId, project, offlineEnabled, updatedAt: Date.now() }));
}

export async function getCachedProject(userId, projectId) {
  const item = await offlineDb.projects.get([String(userId), String(projectId)]);
  return item?.project || null;
}

export async function listCachedProjects(userId) {
  const items = await offlineDb.projects.where("userId").equals(String(userId)).toArray();
  return items.sort((a, b) => (b.updatedAt || 0) - (a.updatedAt || 0)).map((item) => item.project);
}

export async function listCachedProjectRecords(userId) {
  const items = await offlineDb.projects.where("userId").equals(String(userId)).toArray();
  return items.sort((a, b) => (b.updatedAt || 0) - (a.updatedAt || 0));
}

export async function setProjectOffline(userId, projectId, enabled) {
  const key = [String(userId), String(projectId)];
  const item = await offlineDb.projects.get(key);
  if (!item) throw new Error("Primero abre el proyecto en línea para preparar su copia offline.");
  return runStorage(() => offlineDb.projects.put({ ...item, offlineEnabled: Boolean(enabled), updatedAt: Date.now() }));
}

export async function isProjectOffline(userId, projectId) {
  const item = await offlineDb.projects.get([String(userId), String(projectId)]);
  return Boolean(item?.offlineEnabled);
}

export async function cacheSnapshot(userId, projectId, snapshot) {
  return runStorage(() => offlineDb.snapshots.put({ userId: String(userId), projectId: String(projectId), revision: snapshot.revision, snapshot, updatedAt: Date.now() }));
}

export async function getCachedSnapshot(userId, projectId) {
  const item = await offlineDb.snapshots.get([String(userId), String(projectId)]);
  return item?.snapshot || null;
}

export async function getPendingOperations(userId, projectId) {
  return offlineDb.operations.where({ userId: String(userId), projectId: String(projectId), status: "pending" }).sortBy("queuedAt");
}

export async function getRecoveryOperations(userId, projectId) {
  return offlineDb.operations.where({ userId: String(userId), projectId: String(projectId) }).filter((item) => ["pending", "conflict", "requires_reauth", "permission_revoked"].includes(item.status)).sortBy("queuedAt");
}

export async function markOperation(userId, projectId, operationId, status, extra = {}) {
  return offlineDb.operations.update([String(userId), String(projectId), String(operationId)], { status, ...extra });
}

export async function saveOfflineConflict(userId, projectId, conflict) {
  return runStorage(() => offlineDb.conflicts.put({ userId: String(userId), projectId: String(projectId), conflictId: String(conflict.conflictId), ...conflict, updatedAt: Date.now() }));
}

export async function getOfflineConflicts(userId, projectId) {
  return offlineDb.conflicts.where({ userId: String(userId), projectId: String(projectId) }).sortBy("updatedAt");
}

export async function deleteOfflineConflict(userId, projectId, conflictId) {
  return offlineDb.conflicts.delete([String(userId), String(projectId), String(conflictId)]);
}

export async function savePromptDraft(userId, projectId, prompt) {
  return runStorage(() => offlineDb.promptDrafts.put({ userId: String(userId), projectId: String(projectId), prompt, updatedAt: Date.now() }));
}

export async function readPromptDraft(userId, projectId) {
  const draft = await offlineDb.promptDrafts.get([String(userId), String(projectId)]);
  return draft?.prompt || "";
}

export async function exportRecoveryFile(userId, projectId) {
  const operations = await getRecoveryOperations(userId, projectId);
  const payload = JSON.stringify({ project_id: String(projectId), exported_at: new Date().toISOString(), operations }, null, 2);
  return new Blob([payload], { type: "application/json" });
}
