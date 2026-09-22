import test from "node:test";
import assert from "node:assert/strict";

class MemoryStorage {
  constructor() { this.values = new Map(); }
  getItem(key) { return this.values.has(key) ? this.values.get(key) : null; }
  setItem(key, value) { this.values.set(key, String(value)); }
  removeItem(key) { this.values.delete(key); }
  clear() { this.values.clear(); }
}

global.window = { localStorage: new MemoryStorage(), sessionStorage: new MemoryStorage() };
const storage = await import("../src/services/sessionStorage.js");
const ai = await import("../src/domains/ai/aiService.js");

test("transcribe audio como multipart sin enviar automáticamente un prompt", async () => {
  storage.clearSession();
  storage.saveSession({ user: { id: 1 }, access: "token", refresh: "refresh" }, false);
  let captured;
  global.fetch = async (url, init) => {
    captured = { url, init };
    return new Response(JSON.stringify({ text: "crea una clase Cliente", model: "whisper-1" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  };

  const result = await ai.transcribeAiAudio("project-1", new Blob(["audio"], { type: "audio/webm" }));

  assert.equal(result.text, "crea una clase Cliente");
  assert.match(captured.url, /\/projects\/project-1\/ai\/transcriptions\/$/);
  assert.equal(captured.init.method, "POST");
  assert.ok(captured.init.body instanceof FormData);
  assert.equal(captured.init.headers.get("Authorization"), "Bearer token");
  assert.equal(captured.init.headers.has("Content-Type"), false);
});
