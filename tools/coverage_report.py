#!/usr/bin/env python3
"""Coverage dashboard: cross-references database/entries/coverage-plan.json
against the actual authored datasets and reports Complete/Partial/Missing
per category and era. This is a planning tool, not a validator -- it never
fails the build.
"""

import argparse
import json
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENTRIES_DIR = ROOT / "database" / "entries"
COVERAGE_PLAN_PATH = ENTRIES_DIR / "coverage-plan.json"


def load_json(path):
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def load_authored_entities():
    """entity_id -> set of detail levels present in the authored datasets."""
    levels_by_entity = defaultdict(set)
    for path in sorted(ENTRIES_DIR.glob("*-dataset.json")):
        dataset = load_json(path)
        entity_ids = {e["id"] for e in dataset.get("entities", []) if isinstance(e, dict) and e.get("id")}
        for entity_id in entity_ids:
            levels_by_entity[entity_id]  # ensure entity is registered even with no statements yet
        for statement in dataset.get("statements", []) or []:
            entity_id = statement.get("entityId")
            level = statement.get("detailLevel")
            if entity_id and level:
                levels_by_entity[entity_id].add(level)
    return levels_by_entity


def classify(entity_id, levels_by_entity):
    if entity_id not in levels_by_entity:
        return "missing"
    levels = levels_by_entity[entity_id]
    if "quick" in levels and "story" in levels:
        return "complete"
    if levels:
        return "partial"
    return "partial"  # entity exists but has no statements yet


def build_report(plan_entries, levels_by_entity):
    by_category = defaultdict(lambda: {"complete": 0, "partial": 0, "missing": 0})
    by_era = defaultdict(lambda: {"complete": 0, "partial": 0, "missing": 0})
    details = []
    for entry in plan_entries:
        status = classify(entry["id"], levels_by_entity)
        by_category[entry["category"]][status] += 1
        by_era[entry["era"]][status] += 1
        details.append((entry, status))
    return by_category, by_era, details


def percent_complete(counts):
    total = counts["complete"] + counts["partial"] + counts["missing"]
    if total == 0:
        return 0.0
    return round(100.0 * counts["complete"] / total, 1)


def print_dashboard(by_category, by_era, details, show_missing):
    print("LORE BUDDY COVERAGE DASHBOARD")
    print()
    print("By category:")
    for category in sorted(by_category):
        counts = by_category[category]
        total = counts["complete"] + counts["partial"] + counts["missing"]
        print(
            f"  {category:<10} complete={counts['complete']:<3} partial={counts['partial']:<3} "
            f"missing={counts['missing']:<3} total={total:<3} ({percent_complete(counts)}% complete)"
        )
    print()
    print("By era:")
    for era in sorted(by_era):
        counts = by_era[era]
        total = counts["complete"] + counts["partial"] + counts["missing"]
        print(
            f"  {era:<28} complete={counts['complete']:<3} partial={counts['partial']:<3} "
            f"missing={counts['missing']:<3} total={total:<3} ({percent_complete(counts)}% complete)"
        )
    if show_missing:
        print()
        print("Missing entries (highest priority first):")
        missing = [entry for entry, status in details if status == "missing"]
        missing.sort(key=lambda e: (e.get("priority", "p2"), e["category"], e["name"]))
        for entry in missing:
            print(f"  [{entry.get('priority', 'p2')}] {entry['name']} ({entry['category']}, {entry['era']})")


def main(argv=None):
    parser = argparse.ArgumentParser(description="Report LoreBuddy content coverage against the coverage plan")
    parser.add_argument("--missing", action="store_true", help="also list missing entries by priority")
    args = parser.parse_args(argv)

    plan_entries = load_json(COVERAGE_PLAN_PATH)["plan"]
    levels_by_entity = load_authored_entities()
    by_category, by_era, details = build_report(plan_entries, levels_by_entity)
    print_dashboard(by_category, by_era, details, args.missing)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
