import hashlib
import json
import secrets
import uuid
from pathlib import Path
from urllib import error as url_error
from urllib import request as url_request
from datetime import timedelta

from django.conf import settings
from django.db import transaction
from django.core.serializers.json import DjangoJSONEncoder
from django.core.cache import cache
from django.http import HttpResponse
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import AiProposal, Diagram, DiagramEdge, DiagramNode, InviteCode, ModelOperation, Project, ProjectMembership, ProjectSnapshot, SyncConflict, UmlElement, UmlPackage, UmlRelationship
from .permissions import require_membership, require_owner
from .registry import DIAGRAM_TYPES, RELATIONSHIP_TYPES, registry_payload
from .serializers import (ConflictSerializer, DiagramEdgeSerializer, DiagramNodeSerializer, DiagramSerializer, ElementSerializer, InviteSerializer, MembershipSerializer, OperationSerializer, PackageSerializer, ProjectSerializer, RelationshipSerializer, SnapshotSerializer, CreateProjectSerializer)
from .services import record_operation, snapshot_project
from .validators import ValidationResult, result_payload, validate_element, validate_relationship
from .ai import AiProviderError, authorized_context, request_explanation, request_proposal
from .interchange import parse_exchange, write_exchange


def _project_or_404(user, project_id):
    try:
        project = Project.objects.get(pk=project_id)
    except (Project.DoesNotExist, ValueError) as exc:
        from rest_framework.exceptions import NotFound
        raise NotFound("Proyecto no encontrado.") from exc
    require_membership(user, project)
    return project


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def registry(request):
    return Response(registry_payload())


@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def projects(request):
    if request.method == "GET":
        memberships = ProjectMembership.objects.filter(user=request.user).select_related("project", "project__owner")
        return Response(ProjectSerializer([item.project for item in memberships], many=True, context={"request": request}).data)
    serializer = CreateProjectSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    create_initial_diagram = serializer.validated_data.pop("create_initial_diagram", False)
    with transaction.atomic():
        project = serializer.save(owner=request.user)
        ProjectMembership.objects.create(project=project, user=request.user, role=ProjectMembership.Role.OWNER)
        if create_initial_diagram:
            Diagram.objects.create(project=project, name="Diagrama 1", diagram_type="class", created_by=request.user)
        snapshot_project(project, reason="create", created_by=request.user)
    return Response(ProjectSerializer(project, context={"request": request}).data, status=status.HTTP_201_CREATED)


@api_view(["GET", "PATCH", "DELETE"])
@permission_classes([IsAuthenticated])
def project_detail(request, project_id):
    project = _project_or_404(request.user, project_id)
    if request.method == "GET":
        return Response(ProjectSerializer(project, context={"request": request}).data)
    if request.method == "DELETE":
        require_owner(request.user, project)
        project.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
    require_owner(request.user, project)
    previous = _json_value(ProjectSerializer(project, context={"request": request}).data)
    serializer = ProjectSerializer(project, data=request.data, partial=True, context={"request": request})
    serializer.is_valid(raise_exception=True)
    serializer.save()
    current = _json_value(serializer.data)
    if current != previous:
        changed_fields = [field for field in ("name", "description", "mda_level") if previous.get(field) != current.get(field)]
        record_operation(project_id=project.id, author=request.user, origin=ModelOperation.Origin.USER, entity_type="Project", entity_id=project.id, action="update", path=changed_fields[0] if len(changed_fields) == 1 else "", previous_value=previous, new_value=current, base_revision=project.revision)
    return Response(serializer.data)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def project_members(request, project_id):
    project = _project_or_404(request.user, project_id)
    return Response(MembershipSerializer(project.memberships.select_related("user"), many=True).data)


@api_view(["PATCH", "DELETE"])
@permission_classes([IsAuthenticated])
def project_member_detail(request, project_id, member_id):
    project = _project_or_404(request.user, project_id)
    require_owner(request.user, project)
    try:
        membership = project.memberships.select_related("user").get(pk=member_id)
    except ProjectMembership.DoesNotExist as exc:
        from rest_framework.exceptions import NotFound
        raise NotFound("Membresía no encontrada.") from exc
    if membership.role == ProjectMembership.Role.OWNER:
        return Response({"detail": "El propietario no puede degradarse ni eliminarse."}, status=status.HTTP_400_BAD_REQUEST)
    if request.method == "DELETE":
        membership.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
    role = request.data.get("role")
    if role not in {ProjectMembership.Role.EDITOR, ProjectMembership.Role.VIEWER}:
        return Response({"detail": "Rol inválido."}, status=status.HTTP_400_BAD_REQUEST)
    membership.role = role
    membership.save(update_fields=("role",))
    return Response(MembershipSerializer(membership).data)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def websocket_ticket(request, project_id):
    project = _project_or_404(request.user, project_id)
    token = secrets.token_urlsafe(24)
    cache.set(f"ws-ticket:{token}", {"user_id": request.user.id, "project_id": str(project.id)}, timeout=60)
    return Response({"ticket": token, "expires_in": 60, "project_id": str(project.id)})


def _resource_queryset(project, resource):
    return {
        "packages": project.packages.all(),
        "elements": project.elements.select_related("package", "created_by").all(),
        "relationships": project.relationships.select_related("source", "target").all(),
        "diagrams": project.diagrams.select_related("created_by").all(),
    }[resource]


def _resource_serializer(resource):
    return {"packages": PackageSerializer, "elements": ElementSerializer, "relationships": RelationshipSerializer, "diagrams": DiagramSerializer}[resource]


def _json_value(value):
    return json.loads(json.dumps(value, cls=DjangoJSONEncoder))


