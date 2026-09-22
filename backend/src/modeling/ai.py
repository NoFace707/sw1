import copy
import http.client
import json
import re
import unicodedata
import uuid
import urllib.error
import urllib.request

from django.conf import settings

from .registry import DIAGRAM_TYPES, ELEMENT_TYPES, RELATIONSHIP_TYPES


class AiProviderError(Exception):
    pass


class AiProviderTransportError(AiProviderError):
    pass


def _http_provider_error(error, api_key=""):
    try:
        raw = error.read(4096).decode("utf-8", "replace")
    except (AttributeError, OSError, UnicodeError):
        raw = ""
    detail = ""
    if raw:
        try:
            payload = json.loads(raw)
            candidate = payload.get("error", payload) if isinstance(payload, dict) else {}
            if isinstance(candidate, dict):
                detail = str(candidate.get("message") or candidate.get("detail") or candidate.get("error") or "")
            elif isinstance(candidate, str):
                detail = candidate
        except (ValueError, TypeError):
            if not raw.lstrip().startswith("<"):
                detail = raw
    if api_key:
        detail = detail.replace(api_key, "[redactado]")
    detail = " ".join(detail.split())[:300]
    suffix = f" Detalle: {detail}" if detail else ""
    status = getattr(error, "code", None)
    if status in {401, 403}:
        return AiProviderError(
            f"xKiro rechazó la clave o el acceso solicitado (HTTP {status}). "
            f"Comprueba que la clave esté activa y tenga permiso para el modelo configurado.{suffix}"
        )
    if status == 404:
        return AiProviderError(
            f"xKiro no encontró el endpoint o modelo configurado (HTTP 404).{suffix}"
        )
    if status == 429:
        return AiProviderError(
            f"xKiro limitó temporalmente las solicitudes o la cuota disponible (HTTP 429).{suffix}"
        )
    if status and status >= 500:
        return AiProviderError(
            f"xKiro está temporalmente no disponible (HTTP {status}).{suffix}"
        )
    return AiProviderError(
        f"El proveedor rechazó la solicitud de IA"
        f"{f' (HTTP {status})' if status else ''}.{suffix}"
    )


_OPERATION_SCHEMA = {
    "type": "object",
    "properties": {
        "id": {"type": "string"},
        "entity_type": {
            "type": "string",
            "enum": ["UmlPackage", "UmlElement", "UmlRelationship", "Diagram", "DiagramNode", "DiagramEdge"],
        },
        "entity_id": {"type": ["string", "null"]},
        "action": {"type": "string", "enum": ["create", "update", "delete"]},
        "path": {
            "type": "string",
            "description": "Ruta con puntos para una actualización parcial, por ejemplo properties.attributes o name.",
        },
        "value": {
            "description": "Objeto completo de la operación o valor de la ruta indicada para una actualización parcial.",
            "oneOf": [
                {"type": "object"},
                {"type": "array"},
                {"type": "string"},
                {"type": "number"},
                {"type": "boolean"},
                {"type": "null"},
            ],
        },
        "depends_on": {"type": "array", "items": {"type": "string"}},
        "explanation": {"type": "string"},
    },
    "required": ["id", "entity_type", "action", "value"],
    "additionalProperties": False,
}


_AI_PATCH_FIELDS = {
    "UmlPackage": {"parent", "parent_id", "name", "mda_level", "properties"},
    "UmlElement": {"package", "package_id", "metaclass", "name", "properties", "external_ids"},
    "UmlRelationship": {
        "relationship_type", "type", "source", "source_id", "target", "target_id", "properties", "external_ids",
    },
    "Diagram": {"name", "diagram_type", "type", "properties"},
    "DiagramNode": {"diagram", "diagram_id", "element", "element_id", "x", "y", "width", "height", "properties"},
    "DiagramEdge": {
        "diagram", "diagram_id", "relationship", "relationship_id", "source_node", "source_node_id",
        "target_node", "target_node_id", "properties",
    },
}
_AI_PATCH_SEGMENT = re.compile(r"^[A-Za-z][A-Za-z0-9_]*$")
_AI_NESTED_PATCH_FIELDS = {"properties", "external_ids"}
_AI_REFERENCE_FIELDS = {
    "parent", "parent_id", "package", "package_id", "source", "source_id", "target", "target_id",
    "diagram", "diagram_id", "element", "element_id", "relationship", "relationship_id",
    "source_node", "source_node_id", "target_node", "target_node_id",
}
_AI_REFERENCE_ENTITY_TYPES = {
    "parent": "UmlPackage", "parent_id": "UmlPackage", "package": "UmlPackage", "package_id": "UmlPackage",
    "source": "UmlElement", "source_id": "UmlElement", "target": "UmlElement", "target_id": "UmlElement",
    "diagram": "Diagram", "diagram_id": "Diagram", "element": "UmlElement", "element_id": "UmlElement",
    "relationship": "UmlRelationship", "relationship_id": "UmlRelationship",
    "source_node": "DiagramNode", "source_node_id": "DiagramNode",
    "target_node": "DiagramNode", "target_node_id": "DiagramNode",
}


def _normalize_operation_value(operation):
    """Convert safe `path + value` updates into the object shape used by serializers."""
    value = operation.get("value", {})
    path = operation.get("path", "")
    if not path and isinstance(value, dict):
        return value, False
    if operation.get("action") != "update" or not isinstance(path, str) or not path.strip():
        raise AiProviderError("El valor de la operación debe ser un objeto.")

    parts = path.strip().split(".")
    if len(parts) > 6 or any(not _AI_PATCH_SEGMENT.fullmatch(part) for part in parts):
        raise AiProviderError("La ruta de actualización propuesta no es válida.")
    entity_type = operation.get("entity_type")
    root = parts[0]
    if root not in _AI_PATCH_FIELDS.get(entity_type, set()):
        raise AiProviderError("La ruta de actualización propuesta no está permitida.")
    if len(parts) > 1 and root not in _AI_NESTED_PATCH_FIELDS:
        raise AiProviderError("La ruta de actualización no puede anidarse en ese campo.")

    # Providers sometimes send a complete update object together with `path`.
    # Keep that representation when it already starts at the declared root.
    if isinstance(value, dict) and root in value:
        return value, False
    normalized = value
    if isinstance(value, dict) and len(parts) > 1 and set(value) == {parts[-1]}:
        normalized = value[parts[-1]]
    for part in reversed(parts):
        normalized = {part: normalized}
    return normalized, True


def _decode_operation_json_value(operation):
    value = operation.get("value", {})
    if not isinstance(value, str):
        return False
    stripped = value.strip()
    if not stripped or stripped[0] not in "[{":
        return False
    try:
        decoded = json.loads(stripped)
    except (ValueError, TypeError):
        return False
    operation["value"] = decoded
    return True


def _expand_batched_create_operations(operations, diagnostics):
    """Turn a provider's create operation with a list value into atomic creates."""
    expanded = []
    for operation in operations:
        decoded = _decode_operation_json_value(operation)
        value = operation.get("value", {})
        if operation.get("action") != "create" or not isinstance(value, list):
            expanded.append(operation)
            if decoded:
                diagnostics.append({
                    "rule_id": "ai.operation.json-value-decoded",
                    "severity": "info",
                    "message": "Se convirtió el valor JSON textual de una operación a su estructura real.",
                    "evidence": {"operation_id": str(operation.get("id") or "")},
                    "repair": {"kind": "decode_json_value"},
                })
            continue
        if not value or not all(isinstance(item, dict) for item in value):
            raise AiProviderError("Una creación agrupada debe contener objetos válidos.")
        base_id = str(operation.get("id") or uuid.uuid4())
        for index, item in enumerate(value, start=1):
            atomic = copy.deepcopy(operation)
            atomic["id"] = f"{base_id}:{index}"
            atomic["value"] = item
            atomic.pop("entity_id", None)
            expanded.append(atomic)
        diagnostics.append({
            "rule_id": "ai.operation.batch-create-expanded",
            "severity": "info",
            "message": f"Se separó una creación agrupada en {len(value)} operaciones revisables.",
            "evidence": {"operation_id": base_id, "count": len(value)},
            "repair": {"kind": "expand_batch_create"},
        })
    return expanded


