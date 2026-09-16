export function updatePresence(current, event, receivedAt = Date.now()) {
  if (event.event === "presence.left") return current.filter((item) => item.user_id !== event.user_id);
  if (!new Set(["presence.joined", "presence.focus", "presence.heartbeat"]).has(event.event)) return current;
  const next = { ...event, _receivedAt: receivedAt };
  return current.some((item) => item.user_id === event.user_id)
    ? current.map((item) => item.user_id === event.user_id ? { ...item, ...next } : item)
    : [...current, next];
}

export function prunePresence(current, now = Date.now(), timeoutMs = 30_000) {
  return current.filter((item) => now - (item._receivedAt || 0) < timeoutMs);
}
