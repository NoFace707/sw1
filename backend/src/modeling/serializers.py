from django.contrib.auth import get_user_model
from rest_framework import serializers

from .models import (AiProposal, Diagram, DiagramEdge, DiagramNode, ExternalIdentifier, InviteCode, MetaclassRegistry, ModelOperation, Project, ProjectMembership, ProjectSnapshot, SyncConflict, UmlElement, UmlPackage, UmlRelationship)
from .registry import DIAGRAM_TYPES, registry_payload

User = get_user_model()


class UserMiniSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ("id", "first_name", "last_name", "email")


class MembershipSerializer(serializers.ModelSerializer):
    user = UserMiniSerializer(read_only=True)

    class Meta:
        model = ProjectMembership
        fields = ("id", "user", "role", "joined_at")


class ProjectSerializer(serializers.ModelSerializer):
    owner = UserMiniSerializer(read_only=True)
    membership_role = serializers.SerializerMethodField()

    class Meta:
        model = Project
        fields = ("id", "name", "description", "mda_level", "revision", "owner", "membership_role", "created_at", "updated_at")
        read_only_fields = ("id", "revision", "owner", "created_at", "updated_at", "membership_role")

    def get_membership_role(self, obj):
        user = self.context["request"].user
        return obj.memberships.filter(user=user).values_list("role", flat=True).first()


class CreateProjectSerializer(serializers.ModelSerializer):
    create_initial_diagram = serializers.BooleanField(default=False, write_only=True, required=False)

    class Meta:
        model = Project
        fields = ("name", "description", "mda_level", "create_initial_diagram")

    def validate_name(self, value):
        if not value.strip():
            raise serializers.ValidationError("El nombre es obligatorio.")
        return value.strip()


class InviteSerializer(serializers.ModelSerializer):
    class Meta:
        model = InviteCode
        fields = ("id", "code_hint", "role", "expires_at", "max_uses", "uses_count", "revoked_at", "created_at")
        read_only_fields = ("id", "code_hint", "uses_count", "revoked_at", "created_at")


class PackageSerializer(serializers.ModelSerializer):
    class Meta:
        model = UmlPackage
        fields = ("id", "project", "parent", "name", "mda_level", "properties", "created_at", "updated_at")
        read_only_fields = ("id", "project", "created_at", "updated_at")


class ElementSerializer(serializers.ModelSerializer):
    class Meta:
        model = UmlElement
        fields = ("id", "project", "package", "metaclass", "name", "properties", "external_ids", "created_by", "created_at", "updated_at")
        read_only_fields = ("id", "project", "created_by", "created_at", "updated_at")

    def validate(self, attrs):
        metaclass = attrs.get("metaclass", getattr(self.instance, "metaclass", None))
        properties = attrs.get("properties", getattr(self.instance, "properties", {}) or {})
        attributes = properties.get("attributes") if isinstance(properties, dict) else None
        if metaclass == "Class" and attributes is not None:
            if not isinstance(attributes, list) or len(attributes) > 100:
                raise serializers.ValidationError({"properties": "Los atributos de una clase deben ser una lista de hasta 100 elementos."})
            if any(not isinstance(item, str) or not item.strip() or len(item) > 200 for item in attributes):
                raise serializers.ValidationError({"properties": "Cada atributo debe ser texto no vacío de hasta 200 caracteres."})
        return attrs


class RelationshipSerializer(serializers.ModelSerializer):
    class Meta:
        model = UmlRelationship
        fields = ("id", "project", "relationship_type", "source", "target", "properties", "external_ids", "created_at")
        read_only_fields = ("id", "project", "created_at")


class DiagramSerializer(serializers.ModelSerializer):
    class Meta:
        model = Diagram
        fields = ("id", "project", "name", "diagram_type", "properties", "created_by", "created_at", "updated_at")
        read_only_fields = ("id", "project", "created_by", "created_at", "updated_at")

    def validate_diagram_type(self, value):
        if value not in DIAGRAM_TYPES:
            raise serializers.ValidationError("Tipo de diagrama no soportado.")
        return value


