import { useEffect, useMemo, useState } from "react";
import { createInvite, listInvites, listMembers, removeMember, revokeInvite, updateMember } from "./collaborationApi.js";
import { useOnlineStatus } from "../sync/useOnlineStatus.js";

function inviteStatus(invitation) {
  if (invitation.revoked_at) return { label: "Revocada", className: "text-rose-700" };
  if (new Date(invitation.expires_at).getTime() <= Date.now()) return { label: "Vencida", className: "text-amber-700" };
  if (invitation.uses_count >= invitation.max_uses) return { label: "Agotada", className: "text-amber-700" };
  return { label: "Vigente", className: "text-emerald-700" };
}

export default function CollaborationPanel({ projectId, role, compact = false }) {
  const online = useOnlineStatus();
  const [members, setMembers] = useState([]);
  const [invite, setInvite] = useState(null);
  const [invites, setInvites] = useState([]);
  const [inviteRole, setInviteRole] = useState("editor");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [copied, setCopied] = useState(false);
  const canManage = role === "owner";
  const activeInvites = useMemo(() => invites.slice(0, 5), [invites]);

  async function refresh() {
    if (!online) { setError("Colaboración e invitaciones requieren conexión."); return; }
    try {
      setMembers(await listMembers(projectId));
      if (canManage) setInvites(await listInvites(projectId));
      setError("");
    } catch (cause) { setError(cause?.detail || "No se pudieron cargar los miembros."); }
  }

  useEffect(() => { refresh(); }, [projectId, online, canManage]);

  async function generateInvite() {
    if (!online || busy) { if (!online) setError("No se puede generar un código sin conexión."); return; }
    try {
      setBusy(true); setCopied(false); setError("");
      const created = await createInvite(projectId, { role: inviteRole, max_uses: 10, expires_hours: 72 });
      setInvite(created);
      setInvites((current) => [created, ...current]);
    } catch (cause) { setError(cause?.detail || "No se pudo generar la invitación."); }
    finally { setBusy(false); }
  }

  async function copyInvite() {
    if (!invite?.code) return;
    try { await navigator.clipboard.writeText(invite.code); setCopied(true); }
    catch { setError("No se pudo copiar automáticamente. Selecciona el código y cópialo manualmente."); }
  }

  async function changeRole(member, nextRole) {
    try { const updated = await updateMember(projectId, member.id, nextRole); setMembers((current) => current.map((item) => item.id === updated.id ? updated : item)); }
    catch (cause) { setError(cause?.detail || "No se pudo cambiar el rol."); }
  }

  async function remove(member) {
    try { await removeMember(projectId, member.id); setMembers((current) => current.filter((item) => item.id !== member.id)); }
    catch (cause) { setError(cause?.detail || "No se pudo retirar el miembro."); }
  }

  async function revoke(invitation) {
    try { const updated = await revokeInvite(projectId, invitation.id); setInvites((current) => current.map((item) => item.id === updated.id ? updated : item)); }
    catch (cause) { setError(cause?.detail || "No se pudo revocar el código."); }
  }

  return <section className={compact ? "" : "mt-5 border-t border-slate-200 pt-4"}>
    <div className="flex items-center justify-between">
      <h2 className="text-xs font-bold uppercase tracking-widest text-slate-500">Colaboración</h2>
      {canManage && <button type="button" disabled={busy} className="text-xs font-semibold text-teal-700 disabled:opacity-50" onClick={generateInvite}>{busy ? "Generando…" : "Generar código"}</button>}
    </div>
    {error && <p className="mt-2 text-xs text-rose-700" role="alert">{error}</p>}
    {invite && <div className="mt-3 rounded-lg border border-teal-200 bg-teal-50 p-3 text-xs">
      <p className="font-semibold text-teal-900">Código secreto nuevo</p>
      <code className="mt-2 block select-all break-all rounded bg-white p-2 text-slate-800">{invite.code}</code>
      <p className="mt-2 text-amber-800">Cópialo ahora: por seguridad, después solo se mostrará su prefijo.</p>
      <button type="button" className="mt-2 font-semibold text-teal-700 underline" onClick={copyInvite}>{copied ? "Copiado" : "Copiar código completo"}</button>
    </div>}
    <div className="mt-3 space-y-2">{members.map((member) => <div className="flex items-center justify-between gap-2 text-xs" key={member.id}>
      <span className="truncate">{member.user?.email || member.user?.first_name || "Usuario"}</span>
      {canManage && member.role !== "owner" ? <span className="flex items-center gap-1"><select className="rounded border border-slate-300 px-1 py-1" value={member.role} onChange={(event) => changeRole(member, event.target.value)}><option value="editor">Editor</option><option value="viewer">Lector</option></select><button type="button" aria-label={`Retirar a ${member.user?.email || "miembro"}`} className="text-rose-700" onClick={() => remove(member)}>×</button></span> : <span className="text-slate-500">{member.role}</span>}
    </div>)}</div>
    {canManage && <>
      <select className="mt-3 w-full rounded border border-slate-300 px-2 py-1 text-xs" value={inviteRole} onChange={(event) => setInviteRole(event.target.value)} aria-label="Rol de invitación"><option value="editor">Invitar como editor</option><option value="viewer">Invitar como lector</option></select>
      <div className="mt-3 space-y-2">{activeInvites.map((item) => { const status = inviteStatus(item); return <div className="rounded border border-slate-200 p-2 text-xs" key={item.id}><div className="flex items-center justify-between gap-2"><span className="font-mono">{item.code_hint}…</span><span className={status.className}>{status.label}</span></div><p className="mt-1 text-slate-500">{item.uses_count}/{item.max_uses} usos · {item.role}</p>{status.label === "Vigente" && <button type="button" className="mt-1 text-rose-700 underline" onClick={() => revoke(item)}>Revocar</button>}</div>; })}</div>
    </>}
  </section>;
}
