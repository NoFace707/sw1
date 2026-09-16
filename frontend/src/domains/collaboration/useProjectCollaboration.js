import { useEffect, useRef, useState } from "react";
import { getProjectWebsocketTicket, listProjectOperations, projectWebsocketUrl } from "./collaborationApi.js";
import { prunePresence, updatePresence } from "./presence.js";

export function useProjectCollaboration(projectId, enabled = true) {
  const PRESENCE_TIMEOUT_MS = 30_000;
  const socketRef = useRef(null);
  const lastRevisionRef = useRef(0);
  const seenOperationIdsRef = useRef(new Set());
  const [connection, setConnection] = useState("offline");
  const [presence, setPresence] = useState([]);
  const [events, setEvents] = useState([]);

  useEffect(() => {
    if (!enabled || !projectId || typeof WebSocket === "undefined") return undefined;
    let cancelled = false;
    let socket;
    let reconnectTimer;
    let heartbeatTimer;
    let reconnectAttempt = 0;
    const reconnectDelays = [1000, 2000, 5000, 10000];
    const scheduleReconnect = () => {
      if (cancelled || reconnectTimer) return;
      setConnection("reconnecting");
      const delay = reconnectDelays[Math.min(reconnectAttempt, reconnectDelays.length - 1)];
      reconnectAttempt += 1;
      reconnectTimer = setTimeout(() => { reconnectTimer = undefined; connect(); }, delay);
    };
    const connect = () => {
      if (cancelled) return;
      setConnection("connecting");
      getProjectWebsocketTicket(projectId).then(({ ticket }) => {
        if (cancelled) return;
        socket = new WebSocket(projectWebsocketUrl(projectId, ticket));
        socketRef.current = socket;
        socket.addEventListener("open", () => {
          reconnectAttempt = 0;
          setConnection("online");
          socket.send(JSON.stringify({ event: "presence.focus", payload: {} }));
          clearInterval(heartbeatTimer);
          heartbeatTimer = setInterval(() => {
            if (socket?.readyState === WebSocket.OPEN) socket.send(JSON.stringify({ event: "presence.heartbeat", payload: {} }));
          }, 10_000);
          listProjectOperations(projectId, lastRevisionRef.current).then((result) => {
            if (cancelled) return;
            const recovered = (result.operations || []).filter((operation) => !seenOperationIdsRef.current.has(operation.operation_id));
            recovered.forEach((operation) => seenOperationIdsRef.current.add(operation.operation_id));
            if (recovered.length) setEvents((current) => [...recovered.map((operation) => ({ event: "operation.confirmed", operation, recovered: true })).reverse(), ...current].slice(0, 100));
            lastRevisionRef.current = Math.max(lastRevisionRef.current, ...(result.operations || []).map((operation) => Number(operation.server_revision) || 0), Number(result.revision) || 0);
          }).catch(() => setConnection("error"));
        });
        socket.addEventListener("close", (event) => {
          socketRef.current = null;
          clearInterval(heartbeatTimer);
          setPresence([]);
          if (event.code === 4403) setConnection("forbidden");
          else scheduleReconnect();
        });
        socket.addEventListener("error", () => setConnection("error"));
        socket.addEventListener("message", (message) => {
          try {
            const event = JSON.parse(message.data);
            const receivedAt = Date.now();
            if (event.event === "operation.confirmed" && event.operation?.operation_id) {
              if (seenOperationIdsRef.current.has(event.operation.operation_id)) return;
              seenOperationIdsRef.current.add(event.operation.operation_id);
              lastRevisionRef.current = Math.max(lastRevisionRef.current, Number(event.operation.server_revision) || 0);
            }
            setEvents((current) => [event, ...current].slice(0, 100));
            setPresence((current) => updatePresence(current, event, receivedAt));
          } catch { /* Ignora mensajes no JSON del servidor. */ }
        });
      }).catch((cause) => {
        if (cause?.status === 403 || cause?.status === 404) setConnection("forbidden");
        else { setConnection("error"); scheduleReconnect(); }
      });
    };
    const presenceTimer = setInterval(() => setPresence((current) => prunePresence(current, Date.now(), PRESENCE_TIMEOUT_MS)), 5000);
    connect();
    return () => { cancelled = true; clearInterval(presenceTimer); clearInterval(heartbeatTimer); clearTimeout(reconnectTimer); socket?.close(); socketRef.current = null; };
  }, [enabled, projectId]);

  function send(event, payload = {}) {
    if (socketRef.current?.readyState === WebSocket.OPEN) socketRef.current.send(JSON.stringify({ event, payload }));
  }

  return { connection, presence, events, send };
}
