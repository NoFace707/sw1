import { requestJsonWithAuthRetry } from "../../services/apiClient.js";

export function createAiProposal(projectId, payload) {
  return requestJsonWithAuthRetry(`/api/modeling/projects/${projectId}/ai/proposals/`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
}

export function applyAiProposal(projectId, proposalId, operationIds) {
  return requestJsonWithAuthRetry(`/api/modeling/projects/${projectId}/ai/proposals/${proposalId}/apply/`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ operation_ids: operationIds }),
  });
}

export function explainWithAi(projectId, payload) {
  return requestJsonWithAuthRetry(`/api/modeling/projects/${projectId}/ai/explain/`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
}
