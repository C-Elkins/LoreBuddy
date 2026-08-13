#!/usr/bin/env python3
"""Validate LoreBuddy's small JSON fixture datasets without network access."""

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VOCABULARY_PATH = ROOT / "database" / "relationship-vocabulary.json"


def fail(message):
    raise ValueError(message)


def require_string(value, field, context):
    if not isinstance(value, str) or not value:
        fail(f"{context}: {field} must be a non-empty string")


def require_list(value, field, context, minimum=0):
    if not isinstance(value, list) or len(value) < minimum:
        fail(f"{context}: {field} must be a list with at least {minimum} item(s)")
    if all(isinstance(item, (str, int, float, bool, type(None))) for item in value) and len(value) != len(set(value)):
        fail(f"{context}: {field} must not contain duplicates")


def validate_dataset(path, vocabulary):
    with path.open() as handle:
        dataset = json.load(handle)

    for field in ("entities", "sources", "discoveryGates", "statements", "relationships"):
        require_list(dataset.get(field), field, str(path))

    entity_ids = set()
    for entity in dataset["entities"]:
        context = f"entity {entity.get('id', '<missing>')}"
        require_string(entity.get("id"), "id", context)
        require_string(entity.get("name"), "name", context)
        require_string(entity.get("type"), "type", context)
        if entity["id"] in entity_ids:
            fail(f"{context}: duplicate id")
        entity_ids.add(entity["id"])

    source_ids = set()
    for source in dataset["sources"]:
        context = f"source {source.get('id', '<missing>')}"
        for field in ("id", "publisher", "title", "kind", "classification", "reference", "attribution", "license", "verificationStatus"):
            require_string(source.get(field), field, context)
        if source["classification"] not in {"primary", "secondary", "community", "speculation"}:
            fail(f"{context}: classification must be primary, secondary, community, or speculation")
        if source["id"] in source_ids:
            fail(f"{context}: duplicate id")
        source_ids.add(source["id"])

    gate_ids = set()
    for gate in dataset["discoveryGates"]:
        context = f"discovery gate {gate.get('id', '<missing>')}"
        for field in ("id", "label", "signalType", "minimumDetailLevel"):
            require_string(gate.get(field), field, context)
        if gate["id"] in gate_ids:
            fail(f"{context}: duplicate id")
        gate_ids.add(gate["id"])

    statement_ids = set()
    for statement in dataset["statements"]:
        context = f"statement {statement.get('id', '<missing>')}"
        for field in ("id", "entityId", "detailLevel", "text", "canonStatus", "epistemicStatus"):
            require_string(statement.get(field), field, context)
        require_list(statement.get("sourceIds"), "sourceIds", context, minimum=1)
        if statement["entityId"] not in entity_ids:
            fail(f"{context}: unknown entityId {statement['entityId']}")
        if any(source_id not in source_ids for source_id in statement["sourceIds"]):
            fail(f"{context}: unknown sourceId")
        if any(gate_id not in gate_ids for gate_id in statement.get("discoveryGateIds", [])):
            fail(f"{context}: unknown discoveryGateId")
        if statement["id"] in statement_ids:
            fail(f"{context}: duplicate id")
        statement_ids.add(statement["id"])

    relationship_ids = set()
    for relationship in dataset["relationships"]:
        context = f"relationship {relationship.get('id', '<missing>')}"
        for field in ("id", "subjectId", "predicate", "objectId"):
            require_string(relationship.get(field), field, context)
        require_list(relationship.get("sourceIds"), "sourceIds", context, minimum=1)
        if relationship["subjectId"] not in entity_ids or relationship["objectId"] not in entity_ids:
            fail(f"{context}: subjectId and objectId must reference known entities")
        if relationship["predicate"] not in vocabulary:
            fail(f"{context}: unknown predicate {relationship['predicate']}")
        if any(source_id not in source_ids for source_id in relationship["sourceIds"]):
            fail(f"{context}: unknown sourceId")
        if any(gate_id not in gate_ids for gate_id in relationship.get("discoveryGateIds", [])):
            fail(f"{context}: unknown discoveryGateId")
        if relationship["id"] in relationship_ids:
            fail(f"{context}: duplicate id")
        relationship_ids.add(relationship["id"])


def main():
    with VOCABULARY_PATH.open() as handle:
        vocabulary = json.load(handle)["relationships"]
    paths = [Path(argument) for argument in sys.argv[1:]]
    if not paths:
        paths = sorted((ROOT / "database" / "entries").glob("*-dataset.json"))
    try:
        for path in paths:
            validate_dataset(path, vocabulary)
            print(f"valid: {path}")
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print(f"invalid: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())