def _paged(request, queryset, serializer_class):
    limit_value = request.query_params.get("limit")
    if limit_value is None and request.query_params.get("offset") is None:
        return serializer_class(queryset, many=True, context={"request": request}).data
    try:
        limit = max(1, min(int(limit_value or 50), 200))
        offset = max(0, int(request.query_params.get("offset", 0)))
    except ValueError:
        limit, offset = 50, 0
    total = queryset.count()
    return {"count": total, "next_offset": offset + limit if offset + limit < total else None, "results": serializer_class(queryset[offset:offset + limit], many=True, context={"request": request}).data}


@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def project_resource(request, project_id, resource):
    project = _project_or_404(request.user, project_id)
    if resource not in {"packages", "elements", "relationships", "diagrams"}:
        return Response({"detail": "Recurso no encontrado."}, status=status.HTTP_404_NOT_FOUND)
    serializer_class = _resource_serializer(resource)
    if request.method == "GET":
        return Response(_paged(request, _resource_queryset(project, resource), serializer_class))
    require_membership(request.user, project, write=True)
    serializer = serializer_class(data=request.data, context={"request": request})
    serializer.is_valid(raise_exception=True)
    data = serializer.validated_data
    if resource == "packages":
        if data.get("parent") and data["parent"].project_id != project.id:
            return Response({"detail": "El paquete padre no pertenece al proyecto."}, status=status.HTTP_400_BAD_REQUEST)
        obj = UmlPackage.objects.create(project=project, **data)
        entity_type = "UmlPackage"
    elif resource == "elements":
        if project.elements.count() >= int(getattr(settings, "MAX_PROJECT_ELEMENTS", 5000)):
            return Response({"detail": "El proyecto alcanzó el límite de elementos configurado."}, status=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE)
        if data.get("package") and data["package"].project_id != project.id:
            return Response({"detail": "El paquete no pertenece al proyecto."}, status=status.HTTP_400_BAD_REQUEST)
        validation = validate_element(data.get("metaclass"), data.get("name"))
        if not validation.valid:
            return Response(result_payload(validation), status=status.HTTP_400_BAD_REQUEST)
        obj = UmlElement.objects.create(project=project, created_by=request.user, **data)
        entity_type = "UmlElement"
    elif resource == "relationships":
        if project.relationships.count() >= int(getattr(settings, "MAX_PROJECT_RELATIONSHIPS", 10000)):
            return Response({"detail": "El proyecto alcanzó el límite de relaciones configurado."}, status=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE)
        validation = validate_relationship(data.get("relationship_type"), data.get("source"), data.get("target"))
        if not validation.valid:
            return Response(result_payload(validation), status=status.HTTP_400_BAD_REQUEST)
        if data["source"].project_id != project.id or data["target"].project_id != project.id:
            return Response({"detail": "Las referencias deben pertenecer al proyecto."}, status=status.HTTP_400_BAD_REQUEST)
        obj = UmlRelationship.objects.create(project=project, **data)
        entity_type = "UmlRelationship"
    else:
        obj = Diagram.objects.create(project=project, created_by=request.user, **data)
        entity_type = "Diagram"
    record_operation(project_id=project.id, author=request.user, origin=ModelOperation.Origin.USER, entity_type=entity_type, entity_id=obj.id, action="create", new_value=_json_value(serializer_class(obj).data), base_revision=project.revision)
    return Response(serializer_class(obj, context={"request": request}).data, status=status.HTTP_201_CREATED)


@api_view(["GET", "PATCH", "DELETE"])
@permission_classes([IsAuthenticated])
def project_resource_detail(request, project_id, resource, resource_id):
    project = _project_or_404(request.user, project_id)
    model = {"packages": UmlPackage, "elements": UmlElement, "relationships": UmlRelationship, "diagrams": Diagram}.get(resource)
    serializer_class = _resource_serializer(resource) if model else None
    if not model:
        return Response({"detail": "Recurso no encontrado."}, status=status.HTTP_404_NOT_FOUND)
    try:
        obj = model.objects.get(pk=resource_id, project=project)
    except (model.DoesNotExist, ValueError):
        from rest_framework.exceptions import NotFound
        raise NotFound("Recurso no encontrado.")
    if request.method == "GET":
        return Response(serializer_class(obj, context={"request": request}).data)
    require_membership(request.user, project, write=True)
    if request.method == "DELETE":
        previous = _json_value(serializer_class(obj).data)
        if resource == "elements":
            DiagramNode.objects.filter(element=obj).delete()
        entity_type = obj.__class__.__name__
        obj.delete()
        record_operation(project_id=project.id, author=request.user, origin=ModelOperation.Origin.USER, entity_type=entity_type, entity_id=resource_id, action="delete", previous_value=previous, base_revision=project.revision)
        return Response(status=status.HTTP_204_NO_CONTENT)
    previous = _json_value(serializer_class(obj).data)
    serializer = serializer_class(obj, data=request.data, partial=True, context={"request": request})
    serializer.is_valid(raise_exception=True)
    data = serializer.validated_data
    if resource == "elements":
        validation = validate_element(data.get("metaclass", obj.metaclass), data.get("name", obj.name))
        if not validation.valid:
            return Response(result_payload(validation), status=status.HTTP_400_BAD_REQUEST)
        if data.get("package") and data["package"].project_id != project.id:
            return Response({"detail": "El paquete no pertenece al proyecto."}, status=status.HTTP_400_BAD_REQUEST)
    elif resource == "relationships":
        source = data.get("source", obj.source)
        target = data.get("target", obj.target)
        validation = validate_relationship(data.get("relationship_type", obj.relationship_type), source, target)
        if not validation.valid or source.project_id != project.id or target.project_id != project.id:
            return Response(result_payload(validation) if not validation.valid else {"detail": "Las referencias deben pertenecer al proyecto."}, status=status.HTTP_400_BAD_REQUEST)
    elif resource == "diagrams" and data.get("diagram_type") not in (None, *DIAGRAM_TYPES):
        return Response({"detail": "Tipo de diagrama no soportado."}, status=status.HTTP_400_BAD_REQUEST)
    serializer.save()
    record_operation(project_id=project.id, author=request.user, origin=ModelOperation.Origin.USER, entity_type=obj.__class__.__name__, entity_id=obj.id, action="update", previous_value=previous, new_value=_json_value(serializer.data), base_revision=project.revision)
    return Response(serializer.data)


