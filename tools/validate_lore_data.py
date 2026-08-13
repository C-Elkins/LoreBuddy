#!/usr/bin/env python3
"""Validate LoreBuddy datasets and print a human-readable database report."""

import argparse
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VOCABULARY_PATH = ROOT / "database" / "relationship-vocabulary.json"
ENTITY_TYPES = {
    "character", "location", "faction", "event", "item", "quest", "creature",
    "organization", "concept", "book", "dialogue", "dungeon", "raid", "zone",
}
SOURCE_KINDS = {
    "blizzard_api", "quest_text", "npc_dialogue", "book", "external_reference",
    "community_contribution",
}
SOURCE_CLASSIFICATIONS = {"primary", "secondary", "community", "speculation"}
VERIFICATION_STATUSES = {"unverified", "reviewed", "verified"}
DETAIL_LEVELS = {"quick", "story", "deep"}
CANON_STATUSES = {"confirmed", "disputed", "non_canon", "unknown"}
EPISTEMIC_STATUSES = {"fact", "interpretation", "theory", "speculation"}
SIGNAL_TYPES = {"quest", "event", "zone", "achievement", "encounter", "manual_confirmation"}


def load_json(path):
    with path.open() as handle:
        return json.load(handle)


def add_error(report, message):
    report["errors"].append(message)


def add_warning(report, message):
    report["warnings"].append(message)


def require_string(value, field, context, report):
    if not isinstance(value, str) or not value.strip():
        add_error(report, f"{context}: missing required field '{field}'")
        return False
    return True


def require_list(value, field, context, report, minimum=0):
    if not isinstance(value, list) or len(value) < minimum:
        add_error(report, f"{context}: field '{field}' must contain at least {minimum} item(s)")
        return False
    return True


def check_unique_ids(records, label, report, global_ids):
    ids = set()
    for record in records:
        record_id = record.get("id") if isinstance(record, dict) else None
        context = f"{label} {record_id or '<missing>'}"
        if record_id in ids:
            add_error(report, f"{context}: duplicate ID")
        if record_id in global_ids:
            add_error(report, f"{context}: ID is duplicated across data types")
        if record_id:
            ids.add(record_id)
            global_ids.add(record_id)


