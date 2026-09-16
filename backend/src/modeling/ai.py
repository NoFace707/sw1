import json
import uuid
import urllib.error
import urllib.request

from django.conf import settings

from .registry import DIAGRAM_TYPES, ELEMENT_TYPES, RELATIONSHIP_TYPES


class AiProviderError(Exception):
    pass


def _json_safe(value):
    if isinstance(value, uuid.UUID):
        return str(value)
    if isinstance(value, dict):
        return {key: _json_safe(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_json_safe(item) for item in value]
    return value


def authorized_context(project, diagram=None, selection=None):
    context = {
        "project": {"id": str(project.id), "name": project.name, "mda_level": project.mda_level},
        "registry_version": "uml-2.5.1-subset-2",
        "elements": list(project.elements.values("id", "metaclass", "name", "package_id", "properties"))[:5000],
        "relationships": list(project.relationships.values("id", "relationship_type", "source_id", "target_id", "properties"))[:5000],
    }
    if diagram is not None:
        context["diagram"] = {"id": str(diagram.id), "name": diagram.name, "diagram_type": diagram.diagram_type}
    if selection:
        allowed = {str(item) for item in selection}
        context["selection"] = [item for item in context["elements"] if str(item["id"]) in allowed]
    return _json_safe(context)


def _validate_proposal(payload):
    if not isinstance(payload, dict):
        raise AiProviderError("La respuesta de IA debe ser un objeto JSON.")
    operations = payload.get("operations", [])
    if not isinstance(operations, list) or len(operations) > int(getattr(settings, "AI_MAX_OPERATIONS", 200)):
        raise AiProviderError("La propuesta supera el límite de operaciones.")
    warnings = payload.get("warnings", [])
    if not isinstance(warnings, list):
        warnings = [str(warnings)]
    for operation in operations:
        if not isinstance(operation, dict):
            raise AiProviderError("Cada operación debe ser un objeto.")
        operation.setdefault("id", str(uuid.uuid4()))
        if operation.get("entity_type") not in {"UmlPackage", "UmlElement", "UmlRelationship", "Diagram", "DiagramNode", "DiagramEdge"}:
            raise AiProviderError("Entidad no permitida en la propuesta.")
        value = operation.get("value", operation)
        if operation.get("entity_type") == "UmlElement" and value.get("metaclass") not in ELEMENT_TYPES:
            raise AiProviderError("Metaclase no registrada.")
        if operation.get("entity_type") == "UmlRelationship" and value.get("relationship_type") not in RELATIONSHIP_TYPES:
            raise AiProviderError("Relación no registrada.")
        if operation.get("entity_type") == "Diagram" and value.get("diagram_type") not in DIAGRAM_TYPES:
            raise AiProviderError("Tipo de diagrama no registrado.")
    return {"operations": operations, "warnings": warnings}


def _request_provider(prompt, context):
    base_url = getattr(settings, "AI_BASE_URL", "").strip()
    if not base_url:
        raise AiProviderError("El proveedor de IA no está configurado.")
    body = json.dumps({"model": getattr(settings, "AI_MODEL", "Qwen2.5-Coder-1.5B-Q4"), "prompt": prompt, "context": context, "response_format": "json"}).encode("utf-8")
    headers = {"Content-Type": "application/json"}
    api_key = getattr(settings, "AI_API_KEY", "")
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"
    request = urllib.request.Request(base_url, data=body, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(request, timeout=int(getattr(settings, "AI_TIMEOUT_SECONDS", 20))) as response:
            raw = response.read()
    except (urllib.error.URLError, TimeoutError) as exc:
        raise AiProviderError("No se pudo contactar al proveedor de IA.") from exc
    try:
        provider_payload = json.loads(raw.decode("utf-8"))
        # Support OpenAI-compatible content while keeping the stored proposal canonical.
        if isinstance(provider_payload, dict) and isinstance(provider_payload.get("choices"), list):
            content = provider_payload["choices"][0].get("message", {}).get("content", "{}")
            provider_payload = json.loads(content) if isinstance(content, str) else content
        return provider_payload
    except (ValueError, KeyError, IndexError, TypeError) as exc:
        raise AiProviderError("La respuesta del proveedor no contiene JSON estructurado válido.") from exc


def request_proposal(prompt, context):
    return _validate_proposal(_request_provider(prompt, context))


def request_explanation(prompt, context):
    payload = _request_provider(prompt, context)
    if not isinstance(payload, dict):
        raise AiProviderError("La explicación de IA debe ser un objeto JSON.")
    explanation = payload.get("explanation") or payload.get("answer")
    if not isinstance(explanation, str) or not explanation.strip():
        raise AiProviderError("La respuesta de IA no contiene una explicación.")
    validated = _validate_proposal({"operations": payload.get("suggestions", []), "warnings": payload.get("warnings", [])})
    return {"explanation": explanation.strip(), "suggestions": validated["operations"], "warnings": validated["warnings"]}
