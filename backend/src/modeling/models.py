import uuid

from django.conf import settings
from django.db import models
from django.db.models import Q


class Project(models.Model):
    class MdaLevel(models.TextChoices):
        CIM = "CIM", "CIM"
        PIM = "PIM", "PIM"
        PSM = "PSM", "PSM"
        UNSPECIFIED = "UNSPECIFIED", "No especificado"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    owner = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="owned_projects")
    name = models.CharField(max_length=160)
    description = models.TextField(blank=True)
    mda_level = models.CharField(max_length=16, choices=MdaLevel.choices, default=MdaLevel.UNSPECIFIED)
    revision = models.PositiveBigIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)


class ProjectMembership(models.Model):
    class Role(models.TextChoices):
        OWNER = "owner", "Propietario"
        EDITOR = "editor", "Editor"
        VIEWER = "viewer", "Lector"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    project = models.ForeignKey(Project, on_delete=models.CASCADE, related_name="memberships")
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="project_memberships")
    role = models.CharField(max_length=16, choices=Role.choices)
    joined_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=("project", "user"), name="unique_project_member"),
            models.UniqueConstraint(fields=("project",), condition=Q(role="owner"), name="unique_project_owner"),
        ]


class InviteCode(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    project = models.ForeignKey(Project, on_delete=models.CASCADE, related_name="invite_codes")
    code_hash = models.CharField(max_length=128, unique=True)
    code_hint = models.CharField(max_length=12)
    role = models.CharField(max_length=16, choices=ProjectMembership.Role.choices, default=ProjectMembership.Role.EDITOR)
    expires_at = models.DateTimeField()
    max_uses = models.PositiveIntegerField(default=1)
    uses_count = models.PositiveIntegerField(default=0)
    revoked_at = models.DateTimeField(null=True, blank=True)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="created_invites")
    created_at = models.DateTimeField(auto_now_add=True)


class UmlPackage(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    project = models.ForeignKey(Project, on_delete=models.CASCADE, related_name="packages")
    parent = models.ForeignKey("self", null=True, blank=True, on_delete=models.CASCADE, related_name="children")
    name = models.CharField(max_length=160)
    mda_level = models.CharField(max_length=16, choices=Project.MdaLevel.choices, default=Project.MdaLevel.UNSPECIFIED)
    properties = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)


class UmlElement(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    project = models.ForeignKey(Project, on_delete=models.CASCADE, related_name="elements")
    package = models.ForeignKey(UmlPackage, null=True, blank=True, on_delete=models.SET_NULL, related_name="elements")
    metaclass = models.CharField(max_length=80)
    name = models.CharField(max_length=160)
    properties = models.JSONField(default=dict, blank=True)
    external_ids = models.JSONField(default=dict, blank=True)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="created_uml_elements")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)


class UmlRelationship(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    project = models.ForeignKey(Project, on_delete=models.CASCADE, related_name="relationships")
    relationship_type = models.CharField(max_length=80)
    source = models.ForeignKey(UmlElement, on_delete=models.CASCADE, related_name="outgoing_relationships")
    target = models.ForeignKey(UmlElement, on_delete=models.CASCADE, related_name="incoming_relationships")
    properties = models.JSONField(default=dict, blank=True)
    external_ids = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)


class Diagram(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    project = models.ForeignKey(Project, on_delete=models.CASCADE, related_name="diagrams")
    name = models.CharField(max_length=160)
    diagram_type = models.CharField(max_length=64)
    properties = models.JSONField(default=dict, blank=True)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="created_diagrams")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)


