import test from "node:test";
import assert from "node:assert/strict";

class MemoryStorage {
  constructor() { this.values = new Map(); }
  getItem(key) { return this.values.has(key) ? this.values.get(key) : null; }
  setItem(key, value) { this.values.set(key, String(value)); }
  removeItem(key) { this.values.delete(key); }
}

global.window = { localStorage: new MemoryStorage(), sessionStorage: new MemoryStorage() };
const storage = await import("../src/services/sessionStorage.js");
const { getProjectWebsocketTicket } = await import("../src/domains/collaboration/collaborationApi.js");

test("el ticket WebSocket se solicita por POST", async () => {
  storage.saveSession({ user: { id: 1 }, access: "access", refresh: "refresh" }, false);
  let captured;
  global.fetch = async (_url, init) => {
    captured = init;
    return new Response(JSON.stringify({ ticket: "ephemeral" }), { status: 200, headers: { "Content-Type": "application/json" } });
  };
  const result = await getProjectWebsocketTicket("project-1");
  assert.equal(result.ticket, "ephemeral");
  assert.equal(captured.method, "POST");
});
