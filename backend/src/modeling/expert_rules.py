"""Versioned deterministic UML rules shared with offline mobile clients."""

import hashlib
import json

from .registry import ELEMENT_TYPES, RELATIONSHIP_TYPES, UML_REGISTRY_VERSION


EXPERT_RULES_VERSION = "uml-expert-rules-2"
SEVERITY_ORDER = {"error": 0, "warning": 1, "info": 2}


def _rule(identifier, category, scope, severity, operator, message, *, evidence, question=None, repair=None, mapping=None, **condition):
    return {
        "id": identifier,
        "category": category,
        "scope": scope,
        "severity": severity,
        "condition": {"operator": operator, **condition},
        "message": message,
        "evidence": evidence,
        "question": question,
        "repair": repair,
        "mapping": mapping or {},
    }


_RULES = (
    _rule("element.identity.stable", "identity", "element", "error", "stable_identity", "Todo elemento UML debe conservar una identidad estable.", evidence={"fields": ["id"]}),
    _rule("element.name.required", "identity", "element", "error", "non_blank_name", "El nombre del elemento no puede estar vacío.", evidence={"fields": ["id", "name"]}, repair={"kind": "normalize_name"}),
    _rule("element.metaclass.known", "uml_types", "element", "error", "known_metaclass", "La metaclase debe pertenecer al registro UML activo.", evidence={"fields": ["id", "metaclass"]}),
    _rule("relationship.type.known", "uml_relations", "relationship", "error", "known_relationship", "El tipo de relación debe pertenecer al registro UML activo.", evidence={"fields": ["id", "relationship_type"]}),
    _rule("relationship.endpoints.required", "uml_relations", "relationship", "error", "existing_endpoints", "Toda relación debe conectar elementos existentes.", evidence={"fields": ["id", "source", "target"]}),
    _rule("relationship.multiplicity.known", "uml_relations", "relationship", "warning", "multiplicity_known", "La multiplicidad debe definirse antes de inferir cardinalidad.", evidence={"fields": ["id", "properties.multiplicity"]}, question="¿Qué multiplicidad corresponde a cada extremo de la relación?"),
    _rule("project.mda.level", "mda_traceability", "project", "warning", "mda_level_known", "El nivel MDA del proyecto no está definido.", evidence={"fields": ["project.mda_level"]}, question="¿El modelo corresponde a CIM, PIM o PSM?"),
    _rule("proposal.permission.write", "permissions", "proposal", "error", "write_permission", "El permiso de lector no permite confirmar cambios.", evidence={"fields": ["permission"]}),
    _rule("proposal.operations.limit", "limits", "proposal", "error", "operation_limit", "La propuesta supera el límite de operaciones permitido.", evidence={"fields": ["operations"]}, maximum=200),
    _rule("class.attributes.typed", "uml_types", "Class", "warning", "class_attributes_typed", "Los atributos de clase deben declarar nombre y tipo.", evidence={"fields": ["id", "properties.attributes"]}, question="¿Qué tipo debe tener el atributo indicado?"),
    _rule("spring.entity.identifier", "spring_mapping", "Class", "warning", "spring_identifier", "Una clase persistente necesita un identificador para generar Spring.", evidence={"fields": ["id", "name", "properties.attributes"]}, question="¿Qué atributo será el identificador de la entidad?", mapping={"target": "spring.jpa.entity.id"}),
    _rule("spring.attribute.supported_type", "spring_mapping", "Class", "warning", "spring_supported_type", "El tipo del atributo no tiene un mapeo Spring conocido.", evidence={"fields": ["id", "properties.attributes"]}, question="¿A qué tipo Java debe mapearse el atributo?", mapping={"target": "spring.java.type"}),
)


def _canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def validate_rules_document(payload):
    """Validate the closed rule contract used by Python and Dart."""
    if not isinstance(payload, dict) or payload.get("schema_version") != 1:
        raise ValueError("Versión de esquema de reglas inválida.")
    if not isinstance(payload.get("rules"), list):
        raise ValueError("El catálogo de reglas es obligatorio.")
    required = {"id", "category", "scope", "severity", "condition", "message", "evidence", "question", "repair", "mapping"}
    seen = set()
    for rule in payload["rules"]:
        if not isinstance(rule, dict) or set(rule) != required:
            raise ValueError("La regla no cumple el contrato cerrado.")
        if rule["id"] in seen or rule["severity"] not in SEVERITY_ORDER:
            raise ValueError("Identidad o severidad de regla inválida.")
        if not isinstance(rule["condition"], dict) or not rule["condition"].get("operator"):
            raise ValueError("La condición de regla es inválida.")
        seen.add(rule["id"])
    return payload


def expert_rules_payload():
    body = {
        "schema_version": 1,
        "version": EXPERT_RULES_VERSION,
        "registry_version": UML_REGISTRY_VERSION,
        "rules": list(_RULES),
    }
    validate_rules_document(body)
    return {**body, "checksum": hashlib.sha256(_canonical(body).encode("utf-8")).hexdigest()}


