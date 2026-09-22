import asyncio
import http.client
import io
import uuid
import json
import urllib.error
from datetime import timedelta
from pathlib import Path
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.conf import settings
from django.db import IntegrityError, transaction
from django.db.models.deletion import ProtectedError
from django.test import TestCase, TransactionTestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient
from asgiref.sync import async_to_sync
from asgiref.testing import ApplicationCommunicator
from django.core.cache import cache
from django.core.files.uploadedfile import SimpleUploadedFile

from .consumers import ProjectConsumer
from .models import Diagram, DiagramEdge, DiagramNode, InviteCode, ModelOperation, Project, ProjectMembership, ProjectSnapshot, UmlElement, UmlPackage, UmlRelationship
from .serializers import DiagramEdgeSerializer, DiagramNodeSerializer
from .interchange import exchange_mapping, parse_exchange, write_exchange
from .interchange_compare import compare_exchange_payloads, semantic_projection
from .registry import DIAGRAM_DEFINITIONS, DIAGRAM_TYPES
from .expert_rules import EXPERT_RULES_VERSION
from .local_model_manifest import QWEN_MODEL_REVISION


User = get_user_model()


class ModelingApiTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.owner = User.objects.create_user(username="owner", email="owner@example.com", password="universidad-123", is_active=True)
        self.other = User.objects.create_user(username="other", email="other@example.com", password="universidad-123", is_active=True)
        self.client.force_authenticate(self.owner)

    def create_project(self):
        response = self.client.post("/api/modeling/projects/", {"name": "Biblioteca", "mda_level": "PIM"}, format="json")
        self.assertEqual(response.status_code, 201)
        return response.data

    def test_registry_exposes_all_uml_251_diagrams(self):
        response = self.client.get("/api/modeling/registry/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(set(response.data["diagram_types"]), set(DIAGRAM_TYPES))
        self.assertEqual(response.data["version"], "uml-2.5.1-subset-2")

    def test_registry_exposes_expanded_uml_palette_metaclasses(self):
        expected = {
            "class": {"Actor", "Interface", "Enumeration", "DataType", "PrimitiveType", "Signal", "Constraint"},
            "deployment": {"Device", "ExecutionEnvironment", "DeploymentSpecification"},
            "activity": {"CallBehaviorAction", "SendSignalAction", "FlowFinalNode", "ForkNode", "JoinNode", "DataStoreNode"},
            "state_machine": {"StateMachine", "Pseudostate", "Region"},
            "sequence": {"InteractionUse", "StateInvariant", "Continuation", "DestructionOccurrenceSpecification", "Gate"},
            "timing": {"DurationObservation", "TimeConstraint", "DurationConstraint"},
        }
        response = self.client.get("/api/modeling/registry/")
        for diagram_type, metaclasses in expected.items():
            self.assertTrue(metaclasses.issubset(set(response.data["diagrams"][diagram_type]["elements"])))

    def test_expert_rules_exposes_versioned_offline_payload(self):
        response = self.client.get("/api/modeling/expert-rules/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["version"], EXPERT_RULES_VERSION)
        self.assertEqual(response.data["registry_version"], "uml-2.5.1-subset-2")
        self.assertEqual(len(response.data["checksum"]), 64)
        self.assertTrue(response.data["rules"])

    def test_local_qwen_manifest_is_pinned_and_integrity_protected(self):
        response = self.client.get("/api/modeling/ai/local-model/manifest/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["version"], QWEN_MODEL_REVISION)
        self.assertEqual(response.data["byte_size"], 1117320768)
        self.assertEqual(response.data["sha256"], "cc324af070c2ecbfd324a30884d2f951a7ff756aba85cb811a6ec436933bb046")
        self.assertEqual(len(response.data["manifest_checksum"]), 64)

    @override_settings(
        AI_TRANSCRIPTION_BACKEND="remote",
        AI_TRANSCRIPTION_BASE_URL="https://speech.test/v1",
        AI_TRANSCRIPTION_API_KEY="speech-secret",
        AI_TRANSCRIPTION_MODEL="whisper-1",
    )
    @patch("modeling.transcription.urllib_request.urlopen")
    def test_voice_transcription_is_authenticated_forwarded_and_does_not_mutate_project(self, mocked_urlopen):
        class ProviderResponse:
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self): return json.dumps({"text": "crea una clase Cliente"}).encode()

        mocked_urlopen.return_value = ProviderResponse()
        project = self.create_project()
        response = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/transcriptions/",
            {"audio": SimpleUploadedFile("instruction.webm", b"test-audio", content_type="audio/webm"), "language": "es"},
            format="multipart",
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["text"], "crea una clase Cliente")
        self.assertEqual(Project.objects.get(pk=project["id"]).revision, 0)
        sent = mocked_urlopen.call_args.args[0]
        self.assertEqual(sent.full_url, "https://speech.test/v1/audio/transcriptions")
        self.assertEqual(sent.headers["Authorization"], "Bearer speech-secret")
        self.assertIn(b'name="file"; filename="instruction.webm"', sent.data)
        self.assertIn(b'name="model"', sent.data)

    @override_settings(
        AI_TRANSCRIPTION_BACKEND="remote",
        AI_TRANSCRIPTION_BASE_URL="",
        AI_TRANSCRIPTION_API_KEY="",
    )
    def test_voice_transcription_reports_missing_configuration(self):
        project = self.create_project()
        response = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/transcriptions/",
            {"audio": SimpleUploadedFile("instruction.webm", b"audio", content_type="audio/webm")},
            format="multipart",
        )
        self.assertEqual(response.status_code, 503)
        self.assertIn("AI_TRANSCRIPTION_API_KEY", response.data["detail"])

    @override_settings(
        AI_TRANSCRIPTION_BACKEND="remote",
        AI_TRANSCRIPTION_BASE_URL="https://speech.test/v1",
        AI_TRANSCRIPTION_API_KEY="speech-secret",
        AI_TRANSCRIPTION_MAX_BYTES=4,
    )
    def test_voice_transcription_rejects_unsupported_or_oversized_audio(self):
        project = self.create_project()
        unsupported = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/transcriptions/",
            {"audio": SimpleUploadedFile("instruction.txt", b"abc", content_type="text/plain")},
            format="multipart",
        )
        oversized = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/transcriptions/",
            {"audio": SimpleUploadedFile("instruction.webm", b"12345", content_type="audio/webm")},
            format="multipart",
        )
        self.assertEqual(unsupported.status_code, 400)
        self.assertEqual(oversized.status_code, 413)

    @override_settings(
        AI_TRANSCRIPTION_BACKEND="remote",
        AI_TRANSCRIPTION_BASE_URL="https://speech.test/v1",
        AI_TRANSCRIPTION_API_KEY="speech-secret",
    )
    def test_voice_transcription_does_not_reveal_projects_to_non_members(self):
        project = self.create_project()
        self.client.force_authenticate(self.other)
        response = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/transcriptions/",
            {"audio": SimpleUploadedFile("instruction.webm", b"audio", content_type="audio/webm")},
            format="multipart",
        )
        self.assertEqual(response.status_code, 404)

    @override_settings(
        AI_TRANSCRIPTION_BACKEND="local",
        AI_TRANSCRIPTION_LOCAL_MODEL="base",
    )
    @patch("modeling.transcription._get_local_model")
    def test_voice_transcription_uses_local_whisper_without_api_key_and_cleans_temp_file(
        self, mocked_model
    ):
        class Segment:
            text = " crea una clase Cliente "

        temporary_paths = []

        def fake_transcribe(path, **kwargs):
            temporary_paths.append(path)
            self.assertTrue(Path(path).exists())
            return [Segment()], object()

        mocked_model.return_value.transcribe.side_effect = fake_transcribe
        project = self.create_project()
        response = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/transcriptions/",
            {
                "audio": SimpleUploadedFile(
                    "instruction.m4a",
                    b"local-audio",
                    content_type="audio/mp4a-latm",
                )
            },
            format="multipart",
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["text"], "crea una clase Cliente")
        self.assertEqual(response.data["model"], "local:base")
        mocked_model.return_value.transcribe.assert_called_once()
        self.assertEqual(len(temporary_paths), 1)
        self.assertFalse(Path(temporary_paths[0]).exists())
        self.assertEqual(Project.objects.get(pk=project["id"]).revision, 0)

    def test_exchange_mapping_covers_registry_metaclasses_relationships_and_properties(self):
        mapping = exchange_mapping()
        declared_elements = {metaclass for definition in DIAGRAM_DEFINITIONS.values() for metaclass in definition["elements"] if metaclass != "Extension"}
        declared_relationships = {relationship for definition in DIAGRAM_DEFINITIONS.values() for relationship in definition["relationships"]}
        self.assertTrue(declared_elements.issubset(set(mapping["elements"])))
        self.assertTrue(declared_relationships.issubset(set(mapping["relationships"])))
        self.assertEqual(mapping["properties"], "ea:properties JSON attribute")

    def test_exchange_round_trip_preserves_extended_metaclasses_and_properties(self):
        project = self.create_project()
        part = UmlElement.objects.create(project_id=project["id"], metaclass="Part", name="payment", properties={"multiplicity": "1..*"}, created_by=self.owner)
        exported = write_exchange(Project.objects.get(pk=project["id"]))
        parsed = parse_exchange(exported)
        self.assertEqual(next(item for item in parsed["elements"] if item["id"] == str(part.id))["properties"], {"multiplicity": "1..*"})

    def test_exchange_comparator_reports_semantic_differences_and_ignores_view_noise(self):
        base = {"packages": [], "elements": [{"id": "e1", "external_ids": {"xmi": "e1"}, "metaclass": "Class", "name": "Order", "properties": {"attributes": ["id"]}}], "relationships": [], "diagrams": [{"id": "d1", "name": "Class view", "diagram_type": "class"}]}
        same_semantics = {**base, "views": [{"id": "shape-a", "x": 10}], "has_presentation": True}
        changed = {**base, "elements": [{**base["elements"][0], "name": "Invoice"}]}
        self.assertTrue(compare_exchange_payloads(base, same_semantics)["equivalent"])
        self.assertFalse(compare_exchange_payloads(base, changed)["equivalent"])
        self.assertEqual(semantic_projection(base)["elements"][0][0], "e1")

    def test_project_owner_and_semantic_element_are_created(self):
        project = self.create_project()
        project_id = project["id"]
        self.assertTrue(ProjectMembership.objects.filter(project_id=project_id, user=self.owner, role="owner").exists())
        element = self.client.post(f"/api/modeling/projects/{project_id}/elements/", {"metaclass": "Class", "name": "Libro"}, format="json")
        self.assertEqual(element.status_code, 201)
        self.assertEqual(UmlElement.objects.get(pk=element.data["id"]).created_by, self.owner)
        diagram = self.client.post(f"/api/modeling/projects/{project_id}/diagrams/", {"name": "Clases", "diagram_type": "class"}, format="json")
        self.assertEqual(diagram.status_code, 201)
        self.assertEqual(Diagram.objects.get(pk=diagram.data["id"]).project_id, uuid.UUID(project_id))

    def test_class_attributes_can_be_added_edited_removed_and_are_validated(self):
        project = self.create_project()
        created = self.client.post(f"/api/modeling/projects/{project['id']}/elements/", {"metaclass": "Class", "name": "Cliente", "properties": {"attributes": ["+ id: UUID"]}}, format="json")
        self.assertEqual(created.status_code, 201)
        updated = self.client.patch(f"/api/modeling/projects/{project['id']}/elements/{created.data['id']}/", {"properties": {"attributes": ["+ codigo: UUID", "- nombre: String"]}}, format="json")
        self.assertEqual(updated.status_code, 200)
        self.assertEqual(updated.data["properties"]["attributes"], ["+ codigo: UUID", "- nombre: String"])
        removed = self.client.patch(f"/api/modeling/projects/{project['id']}/elements/{created.data['id']}/", {"properties": {"attributes": ["+ codigo: UUID"]}}, format="json")
        self.assertEqual(removed.status_code, 200)
        self.assertEqual(removed.data["properties"]["attributes"], ["+ codigo: UUID"])
        invalid = self.client.patch(f"/api/modeling/projects/{project['id']}/elements/{created.data['id']}/", {"properties": {"attributes": "id: UUID"}}, format="json")
        self.assertEqual(invalid.status_code, 400)
        self.assertEqual(UmlElement.objects.get(pk=created.data["id"]).properties["attributes"], ["+ codigo: UUID"])

    def test_quick_project_creation_includes_initial_diagram_atomically(self):
        response = self.client.post("/api/modeling/projects/", {"name": "Proyecto sin título", "create_initial_diagram": True}, format="json")
        self.assertEqual(response.status_code, 201)
        diagram = Diagram.objects.get(project_id=response.data["id"])
        self.assertEqual((diagram.name, diagram.diagram_type), ("Diagrama 1", "class"))

    def test_project_rename_records_a_collaborative_operation(self):
        project = self.create_project()
        response = self.client.patch(f"/api/modeling/projects/{project['id']}/", {"name": "Biblioteca compartida"}, format="json")
        self.assertEqual(response.status_code, 200)
        operation = ModelOperation.objects.filter(project_id=project["id"], entity_type="Project", action="update").latest("created_at")
        self.assertEqual(operation.new_value["name"], "Biblioteca compartida")

    def test_visual_nodes_and_edges_accept_only_allowlisted_contracts(self):
        project = self.create_project()
        diagram = self.client.post(f"/api/modeling/projects/{project['id']}/diagrams/", {"name": "Lienzo", "diagram_type": "class"}, format="json").data
        first = self.client.post(f"/api/modeling/projects/{project['id']}/diagrams/{diagram['id']}/nodes/", {"diagram": diagram["id"], "x": 10, "y": 20, "properties": {"kind": "visual", "library": "general", "shape": "rectangle", "label": "Nota", "style": {"fill": "#ffffff"}}}, format="json")
        second = self.client.post(f"/api/modeling/projects/{project['id']}/diagrams/{diagram['id']}/nodes/", {"diagram": diagram["id"], "x": 220, "y": 20, "properties": {"kind": "visual", "library": "er", "shape": "entity", "label": "Cliente", "style": {}}}, format="json")
        flow = self.client.post(f"/api/modeling/projects/{project['id']}/diagrams/{diagram['id']}/nodes/", {"diagram": diagram["id"], "x": 420, "y": 20, "properties": {"kind": "visual", "library": "flowchart", "shape": "database", "label": "Datos", "style": {"strokeWidth": 2}}}, format="json")
        self.assertEqual((first.status_code, second.status_code, flow.status_code), (201, 201, 201))
        edge = self.client.post(f"/api/modeling/projects/{project['id']}/diagrams/{diagram['id']}/edges/", {"diagram": diagram["id"], "source_node": first.data["id"], "target_node": second.data["id"], "properties": {"kind": "visual", "library": "arrows", "shape": "er-zero-many", "label": "", "sourceHandle": "right", "targetHandle": "left", "style": {"routing": "orthogonal", "lineStyle": "dashed", "startMarker": "one", "endMarker": "zero-many"}}}, format="json")
        self.assertEqual(edge.status_code, 201)
        self.assertEqual((edge.data["properties"]["sourceHandle"], edge.data["properties"]["targetHandle"]), ("right", "left"))
        exported = write_exchange(Project.objects.get(pk=project["id"])).decode("utf-8")
        self.assertNotIn(first.data["id"], exported)
        self.assertNotIn(edge.data["id"], exported)
        rejected = self.client.post(f"/api/modeling/projects/{project['id']}/diagrams/{diagram['id']}/nodes/", {"diagram": diagram["id"], "properties": {"kind": "visual", "library": "general", "shape": "script", "danger": "x"}}, format="json")
        self.assertEqual(rejected.status_code, 400)
        invalid_marker = self.client.post(f"/api/modeling/projects/{project['id']}/diagrams/{diagram['id']}/edges/", {"diagram": diagram["id"], "source_node": first.data["id"], "target_node": second.data["id"], "properties": {"kind": "visual", "library": "arrows", "shape": "arrow", "style": {"endMarker": "arbitrary"}}}, format="json")
        self.assertEqual(invalid_marker.status_code, 400)

    def test_complete_visual_library_and_markers_are_allowlisted(self):
        node_serializer = DiagramNodeSerializer()
        edge_serializer = DiagramEdgeSerializer()
        libraries = {
            "general": {"text", "rectangle", "rounded-rectangle", "ellipse", "circle", "diamond", "triangle", "parallelogram", "hexagon", "cylinder", "document", "note", "cloud", "callout"},
            "flowchart": {"process", "terminator", "decision", "data", "database", "flow-document", "manual-input", "preparation", "delay", "connector", "off-page-connector", "subprocess"},
            "er": {"entity", "weak-entity", "attribute", "key-attribute", "multivalued-attribute", "derived-attribute", "relationship", "identifying-relationship"},
        }
        for library, shapes in libraries.items():
            for shape in shapes:
                properties = {"kind": "visual", "library": library, "shape": shape, "label": shape, "style": {}}
                self.assertEqual(node_serializer.validate_properties(properties), properties)
        edge_shapes = {"line", "arrow", "double-arrow", "dashed", "dashed-arrow", "orthogonal", "curved", "er-one", "er-zero-one", "er-many", "er-one-many", "er-zero-many"}
        markers = {"none", "arrow", "arrow-open", "triangle", "diamond", "diamond-filled", "circle", "one", "zero-one", "many", "one-many", "zero-many"}
        for shape in edge_shapes:
            for marker in markers:
                properties = {"kind": "visual", "library": "arrows", "shape": shape, "label": "", "sourceHandle": "right", "targetHandle": "left", "style": {"routing": "orthogonal", "lineStyle": "solid", "startMarker": "none", "endMarker": marker}}
                self.assertEqual(edge_serializer.validate_properties(properties), properties)

    def test_project_import_is_atomic_and_does_not_leave_invalid_project(self):
        before = Project.objects.count()
        invalid = self.client.post("/api/modeling/projects/import/", {"xml": "<x>"}, format="json")
        self.assertEqual(invalid.status_code, 400)
        self.assertEqual(Project.objects.count(), before)
        xml = '<xmi:XMI xmlns:xmi="http://www.omg.org/spec/XMI/20131001" xmlns:uml="http://www.omg.org/spec/UML/20131001"><uml:Model xmi:id="m"><uml:Class xmi:id="c" name="Cliente"/><uml:Diagram xmi:id="d" name="Clases" /></uml:Model></xmi:XMI>'
        imported = self.client.post("/api/modeling/projects/import/", {"xml": xml, "name": "Importado"}, format="json")
        self.assertEqual(imported.status_code, 201)
        self.assertEqual(imported.data["project"]["name"], "Importado")
        self.assertTrue(UmlElement.objects.filter(project_id=imported.data["project"]["id"], name="Cliente").exists())

    def test_project_has_one_owner_and_unique_membership(self):
        project = self.create_project()
        with self.assertRaises(IntegrityError), transaction.atomic():
            ProjectMembership.objects.create(project_id=project["id"], user=self.other, role="owner")
        with self.assertRaises(IntegrityError), transaction.atomic():
            ProjectMembership.objects.create(project_id=project["id"], user=self.owner, role="editor")

    def test_owner_delete_is_protected(self):
        project = self.create_project()
        with self.assertRaises(ProtectedError):
            self.owner.delete()

    def test_only_owner_can_delete_a_project(self):
        project = self.create_project()
        ProjectMembership.objects.create(project_id=project["id"], user=self.other, role="editor")
        self.client.force_authenticate(self.other)
        denied = self.client.delete(f"/api/modeling/projects/{project['id']}/")
        self.assertEqual(denied.status_code, 403)
        self.assertTrue(Project.objects.filter(pk=project["id"]).exists())
        self.client.force_authenticate(self.owner)
        deleted = self.client.delete(f"/api/modeling/projects/{project['id']}/")
        self.assertEqual(deleted.status_code, 204)
        self.assertFalse(Project.objects.filter(pk=project["id"]).exists())

    def test_invalid_element_is_rejected_without_mutation(self):
        project = self.create_project()
        response = self.client.post(f"/api/modeling/projects/{project['id']}/elements/", {"metaclass": "Unknown", "name": ""}, format="json")
        self.assertEqual(response.status_code, 400)
        self.assertEqual(UmlElement.objects.count(), 0)

    def test_viewer_cannot_mutate_project(self):
        project = self.create_project()
        ProjectMembership.objects.create(project_id=project["id"], user=self.other, role="viewer")
        self.client.force_authenticate(self.other)
        response = self.client.post(f"/api/modeling/projects/{project['id']}/elements/", {"metaclass": "Class", "name": "Libro"}, format="json")
        self.assertEqual(response.status_code, 403)

    def test_authorization_matrix_isolated_for_owner_editor_viewer_and_outsider(self):
        project = self.create_project()
        diagram = self.client.post(f"/api/modeling/projects/{project['id']}/diagrams/", {"name": "Clases", "diagram_type": "class"}, format="json")
        self.assertEqual(diagram.status_code, 201)
        ProjectMembership.objects.create(project_id=project["id"], user=self.other, role="viewer")
        outsider = User.objects.create_user(username="outsider", email="outsider@example.com", password="universidad-123")

        self.client.force_authenticate(self.other)
        self.assertEqual(self.client.get(f"/api/modeling/projects/{project['id']}/").status_code, 200)
        self.assertEqual(self.client.get(f"/api/modeling/projects/{project['id']}/elements/").status_code, 200)
        self.assertEqual(self.client.get(f"/api/modeling/projects/{project['id']}/diagrams/{diagram.data['id']}/nodes/").status_code, 200)
        self.assertEqual(self.client.post(f"/api/modeling/projects/{project['id']}/elements/", {"metaclass": "Class", "name": "Bloqueada"}, format="json").status_code, 403)
        self.assertEqual(self.client.get(f"/api/modeling/projects/{project['id']}/invites/").status_code, 403)

        self.client.force_authenticate(self.owner)
        editor_invite = self.client.post(f"/api/modeling/projects/{project['id']}/invites/create/", {"role": "editor"}, format="json")
        ProjectMembership.objects.create(project_id=project["id"], user=outsider, role="editor")
        self.client.force_authenticate(outsider)
        self.assertEqual(self.client.post(f"/api/modeling/projects/{project['id']}/elements/", {"metaclass": "Class", "name": "Permitida"}, format="json").status_code, 201)
        self.assertEqual(self.client.post(f"/api/modeling/projects/{project['id']}/invites/create/", {}, format="json").status_code, 403)

        self.client.force_authenticate(User.objects.get(username="outsider"))
        foreign_project = self.client.get(f"/api/modeling/projects/{project['id']}/history/")
        self.assertEqual(foreign_project.status_code, 200)
        foreign_user = User.objects.create_user(username="foreign", email="foreign@example.com", password="universidad-123")
        self.client.force_authenticate(foreign_user)
        self.assertEqual(self.client.get(f"/api/modeling/projects/{project['id']}/").status_code, 404)
        self.assertEqual(self.client.get(f"/api/modeling/projects/{project['id']}/interchange/export/").status_code, 404)
        self.assertEqual(self.client.post(f"/api/modeling/projects/{project['id']}/sync/ticket/", {}, format="json").status_code, 404)

    def test_invitation_is_hashed_limited_and_joinable(self):
        project = self.create_project()
        invite = self.client.post(f"/api/modeling/projects/{project['id']}/invites/create/", {"role": "editor", "max_uses": 1, "expires_hours": 1}, format="json")
        self.assertEqual(invite.status_code, 201)
        self.assertNotEqual(invite.data["code"], invite.data["code_hint"])
        self.client.force_authenticate(self.other)
        joined = self.client.post("/api/modeling/projects/join/", {"code": invite.data["code"]}, format="json")
        self.assertEqual(joined.status_code, 200)
        self.assertTrue(ProjectMembership.objects.filter(project_id=project["id"], user=self.other, role="editor").exists())
        exhausted = self.client.post("/api/modeling/projects/join/", {"code": invite.data["code"]}, format="json")
        self.assertEqual(exhausted.status_code, 400)

    def test_expired_and_revoked_invites_are_not_consumed(self):
        project = self.create_project()
        expired = self.client.post(f"/api/modeling/projects/{project['id']}/invites/create/", {"expires_hours": 1}, format="json")
        self.assertEqual(expired.status_code, 201)
        InviteCode.objects.filter(pk=expired.data["id"]).update(expires_at=timezone.now() - timedelta(seconds=1))
        self.client.force_authenticate(self.other)
        self.assertEqual(self.client.post("/api/modeling/projects/join/", {"code": expired.data["code"]}, format="json").status_code, 400)

        self.client.force_authenticate(self.owner)
        revoked = self.client.post(f"/api/modeling/projects/{project['id']}/invites/create/", {"max_uses": 2}, format="json")
        self.assertEqual(revoked.status_code, 201)
        self.assertEqual(self.client.post(f"/api/modeling/projects/{project['id']}/invites/{revoked.data['id']}/revoke/", {}, format="json").status_code, 200)
        self.client.force_authenticate(self.other)
        self.assertEqual(self.client.post("/api/modeling/projects/join/", {"code": revoked.data["code"]}, format="json").status_code, 400)
        self.assertEqual(InviteCode.objects.get(pk=revoked.data["id"]).uses_count, 0)

    def test_operations_are_idempotent_and_revisioned(self):
        project = self.create_project()
        operation_id = str(uuid.uuid4())
        payload = {"operation_id": operation_id, "entity_type": "Diagram", "action": "create", "new_value": {"name": "Clases"}, "base_revision": 0}
        first = self.client.post(f"/api/modeling/projects/{project['id']}/operations/", payload, format="json")
        second = self.client.post(f"/api/modeling/projects/{project['id']}/operations/", payload, format="json")
        self.assertEqual(first.status_code, 201)
        self.assertEqual(second.status_code, 200)
        self.assertEqual(first.data["operation_id"], second.data["operation_id"])
        self.assertEqual(first.data["server_revision"], second.data["server_revision"])

    def test_snapshot_and_conflict_are_retained(self):
        project = self.create_project()
        element = UmlElement.objects.create(project_id=project["id"], metaclass="Class", name="Libro", created_by=self.owner)
        first = self.client.post(f"/api/modeling/projects/{project['id']}/operations/", {"entity_type": "UmlElement", "entity_id": str(element.id), "action": "update", "path": "name", "base_revision": 0, "new_value": "Libro A"}, format="json")
        second = self.client.post(f"/api/modeling/projects/{project['id']}/operations/", {"entity_type": "UmlElement", "entity_id": str(element.id), "action": "update", "path": "name", "base_revision": 0, "new_value": "Libro B"}, format="json")
        self.assertEqual(first.status_code, 201)
        self.assertEqual(second.status_code, 201)
        self.assertEqual(Project.objects.get(pk=project["id"]).revision, 2)
        self.assertEqual(ModelOperation.objects.filter(project_id=project["id"]).count(), 2)
        self.assertEqual(project["id"], str(ProjectSnapshot.objects.get(project_id=project["id"]).project_id))
        history = self.client.get(f"/api/modeling/projects/{project['id']}/history/")
        self.assertEqual(len(history.data["conflicts"]), 1)

    def test_conflict_resolution_creates_new_operation_and_preserves_alternatives(self):
        project = self.create_project()
        element = UmlElement.objects.create(project_id=project["id"], metaclass="Class", name="Libro", created_by=self.owner)
        for value in ("Libro A", "Libro B"):
            response = self.client.post(f"/api/modeling/projects/{project['id']}/operations/", {"entity_type": "UmlElement", "entity_id": str(element.id), "action": "update", "path": "name", "base_revision": 0, "new_value": value}, format="json")
            self.assertEqual(response.status_code, 201)
        conflict = self.client.get(f"/api/modeling/projects/{project['id']}/history/").data["conflicts"][0]
        resolved = self.client.post(f"/api/modeling/projects/{project['id']}/conflicts/{conflict['id']}/resolve/", {"value": "Libro definitivo"}, format="json")
        self.assertEqual(resolved.status_code, 200)
        self.assertEqual(resolved.data["operation"]["action"], "resolve")
        self.assertIsNotNone(resolved.data["conflict"]["resolved_at"])

    def test_validation_reports_unclassified_package_as_warning(self):
        project = self.create_project()
        self.client.post(f"/api/modeling/projects/{project['id']}/packages/", {"name": "Sin nivel"}, format="json")
        response = self.client.get(f"/api/modeling/projects/{project['id']}/validate/")
        self.assertEqual(response.status_code, 200)
        self.assertTrue(any(item["code"] == "mda_unclassified" for item in response.data["warnings"]))

    def test_element_can_have_multiple_views_without_semantic_delete(self):
        project = self.create_project()
        element = UmlElement.objects.create(project_id=project["id"], metaclass="Class", name="Libro", created_by=self.owner)
        first = Diagram.objects.create(project_id=project["id"], name="A", diagram_type="class", created_by=self.owner)
        second = Diagram.objects.create(project_id=project["id"], name="B", diagram_type="object", created_by=self.owner)
        node_a = DiagramNode.objects.create(diagram=first, element=element)
        node_b = DiagramNode.objects.create(diagram=second, element=element)
        node_a.delete()
        self.assertTrue(UmlElement.objects.filter(pk=element.pk).exists())
        self.assertTrue(DiagramNode.objects.filter(pk=node_b.pk).exists())

    def test_semantic_element_delete_cascades_its_views_and_relations(self):
        project = self.create_project()
        element = UmlElement.objects.create(project_id=project["id"], metaclass="Class", name="Libro", created_by=self.owner)
        diagram = Diagram.objects.create(project_id=project["id"], name="Clases", diagram_type="class", created_by=self.owner)
        node = DiagramNode.objects.create(diagram=diagram, element=element)
        response = self.client.delete(f"/api/modeling/projects/{project['id']}/elements/{element.id}/")
        self.assertEqual(response.status_code, 204)
        self.assertFalse(UmlElement.objects.filter(pk=element.pk).exists())
        self.assertFalse(DiagramNode.objects.filter(pk=node.pk).exists())

    def test_mda_classification_and_bidirectional_traceability_are_persisted(self):
        project = self.create_project()
        changed = self.client.patch(f"/api/modeling/projects/{project['id']}/", {"mda_level": "PSM"}, format="json")
        self.assertEqual(changed.status_code, 200)
        self.assertEqual(changed.data["mda_level"], "PSM")
        cim = self.client.post(f"/api/modeling/projects/{project['id']}/elements/", {"metaclass": "Class", "name": "Customer", "properties": {"mda_level": "PIM"}}, format="json")
        psm = self.client.post(f"/api/modeling/projects/{project['id']}/elements/", {"metaclass": "Class", "name": "CustomerEntity", "properties": {"mda_level": "PSM"}}, format="json")
        trace = self.client.post(f"/api/modeling/projects/{project['id']}/relationships/", {"relationship_type": "Trace", "source": cim.data["id"], "target": psm.data["id"], "properties": {"mda": "PIM→PSM"}}, format="json")
        self.assertEqual(trace.status_code, 201)
        links = self.client.get(f"/api/modeling/projects/{project['id']}/relationships/")
        self.assertEqual(links.data[0]["relationship_type"], "Trace")
        self.assertEqual(links.data[0]["properties"]["mda"], "PIM→PSM")
        self.assertTrue(ModelOperation.objects.filter(project=project["id"], entity_type="Project", path="mda_level").exists())

    def test_supported_diagram_fixtures_create_save_reopen_and_validate(self):
        project = self.create_project()
        fixtures = {
            "class": [("Class", "Customer", {"attributes": ["id: UUID"], "operations": ["register()"]}), ("Class", "Order", {"attributes": ["total: Decimal"]})],
            "object": [("Object", "customer01", {"classifier": "Customer", "slots": ["id = 1"]})],
            "package": [("Package", "Sales", {"documentation": "Sales bounded context"})],
            "use_case": [("Actor", "Customer", {}), ("UseCase", "Place order", {"extension_points": ["payment"]})],
            "component": [("Component", "Order Service", {"provided": ["OrderApi"], "required": ["UserApi"]}), ("Interface", "OrderApi", {"operations": ["createOrder()"]})],
            "deployment": [("Node", "Application Server", {"environment": "production"}), ("Artifact", "orders.jar", {"file_name": "orders.jar", "version": "1.0"})],
            "composite_structure": [("Class", "Checkout", {"parts": ["payment: PaymentPort"]}), ("Port", "payment", {"type": "PaymentPort", "required": ["authorize()"]})],
            "profile": [("Profile", "PersistenceProfile", {"version": "1.0"}), ("Stereotype", "Entity", {"base_class": "Class"})],
            "activity": [("Activity", "Checkout", {"preconditions": ["cart not empty"]}), ("Action", "Authorize payment", {"inputs": ["PaymentRequest"], "outputs": ["Receipt"]}), ("DecisionNode", "Approved?", {"decision_input": "payment status"}), ("InitialNode", "Start", {}), ("ActivityFinalNode", "End", {})],
            "state_machine": [("State", "Pending", {"entry": "notify()", "do": "wait()", "exit": "clearTimer()"}), ("FinalState", "Completed", {}), ("Pseudostate", "Start", {"kind": "initial"}), ("Region", "Order lifecycle", {"substates": ["Pending", "Completed"]})],
            "sequence": [("Lifeline", "SeqCustomer", {"represents": "customer01", "order": 1}), ("Lifeline", "SeqOrderService", {"represents": "Order Service", "order": 2}), ("Interaction", "Place order", {"arguments": ["cart"]}), ("CombinedFragment", "alt payment", {"operator": "alt", "guard": "authorized", "fragments": ["confirm"]})],
            "communication": [("Lifeline", "CommCustomer", {"represents": "customer01", "order": 1}), ("Lifeline", "CommOrderService", {"represents": "Order Service", "order": 2}), ("Interaction", "createOrder()", {"arguments": ["cart"]})],
            "interaction_overview": [("Interaction", "Checkout flow", {"refers_to": "Place order"}), ("Activity", "Validate cart", {"preconditions": ["cart loaded"]}), ("DecisionNode", "Payment?", {"decision_input": "payment status"})],
            "timing": [("Lifeline", "TimingOrder", {"represents": "order01", "order": 1}), ("TimeObservation", "Payment accepted", {"event": "payment.accepted", "time_expression": "t+120ms"}), ("State", "TimingPaid", {"entry": "emit()"})],
        }
        for diagram_type, elements in fixtures.items():
            diagram = self.client.post(f"/api/modeling/projects/{project['id']}/diagrams/", {"name": diagram_type, "diagram_type": diagram_type}, format="json")
            self.assertEqual(diagram.status_code, 201)
            for index, (metaclass, name, properties) in enumerate(elements):
                created = self.client.post(f"/api/modeling/projects/{project['id']}/elements/", {"metaclass": metaclass, "name": name, "properties": properties}, format="json")
                self.assertEqual(created.status_code, 201)
                view = self.client.post(f"/api/modeling/projects/{project['id']}/diagrams/{diagram.data['id']}/nodes/", {"element": created.data["id"], "x": index * 220, "y": 40, "width": 180, "height": 80}, format="json")
                self.assertEqual(view.status_code, 201)
                reopened = self.client.get(f"/api/modeling/projects/{project['id']}/diagrams/{diagram.data['id']}/nodes/")
                self.assertEqual(reopened.status_code, 200)
                self.assertTrue(any(str(item["element"]) == created.data["id"] for item in reopened.data))
        activity = {item.name: str(item.id) for item in UmlElement.objects.filter(project=project["id"], name__in=["Start", "Authorize payment"])}
        transition = {item.name: str(item.id) for item in UmlElement.objects.filter(project=project["id"], name__in=["Pending", "Completed"])}
        self.assertEqual(self.client.post(f"/api/modeling/projects/{project['id']}/relationships/", {"relationship_type": "ControlFlow", "source": activity["Start"], "target": activity["Authorize payment"], "properties": {"guard": "cart not empty"}}, format="json").status_code, 201)
        self.assertEqual(self.client.post(f"/api/modeling/projects/{project['id']}/relationships/", {"relationship_type": "Transition", "source": transition["Pending"], "target": transition["Completed"], "properties": {"guard": "payment authorized"}}, format="json").status_code, 201)
        interaction = {item.name: str(item.id) for item in UmlElement.objects.filter(project=project["id"], name__in=["SeqCustomer", "SeqOrderService", "CommCustomer", "CommOrderService", "Checkout flow", "Validate cart", "TimingOrder", "Payment accepted"])}
        self.assertEqual(self.client.post(f"/api/modeling/projects/{project['id']}/relationships/", {"relationship_type": "Message", "source": interaction["SeqCustomer"], "target": interaction["SeqOrderService"], "properties": {"order": 1, "guard": "authorized"}}, format="json").status_code, 201)
        self.assertEqual(self.client.post(f"/api/modeling/projects/{project['id']}/relationships/", {"relationship_type": "Message", "source": interaction["CommCustomer"], "target": interaction["CommOrderService"], "properties": {"order": 1}}, format="json").status_code, 201)
        self.assertEqual(self.client.post(f"/api/modeling/projects/{project['id']}/relationships/", {"relationship_type": "ControlFlow", "source": interaction["Checkout flow"], "target": interaction["Validate cart"], "properties": {}}, format="json").status_code, 201)
        self.assertEqual(self.client.post(f"/api/modeling/projects/{project['id']}/relationships/", {"relationship_type": "Message", "source": interaction["TimingOrder"], "target": interaction["Payment accepted"], "properties": {"time": "t+120ms"}}, format="json").status_code, 201)
        self.assertEqual(self.client.get(f"/api/modeling/projects/{project['id']}/validate/").status_code, 200)

    def test_snapshot_endpoint_and_restore_create_new_revision(self):
        project = self.create_project()
        element = self.client.post(f"/api/modeling/projects/{project['id']}/elements/", {"metaclass": "Class", "name": "Libro"}, format="json")
        snapshot = self.client.post(f"/api/modeling/projects/{project['id']}/snapshots/", {"reason": "manual"}, format="json")
        self.assertEqual(snapshot.status_code, 201)
        self.client.delete(f"/api/modeling/projects/{project['id']}/elements/{element.data['id']}/")
        restored = self.client.post(f"/api/modeling/projects/{project['id']}/snapshots/{snapshot.data['id']}/restore/", {}, format="json")
        self.assertEqual(restored.status_code, 200)
        self.assertTrue(UmlElement.objects.filter(pk=element.data["id"]).exists())
        self.assertGreater(restored.data["revision"], snapshot.data["revision"])

    def test_diagram_views_and_resource_detail_are_persisted(self):
        project = self.create_project()
        element = self.client.post(f"/api/modeling/projects/{project['id']}/elements/", {"metaclass": "Class", "name": "Libro"}, format="json")
        diagram = self.client.post(f"/api/modeling/projects/{project['id']}/diagrams/", {"name": "Clases", "diagram_type": "class"}, format="json")
        node = self.client.post(f"/api/modeling/projects/{project['id']}/diagrams/{diagram.data['id']}/nodes/", {"element": element.data["id"], "x": 10, "y": 20}, format="json")
        self.assertEqual(node.status_code, 201)
        self.assertEqual(str(self.client.get(f"/api/modeling/projects/{project['id']}/diagrams/{diagram.data['id']}/nodes/").data[0]["element"]), element.data["id"])
        renamed = self.client.patch(f"/api/modeling/projects/{project['id']}/elements/{element.data['id']}/", {"name": "Libro actualizado"}, format="json")
        self.assertEqual(renamed.status_code, 200)

    def test_offline_node_update_operation_applies_position(self):
        project = self.create_project()
        element = self.client.post(f"/api/modeling/projects/{project['id']}/elements/", {"metaclass": "Class", "name": "Libro"}, format="json")
        diagram = self.client.post(f"/api/modeling/projects/{project['id']}/diagrams/", {"name": "Clases", "diagram_type": "class"}, format="json")
        node = self.client.post(f"/api/modeling/projects/{project['id']}/diagrams/{diagram.data['id']}/nodes/", {"element": element.data['id'], "x": 10, "y": 20}, format="json")
        operation = self.client.post(f"/api/modeling/projects/{project['id']}/operations/", {"operation_id": str(uuid.uuid4()), "entity_type": "DiagramNode", "entity_id": node.data["id"], "action": "update", "path": "position", "base_revision": 0, "new_value": {"x": 120, "y": 240}}, format="json")
        self.assertEqual(operation.status_code, 201)
        refreshed = self.client.get(f"/api/modeling/projects/{project['id']}/diagrams/{diagram.data['id']}/nodes/")
        self.assertEqual((refreshed.data[0]["x"], refreshed.data[0]["y"]), (120, 240))

    def test_inverse_operations_recreate_and_remove_diagram_view(self):
        project = self.create_project()
        element = self.client.post(f"/api/modeling/projects/{project['id']}/elements/", {"metaclass": "Class", "name": "Libro"}, format="json")
        diagram = self.client.post(f"/api/modeling/projects/{project['id']}/diagrams/", {"name": "Clases", "diagram_type": "class"}, format="json")
        node = self.client.post(f"/api/modeling/projects/{project['id']}/diagrams/{diagram.data['id']}/nodes/", {"element": element.data["id"], "x": 10, "y": 20}, format="json")
        value = {"id": node.data["id"], "diagram": diagram.data["id"], "element": element.data["id"], "x": 10, "y": 20, "width": 180, "height": 80, "properties": {}}
        removed = self.client.post(f"/api/modeling/projects/{project['id']}/operations/", {"entity_type": "DiagramNode", "entity_id": node.data["id"], "action": "delete", "base_revision": 0, "previous_value": value}, format="json")
        self.assertEqual(removed.status_code, 201)
        self.assertFalse(DiagramNode.objects.filter(pk=node.data["id"]).exists())
        restored = self.client.post(f"/api/modeling/projects/{project['id']}/operations/", {"entity_type": "DiagramNode", "entity_id": node.data["id"], "action": "create", "base_revision": 1, "new_value": value}, format="json")
        self.assertEqual(restored.status_code, 201)
        self.assertTrue(DiagramNode.objects.filter(pk=node.data["id"]).exists())

    def test_exchange_export_and_safe_preview_import(self):
        project = self.create_project()
        self.client.post(f"/api/modeling/projects/{project['id']}/elements/", {"metaclass": "Class", "name": "Libro"}, format="json")
        exported = self.client.get(f"/api/modeling/projects/{project['id']}/interchange/export/?profile=omg-xmi-2.5.1")
        self.assertEqual(exported.status_code, 200)
        preview = self.client.post(f"/api/modeling/projects/{project['id']}/interchange/import/", {"xml": exported.content.decode(), "preview": True}, format="json")
        self.assertEqual(preview.status_code, 200)
        self.assertFalse(preview.data["applied"])
        unsafe = self.client.post(f"/api/modeling/projects/{project['id']}/interchange/import/", {"xml": "<!DOCTYPE foo [<!ENTITY xxe SYSTEM 'file:///etc/passwd'>]><x>&xxe;</x>", "preview": True}, format="json")
        self.assertEqual(unsafe.status_code, 400)

    def test_exchange_rejects_malformed_and_oversized_documents(self):
        project = self.create_project()
        malformed = self.client.post(f"/api/modeling/projects/{project['id']}/interchange/import/", {"xml": "<x>", "preview": True}, format="json")
        oversized = self.client.post(f"/api/modeling/projects/{project['id']}/interchange/import/", {"xml": "<x>" + ("a" * (10 * 1024 * 1024)) + "</x>", "preview": True}, format="json")
        self.assertEqual(malformed.status_code, 400)
        self.assertEqual(oversized.status_code, 400)

    def test_exchange_reports_broken_references_in_preview(self):
        project = self.create_project()
        xml = '<xmi:XMI xmlns:xmi="http://www.omg.org/spec/XMI/20131001" xmlns:uml="http://www.omg.org/spec/UML/20131001"><uml:Model xmi:id="m"><uml:Association xmi:id="r" source="missing" target="missing2" /></uml:Model></xmi:XMI>'
        preview = self.client.post(f"/api/modeling/projects/{project['id']}/interchange/import/", {"xml": xml, "preview": True}, format="json")
        self.assertEqual(preview.status_code, 200)
        self.assertTrue(any(item["code"] == "broken_reference" for item in preview.data["warnings"]))

    def test_exchange_round_trip_preserves_diagram_views(self):
        project = self.create_project()
        element = UmlElement.objects.create(project_id=project["id"], metaclass="Class", name="Libro", created_by=self.owner)
        diagram = Diagram.objects.create(project_id=project["id"], name="Clases", diagram_type="class", created_by=self.owner)
        DiagramNode.objects.create(diagram=diagram, element=element, x=12, y=24)
        exported = self.client.get(f"/api/modeling/projects/{project['id']}/interchange/export/?profile=omg-xmi-2.5.1")
        self.assertEqual(exported.status_code, 200)
        self.assertIn(b"UMLDI", exported.content)
        self.assertIn(b"2.5.1", exported.content)
        preview = self.client.post(f"/api/modeling/projects/{project['id']}/interchange/import/", {"xml": exported.content.decode(), "preview": True}, format="json")
        self.assertEqual(preview.status_code, 200)
        self.assertTrue(preview.data["has_presentation"])
        self.assertTrue(any(item["kind"] == "node" for item in preview.data["views"]))
        imported = self.client.post(f"/api/modeling/projects/{project['id']}/interchange/import/", {"xml": exported.content.decode(), "profile": "omg-xmi-2.5.1"}, format="json")
        self.assertEqual(imported.status_code, 201)
        self.assertGreater(DiagramNode.objects.filter(diagram__project=project["id"]).count(), 1)

    def test_sparx_profile_writes_xmi_21_and_reimports(self):
        project = self.create_project()
        self.client.post(f"/api/modeling/projects/{project['id']}/elements/", {"metaclass": "Class", "name": "Cliente"}, format="json")
        exported = self.client.get(f"/api/modeling/projects/{project['id']}/interchange/export/?profile=sparx-ea-xmi-2.1")
        self.assertEqual(exported.status_code, 200)
        self.assertIn(b'version="2.1"', exported.content)
        self.assertIn(b"schema.omg.org/spec/XMI/2.1", exported.content)
        preview = self.client.post(f"/api/modeling/projects/{project['id']}/interchange/import/", {"xml": exported.content.decode(), "profile": "sparx-ea-xmi-2.1", "preview": True}, format="json")
        self.assertEqual(preview.status_code, 200)
        self.assertEqual(preview.data["errors"], [])

    def test_sparx_unknown_extensions_are_preserved_as_opaque_data(self):
        project = self.create_project()
        xml = '<xmi:XMI xmlns:xmi="http://schema.omg.org/spec/XMI/2.1" xmlns:uml="http://www.omg.org/spec/UML/20131001" xmlns:ea="http://www.sparxsystems.com/profiles/EA"><uml:Model xmi:id="m"><uml:Class xmi:id="c" name="Libro"/><ea:TaggedValue name="risk" value="high"/></uml:Model></xmi:XMI>'
        preview = self.client.post(f"/api/modeling/projects/{project['id']}/interchange/import/", {"xml": xml, "profile": "sparx-ea-xmi-2.1", "preview": True}, format="json")
        self.assertEqual(preview.status_code, 200)
        self.assertTrue(any(item["tag"] == "TaggedValue" for item in preview.data["opaque_extensions"]))

    def test_exchange_import_auto_layouts_when_presentation_is_missing(self):
        project = self.create_project()
        xml = '<xmi:XMI xmlns:xmi="http://www.omg.org/spec/XMI/20131001" xmlns:uml="http://www.omg.org/spec/UML/20131001"><uml:Model xmi:id="m"><uml:Class xmi:id="c" name="Libro"/><uml:Diagram xmi:id="d" name="Clases" /></uml:Model></xmi:XMI>'
        preview = self.client.post(f"/api/modeling/projects/{project['id']}/interchange/import/", {"xml": xml, "preview": True}, format="json")
        self.assertTrue(any(item["code"] == "missing_presentation" for item in preview.data["warnings"]))
        imported = self.client.post(f"/api/modeling/projects/{project['id']}/interchange/import/", {"xml": xml}, format="json")
        self.assertEqual(imported.status_code, 201)
        self.assertTrue(DiagramNode.objects.filter(diagram__project=project["id"], properties__layout="automatic").exists())

    def test_exchange_reimport_can_update_known_external_ids_or_create_copy(self):
        project = self.create_project()
        xml = '<xmi:XMI xmlns:xmi="http://www.omg.org/spec/XMI/20131001" xmlns:uml="http://www.omg.org/spec/UML/20131001"><uml:Model xmi:id="m"><uml:Class xmi:id="c" name="Original" /></uml:Model></xmi:XMI>'
        first = self.client.post(f"/api/modeling/projects/{project['id']}/interchange/import/", {"xml": xml}, format="json")
        self.assertEqual(first.status_code, 201)
        self.assertEqual(UmlElement.objects.filter(project=project["id"]).count(), 1)
        changed_xml = xml.replace("Original", "Actualizada")
        preview = self.client.post(f"/api/modeling/projects/{project['id']}/interchange/import/", {"xml": changed_xml, "mode": "update", "preview": True}, format="json")
        self.assertEqual(preview.status_code, 200)
        self.assertEqual(len(preview.data["matches"]), 1)
        updated = self.client.post(f"/api/modeling/projects/{project['id']}/interchange/import/", {"xml": changed_xml, "mode": "update"}, format="json")
        self.assertEqual(updated.status_code, 201)
        self.assertEqual(UmlElement.objects.filter(project=project["id"]).count(), 1)
        self.assertEqual(UmlElement.objects.get(project=project["id"]).name, "Actualizada")
        copied = self.client.post(f"/api/modeling/projects/{project['id']}/interchange/import/", {"xml": changed_xml, "mode": "copy"}, format="json")
        self.assertEqual(copied.status_code, 201)
        self.assertEqual(UmlElement.objects.filter(project=project["id"]).count(), 2)

    def test_exchange_overlay_adds_objects_to_target_diagram_without_replacing_existing_views(self):
        project = self.create_project()
        existing = UmlElement.objects.create(project_id=project["id"], metaclass="Class", name="Existente", created_by=self.owner)
        target = Diagram.objects.create(project_id=project["id"], name="Diagrama actual", diagram_type="class", created_by=self.owner)
        existing_node = DiagramNode.objects.create(diagram=target, element=existing, x=730, y=410)
        xml = '<xmi:XMI xmlns:xmi="http://www.omg.org/spec/XMI/20131001" xmlns:uml="http://www.omg.org/spec/UML/20131001"><uml:Model xmi:id="m"><uml:Class xmi:id="c" name="Importada"/><uml:Diagram xmi:id="d" name="Diagrama externo" /></uml:Model></xmi:XMI>'

        preview = self.client.post(
            f"/api/modeling/projects/{project['id']}/interchange/import/",
            {"xml": xml, "mode": "overlay", "target_diagram_id": str(target.id), "preview": True},
            format="json",
        )
        self.assertEqual(preview.status_code, 200)
        self.assertEqual(preview.data["target_diagram"]["id"], str(target.id))
        self.assertEqual(DiagramNode.objects.filter(diagram=target).count(), 1)

        imported = self.client.post(
            f"/api/modeling/projects/{project['id']}/interchange/import/",
            {"xml": xml, "mode": "overlay", "target_diagram_id": str(target.id)},
            format="json",
        )
        self.assertEqual(imported.status_code, 201)
        self.assertEqual(Diagram.objects.filter(project_id=project["id"]).count(), 1)
        self.assertEqual(DiagramNode.objects.filter(diagram=target).count(), 2)
        existing_node.refresh_from_db()
        self.assertEqual((existing_node.x, existing_node.y), (730, 410))
        self.assertTrue(DiagramNode.objects.filter(diagram=target, element__name="Importada").exists())

    def test_exchange_overlay_rejects_a_diagram_from_another_project(self):
        project = self.create_project()
        other_project = self.create_project()
        foreign_diagram = Diagram.objects.create(project_id=other_project["id"], name="Ajeno", diagram_type="class", created_by=self.owner)
        xml = '<xmi:XMI xmlns:xmi="http://www.omg.org/spec/XMI/20131001" xmlns:uml="http://www.omg.org/spec/UML/20131001"><uml:Model xmi:id="m"><uml:Class xmi:id="c" name="Importada"/></uml:Model></xmi:XMI>'
        response = self.client.post(
            f"/api/modeling/projects/{project['id']}/interchange/import/",
            {"xml": xml, "mode": "overlay", "target_diagram_id": str(foreign_diagram.id)},
            format="json",
        )
        self.assertEqual(response.status_code, 400)
        self.assertEqual(UmlElement.objects.filter(project_id=project["id"]).count(), 0)

    @override_settings(MAX_PROJECT_ELEMENTS=1)
    def test_project_element_limit_returns_clear_error(self):
        project = self.create_project()
        first = self.client.post(f"/api/modeling/projects/{project['id']}/elements/", {"metaclass": "Class", "name": "Uno"}, format="json")
        second = self.client.post(f"/api/modeling/projects/{project['id']}/elements/", {"metaclass": "Class", "name": "Dos"}, format="json")
        self.assertEqual(first.status_code, 201)
        self.assertEqual(second.status_code, 413)

    @override_settings(MAX_COLLABORATORS=1)
    def test_collaborator_limit_is_enforced_before_consuming_invite(self):
        project = self.create_project()
        invite = self.client.post(f"/api/modeling/projects/{project['id']}/invites/create/", {}, format="json")
        self.client.force_authenticate(self.other)
        joined = self.client.post("/api/modeling/projects/join/", {"code": invite.data["code"]}, format="json")
        self.assertEqual(joined.status_code, 409)

    @override_settings(MODEL_SNAPSHOT_INTERVAL=1, SNAPSHOT_RETENTION=1)
    def test_periodic_snapshot_retention_keeps_latest_only(self):
        project = self.create_project()
        self.client.post(f"/api/modeling/projects/{project['id']}/elements/", {"metaclass": "Class", "name": "Uno"}, format="json")
        self.client.post(f"/api/modeling/projects/{project['id']}/elements/", {"metaclass": "Class", "name": "Dos"}, format="json")
        self.assertLessEqual(ProjectSnapshot.objects.filter(project=project["id"], reason="periodic").count(), 1)

    @override_settings(AI_BASE_URL="")
    def test_ai_is_disabled_without_provider_and_does_not_mutate(self):
        project = self.create_project()
        response = self.client.post(f"/api/modeling/projects/{project['id']}/ai/proposals/", {"prompt": "crea una clase"}, format="json")
        self.assertEqual(response.status_code, 503)
        self.assertEqual(Project.objects.get(pk=project["id"]).revision, 0)

    @override_settings(AI_BASE_URL="https://api.xkiro.com/v1", AI_API_KEY="")
    def test_xkiro_without_key_returns_recoverable_configuration_error(self):
        project = self.create_project()
        response = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/proposals/",
            {"prompt": "crea una clase"},
            format="json",
        )
        self.assertEqual(response.status_code, 503)
        self.assertIn("AI_API_KEY", response.data["detail"])
        self.assertEqual(Project.objects.get(pk=project["id"]).revision, 0)

    @override_settings(
        AI_BASE_URL="https://api.xkiro.com/v1",
        AI_API_KEY="secret-that-must-not-leak",
    )
    @patch("modeling.ai.urllib.request.urlopen")
    def test_xkiro_http_error_preserves_safe_provider_diagnostic(self, mocked_urlopen):
        mocked_urlopen.side_effect = urllib.error.HTTPError(
            "https://api.xkiro.com/v1/chat/completions",
            403,
            "Forbidden",
            {},
            io.BytesIO(json.dumps({
                "error": {"message": "API key is inactive"},
            }).encode()),
        )
        project = self.create_project()

        response = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/proposals/",
            {"prompt": "crea una clase"},
            format="json",
        )

        self.assertEqual(response.status_code, 503)
        self.assertIn("HTTP 403", response.data["detail"])
        self.assertIn("API key is inactive", response.data["detail"])
        self.assertNotIn("secret-that-must-not-leak", response.data["detail"])
        self.assertEqual(Project.objects.get(pk=project["id"]).revision, 0)

    def test_owner_can_manage_member_role_and_revoke_invite(self):
        project = self.create_project()
        membership = ProjectMembership.objects.create(project_id=project["id"], user=self.other, role="viewer")
        changed = self.client.patch(f"/api/modeling/projects/{project['id']}/members/{membership.id}/", {"role": "editor"}, format="json")
        self.assertEqual(changed.status_code, 200)
        self.assertEqual(changed.data["role"], "editor")
        invite = self.client.post(f"/api/modeling/projects/{project['id']}/invites/create/", {}, format="json")
        revoked = self.client.post(f"/api/modeling/projects/{project['id']}/invites/{invite.data['id']}/revoke/", {}, format="json")
        self.assertEqual(revoked.status_code, 200)
        self.client.force_authenticate(self.other)
        self.assertEqual(self.client.post("/api/modeling/projects/join/", {"code": invite.data["code"]}, format="json").status_code, 400)

    def test_resource_lists_support_offset_limit_without_changing_default_shape(self):
        project = self.create_project()
        for name in ("A", "B", "C"):
            self.client.post(f"/api/modeling/projects/{project['id']}/elements/", {"metaclass": "Class", "name": name}, format="json")
        self.assertIsInstance(self.client.get(f"/api/modeling/projects/{project['id']}/elements/").data, list)
        paged = self.client.get(f"/api/modeling/projects/{project['id']}/elements/?limit=2&offset=1")
        self.assertEqual(paged.status_code, 200)
        self.assertEqual(paged.data["count"], 3)
        self.assertEqual(len(paged.data["results"]), 2)

    @override_settings(AI_BASE_URL="http://provider.test", AI_API_KEY="secret-for-test")
    @patch("modeling.ai.urllib.request.urlopen")
    def test_ai_proposal_is_structured_and_applied_only_after_confirmation(self, mocked_urlopen):
        class ProviderResponse:
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self): return json.dumps({"operations": [{"entity_type": "UmlElement", "action": "create", "value": {"metaclass": "Class", "name": "Pedido"}}], "warnings": []}).encode()
        mocked_urlopen.return_value = ProviderResponse()
        project = self.create_project()
        proposal = self.client.post(f"/api/modeling/projects/{project['id']}/ai/proposals/", {"prompt": "Crea una clase Pedido"}, format="json")
        self.assertEqual(proposal.status_code, 201)
        self.assertEqual(UmlElement.objects.count(), 0)
        applied = self.client.post(f"/api/modeling/projects/{project['id']}/ai/proposals/{proposal.data['id']}/apply/", {}, format="json")
        self.assertEqual(applied.status_code, 200)
        self.assertTrue(UmlElement.objects.filter(name="Pedido").exists())
        self.assertEqual(applied.data["operations"][0]["origin"], "ai")
        self.assertTrue(ProjectSnapshot.objects.filter(project=project["id"], reason="before_ai").exists())
        sent_payload = json.loads(mocked_urlopen.call_args.args[0].data.decode())
        self.assertNotIn("secret-for-test", json.dumps(sent_payload))

    @override_settings(AI_BASE_URL="http://provider.test")
    @patch("modeling.ai.urllib.request.urlopen")
    def test_ai_normalizes_path_value_update_and_preserves_other_properties(self, mocked_urlopen):
        project = self.create_project()
        element = self.client.post(
            f"/api/modeling/projects/{project['id']}/elements/",
            {
                "metaclass": "Class",
                "name": "Cliente",
                "properties": {
                    "attributes": ["+ nombre: String"],
                    "presentation": "classifier-with-attributes",
                },
            },
            format="json",
        )

        class ProviderResponse:
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self):
                return json.dumps({
                    "operations": [{
                        "id": "add-email",
                        "entity_type": "UmlElement",
                        "entity_id": element.data["id"],
                        "action": "update",
                        "path": "properties.attributes",
                        "value": ["+ nombre: String", "+ email: String"],
                    }],
                    "warnings": [],
                    "questions": [],
                    "assumptions": [],
                    "diagnostics": [],
                }).encode()

        mocked_urlopen.return_value = ProviderResponse()
        proposal = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/proposals/",
            {"prompt": "Agrega email String a Cliente"},
            format="json",
        )

        self.assertEqual(proposal.status_code, 201)
        operation = proposal.data["proposal"]["operations"][0]
        self.assertEqual(
            operation["value"],
            {"properties": {"attributes": ["+ nombre: String", "+ email: String"]}},
        )
        self.assertEqual(proposal.data["proposal"]["diagnostics"][0]["severity"], "info")
        applied = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/proposals/{proposal.data['id']}/apply/",
            {},
            format="json",
        )
        self.assertEqual(applied.status_code, 200)
        saved = UmlElement.objects.get(pk=element.data["id"])
        self.assertEqual(saved.properties["attributes"], ["+ nombre: String", "+ email: String"])
        self.assertEqual(saved.properties["presentation"], "classifier-with-attributes")
        self.assertTrue(ModelOperation.objects.filter(
            project_id=project["id"], entity_type="UmlElement", path="properties.attributes", origin="ai"
        ).exists())

    @override_settings(AI_BASE_URL="http://provider.test")
    @patch("modeling.ai.urllib.request.urlopen")
    def test_ai_repairs_temporary_ids_when_adding_an_element_to_a_diagram(self, mocked_urlopen):
        project = self.create_project()
        diagram = self.client.post(
            f"/api/modeling/projects/{project['id']}/diagrams/",
            {"name": "Clases", "diagram_type": "class"},
            format="json",
        )
        temporary_element_id = "a1b2c3d4-e5f6-7890-g1h2-i3j4k5l6m7n8"

        class ProviderResponse:
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self):
                return json.dumps({
                    "operations": [
                        {
                            "id": temporary_element_id,
                            "entity_type": "UmlElement",
                            "action": "create",
                            "value": {
                                "metaclass": "Class",
                                "name": "Producto",
                                "properties": {"attributes": ["+ nombre: String"]},
                                "diagram_nodes": [{"diagram_id": diagram.data["id"]}],
                            },
                        },
                        {
                            "id": "create-product-node",
                            "entity_type": "DiagramNode",
                            "action": "create",
                            "depends_on": [temporary_element_id],
                            "value": {
                                "diagram_id": diagram.data["id"],
                                "element_id": "11111111-2222-4333-8444-555555555555",
                                "x": 200,
                                "y": 120,
                                "width": 180,
                                "height": 100,
                                "properties": {},
                            },
                        },
                    ],
                    "warnings": [],
                }).encode()

        mocked_urlopen.return_value = ProviderResponse()
        proposal = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/proposals/",
            {"prompt": "Agrega Producto al diagrama", "diagram_id": diagram.data["id"]},
            format="json",
        )

        self.assertEqual(proposal.status_code, 201)
        operations = proposal.data["proposal"]["operations"]
        element_id = operations[0]["entity_id"]
        self.assertEqual(str(uuid.UUID(element_id)), element_id)
        self.assertNotIn("diagram_nodes", operations[0]["value"])
        self.assertEqual(operations[1]["value"]["element"], element_id)
        self.assertIn(operations[0]["id"], operations[1]["depends_on"])

        applied = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/proposals/{proposal.data['id']}/apply/",
            {},
            format="json",
        )
        self.assertEqual(applied.status_code, 200)
        self.assertTrue(UmlElement.objects.filter(pk=element_id, name="Producto").exists())
        self.assertTrue(DiagramNode.objects.filter(diagram_id=diagram.data["id"], element_id=element_id).exists())

    @override_settings(AI_BASE_URL="http://provider.test")
    @patch("modeling.ai.urllib.request.urlopen")
    def test_ai_expands_two_classes_and_applies_many_to_many_relationship(self, mocked_urlopen):
        project = self.create_project()
        diagram = self.client.post(
            f"/api/modeling/projects/{project['id']}/diagrams/",
            {"name": "Clases", "diagram_type": "class"},
            format="json",
        )

        class ProviderResponse:
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self):
                return json.dumps({
                    "operations": [
                        {
                            "id": "many-to-many",
                            "entity_type": "UmlRelationship",
                            "action": "create",
                            "value": json.dumps({
                                "relationship_type": "Association",
                                "source": "Persona",
                                "target": "Mascota",
                                "properties": {"multiplicity": {"source": "*", "target": "*"}},
                            }),
                        },
                        {
                            "id": "classes",
                            "entity_type": "UmlElement",
                            "action": "create",
                            "value": [
                                {"metaclass": "Class", "name": "Persona", "properties": {"attributes": ["+ nombre: String", "+ edad: Integer", "+ sexo: String"]}},
                                {"metaclass": "Class", "name": "Mascota", "properties": {"attributes": ["+ nombre: String", "+ edad: Integer", "+ sexo: String"]}},
                            ],
                        },
                        {
                            "id": "nodes",
                            "entity_type": "DiagramNode",
                            "action": "create",
                            "value": [
                                {"diagram": diagram.data["id"], "element": "Persona", "x": 120, "y": 160, "width": 200, "height": 130, "properties": {}},
                                {"diagram": diagram.data["id"], "element": "Mascota", "x": 480, "y": 160, "width": 200, "height": 130, "properties": {}},
                            ],
                        },
                        {
                            "id": "relationship-edge",
                            "entity_type": "DiagramEdge",
                            "action": "create",
                            "depends_on": ["nodes:1", "nodes:2", "many-to-many"],
                            "value": {
                                "diagram": diagram.data["id"],
                                "relationship": "many-to-many",
                                "source_node": "nodes:1",
                                "target_node": "nodes:2",
                                "properties": {"presentation": {"label": "* ↔ *"}},
                            },
                        },
                    ],
                    "warnings": [],
                }).encode()

        mocked_urlopen.return_value = ProviderResponse()
        proposal = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/proposals/",
            {
                "prompt": "Crea Persona y Mascota con nombre, edad y sexo y relación muchos a muchos",
                "diagram_id": diagram.data["id"],
            },
            format="json",
        )

        self.assertEqual(proposal.status_code, 201)
        operations = proposal.data["proposal"]["operations"]
        self.assertEqual(len(operations), 6)
        self.assertEqual([item["entity_type"] for item in operations[:2]], ["UmlElement", "UmlElement"])
        applied = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/proposals/{proposal.data['id']}/apply/",
            {},
            format="json",
        )

        self.assertEqual(applied.status_code, 200)
        elements = UmlElement.objects.filter(project_id=project["id"], name__in=["Persona", "Mascota"])
        self.assertEqual(elements.count(), 2)
        self.assertTrue(all(len(item.properties["attributes"]) == 3 for item in elements))
        relationship = UmlRelationship.objects.get(project_id=project["id"], relationship_type="Association")
        self.assertEqual(relationship.properties["multiplicity"], {"source": "*", "target": "*"})
        self.assertEqual(DiagramNode.objects.filter(diagram_id=diagram.data["id"], element__in=elements).count(), 2)
        self.assertTrue(DiagramEdge.objects.filter(diagram_id=diagram.data["id"], relationship=relationship).exists())

    @override_settings(AI_BASE_URL="http://provider.test")
    @patch("modeling.ai.urllib.request.urlopen")
    def test_ai_normalizes_provider_aliases_and_structured_class_attributes(self, mocked_urlopen):
        project = self.create_project()
        diagram = self.client.post(
            f"/api/modeling/projects/{project['id']}/diagrams/",
            {"name": "Clases", "diagram_type": "class"},
            format="json",
        )
        persona_id = str(uuid.uuid4())
        mascota_id = str(uuid.uuid4())
        relationship_id = str(uuid.uuid4())

        class ProviderResponse:
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self):
                return json.dumps({
                    "operations": [
                        {"id": "op1", "entity_type": "UmlElement", "entity_id": persona_id, "action": "create", "value": {"meta_class": "Class", "name": "Persona", "properties": {"attributes": [{"name": "nombre", "type": "String"}, {"name": "edad", "type": "Integer"}]}}},
                        {"id": "op2", "entity_type": "DiagramNode", "action": "create", "depends_on": ["op1"], "value": {"diagram_id": diagram.data["id"], "element_ref": persona_id}},
                        {"id": "op3", "entity_type": "UmlElement", "entity_id": mascota_id, "action": "create", "value": {"meta_class": "Class", "name": "Mascota", "properties": {"attributes": [{"name": "especie", "type": "String"}, {"name": "peso", "type": "Float"}]}}},
                        {"id": "op4", "entity_type": "DiagramNode", "action": "create", "depends_on": ["op3"], "value": {"diagram_id": diagram.data["id"], "element_ref": mascota_id}},
                        {"id": "op5", "entity_type": "UmlRelationship", "entity_id": relationship_id, "action": "create", "depends_on": ["op1", "op3"], "value": {"relationship_type": "Association", "source_element_ref": persona_id, "target_element_ref": mascota_id, "properties": {"multiplicity": {"source": "*", "target": "*"}}}},
                        {"id": "op6", "entity_type": "DiagramEdge", "action": "create", "depends_on": ["op2", "op4", "op5"], "value": {"diagram_id": diagram.data["id"], "relationship_ref": relationship_id, "source_node_ref": persona_id, "target_node_ref": mascota_id}},
                    ],
                    "warnings": [], "questions": [], "assumptions": [], "diagnostics": [],
                }).encode()

        mocked_urlopen.return_value = ProviderResponse()
        proposal = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/proposals/",
            {"prompt": "Crea Persona y Mascota y relaciónalas de muchos a muchos", "diagram_id": diagram.data["id"]},
            format="json",
        )
        self.assertEqual(proposal.status_code, 201)
        first = proposal.data["proposal"]["operations"][0]
        self.assertEqual(first["value"]["metaclass"], "Class")
        self.assertEqual(first["value"]["properties"]["attributes"], ["+ nombre: String", "+ edad: Integer"])

        applied = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/proposals/{proposal.data['id']}/apply/",
            {},
            format="json",
        )
        self.assertEqual(applied.status_code, 200)
        self.assertEqual(UmlElement.objects.filter(project_id=project["id"], metaclass="Class").count(), 2)
        relationship = UmlRelationship.objects.get(project_id=project["id"])
        self.assertEqual(relationship.properties["multiplicity"], {"source": "*", "target": "*"})
        self.assertTrue(DiagramEdge.objects.filter(diagram_id=diagram.data["id"], relationship=relationship).exists())

    @override_settings(AI_BASE_URL="http://provider.test")
    @patch("modeling.ai.urllib.request.urlopen")
    def test_ai_normalizes_closed_metaclass_variants_but_rejects_unknown_values(self, mocked_urlopen):
        class ProviderResponse:
            def __init__(self, operations): self.operations = operations
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self):
                return json.dumps({"operations": self.operations, "warnings": [], "questions": [], "assumptions": [], "diagnostics": []}).encode()

        project = self.create_project()
        mocked_urlopen.return_value = ProviderResponse([
            {"id": "first", "entity_type": "uml_element", "action": "create", "value": {"metaclass": "UML::class", "name": "Primera"}},
            {"id": "second", "entity_type": "UmlElement", "action": "create", "value": {"type": "Clase", "name": "Segunda"}},
        ])
        proposal = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/proposals/",
            {"prompt": "Crea dos clases"},
            format="json",
        )
        self.assertEqual(proposal.status_code, 201)
        self.assertEqual([item["value"]["metaclass"] for item in proposal.data["proposal"]["operations"]], ["Class", "Class"])

        mocked_urlopen.return_value = ProviderResponse([
            {"id": "invalid", "entity_type": "UmlElement", "action": "create", "value": {"metaclass": "InventedMetaClass", "name": "Inválida"}},
        ])
        rejected = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/proposals/",
            {"prompt": "Crea otra clase"},
            format="json",
        )
        self.assertEqual(rejected.status_code, 503)
        self.assertIn("InventedMetaClass", rejected.data["detail"])

    @override_settings(AI_BASE_URL="http://provider.test")
    @patch("modeling.ai.urllib.request.urlopen")
    def test_ai_completes_and_applies_a_three_class_many_to_many_graph(self, mocked_urlopen):
        project = self.create_project()
        diagram = self.client.post(
            f"/api/modeling/projects/{project['id']}/diagrams/",
            {"name": "Clases", "diagram_type": "class"},
            format="json",
        )
        element_ids = [str(uuid.uuid4()) for _ in range(3)]
        relationship_ids = [str(uuid.uuid4()) for _ in range(3)]
        names = ["Estudiante", "Curso", "Profesor"]
        pairs = [(0, 1), (1, 2), (0, 2)]
        operations = []
        for index, (element_id, name) in enumerate(zip(element_ids, names), start=1):
            element_operation = f"element-{index}"
            node_operation = f"node-{index}"
            operations.extend([
                {"id": element_operation, "entity_type": "UmlElement", "entity_id": element_id, "action": "create", "value": {"metaclass": "Class", "name": name, "properties": {"attributes": ["+ id: String"]}}},
                {"id": node_operation, "entity_type": "DiagramNode", "action": "create", "depends_on": [element_operation], "value": {"element": element_id}},
            ])
        for index, ((source_index, target_index), relationship_id) in enumerate(zip(pairs, relationship_ids), start=1):
            relationship_operation = f"relationship-{index}"
            operations.extend([
                {"id": relationship_operation, "entity_type": "UmlRelationship", "entity_id": relationship_id, "action": "create", "depends_on": [f"element-{source_index + 1}", f"element-{target_index + 1}"], "value": {"relationship_type": "Association", "source": element_ids[source_index], "target": element_ids[target_index], "properties": {"multiplicity": {"source": "*", "target": "*"}}}},
                {"id": f"edge-{index}", "entity_type": "DiagramEdge", "action": "create", "depends_on": [f"node-{source_index + 1}", f"node-{target_index + 1}", relationship_operation], "value": {"relationship": relationship_id, "source_node": f"<node_{source_index}>", "target_node": f"<node_{target_index}>"}},
            ])

        class ProviderResponse:
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self):
                return json.dumps({"operations": operations, "warnings": [], "questions": [], "assumptions": [], "diagnostics": []}).encode()

        mocked_urlopen.return_value = ProviderResponse()
        proposal = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/proposals/",
            {"prompt": "Crea tres clases relacionadas muchos a muchos", "diagram_id": diagram.data["id"]},
            format="json",
        )
        self.assertEqual(proposal.status_code, 201)
        normalized = proposal.data["proposal"]["operations"]
        nodes = [item for item in normalized if item["entity_type"] == "DiagramNode"]
        edges = [item for item in normalized if item["entity_type"] == "DiagramEdge"]
        self.assertEqual(len(nodes), 3)
        self.assertEqual(len(edges), 3)
        self.assertTrue(all(item["value"]["diagram"] == diagram.data["id"] for item in nodes + edges))
        self.assertTrue(all(not item["value"]["source_node"].startswith("<") for item in edges))

        applied = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/proposals/{proposal.data['id']}/apply/",
            {},
            format="json",
        )
        self.assertEqual(applied.status_code, 200)
        self.assertEqual(UmlElement.objects.filter(project_id=project["id"], metaclass="Class").count(), 3)
        self.assertEqual(UmlRelationship.objects.filter(project_id=project["id"], relationship_type="Association").count(), 3)
        self.assertEqual(DiagramNode.objects.filter(diagram_id=diagram.data["id"]).count(), 3)
        self.assertEqual(DiagramEdge.objects.filter(diagram_id=diagram.data["id"]).count(), 3)

    @override_settings(AI_BASE_URL="http://provider.test")
    @patch("modeling.ai.urllib.request.urlopen")
    def test_ai_keeps_an_explicit_rectangle_and_diamond_as_visual_shapes(self, mocked_urlopen):
        project = self.create_project()
        diagram = self.client.post(
            f"/api/modeling/projects/{project['id']}/diagrams/",
            {"name": "Lienzo", "diagram_type": "class"},
            format="json",
        )

        class ProviderResponse:
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self):
                return json.dumps({
                    "operations": [
                        {"id": "dog", "entity_type": "UmlElement", "action": "create", "value": {"metaclass": "Class", "name": "Perro"}},
                        {"id": "cat", "entity_type": "UmlElement", "action": "create", "value": {"metaclass": "Class", "name": "Gato"}},
                        {"id": "association", "entity_type": "UmlRelationship", "action": "create", "depends_on": ["dog", "cat"], "value": {"relationship_type": "Association", "source": "dog", "target": "cat"}},
                    ],
                    "warnings": [], "questions": [], "assumptions": [], "diagnostics": [],
                }).encode()

        mocked_urlopen.return_value = ProviderResponse()
        proposal = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/proposals/",
            {"prompt": "Añade un cuadrado y un rombo, relaciónalos y ponles nombres de animales", "diagram_id": diagram.data["id"]},
            format="json",
        )
        self.assertEqual(proposal.status_code, 201)
        operations = proposal.data["proposal"]["operations"]
        self.assertEqual([item["entity_type"] for item in operations], ["DiagramNode", "DiagramNode", "DiagramEdge"])
        self.assertEqual([item["value"]["properties"]["shape"] for item in operations[:2]], ["rectangle", "diamond"])
        self.assertEqual([item["value"]["properties"]["label"] for item in operations[:2]], ["Perro", "Gato"])
        self.assertTrue(all(item["value"].get("element") is None for item in operations[:2]))
        self.assertIsNone(operations[2]["value"]["relationship"])

        applied = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/proposals/{proposal.data['id']}/apply/",
            {},
            format="json",
        )
        self.assertEqual(applied.status_code, 200)
        self.assertEqual(UmlElement.objects.filter(project_id=project["id"]).count(), 0)
        self.assertEqual(UmlRelationship.objects.filter(project_id=project["id"]).count(), 0)
        self.assertEqual(DiagramNode.objects.filter(diagram_id=diagram.data["id"], properties__kind="visual").count(), 2)
        self.assertEqual(DiagramEdge.objects.filter(diagram_id=diagram.data["id"], properties__kind="visual").count(), 1)

    @override_settings(AI_BASE_URL="http://provider.test")
    @patch("modeling.ai.urllib.request.urlopen")
    def test_ai_replaces_named_uml_views_with_visual_shapes_without_deleting_semantics(self, mocked_urlopen):
        project_data = self.create_project()
        project = Project.objects.get(pk=project_data["id"])
        diagram = Diagram.objects.create(
            project=project,
            name="Lienzo",
            diagram_type="class",
            created_by=self.owner,
        )
        dog = UmlElement.objects.create(
            project=project, metaclass="Interface", name="perro", created_by=self.owner,
        )
        cat = UmlElement.objects.create(
            project=project, metaclass="Class", name="gato", created_by=self.owner,
        )
        dog_node = DiagramNode.objects.create(
            diagram=diagram, element=dog, x=-162.79, y=-13.45, width=150, height=80,
        )
        cat_node = DiagramNode.objects.create(
            diagram=diagram, element=cat, x=142.88, y=-177.57, width=150, height=80,
        )
        relationship = UmlRelationship.objects.create(
            project=project,
            relationship_type="Association",
            source=cat,
            target=dog,
        )
        DiagramEdge.objects.create(
            diagram=diagram,
            relationship=relationship,
            source_node=cat_node,
            target_node=dog_node,
        )

        class ProviderResponse:
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self):
                return json.dumps({
                    "operations": [
                        {
                            "id": "diamond",
                            "entity_type": "DiagramNode",
                            "action": "create",
                            "value": {
                                "diagram": str(diagram.id), "element": None,
                                "x": 140, "y": 160, "width": 150, "height": 110,
                                "properties": {"kind": "visual", "library": "general", "shape": "diamond", "label": "Rombo", "style": {}},
                            },
                        },
                        {
                            "id": "rectangle",
                            "entity_type": "DiagramNode",
                            "action": "create",
                            "value": {
                                "diagram": str(diagram.id), "element": None,
                                "x": 440, "y": 160, "width": 180, "height": 110,
                                "properties": {"kind": "visual", "library": "general", "shape": "rectangle", "label": "Cuadrado", "style": {}},
                            },
                        },
                    ],
                    "questions": [
                        "Se eliminarán los elementos UML subyacentes y se crearán figuras visuales. ¿Es este comportamiento deseado?"
                    ],
                    "warnings": [], "assumptions": [], "diagnostics": [],
                }).encode()

        mocked_urlopen.return_value = ProviderResponse()
        proposal = self.client.post(
            f"/api/modeling/projects/{project.id}/ai/proposals/",
            {
                "prompt": "puedes reemplazar las clases que estan como perro y gato por las figura rombo y cuadrado",
                "diagram_id": str(diagram.id),
            },
            format="json",
        )

        self.assertEqual(proposal.status_code, 201)
        normalized = proposal.data["proposal"]
        self.assertEqual(normalized["questions"], [])
        created_nodes = [
            item for item in normalized["operations"]
            if item["entity_type"] == "DiagramNode" and item["action"] == "create"
        ]
        created_edge = next(
            item for item in normalized["operations"]
            if item["entity_type"] == "DiagramEdge" and item["action"] == "create"
        )
        deleted_nodes = [
            item for item in normalized["operations"]
            if item["entity_type"] == "DiagramNode" and item["action"] == "delete"
        ]
        self.assertEqual(
            [(item["value"]["properties"]["label"], item["value"]["properties"]["shape"]) for item in created_nodes],
            [("perro", "diamond"), ("gato", "rectangle")],
        )
        self.assertEqual(
            [(item["value"]["x"], item["value"]["y"]) for item in created_nodes],
            [(dog_node.x, dog_node.y), (cat_node.x, cat_node.y)],
        )
        self.assertIsNone(created_edge["value"]["relationship"])
        self.assertEqual({item["entity_id"] for item in deleted_nodes}, {str(dog_node.id), str(cat_node.id)})

        applied = self.client.post(
            f"/api/modeling/projects/{project.id}/ai/proposals/{proposal.data['id']}/apply/",
            {"operation_ids": [item["id"] for item in normalized["operations"]]},
            format="json",
        )
        self.assertEqual(applied.status_code, 200)
        self.assertTrue(UmlElement.objects.filter(pk=dog.id).exists())
        self.assertTrue(UmlElement.objects.filter(pk=cat.id).exists())
        self.assertTrue(UmlRelationship.objects.filter(pk=relationship.id).exists())
        self.assertFalse(DiagramNode.objects.filter(pk=dog_node.id).exists())
        self.assertFalse(DiagramNode.objects.filter(pk=cat_node.id).exists())
        self.assertEqual(DiagramNode.objects.filter(diagram=diagram, properties__kind="visual").count(), 2)
        self.assertEqual(DiagramEdge.objects.filter(diagram=diagram, properties__kind="visual").count(), 1)

    @override_settings(AI_BASE_URL="http://provider.test")
    @patch("modeling.ai.urllib.request.urlopen")
    def test_ai_connects_actor_to_package_figure_without_blocking_question(self, mocked_urlopen):
        project_data = self.create_project()
        project = Project.objects.get(pk=project_data["id"])
        diagram = Diagram.objects.create(
            project=project,
            name="Clases",
            diagram_type="class",
            created_by=self.owner,
        )
        actor_id = "a1b2c3d4-e5f6-4789-abcd-ef0123456789"
        package_id = "b2c3d4e5-f6a7-4890-bcde-f01234567890"
        relationship_id = "c3d4e5f6-a7b8-4901-cdef-012345678901"
        actor_node_id = "d4e5f6a7-b8c9-4012-defa-123456789012"
        package_node_id = "e5f6a7b8-c9d0-4123-efab-234567890123"

        class ProviderResponse:
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self):
                return json.dumps({
                    "operations": [
                        {
                            "id": "create-actor", "entity_type": "UmlElement", "entity_id": actor_id,
                            "action": "create", "value": {
                                "metaclass": "Actor", "name": "cliente", "package_id": None, "properties": {},
                            },
                        },
                        {
                            "id": "create-package", "entity_type": "UmlPackage", "entity_id": package_id,
                            "action": "create", "value": {"name": "cajas", "parent_id": None, "properties": {}},
                        },
                        {
                            "id": "create-relation", "entity_type": "UmlRelationship", "entity_id": relationship_id,
                            "action": "create", "value": {
                                "relationship_type": "Association", "source_id": actor_id,
                                "target_id": package_id, "properties": {},
                            },
                        },
                        {
                            "id": "create-actor-node", "entity_type": "DiagramNode", "entity_id": actor_node_id,
                            "action": "create", "value": {
                                "diagram": str(diagram.id), "element": actor_id, "x": -500, "y": 400,
                                "width": 100, "height": 100, "properties": {},
                            },
                        },
                        {
                            "id": "create-package-node", "entity_type": "DiagramNode", "entity_id": package_node_id,
                            "action": "create", "value": {
                                "element": package_id, "x": -300, "y": 400,
                                "width": 150, "height": 100, "properties": {},
                            },
                        },
                        {
                            "id": "create-edge", "entity_type": "DiagramEdge", "action": "create",
                            "value": {
                                "diagram": str(diagram.id), "relationship": relationship_id,
                                "source_node": actor_node_id, "target_node": package_node_id, "properties": {},
                            },
                        },
                    ],
                    "questions": [
                        "¿Qué tipo de relación deseas entre 'cliente' y el paquete 'cajas'? He asumido una Asociación simple."
                    ],
                    "assumptions": ["Se establece una relación de tipo Association."],
                    "warnings": [], "diagnostics": [],
                }).encode()

        mocked_urlopen.return_value = ProviderResponse()
        proposal = self.client.post(
            f"/api/modeling/projects/{project.id}/ai/proposals/",
            {
                "prompt": "añade un actor llamado cliente y relacionalo con un paquete llamado cajas",
                "diagram_id": str(diagram.id),
            },
            format="json",
        )

        self.assertEqual(proposal.status_code, 201)
        normalized = proposal.data["proposal"]
        self.assertEqual(normalized["questions"], [])
        self.assertFalse(any(item["entity_type"] == "UmlPackage" for item in normalized["operations"]))
        elements = [item for item in normalized["operations"] if item["entity_type"] == "UmlElement"]
        self.assertEqual(
            {(item["value"]["name"], item["value"]["metaclass"]) for item in elements},
            {("cliente", "Actor"), ("cajas", "Package")},
        )
        package_node = next(
            item for item in normalized["operations"]
            if item["entity_type"] == "DiagramNode" and item["value"]["element"] == package_id
        )
        self.assertEqual(package_node["value"]["diagram"], str(diagram.id))

        applied = self.client.post(
            f"/api/modeling/projects/{project.id}/ai/proposals/{proposal.data['id']}/apply/",
            {"operation_ids": [item["id"] for item in normalized["operations"]]},
            format="json",
        )
        self.assertEqual(applied.status_code, 200)
        self.assertFalse(UmlPackage.objects.filter(project=project, name="cajas").exists())
        actor = UmlElement.objects.get(project=project, name="cliente")
        package = UmlElement.objects.get(project=project, name="cajas")
        self.assertEqual(actor.metaclass, "Actor")
        self.assertEqual(package.metaclass, "Package")
        relationship = UmlRelationship.objects.get(project=project, source=actor, target=package)
        self.assertEqual(relationship.relationship_type, "Association")
        self.assertEqual(DiagramNode.objects.filter(diagram=diagram, element__in=[actor, package]).count(), 2)
        self.assertTrue(DiagramEdge.objects.filter(diagram=diagram, relationship=relationship).exists())

    @override_settings(AI_BASE_URL="http://provider.test")
    @patch("modeling.ai.urllib.request.urlopen")
    def test_ai_completes_incomplete_explicit_many_to_many_canvas_graph(self, mocked_urlopen):
        project = self.create_project()
        diagram = self.client.post(
            f"/api/modeling/projects/{project['id']}/diagrams/",
            {"name": "Clases", "diagram_type": "class"},
            format="json",
        )
        nested_persona_id = str(uuid.uuid4())
        nested_mascota_id = str(uuid.uuid4())

        class ProviderResponse:
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self):
                return json.dumps({
                    "operations": [
                        {"id": "persona", "entity_type": "UmlElement", "action": "create", "value": {"entity_id": nested_persona_id, "metaclass": "Class", "name": "Persona", "properties": {"attributes": ["+ nombre: String", "+ edad: Integer", "+ sexo: String"]}}},
                        {"id": "mascota", "entity_type": "UmlElement", "action": "create", "value": {"entity_id": nested_mascota_id, "metaclass": "Class", "name": "Mascota", "properties": {"attributes": ["+ nombre: String", "+ edad: Integer", "+ sexo: String"]}}},
                        {"id": "relation", "entity_type": "UmlRelationship", "action": "create", "value": {"relationship_type": "Association", "source": str(uuid.uuid4()), "target": None, "properties": {}}},
                        {"id": "node-persona", "entity_type": "DiagramNode", "action": "create", "value": {"diagram": diagram.data["id"], "element": None}},
                        {"id": "node-mascota", "entity_type": "DiagramNode", "action": "create", "depends_on": ["mascota"], "value": {"diagram": diagram.data["id"], "element": "mascota"}},
                    ],
                    "questions": [
                        "¿Cuál será el ID de Mascota para establecer la relación?",
                        "¿Desea agregar las clases al diagrama actual?",
                    ],
                    "warnings": [],
                }).encode()

        mocked_urlopen.return_value = ProviderResponse()
        proposal = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/proposals/",
            {
                "prompt": "Crea Persona y Mascota con nombre, edad y sexo y relaciónalas de muchos a muchos",
                "diagram_id": diagram.data["id"],
            },
            format="json",
        )

        self.assertEqual(proposal.status_code, 201)
        self.assertEqual(proposal.data["proposal"]["questions"], [])
        self.assertEqual(len(proposal.data["proposal"]["operations"]), 6)
        self.assertEqual(proposal.data["proposal"]["operations"][0]["entity_id"], nested_persona_id)
        self.assertNotIn("entity_id", proposal.data["proposal"]["operations"][0]["value"])
        applied = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/proposals/{proposal.data['id']}/apply/",
            {},
            format="json",
        )
        self.assertEqual(applied.status_code, 200)
        relationship = UmlRelationship.objects.get(project_id=project["id"])
        self.assertEqual({relationship.source.name, relationship.target.name}, {"Persona", "Mascota"})
        self.assertEqual(relationship.properties["multiplicity"], {"source": "*", "target": "*"})
        self.assertTrue(DiagramEdge.objects.filter(diagram_id=diagram.data["id"], relationship=relationship).exists())

    @override_settings(AI_BASE_URL="http://provider.test")
    @patch("modeling.ai.urllib.request.urlopen")
    def test_ai_rejects_unsafe_or_ambiguous_scalar_updates(self, mocked_urlopen):
        project = self.create_project()

        class ProviderResponse:
            def __init__(self, payload): self.payload = payload
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self): return json.dumps(self.payload).encode()

        base = {"entity_type": "UmlElement", "action": "update", "entity_id": str(uuid.uuid4()), "value": "x"}
        for path in ("", "id", "name.first"):
            operation = {**base, "path": path}
            mocked_urlopen.return_value = ProviderResponse({"operations": [operation], "warnings": []})
            response = self.client.post(
                f"/api/modeling/projects/{project['id']}/ai/proposals/",
                {"prompt": "actualiza"},
                format="json",
            )
            self.assertEqual(response.status_code, 503)
        self.assertFalse(project["id"] in [str(item.project_id) for item in UmlElement.objects.all()])

    @override_settings(
        AI_PROVIDER="xkiro",
        AI_BASE_URL="https://api.xkiro.test/v1",
        AI_API_KEY="xkiro-secret",
        AI_MODEL="minimax/minimax-m3:free",
    )
    @patch("modeling.ai.urllib.request.urlopen")
    def test_ai_uses_openai_tool_call_without_exposing_key(self, mocked_urlopen):
        arguments = {
            "operations": [
                {
                    "id": "create-customer",
                    "entity_type": "UmlElement",
                    "action": "create",
                    "value": {"metaclass": "Class", "name": "Cliente"},
                    "depends_on": [],
                    "explanation": "Representa al cliente del dominio.",
                }
            ],
            "questions": [],
            "assumptions": [],
            "warnings": [],
            "diagnostics": [],
        }

        class ProviderResponse:
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self):
                return json.dumps({
                    "choices": [{
                        "message": {
                            "content": None,
                            "tool_calls": [{
                                "function": {
                                    "name": "submit_uml_proposal",
                                    "arguments": json.dumps(arguments),
                                }
                            }],
                        }
                    }]
                }).encode()

        mocked_urlopen.return_value = ProviderResponse()
        project = self.create_project()
        diagram = self.client.post(
            f"/api/modeling/projects/{project['id']}/diagrams/",
            {"name": "Clases", "diagram_type": "class"},
            format="json",
        )
        response = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/proposals/",
            {"prompt": "Agrega Cliente", "diagram_id": diagram.data["id"]},
            format="json",
        )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data["provider"], "xkiro")
        self.assertEqual(response.data["model"], "minimax/minimax-m3:free")
        self.assertEqual(response.data["proposal"]["operations"][0]["value"]["name"], "Cliente")
        sent_request = mocked_urlopen.call_args.args[0]
        sent_payload = json.loads(sent_request.data.decode())
        self.assertEqual(sent_request.full_url, "https://api.xkiro.test/v1/chat/completions")
        self.assertEqual(sent_request.headers["Authorization"], "Bearer xkiro-secret")
        self.assertEqual(sent_request.headers["Accept"], "application/json")
        self.assertEqual(sent_request.headers["User-agent"], "sw1-uml-modeler/1.0")
        self.assertEqual(sent_payload["tool_choice"]["function"]["name"], "submit_uml_proposal")
        self.assertIn('"diagram"', sent_payload["messages"][1]["content"])
        self.assertNotIn("xkiro-secret", json.dumps(sent_payload))

    @override_settings(AI_BASE_URL="http://provider.test")
    @patch("modeling.ai.urllib.request.urlopen")
    def test_ai_retries_empty_tool_response_once_in_json_mode(self, mocked_urlopen):
        class ProviderResponse:
            def __init__(self, payload): self.payload = payload
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self): return json.dumps(self.payload).encode()

        mocked_urlopen.side_effect = [
            ProviderResponse({
                "choices": [{"message": {"role": "assistant", "content": ""}, "finish_reason": "stop"}],
                "usage": {"completion_tokens": 0},
            }),
            ProviderResponse({
                "choices": [{
                    "message": {"role": "assistant", "content": json.dumps({
                        "operations": [{
                            "id": "create-person",
                            "entity_type": "UmlElement",
                            "action": "create",
                            "value": {"metaclass": "Class", "name": "Persona"},
                        }],
                        "questions": [],
                        "assumptions": [],
                        "warnings": [],
                        "diagnostics": [],
                    })},
                    "finish_reason": "stop",
                }],
            }),
        ]
        project = self.create_project()
        response = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/proposals/",
            {"prompt": "Crea Persona"},
            format="json",
        )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(mocked_urlopen.call_count, 2)
        fallback = json.loads(mocked_urlopen.call_args_list[1].args[0].data.decode())
        self.assertEqual(fallback["response_format"], {"type": "json_object"})
        self.assertNotIn("tools", fallback)

    @override_settings(AI_BASE_URL="http://provider.test")
    @patch("modeling.ai.urllib.request.urlopen")
    def test_ai_retries_a_closed_tool_connection_in_json_mode(self, mocked_urlopen):
        class ProviderResponse:
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self):
                return json.dumps({
                    "choices": [{
                        "message": {"role": "assistant", "content": json.dumps({
                            "operations": [{
                                "id": "create-person",
                                "entity_type": "UmlElement",
                                "action": "create",
                                "value": {"metaclass": "Class", "name": "Persona"},
                            }],
                            "questions": [],
                            "assumptions": [],
                            "warnings": [],
                            "diagnostics": [],
                        })},
                        "finish_reason": "stop",
                    }],
                }).encode()

        mocked_urlopen.side_effect = [
            http.client.RemoteDisconnected("Remote end closed connection without response"),
            ProviderResponse(),
        ]
        project = self.create_project()
        response = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/proposals/",
            {"prompt": "Crea Persona"},
            format="json",
        )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(mocked_urlopen.call_count, 2)
        fallback = json.loads(mocked_urlopen.call_args_list[1].args[0].data.decode())
        self.assertNotIn("tools", fallback)
        self.assertEqual(response.data["proposal"]["operations"][0]["value"]["name"], "Persona")

    @override_settings(AI_BASE_URL="http://provider.test")
    @patch("modeling.ai.urllib.request.urlopen", side_effect=http.client.RemoteDisconnected("closed"))
    def test_ai_closed_connections_return_recoverable_error_without_mutation(self, mocked_urlopen):
        project = self.create_project()
        response = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/proposals/",
            {"prompt": "Crea Persona y Mascota"},
            format="json",
        )

        self.assertEqual(response.status_code, 503)
        self.assertIn("ambos intentos", response.data["detail"])
        self.assertEqual(mocked_urlopen.call_count, 2)
        self.assertEqual(Project.objects.get(pk=project["id"]).revision, 0)

    @override_settings(AI_BASE_URL="http://provider.test", AI_MAX_PROMPT_CHARS=10)
    def test_ai_rejects_oversized_prompt_before_calling_provider(self):
        project = self.create_project()
        response = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/proposals/",
            {"prompt": "x" * 11},
            format="json",
        )
        self.assertEqual(response.status_code, 400)
        self.assertEqual(Project.objects.get(pk=project["id"]).revision, 0)

    @override_settings(AI_BASE_URL="http://provider.test")
    @patch("modeling.ai.urllib.request.urlopen")
    def test_ai_context_includes_canvas_ids_and_limits_an_explicit_selection(self, mocked_urlopen):
        class ProviderResponse:
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self):
                return json.dumps({
                    "operations": [],
                    "questions": [],
                    "assumptions": [],
                    "warnings": [],
                    "diagnostics": [],
                }).encode()

        mocked_urlopen.return_value = ProviderResponse()
        project = self.create_project()
        diagram = self.client.post(
            f"/api/modeling/projects/{project['id']}/diagrams/",
            {"name": "Clases", "diagram_type": "class"},
            format="json",
        )
        selected = self.client.post(
            f"/api/modeling/projects/{project['id']}/elements/",
            {"name": "Seleccionada", "metaclass": "Class"},
            format="json",
        )
        other = self.client.post(
            f"/api/modeling/projects/{project['id']}/elements/",
            {"name": "Fuera", "metaclass": "Class"},
            format="json",
        )
        node = self.client.post(
            f"/api/modeling/projects/{project['id']}/diagrams/{diagram.data['id']}/nodes/",
            {"element": selected.data["id"], "x": 10, "y": 20, "width": 180, "height": 90},
            format="json",
        )

        response = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/proposals/",
            {
                "prompt": "Edita la clase seleccionada",
                "diagram_id": diagram.data["id"],
                "selection": [selected.data["id"]],
            },
            format="json",
        )

        self.assertEqual(response.status_code, 201)
        sent_payload = json.loads(mocked_urlopen.call_args.args[0].data.decode())
        context = json.loads(sent_payload["messages"][1]["content"].split("Contexto autorizado del proyecto (JSON):\n", 1)[1])
        self.assertEqual([item["id"] for item in context["elements"]], [selected.data["id"]])
        self.assertNotIn(other.data["id"], json.dumps(context))
        self.assertEqual(context["diagram"]["nodes"][0]["id"], node.data["id"])

    @override_settings(AI_BASE_URL="http://provider.test")
    @patch("modeling.ai.urllib.request.urlopen")
    def test_ai_rejects_unknown_entities_and_large_batches(self, mocked_urlopen):
        class ProviderResponse:
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self): return json.dumps({"operations": [{"entity_type": "ShellCommand", "action": "create"}], "warnings": []}).encode()
        mocked_urlopen.return_value = ProviderResponse()
        project = self.create_project()
        response = self.client.post(f"/api/modeling/projects/{project['id']}/ai/proposals/", {"prompt": "hazlo"}, format="json")
        self.assertEqual(response.status_code, 503)

    @override_settings(AI_BASE_URL="http://provider.test", AI_MAX_OPERATIONS=200)
    @patch("modeling.ai.urllib.request.urlopen")
    def test_ai_rejects_more_than_two_hundred_operations(self, mocked_urlopen):
        class ProviderResponse:
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self): return json.dumps({"operations": [{"entity_type": "Diagram", "action": "create", "value": {"diagram_type": "class", "name": str(index)}} for index in range(201)], "warnings": []}).encode()
        mocked_urlopen.return_value = ProviderResponse()
        project = self.create_project()
        response = self.client.post(f"/api/modeling/projects/{project['id']}/ai/proposals/", {"prompt": "muchos"}, format="json")
        self.assertEqual(response.status_code, 503)

    @override_settings(AI_BASE_URL="http://provider.test", AI_TIMEOUT_SECONDS=1)
    @patch("modeling.ai.urllib.request.urlopen", side_effect=TimeoutError())
    def test_ai_timeout_is_recoverable_without_mutation(self, mocked_urlopen):
        project = self.create_project()
        response = self.client.post(f"/api/modeling/projects/{project['id']}/ai/proposals/", {"prompt": "espera"}, format="json")
        self.assertEqual(response.status_code, 503)
        self.assertEqual(Project.objects.get(pk=project["id"]).revision, 0)

    @override_settings(AI_BASE_URL="http://provider.test")
    @patch("modeling.ai.urllib.request.urlopen")
    def test_ai_invalid_json_is_rejected(self, mocked_urlopen):
        class ProviderResponse:
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self): return b"not-json"
        mocked_urlopen.return_value = ProviderResponse()
        project = self.create_project()
        response = self.client.post(f"/api/modeling/projects/{project['id']}/ai/proposals/", {"prompt": "invalido"}, format="json")
        self.assertEqual(response.status_code, 503)

    @override_settings(AI_BASE_URL="http://provider.test")
    @patch("modeling.ai.urllib.request.urlopen")
    def test_viewer_can_request_ai_explanation_but_cannot_apply_changes(self, mocked_urlopen):
        class ProviderResponse:
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self): return json.dumps({"operations": [], "warnings": ["Revisión sugerida"]}).encode()
        mocked_urlopen.return_value = ProviderResponse()
        project = self.create_project()
        ProjectMembership.objects.create(project_id=project["id"], user=self.other, role="viewer")
        self.client.force_authenticate(self.other)
        proposal = self.client.post(f"/api/modeling/projects/{project['id']}/ai/proposals/", {"prompt": "Explica el modelo"}, format="json")
        self.assertEqual(proposal.status_code, 201)
        applied = self.client.post(f"/api/modeling/projects/{project['id']}/ai/proposals/{proposal.data['id']}/apply/", {}, format="json")
        self.assertEqual(applied.status_code, 403)

    @override_settings(AI_BASE_URL="http://provider.test")
    @patch("modeling.ai.urllib.request.urlopen")
    def test_ai_explanation_returns_authorized_scope_and_validated_suggestions(self, mocked_urlopen):
        class ProviderResponse:
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self): return json.dumps({"explanation": "El diagrama muestra una clase Cliente.", "suggestions": [{"entity_type": "Diagram", "action": "create", "value": {"diagram_type": "class", "name": "Detalle"}}], "warnings": ["Revisar cardinalidad"]}).encode()
        mocked_urlopen.return_value = ProviderResponse()
        project = self.create_project()
        response = self.client.post(f"/api/modeling/projects/{project['id']}/ai/explain/", {"prompt": "Explica este modelo"}, format="json")
        self.assertEqual(response.status_code, 200)
        self.assertIn("Cliente", response.data["explanation"])
        self.assertEqual(response.data["suggestions"][0]["entity_type"], "Diagram")
        self.assertEqual(response.data["context_scope"]["project_id"], project["id"])

    @override_settings(AI_BASE_URL="http://provider.test")
    @patch("modeling.ai.urllib.request.urlopen")
    def test_ai_apply_accepts_only_selected_operation_ids(self, mocked_urlopen):
        class ProviderResponse:
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self): return json.dumps({"operations": [{"entity_type": "UmlElement", "action": "create", "value": {"metaclass": "Class", "name": "Uno"}}, {"entity_type": "UmlElement", "action": "create", "value": {"metaclass": "Class", "name": "Dos"}}], "warnings": []}).encode()
        mocked_urlopen.return_value = ProviderResponse()
        project = self.create_project()
        proposal = self.client.post(f"/api/modeling/projects/{project['id']}/ai/proposals/", {"prompt": "Crea dos clases"}, format="json")
        operation_id = proposal.data["proposal"]["operations"][0]["id"]
        applied = self.client.post(f"/api/modeling/projects/{project['id']}/ai/proposals/{proposal.data['id']}/apply/", {"operation_ids": [operation_id]}, format="json")
        self.assertEqual(applied.status_code, 200)
        self.assertEqual(UmlElement.objects.filter(project=project["id"]).count(), 1)
        self.assertTrue(UmlElement.objects.filter(project=project["id"], name="Uno").exists())

    @override_settings(AI_BASE_URL="http://provider.test", AI_MODEL="uml-test-model")
    @patch("modeling.ai.urllib.request.urlopen")
    def test_ai_can_create_semantic_element_and_its_diagram_node(self, mocked_urlopen):
        element_id = str(uuid.uuid4())
        node_id = str(uuid.uuid4())

        class ProviderResponse:
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self):
                return json.dumps({
                    "operations": [
                        {
                            "id": "create-element",
                            "entity_type": "UmlElement",
                            "entity_id": element_id,
                            "action": "create",
                            "value": {"id": element_id, "metaclass": "Class", "name": "Factura"},
                        },
                        {
                            "id": "create-node",
                            "entity_type": "DiagramNode",
                            "entity_id": node_id,
                            "action": "create",
                            "depends_on": ["create-element"],
                            "value": {
                                "id": node_id,
                                "diagram": diagram_id,
                                "element": element_id,
                                "x": 220,
                                "y": 140,
                                "width": 180,
                                "height": 96,
                                "properties": {},
                            },
                        },
                    ],
                    "assumptions": ["Se usa el diagrama de clases actual."],
                    "warnings": [],
                }).encode()

        project = self.create_project()
        diagram = self.client.post(
            f"/api/modeling/projects/{project['id']}/diagrams/",
            {"name": "Clases", "diagram_type": "class"},
            format="json",
        )
        diagram_id = diagram.data["id"]
        mocked_urlopen.return_value = ProviderResponse()

        proposal = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/proposals/",
            {"prompt": "Añade Factura al diagrama"},
            format="json",
        )
        self.assertEqual(proposal.status_code, 201)
        self.assertEqual(proposal.data["model"], "uml-test-model")
        rejected = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/proposals/{proposal.data['id']}/apply/",
            {"operation_ids": ["create-node"]},
            format="json",
        )
        self.assertEqual(rejected.status_code, 400)
        self.assertFalse(UmlElement.objects.filter(pk=element_id).exists())

        applied = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/proposals/{proposal.data['id']}/apply/",
            {"operation_ids": ["create-element", "create-node"]},
            format="json",
        )
        self.assertEqual(applied.status_code, 200)
        self.assertTrue(UmlElement.objects.filter(pk=element_id, name="Factura").exists())
        self.assertTrue(DiagramNode.objects.filter(pk=node_id, element_id=element_id).exists())
        self.assertEqual([item["origin"] for item in applied.data["operations"]], ["ai", "ai"])

    @override_settings(AI_BASE_URL="http://provider.test")
    @patch("modeling.ai.urllib.request.urlopen")
    def test_ai_questions_block_confirmation_until_a_new_proposal(self, mocked_urlopen):
        class ProviderResponse:
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self):
                return json.dumps({
                    "operations": [],
                    "questions": ["¿Qué multiplicidad debe tener la relación?"],
                    "warnings": [],
                }).encode()

        mocked_urlopen.return_value = ProviderResponse()
        project = self.create_project()
        proposal = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/proposals/",
            {"prompt": "Relaciona las clases"},
            format="json",
        )
        self.assertEqual(proposal.status_code, 201)
        self.assertEqual(len(proposal.data["proposal"]["questions"]), 1)
        applied = self.client.post(
            f"/api/modeling/projects/{project['id']}/ai/proposals/{proposal.data['id']}/apply/",
            {},
            format="json",
        )
        self.assertEqual(applied.status_code, 400)
        self.assertEqual(Project.objects.get(pk=project["id"]).revision, 0)