class DiagramNode(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    diagram = models.ForeignKey(Diagram, on_delete=models.CASCADE, related_name="nodes")
    element = models.ForeignKey(UmlElement, null=True, blank=True, on_delete=models.SET_NULL, related_name="diagram_nodes")
    x = models.FloatField(default=0)
    y = models.FloatField(default=0)
    width = models.FloatField(default=180)
    height = models.FloatField(default=80)
    properties = models.JSONField(default=dict, blank=True)


class DiagramEdge(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    diagram = models.ForeignKey(Diagram, on_delete=models.CASCADE, related_name="edges")
    relationship = models.ForeignKey(UmlRelationship, null=True, blank=True, on_delete=models.SET_NULL, related_name="diagram_edges")
    source_node = models.ForeignKey(DiagramNode, on_delete=models.CASCADE, related_name="outgoing_edges")
    target_node = models.ForeignKey(DiagramNode, on_delete=models.CASCADE, related_name="incoming_edges")
    properties = models.JSONField(default=dict, blank=True)


class ModelOperation(models.Model):
    class Origin(models.TextChoices):
        USER = "user", "Usuario"
        IMPORT = "import", "Importación"
        AI = "ai", "IA"
        RESTORE = "restore", "Restauración"

    operation_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    project = models.ForeignKey(Project, on_delete=models.CASCADE, related_name="operations")
    author = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="model_operations")
    origin = models.CharField(max_length=16, choices=Origin.choices, default=Origin.USER)
    entity_type = models.CharField(max_length=80)
    entity_id = models.UUIDField(null=True, blank=True)
    action = models.CharField(max_length=32)
    path = models.CharField(max_length=255, blank=True)
    base_revision = models.PositiveBigIntegerField(default=0)
    previous_value = models.JSONField(null=True, blank=True)
    new_value = models.JSONField(null=True, blank=True)
    server_revision = models.PositiveBigIntegerField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=("project", "server_revision"), name="unique_project_revision")]
        ordering = ("server_revision",)


class ProjectSnapshot(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    project = models.ForeignKey(Project, on_delete=models.CASCADE, related_name="snapshots")
    revision = models.PositiveBigIntegerField()
    payload = models.JSONField(default=dict)
    reason = models.CharField(max_length=32)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="project_snapshots")
    created_at = models.DateTimeField(auto_now_add=True)


class SyncConflict(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    project = models.ForeignKey(Project, on_delete=models.CASCADE, related_name="conflicts")
    entity_type = models.CharField(max_length=80)
    entity_id = models.UUIDField(null=True, blank=True)
    path = models.CharField(max_length=255)
    accepted_operation = models.ForeignKey(ModelOperation, on_delete=models.PROTECT, related_name="accepted_conflicts")
    rejected_value = models.JSONField(null=True, blank=True)
    rejected_author = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="rejected_conflicts")
    resolved_at = models.DateTimeField(null=True, blank=True)


class ExternalIdentifier(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    project = models.ForeignKey(Project, on_delete=models.CASCADE, related_name="external_identifiers")
    provider = models.CharField(max_length=64)
    external_id = models.CharField(max_length=255)
    entity_type = models.CharField(max_length=80)
    entity_id = models.UUIDField()

    class Meta:
        constraints = [models.UniqueConstraint(fields=("project", "provider", "external_id"), name="unique_external_identifier")]


class AiProposal(models.Model):
    class Status(models.TextChoices):
        DRAFT = "draft", "Borrador"
        READY = "ready", "Lista"
        APPLIED = "applied", "Aplicada"
        CANCELLED = "cancelled", "Cancelada"
        INVALID = "invalid", "Inválida"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    project = models.ForeignKey(Project, on_delete=models.CASCADE, related_name="ai_proposals")
    requested_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="ai_proposals")
    prompt = models.TextField()
    context = models.JSONField(default=dict)
    proposal = models.JSONField(default=dict)
    warnings = models.JSONField(default=list)
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.DRAFT)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)


class MetaclassRegistry(models.Model):
    version = models.CharField(max_length=32)
    diagram_type = models.CharField(max_length=64)
    definitions = models.JSONField(default=dict)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=("version", "diagram_type"), name="unique_metaclass_registry")]