def validate_dataset(path, vocabulary):
    report = {
        "path": str(path),
        "counts": {"entities": 0, "relationships": 0, "sources": 0},
        "errors": [],
        "warnings": [],
    }
    try:
        dataset = load_json(path)
    except (OSError, json.JSONDecodeError) as error:
        add_error(report, f"cannot read dataset: {error}")
        return report

    collections = {}
    for field in ("entities", "sources", "discoveryGates", "statements", "relationships"):
        value = dataset.get(field)
        if require_list(value, field, str(path), report):
            collections[field] = value
        else:
            collections[field] = []

    report["counts"] = {
        "entities": len(collections["entities"]),
        "relationships": len(collections["relationships"]),
        "sources": len(collections["sources"]),
    }
    global_ids = set()
    labels = {
        "entities": "entity",
        "sources": "source",
        "discoveryGates": "discovery gate",
        "statements": "statement",
        "relationships": "relationship",
    }
    for field, label in labels.items():
        check_unique_ids(collections[field], label, report, global_ids)

    entity_ids = {record.get("id") for record in collections["entities"] if isinstance(record, dict) and record.get("id")}
    source_ids = {record.get("id") for record in collections["sources"] if isinstance(record, dict) and record.get("id")}
    gate_ids = {record.get("id") for record in collections["discoveryGates"] if isinstance(record, dict) and record.get("id")}
    referenced_entity_ids = set()

    for entity in collections["entities"]:
        context = f"entity {entity.get('id', '<missing>')}"
        for field in ("id", "name", "type"):
            require_string(entity.get(field), field, context, report)
        if entity.get("type") not in ENTITY_TYPES:
            add_error(report, f"{context}: invalid entity type '{entity.get('type')}'")

    for source in collections["sources"]:
        context = f"source {source.get('id', '<missing>')}"
        for field in ("id", "publisher", "title", "kind", "classification", "reference", "attribution", "license", "verificationStatus"):
            require_string(source.get(field), field, context, report)
        if source.get("kind") not in SOURCE_KINDS:
            add_error(report, f"{context}: invalid source type '{source.get('kind')}'")
        if source.get("classification") not in SOURCE_CLASSIFICATIONS:
            add_error(report, f"{context}: invalid source classification '{source.get('classification')}'")
        if source.get("verificationStatus") not in VERIFICATION_STATUSES:
            add_error(report, f"{context}: invalid verification status '{source.get('verificationStatus')}'")

    for gate in collections["discoveryGates"]:
        context = f"discovery gate {gate.get('id', '<missing>')}"
        for field in ("id", "label", "signalType", "minimumDetailLevel"):
            require_string(gate.get(field), field, context, report)
        if gate.get("signalType") not in SIGNAL_TYPES:
            add_error(report, f"{context}: invalid signal type '{gate.get('signalType')}'")
        if gate.get("minimumDetailLevel") not in DETAIL_LEVELS:
            add_error(report, f"{context}: invalid minimum detail level '{gate.get('minimumDetailLevel')}'")

    for statement in collections["statements"]:
        context = f"statement {statement.get('id', '<missing>')}"
        for field in ("id", "entityId", "detailLevel", "text", "canonStatus", "epistemicStatus"):
            require_string(statement.get(field), field, context, report)
        require_list(statement.get("sourceIds"), "sourceIds", context, report, minimum=1)
        entity_id = statement.get("entityId")
        if entity_id not in entity_ids:
            add_error(report, f"{context}: broken entity reference '{entity_id}'")
        else:
            referenced_entity_ids.add(entity_id)
        if statement.get("detailLevel") not in DETAIL_LEVELS:
            add_error(report, f"{context}: invalid detail level '{statement.get('detailLevel')}'")
        if statement.get("canonStatus") not in CANON_STATUSES:
            add_error(report, f"{context}: invalid canon status '{statement.get('canonStatus')}'")
        if statement.get("epistemicStatus") not in EPISTEMIC_STATUSES:
            add_error(report, f"{context}: invalid epistemic status '{statement.get('epistemicStatus')}'")
        for source_id in statement.get("sourceIds") or []:
            if source_id not in source_ids:
                add_error(report, f"{context}: missing source reference '{source_id}'")
        for gate_id in statement.get("discoveryGateIds") or []:
            if gate_id not in gate_ids:
                add_error(report, f"{context}: broken discovery gate reference '{gate_id}'")

    for relationship in collections["relationships"]:
        context = f"relationship {relationship.get('id', '<missing>')}"
        for field in ("id", "subjectId", "predicate", "objectId"):
            require_string(relationship.get(field), field, context, report)
        require_list(relationship.get("sourceIds"), "sourceIds", context, report, minimum=1)
        subject_id = relationship.get("subjectId")
        object_id = relationship.get("objectId")
        if subject_id not in entity_ids or object_id not in entity_ids:
            add_error(report, f"{context}: broken entity reference")
        referenced_entity_ids.update({subject_id, object_id} & entity_ids)
        if relationship.get("predicate") not in vocabulary:
            add_error(report, f"{context}: invalid relationship '{relationship.get('predicate')}'")
        for source_id in relationship.get("sourceIds") or []:
            if source_id not in source_ids:
                add_error(report, f"{context}: missing source reference '{source_id}'")
        for gate_id in relationship.get("discoveryGateIds") or []:
            if gate_id not in gate_ids:
                add_error(report, f"{context}: broken discovery gate reference '{gate_id}'")

    for entity in collections["entities"]:
        entity_id = entity.get("id")
        if entity_id and entity_id not in referenced_entity_ids:
            add_warning(report, f"orphaned entity '{entity_id}' is not referenced by a statement or relationship")

    secondary_source_ids = {
        source.get("id") for source in collections["sources"] if source.get("classification") == "secondary"
    }
    statements_with_secondary = {
        statement.get("entityId") for statement in collections["statements"]
        if secondary_source_ids.intersection(statement.get("sourceIds") or [])
    }
    for entity in collections["entities"]:
        entity_id = entity.get("id")
        if entity_id and entity_id in referenced_entity_ids and entity_id not in statements_with_secondary:
            add_warning(report, f"entry '{entity_id}' has no secondary source")

    return report


def print_report(reports):
    totals = {key: sum(report["counts"][key] for report in reports) for key in ("entities", "relationships", "sources")}
    errors = [message for report in reports for message in report["errors"]]
    warnings = [message for report in reports for message in report["warnings"]]
    print("LORE BUDDY DATABASE VALIDATION")
    print()
    print(f"Entities:       {totals['entities']}")
    print(f"Relationships:   {totals['relationships']}")
    print(f"Sources:         {totals['sources']}")
    print()
    if errors:
        for message in errors:
            print(f"✗ {message}")
    else:
        print("✓ No duplicate IDs")
        print("✓ No broken references")
        print("✓ No missing required fields")
        print("✓ No invalid relationships or source types")
    for message in warnings:
        print(f"⚠ {message}")
    print()
    print("DATABASE INVALID" if errors else "DATABASE VALID")
    return 1 if errors else 0


def main(argv=None):
    parser = argparse.ArgumentParser(description="Validate LoreBuddy JSON datasets")
    parser.add_argument("paths", nargs="*", type=Path, help="dataset files; defaults to database/entries/*-dataset.json")
    args = parser.parse_args(argv)
    try:
        vocabulary = load_json(VOCABULARY_PATH)["relationships"]
        paths = args.paths or sorted((ROOT / "database" / "entries").glob("*-dataset.json"))
        reports = [validate_dataset(path, vocabulary) for path in paths]
    except (OSError, json.JSONDecodeError, KeyError) as error:
        print(f"invalid: {error}", file=sys.stderr)
        return 1
    return print_report(reports)


if __name__ == "__main__":
    raise SystemExit(main())
