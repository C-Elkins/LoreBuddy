#!/usr/bin/env python3
"""LoreBuddy Explorer: a read-only desktop viewer for the lore graph.

Loads every database/entries/*-dataset.json file, then lets you browse
entities, click connections to jump the graph, and toggle spoiler visibility
to test discovery gating -- all without WoW running.
"""

import argparse
import sys
import tkinter as tk
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import validate_lore_data as vld  # noqa: E402  (reuse load_json + dataset glob root)

ROOT = Path(__file__).resolve().parents[1]
ENTRIES_DIR = ROOT / "database" / "entries"
LOCATION_TYPES = {"zone", "location", "raid", "dungeon"}


def load_merged_dataset(paths):
    merged = {"entities": [], "sources": [], "discoveryGates": [], "statements": [], "relationships": []}
    for path in paths:
        dataset = vld.load_json(path)
        for field in merged:
            merged[field].extend(dataset.get(field, []) or [])
    return merged


def is_visible(statement, allow_spoilers):
    return allow_spoilers or not statement.get("discoveryGateIds")


class ExplorerApp(tk.Tk):
    def __init__(self, dataset):
        super().__init__()
        self.title("LoreBuddy Explorer")
        self.geometry("1000x650")

        self.dataset = dataset
        self.entities_by_id = {e["id"]: e for e in dataset["entities"] if e.get("id")}
        self.sources_by_id = {s["id"]: s for s in dataset["sources"] if s.get("id")}
        self.history = []
        self.current_entity_id = None
        self.allow_spoilers_var = tk.BooleanVar(value=False)

        self._build_layout()
        self._refresh_entity_list()

    def _build_layout(self):
        left = tk.Frame(self, width=260)
        left.pack(side="left", fill="y", padx=6, pady=6)
        left.pack_propagate(False)

        tk.Label(left, text="LoreBuddy Explorer", font=("Segoe UI", 12, "bold")).pack(anchor="w")

        self.search_var = tk.StringVar()
        self.search_var.trace_add("write", lambda *_: self._refresh_entity_list())
        tk.Entry(left, textvariable=self.search_var).pack(fill="x", pady=(8, 4))

        list_frame = tk.Frame(left)
        list_frame.pack(fill="both", expand=True)
        scrollbar = tk.Scrollbar(list_frame)
        scrollbar.pack(side="right", fill="y")
        self.entity_listbox = tk.Listbox(list_frame, yscrollcommand=scrollbar.set, exportselection=False)
        self.entity_listbox.pack(side="left", fill="both", expand=True)
        scrollbar.config(command=self.entity_listbox.yview)
        self.entity_listbox.bind("<<ListboxSelect>>", self._on_select_entity)

        tk.Checkbutton(
            left, text="Allow spoilers", variable=self.allow_spoilers_var, command=self._render_current
        ).pack(anchor="w", pady=(6, 0))

        right = tk.Frame(self)
        right.pack(side="left", fill="both", expand=True, padx=6, pady=6)

        nav_row = tk.Frame(right)
        nav_row.pack(fill="x")
        self.back_button = tk.Button(nav_row, text="\u2190 Back", command=self._go_back, state="disabled")
        self.back_button.pack(side="left")

        self.name_label = tk.Label(right, text="", font=("Segoe UI", 18, "bold"))
        self.name_label.pack(anchor="w", pady=(8, 0))
        self.subtitle_label = tk.Label(right, text="", font=("Segoe UI", 10, "italic"), fg="#555555")
        self.subtitle_label.pack(anchor="w")
        self.summary_label = tk.Label(right, text="", wraplength=680, justify="left")
        self.summary_label.pack(anchor="w", pady=(4, 8))

        self.detail_text = tk.Text(right, height=10, wrap="word", state="disabled")
        self.detail_text.pack(fill="both", pady=(0, 8))

        lists_row = tk.Frame(right)
        lists_row.pack(fill="both", expand=True)

        connections_frame = tk.LabelFrame(lists_row, text="CONNECTIONS", padx=6, pady=6)
        connections_frame.pack(side="left", fill="both", expand=True, padx=(0, 6))
        self.connections_listbox = tk.Listbox(connections_frame, exportselection=False)
        self.connections_listbox.pack(fill="both", expand=True)
        self.connections_listbox.bind("<<ListboxSelect>>", self._on_select_connection)

        locations_frame = tk.LabelFrame(lists_row, text="LOCATIONS", padx=6, pady=6)
        locations_frame.pack(side="left", fill="both", expand=True, padx=(6, 0))
        self.locations_listbox = tk.Listbox(locations_frame, exportselection=False)
        self.locations_listbox.pack(fill="both", expand=True)
        self.locations_listbox.bind("<<ListboxSelect>>", self._on_select_location)

    # -- entity list -----------------------------------------------------------
    def _refresh_entity_list(self):
        query = self.search_var.get().strip().lower()
        entities = sorted(
            self.entities_by_id.values(), key=lambda e: (e.get("type", ""), e.get("name", ""))
        )
        self.entity_listbox.delete(0, tk.END)
        self._entity_ids_by_row = []
        for entity in entities:
            haystack = " ".join(
                [entity.get("name", ""), entity.get("type", ""), " ".join(entity.get("aliases", []))]
            ).lower()
            if query and query not in haystack:
                continue
            self.entity_listbox.insert(tk.END, f"{entity.get('type', '').upper():<10} {entity.get('name', '')}")
            self._entity_ids_by_row.append(entity["id"])

    def _on_select_entity(self, _event):
        selection = self.entity_listbox.curselection()
        if not selection:
            return
        self._show_entity(self._entity_ids_by_row[selection[0]], push_history=True)

    # -- navigation --------------------------------------------------------------
    def _show_entity(self, entity_id, push_history):
        if entity_id not in self.entities_by_id:
            return
        if push_history and self.current_entity_id and self.current_entity_id != entity_id:
            self.history.append(self.current_entity_id)
            self.back_button.config(state="normal")
        self.current_entity_id = entity_id
        self._render_current()

    def _go_back(self):
        if not self.history:
            return
        entity_id = self.history.pop()
        self.current_entity_id = entity_id
        self._render_current()
        self.back_button.config(state="normal" if self.history else "disabled")

    def _on_select_connection(self, _event):
        selection = self.connections_listbox.curselection()
        if not selection:
            return
        self._show_entity(self._connection_ids_by_row[selection[0]], push_history=True)

    def _on_select_location(self, _event):
        selection = self.locations_listbox.curselection()
        if not selection:
            return
        self._show_entity(self._location_ids_by_row[selection[0]], push_history=True)

    # -- rendering -----------------------------------------------------------------
    def _render_current(self):
        entity = self.entities_by_id.get(self.current_entity_id)
        if not entity:
            return
        allow_spoilers = self.allow_spoilers_var.get()

        self.name_label.config(text=entity.get("name", ""))
        self.subtitle_label.config(
            text=f"{entity.get('type', '').capitalize()} \u00b7 {entity.get('status', 'unknown').capitalize()}"
        )
        self.summary_label.config(text=entity.get("summary", ""))

        statements = [
            s
            for s in self.dataset["statements"]
            if s.get("entityId") == self.current_entity_id and is_visible(s, allow_spoilers)
        ]
        order = {"quick": 0, "story": 1, "deep": 2}
        statements.sort(key=lambda s: order.get(s.get("detailLevel"), 3))

        self.detail_text.config(state="normal")
        self.detail_text.delete("1.0", tk.END)
        if not statements:
            self.detail_text.insert("1.0", "(No visible lore. Enable 'Allow spoilers' to see gated content.)")
        for statement in statements:
            self.detail_text.insert(tk.END, f"[{statement.get('detailLevel', '').upper()}] ")
            self.detail_text.insert(tk.END, statement.get("text", "") + "\n\n")
        self.detail_text.config(state="disabled")

        connections = []
        locations = []
        for relationship in self.dataset["relationships"]:
            other_id = None
            direction = None
            if relationship.get("subjectId") == self.current_entity_id:
                other_id, direction = relationship.get("objectId"), "outgoing"
            elif relationship.get("objectId") == self.current_entity_id:
                other_id, direction = relationship.get("subjectId"), "incoming"
            else:
                continue
            other = self.entities_by_id.get(other_id)
            if not other:
                continue
            label = (
                f"{relationship.get('predicate')} \u2192 {other.get('name')}"
                if direction == "outgoing"
                else f"{other.get('name')} \u2192 {relationship.get('predicate')}"
            )
            if other.get("type") in LOCATION_TYPES:
                locations.append((label, other_id))
            else:
                connections.append((label, other_id))

        self.connections_listbox.delete(0, tk.END)
        self._connection_ids_by_row = []
        for label, other_id in connections:
            self.connections_listbox.insert(tk.END, label)
            self._connection_ids_by_row.append(other_id)

        self.locations_listbox.delete(0, tk.END)
        self._location_ids_by_row = []
        for label, other_id in locations:
            self.locations_listbox.insert(tk.END, label)
            self._location_ids_by_row.append(other_id)


def main(argv=None):
    parser = argparse.ArgumentParser(description="LoreBuddy lore explorer")
    parser.add_argument(
        "datasets", nargs="*", type=Path, help="dataset files; defaults to database/entries/*-dataset.json"
    )
    args = parser.parse_args(argv)
    paths = args.datasets or sorted(ENTRIES_DIR.glob("*-dataset.json"))
    dataset = load_merged_dataset(paths)
    app = ExplorerApp(dataset)
    if dataset["entities"]:
        app._show_entity(dataset["entities"][0]["id"], push_history=False)
    app.mainloop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
