import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { requestJsonWithAuthRetry } from "../services/apiClient.js";
import EditorShell from "../domains/modeling/EditorShell.jsx";
import { useAuth } from "../context/AuthContext.jsx";
import { cacheProject, getCachedProject, isProjectOffline } from "../domains/sync/offlineDb.js";
import { syncProject } from "../domains/sync/syncService.js";
import { useOnlineStatus } from "../domains/sync/useOnlineStatus.js";

export default function ModelerPage() {
  const { projectId } = useParams();
  const navigate = useNavigate();
  const { user } = useAuth();
  const online = useOnlineStatus();
  const [project, setProject] = useState(null);
  const [error, setError] = useState("");
  useEffect(() => {
    let cancelled = false;
    async function openProject() {
      try {
        if (online) {
          const loaded = await requestJsonWithAuthRetry(`/api/modeling/projects/${projectId}/`);
          if (!cancelled) { setProject(loaded); setError(""); await cacheProject(user?.id || "session", loaded); }
          try { await syncProject({ userId: user?.id || "session", projectId }); } catch { /* La cola queda local para reintentar. */ }
        } else {
          if (project) return;
          if (!(await isProjectOffline(user?.id || "session", projectId))) throw { detail: "Este proyecto no está preparado para abrirse offline. Vuelve a conectarte y pulsa «Preparar para offline»." };
          const cached = await getCachedProject(user?.id || "session", projectId);
          if (!cached) throw { detail: "Este proyecto todavía no está disponible offline." };
          if (!cancelled) { setProject(cached); setError(""); }
        }
      } catch (cause) { if (!cancelled) setError(cause?.detail || "No se pudo abrir el proyecto."); }
    }
    openProject();
    return () => { cancelled = true; };
  }, [projectId, online, user?.id]);
  if (error) return <main className="grid min-h-screen place-items-center bg-slate-50 p-6"><div className="rounded-2xl bg-white p-8 text-center shadow-sm"><p className="text-rose-700">{error}</p><button className="mt-5 rounded-lg bg-teal-700 px-4 py-2 font-semibold text-white" type="button" onClick={() => navigate("/")}>Volver a proyectos</button></div></main>;
  if (!project) return <main className="grid min-h-screen place-items-center bg-slate-50 text-slate-500">Abriendo modelo…</main>;
  return <EditorShell project={project} userId={user?.id || "session"} onProjectChange={setProject} onBack={() => navigate("/")} />;
}
