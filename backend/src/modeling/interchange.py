import io
import json
import uuid
import xml.etree.ElementTree as ET

from defusedxml import ElementTree as SafeET
from django.conf import settings

from .models import Diagram, UmlElement, UmlPackage, UmlRelationship
from .registry import ELEMENT_TYPES, RELATIONSHIP_TYPES

OMG_NS = "http://www.omg.org/spec/XMI/20131001"
UML_NS = "http://www.omg.org/spec/UML/20131001"
SPARX_NS = "http://www.sparxsystems.com/profiles/EA"
XMI21_NS = "http://schema.omg.org/spec/XMI/2.1"
UMLDI_NS = "http://www.omg.org/spec/UML/20131001/UMLDI"
DC_NS = "http://www.omg.org/spec/DD/20131001/DC"
MAX_XML_BYTES = int(getattr(settings, "XMI_MAX_BYTES", 10 * 1024 * 1024))
EXCHANGE_ELEMENT_METACLASSES = tuple(item for item in ELEMENT_TYPES if item != "Extension")
EXCHANGE_RELATIONSHIP_TYPES = tuple(RELATIONSHIP_TYPES)


def exchange_mapping():
    return {"elements": list(EXCHANGE_ELEMENT_METACLASSES), "relationships": list(EXCHANGE_RELATIONSHIP_TYPES), "properties": "ea:properties JSON attribute"}


def _local(tag):
    return tag.rsplit("}", 1)[-1]


def parse_exchange(raw):
    if isinstance(raw, str):
        raw = raw.encode("utf-8")
    if len(raw) > MAX_XML_BYTES:
        raise ValueError("El archivo XMI supera el límite de 10 MB.")
    try:
        root = SafeET.fromstring(raw)
    except Exception as exc:
        raise ValueError("El XML/XMI no es válido o contiene entidades no permitidas.") from exc
    elements = []
    relationships = []
    diagrams = []
    has_presentation = False
    views = []
    parent_map = {child: parent for parent in root.iter() for child in parent}
    packages = []
    known_ids = set()
    unknown = []
    opaque_extensions = []
    for node in root.iter():
        kind = _local(node.tag)
        xmi_id = node.attrib.get(f"{{{OMG_NS}}}id") or node.attrib.get(f"{{{XMI21_NS}}}id") or node.attrib.get("xmi.id") or str(uuid.uuid4())
        name = node.attrib.get("name", kind)
        if kind in {"Package", "Model"}:
            packages.append({"id": xmi_id, "name": name, "mda_level": "UNSPECIFIED", "properties": {}})
            known_ids.add(xmi_id)
        elif kind in EXCHANGE_ELEMENT_METACLASSES:
            raw_properties = node.attrib.get(f"{{{SPARX_NS}}}properties", "{}")
            try:
                properties = json.loads(raw_properties)
            except (TypeError, ValueError):
                properties = {}
                unknown.append(f"properties:{kind}")
            elements.append({"id": xmi_id, "metaclass": kind, "name": name, "properties": properties, "external_ids": {"xmi": xmi_id}})
            known_ids.add(xmi_id)
        elif kind in EXCHANGE_RELATIONSHIP_TYPES:
            raw_properties = node.attrib.get(f"{{{SPARX_NS}}}properties", "{}")
            try:
                properties = json.loads(raw_properties)
            except (TypeError, ValueError):
                properties = {}
                unknown.append(f"properties:{kind}")
            relationships.append({"id": xmi_id, "relationship_type": kind, "source_id": node.attrib.get("source", ""), "target_id": node.attrib.get("target", ""), "properties": properties, "external_ids": {"xmi": xmi_id}})
        elif kind.endswith("Diagram") or kind == "Diagram":
            diagrams.append({"id": xmi_id, "name": name, "diagram_type": "class", "properties": {"source": "xmi"}})
        elif kind in {"Shape", "Edge"}:
            has_presentation = True
            parent = parent_map.get(node)
            if parent is not None:
                parent_id = parent.attrib.get(f"{{{OMG_NS}}}id") or parent.attrib.get(f"{{{XMI21_NS}}}id") or parent.attrib.get("xmi.id")
                if kind == "Shape":
                    bounds = next((child for child in node if _local(child.tag) == "Bounds"), None)
                    views.append({"kind": "node", "id": xmi_id, "diagram_id": parent_id, "element_id": node.attrib.get("modelElement"), "x": float(bounds.attrib.get("x", 0)) if bounds is not None else 0, "y": float(bounds.attrib.get("y", 0)) if bounds is not None else 0, "width": float(bounds.attrib.get("width", 180)) if bounds is not None else 180, "height": float(bounds.attrib.get("height", 80)) if bounds is not None else 80})
                else:
                    views.append({"kind": "edge", "id": xmi_id, "diagram_id": parent_id, "source_node_id": node.attrib.get("source"), "target_node_id": node.attrib.get("target")})
        elif kind not in {"XMI", "ownedComment", "ownedAttribute", "ownedOperation", "LiteralString", "bounds", "Shape", "Edge"} and not node.tag.startswith(f"{{{UML_NS}}}"):
            unknown.append(kind)
            opaque_extensions.append({"tag": kind, "xml": ET.tostring(node, encoding="unicode")})
    warnings = [{"code": "unknown_element", "message": f"Elemento XML no interpretado: {kind}"} for kind in sorted(set(unknown))]
    for relationship in relationships:
        if relationship["source_id"] and relationship["source_id"] not in known_ids:
            warnings.append({"code": "broken_reference", "message": f"Origen no encontrado: {relationship['source_id']}"})
        if relationship["target_id"] and relationship["target_id"] not in known_ids:
            warnings.append({"code": "broken_reference", "message": f"Destino no encontrado: {relationship['target_id']}"})
    if diagrams and not has_presentation:
        warnings.append({"code": "missing_presentation", "message": "No se encontró UMLDI; se generará una disposición automática."})
    return {"packages": packages, "elements": elements, "relationships": relationships, "diagrams": diagrams, "views": views, "opaque_extensions": opaque_extensions, "has_presentation": has_presentation, "warnings": warnings, "errors": []}


