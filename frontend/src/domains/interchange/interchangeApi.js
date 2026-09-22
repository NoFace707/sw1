import { requestJsonWithAuthRetry, requestWithAuthRetry } from "../../services/apiClient.js";

const enableEnterpriseArchitect = String(import.meta.env?.VITE_ENABLE_EA_INTERCHANGE || "").toLowerCase() === "true";

export const interchangeProfiles = [
  { id: "omg-xmi-2.5.1", label: "OMG XMI 2.5.1", description: "Perfil normativo UML 2.5.1 con UMLDI representable.", limitations: "Las extensiones propietarias de Sparx no se incluyen; las vistas sin UMLDI pueden recibir disposición automática." },
  ...(enableEnterpriseArchitect ? [{ id: "sparx-ea-xmi-2.1", label: "Sparx Enterprise Architect (XMI 2.1)", description: "Perfil experimental de intercambio para Enterprise Architect 17.2.", limitations: "Permanece experimental hasta completar la aceptación real en Enterprise Architect." }] : []),
];

export function getInterchangeReport(projectId, profile) {
  return requestJsonWithAuthRetry(`/api/modeling/projects/${projectId}/interchange/report/?profile=${encodeURIComponent(profile)}`);
}

export async function downloadInterchange(projectId, profile) {
  const response = await requestWithAuthRetry(`/api/modeling/projects/${projectId}/interchange/export/?profile=${encodeURIComponent(profile)}`);
  if (!response.ok) throw await response.json();
  return response.blob();
}

export function previewInterchange(projectId, file, profile, mode = "update", targetDiagramId = null) {
  const form = new FormData();
  form.append("file", file);
  form.append("profile", profile);
  form.append("preview", "true");
  form.append("mode", mode);
  if (targetDiagramId) form.append("target_diagram_id", targetDiagramId);
  return requestJsonWithAuthRetry(`/api/modeling/projects/${projectId}/interchange/import/`, { method: "POST", body: form });
}
