import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { createProject, importNewProject, joinProject, listProjects } from "../domains/projects/projectsApi.js";
import { useOnlineStatus } from "../domains/sync/useOnlineStatus.js";
import { cacheProject, listCachedProjectRecords, setProjectOffline } from "../domains/sync/offlineDb.js";

function errorMessage(cause, fallback) {
  if (typeof cause?.detail === "string") return cause.detail;
  if (Array.isArray(cause?.errors) && cause.errors.length) return cause.errors[0];
  return fallback;
}

export default function HomePage() {
  const navigate = useNavigate();
  const { user, logout } = useAuth();
  const online = useOnlineStatus();
  const [projects, setProjects] = useState(null);
  const [offlineProjects, setOfflineProjects] = useState(() => new Set());
  const [error, setError] = useState("");
  const [dialog, setDialog] = useState(null);
  const [code, setCode] = useState("");
  const [importFile, setImportFile] = useState(null);
  const [busy, setBusy] = useState(false);

  async function loadProjects() {
    try {
      const loaded = await listProjects();
      setProjects(loaded);
      await Promise.all(loaded.map((item) => cacheProject(user?.id || "session", item)));
      const records = await listCachedProjectRecords(user?.id || "session");
      setOfflineProjects(new Set(records.filter((item) => item.offlineEnabled).map((item) => item.projectId)));
      setError("");
    } catch (cause) {
      const records = await listCachedProjectRecords(user?.id || "session").catch(() => []);
      setProjects(records.map((item) => item.project));
      setOfflineProjects(new Set(records.filter((item) => item.offlineEnabled).map((item) => item.projectId)));
      setError(records.length ? "Sin conexión: mostrando proyectos guardados." : errorMessage(cause, "No se pudieron cargar tus proyectos."));
    }
  }

  useEffect(() => { loadProjects(); }, [user?.id, online]);

  async function handleCreate() {
    if (busy) return;
    try {
      setBusy(true); setError("");
      const created = await createProject({ name: "Proyecto sin título", description: "", mda_level: "UNSPECIFIED", create_initial_diagram: true });
      navigate(`/projects/${created.id}`);
    } catch (cause) { setError(errorMessage(cause, "No se pudo crear el proyecto.")); }
    finally { setBusy(false); }
  }

  async function handleJoin(event) {
    event.preventDefault();
    if (busy || !code.trim()) return;
    try { setBusy(true); setError(""); const joined = await joinProject(code.trim()); navigate(`/projects/${joined.id}`); }
    catch (cause) { setError(errorMessage(cause, "El código no es válido o ya no está disponible.")); }
    finally { setBusy(false); }
  }

  async function handleImport(event) {
    event.preventDefault();
    if (busy || !importFile) return;
    try { setBusy(true); setError(""); const result = await importNewProject(importFile); navigate(`/projects/${result.project.id}`); }
    catch (cause) { setError(errorMessage(cause, "No se pudo importar el archivo XMI.")); }
    finally { setBusy(false); }
  }

  async function toggleOffline(item) {
    if (!online) { setError("Conéctate para preparar o retirar una copia offline."); return; }
    const enabled = !offlineProjects.has(String(item.id));
    try {
      await setProjectOffline(user?.id || "session", item.id, enabled);
      setOfflineProjects((current) => { const next = new Set(current); if (enabled) next.add(String(item.id)); else next.delete(String(item.id)); return next; });
      setError(enabled ? `«${item.name}» estará disponible sin conexión.` : `Se deshabilitó la apertura offline de «${item.name}».`);
    } catch (cause) { setError(cause?.message || "No se pudo actualizar la disponibilidad offline."); }
  }

  async function handleLogout() { await logout(); navigate("/login", { replace: true }); }

  return <main className="min-h-screen bg-slate-50 text-slate-800">
    <header className="border-b border-slate-200 bg-white"><div className="mx-auto flex max-w-7xl items-center justify-between px-6 py-4"><div><p className="text-xs font-semibold uppercase tracking-[0.25em] text-teal-700">Modelador UML</p><h1 className="mt-1 text-xl font-bold text-slate-900">Mis proyectos</h1></div><div className="flex items-center gap-3 text-sm"><span className={`rounded-full px-3 py-1 ${online ? "bg-emerald-50 text-emerald-700" : "bg-amber-50 text-amber-700"}`}>{online ? "En línea" : "Sin conexión"}</span><span className="hidden text-slate-500 sm:inline">{user?.email}</span><button className="rounded-lg border border-slate-300 px-3 py-2 font-semibold" type="button" onClick={handleLogout}>Salir</button></div></div></header>
    <section className="mx-auto max-w-7xl px-6 py-8">
      <div className="flex flex-wrap items-end justify-between gap-4"><div><p className="text-sm text-slate-500">Espacio de trabajo</p><h2 className="mt-1 text-3xl font-bold text-slate-900">Construye tus modelos UML</h2></div><div className="flex flex-wrap gap-2"><button className="rounded-xl bg-teal-700 px-4 py-2.5 font-semibold text-white disabled:opacity-50" type="button" disabled={busy || !online} onClick={handleCreate}>{busy ? "Creando…" : "Nuevo proyecto"}</button><button className="rounded-xl border border-slate-300 bg-white px-4 py-2.5 font-semibold" type="button" onClick={() => { setDialog("join"); setError(""); }}>Unirse con código</button><button className="rounded-xl border border-slate-300 bg-white px-4 py-2.5 font-semibold" type="button" onClick={() => { setDialog("import"); setError(""); }}>Importar</button></div></div>
      {error && !dialog && <p className="mt-6 rounded-xl bg-rose-50 px-4 py-3 text-sm text-rose-700" role="alert">{error}</p>}
      {projects === null ? <div className="mt-10 rounded-2xl border border-dashed border-slate-300 bg-white p-10 text-center text-slate-500">Cargando proyectos…</div> : projects.length === 0 ? <div className="mt-10 rounded-2xl border border-dashed border-slate-300 bg-white p-12 text-center"><p className="text-lg font-semibold">Todavía no participas en ningún proyecto</p><p className="mt-2 text-sm text-slate-500">Crea un modelo nuevo, importa XMI o usa un código de invitación.</p></div> : <div className="mt-8 grid gap-4 md:grid-cols-2 xl:grid-cols-3">{projects.map((item) => <article key={item.id} className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm transition hover:border-teal-300 hover:shadow-md"><button type="button" onClick={() => navigate(`/projects/${item.id}`)} className="block w-full text-left"><h3 className="text-lg font-bold text-slate-900">{item.name}</h3><p className="mt-3 line-clamp-2 min-h-10 text-sm text-slate-500">{item.description || "Sin descripción todavía."}</p><div className="mt-5 flex justify-between text-xs text-slate-400"><span>{item.membership_role}</span><span>Revisión {item.revision}</span></div></button><button type="button" onClick={() => toggleOffline(item)} className={`mt-4 w-full rounded-lg border px-3 py-2 text-xs font-semibold ${offlineProjects.has(String(item.id)) ? "border-emerald-300 text-emerald-700" : "border-slate-300 text-slate-600"}`}>{offlineProjects.has(String(item.id)) ? "Disponible offline" : "Preparar para offline"}</button></article>)}</div>}
    </section>
    {dialog === "join" && <div className="fixed inset-0 z-20 grid place-items-center bg-slate-900/30 p-4"><form onSubmit={handleJoin} className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl"><h2 className="text-xl font-bold">Unirse a un proyecto</h2><p className="mt-2 text-sm text-slate-500">Introduce el código completo que compartió el propietario.</p><label className="mt-5 block text-sm font-semibold">Código<input className="mt-2 w-full rounded-lg border border-slate-300 px-3 py-2" value={code} onChange={(event) => setCode(event.target.value)} autoFocus /></label>{error && <p className="mt-3 rounded-lg bg-rose-50 p-3 text-sm text-rose-700" role="alert">{error}</p>}<div className="mt-6 flex justify-end gap-2"><button className="rounded-lg px-4 py-2" type="button" onClick={() => setDialog(null)}>Cancelar</button><button className="rounded-lg bg-teal-700 px-4 py-2 font-semibold text-white disabled:opacity-50" type="submit" disabled={busy || !code.trim()}>{busy ? "Uniendo…" : "Unirse"}</button></div></form></div>}
    {dialog === "import" && <div className="fixed inset-0 z-20 grid place-items-center bg-slate-900/30 p-4"><form onSubmit={handleImport} className="w-full max-w-lg rounded-2xl bg-white p-6 shadow-xl"><h2 className="text-xl font-bold">Importar modelo</h2><p className="mt-2 text-sm text-slate-500">El archivo OMG XMI 2.5.1 se valida antes de crear el proyecto; si falla no quedará un proyecto vacío.</p><label className="mt-5 block text-sm font-semibold">Archivo XMI<input className="mt-2 block w-full rounded-lg border border-slate-300 px-3 py-2" type="file" accept=".xmi,.xml" onChange={(event) => setImportFile(event.target.files?.[0] || null)} required /></label>{error && <p className="mt-3 rounded-lg bg-rose-50 p-3 text-sm text-rose-700" role="alert">{error}</p>}<div className="mt-6 flex justify-end gap-2"><button className="rounded-lg px-4 py-2" type="button" onClick={() => setDialog(null)}>Cancelar</button><button className="rounded-lg bg-teal-700 px-4 py-2 font-semibold text-white disabled:opacity-50" type="submit" disabled={busy || !importFile}>{busy ? "Importando…" : "Importar"}</button></div></form></div>}
  </main>;
}
