import test from "node:test";
import assert from "node:assert/strict";
import { prunePresence, updatePresence } from "../src/domains/collaboration/presence.js";

test("presencia registra entrada y actualiza el foco sin duplicar usuarios", () => {
  const joined = updatePresence([], { event: "presence.joined", user_id: "u1", role: "editor" }, 100);
  const focused = updatePresence(joined, { event: "presence.focus", user_id: "u1", payload: { diagram_id: "d1" } }, 200);
  assert.equal(focused.length, 1);
  assert.deepEqual(focused[0].payload, { diagram_id: "d1" });
});

test("presencia elimina desconexiones y vence entradas antiguas", () => {
  const current = updatePresence([{ user_id: "u1", _receivedAt: 1 }], { event: "presence.left", user_id: "u1" }, 2);
  assert.deepEqual(current, []);
  assert.equal(prunePresence([{ user_id: "u2", _receivedAt: 1 }, { user_id: "u3", _receivedAt: 90 }], 100, 20).length, 1);
});

test("heartbeat conserva visible a un colaborador inactivo", () => {
  const joined = updatePresence([], { event: "presence.joined", user_id: "u1", role: "editor" }, 100);
  const alive = updatePresence(joined, { event: "presence.heartbeat", user_id: "u1", role: "editor" }, 20_000);
  assert.equal(prunePresence(alive, 40_000, 30_000).length, 1);
});