_PROVIDER_VALUE_ALIASES = {
    "UmlElement": {"meta_class": "metaclass", "uml_type": "metaclass", "type": "metaclass", "package_ref": "package"},
    "UmlRelationship": {
        "type": "relationship_type",
        "source_element_ref": "source", "source_ref": "source",
        "target_element_ref": "target", "target_ref": "target",
    },
    "Diagram": {"type": "diagram_type"},
    "DiagramNode": {"diagram_ref": "diagram", "element_ref": "element"},
    "DiagramEdge": {
        "diagram_ref": "diagram", "relationship_ref": "relationship",
        "source_node_ref": "source_node", "target_node_ref": "target_node",
    },
}

_AI_ENTITY_TYPES = {"UmlPackage", "UmlElement", "UmlRelationship", "Diagram", "DiagramNode", "DiagramEdge"}
_METACLASS_LANGUAGE_ALIASES = {"clase": "Class", "interfaz": "Interface", "actoruml": "Actor"}
_VISUAL_NODE_SHAPES = {
    "general": ("text", "rectangle", "rounded-rectangle", "ellipse", "circle", "diamond", "triangle", "parallelogram", "hexagon", "cylinder", "document", "note", "cloud", "callout"),
    "flowchart": ("process", "terminator", "decision", "data", "database", "flow-document", "manual-input", "preparation", "delay", "connector", "off-page-connector", "subprocess"),
    "er": ("entity", "weak-entity", "attribute", "key-attribute", "multivalued-attribute", "derived-attribute", "relationship", "identifying-relationship"),
}
_VISUAL_PROMPT_SHAPES = (
    (r"\bcuadrad[oa]\b", "general", "rectangle", 180, 90),
    (r"\brect[aá]ngulo\b", "general", "rectangle", 180, 90),
    (r"\brombo\b", "general", "diamond", 150, 110),
    (r"\belipse\b", "general", "ellipse", 180, 110),
    (r"\bc[ií]rculo\b", "general", "circle", 110, 110),
    (r"\btri[aá]ngulo\b", "general", "triangle", 140, 120),
    (r"\bparalelogramo\b", "general", "parallelogram", 180, 90),
    (r"\bhex[aá]gono\b", "general", "hexagon", 180, 90),
    (r"\bcilindro\b", "general", "cylinder", 160, 120),
    (r"\bdocumento\b", "general", "document", 170, 110),
    (r"\bnota\b", "general", "note", 160, 110),
    (r"\bnube\b", "general", "cloud", 180, 110),
)


def _canonical_closed_name(value, allowed, aliases=None):
    if not isinstance(value, str) or not value.strip():
        return None
    compact = re.sub(r"[^a-z0-9]", "", value.casefold())
    alias = (aliases or {}).get(compact)
    if alias in allowed:
        return alias
    by_compact = {re.sub(r"[^a-z0-9]", "", item.casefold()): item for item in allowed}
    if compact in by_compact:
        return by_compact[compact]
    if compact.startswith("uml") and compact[3:] in by_compact:
        return by_compact[compact[3:]]
    return None


def _latest_user_request(prompt):
    text = str(prompt or "")
    return text.rsplit("Usuario:", 1)[-1].strip() if "Usuario:" in text else text.strip()


