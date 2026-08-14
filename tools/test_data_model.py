#!/usr/bin/env python3
"""Validation tests for the LoreBuddy data model itself.

Unlike validate_lore_data.py (which validates the real authored datasets),
this exercises validate_dataset()/find_cross_file_duplicates() against small
in-memory fixtures to prove the architecture: new entity types, eras,
priorities, spoiler levels, chronology, source confidence, cross-file
relationships, and cross-file duplicate detection all behave as designed.
"""

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import validate_lore_data as vld


def write_dataset(directory, filename, dataset):
    path = Path(directory) / filename
    path.write_text(json.dumps(dataset), encoding="utf-8")
    return path


def base_source(source_id="src_test", classification="community"):
    return {
        "id": source_id,
        "publisher": "Test",
        "title": "Test source",
        "kind": "community_contribution",
        "classification": classification,
        "reference": "test",
        "attribution": "Test",
        "license": "MIT",
        "verificationStatus": "unverified",
    }


def base_statement(statement_id, entity_id, source_ids, **overrides):
    statement = {
        "id": statement_id,
        "entityId": entity_id,
        "detailLevel": "quick",
        "text": "Test text.",
        "canonStatus": "confirmed",
        "epistemicStatus": "fact",
        "sourceIds": source_ids,
    }
    statement.update(overrides)
    return statement


