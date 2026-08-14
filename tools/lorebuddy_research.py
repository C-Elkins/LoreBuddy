#!/usr/bin/env python3
"""LoreBuddy Research: gather source references for a search term.

This tool never scrapes or copies prose from third-party sites. It only
constructs reference links (Wowhead, Warcraft Wiki, WoWDB) and, optionally,
stub source records the author can attach to a new lore entry. The author
must write quick/story/deep text themselves, in their own words, citing
these references -- respecting third-party copyright.
"""

import argparse
import json
import subprocess
import sys
import tkinter as tk
import webbrowser
from pathlib import Path
from tkinter import messagebox
from urllib.parse import quote

sys.path.insert(0, str(Path(__file__).resolve().parent))
import lorebuddy_author as la  # noqa: E402  (reuse slug/id helpers and dataset I/O)

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATASET = ROOT / "database" / "entries" / "example-dataset.json"


def build_references(query):
    encoded = quote(query)
    return [
        {
            "label": "Wowhead",
            "url": f"https://www.wowhead.com/search?q={encoded}#npcs",
            "note": "Search Wowhead for NPC IDs, items, quests, and zones.",
            "publisher": "Wowhead",
            "license": "Proprietary; reference link only, do not copy text",
        },
        {
            "label": "Warcraft Wiki",
            "url": f"https://warcraft.wiki.gg/index.php?search={encoded}",
            "note": "Search Warcraft Wiki (wiki.gg) for lore articles.",
            "publisher": "Warcraft Wiki (wiki.gg)",
            "license": "CC BY-SA 4.0; summarize in your own words and attribute",
        },
        {
            "label": "WoWDB",
            "url": f"https://www.wowdb.com/search?search={encoded}#t1:npcs",
            "note": "Cross-reference NPC IDs and zone/encounter data.",
            "publisher": "WoWDB",
            "license": "Proprietary; reference link only, do not copy text",
        },
        {
            "label": "Blizzard",
            "url": None,
            "note": (
                "Use tools/blizzard_api_request.sh with local credentials for official "
                "Game Data API lookups. See docs/BLIZZARD_API_SETUP.md."
            ),
            "publisher": "Blizzard Entertainment",
            "license": None,
        },
    ]


class ResearchApp(tk.Tk):
    def __init__(self, dataset_path):
        super().__init__()
        self.title("LoreBuddy Research")
        self.geometry("640x520")
        self.dataset_path = dataset_path
        self.references = []

        tk.Label(self, text="\U0001F50E Research", font=("Segoe UI", 14, "bold")).pack(
            anchor="w", padx=10, pady=(10, 4)
        )

        search_row = tk.Frame(self)
        search_row.pack(fill="x", padx=10)
        tk.Label(search_row, text="Search Warcraft information:").pack(side="left")
        self.query_var = tk.StringVar()
        entry = tk.Entry(search_row, textvariable=self.query_var, width=40)
        entry.pack(side="left", fill="x", expand=True, padx=6)
        entry.bind("<Return>", lambda _event: self._search())
        tk.Button(search_row, text="SEARCH SOURCES", command=self._search).pack(side="left")

        self.results_frame = tk.Frame(self)
        self.results_frame.pack(fill="both", expand=True, padx=10, pady=10)

        self.create_button = tk.Button(
            self, text="[ CREATE LORE ENTRY ]", state="disabled", command=self._create_lore_entry
        )
        self.create_button.pack(fill="x", padx=10, pady=(0, 10))

    def _search(self):
        query = self.query_var.get().strip()
        for child in self.results_frame.winfo_children():
            child.destroy()
        if not query:
            self.create_button.config(state="disabled")
            return

        self.references = build_references(query)
        for reference in self.references:
            block = tk.LabelFrame(self.results_frame, text=reference["label"], padx=6, pady=6)
            block.pack(fill="x", pady=4)
            tk.Label(block, text=reference["note"], wraplength=560, justify="left").pack(anchor="w")
            if reference["url"]:
                link = tk.Label(block, text=reference["url"], fg="#1a5fb4", cursor="hand2")
                link.pack(anchor="w")
                link.bind("<Button-1>", lambda _e, url=reference["url"]: webbrowser.open(url))

        tk.Label(
            self.results_frame,
            text=(
                "Important: this only gathers reference links. Write lore text in your own "
                "words and cite these sources -- do not paste copyrighted prose."
            ),
            fg="#c62828",
            wraplength=560,
            justify="left",
        ).pack(fill="x", pady=(6, 0))

        self.create_button.config(state="normal")

    def _create_lore_entry(self):
        query = self.query_var.get().strip()
        if not query:
            return
        dataset = la.load_dataset(self.dataset_path)
        entity_id = la.unique_id(la.slugify(query), la.all_ids(dataset))
        dataset["entities"].append({"id": entity_id, "name": query, "type": "character", "status": "draft"})

        source_ids = []
        for reference in self.references:
            if not reference["url"]:
                continue
            source_id = la.unique_id(f"{entity_id}_{reference['label'].lower().replace(' ', '_')}", la.all_ids(dataset))
            dataset["sources"].append(
                {
                    "id": source_id,
                    "publisher": reference["publisher"],
                    "title": f"{query} \u2014 {reference['label']} search",
                    "kind": "external_reference",
                    "classification": "community",
                    "reference": reference["url"],
                    "url": reference["url"],
                    "attribution": reference["publisher"],
                    "license": reference["license"],
                    "verificationStatus": "unverified",
                }
            )
            source_ids.append(source_id)

        with self.dataset_path.open("w", encoding="utf-8") as handle:
            json.dump(dataset, handle, indent=2, ensure_ascii=False)
            handle.write("\n")

        messagebox.showinfo(
            "Draft entry created",
            f"Created draft entry '{query}' with {len(source_ids)} reference source(s).\n"
            "Opening the authoring tool to write quick/story/deep text.",
        )
        subprocess.Popen([sys.executable, str(Path(__file__).resolve().parent / "lorebuddy_author.py"), str(self.dataset_path)])
        self.destroy()


def main(argv=None):
    parser = argparse.ArgumentParser(description="LoreBuddy research assistant")
    parser.add_argument("dataset", nargs="?", type=Path, default=DEFAULT_DATASET, help="dataset file to add drafts to")
    args = parser.parse_args(argv)
    app = ResearchApp(args.dataset)
    app.mainloop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
