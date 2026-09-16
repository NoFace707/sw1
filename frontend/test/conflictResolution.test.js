import test from "node:test";
import assert from "node:assert/strict";
import { buildOfflineResolutionOperation } from "../src/domains/sync/conflictResolution.js";

test("la reconciliación offline conserva la alternativa y la envía como nueva revisión", () => {
  const operation = buildOfflineResolutionOperation({ entityType: "UmlElement", entityId: "e1", path: "name", rejectedValue: { name: "Local" } }, 7);
  assert.match(operation.operation_id, /^[0-9a-f-]{36}$/);
  assert.deepEqual({ ...operation, operation_id: undefined }, { operation_id: undefined, entity_type: "UmlElement", entity_id: "e1", action: "resolve", path: "name", base_revision: 7, previous_value: null, new_value: { name: "Local" } });
});
