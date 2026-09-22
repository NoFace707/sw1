import json
from pathlib import Path

from django.test import SimpleTestCase
from jsonschema import Draft202012Validator

from .expert_rules import (
    evaluate_expert_rules,
    expert_rules_payload,
    repair_deterministically,
)


SHARED = Path("/shared")
if not SHARED.exists():
    SHARED = Path(__file__).resolve().parents[3] / "shared"


class ExpertRulesTests(SimpleTestCase):
    def test_catalog_matches_json_schema_and_covers_required_categories(self):
        schema = json.loads((SHARED / "contracts/expert-rules.schema.json").read_text(encoding="utf-8"))
        payload = expert_rules_payload()
        Draft202012Validator(schema).validate(payload)
        self.assertEqual(
            {rule["category"] for rule in payload["rules"]},
            {"identity", "uml_types", "uml_relations", "mda_traceability", "permissions", "limits", "spring_mapping"},
        )

    def test_shared_fixtures_are_deterministic(self):
        cases = json.loads((SHARED / "fixtures/expert-rules-cases.json").read_text(encoding="utf-8"))
        for case in cases:
            first = evaluate_expert_rules(case["context"])
            second = evaluate_expert_rules(case["context"])
            self.assertEqual(first, second, case["name"])
            identifiers = {item["rule_id"] for item in first}
            self.assertTrue(set(case.get("must_contain", [])).issubset(identifiers), case["name"])
            self.assertTrue(set(case.get("must_not_contain", [])).isdisjoint(identifiers), case["name"])

    def test_repair_is_bounded_explained_and_revalidated(self):
        context = {
            "project": {"mda_level": "PIM"},
            "permission": "editor",
            "elements": [{"id": "e1", "metaclass": "Class", "name": "  Pedido   especial  ", "properties": {"attributes": ["id: UUID"]}}],
            "relationships": [],
        }
        diagnostics = [{
            "rule_id": "element.name.required",
            "evidence": {"entity_id": "e1"},
            "repair": {"kind": "normalize_name"},
        }]
        repaired, applied, validated = repair_deterministically(context, diagnostics)
        self.assertEqual(repaired["elements"][0]["name"], "Pedido especial")
        self.assertEqual(applied[0]["rule_id"], "element.name.required")
        self.assertFalse(any(item["severity"] == "error" for item in validated))
