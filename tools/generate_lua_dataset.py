#!/usr/bin/env python3
"""Generate core/GeneratedDataset.lua from database/entries/*.json.

WoW addons cannot parse JSON at runtime, so this bakes the merged dataset
into a plain Lua table the addon can load directly. Re-run this after
editing any dataset file, before packaging or testing in-game.
"""

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENTRIES_DIR = ROOT / "database" / "entries"
DEFAULT_OUTPUT = ROOT / "core" / "GeneratedDataset.lua"
MERGE_FIELDS = ("entities", "sources", "discoveryGates", "statements", "relationships")


def lua_string(value):
    escaped = (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
    )
    return f'"{escaped}"'


def to_lua(value, indent=0):
    pad = "  " * indent
    pad_inner = "  " * (indent + 1)
    if isinstance(value, dict):
        lines = ["{"]
        for key, val in value.items():
            if val is None:
                continue
            lines.append(f"{pad_inner}[{lua_string(str(key))}] = {to_lua(val, indent + 1)},")
        lines.append(pad + "}")
        return "\n".join(lines)
    if isinstance(value, list):
        if not value:
            return "{}"
        lines = ["{"]
        for item in value:
            lines.append(f"{pad_inner}{to_lua(item, indent + 1)},")
        lines.append(pad + "}")
        return "\n".join(lines)
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        return lua_string(value)
    raise TypeError(f"Unsupported type in dataset: {type(value)}")


def load_merged(paths):
    merged = {field: [] for field in MERGE_FIELDS}
    for path in paths:
        with path.open(encoding="utf-8") as handle:
            dataset = json.load(handle)
        for field in MERGE_FIELDS:
            merged[field].extend(dataset.get(field) or [])
    return merged


def main(argv=None):
    parser = argparse.ArgumentParser(description="Generate the Lua dataset for the addon")
    parser.add_argument("output", nargs="?", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args(argv)

    paths = sorted(ENTRIES_DIR.glob("*-dataset.json"))
    merged = load_merged(paths)

    with args.output.open("w", encoding="utf-8") as handle:
        handle.write("-- GENERATED FILE. Run tools/generate_lua_dataset.py to regenerate.\n")
        handle.write("-- Source: database/entries/*-dataset.json. Do not hand-edit.\n\n")
        handle.write("local LoreBuddyCore = _G.LoreBuddyCore or {}\n")
        handle.write("_G.LoreBuddyCore = LoreBuddyCore\n\n")
        handle.write("LoreBuddyCore.GeneratedDataset = " + to_lua(merged) + "\n")

    print(
        f"Wrote {args.output} "
        f"({len(merged['entities'])} entities, {len(merged['statements'])} statements, "
        f"{len(merged['relationships'])} relationships)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
