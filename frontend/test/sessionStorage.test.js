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

function reset() {
  window.localStorage.clear();
  window.sessionStorage.clear();
}

test("Recordarme guarda usuario y tokens solo en localStorage", () => {
  reset();
  storage.saveSession({ user: { id: 1 }, access: "access", refresh: "refresh" }, true);
  assert.equal(storage.getStoredSession().remember, true);
  assert.equal(window.sessionStorage.getItem("auth_refresh_token"), null);
  assert.equal(window.localStorage.getItem("password"), null);
});

test("sesión temporal usa sessionStorage y limpia localStorage", () => {
  reset();
  storage.saveSession({ user: { id: 1 }, access: "old", refresh: "old" }, true);
  storage.saveSession({ user: { id: 2 }, access: "new", refresh: "new" }, false);
  assert.equal(storage.getStoredSession().remember, false);
  assert.equal(window.localStorage.getItem("auth_refresh_token"), null);
});

test("claves heredadas sin modalidad se descartan", () => {
  reset();
  window.localStorage.setItem("auth_access_token", "legacy");
  window.localStorage.setItem("auth_refresh_token", "legacy");
  assert.equal(storage.getStoredSession(), null);
  assert.equal(window.localStorage.getItem("auth_access_token"), null);
});

test("clearSession limpia ambas modalidades", () => {
  reset();
  storage.saveSession({ user: { id: 1 }, access: "a", refresh: "r" }, true);
  storage.clearSession();
  assert.equal(storage.getStoredSession(), null);
});