class ModelingWebsocketTests(TransactionTestCase):
    reset_sequences = True

    def setUp(self):
        self.client = APIClient()
        self.owner = User.objects.create_user(username="ws-owner", email="ws-owner@example.com", password="universidad-123", is_active=True)
        self.client.force_authenticate(self.owner)
        response = self.client.post("/api/modeling/projects/", {"name": "Colaboración"}, format="json")
        self.project_id = response.data["id"]

    def test_websocket_ticket_is_ephemeral_and_scoped_to_membership(self):
        ticket_response = self.client.post(f"/api/modeling/projects/{self.project_id}/sync/ticket/", {}, format="json")
        self.assertEqual(ticket_response.status_code, 200)
        ticket = ticket_response.data["ticket"]

        async def connect_once(value):
            communicator = ApplicationCommunicator(ProjectConsumer.as_asgi(), {
                "type": "websocket",
                "path": f"/ws/projects/{self.project_id}/",
                "query_string": f"ticket={value}".encode(),
                "url_route": {"kwargs": {"project_id": self.project_id}},
            })
            await communicator.send_input({"type": "websocket.connect"})
            output = await communicator.receive_output(timeout=1)
            if output["type"] == "websocket.accept":
                await communicator.send_input({"type": "websocket.disconnect", "code": 1000})
            return output

        self.assertEqual(async_to_sync(connect_once)(ticket)["type"], "websocket.accept")
        self.assertEqual(async_to_sync(connect_once)(ticket), {"type": "websocket.close", "code": 4401})
        cache.clear()

    def test_redis_channel_layer_keeps_idle_websocket_open_beyond_poll_interval(self):
        if "RedisChannelLayer" not in settings.CHANNEL_LAYERS["default"]["BACKEND"]:
            self.skipTest("La prueba de regresión requiere el channel layer Redis.")

        redis_host = settings.CHANNEL_LAYERS["default"]["CONFIG"]["hosts"][0]
        self.assertIsNone(redis_host["socket_timeout"])

        ticket_response = self.client.post(
            f"/api/modeling/projects/{self.project_id}/sync/ticket/", {}, format="json"
        )
        ticket = ticket_response.data["ticket"]

        async def keep_connection_open():
            communicator = ApplicationCommunicator(
                ProjectConsumer.as_asgi(),
                {
                    "type": "websocket",
                    "path": f"/ws/projects/{self.project_id}/",
                    "query_string": f"ticket={ticket}".encode(),
                    "url_route": {"kwargs": {"project_id": self.project_id}},
                },
            )
            await communicator.send_input({"type": "websocket.connect"})
            self.assertEqual(
                (await communicator.receive_output(timeout=1))["type"],
                "websocket.accept",
            )

            # channels_redis waits five seconds when no messages arrive. The
            # connection must outlive that poll and still process a heartbeat.
            await asyncio.sleep(6)
            self.assertFalse(communicator.future.done())
            await communicator.send_input(
                {
                    "type": "websocket.receive",
                    "text": json.dumps(
                        {"event": "presence.heartbeat", "payload": {}}
                    ),
                }
            )
            await asyncio.sleep(0.2)
            self.assertFalse(communicator.future.done())
            await communicator.send_input({"type": "websocket.disconnect", "code": 1000})
            await communicator.wait(timeout=1)

        async_to_sync(keep_connection_open)()
        cache.clear()
