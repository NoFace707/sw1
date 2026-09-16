import test from "node:test";
import assert from "node:assert/strict";
import { DEFAULT_CLASS_ATTRIBUTE, addClassAttribute, commitClassAttribute, normalizeClassAttributes, removeClassAttribute, requiredClassHeight } from "../src/domains/modeling/classAttributes.js";

test("normaliza, añade, edita y elimina atributos de clase", () => {
  assert.deepEqual(normalizeClassAttributes([" + id: UUID ", "", null]), ["+ id: UUID"]);
  assert.deepEqual(addClassAttribute(["+ id: UUID"]), ["+ id: UUID", DEFAULT_CLASS_ATTRIBUTE]);
  assert.deepEqual(commitClassAttribute(["+ id: UUID", "+ name: String"], 1, "- nombre: Texto "), ["+ id: UUID", "- nombre: Texto"]);
  assert.deepEqual(commitClassAttribute(["+ id: UUID", "+ name: String"], 0, ""), ["+ name: String"]);
  assert.deepEqual(removeClassAttribute(["+ id: UUID", "+ name: String"], 1), ["+ id: UUID"]);
});

test("la clase crece al añadir atributos y no reduce un tamaño manual mayor", () => {
  assert.equal(requiredClassHeight(110, 5), 182);
  assert.equal(requiredClassHeight(240, 1), 240);
  assert.equal(requiredClassHeight(110, 2, 3), 170);
});
