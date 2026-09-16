import test from "node:test";
import assert from "node:assert/strict";
import { DIAGRAM_PROFILES, MDA_LEVELS, STRUCTURAL_FIXTURES, diagramProfile } from "../src/domains/modeling/diagramRegistry.js";
import { UML_ELEMENT_DEFINITIONS, UML_PALETTE_KEYS, umlElementDefinition } from "../src/domains/modeling/umlRegistry.js";

test("los catorce diagramas tienen paleta UML ampliada, relaciones y fixture", () => {
  for (const type of Object.keys(DIAGRAM_PROFILES)) {
    const profile = diagramProfile(type);
    assert.ok(profile.elements.length > 0);
    assert.ok(profile.palette.length >= profile.elements.length);
    assert.ok(profile.relationships.length > 0);
    assert.equal(STRUCTURAL_FIXTURES[type].diagram_type, type);
    assert.ok(STRUCTURAL_FIXTURES[type].elements.length > 0);
    for (const item of profile.palette) assert.ok(profile.elements.includes(item.metaclass));
  }
});

test("las propiedades esenciales están declaradas por metaclase", () => {
  assert.ok(DIAGRAM_PROFILES.class.properties.Class.includes("operations"));
  assert.ok(DIAGRAM_PROFILES.class.properties.Class.includes("is_abstract"));
  assert.deepEqual(DIAGRAM_PROFILES.object.properties.Object, ["classifier", "slots"]);
  assert.ok(DIAGRAM_PROFILES.use_case.properties.UseCase.includes("extension_points"));
});

test("las variantes UML conservan metaclase, presentación y dimensiones", () => {
  assert.ok(Object.keys(UML_ELEMENT_DEFINITIONS).length >= 70);
  assert.equal(UML_ELEMENT_DEFINITIONS["Class.abstract"].metaclass, "Class");
  assert.equal(UML_ELEMENT_DEFINITIONS["Pseudostate.choice"].properties.kind, "choice");
  assert.equal(UML_ELEMENT_DEFINITIONS["Lifeline.database"].properties.stereotype, "database");
  assert.equal(umlElementDefinition("Pseudostate", { kind: "terminate" }).key, "Pseudostate.terminate");
  assert.equal(umlElementDefinition("Class", { is_active: true }).height, 110);
  assert.equal(UML_ELEMENT_DEFINITIONS["Class.fields"].properties.attributes.length, 3);
  assert.equal(umlElementDefinition("Class", { presentation: "classifier-with-attributes" }).key, "Class.fields");
  assert.ok(DIAGRAM_PROFILES.class.elements.includes("Actor"));
  assert.ok(UML_PALETTE_KEYS.class.includes("Actor"));
  assert.ok(UML_PALETTE_KEYS.activity.length >= 20);
  assert.ok(UML_PALETTE_KEYS.state_machine.length >= 15);
  assert.ok(UML_PALETTE_KEYS.sequence.length >= 15);
});

test("el registro conserva los cuatro niveles MDA explícitos", () => {
  assert.deepEqual(MDA_LEVELS.map(([value]) => value), ["UNSPECIFIED", "CIM", "PIM", "PSM"]);
});
