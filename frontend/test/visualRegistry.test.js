import test from "node:test";
import assert from "node:assert/strict";
import { ARROW_SHAPES, ER_CONNECTORS, ER_SHAPES, FLOWCHART_SHAPES, GENERAL_SHAPES, isVisualItem, normalizeVisualEdgeProperties, relationshipPresentation, shapeDefinition, visualEdgeProperties, visualNodeProperties } from "../src/domains/modeling/visualRegistry.js";

test("la paleta auxiliar expone las figuras acordadas por categoría", () => {
  assert.deepEqual(GENERAL_SHAPES.map((item) => item.shape), ["text", "rectangle", "rounded-rectangle", "ellipse", "circle", "diamond", "triangle", "parallelogram", "hexagon", "cylinder", "document", "note", "cloud", "callout"]);
  assert.equal(FLOWCHART_SHAPES.length, 12);
  assert.equal(ER_SHAPES.length, 8);
  assert.equal(ARROW_SHAPES.length, 7);
  assert.equal(ER_CONNECTORS.length, 5);
  assert.equal(shapeDefinition("general", "circle").keepAspectRatio, true);
  assert.equal(shapeDefinition("general", "ellipse").keepAspectRatio, undefined);
});

test("los contratos visuales generan propiedades cerradas para nodos y flechas", () => {
  const node = visualNodeProperties("general", "rectangle", "Nota");
  const edge = visualEdgeProperties("double-arrow");
  assert.equal(isVisualItem(node), true);
  assert.equal(node.label, "Nota");
  assert.equal(edge.library, "arrows");
  assert.equal(edge.style.startMarker, "arrow");
  assert.equal(edge.style.endMarker, "arrow");
  assert.equal(edge.style.routing, "straight");
  assert.equal(edge.sourceHandle, "bottom");
  assert.equal(edge.targetHandle, "top");
});

test("normaliza flechas antiguas y mapea la notación UML", () => {
  const legacy = normalizeVisualEdgeProperties({ kind: "visual", library: "arrows", shape: "line", style: { dashed: true, arrowStart: true, arrowEnd: true } });
  assert.equal(legacy.style.lineStyle, "dashed");
  assert.equal(legacy.style.startMarker, "arrow");
  assert.equal(legacy.style.endMarker, "arrow");
  assert.deepEqual(relationshipPresentation("Composition").style, {
    stroke: "#334155", strokeWidth: 2, routing: "orthogonal", lineStyle: "solid", startMarker: "diamond-filled", endMarker: "none",
  });
  assert.equal(relationshipPresentation("Include").label, "«include»");
});
