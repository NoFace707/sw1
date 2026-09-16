"""Compare semantic exchange payloads while ignoring presentation-only churn."""

import argparse
import json
from pathlib import Path

from .interchange import parse_exchange


def _canonical(value):
    return json.dumps(value or {}, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def _element_key(item):
    external_id = (item.get("external_ids") or {}).get("xmi") or item.get("id")
    return external_id, item.get("metaclass"), item.get("name"), _canonical(item.get("properties"))


def _relationship_key(item):
    return (
        (item.get("external_ids") or {}).get("xmi") or item.get("id"),
        item.get("relationship_type"),
        item.get("source_id"),
        item.get("target_id"),
        _canonical(item.get("properties")),
    )


def semantic_projection(payload):
    """Return the comparable semantic subset of a parsed exchange document."""
    return {
        "packages": sorted((item.get("id"), item.get("name"), _canonical(item.get("properties"))) for item in payload.get("packages", [])),
        "elements": sorted(_element_key(item) for item in payload.get("elements", [])),
        "relationships": sorted(_relationship_key(item) for item in payload.get("relationships", [])),
        "diagrams": sorted((item.get("id"), item.get("name"), item.get("diagram_type")) for item in payload.get("diagrams", [])),
    }


def compare_exchange_payloads(left, right):
    left_projection = semantic_projection(left)
    right_projection = semantic_projection(right)
    differences = []
    for section in left_projection:
        if left_projection[section] != right_projection[section]:
            differences.append({"section": section, "left": left_projection[section], "right": right_projection[section]})
    return {"equivalent": not differences, "differences": differences}


def compare_exchange_files(left_path, right_path):
    return compare_exchange_payloads(parse_exchange(Path(left_path).read_bytes()), parse_exchange(Path(right_path).read_bytes()))


def main():
    parser = argparse.ArgumentParser(description="Compara la semántica de dos archivos XMI/XML.")
    parser.add_argument("left")
    parser.add_argument("right")
    args = parser.parse_args()
    print(json.dumps(compare_exchange_files(args.left, args.right), indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
