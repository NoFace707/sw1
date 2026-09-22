import { requestJsonWithAuthRetry } from "../../services/apiClient.js";

export function listProjects() {
  return requestJsonWithAuthRetry("/api/modeling/projects/");
}

export function createProject(payload) {
  return requestJsonWithAuthRetry("/api/modeling/projects/", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
}

export function getProject(projectId) {
  return requestJsonWithAuthRetry(`/api/modeling/projects/${projectId}/`);
}

export function deleteProject(projectId) {
  return requestJsonWithAuthRetry(`/api/modeling/projects/${projectId}/`, { method: "DELETE" });
}

export function restoreSnapshot(projectId, snapshotId) {
  return requestJsonWithAuthRetry(`/api/modeling/projects/${projectId}/snapshots/${snapshotId}/restore/`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({}) });
}

export function joinProject(code) {
  return requestJsonWithAuthRetry("/api/modeling/projects/join/", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ code }),
  });
}

export function importProjectFile(projectId, file, profile = "omg-xmi-2.5.1", mode = "copy", targetDiagramId = null) {
  const form = new FormData();
  form.append("file", file);
  form.append("profile", profile);
  form.append("mode", mode);
  if (targetDiagramId) form.append("target_diagram_id", targetDiagramId);
  return requestJsonWithAuthRetry(`/api/modeling/projects/${projectId}/interchange/import/`, { method: "POST", body: form });
}

export function importNewProject(file, profile = "omg-xmi-2.5.1") {
  const form = new FormData();
  form.append("file", file);
  form.append("profile", profile);
  return requestJsonWithAuthRetry("/api/modeling/projects/import/", { method: "POST", body: form });
}