def _diagram_for_user(user, project_id, diagram_id, write=False):
    project = _project_or_404(user, project_id)
    try:
        diagram = Diagram.objects.get(pk=diagram_id, project=project)
    except (Diagram.DoesNotExist, ValueError) as exc:
        from rest_framework.exceptions import NotFound
        raise NotFound("Diagrama no encontrado.") from exc
    if write:
        require_membership(user, project, write=True)
    return project, diagram


@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def diagram_nodes(request, project_id, diagram_id):
    project, diagram = _diagram_for_user(request.user, project_id, diagram_id, write=request.method == "POST")
    if request.method == "GET":
        return Response(DiagramNodeSerializer(diagram.nodes.select_related("element"), many=True).data)
    serializer = DiagramNodeSerializer(data={**request.data, "diagram": str(diagram.id)})
    serializer.is_valid(raise_exception=True)
    element = serializer.validated_data.get("element")
    if element and element.project_id != project.id:
        return Response({"detail": "El elemento no pertenece al proyecto."}, status=status.HTTP_400_BAD_REQUEST)
    node = serializer.save()
    record_operation(project_id=project.id, author=request.user, origin=ModelOperation.Origin.USER, entity_type="DiagramNode", entity_id=node.id, action="create", new_value=_json_value(DiagramNodeSerializer(node).data), base_revision=project.revision)
    return Response(DiagramNodeSerializer(node).data, status=status.HTTP_201_CREATED)


@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def diagram_edges(request, project_id, diagram_id):
    project, diagram = _diagram_for_user(request.user, project_id, diagram_id, write=request.method == "POST")
    if request.method == "GET":
        return Response(DiagramEdgeSerializer(diagram.edges, many=True).data)
    serializer = DiagramEdgeSerializer(data={**request.data, "diagram": str(diagram.id)})
    serializer.is_valid(raise_exception=True)
    source_node = serializer.validated_data["source_node"]
    target_node = serializer.validated_data["target_node"]
    if source_node.diagram_id != diagram.id or target_node.diagram_id != diagram.id:
        return Response({"detail": "Los nodos deben pertenecer al diagrama."}, status=status.HTTP_400_BAD_REQUEST)
    edge = serializer.save()
    record_operation(project_id=project.id, author=request.user, origin=ModelOperation.Origin.USER, entity_type="DiagramEdge", entity_id=edge.id, action="create", new_value=_json_value(DiagramEdgeSerializer(edge).data), base_revision=project.revision)
    return Response(DiagramEdgeSerializer(edge).data, status=status.HTTP_201_CREATED)


@api_view(["PATCH", "DELETE"])
@permission_classes([IsAuthenticated])
def diagram_node_detail(request, project_id, diagram_id, node_id):
    project, diagram = _diagram_for_user(request.user, project_id, diagram_id, write=True)
    try:
        node = diagram.nodes.get(pk=node_id)
    except DiagramNode.DoesNotExist as exc:
        from rest_framework.exceptions import NotFound
        raise NotFound("Nodo no encontrado.") from exc
    if request.method == "DELETE":
        previous = _json_value(DiagramNodeSerializer(node).data)
        node.delete()
        record_operation(project_id=project.id, author=request.user, origin=ModelOperation.Origin.USER, entity_type="DiagramNode", entity_id=node_id, action="delete", previous_value=previous, base_revision=project.revision)
        return Response(status=status.HTTP_204_NO_CONTENT)
    serializer = DiagramNodeSerializer(node, data=request.data, partial=True)
    serializer.is_valid(raise_exception=True)
    if serializer.validated_data.get("element") and serializer.validated_data["element"].project_id != project.id:
        return Response({"detail": "El elemento no pertenece al proyecto."}, status=status.HTTP_400_BAD_REQUEST)
    previous = _json_value(DiagramNodeSerializer(node).data)
    serializer.save()
    record_operation(project_id=project.id, author=request.user, origin=ModelOperation.Origin.USER, entity_type="DiagramNode", entity_id=node.id, action="update", previous_value=previous, new_value=_json_value(serializer.data), base_revision=project.revision)
    return Response(serializer.data)


@api_view(["PATCH", "DELETE"])
@permission_classes([IsAuthenticated])
def diagram_edge_detail(request, project_id, diagram_id, edge_id):
    project, diagram = _diagram_for_user(request.user, project_id, diagram_id, write=True)
    try:
        edge = diagram.edges.get(pk=edge_id)
    except DiagramEdge.DoesNotExist as exc:
        from rest_framework.exceptions import NotFound
        raise NotFound("Arista no encontrada.") from exc
    if request.method == "DELETE":
        previous = _json_value(DiagramEdgeSerializer(edge).data)
        edge.delete()
        record_operation(project_id=project.id, author=request.user, origin=ModelOperation.Origin.USER, entity_type="DiagramEdge", entity_id=edge_id, action="delete", previous_value=previous, base_revision=project.revision)
        return Response(status=status.HTTP_204_NO_CONTENT)
    serializer = DiagramEdgeSerializer(edge, data=request.data, partial=True)
    serializer.is_valid(raise_exception=True)
    if serializer.validated_data.get("source_node") and serializer.validated_data["source_node"].diagram_id != diagram.id:
        return Response({"detail": "El nodo origen no pertenece al diagrama."}, status=status.HTTP_400_BAD_REQUEST)
    if serializer.validated_data.get("target_node") and serializer.validated_data["target_node"].diagram_id != diagram.id:
        return Response({"detail": "El nodo destino no pertenece al diagrama."}, status=status.HTTP_400_BAD_REQUEST)
    previous = _json_value(DiagramEdgeSerializer(edge).data)
    serializer.save()
    record_operation(project_id=project.id, author=request.user, origin=ModelOperation.Origin.USER, entity_type="DiagramEdge", entity_id=edge.id, action="update", previous_value=previous, new_value=_json_value(serializer.data), base_revision=project.revision)
    return Response(serializer.data)


