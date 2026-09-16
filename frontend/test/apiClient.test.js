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
const client = await import("../src/services/apiClient.js");

function jsonResponse(status, data) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

test("solicitudes 401 paralelas comparten una única renovación", async () => {
  storage.clearSession();
  storage.saveSession({ user: { id: 1 }, access: "old", refresh: "refresh" }, false);
  let refreshCalls = 0;
  let protectedCalls = 0;
  global.fetch = async (url) => {
    if (url.endsWith("/api/auth/refresh/")) {
      refreshCalls += 1;
      return jsonResponse(200, { access: "new" });
    }
    protectedCalls += 1;
    return protectedCalls <= 2
      ? jsonResponse(401, { detail: "expired" })
      : jsonResponse(200, { id: 1 });
  };

  const responses = await Promise.all([
    client.requestWithAuthRetry("/api/auth/me/"),
    client.requestWithAuthRetry("/api/auth/me/"),
  ]);
  assert.equal(refreshCalls, 1);
  assert.deepEqual(responses.map((response) => response.status), [200, 200]);
  assert.equal(storage.getStoredSession().access, "new");
});

test("una renovación fallida limpia la sesión", async () => {
  storage.clearSession();
  storage.saveSession({ user: { id: 1 }, access: "old", refresh: "bad" }, true);
  global.fetch = async (url) => url.endsWith("/api/auth/refresh/")
    ? jsonResponse(401, { detail: "invalid" })
    : jsonResponse(401, { detail: "expired" });

  const response = await client.requestWithAuthRetry("/api/auth/me/");
  assert.equal(response.status, 401);
  assert.equal(storage.getStoredSession(), null);
});

test("requestJsonWithAuthRetry conserva el código HTTP para reconciliación", async () => {
  storage.clearSession();
  global.fetch = async () => jsonResponse(403, { detail: "revocado" });
  await assert.rejects(() => client.requestJsonWithAuthRetry("/api/modeling/projects/1/"), (error) => {
    assert.equal(error.status, 403);
    assert.equal(error.detail, "revocado");
    return true;
  });
});
