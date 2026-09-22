import { useEffect, useMemo, useRef, useState } from "react";
import { applyAiProposal, createAiProposal, transcribeAiAudio } from "./aiService.js";

function errorMessage(error, fallback) {
  if (typeof error?.detail === "string") return error.detail;
  if (typeof error?.message === "string") return error.message;
  const findMessage = (value) => {
    if (typeof value === "string") return value;
    if (Array.isArray(value)) return value.map(findMessage).find(Boolean);
    if (value && typeof value === "object") return Object.values(value).map(findMessage).find(Boolean);
    return "";
  };
  return findMessage(error) || fallback;
}

function operationTitle(operation) {
  const actions = { create: "Crear", update: "Editar", delete: "Eliminar" };
  return `${actions[operation.action] || operation.action} ${operation.entity_type}`;
}

function compactConversation(messages, nextText) {
  const transcript = [...messages, { role: "user", text: nextText }]
    .slice(-8)
    .map((message) => `${message.role === "user" ? "Usuario" : "Asistente"}: ${message.text}`)
    .join("\n");
  return transcript.length > 3800 ? transcript.slice(-3800) : transcript;
}

export default function AiAssistantPanel({
  projectId,
  diagramId,
  selectedElementIds = [],
  canApply,
  onApplied,
  onClose,
}) {
  const [messages, setMessages] = useState([
    {
      role: "assistant",
      text: "Describe el cambio UML. Prepararé una propuesta; nada se aplicará sin tu aprobación.",
    },
  ]);
  const [input, setInput] = useState("");
  const [proposal, setProposal] = useState(null);
  const [selected, setSelected] = useState(new Set());
  const [requesting, setRequesting] = useState(false);
  const [applying, setApplying] = useState(false);
  const [recording, setRecording] = useState(false);
  const [transcribing, setTranscribing] = useState(false);
  const [error, setError] = useState("");
  const recorderRef = useRef(null);
  const streamRef = useRef(null);
  const chunksRef = useRef([]);
  const recordingTimerRef = useRef(null);
  const mountedRef = useRef(true);

  useEffect(() => {
    mountedRef.current = true;
    return () => {
      mountedRef.current = false;
      clearTimeout(recordingTimerRef.current);
      if (recorderRef.current?.state === "recording") {
        recorderRef.current.onstop = null;
        recorderRef.current.stop();
      }
      streamRef.current?.getTracks().forEach((track) => track.stop());
    };
  }, []);

  const operationById = useMemo(
    () => new Map((proposal?.proposal?.operations || []).map((operation) => [String(operation.id), operation])),
    [proposal],
  );

  async function send(event) {
    event.preventDefault();
    const text = input.trim();
    if (!text || requesting || applying) return;
    const userMessage = { role: "user", text };
    setMessages((current) => [...current, userMessage]);
    setInput("");
    setProposal(null);
    setSelected(new Set());
    setError("");
    setRequesting(true);
    try {
      const result = await createAiProposal(projectId, {
        prompt: compactConversation(messages, text),
        diagram_id: diagramId || undefined,
        selection: selectedElementIds,
      });
      const operations = result?.proposal?.operations || [];
      setProposal(result);
      setSelected(new Set(operations.map((operation) => String(operation.id))));
      const questions = result?.proposal?.questions || [];
      setMessages((current) => [
        ...current,
        {
          role: "assistant",
          text: questions.length
            ? `Necesito aclarar:\n${questions.map((question) => `• ${question}`).join("\n")}`
            : operations.length
              ? `Preparé ${operations.length} cambio(s). Revísalos antes de confirmar.`
              : "No encontré cambios seguros. Precisa la solicitud o revisa las advertencias.",
        },
      ]);
    } catch (cause) {
      setError(errorMessage(cause, "No se pudo consultar la IA."));
    } finally {
      setRequesting(false);
    }
  }

  function toggleOperation(operation, checked) {
    setSelected((current) => {
      const next = new Set(current);
      if (checked) {
        const include = (id) => {
          const dependency = operationById.get(String(id));
          if (!dependency || next.has(String(id))) return;
          next.add(String(id));
          (dependency.depends_on || []).forEach(include);
        };
        include(operation.id);
      } else {
        next.delete(String(operation.id));
        let changed = true;
        while (changed) {
          changed = false;
          for (const candidate of operationById.values()) {
            if (next.has(String(candidate.id)) && (candidate.depends_on || []).some((id) => !next.has(String(id)))) {
              next.delete(String(candidate.id));
              changed = true;
            }
          }
        }
      }
      return next;
    });
  }

  async function confirm() {
    if (!proposal?.id || selected.size === 0 || !canApply || applying) return;
    setApplying(true);
    setError("");
    try {
      const result = await applyAiProposal(projectId, proposal.id, [...selected]);
      setMessages((current) => [
        ...current,
        { role: "assistant", text: `Se aplicaron ${result.operations?.length || 0} cambio(s) aprobados.` },
      ]);
      setProposal(null);
      setSelected(new Set());
      await onApplied?.(result);
    } catch (cause) {
      setError(errorMessage(cause, "No se pudo aplicar la propuesta."));
    } finally {
      setApplying(false);
    }
  }

  function releaseMicrophone() {
    clearTimeout(recordingTimerRef.current);
    recordingTimerRef.current = null;
    streamRef.current?.getTracks().forEach((track) => track.stop());
    streamRef.current = null;
    recorderRef.current = null;
  }

  async function transcribeRecording(blob) {
    if (!blob.size) {
      setError("No se capturó audio. Intenta nuevamente.");
      return;
    }
    setTranscribing(true);
    setError("");
    const extension = blob.type.includes("mp4") ? "m4a" : blob.type.includes("ogg") ? "ogg" : "webm";
    try {
      const result = await transcribeAiAudio(projectId, blob, `instruction.${extension}`);
      if (!mountedRef.current) return;
      const text = String(result?.text || "").trim();
      if (!text) throw new Error("No se detectó texto en el audio.");
      setInput((current) => current.trim() ? `${current.trim()} ${text}` : text);
    } catch (cause) {
      if (mountedRef.current) setError(errorMessage(cause, "No se pudo transcribir el audio."));
    } finally {
      if (mountedRef.current) setTranscribing(false);
    }
  }

  async function startRecording() {
    if (requesting || applying || transcribing || recording) return;
    if (!navigator.mediaDevices?.getUserMedia || typeof MediaRecorder === "undefined") {
      setError("Este navegador no permite grabar audio.");
      return;
    }
    setError("");
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const candidates = ["audio/webm;codecs=opus", "audio/webm", "audio/mp4"];
      const mimeType = candidates.find((type) => MediaRecorder.isTypeSupported?.(type));
      const recorder = new MediaRecorder(stream, mimeType ? { mimeType } : undefined);
      streamRef.current = stream;
      recorderRef.current = recorder;
      chunksRef.current = [];
      recorder.ondataavailable = (event) => {
        if (event.data?.size) chunksRef.current.push(event.data);
      };
      recorder.onerror = () => {
        if (mountedRef.current) setError("La grabación se interrumpió.");
      };
      recorder.onstop = () => {
        const blob = new Blob(chunksRef.current, { type: recorder.mimeType || "audio/webm" });
        chunksRef.current = [];
        releaseMicrophone();
        if (mountedRef.current) {
          setRecording(false);
          void transcribeRecording(blob);
        }
      };
      recorder.start(250);
      setRecording(true);
      recordingTimerRef.current = setTimeout(() => {
        if (recorder.state === "recording") recorder.stop();
      }, 60_000);
    } catch (cause) {
      releaseMicrophone();
      const denied = cause?.name === "NotAllowedError" || cause?.name === "PermissionDeniedError";
      setError(denied ? "Debes permitir el micrófono para dictar." : "No se pudo iniciar el micrófono.");
    }
  }

  function stopRecording() {
    if (recorderRef.current?.state === "recording") recorderRef.current.stop();
  }

  const details = proposal?.proposal;
  const blocked = (details?.questions || []).length > 0
    || (details?.diagnostics || []).some((item) => item?.severity === "error");

  return (
    <div className="fixed inset-0 z-[70] flex justify-end bg-slate-950/25" role="dialog" aria-label="Asistente UML">
      <section className="flex h-full w-full max-w-lg flex-col bg-white shadow-2xl">
        <header className="flex items-center gap-3 border-b border-slate-200 px-4 py-3">
          <span className="grid h-9 w-9 place-items-center rounded-full bg-indigo-100 text-lg">✦</span>
          <div className="min-w-0 flex-1">
            <h2 className="font-bold text-slate-900">Asistente UML</h2>
            <p className="truncate text-xs text-slate-500">Modelo configurado vía backend · cambios sujetos a aprobación</p>
          </div>
          <button type="button" className="rounded p-2 hover:bg-slate-100" onClick={onClose} aria-label="Cerrar asistente">✕</button>
        </header>

        <div className="min-h-0 flex-1 space-y-3 overflow-y-auto p-4">
          {messages.map((message, index) => (
            <div key={`${message.role}-${index}`} className={`max-w-[88%] whitespace-pre-wrap rounded-2xl px-3 py-2 text-sm ${message.role === "user" ? "ml-auto bg-indigo-600 text-white" : "bg-slate-100 text-slate-700"}`}>
              {message.text}
            </div>
          ))}
          {requesting && <p className="text-sm text-indigo-700">Analizando el modelo…</p>}

          {details && (
            <div className="rounded-xl border border-indigo-200 bg-indigo-50/40 p-3">
              <p className="text-xs font-semibold text-indigo-700">Vista previa · {proposal.model}</p>
              {(details.assumptions || []).map((item, index) => <p key={`a-${index}`} className="mt-2 text-xs text-slate-600">Supuesto: {item}</p>)}
              {(details.warnings || []).map((item, index) => <p key={`w-${index}`} className="mt-2 text-xs text-amber-700">Advertencia: {item}</p>)}
              {(details.diagnostics || []).map((item, index) => <p key={`d-${index}`} className="mt-2 text-xs text-rose-700">{item.severity}: {item.message}</p>)}
              <div className="mt-3 space-y-2">
                {(details.operations || []).map((operation) => (
                  <label key={operation.id} className="flex gap-2 rounded-lg border border-slate-200 bg-white p-3 text-sm">
                    <input
                      type="checkbox"
                      checked={selected.has(String(operation.id))}
                      onChange={(event) => toggleOperation(operation, event.target.checked)}
                    />
                    <span className="min-w-0">
                      <strong className="block">{operationTitle(operation)}</strong>
                      {operation.explanation && <span className="block text-xs text-slate-500">{operation.explanation}</span>}
                      <code className="mt-1 block max-h-24 overflow-auto whitespace-pre-wrap break-all text-[11px] text-slate-600">{JSON.stringify(operation.value, null, 2)}</code>
                    </span>
                  </label>
                ))}
              </div>
              {!canApply && <p className="mt-3 text-xs text-amber-700">Tu permiso permite consultar y revisar, pero no aplicar cambios.</p>}
              <div className="mt-3 flex justify-end gap-2">
                <button type="button" className="rounded px-3 py-2 text-sm" onClick={() => { setProposal(null); setSelected(new Set()); }}>Descartar</button>
                <button
                  type="button"
                  className="rounded bg-indigo-600 px-3 py-2 text-sm font-semibold text-white disabled:opacity-40"
                  disabled={!canApply || blocked || selected.size === 0 || applying}
                  onClick={confirm}
                >
                  {applying ? "Aplicando…" : `Confirmar ${selected.size} cambio(s)`}
                </button>
              </div>
            </div>
          )}
          {error && <p className="rounded-lg bg-rose-50 p-3 text-sm text-rose-700">{error}</p>}
        </div>

        <form className="flex gap-2 border-t border-slate-200 p-3" onSubmit={send}>
          <button
            type="button"
            className={`self-end rounded-lg px-3 py-2 font-semibold ${recording ? "bg-rose-600 text-white" : "bg-slate-100 text-slate-700"} disabled:opacity-40`}
            onClick={recording ? stopRecording : startRecording}
            disabled={requesting || applying || transcribing}
            aria-label={recording ? "Detener grabación" : "Dictar por voz"}
            title={recording ? "Detener y transcribir" : "Dictar por voz"}
          >
            {recording ? "■" : transcribing ? "…" : "🎙"}
          </button>
          <textarea
            className="min-h-11 flex-1 resize-none rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-indigo-500"
            rows="2"
            maxLength="3000"
            placeholder="Ej.: agrega una clase Factura con sus atributos"
            value={input}
            disabled={requesting || applying || transcribing}
            onChange={(event) => setInput(event.target.value)}
          />
          <button type="submit" className="self-end rounded-lg bg-indigo-600 px-4 py-2 font-semibold text-white disabled:opacity-40" disabled={!input.trim() || requesting || applying || recording || transcribing}>
            Enviar
          </button>
        </form>
        {(recording || transcribing) && (
          <p className="border-t border-slate-100 px-4 py-2 text-xs text-slate-600" role="status">
            {recording ? "Grabando… pulsa detener para transcribir (máximo 60 s)." : "Whisper está convirtiendo el audio a texto…"}
          </p>
        )}
      </section>
    </div>
  );
}