@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def project_operations(request, project_id):
    project = _project_or_404(request.user, project_id)
    if request.method == "GET":
        after = int(request.query_params.get("after_revision", 0))
        operations = project.operations.filter(server_revision__gt=after).select_related("author")[:1000]
        return Response({"revision": project.revision, "operations": OperationSerializer(operations, many=True).data})
    require_membership(request.user, project, write=True)
    payload = request.data
    operation_id = payload.get("operation_id")
    if operation_id:
        try:
            existing = ModelOperation.objects.get(operation_id=operation_id, project=project)
        except (ModelOperation.DoesNotExist, ValueError):
            existing = None
        if existing:
            return Response(OperationSerializer(existing).data)
    try:
        operation_id = uuid.UUID(str(operation_id)) if operation_id else uuid.uuid4()
    except ValueError:
        return Response({"detail": "operation_id inválido."}, status=status.HTTP_400_BAD_REQUEST)
    try:
        entity_id = uuid.UUID(str(payload.get("entity_id"))) if payload.get("entity_id") else None
    except (ValueError, TypeError):
        return Response({"detail": "entity_id inválido."}, status=status.HTTP_400_BAD_REQUEST)
    entity_type = payload.get("entity_type", "unknown")
    action = payload.get("action", "update")
    value = payload.get("new_value") or {}
    if action == "create" and isinstance(value, dict) and entity_id:
        if entity_type == "UmlPackage" and not UmlPackage.objects.filter(pk=entity_id, project=project).exists():
            UmlPackage.objects.create(id=entity_id, project=project, name=value.get("name", "Paquete"), mda_level=value.get("mda_level", Project.MdaLevel.UNSPECIFIED), properties=value.get("properties") or {})
        elif entity_type == "UmlElement" and not UmlElement.objects.filter(pk=entity_id, project=project).exists():
            validation = validate_element(value.get("metaclass"), value.get("name"))
            if not validation.valid:
                return Response(result_payload(validation), status=status.HTTP_400_BAD_REQUEST)
            UmlElement.objects.create(id=entity_id, project=project, created_by=request.user, metaclass=value["metaclass"], name=value["name"], properties=value.get("properties") or {}, external_ids=value.get("external_ids") or {})
        elif entity_type == "Diagram" and not Diagram.objects.filter(pk=entity_id, project=project).exists():
            Diagram.objects.create(id=entity_id, project=project, created_by=request.user, name=value.get("name", "Diagrama"), diagram_type=value.get("diagram_type", "class"), properties=value.get("properties") or {})
        elif entity_type == "DiagramNode" and not DiagramNode.objects.filter(pk=entity_id, diagram__project=project).exists():
            diagram = Diagram.objects.filter(pk=value.get("diagram"), project=project).first()
            element = UmlElement.objects.filter(pk=value.get("element"), project=project).first()
            if diagram:
                DiagramNode.objects.create(id=entity_id, diagram=diagram, element=element, x=value.get("x", 0), y=value.get("y", 0), width=value.get("width", 180), height=value.get("height", 80), properties=value.get("properties") or {})
        elif entity_type == "DiagramEdge" and not DiagramEdge.objects.filter(pk=entity_id, diagram__project=project).exists():
            diagram = Diagram.objects.filter(pk=value.get("diagram"), project=project).first()
            source_node = DiagramNode.objects.filter(pk=value.get("source_node"), diagram__project=project).first()
            target_node = DiagramNode.objects.filter(pk=value.get("target_node"), diagram__project=project).first()
            relationship = UmlRelationship.objects.filter(pk=value.get("relationship"), project=project).first()
            if diagram and source_node and target_node and source_node.diagram_id == diagram.id and target_node.diagram_id == diagram.id:
                DiagramEdge.objects.create(id=entity_id, diagram=diagram, relationship=relationship, source_node=source_node, target_node=target_node, properties=value.get("properties") or {})
        elif entity_type == "UmlRelationship" and not UmlRelationship.objects.filter(pk=entity_id, project=project).exists():
            source = UmlElement.objects.filter(pk=value.get("source"), project=project).first()
            target = UmlElement.objects.filter(pk=value.get("target"), project=project).first()
            if source and target:
                UmlRelationship.objects.create(id=entity_id, project=project, relationship_type=value.get("relationship_type", "Association"), source=source, target=target, properties=value.get("properties") or {}, external_ids=value.get("external_ids") or {})
    elif action == "delete" and entity_id:
        model = {"UmlElement": UmlElement, "DiagramNode": DiagramNode, "DiagramEdge": DiagramEdge}.get(entity_type)
        if model is not None:
            filters = {"pk": entity_id}
            if entity_type == "UmlElement": filters["project"] = project
            else: filters["diagram__project"] = project
            model.objects.filter(**filters).delete()
    elif action == "update" and isinstance(value, dict) and entity_id:
        if entity_type == "DiagramNode":
            node = DiagramNode.objects.filter(pk=entity_id, diagram__project=project).first()
            if node:
                for field in ("x", "y", "width", "height"):
                    if field in value:
                        setattr(node, field, value[field])
                if "properties" in value:
                    node.properties = value["properties"] or {}
                node.save(update_fields=("x", "y", "width", "height", "properties"))
        elif entity_type == "UmlElement":
            element = UmlElement.objects.filter(pk=entity_id, project=project).first()
            if element:
                for field in ("name", "metaclass", "properties", "external_ids"):
                    if field in value:
                        setattr(element, field, value[field])
                element.save(update_fields=("name", "metaclass", "properties", "external_ids", "updated_at"))
    operation = record_operation(project_id=project.id, author=request.user, origin=payload.get("origin", ModelOperation.Origin.USER), entity_type=entity_type, entity_id=entity_id, action=action, path=payload.get("path", ""), base_revision=payload.get("base_revision", project.revision), previous_value=payload.get("previous_value"), new_value=payload.get("new_value"), operation_id=operation_id)
    return Response(OperationSerializer(operation).data, status=status.HTTP_201_CREATED)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def project_history(request, project_id):
    project = _project_or_404(request.user, project_id)
    return Response({"operations": OperationSerializer(project.operations.select_related("author"), many=True).data, "snapshots": SnapshotSerializer(project.snapshots.select_related("created_by"), many=True).data, "conflicts": ConflictSerializer(project.conflicts.select_related("rejected_author"), many=True).data})


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def resolve_conflict(request, project_id, conflict_id):
    project = _project_or_404(request.user, project_id)
    require_membership(request.user, project, write=True)
    try:
        conflict = project.conflicts.get(pk=conflict_id, resolved_at__isnull=True)
    except SyncConflict.DoesNotExist as exc:
        from rest_framework.exceptions import NotFound
        raise NotFound("Conflicto no encontrado o ya resuelto.") from exc
    operation = record_operation(project_id=project.id, author=request.user, origin=ModelOperation.Origin.USER, entity_type=conflict.entity_type, entity_id=conflict.entity_id, action="resolve", path=conflict.path, previous_value=conflict.rejected_value, new_value=request.data.get("value"), base_revision=project.revision)
    conflict.resolved_at = timezone.now()
    conflict.save(update_fields=("resolved_at",))
    return Response({"conflict": ConflictSerializer(conflict).data, "operation": OperationSerializer(operation).data})


