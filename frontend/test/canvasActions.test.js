import test from "node:test";
import assert from "node:assert/strict";
import { cloneNodeForCopy, copyPosition, isTextEditingTarget, selectedItems } from "../src/domains/modeling/canvasActions.js";

test("selecciona solo las vistas marcadas para operaciones de lienzo", () => {
  const selected = selectedItems([{ id: "a", selected: true }, { id: "b", selected: false }, { id: "c", selected: true }]);
  assert.deepEqual(selected.map((item) => item.id), ["a", "c"]);
});

test("copia una vista con un desplazamiento estable sin cambiar el elemento semántico", () => {
  const node = { id: "original", position: { x: 10, y: 20 }, selected: true, data: { elementId: "element-1", label: "Cliente" } };
  const copy = cloneNodeForCopy(node, "copy", copyPosition(node.position));
  assert.equal(copy.id, "copy");
  assert.deepEqual(copy.position, { x: 42, y: 52 });
  assert.equal(copy.data.elementId, "element-1");
  assert.equal(copy.selected, false);
  assert.deepEqual(node.position, { x: 10, y: 20 });
});

test("no intercepta atajos mientras se edita texto", () => {
  assert.equal(isTextEditingTarget({ closest: () => ({}) }), true);
  assert.equal(isTextEditingTarget({ closest: () => null }), false);
});