def evaluate_expert_rules(context, rules=None):
    rules = rules or _RULES
    elements = context.get("elements") if isinstance(context.get("elements"), list) else []
    relationships = context.get("relationships") if isinstance(context.get("relationships"), list) else []
    element_ids = {str(item.get("id")) for item in elements if item.get("id")}
    diagnostics = []
    for rule in rules:
        operator = rule["condition"]["operator"]
        evidence_items = []
        if operator == "stable_identity":
            evidence_items = [{"entity": item} for item in elements if not str(item.get("id") or "").strip()]
        elif operator == "non_blank_name":
            evidence_items = [{"entity_id": item.get("id")} for item in elements if not str(item.get("name") or "").strip()]
        elif operator == "known_metaclass":
            evidence_items = [{"entity_id": item.get("id"), "metaclass": item.get("metaclass")} for item in elements if item.get("metaclass") not in ELEMENT_TYPES]
        elif operator == "known_relationship":
            evidence_items = [{"relationship_id": item.get("id"), "relationship_type": item.get("relationship_type")} for item in relationships if item.get("relationship_type") not in RELATIONSHIP_TYPES]
        elif operator == "existing_endpoints":
            evidence_items = [{"relationship_id": item.get("id")} for item in relationships if str(item.get("source") or item.get("source_id")) not in element_ids or str(item.get("target") or item.get("target_id")) not in element_ids]
        elif operator == "multiplicity_known":
            evidence_items = [{"relationship_id": item.get("id")} for item in relationships if not (item.get("properties") or {}).get("multiplicity")]
        elif operator == "mda_level_known":
            level = str((context.get("project") or {}).get("mda_level") or "").lower()
            evidence_items = [{"field": "project.mda_level"}] if level in {"", "unspecified"} else []
        elif operator == "write_permission":
            evidence_items = [{"permission": "viewer"}] if context.get("permission") == "viewer" else []
        elif operator == "operation_limit":
            operations = context.get("operations") if isinstance(context.get("operations"), list) else []
            maximum = rule["condition"].get("maximum", 200)
            evidence_items = [{"count": len(operations), "maximum": maximum}] if len(operations) > maximum else []
        elif operator == "class_attributes_typed":
            for element in elements:
                if element.get("metaclass") != "Class":
                    continue
                for attribute in (element.get("properties") or {}).get("attributes") or []:
                    text = str(attribute)
                    if ":" not in text or not text.split(":", 1)[1].strip():
                        evidence_items.append({"entity_id": element.get("id"), "attribute": text})
        elif operator == "spring_identifier":
            for element in elements:
                attributes = (element.get("properties") or {}).get("attributes") or []
                if element.get("metaclass") == "Class" and not any(_attribute_name(item) in {"id", "uuid"} for item in attributes):
                    evidence_items.append({"entity_id": element.get("id"), "name": element.get("name")})
        elif operator == "spring_supported_type":
            supported = {"string", "uuid", "int", "integer", "long", "double", "decimal", "boolean", "date", "datetime", "instant"}
            for element in elements:
                if element.get("metaclass") != "Class":
                    continue
                for attribute in (element.get("properties") or {}).get("attributes") or []:
                    attr_type = _attribute_type(attribute)
                    if attr_type and attr_type.lower() not in supported:
                        evidence_items.append({"entity_id": element.get("id"), "attribute": str(attribute), "type": attr_type})
        for evidence in evidence_items:
            diagnostics.append({
                "rule_id": rule["id"],
                "severity": rule["severity"],
                "message": rule["message"],
                "evidence": evidence,
                "question": rule["question"],
                "repair": rule["repair"],
                "mapping": rule["mapping"],
            })
    return sorted(diagnostics, key=lambda item: (SEVERITY_ORDER[item["severity"]], item["rule_id"], _canonical(item["evidence"])))


def repair_deterministically(context, diagnostics):
    """Only whitespace normalization is safe without a user decision."""
    repaired = json.loads(json.dumps(context))
    applied = []
    by_id = {str(item.get("id")): item for item in repaired.get("elements", [])}
    for diagnostic in diagnostics:
        repair = diagnostic.get("repair") or {}
        if repair.get("kind") != "normalize_name":
            continue
        element = by_id.get(str((diagnostic.get("evidence") or {}).get("entity_id")))
        if element is None:
            continue
        normalized = " ".join(str(element.get("name") or "").split())
        if normalized and normalized != element.get("name"):
            element["name"] = normalized
            applied.append({"rule_id": diagnostic["rule_id"], "kind": "normalize_name", "entity_id": element.get("id")})
    return repaired, applied, evaluate_expert_rules(repaired)


def _attribute_name(value):
    text = str(value).lstrip("+-#~ ")
    return text.split(":", 1)[0].strip().lower()


def _attribute_type(value):
    text = str(value)
    return text.split(":", 1)[1].strip() if ":" in text else ""