def write_exchange(project, profile="omg-xmi-2.5.1"):
    sparx = profile == "sparx-ea-xmi-2.1"
    xmi_ns = XMI21_NS if sparx else OMG_NS
    ET.register_namespace("xmi", xmi_ns)
    ET.register_namespace("uml", UML_NS)
    ET.register_namespace("ea", SPARX_NS)
    ET.register_namespace("di", UMLDI_NS)
    ET.register_namespace("dc", DC_NS)
    root = ET.Element(f"{{{xmi_ns}}}XMI", {f"{{{xmi_ns}}}version": "2.1" if sparx else "2.5.1"})
    model = ET.SubElement(root, f"{{{UML_NS}}}Model", {f"{{{xmi_ns}}}id": str(project.id), "name": project.name})
    for package in project.packages.all():
        ET.SubElement(model, f"{{{UML_NS}}}Package", {f"{{{xmi_ns}}}id": str(package.id), "name": package.name})
    for element in project.elements.all():
        metaclass = element.metaclass if element.metaclass in EXCHANGE_ELEMENT_METACLASSES else "Class"
        attributes = {f"{{{xmi_ns}}}id": str(element.id), "name": element.name}
        if element.properties:
            attributes[f"{{{SPARX_NS}}}properties"] = json.dumps(element.properties, separators=(",", ":"), sort_keys=True)
        ET.SubElement(model, f"{{{UML_NS}}}{metaclass}", attributes)
    for relationship in project.relationships.all():
        relationship_type = relationship.relationship_type if relationship.relationship_type in EXCHANGE_RELATIONSHIP_TYPES else "Dependency"
        attributes = {f"{{{xmi_ns}}}id": str(relationship.id), "name": relationship.properties.get("name", "")}
        if relationship.properties:
            attributes[f"{{{SPARX_NS}}}properties"] = json.dumps(relationship.properties, separators=(",", ":"), sort_keys=True)
        node = ET.SubElement(model, f"{{{UML_NS}}}{relationship_type}", attributes)
        node.set("source", str(relationship.source_id))
        node.set("target", str(relationship.target_id))
    for diagram in project.diagrams.all():
        diagram_node = ET.SubElement(root, f"{{{UMLDI_NS}}}Diagram", {f"{{{xmi_ns}}}id": str(diagram.id), "name": diagram.name, "modelElement": str(project.id)})
        for view in diagram.nodes.all():
            if view.properties.get("kind") == "visual":
                continue
            shape = ET.SubElement(diagram_node, f"{{{UMLDI_NS}}}Shape", {f"{{{xmi_ns}}}id": str(view.id), "modelElement": str(view.element_id or "")})
            ET.SubElement(shape, f"{{{DC_NS}}}Bounds", {"x": str(view.x), "y": str(view.y), "width": str(view.width), "height": str(view.height)})
        for edge in diagram.edges.all():
            if edge.properties.get("kind") == "visual":
                continue
            ET.SubElement(diagram_node, f"{{{UMLDI_NS}}}Edge", {f"{{{xmi_ns}}}id": str(edge.id), "source": str(edge.source_node_id), "target": str(edge.target_node_id)})
        for extension in diagram.properties.get("opaque_extensions", []):
            ET.SubElement(diagram_node, f"{{{SPARX_NS}}}OpaqueExtension", {"payload": json.dumps(extension, separators=(",", ":"), sort_keys=True)})
    return ET.tostring(root, encoding="utf-8", xml_declaration=True)
