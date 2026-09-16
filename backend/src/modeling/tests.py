import asyncio
import uuid
import json
from datetime import timedelta
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

from .consumers import ProjectConsumer
from .models import Diagram, DiagramNode, InviteCode, ModelOperation, Project, ProjectMembership, ProjectSnapshot, UmlElement
from .serializers import DiagramEdgeSerializer, DiagramNodeSerializer
from .interchange import exchange_mapping, parse_exchange, write_exchange
from .interchange_compare import compare_exchange_payloads, semantic_projection
from .registry import DIAGRAM_DEFINITIONS, DIAGRAM_TYPES


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

    def test_ai_is_disabled_without_provider_and_does_not_mutate(self):
        project = self.create_project()
        response = self.client.post(f"/api/modeling/projects/{project['id']}/ai/proposals/", {"prompt": "crea una clase"}, format="json")
        self.assertEqual(response.status_code, 503)
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
