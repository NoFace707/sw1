import test from "node:test";
import assert from "node:assert/strict";
import { COVERAGE_COLUMNS, UML_COVERAGE_MATRIX, buildCoverageMatrix, coverageSummary, hasCompleteCoverage } from "../src/domains/modeling/coverageMatrix.js";
import { DIAGRAM_PROFILES } from "../src/domains/modeling/diagramRegistry.js";

test("la matriz cubre los catorce tipos y todas las celdas obligatorias", () => {
  assert.equal(UML_COVERAGE_MATRIX.length, 14);
  for (const row of UML_COVERAGE_MATRIX) {
    for (const column of COVERAGE_COLUMNS) assert.ok(row.cells[column]);
    assert.equal(row.complete, hasCompleteCoverage(row));
  }
  assert.deepEqual(coverageSummary(), { complete: 14, total: 14, pending: 0 });
});

test("una celda pendiente impide marcar completa la fila", () => {
  const matrix = buildCoverageMatrix({ profiles: { ...DIAGRAM_PROFILES, activity: { elements: ["Activity"], relationships: [], properties: {} } } });
  const activity = matrix.find((row) => row.diagramType === "activity");
  assert.equal(activity.cells.relationships.implemented, false);
  assert.equal(activity.complete, false);
});
