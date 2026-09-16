import { getApiBaseUrl, requestJsonWithAuthRetry } from "../../services/apiClient.js";

export function createInvite(projectId, payload) {
  return requestJsonWithAuthRetry(`/api/modeling/projects/${projectId}/invites/create/`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
}

export function listInvites(projectId) {
  return requestJsonWithAuthRetry(`/api/modeling/projects/${projectId}/invites/`);
}

export function joinWithInvite(code) {
  return requestJsonWithAuthRetry("/api/modeling/projects/join/", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ code }),
  });
}

export function getProjectWebsocketTicket(projectId) {
  return requestJsonWithAuthRetry(`/api/modeling/projects/${projectId}/sync/ticket/`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({}),
  });
}

export function listProjectOperations(projectId, afterRevision = 0) {
  return requestJsonWithAuthRetry(`/api/modeling/projects/${projectId}/operations/?after_revision=${encodeURIComponent(afterRevision)}`);
}

export function projectWebsocketUrl(projectId, ticket) {
  const apiUrl = new URL(getApiBaseUrl());
  apiUrl.protocol = apiUrl.protocol === "https:" ? "wss:" : "ws:";
  apiUrl.pathname = `/ws/projects/${projectId}/`;
  apiUrl.search = `?ticket=${encodeURIComponent(ticket)}`;
  return apiUrl.toString();
}

export function listMembers(projectId) {
  return requestJsonWithAuthRetry(`/api/modeling/projects/${projectId}/members/`);
}

export function updateMember(projectId, memberId, role) {
  return requestJsonWithAuthRetry(`/api/modeling/projects/${projectId}/members/${memberId}/`, { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ role }) });
}

export function removeMember(projectId, memberId) {
  return requestJsonWithAuthRetry(`/api/modeling/projects/${projectId}/members/${memberId}/`, { method: "DELETE" });
}

export function revokeInvite(projectId, inviteId) {
  return requestJsonWithAuthRetry(`/api/modeling/projects/${projectId}/invites/${inviteId}/revoke/`, { method: "POST" });
}

export function resolveConflict(projectId, conflictId, value) {
  return requestJsonWithAuthRetry(`/api/modeling/projects/${projectId}/conflicts/${conflictId}/resolve/`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ value }) });
}
