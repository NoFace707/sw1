import uuid

from django.db import transaction
from django.conf import settings
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer

from .models import DiagramEdge, DiagramNode, ModelOperation, Project, ProjectSnapshot, SyncConflict


@transaction.atomic
def record_operation(*, project_id, author, origin, entity_type, entity_id, action, path="", base_revision=0, previous_value=None, new_value=None, operation_id=None):
    project = Project.objects.select_for_update().get(pk=project_id)
    next_revision = project.revision + 1
    previous_operation = None
    if base_revision < project.revision and entity_id and path:
        previous_operation = ModelOperation.objects.filter(
            project=project,
            entity_type=entity_type,
            entity_id=entity_id,
            path=path,
            server_revision__gt=base_revision,
        ).order_by("-server_revision").first()
    operation = ModelOperation.objects.create(
        operation_id=operation_id or uuid.uuid4(),
        project=project,
        author=author,
        origin=origin,
        entity_type=entity_type,
        entity_id=entity_id,
        action=action,
        path=path,
        base_revision=base_revision,
        previous_value=previous_value,
        new_value=new_value,
        server_revision=next_revision,
    )
    project.revision = next_revision
    project.save(update_fields=("revision", "updated_at"))
    if previous_operation and previous_operation.new_value != new_value:
        SyncConflict.objects.create(
            project=project,
            entity_type=entity_type,
            entity_id=entity_id,
            path=path,
            accepted_operation=operation,
            rejected_value=previous_operation.new_value,
            rejected_author=previous_operation.author,
        )
    interval = max(1, int(getattr(settings, "MODEL_SNAPSHOT_INTERVAL", 50)))
    if next_revision % interval == 0:
        snapshot_project(project, reason="periodic", created_by=author)
    channel_layer = get_channel_layer()
    if channel_layer:
        event = {"type": "project.event", "event": "operation.confirmed", "operation": {"operation_id": str(operation.operation_id), "entity_type": operation.entity_type, "entity_id": str(operation.entity_id) if operation.entity_id else None, "action": operation.action, "server_revision": operation.server_revision}, "user_id": str(author.id) if author else None}
        transaction.on_commit(lambda: async_to_sync(channel_layer.group_send)(f"project-{project.id}", event))
    return operation


def snapshot_project(project, *, reason, created_by=None):
    payload = {
        "project": {"id": str(project.id), "name": project.name, "revision": project.revision},
        "packages": list(project.packages.values("id", "parent_id", "name", "mda_level", "properties")),
        "elements": list(project.elements.values("id", "package_id", "metaclass", "name", "properties", "external_ids")),
        "relationships": list(project.relationships.values("id", "relationship_type", "source_id", "target_id", "properties", "external_ids")),
        "diagrams": list(project.diagrams.values("id", "name", "diagram_type", "properties")),
        "diagram_nodes": list(DiagramNode.objects.filter(diagram__project=project).values("id", "diagram_id", "element_id", "x", "y", "width", "height", "properties")),
        "diagram_edges": list(DiagramEdge.objects.filter(diagram__project=project).values("id", "diagram_id", "relationship_id", "source_node_id", "target_node_id", "properties")),
    }
    # JSONField cannot serialize UUID values directly.
    def normalize(value):
        if isinstance(value, dict):
            return {key: normalize(item) for key, item in value.items()}
        if isinstance(value, list):
            return [normalize(item) for item in value]
        if isinstance(value, uuid.UUID):
            return str(value)
        return value
    snapshot = ProjectSnapshot.objects.create(project=project, revision=project.revision, payload=normalize(payload), reason=reason, created_by=created_by)
    retention = max(1, int(getattr(settings, "SNAPSHOT_RETENTION", 20)))
    periodic = project.snapshots.filter(reason="periodic").order_by("-created_at")
    stale_ids = list(periodic.values_list("id", flat=True)[retention:])
    if stale_ids:
        ProjectSnapshot.objects.filter(id__in=stale_ids).delete()
    return snapshot