@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def project_snapshots(request, project_id):
    project = _project_or_404(request.user, project_id)
    if request.method == "GET":
        return Response(SnapshotSerializer(project.snapshots.select_related("created_by"), many=True).data)
    require_membership(request.user, project, write=True)
    reason = str(request.data.get("reason", "manual"))[:32]
    snapshot = snapshot_project(project, reason=reason, created_by=request.user)
    return Response(SnapshotSerializer(snapshot).data, status=status.HTTP_201_CREATED)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def restore_snapshot(request, project_id, snapshot_id):
    project = _project_or_404(request.user, project_id)
    require_owner(request.user, project)
    try:
        snapshot = project.snapshots.get(pk=snapshot_id)
    except ProjectSnapshot.DoesNotExist as exc:
        from rest_framework.exceptions import NotFound
        raise NotFound("Snapshot no encontrado.") from exc
    # Keep a protected point-in-time copy and append a restore operation; the
    # operation log is never removed by restoring model data.
    snapshot_project(project, reason="before_restore", created_by=request.user)
    payload = snapshot.payload
    with transaction.atomic():
        project.diagrams.all().delete()
        project.relationships.all().delete()
        project.elements.all().delete()
        project.packages.all().delete()
        package_map = {}
        for item in payload.get("packages", []):
            parent_id = package_map.get(str(item.get("parent_id")))
            package = UmlPackage.objects.create(id=item["id"], project=project, parent=parent_id, name=item["name"], mda_level=item.get("mda_level", Project.MdaLevel.UNSPECIFIED), properties=item.get("properties") or {})
            package_map[str(package.id)] = package
        for item in payload.get("elements", []):
            UmlElement.objects.create(id=item["id"], project=project, package=package_map.get(str(item.get("package_id"))), metaclass=item["metaclass"], name=item["name"], properties=item.get("properties") or {}, external_ids=item.get("external_ids") or {})
        element_map = {str(item.id): item for item in project.elements.all()}
        for item in payload.get("relationships", []):
            source = element_map.get(str(item.get("source_id")))
            target = element_map.get(str(item.get("target_id")))
            if source and target:
                UmlRelationship.objects.create(id=item["id"], project=project, relationship_type=item["relationship_type"], source=source, target=target, properties=item.get("properties") or {}, external_ids=item.get("external_ids") or {})
        for item in payload.get("diagrams", []):
            Diagram.objects.create(id=item["id"], project=project, name=item["name"], diagram_type=item["diagram_type"], properties=item.get("properties") or {}, created_by=request.user)
        diagram_map = {str(item.id): item for item in project.diagrams.all()}
        node_map = {}
        for item in payload.get("diagram_nodes", []):
            diagram = diagram_map.get(str(item.get("diagram_id")))
            if diagram:
                node = DiagramNode.objects.create(id=item["id"], diagram=diagram, element=element_map.get(str(item.get("element_id"))), x=item.get("x", 0), y=item.get("y", 0), width=item.get("width", 180), height=item.get("height", 80), properties=item.get("properties") or {})
                node_map[str(node.id)] = node
        relationship_map = {str(item.id): item for item in project.relationships.all()}
        for item in payload.get("diagram_edges", []):
            diagram = diagram_map.get(str(item.get("diagram_id")))
            source = node_map.get(str(item.get("source_node_id")))
            target = node_map.get(str(item.get("target_node_id")))
            if diagram and source and target:
                DiagramEdge.objects.create(id=item["id"], diagram=diagram, relationship=relationship_map.get(str(item.get("relationship_id"))), source_node=source, target_node=target, properties=item.get("properties") or {})
        operation = record_operation(project_id=project.id, author=request.user, origin=ModelOperation.Origin.RESTORE, entity_type="ProjectSnapshot", entity_id=snapshot.id, action="restore", previous_value={"revision": project.revision}, new_value={"snapshot_id": str(snapshot.id)}, base_revision=project.revision)
    project.refresh_from_db(fields=("revision",))
    return Response({"snapshot": SnapshotSerializer(snapshot).data, "operation": OperationSerializer(operation).data, "revision": project.revision})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def validate_project(request, project_id):
    project = _project_or_404(request.user, project_id)
    result = ValidationResult()
    for element in project.elements.all():
        element_result = validate_element(element.metaclass, element.name)
        result.errors.extend(element_result.errors)
        result.warnings.extend(element_result.warnings)
        if element.package_id is None or element.package.mda_level == Project.MdaLevel.UNSPECIFIED:
            from .validators import ValidationIssue
            result.warnings.append(ValidationIssue("warning", "mda_unclassified", "El elemento no está clasificado en CIM, PIM o PSM.", f"elements.{element.id}"))
    for relationship in project.relationships.select_related("source", "target"):
        relationship_result = validate_relationship(relationship.relationship_type, relationship.source, relationship.target)
        result.errors.extend(relationship_result.errors)
        result.warnings.extend(relationship_result.warnings)
    for package in project.packages.filter(mda_level="UNSPECIFIED"):
        from .validators import ValidationIssue
        result.warnings.append(ValidationIssue("warning", "mda_unclassified", "El paquete no tiene nivel CIM, PIM o PSM.", f"packages.{package.id}"))
    return Response(result_payload(result))


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def export_interchange(request, project_id):
    project = _project_or_404(request.user, project_id)
    profile = request.query_params.get("profile", "omg-xmi-2.5.1")
    if profile not in {"omg-xmi-2.5.1", "sparx-ea-xmi-2.1"}:
        return Response({"detail": "Perfil de intercambio no soportado."}, status=status.HTTP_400_BAD_REQUEST)
    xml = write_exchange(project, profile)
    response = HttpResponse(xml, content_type="application/xml")
    response["Content-Disposition"] = f'attachment; filename="{project.name[:60]}.xmi"'
    return response