class ValidateDatasetTests(unittest.TestCase):
    def setUp(self):
        self.vocabulary = vld.load_json(vld.VOCABULARY_PATH)["relationships"]
        self.era_ids = vld.load_era_ids()
        self.tempdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tempdir.cleanup)

    def validate(self, dataset, **kwargs):
        path = write_dataset(self.tempdir.name, "fixture-dataset.json", dataset)
        return vld.validate_dataset(path, self.vocabulary, era_ids=self.era_ids, **kwargs)

    def test_valid_entity_passes(self):
        dataset = {
            "entities": [{"id": "test_entity", "name": "Test Entity", "type": "character"}],
            "sources": [], "discoveryGates": [], "statements": [], "relationships": [],
        }
        report = self.validate(dataset)
        self.assertEqual(report["errors"], [])

    def test_invalid_entity_type_fails(self):
        dataset = {
            "entities": [{"id": "test_entity", "name": "Test Entity", "type": "not_a_real_type"}],
            "sources": [], "discoveryGates": [], "statements": [], "relationships": [],
        }
        report = self.validate(dataset)
        self.assertTrue(any("invalid entity type" in e for e in report["errors"]))

    def test_known_era_id_passes(self):
        dataset = {
            "entities": [{"id": "test_entity", "name": "Test", "type": "character", "eraId": "era_classic"}],
            "sources": [], "discoveryGates": [], "statements": [], "relationships": [],
        }
        report = self.validate(dataset)
        self.assertEqual(report["errors"], [])

    def test_unknown_era_id_fails(self):
        dataset = {
            "entities": [{"id": "test_entity", "name": "Test", "type": "character", "eraId": "era_made_up"}],
            "sources": [], "discoveryGates": [], "statements": [], "relationships": [],
        }
        report = self.validate(dataset)
        self.assertTrue(any("unknown eraId" in e for e in report["errors"]))

    def test_invalid_lore_relevance_fails(self):
        dataset = {
            "entities": [{"id": "test_entity", "name": "Test", "type": "character", "loreRelevance": "legendary"}],
            "sources": [], "discoveryGates": [], "statements": [], "relationships": [],
        }
        report = self.validate(dataset)
        self.assertTrue(any("invalid loreRelevance" in e for e in report["errors"]))

    def test_invalid_priority_fails(self):
        dataset = {
            "entities": [{"id": "test_entity", "name": "Test", "type": "character", "priority": "p9"}],
            "sources": [], "discoveryGates": [], "statements": [], "relationships": [],
        }
        report = self.validate(dataset)
        self.assertTrue(any("invalid priority" in e for e in report["errors"]))

    def test_invalid_source_confidence_fails(self):
        source = base_source()
        source["confidence"] = "extremely_sure"
        dataset = {
            "entities": [{"id": "test_entity", "name": "Test", "type": "character"}],
            "sources": [source],
            "discoveryGates": [], "statements": [], "relationships": [],
        }
        report = self.validate(dataset)
        self.assertTrue(any("invalid source confidence" in e for e in report["errors"]))

    def test_invalid_spoiler_level_fails(self):
        source = base_source()
        statement = base_statement("test_stmt", "test_entity", [source["id"]], spoilerLevel="spoils_everything")
        dataset = {
            "entities": [{"id": "test_entity", "name": "Test", "type": "character"}],
            "sources": [source], "discoveryGates": [],
            "statements": [statement], "relationships": [],
        }
        report = self.validate(dataset)
        self.assertTrue(any("invalid spoilerLevel" in e for e in report["errors"]))

    def test_new_detail_levels_accepted(self):
        source = base_source()
        statements = [
            base_statement("s_micro", "test_entity", [source["id"]], detailLevel="micro"),
            base_statement("s_reference", "test_entity", [source["id"]], detailLevel="reference"),
        ]
        dataset = {
            "entities": [{"id": "test_entity", "name": "Test", "type": "character"}],
            "sources": [source], "discoveryGates": [], "statements": statements, "relationships": [],
        }
        report = self.validate(dataset)
        self.assertEqual(report["errors"], [])

    def test_expanded_relationship_predicates_accepted(self):
        source = base_source()
        dataset = {
            "entities": [
                {"id": "test_subject", "name": "Subject", "type": "character"},
                {"id": "test_object", "name": "Object", "type": "character"},
            ],
            "sources": [source], "discoveryGates": [], "statements": [],
            "relationships": [
                {
                    "id": "test_rel", "subjectId": "test_subject", "predicate": "sibling_of",
                    "objectId": "test_object", "sourceIds": [source["id"]],
                }
            ],
        }
        report = self.validate(dataset)
        self.assertEqual(report["errors"], [])

    def test_cross_file_relationship_resolves(self):
        # File A defines the entity; file B relates to it. Neither file alone
        # contains both ends, proving the merged/external-id resolution works.
        source = base_source()
        dataset_a = {
            "entities": [{"id": "shared_entity", "name": "Shared", "type": "zone"}],
            "sources": [], "discoveryGates": [], "statements": [], "relationships": [],
        }
        dataset_b = {
            "entities": [{"id": "local_entity", "name": "Local", "type": "character"}],
            "sources": [source], "discoveryGates": [], "statements": [],
            "relationships": [
                {
                    "id": "cross_file_rel", "subjectId": "local_entity", "predicate": "located_at",
                    "objectId": "shared_entity", "sourceIds": [source["id"]],
                }
            ],
        }
        path_a = write_dataset(self.tempdir.name, "a-dataset.json", dataset_a)
        path_b = write_dataset(self.tempdir.name, "b-dataset.json", dataset_b)

        external_entities = {"shared_entity"}
        report_a = vld.validate_dataset(path_a, self.vocabulary, era_ids=self.era_ids)
        report_b = vld.validate_dataset(
            path_b, self.vocabulary, external_entity_ids=external_entities, era_ids=self.era_ids
        )
        self.assertEqual(report_a["errors"], [])
        self.assertEqual(report_b["errors"], [])

    def test_cross_file_duplicate_id_detected(self):
        dataset_a = {
            "entities": [{"id": "dup_entity", "name": "First", "type": "character"}],
            "sources": [], "discoveryGates": [], "statements": [], "relationships": [],
        }
        dataset_b = {
            "entities": [{"id": "dup_entity", "name": "Second", "type": "character"}],
            "sources": [], "discoveryGates": [], "statements": [], "relationships": [],
        }
        path_a = write_dataset(self.tempdir.name, "a-dataset.json", dataset_a)
        path_b = write_dataset(self.tempdir.name, "b-dataset.json", dataset_b)
        duplicates = vld.find_cross_file_duplicates([(path_a, dataset_a), (path_b, dataset_b)])
        self.assertTrue(any("dup_entity" in message for message in duplicates))

    def test_missing_required_source_fields_fail(self):
        incomplete_source = {"id": "src_incomplete"}
        dataset = {
            "entities": [{"id": "test_entity", "name": "Test", "type": "character"}],
            "sources": [incomplete_source], "discoveryGates": [], "statements": [], "relationships": [],
        }
        report = self.validate(dataset)
        self.assertTrue(len(report["errors"]) >= 5)  # publisher, title, kind, classification, etc.

    def test_statement_without_secondary_source_warns(self):
        source = base_source(classification="community")
        statement = base_statement("test_stmt", "test_entity", [source["id"]])
        dataset = {
            "entities": [{"id": "test_entity", "name": "Test", "type": "character"}],
            "sources": [source], "discoveryGates": [], "statements": [statement], "relationships": [],
        }
        report = self.validate(dataset)
        self.assertTrue(any("no secondary source" in w for w in report["warnings"]))

    def test_real_datasets_still_valid(self):
        """Regression guard: the actual repository datasets must stay valid."""
        entries_dir = vld.ROOT / "database" / "entries"
        paths = sorted(entries_dir.glob("*-dataset.json"))
        raw_datasets = [(p, vld.load_json(p)) for p in paths]
        global_entities, global_sources, global_gates = set(), set(), set()
        for _, dataset in raw_datasets:
            global_entities |= {e["id"] for e in dataset.get("entities", []) if e.get("id")}
            global_sources |= {s["id"] for s in dataset.get("sources", []) if s.get("id")}
            global_gates |= {g["id"] for g in dataset.get("discoveryGates", []) if g.get("id")}
        cross_file_errors = vld.find_cross_file_duplicates(raw_datasets)
        self.assertEqual(cross_file_errors, [])
        for path, _ in raw_datasets:
            report = vld.validate_dataset(
                path, self.vocabulary, global_entities, global_sources, global_gates, self.era_ids
            )
            self.assertEqual(report["errors"], [], f"{path} has errors: {report['errors']}")


if __name__ == "__main__":
    unittest.main()