def _adapt_explicit_visual_shape_request(operations, diagnostics, context, prompt):
    """Keep explicit general-shape requests visual even when a model emits UML classes."""
    diagram_context = (context or {}).get("diagram") or {}
    diagram_id = diagram_context.get("id")
    request_text = "".join(
        character for character in unicodedata.normalize("NFKD", _latest_user_request(prompt).casefold())
        if not unicodedata.combining(character)
    )
    if not diagram_id:
        return
    requested = []
    for pattern, library, shape, width, height in _VISUAL_PROMPT_SHAPES:
        requested.extend((match.start(), library, shape, width, height) for match in re.finditer(pattern, request_text))
    requested.sort(key=lambda item: item[0])
    if not requested:
        return

    # Applying a proposal validates it again. Reuse identities from the saved
    # preview so a frontend selection remains valid across that second pass.
    existing_visual_nodes = [
        operation for operation in operations
        if operation.get("entity_type") == "DiagramNode"
        and operation.get("action") == "create"
        and isinstance(operation.get("value"), dict)
        and ((operation.get("value") or {}).get("properties") or {}).get("kind") == "visual"
    ]
    existing_visual_edges = [
        operation for operation in operations
        if operation.get("entity_type") == "DiagramEdge"
        and operation.get("action") == "create"
        and isinstance(operation.get("value"), dict)
        and ((operation.get("value") or {}).get("properties") or {}).get("kind") == "visual"
    ]
    existing_node_deletes = {
        str(operation.get("entity_id")): operation
        for operation in operations
        if operation.get("entity_type") == "DiagramNode"
        and operation.get("action") == "delete"
        and operation.get("entity_id")
    }

    replacement_requested = any(
        term in request_text for term in ("reemplaz", "sustitu", "cambia", "convierte")
    )
    context_elements = (context or {}).get("elements") or []
    context_nodes = diagram_context.get("nodes") or []
    context_edges = diagram_context.get("edges") or []
    node_by_element = {
        str(node.get("element_id")): node
        for node in context_nodes
        if node.get("element_id")
    }
    mentioned_elements = []
    if replacement_requested:
        for element in context_elements:
            name = str(element.get("name") or "").strip()
            normalized_name = "".join(
                character for character in unicodedata.normalize("NFKD", name.casefold())
                if not unicodedata.combining(character)
            )
            if not normalized_name or str(element.get("id")) not in node_by_element:
                continue
            match = re.search(rf"(?<!\w){re.escape(normalized_name)}(?!\w)", request_text)
            if match:
                mentioned_elements.append((match.start(), element, node_by_element[str(element.get("id"))]))
        mentioned_elements.sort(key=lambda item: item[0])

    # Pair named existing views and requested shapes by their order in the
    # sentence. Replacing a view must not erase the underlying UML model.
    replacement_targets = mentioned_elements[:len(requested)] if len(mentioned_elements) >= len(requested) else []
    visual_labels = [
        str(((operation.get("value") or {}).get("properties") or {}).get("label") or "").strip()
        for operation in operations
        if operation.get("entity_type") == "DiagramNode"
        and isinstance(operation.get("value"), dict)
        and ((operation.get("value") or {}).get("properties") or {}).get("kind") == "visual"
    ]
    semantic_labels = [
        str((operation.get("value") or {}).get("name") or "").strip()
        for operation in operations
        if operation.get("entity_type") == "UmlElement" and operation.get("action") == "create"
    ]
    labels = [label for label in [*visual_labels, *semantic_labels] if label]
    asks_for_animal_names = "animal" in request_text and ("nombre" in request_text or "llama" in request_text)
    animal_names = ("Perro", "Gato", "Águila", "Delfín", "León", "Tortuga")
    visual_operations = []
    node_operations = []
    for index, (_, library, shape, width, height) in enumerate(requested):
        replacement = replacement_targets[index] if replacement_targets else None
        old_element = replacement[1] if replacement else None
        old_node = replacement[2] if replacement else None
        existing_node = existing_visual_nodes[index] if index < len(existing_visual_nodes) else {}
        node = {
            "id": existing_node.get("id") or f"visual-node-{uuid.uuid4()}",
            "entity_type": "DiagramNode",
            "entity_id": existing_node.get("entity_id") or str(uuid.uuid4()),
            "action": "create",
            "depends_on": [],
            "value": {
                "diagram": str(diagram_id),
                "element": None,
                "x": old_node.get("x", 0) if old_node else 140 + (index % 3) * 300,
                "y": old_node.get("y", 0) if old_node else 160 + (index // 3) * 190,
                "width": width,
                "height": height,
                "properties": {
                    "kind": "visual", "library": library, "shape": shape,
                    "label": (
                        str(old_element.get("name") or f"Figura {index + 1}")
                        if old_element
                        else animal_names[index % len(animal_names)]
                        if asks_for_animal_names and (index >= len(labels) or re.fullmatch(r"animal\s*\d*", labels[index], re.IGNORECASE))
                        else labels[index] if index < len(labels)
                        else f"Figura {index + 1}"
                    ),
                    "style": {},
                },
            },
            "explanation": (
                f"Reemplaza la vista de {old_element.get('name')} por una figura {shape}, conservando su elemento UML."
                if old_element else f"Figura visual {shape} solicitada para el diagrama actual."
            ),
        }
        visual_operations.append(node)
        node_operations.append(node)

    preserved_edges = []
    if replacement_targets:
        operation_by_old_node = {
            str(replacement[2].get("id")): node_operation
            for replacement, node_operation in zip(replacement_targets, node_operations)
        }
        preserved_edges = [
            edge for edge in context_edges
            if str(edge.get("source_node_id")) in operation_by_old_node
            and str(edge.get("target_node_id")) in operation_by_old_node
        ]
        for edge_index, edge in enumerate(preserved_edges):
            source = operation_by_old_node[str(edge.get("source_node_id"))]
            target = operation_by_old_node[str(edge.get("target_node_id"))]
            existing_edge = existing_visual_edges[edge_index] if edge_index < len(existing_visual_edges) else {}
            visual_operations.append({
                "id": existing_edge.get("id") or f"visual-edge-{uuid.uuid4()}",
                "entity_type": "DiagramEdge",
                "entity_id": existing_edge.get("entity_id") or str(uuid.uuid4()),
                "action": "create",
                "depends_on": [source["id"], target["id"]],
                "value": {
                    "diagram": str(diagram_id),
                    "relationship": None,
                    "source_node": source["entity_id"],
                    "target_node": target["entity_id"],
                    "properties": {
                        "kind": "visual", "library": "arrows", "shape": "line", "label": "",
                        "sourceHandle": "right", "targetHandle": "left",
                        "style": {"routing": "straight", "lineStyle": "solid", "startMarker": "none", "endMarker": "none"},
                    },
                },
                "explanation": "Conserva visualmente la conexión que existía entre las figuras reemplazadas.",
            })

    wants_connection = any(term in request_text for term in ("asocia", "relaciona", "conecta", "conexi", "une ", "unir"))
    if wants_connection and not preserved_edges:
        for edge_index, (source, target) in enumerate(zip(node_operations, node_operations[1:])):
            existing_edge = existing_visual_edges[edge_index] if edge_index < len(existing_visual_edges) else {}
            visual_operations.append({
                "id": existing_edge.get("id") or f"visual-edge-{uuid.uuid4()}",
                "entity_type": "DiagramEdge",
                "entity_id": existing_edge.get("entity_id") or str(uuid.uuid4()),
                "action": "create",
                "depends_on": [source["id"], target["id"]],
                "value": {
                    "diagram": str(diagram_id),
                    "relationship": None,
                    "source_node": source["entity_id"],
                    "target_node": target["entity_id"],
                    "properties": {
                        "kind": "visual", "library": "arrows", "shape": "line", "label": "",
                        "sourceHandle": "right", "targetHandle": "left",
                        "style": {"routing": "straight", "lineStyle": "solid", "startMarker": "none", "endMarker": "none"},
                    },
                },
                "explanation": "Conector visual entre las figuras solicitadas.",
            })

    if replacement_targets:
        for replacement, new_node in zip(replacement_targets, node_operations):
            old_element, old_node = replacement[1], replacement[2]
            existing_delete = existing_node_deletes.get(str(old_node["id"]), {})
            visual_operations.append({
                "id": existing_delete.get("id") or f"remove-view-{uuid.uuid4()}",
                "entity_type": "DiagramNode",
                "entity_id": str(old_node["id"]),
                "action": "delete",
                "depends_on": [new_node["id"]],
                "value": {},
                "explanation": (
                    f"Retira únicamente la vista UML anterior de {old_element.get('name')}; "
                    "el elemento semántico se conserva en el proyecto."
                ),
            })
    operations[:] = visual_operations
    if replacement_targets:
        diagnostics.append({
            "rule_id": "ai.operation.visual-views-replaced",
            "severity": "info",
            "message": "Se reemplazarán las vistas por figuras visuales sin eliminar los elementos UML del proyecto.",
            "evidence": {
                "diagram_id": str(diagram_id),
                "element_ids": [str(item[1]["id"]) for item in replacement_targets],
                "node_ids": [str(item[2]["id"]) for item in replacement_targets],
                "shapes": [item[2] for item in requested],
            },
            "repair": {"kind": "replace_diagram_views_with_visual_shapes"},
        })
    else:
        diagnostics.append({
            "rule_id": "ai.operation.explicit-visual-shapes-preserved",
            "severity": "info",
            "message": "La solicitud de figuras se conservó como geometría visual y no como clases UML.",
            "evidence": {"diagram_id": str(diagram_id), "shapes": [item[2] for item in requested]},
            "repair": {"kind": "replace_semantic_classes_with_visual_shapes"},
        })


def _normalize_provider_field_aliases(operations, diagnostics):
    """Normalize a small, explicit set of common provider field aliases."""
    repaired_operations = []
    repaired_attributes = []
    visibility_symbols = {
        "public": "+", "private": "-", "protected": "#", "package": "~",
        "+": "+", "-": "-", "#": "#", "~": "~",
    }
    for operation in operations:
        canonical_entity_type = _canonical_closed_name(operation.get("entity_type"), _AI_ENTITY_TYPES)
        if canonical_entity_type and canonical_entity_type != operation.get("entity_type"):
            operation["entity_type"] = canonical_entity_type
            repaired_operations.append(str(operation.get("id") or ""))
        value = operation.get("value")
        if not isinstance(value, dict):
            continue
        changed = False
        for alias, canonical in _PROVIDER_VALUE_ALIASES.get(operation.get("entity_type"), {}).items():
            if alias not in value:
                continue
            if canonical not in value:
                value[canonical] = value[alias]
            value.pop(alias, None)
            changed = True

        registry_field = {
            "UmlElement": ("metaclass", ELEMENT_TYPES, _METACLASS_LANGUAGE_ALIASES),
            "UmlRelationship": ("relationship_type", RELATIONSHIP_TYPES, None),
            "Diagram": ("diagram_type", DIAGRAM_TYPES, None),
        }.get(operation.get("entity_type"))
        if registry_field:
            field, allowed, aliases = registry_field
            if field in value:
                canonical = _canonical_closed_name(value[field], allowed, aliases)
                if canonical and canonical != value[field]:
                    value[field] = canonical
                    changed = True

        if operation.get("entity_type") == "UmlElement":
            properties = value.get("properties")
            attributes = properties.get("attributes") if isinstance(properties, dict) else None
            if isinstance(attributes, list) and any(isinstance(item, dict) for item in attributes):
                normalized_attributes = []
                for attribute in attributes:
                    if isinstance(attribute, str):
                        normalized_attributes.append(attribute)
                        continue
                    if not isinstance(attribute, dict):
                        raise AiProviderError("Los atributos propuestos para la clase no son válidos.")
                    name = attribute.get("name")
                    if not isinstance(name, str) or not name.strip():
                        raise AiProviderError("Cada atributo propuesto requiere un nombre.")
                    type_name = attribute.get("type") or attribute.get("data_type") or "String"
                    if not isinstance(type_name, str) or not type_name.strip():
                        raise AiProviderError("Cada atributo propuesto requiere un tipo válido.")
                    visibility = visibility_symbols.get(str(attribute.get("visibility", "public")).casefold(), "+")
                    normalized_attributes.append(f"{visibility} {name.strip()}: {type_name.strip()}")
                properties["attributes"] = normalized_attributes
                repaired_attributes.append(str(operation.get("id") or ""))
                changed = True
        if changed:
            repaired_operations.append(str(operation.get("id") or ""))

    if repaired_operations:
        diagnostics.append({
            "rule_id": "ai.operation.provider-aliases-normalized",
            "severity": "info",
            "message": "Se normalizaron nombres de campos equivalentes devueltos por el proveedor.",
            "evidence": {"operation_ids": repaired_operations},
            "repair": {"kind": "normalize_provider_field_aliases"},
        })
    if repaired_attributes:
        diagnostics.append({
            "rule_id": "ai.operation.class-attributes-normalized",
            "severity": "info",
            "message": "Se convirtieron los atributos estructurados al formato editable de las clases.",
            "evidence": {"operation_ids": repaired_attributes},
            "repair": {"kind": "normalize_class_attributes"},
        })


def _normalize_package_figures_as_elements(operations, diagnostics):
    """Turn provider-created namespace packages into connectable UML Package elements.

    UmlPackage organizes the repository and cannot be a DiagramNode element or
    a UmlRelationship endpoint. A package drawn on a diagram is represented by
    UmlElement(metaclass=Package), just like figures created from the palette.
    """
    referenced_as_element = set()
    for operation in operations:
        value = operation.get("value")
        if not isinstance(value, dict):
            continue
        if operation.get("entity_type") == "UmlRelationship":
            fields = ("source", "source_id", "target", "target_id")
        elif operation.get("entity_type") == "DiagramNode":
            fields = ("element", "element_id")
        else:
            continue
        referenced_as_element.update(str(value[field]) for field in fields if value.get(field))

    repaired = []
    for operation in operations:
        if operation.get("action") != "create" or operation.get("entity_type") != "UmlPackage":
            continue
        value = operation.get("value")
        if not isinstance(value, dict):
            continue
        identities = {
            str(candidate) for candidate in (
                operation.get("id"), operation.get("entity_id"), value.get("id"), value.get("entity_id"),
            ) if candidate
        }
        if not identities.intersection(referenced_as_element):
            continue
        properties = dict(value.get("properties") or {})
        if value.get("mda_level"):
            properties.setdefault("mda_level", value["mda_level"])
        parent = value.get("parent") or value.get("parent_id")
        operation["entity_type"] = "UmlElement"
        operation["value"] = {
            "metaclass": "Package",
            "name": str(value.get("name") or "Paquete").strip() or "Paquete",
            "package": parent,
            "properties": properties,
        }
        repaired.append(str(operation.get("id") or ""))

    if repaired:
        diagnostics.append({
            "rule_id": "ai.operation.package-figure-normalized",
            "severity": "info",
            "message": "Se normalizaron los paquetes dibujados como elementos UML conectables.",
            "evidence": {"operation_ids": repaired},
            "repair": {"kind": "convert_namespace_package_to_uml_package_element"},
        })


def _valid_uuid(value):
    try:
        return str(uuid.UUID(str(value)))
    except (ValueError, TypeError, AttributeError):
        return None


def _normalize_created_entity_ids(operations, diagnostics):
    """Assign valid entity UUIDs and rewrite temporary cross-operation references."""
    replacements = {}
    creators = {}
    created_by_operation = {}
    created_names = {}
    seen_operation_ids = set()
    for operation in operations:
        operation_id = operation["id"]
        if operation_id in seen_operation_ids:
            raise AiProviderError("Los identificadores de operación deben ser únicos.")
        seen_operation_ids.add(operation_id)
        if operation.get("action") != "create":
            continue
        raw_value = operation.get("value") or {}
        requested_id = operation.get("entity_id") or raw_value.get("entity_id") or raw_value.get("id")
        entity_id = _valid_uuid(requested_id) or str(uuid.uuid4())
        operation["entity_id"] = entity_id
        creators[entity_id] = operation_id
        created_by_operation[operation_id] = (operation.get("entity_type"), entity_id)
        name = raw_value.get("name")
        if isinstance(name, str) and name.strip():
            created_names.setdefault((operation.get("entity_type"), name.strip().casefold()), []).append(entity_id)
        for candidate in (operation_id, requested_id, raw_value.get("entity_id"), raw_value.get("id")):
            if candidate:
                replacements[str(candidate)] = entity_id
        raw_value.pop("entity_id", None)
        if requested_id and not _valid_uuid(requested_id):
            diagnostics.append({
                "rule_id": "ai.operation.entity-id-normalized",
                "severity": "info",
                "message": "Se reemplazó un identificador temporal por un UUID válido.",
                "evidence": {"operation_id": operation_id},
                "repair": {"kind": "replace_temporary_entity_id", "entity_id": entity_id},
            })

    for operation in operations:
        dependencies = list(operation.get("depends_on") or [])
        raw_entity_id = operation.get("entity_id")
        if raw_entity_id is not None and str(raw_entity_id) in replacements:
            operation["entity_id"] = replacements[str(raw_entity_id)]
            creator = creators.get(operation["entity_id"])
            if creator and creator != operation["id"] and creator not in dependencies:
                dependencies.append(creator)
        value = operation.get("value") or {}
        for field in _AI_REFERENCE_FIELDS.intersection(value):
            raw_reference = value[field]
            if raw_reference is None:
                continue
            replacement = replacements.get(str(raw_reference))
            if replacement is None and isinstance(raw_reference, str):
                named = created_names.get((_AI_REFERENCE_ENTITY_TYPES[field], raw_reference.strip().casefold()), [])
                if len(named) == 1:
                    replacement = named[0]
                    diagnostics.append({
                        "rule_id": "ai.operation.named-reference-normalized",
                        "severity": "info",
                        "message": f"Se resolvió la referencia {field} por el nombre único del elemento creado.",
                        "evidence": {"operation_id": operation["id"], "field": field},
                        "repair": {"kind": "resolve_named_reference"},
                    })
            if replacement is None:
                expected_type = _AI_REFERENCE_ENTITY_TYPES[field]
                dependency_matches = [
                    entity_id
                    for dependency in dependencies
                    for entity_type, entity_id in [created_by_operation.get(dependency, (None, None))]
                    if entity_type == expected_type
                ]
                if len(dependency_matches) == 1:
                    replacement = dependency_matches[0]
                    diagnostics.append({
                        "rule_id": "ai.operation.reference-normalized",
                        "severity": "info",
                        "message": f"Se corrigió la referencia {field} usando su dependencia explícita.",
                        "evidence": {"operation_id": operation["id"], "field": field},
                        "repair": {"kind": "resolve_reference_from_dependency"},
                    })
            if replacement is None:
                continue
            value[field] = replacement
            creator = creators.get(value[field])
            if creator and creator != operation["id"] and creator not in dependencies:
                dependencies.append(creator)
        operation["depends_on"] = dependencies


def _order_operations_by_dependencies(operations, diagnostics):
    by_id = {operation["id"]: operation for operation in operations}
    unknown = {
        dependency
        for operation in operations
        for dependency in operation.get("depends_on", [])
        if dependency not in by_id
    }
    if unknown:
        raise AiProviderError("La propuesta contiene dependencias desconocidas.")
    remaining = {operation["id"]: set(operation.get("depends_on", [])) for operation in operations}
    ordered = []
    while remaining:
        ready = [operation["id"] for operation in operations if operation["id"] in remaining and not remaining[operation["id"]]]
        if not ready:
            raise AiProviderError("La propuesta contiene un ciclo de dependencias.")
        for operation_id in ready:
            ordered.append(by_id[operation_id])
            remaining.pop(operation_id)
        for dependencies in remaining.values():
            dependencies.difference_update(ready)
    if [item["id"] for item in ordered] != [item["id"] for item in operations]:
        diagnostics.append({
            "rule_id": "ai.operation.dependencies-ordered",
            "severity": "info",
            "message": "Se reordenaron las operaciones para crear primero sus dependencias.",
            "evidence": {"operation_ids": [item["id"] for item in ordered]},
            "repair": {"kind": "topological_sort"},
        })
    operations[:] = ordered


def _explicit_many_to_many(prompt):
    normalized = " ".join(str(prompt or "").casefold().replace("-", " ").split())
    return "muchos a muchos" in normalized or "many to many" in normalized


def _complete_explicit_many_to_many_graph(operations, diagnostics, context, prompt):
    """Complete the mechanical canvas operations for an explicit two-class request."""
    if not _explicit_many_to_many(prompt):
        return
    elements = [
        operation for operation in operations
        if operation.get("action") == "create" and operation.get("entity_type") == "UmlElement"
        and (operation.get("value") or {}).get("metaclass") == "Class"
    ]
    if len(elements) != 2:
        return
    element_ids = [operation["entity_id"] for operation in elements]
    element_dependencies = [operation["id"] for operation in elements]

    relationships = [
        operation for operation in operations
        if operation.get("action") == "create" and operation.get("entity_type") == "UmlRelationship"
    ]
    if relationships:
        relationship = relationships[0]
    else:
        relationship = {
            "id": f"auto-many-to-many-{uuid.uuid4()}",
            "entity_type": "UmlRelationship",
            "entity_id": str(uuid.uuid4()),
            "action": "create",
            "depends_on": list(element_dependencies),
            "value": {},
            "explanation": "Asociación muchos a muchos solicitada explícitamente.",
        }
        operations.append(relationship)
    relationship_value = relationship["value"]
    relationship_value["relationship_type"] = "Association"
    relationship_value.pop("type", None)
    relationship_value["source"] = element_ids[0]
    relationship_value["target"] = element_ids[1]
    relationship_value.pop("source_id", None)
    relationship_value.pop("target_id", None)
    properties = relationship_value.setdefault("properties", {})
    properties["multiplicity"] = {"source": "*", "target": "*"}
    relationship["depends_on"] = list(dict.fromkeys([
        *(relationship.get("depends_on") or []), *element_dependencies,
    ]))

    diagram = (context or {}).get("diagram") or {}
    diagram_id = diagram.get("id")
    if not diagram_id:
        return
    nodes = [
        operation for operation in operations
        if operation.get("action") == "create" and operation.get("entity_type") == "DiagramNode"
    ]
    node_by_element = {}
    for node in nodes:
        value = node.get("value") or {}
        element_id = value.get("element") or value.get("element_id")
        if element_id in element_ids and element_id not in node_by_element:
            node_by_element[element_id] = node
    for index, (element, element_id) in enumerate(zip(elements, element_ids)):
        node = node_by_element.get(element_id)
        if node is None:
            reusable = next(
                (candidate for candidate in nodes if candidate not in node_by_element.values()
                 and not ((candidate.get("value") or {}).get("element") or (candidate.get("value") or {}).get("element_id"))),
                None,
            )
            node = reusable or {
                "id": f"auto-node-{uuid.uuid4()}",
                "entity_type": "DiagramNode",
                "entity_id": str(uuid.uuid4()),
                "action": "create",
                "depends_on": [],
                "value": {},
                "explanation": f"Vista de la clase {(element.get('value') or {}).get('name', index + 1)}.",
            }
            if reusable is None:
                operations.append(node)
                nodes.append(node)
            node_by_element[element_id] = node
        node_value = node["value"]
        node_value.update({
            "diagram": diagram_id,
            "element": element_id,
            "x": node_value.get("x", 120 + index * 360),
            "y": node_value.get("y", 160),
            "width": node_value.get("width", 220),
            "height": node_value.get("height", 130),
            "properties": node_value.get("properties") or {},
        })
        node_value.pop("diagram_id", None)
        node_value.pop("element_id", None)
        node["depends_on"] = list(dict.fromkeys([*(node.get("depends_on") or []), element["id"]]))

    source_node = node_by_element[element_ids[0]]
    target_node = node_by_element[element_ids[1]]
    edge = next((
        operation for operation in operations
        if operation.get("action") == "create" and operation.get("entity_type") == "DiagramEdge"
    ), None)
    if edge is None:
        edge = {
            "id": f"auto-edge-{uuid.uuid4()}",
            "entity_type": "DiagramEdge",
            "entity_id": str(uuid.uuid4()),
            "action": "create",
            "depends_on": [],
            "value": {},
            "explanation": "Conector visual de la asociación muchos a muchos.",
        }
        operations.append(edge)
    edge["value"] = {
        "diagram": diagram_id,
        "relationship": relationship["entity_id"],
        "source_node": source_node["entity_id"],
        "target_node": target_node["entity_id"],
        "properties": {"presentation": {"label": "* ↔ *"}},
    }
    edge["depends_on"] = list(dict.fromkeys([
        *(edge.get("depends_on") or []), relationship["id"], source_node["id"], target_node["id"],
    ]))
    diagnostics.append({
        "rule_id": "ai.operation.explicit-many-to-many-completed",
        "severity": "info",
        "message": "Se completaron los extremos, nodos y conector de la asociación muchos a muchos solicitada.",
        "evidence": {"elements": element_ids, "diagram_id": diagram_id},
        "repair": {"kind": "complete_explicit_many_to_many_graph"},
    })


def _complete_current_diagram_graph(operations, diagnostics, context):
    """Complete mechanical diagram references for any number of created elements."""
    diagram_id = ((context or {}).get("diagram") or {}).get("id")
    if not diagram_id:
        return
    by_operation_id = {operation["id"]: operation for operation in operations}
    element_operations = [
        operation for operation in operations
        if operation.get("action") == "create" and operation.get("entity_type") == "UmlElement"
    ]
    node_operations = [
        operation for operation in operations
        if operation.get("action") == "create" and operation.get("entity_type") == "DiagramNode"
    ]
    repaired = False

    node_by_element = {}
    for node in node_operations:
        value = node.setdefault("value", {})
        element_id = value.get("element") or value.get("element_id")
        if not element_id:
            dependencies = [by_operation_id.get(item) for item in node.get("depends_on", [])]
            candidates = [item for item in dependencies if item and item.get("entity_type") == "UmlElement"]
            if len(candidates) == 1:
                element_id = candidates[0].get("entity_id")
        if element_id:
            value["element"] = element_id
            value.pop("element_id", None)
            node_by_element[str(element_id)] = node

    for index, element in enumerate(element_operations):
        element_id = str(element["entity_id"])
        node = node_by_element.get(element_id)
        if node is None:
            node = {
                "id": f"auto-node-{uuid.uuid4()}",
                "entity_type": "DiagramNode",
                "entity_id": str(uuid.uuid4()),
                "action": "create",
                "depends_on": [element["id"]],
                "value": {"element": element_id},
                "explanation": f"Vista de {(element.get('value') or {}).get('name', 'elemento UML')} en el diagrama actual.",
            }
            operations.append(node)
            node_operations.append(node)
            node_by_element[element_id] = node
            repaired = True
        value = node["value"]
        defaults = {
            "diagram": diagram_id,
            "element": element_id,
            "x": 120 + (index % 3) * 320,
            "y": 140 + (index // 3) * 210,
            "width": 220,
            "height": 130,
            "properties": {},
        }
        for field, default in defaults.items():
            if field not in value:
                value[field] = default
                repaired = True
        value.pop("diagram_id", None)
        value.pop("element_id", None)
        if element["id"] not in node.setdefault("depends_on", []):
            node["depends_on"].append(element["id"])
            repaired = True

    relationship_operations = [
        operation for operation in operations
        if operation.get("action") == "create" and operation.get("entity_type") == "UmlRelationship"
    ]
    edge_operations = [
        operation for operation in operations
        if operation.get("action") == "create" and operation.get("entity_type") == "DiagramEdge"
    ]
    edge_by_relationship = {}
    for edge in edge_operations:
        value = edge.setdefault("value", {})
        relationship_id = value.get("relationship") or value.get("relationship_id")
        if not relationship_id:
            dependencies = [by_operation_id.get(item) for item in edge.get("depends_on", [])]
            candidates = [item for item in dependencies if item and item.get("entity_type") == "UmlRelationship"]
            if len(candidates) == 1:
                relationship_id = candidates[0].get("entity_id")
        if relationship_id:
            value["relationship"] = relationship_id
            value.pop("relationship_id", None)
            edge_by_relationship[str(relationship_id)] = edge

    for relationship in relationship_operations:
        relationship_id = str(relationship["entity_id"])
        relationship_value = relationship.get("value") or {}
        source_node = node_by_element.get(str(relationship_value.get("source") or relationship_value.get("source_id")))
        target_node = node_by_element.get(str(relationship_value.get("target") or relationship_value.get("target_id")))
        if not source_node or not target_node:
            continue
        edge = edge_by_relationship.get(relationship_id)
        if edge is None:
            edge = {
                "id": f"auto-edge-{uuid.uuid4()}",
                "entity_type": "DiagramEdge",
                "entity_id": str(uuid.uuid4()),
                "action": "create",
                "depends_on": [],
                "value": {},
                "explanation": "Conector visual de la relación propuesta.",
            }
            operations.append(edge)
            edge_operations.append(edge)
            edge_by_relationship[relationship_id] = edge
            repaired = True
        expected = {
            "diagram": diagram_id,
            "relationship": relationship_id,
            "source_node": str(source_node["entity_id"]),
            "target_node": str(target_node["entity_id"]),
        }
        edge_value = edge.setdefault("value", {})
        for field, expected_value in expected.items():
            if edge_value.get(field) != expected_value:
                edge_value[field] = expected_value
                repaired = True
        edge_value.setdefault("properties", {})
        for alias in ("diagram_id", "relationship_id", "source_node_id", "target_node_id"):
            edge_value.pop(alias, None)
        edge["depends_on"] = list(dict.fromkeys([
            *(edge.get("depends_on") or []), relationship["id"], source_node["id"], target_node["id"],
        ]))

    if repaired:
        diagnostics.append({
            "rule_id": "ai.operation.current-diagram-graph-completed",
            "severity": "info",
            "message": "Se completaron automáticamente las vistas y conexiones del diagrama actual.",
            "evidence": {
                "diagram_id": str(diagram_id),
                "nodes": len(node_operations),
                "edges": len(edge_operations),
            },
            "repair": {"kind": "complete_current_diagram_graph"},
        })


def _remove_resolved_technical_questions(questions, operations, context, diagnostics, prompt=""):
    if not questions:
        return questions
    diagram_id = ((context or {}).get("diagram") or {}).get("id")
    has_complete_graph = any(item.get("entity_type") == "DiagramEdge" for item in operations)
    has_semantic_relationship = any(
        item.get("entity_type") == "UmlRelationship" and item.get("action") == "create"
        for item in operations
    )
    request_text = "".join(
        character for character in unicodedata.normalize("NFKD", _latest_user_request(prompt).casefold())
        if not unicodedata.combining(character)
    )
    explicitly_requests_connection = any(
        term in request_text for term in ("relaciona", "asocia", "conecta", "conexi", "une ", "unir")
    )
    visual_views_replaced = any(
        item.get("rule_id") == "ai.operation.visual-views-replaced" for item in diagnostics
    )
    kept = []
    removed = []
    for question in questions:
        normalized = question.casefold()
        normalized_plain = "".join(
            character for character in unicodedata.normalize("NFKD", normalized)
            if not unicodedata.combining(character)
        )
        is_internal_id = " id " in f" {normalized} " or "identificador" in normalized
        is_current_diagram = "diagrama" in normalized and diagram_id
        is_stale_visual_confirmation = (
            visual_views_replaced
            and any(term in normalized for term in ("figura", "visual", "reemplaz", "elementos uml"))
            and any(term in normalized for term in ("deseado", "confirm", "elimin", "comportamiento"))
        )
        is_resolved_relationship_choice = (
            has_semantic_relationship
            and explicitly_requests_connection
            and "tipo de relacion" in normalized_plain
        )
        if (
            (has_complete_graph and (is_internal_id or is_current_diagram))
            or is_stale_visual_confirmation
            or is_resolved_relationship_choice
        ):
            removed.append(question)
        else:
            kept.append(question)
    if removed:
        diagnostics.append({
            "rule_id": "ai.question.technical-detail-resolved",
            "severity": "info",
            "message": "Se resolvieron internamente preguntas técnicas de IDs y del diagrama actual.",
            "evidence": {"count": len(removed)},
            "repair": {"kind": "remove_resolved_technical_questions"},
        })
    return kept


def _remove_redundant_embedded_nodes(operations, diagnostics):
    """Remove a provider convenience field when explicit DiagramNode operations exist."""
    has_explicit_nodes = any(item.get("entity_type") == "DiagramNode" for item in operations)
    if not has_explicit_nodes:
        return
    for operation in operations:
        value = operation.get("value")
        if operation.get("entity_type") != "UmlElement" or not isinstance(value, dict):
            continue
        if "diagram_nodes" not in value:
            continue
        value.pop("diagram_nodes")
        diagnostics.append({
            "rule_id": "ai.operation.redundant-embedded-nodes",
            "severity": "info",
            "message": "Se eliminó una representación visual duplicada; se conservaron los nodos explícitos.",
            "evidence": {"operation_id": operation["id"]},
            "repair": {"kind": "remove_redundant_embedded_nodes"},
        })


def _proposal_schema(include_explanation=False):
    properties = {
        "operations" if not include_explanation else "suggestions": {
            "type": "array",
            "items": _OPERATION_SCHEMA,
        },
        "warnings": {"type": "array", "items": {"type": "string"}},
    }
    required = ["operations" if not include_explanation else "suggestions", "warnings"]
    if include_explanation:
        properties["explanation"] = {"type": "string"}
        required.append("explanation")
    else:
        properties.update({
            "questions": {"type": "array", "items": {"type": "string"}},
            "assumptions": {"type": "array", "items": {"type": "string"}},
            "diagnostics": {"type": "array", "items": {"type": "object"}},
        })
        required.extend(["questions", "assumptions", "diagnostics"])
    return {
        "type": "object",
        "properties": properties,
        "required": required,
        "additionalProperties": False,
    }


def _json_safe(value):
    if isinstance(value, uuid.UUID):
        return str(value)
    if isinstance(value, dict):
        return {key: _json_safe(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_json_safe(item) for item in value]
    return value


def authorized_context(project, diagram=None, selection=None):
    limit = int(getattr(settings, "AI_MAX_CONTEXT_ITEMS", 1000))
    elements = list(project.elements.values("id", "metaclass", "name", "package_id", "properties"))[:limit]
    relationships = list(project.relationships.values("id", "relationship_type", "source_id", "target_id", "properties"))[:limit]
    selected_ids = {str(item) for item in (selection or [])}
    if selected_ids:
        related_relationships = [
            item for item in relationships
            if str(item["source_id"]) in selected_ids or str(item["target_id"]) in selected_ids
        ]
        related_ids = set(selected_ids)
        for item in related_relationships:
            related_ids.update((str(item["source_id"]), str(item["target_id"])))
        elements = [item for item in elements if str(item["id"]) in related_ids]
        relationships = related_relationships
    context = {
        "project": {"id": str(project.id), "name": project.name, "mda_level": project.mda_level, "revision": project.revision},
        "registry_version": "uml-2.5.1-subset-2",
        "visual_registry": {
            "node_shapes": {library: list(shapes) for library, shapes in _VISUAL_NODE_SHAPES.items()},
            "edge_shapes": ["line", "arrow", "double-arrow", "dashed", "dashed-arrow", "orthogonal", "curved", "er-one", "er-zero-one", "er-many", "er-one-many", "er-zero-many"],
        },
        "packages": list(project.packages.values("id", "name", "parent_id", "properties"))[:limit],
        "diagrams": list(project.diagrams.values("id", "name", "diagram_type"))[:limit],
        "elements": elements,
        "relationships": relationships,
    }
    if diagram is not None:
        context["diagram"] = {"id": str(diagram.id), "name": diagram.name, "diagram_type": diagram.diagram_type}
        nodes = list(diagram.nodes.values("id", "element_id", "x", "y", "width", "height", "properties"))[:limit]
        if selected_ids:
            related_element_ids = {str(item["id"]) for item in elements}
            nodes = [item for item in nodes if item["element_id"] and str(item["element_id"]) in related_element_ids]
        node_ids = {str(item["id"]) for item in nodes}
        edges = list(diagram.edges.values(
            "id", "relationship_id", "source_node_id", "target_node_id", "properties"
        ))[:limit]
        if selected_ids:
            edges = [
                item for item in edges
                if str(item["source_node_id"]) in node_ids and str(item["target_node_id"]) in node_ids
            ]
        context["diagram"]["nodes"] = nodes
        context["diagram"]["edges"] = edges
    if selected_ids:
        context["selection"] = [item for item in elements if str(item["id"]) in selected_ids]
    return _json_safe(context)


def _validate_proposal(payload, *, context=None, prompt=""):
    if not isinstance(payload, dict):
        raise AiProviderError("La respuesta de IA debe ser un objeto JSON.")
    operations = payload.get("operations", [])
    if not isinstance(operations, list):
        raise AiProviderError("La propuesta supera el límite de operaciones.")
    warnings = payload.get("warnings", [])
    if not isinstance(warnings, list):
        warnings = [str(warnings)]
    questions = payload.get("questions", [])
    assumptions = payload.get("assumptions", [])
    diagnostics = payload.get("diagnostics", [])
    if not isinstance(questions, list) or not all(isinstance(item, str) for item in questions):
        raise AiProviderError("Las preguntas de la propuesta no son válidas.")
    if not isinstance(assumptions, list) or not all(isinstance(item, str) for item in assumptions):
        raise AiProviderError("Los supuestos de la propuesta no son válidos.")
    if not isinstance(diagnostics, list) or not all(isinstance(item, dict) for item in diagnostics):
        raise AiProviderError("Los diagnósticos de la propuesta no son válidos.")
    diagnostics = list(diagnostics)
    operations = _expand_batched_create_operations(operations, diagnostics)
    _normalize_provider_field_aliases(operations, diagnostics)
    _normalize_package_figures_as_elements(operations, diagnostics)
    _adapt_explicit_visual_shape_request(operations, diagnostics, context, prompt)
    if len(operations) > int(getattr(settings, "AI_MAX_OPERATIONS", 200)):
        raise AiProviderError("La propuesta supera el límite de operaciones.")
    for operation in operations:
        if not isinstance(operation, dict):
            raise AiProviderError("Cada operación debe ser un objeto.")
        operation.setdefault("id", str(uuid.uuid4()))
        if not isinstance(operation.get("id"), str) or not operation["id"].strip():
            raise AiProviderError("Cada operación requiere un identificador.")
        dependencies = operation.get("depends_on", [])
        if not isinstance(dependencies, list) or not all(isinstance(item, str) for item in dependencies):
            raise AiProviderError("Las dependencias de la operación no son válidas.")
        if operation.get("entity_type") not in _AI_ENTITY_TYPES:
            raise AiProviderError("Entidad no permitida en la propuesta.")
        action = operation.get("action")
        if action not in {"create", "update", "delete"}:
            raise AiProviderError("Acción no permitida en la propuesta.")
        value, repaired = _normalize_operation_value(operation)
        operation["value"] = value
        if repaired:
            diagnostics.append({
                "rule_id": "ai.operation.path-value-normalized",
                "severity": "info",
                "message": f"Se normalizó la actualización parcial de {operation['path']}.",
                "evidence": {"operation_id": operation["id"], "path": operation["path"]},
                "repair": {"kind": "wrap_path_value"},
            })
        if operation.get("entity_type") == "UmlElement" and (action == "create" or "metaclass" in value) and value.get("metaclass") not in ELEMENT_TYPES:
            invalid_metaclass = str(value.get("metaclass") or "(vacía)")[:80]
            raise AiProviderError(f"Metaclase no registrada: {invalid_metaclass}.")
        if operation.get("entity_type") == "UmlRelationship" and (action == "create" or "relationship_type" in value) and value.get("relationship_type") not in RELATIONSHIP_TYPES:
            raise AiProviderError("Relación no registrada.")
        if operation.get("entity_type") == "Diagram" and (action == "create" or "diagram_type" in value) and value.get("diagram_type") not in DIAGRAM_TYPES:
            raise AiProviderError("Tipo de diagrama no registrado.")
    _remove_redundant_embedded_nodes(operations, diagnostics)
    _normalize_created_entity_ids(operations, diagnostics)
    _complete_explicit_many_to_many_graph(operations, diagnostics, context, prompt)
    _complete_current_diagram_graph(operations, diagnostics, context)
    questions = _remove_resolved_technical_questions(questions, operations, context, diagnostics, prompt)
    if len(operations) > int(getattr(settings, "AI_MAX_OPERATIONS", 200)):
        raise AiProviderError("La propuesta supera el límite de operaciones.")
    _order_operations_by_dependencies(operations, diagnostics)
    return {
        "operations": operations,
        "questions": questions,
        "assumptions": assumptions,
        "warnings": warnings,
        "diagnostics": diagnostics,
    }


def _provider_endpoint(base_url):
    normalized = base_url.rstrip("/")
    if normalized.endswith("/chat/completions"):
        return normalized
    return f"{normalized}/chat/completions"


def _provider_tool(include_explanation=False):
    return {
        "type": "function",
        "function": {
            "name": "submit_uml_explanation" if include_explanation else "submit_uml_proposal",
            "description": (
                "Devuelve una explicación del modelo UML y sugerencias opcionales que el usuario deberá aprobar."
                if include_explanation
                else "Devuelve operaciones UML propuestas. Nunca las ejecuta; el usuario deberá revisarlas y aprobarlas."
            ),
            "parameters": _proposal_schema(include_explanation=include_explanation),
        },
    }


def _system_prompt(include_explanation=False):
    task = (
        "Explica el modelo y, solo si aporta valor, devuelve sugerencias estructuradas."
        if include_explanation
        else "Convierte la solicitud en una propuesta de operaciones estructuradas."
    )
    return (
        "Eres un asistente experto en UML 2.5.1 integrado en un modelador colaborativo. "
        f"{task} No ejecutas cambios ni afirmas que fueron aplicados. "
        "Usa exclusivamente IDs presentes en el contexto para actualizar o eliminar. "
        "Para crear entidades relacionadas genera UUID válidos y expresa el orden mediante depends_on. "
        "El id de una operación es solo un identificador lógico. Para cada create incluye además entity_id con un UUID v4 válido, "
        "y usa exactamente ese entity_id en las referencias de otras operaciones. Para agregar una figura al diagrama actual, "
        "crea primero su UmlElement y después un DiagramNode explícito que dependa de esa operación; no uses campos embebidos como diagram_nodes. "
        "Usa exactamente metaclass para el tipo UML, element para DiagramNode, source y target para UmlRelationship, "
        "y relationship, source_node y target_node para DiagramEdge; no uses nombres terminados en _ref ni meta_class. "
        "Una figura de paquete en el lienzo es UmlElement con metaclass='Package'; UmlPackage se usa solo como contenedor del repositorio y nunca "
        "como extremo de UmlRelationship ni como element de DiagramNode. Si el usuario pide simplemente relacionar dos elementos sin indicar tipo, "
        "usa Association y decláralo como supuesto, sin añadir una pregunta bloqueante. "
        "En properties.attributes devuelve una lista de textos como '+ nombre: String', no objetos. "
        "Distingue semántica UML de figuras auxiliares. Si el usuario pide explícitamente cuadrado, rectángulo, rombo, elipse, círculo u otra figura visual, "
        "NO crees UmlElement ni clases: crea DiagramNode sin element, con properties.kind='visual', la library y shape exactas del visual_registry, label y style={}. "
        "Si pide reemplazar una clase existente por una figura visual, sustituye únicamente su DiagramNode, conserva el UmlElement y sus relaciones semánticas, "
        "mantén el nombre y la posición aproximada, y elimina el UmlElement solo si el usuario lo solicita explícitamente. "
        "Para asociar figuras visuales crea DiagramEdge sin relationship, con properties.kind='visual', library='arrows', shape='line', handles y style permitidos. "
        "Si falta una decisión importante, devuelve preguntas y ninguna operación insegura. "
        "Para actualizar, incluye entity_id y usa un objeto completo en value, o indica path y coloca en value "
        "el valor exacto de esa ruta. Para editar atributos de una clase usa path=properties.attributes y devuelve "
        "la lista completa resultante, conservando los atributos que el usuario no haya pedido eliminar. "
        "Para renombrar usa path=name. "
        "value siempre debe ser un objeto en operaciones create: crea una operación independiente por cada entidad, nunca una lista. "
        "Si el usuario pide dos clases en el diagrama, crea dos UmlElement y dos DiagramNode. Si también pide relacionarlas, "
        "crea un UmlRelationship y un DiagramEdge que una los dos nodos. Una relación muchos a muchos usa "
        "relationship_type=Association y properties.multiplicity con source='*' y target='*'. La arista debe depender de la relación y ambos nodos. "
        f"Metaclases permitidas: {', '.join(ELEMENT_TYPES)}. "
        f"Relaciones permitidas: {', '.join(RELATIONSHIP_TYPES)}. "
        f"Diagramas permitidos: {', '.join(DIAGRAM_TYPES)}. "
        "No incluyas secretos, comandos, código ejecutable ni entidades fuera del esquema."
    )


def _decode_provider_payload(provider_payload, tool_name):
    if not isinstance(provider_payload, dict) or not isinstance(provider_payload.get("choices"), list):
        return provider_payload
    try:
        message = provider_payload["choices"][0]["message"]
        for call in message.get("tool_calls") or []:
            function = call.get("function") or {}
            if function.get("name") == tool_name:
                arguments = function.get("arguments", "{}")
                return json.loads(arguments) if isinstance(arguments, str) else arguments
        content = message.get("content", "{}")
        if not isinstance(content, str):
            return content
        stripped = content.strip()
        if stripped.startswith("```"):
            lines = stripped.splitlines()
            stripped = "\n".join(lines[1:-1]) if len(lines) > 2 else "{}"
        return json.loads(stripped)
    except (ValueError, KeyError, IndexError, TypeError, AttributeError) as exc:
        raise AiProviderError("La respuesta del proveedor no contiene una propuesta estructurada válida.") from exc


def _post_provider_json(base_url, payload, headers, api_key):
    request = urllib.request.Request(
        _provider_endpoint(base_url),
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=int(getattr(settings, "AI_TIMEOUT_SECONDS", 20))) as response:
            raw = response.read()
    except urllib.error.HTTPError as exc:
        raise _http_provider_error(exc, api_key=api_key) from exc
    except (urllib.error.URLError, TimeoutError, OSError, http.client.HTTPException) as exc:
        raise AiProviderTransportError(
            "El proveedor de IA cerró la conexión o no respondió a tiempo. Puedes reintentar sin perder cambios."
        ) from exc
    try:
        return json.loads(raw.decode("utf-8"))
    except (ValueError, TypeError, UnicodeError) as exc:
        raise AiProviderError("La respuesta del proveedor no contiene JSON estructurado válido.") from exc


def _request_provider(prompt, context, *, include_explanation=False):
    base_url = getattr(settings, "AI_BASE_URL", "").strip()
    if not base_url:
        raise AiProviderError("El proveedor de IA no está configurado.")
    tool = _provider_tool(include_explanation=include_explanation)
    messages = [
        {"role": "system", "content": _system_prompt(include_explanation=include_explanation)},
        {
            "role": "user",
            "content": (
                f"Solicitud del usuario:\n{prompt}\n\n"
                "Contexto autorizado del proyecto (JSON):\n"
                f"{json.dumps(context, ensure_ascii=False, separators=(',', ':'))}"
            ),
        },
    ]
    body = {
        "model": getattr(settings, "AI_MODEL", "mistralai/mistral-large-2512"),
        "messages": messages,
        "tools": [tool],
        "tool_choice": {"type": "function", "function": {"name": tool["function"]["name"]}},
        "temperature": float(getattr(settings, "AI_TEMPERATURE", 0.1)),
        "max_tokens": int(getattr(settings, "AI_MAX_TOKENS", 4096)),
    }
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "User-Agent": "sw1-uml-modeler/1.0",
    }
    api_key = getattr(settings, "AI_API_KEY", "")
    if "api.xkiro.com" in base_url and not api_key:
        raise AiProviderError("La clave AI_API_KEY de xKiro no está configurada en el backend.")
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"
    provider_payload = None
    try:
        provider_payload = _post_provider_json(base_url, body, headers, api_key)
        return _decode_provider_payload(provider_payload, tool["function"]["name"])
    except AiProviderError as primary_error:
        # Some compatible routes occasionally return a valid 200 response with
        # empty content instead of the forced tool call. A single JSON-mode
        # fallback also covers a prematurely closed tool-call connection. It
        # uses a different request body while preserving the closed contract.
        has_provider_response = isinstance(provider_payload, dict) and isinstance(provider_payload.get("choices"), list)
        if not has_provider_response and not isinstance(primary_error, AiProviderTransportError):
            raise
        fallback = {
            "model": body["model"],
            "messages": messages + [{
                "role": "user",
                "content": (
                    "Devuelve ahora exclusivamente un objeto JSON válido que cumpla este esquema, sin Markdown: "
                    f"{json.dumps(tool['function']['parameters'], ensure_ascii=False, separators=(',', ':'))}"
                ),
            }],
            "response_format": {"type": "json_object"},
            "temperature": body["temperature"],
            "max_tokens": body["max_tokens"],
        }
        try:
            fallback_payload = _post_provider_json(base_url, fallback, headers, api_key)
        except AiProviderTransportError as fallback_error:
            raise AiProviderError(
                "El proveedor de IA cerró la conexión en ambos intentos. Inténtalo de nuevo o configura otro modelo compatible."
            ) from fallback_error
        try:
            return _decode_provider_payload(fallback_payload, tool["function"]["name"])
        except AiProviderError as fallback_error:
            raise AiProviderError("El proveedor devolvió una respuesta vacía o no estructurada después del reintento.") from fallback_error


def request_proposal(prompt, context):
    return validate_proposal(_request_provider(prompt, context), context=context, prompt=prompt)


def validate_proposal(payload, *, context=None, prompt=""):
    return _validate_proposal(copy.deepcopy(payload), context=context, prompt=prompt)


def request_explanation(prompt, context):
    payload = _request_provider(prompt, context, include_explanation=True)
    if not isinstance(payload, dict):
        raise AiProviderError("La explicación de IA debe ser un objeto JSON.")
    explanation = payload.get("explanation") or payload.get("answer")
    if not isinstance(explanation, str) or not explanation.strip():
        raise AiProviderError("La respuesta de IA no contiene una explicación.")
    validated = _validate_proposal(
        {"operations": payload.get("suggestions", []), "warnings": payload.get("warnings", [])},
        context=context,
        prompt=prompt,
    )
    return {"explanation": explanation.strip(), "suggestions": validated["operations"], "warnings": validated["warnings"]}
