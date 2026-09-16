import { DIAGRAM_PROFILES, STRUCTURAL_FIXTURES, UML_DIAGRAM_TYPES } from "./diagramRegistry.js";

export const COVERAGE_COLUMNS = [
  "metaclasses",
  "relationships",
  "properties",
  "validation",
  "fixture",
];

const VALIDATED_DIAGRAM_TYPES = new Set(UML_DIAGRAM_TYPES.map(([type]) => type));

function nonEmpty(value) {
  return Array.isArray(value) ? value.length > 0 : Boolean(value && Object.keys(value).length > 0);
}

function coverageCell(implemented, detail) {
  return { implemented: Boolean(implemented), detail };
}

export function buildCoverageMatrix({ profiles = DIAGRAM_PROFILES, fixtures = STRUCTURAL_FIXTURES } = {}) {
  return UML_DIAGRAM_TYPES.map(([diagramType, label]) => {
    const profile = profiles[diagramType] || { elements: [], relationships: [], properties: {} };
    const fixture = fixtures[diagramType];
    const properties = profile.properties || {};
    const cells = {
      metaclasses: coverageCell(nonEmpty(profile.elements), profile.elements || []),
      relationships: coverageCell(nonEmpty(profile.relationships), profile.relationships || []),
      properties: coverageCell(Object.keys(properties).length > 0 && Object.values(properties).every((names) => Array.isArray(names)), properties),
      validation: coverageCell(VALIDATED_DIAGRAM_TYPES.has(diagramType), "Registro autoritativo y validador API"),
      fixture: coverageCell(Boolean(fixture && fixture.diagram_type === diagramType && nonEmpty(fixture.elements)), fixture || null),
    };
    const complete = COVERAGE_COLUMNS.every((column) => cells[column].implemented);
    return { diagramType, label, cells, complete };
  });
}

export const UML_COVERAGE_MATRIX = buildCoverageMatrix();

export function coverageSummary(matrix = UML_COVERAGE_MATRIX) {
  const complete = matrix.filter((row) => row.complete).length;
  return { complete, total: matrix.length, pending: matrix.length - complete };
}

export function hasCompleteCoverage(row) {
  return COVERAGE_COLUMNS.every((column) => row?.cells?.[column]?.implemented === true) && row.complete === true;
}
