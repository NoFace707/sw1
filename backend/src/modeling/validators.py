from dataclasses import dataclass, field

from .registry import DIAGRAM_DEFINITIONS, ELEMENT_TYPES, RELATIONSHIP_TYPES


@dataclass
class ValidationIssue:
    severity: str
    code: str
    message: str
    path: str = ""


@dataclass
class ValidationResult:
    errors: list[ValidationIssue] = field(default_factory=list)
    warnings: list[ValidationIssue] = field(default_factory=list)

    @property
    def valid(self):
        return not self.errors


def validate_element(metaclass, name, diagram_type=None):
    result = ValidationResult()
    if not metaclass:
        result.errors.append(ValidationIssue("error", "metaclass_required", "La metaclase es obligatoria.", "metaclass"))
    elif metaclass not in ELEMENT_TYPES and not any(metaclass in item["elements"] for item in DIAGRAM_DEFINITIONS.values()):
        result.errors.append(ValidationIssue("error", "metaclass_unknown", "La metaclase no pertenece al registro UML soportado.", "metaclass"))
    if not name or not name.strip():
        result.errors.append(ValidationIssue("error", "name_required", "El nombre es obligatorio.", "name"))
    if diagram_type and metaclass not in DIAGRAM_DEFINITIONS.get(diagram_type, {}).get("elements", []):
        result.warnings.append(ValidationIssue("warning", "metaclass_not_typical", "La metaclase no está declarada como típica para este diagrama.", "metaclass"))
    return result


def validate_relationship(relationship_type, source, target):
    result = ValidationResult()
    if relationship_type not in RELATIONSHIP_TYPES and not any(relationship_type in item["relationships"] for item in DIAGRAM_DEFINITIONS.values()):
        result.errors.append(ValidationIssue("error", "relationship_unknown", "La relación no pertenece al registro UML soportado.", "relationship_type"))
    if source is None or target is None:
        result.errors.append(ValidationIssue("error", "endpoint_required", "Una relación necesita origen y destino.", "endpoints"))
    elif source.project_id != target.project_id:
        result.errors.append(ValidationIssue("error", "cross_project_reference", "Los extremos deben pertenecer al mismo proyecto.", "endpoints"))
    return result


def result_payload(result):
    return {
        "valid": result.valid,
        "errors": [issue.__dict__ for issue in result.errors],
        "warnings": [issue.__dict__ for issue in result.warnings],
    }