def _read_exchange_request(request):
    uploaded_file = request.FILES.get("file")
    raw = uploaded_file.read() if uploaded_file else request.data.get("xml", "")
    parsed = parse_exchange(raw)
    if len(parsed["elements"]) > int(getattr(settings, "MAX_PROJECT_ELEMENTS", 5000)) or len(parsed["relationships"]) > int(getattr(settings, "MAX_PROJECT_RELATIONSHIPS", 10000)):
        raise OverflowError("El archivo excede los límites configurados de elementos o relaciones.")
    return parsed, uploaded_file


def _apply_parsed_exchange(*, project, user, parsed, import_mode, profile):
    snapshot = snapshot_project(project, reason="before_import", created_by=user)
    package_map = {}
    for item in parsed["packages"]:
        package = UmlPackage.objects.create(project=project, name=item["name"], mda_level=item.get("mda_level", Project.MdaLevel.UNSPECIFIED), properties=item.get("properties") or {})
        package_map[item["id"]] = package
    element_map = {}
    for item in parsed["elements"]:
        element = project.elements.filter(external_ids__xmi=item["id"]).first() if import_mode == "update" else None
        if element is None:
            element = UmlElement.objects.create(project=project, metaclass=item["metaclass"], name=item["name"], properties=item.get("properties") or {}, external_ids=item.get("external_ids") or {}, created_by=user)
        else:
            element.metaclass = item["metaclass"]
            element.name = item["name"]
            element.properties = item.get("properties") or {}
            element.external_ids = item.get("external_ids") or element.external_ids
            element.save(update_fields=("metaclass", "name", "properties", "external_ids", "updated_at"))
        element_map[item["id"]] = element
    for item in parsed["relationships"]:
        source = element_map.get(item.get("source_id")) or project.elements.filter(external_ids__xmi=item.get("source_id")).first()
        target = element_map.get(item.get("target_id")) or project.elements.filter(external_ids__xmi=item.get("target_id")).first()
        if source and target and item.get("relationship_type") in RELATIONSHIP_TYPES:
            relationship = project.relationships.filter(external_ids__xmi=item["id"]).first() if import_mode == "update" else None
            if relationship is None:
                UmlRelationship.objects.create(project=project, relationship_type=item["relationship_type"], source=source, target=target, properties=item.get("properties") or {}, external_ids=item.get("external_ids") or {})
            else:
                relationship.relationship_type = item["relationship_type"]
                relationship.source = source
                relationship.target = target
                relationship.properties = item.get("properties") or {}
                relationship.external_ids = item.get("external_ids") or relationship.external_ids
                relationship.save(update_fields=("relationship_type", "source", "target", "properties", "external_ids"))
    imported_diagrams = []
    diagram_map = {}
    for item in parsed["diagrams"]:
        diagram = project.diagrams.filter(properties__xmi_id=item["id"]).first() if import_mode == "update" else None
        if diagram is None:
            properties = item.get("properties") or {}
            properties.setdefault("xmi_id", item["id"])
            if parsed.get("opaque_extensions"):
                properties.setdefault("opaque_extensions", parsed["opaque_extensions"])
            diagram = Diagram.objects.create(project=project, name=item["name"], diagram_type=item.get("diagram_type", "class"), properties=properties, created_by=user)
        else:
            diagram.name = item["name"]
            diagram.diagram_type = item.get("diagram_type", "class")
            diagram.properties = item.get("properties") or diagram.properties
            diagram.save(update_fields=("name", "diagram_type", "properties", "updated_at"))
        imported_diagrams.append(diagram)
        diagram_map[item["id"]] = diagram
    if imported_diagrams and not parsed.get("has_presentation"):
        for diagram in imported_diagrams:
            for index, element in enumerate(element_map.values()):
                DiagramNode.objects.create(diagram=diagram, element=element, x=40 + (index % 5) * 220, y=40 + (index // 5) * 120, properties={"layout": "automatic"})
    elif parsed.get("views"):
        node_map = {}
        for view in parsed["views"]:
            if view["kind"] != "node":
                continue
            diagram = diagram_map.get(view.get("diagram_id"))
            element = element_map.get(view.get("element_id"))
            if diagram:
                node = DiagramNode.objects.create(diagram=diagram, element=element, x=view.get("x", 0), y=view.get("y", 0), width=view.get("width", 180), height=view.get("height", 80))
                node_map[view["id"]] = node
        for view in parsed["views"]:
            if view["kind"] != "edge":
                continue
            diagram = diagram_map.get(view.get("diagram_id"))
            source = node_map.get(view.get("source_node_id"))
            target = node_map.get(view.get("target_node_id"))
            if diagram and source and target:
                DiagramEdge.objects.create(diagram=diagram, source_node=source, target_node=target)
    operation = record_operation(project_id=project.id, author=user, origin=ModelOperation.Origin.IMPORT, entity_type="Project", entity_id=project.id, action="import", new_value={"profile": profile, "snapshot_id": str(snapshot.id)}, base_revision=project.revision)
    return snapshot, operation


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def import_interchange(request, project_id):
    project = _project_or_404(request.user, project_id)
    require_membership(request.user, project, write=True)
    try:
        parsed, _ = _read_exchange_request(request)
    except OverflowError as exc:
        return Response({"errors": [str(exc)], "warnings": [], "applied": False}, status=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE)
    except (ValueError, TypeError) as exc:
        return Response({"errors": [str(exc)], "warnings": [], "applied": False}, status=status.HTTP_400_BAD_REQUEST)
    import_mode = request.data.get("mode", "update")
    if import_mode not in {"copy", "update"}:
        return Response({"errors": ["El modo de importación debe ser copy o update."], "warnings": [], "applied": False}, status=status.HTTP_400_BAD_REQUEST)
    parsed["matches"] = [{"kind": "element", "external_id": item["id"], "name": item["name"]} for item in parsed["elements"] if project.elements.filter(external_ids__xmi=item["id"]).exists()]
    parsed["mode"] = import_mode
    if request.data.get("preview", "false") in {True, "true", "1", 1}:
        return Response({**parsed, "applied": False})
    with transaction.atomic():
        snapshot, operation = _apply_parsed_exchange(project=project, user=request.user, parsed=parsed, import_mode=import_mode, profile=request.data.get("profile", "omg-xmi-2.5.1"))
    return Response({**parsed, "applied": True, "snapshot_id": str(snapshot.id), "revision": operation.server_revision}, status=status.HTTP_201_CREATED)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def import_project(request):
    try:
        parsed, uploaded_file = _read_exchange_request(request)
    except OverflowError as exc:
        return Response({"errors": [str(exc)], "warnings": [], "applied": False}, status=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE)
    except (ValueError, TypeError) as exc:
        return Response({"errors": [str(exc)], "warnings": [], "applied": False}, status=status.HTTP_400_BAD_REQUEST)
    fallback_name = Path(uploaded_file.name).stem if uploaded_file else "Proyecto importado"
    project_name = str(request.data.get("name") or fallback_name or "Proyecto importado").strip()[:160]
    with transaction.atomic():
        project = Project.objects.create(owner=request.user, name=project_name, description="Importado desde XMI")
        ProjectMembership.objects.create(project=project, user=request.user, role=ProjectMembership.Role.OWNER)
        snapshot, operation = _apply_parsed_exchange(project=project, user=request.user, parsed=parsed, import_mode="update", profile=request.data.get("profile", "omg-xmi-2.5.1"))
    return Response({"project": ProjectSerializer(project, context={"request": request}).data, "report": {**parsed, "applied": True, "snapshot_id": str(snapshot.id), "revision": operation.server_revision}}, status=status.HTTP_201_CREATED)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def ai_proposals(request, project_id):
    project = _project_or_404(request.user, project_id)
    require_membership(request.user, project)
    prompt = str(request.data.get("prompt", "")).strip()
    if not prompt:
        return Response({"detail": "El prompt es obligatorio."}, status=status.HTTP_400_BAD_REQUEST)
    context = authorized_context(project, selection=request.data.get("selection", []))
    try:
        proposal = request_proposal(prompt, context)
    except AiProviderError as exc:
        return Response({"detail": str(exc), "code": "ai_unavailable"}, status=status.HTTP_503_SERVICE_UNAVAILABLE)
    item = AiProposal.objects.create(project=project, requested_by=request.user, prompt=prompt, context=context, proposal=proposal, warnings=proposal.get("warnings", []), status=AiProposal.Status.READY)
    return Response({"id": str(item.id), "proposal": proposal, "warnings": item.warnings, "status": item.status}, status=status.HTTP_201_CREATED)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def ai_explain(request, project_id):
    project = _project_or_404(request.user, project_id)
    require_membership(request.user, project)
    prompt = str(request.data.get("prompt", "")).strip()
    if not prompt:
        return Response({"detail": "El prompt es obligatorio."}, status=status.HTTP_400_BAD_REQUEST)
    context = authorized_context(project, selection=request.data.get("selection", []))
    try:
        result = request_explanation(prompt, context)
    except AiProviderError as exc:
        return Response({"detail": str(exc), "code": "ai_unavailable"}, status=status.HTTP_503_SERVICE_UNAVAILABLE)
    return Response({**result, "context_scope": {"project_id": str(project.id), "selection_count": len(context.get("selection", []))}})


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def ai_apply(request, project_id, proposal_id):
    project = _project_or_404(request.user, project_id)
    require_membership(request.user, project, write=True)
    try:
        item = project.ai_proposals.get(pk=proposal_id, status=AiProposal.Status.READY)
    except AiProposal.DoesNotExist as exc:
        from rest_framework.exceptions import NotFound
        raise NotFound("Propuesta de IA no encontrada o ya aplicada.") from exc
    selected = set(request.data.get("operation_ids") or [])
    operations = item.proposal.get("operations", [])
    if selected:
        operations = [operation for operation in operations if str(operation.get("id")) in selected]
    if len(operations) > int(getattr(settings, "AI_MAX_OPERATIONS", 200)):
        return Response({"detail": "La propuesta supera el límite de operaciones."}, status=status.HTTP_400_BAD_REQUEST)
    snapshot = snapshot_project(project, reason="before_ai", created_by=request.user)
    created = []
    with transaction.atomic():
        for operation in operations:
            entity_type = operation.get("entity_type", "unknown")
            action = operation.get("action", "propose")
            value = operation.get("value", operation)
            entity_id = operation.get("entity_id")
            if action == "create" and isinstance(value, dict):
                if entity_type == "UmlPackage":
                    obj = UmlPackage.objects.create(project=project, name=value.get("name", "Paquete"), mda_level=value.get("mda_level", Project.MdaLevel.UNSPECIFIED), properties=value.get("properties") or {})
                    entity_id = obj.id
                elif entity_type == "UmlElement":
                    validation = validate_element(value.get("metaclass"), value.get("name"))
                    if not validation.valid:
                        raise ValueError("La propuesta contiene un elemento UML inválido.")
                    obj = UmlElement.objects.create(project=project, created_by=request.user, metaclass=value["metaclass"], name=value["name"], properties=value.get("properties") or {}, external_ids=value.get("external_ids") or {})
                    entity_id = obj.id
                elif entity_type == "Diagram":
                    obj = Diagram.objects.create(project=project, created_by=request.user, name=value.get("name", "Diagrama"), diagram_type=value.get("diagram_type", "class"), properties=value.get("properties") or {})
                    entity_id = obj.id
            try:
                parsed_entity_id = uuid.UUID(str(entity_id)) if entity_id else None
            except (ValueError, TypeError):
                parsed_entity_id = None
            created.append(record_operation(project_id=project.id, author=request.user, origin=ModelOperation.Origin.AI, entity_type=entity_type, entity_id=parsed_entity_id, action=action, path=operation.get("path", ""), new_value=value, base_revision=project.revision))
        item.status = AiProposal.Status.APPLIED
        item.save(update_fields=("status", "updated_at"))
    project.refresh_from_db(fields=("revision",))
    return Response({"proposal_id": str(item.id), "snapshot_id": str(snapshot.id), "operations": OperationSerializer(created, many=True).data, "revision": project.revision})


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def create_invite(request, project_id):
    project = _project_or_404(request.user, project_id)
    require_owner(request.user, project)
    role = request.data.get("role", ProjectMembership.Role.EDITOR)
    if role not in {ProjectMembership.Role.EDITOR, ProjectMembership.Role.VIEWER}:
        return Response({"detail": "El rol de invitación no es válido."}, status=status.HTTP_400_BAD_REQUEST)
    try:
        max_uses = max(1, min(int(request.data.get("max_uses", 1)), 100))
        expires_hours = max(1, min(int(request.data.get("expires_hours", 72)), 720))
    except (TypeError, ValueError):
        return Response({"detail": "Límite o vencimiento inválido."}, status=status.HTTP_400_BAD_REQUEST)
    expires_at = timezone.now() + timedelta(hours=expires_hours)
    raw_code = secrets.token_urlsafe(18)
    with transaction.atomic():
        invite = InviteCode.objects.create(project=project, code_hash=hashlib.sha256(raw_code.encode()).hexdigest(), code_hint=raw_code[:8], role=role, expires_at=expires_at, max_uses=max_uses, created_by=request.user)
    data = InviteSerializer(invite).data
    data["code"] = raw_code
    return Response(data, status=status.HTTP_201_CREATED)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def list_invites(request, project_id):
    project = _project_or_404(request.user, project_id)
    require_owner(request.user, project)
    return Response(InviteSerializer(project.invite_codes.order_by("-created_at"), many=True).data)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def revoke_invite(request, project_id, invite_id):
    project = _project_or_404(request.user, project_id)
    require_owner(request.user, project)
    try:
        invite = project.invite_codes.get(pk=invite_id)
    except InviteCode.DoesNotExist as exc:
        from rest_framework.exceptions import NotFound
        raise NotFound("Invitación no encontrada.") from exc
    with transaction.atomic():
        invite = InviteCode.objects.select_for_update().get(pk=invite.pk)
        if invite.revoked_at is None:
            invite.revoked_at = timezone.now()
            invite.save(update_fields=("revoked_at",))
    return Response(InviteSerializer(invite).data)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def join_project(request):
    raw_code = str(request.data.get("code", "")).strip()
    if not raw_code:
        return Response({"detail": "Código inválido."}, status=status.HTTP_400_BAD_REQUEST)
    code_hash = hashlib.sha256(raw_code.encode()).hexdigest()
    with transaction.atomic():
        try:
            invite = InviteCode.objects.select_for_update().select_related("project").get(code_hash=code_hash)
        except InviteCode.DoesNotExist:
            return Response({"detail": "Código inválido o no disponible."}, status=status.HTTP_400_BAD_REQUEST)
        if invite.revoked_at or invite.expires_at <= timezone.now() or invite.uses_count >= invite.max_uses:
            return Response({"detail": "Código inválido o no disponible."}, status=status.HTTP_400_BAD_REQUEST)
        max_collaborators = int(getattr(settings, "MAX_COLLABORATORS", 50))
        if invite.project.memberships.count() >= max_collaborators:
            return Response({"detail": "El proyecto alcanzó el límite de colaboradores."}, status=status.HTTP_409_CONFLICT)
        membership, created = ProjectMembership.objects.get_or_create(project=invite.project, user=request.user, defaults={"role": invite.role})
        if not created:
            return Response(ProjectSerializer(invite.project, context={"request": request}).data)
        invite.uses_count += 1
        invite.save(update_fields=("uses_count",))
    return Response(ProjectSerializer(invite.project, context={"request": request}).data)