class DiagramNodeSerializer(serializers.ModelSerializer):
    class Meta:
        model = DiagramNode
        fields = ("id", "diagram", "element", "x", "y", "width", "height", "properties")
        read_only_fields = ("id",)

    def validate_properties(self, value):
        if value.get("kind") != "visual":
            return value
        allowed_shapes = {
            "general": {"text", "rectangle", "rounded-rectangle", "ellipse", "circle", "diamond", "triangle", "parallelogram", "hexagon", "cylinder", "document", "note", "cloud", "callout"},
            "flowchart": {"process", "terminator", "decision", "data", "database", "flow-document", "manual-input", "preparation", "delay", "connector", "off-page-connector", "subprocess"},
            "er": {"entity", "weak-entity", "attribute", "key-attribute", "multivalued-attribute", "derived-attribute", "relationship", "identifying-relationship"},
        }
        library = value.get("library")
        if library not in allowed_shapes or value.get("shape") not in allowed_shapes[library]:
            raise serializers.ValidationError("Figura visual no soportada.")
        allowed_keys = {"kind", "library", "shape", "label", "style"}
        if set(value) - allowed_keys:
            raise serializers.ValidationError("La figura contiene propiedades visuales no permitidas.")
        style = value.get("style") or {}
        if not isinstance(style, dict) or set(style) - {"fill", "stroke", "strokeWidth", "fontSize", "textColor"}:
            raise serializers.ValidationError("El estilo visual contiene propiedades no permitidas.")
        return value


class DiagramEdgeSerializer(serializers.ModelSerializer):
    class Meta:
        model = DiagramEdge
        fields = ("id", "diagram", "relationship", "source_node", "target_node", "properties")
        read_only_fields = ("id",)

    def validate_properties(self, value):
        if value.get("kind") != "visual":
            return value
        allowed_shapes = {"line", "arrow", "double-arrow", "dashed", "dashed-arrow", "orthogonal", "curved", "er-one", "er-zero-one", "er-many", "er-one-many", "er-zero-many"}
        if value.get("library") != "arrows" or value.get("shape") not in allowed_shapes:
            raise serializers.ValidationError("Flecha visual no soportada.")
        if set(value) - {"kind", "library", "shape", "label", "sourceHandle", "targetHandle", "style"}:
            raise serializers.ValidationError("La flecha contiene propiedades visuales no permitidas.")
        handles = {"top", "right", "bottom", "left"}
        if value.get("sourceHandle", "bottom") not in handles or value.get("targetHandle", "top") not in handles:
            raise serializers.ValidationError("Punto de conexión no soportado.")
        style = value.get("style") or {}
        allowed_style = {"stroke", "strokeWidth", "dashed", "arrowStart", "arrowEnd", "routing", "lineStyle", "startMarker", "endMarker"}
        if not isinstance(style, dict) or set(style) - allowed_style:
            raise serializers.ValidationError("El estilo de flecha contiene propiedades no permitidas.")
        if style.get("routing", "straight") not in {"straight", "orthogonal", "curved"}:
            raise serializers.ValidationError("Enrutamiento de flecha no soportado.")
        if style.get("lineStyle", "solid") not in {"solid", "dashed"}:
            raise serializers.ValidationError("Tipo de línea no soportado.")
        markers = {"none", "arrow", "arrow-open", "triangle", "diamond", "diamond-filled", "circle", "one", "zero-one", "many", "one-many", "zero-many"}
        if style.get("startMarker", "none") not in markers or style.get("endMarker", "none") not in markers:
            raise serializers.ValidationError("Marcador de flecha no soportado.")
        return value


class OperationSerializer(serializers.ModelSerializer):
    author = UserMiniSerializer(read_only=True)

    class Meta:
        model = ModelOperation
        fields = ("operation_id", "project", "author", "origin", "entity_type", "entity_id", "action", "path", "base_revision", "previous_value", "new_value", "server_revision", "created_at")


class SnapshotSerializer(serializers.ModelSerializer):
    created_by = UserMiniSerializer(read_only=True)

    class Meta:
        model = ProjectSnapshot
        fields = ("id", "project", "revision", "payload", "reason", "created_by", "created_at")


class ConflictSerializer(serializers.ModelSerializer):
    accepted_operation = OperationSerializer(read_only=True)
    rejected_author = UserMiniSerializer(read_only=True)

    class Meta:
        model = SyncConflict
        fields = ("id", "project", "entity_type", "entity_id", "path", "accepted_operation", "rejected_value", "rejected_author", "resolved_at")


class AiProposalSerializer(serializers.ModelSerializer):
    class Meta:
        model = AiProposal
        fields = ("id", "project", "requested_by", "prompt", "context", "proposal", "warnings", "status", "created_at", "updated_at")
        read_only_fields = ("id", "requested_by", "proposal", "warnings", "status", "created_at", "updated_at")


class RegistrySerializer(serializers.Serializer):
    def to_representation(self, instance):
        return registry_payload()
