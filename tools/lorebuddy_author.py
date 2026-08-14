#!/usr/bin/env python3
"""LoreBuddy Author: a GUI for creating and editing lore dataset entries.

Reuses the schema constants and validation logic from validate_lore_data.py
so authored data stays consistent with `LoreBuddy validate`.
"""

import argparse
import json
import re
import sys
import tkinter as tk
from pathlib import Path
from tkinter import messagebox, ttk

import validate_lore_data as vld

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATASET = ROOT / "database" / "entries" / "example-dataset.json"

ENTITY_STATUSES = ["draft", "active", "retired"]


def slugify(text):
    slug = re.sub(r"[^a-z0-9]+", "_", text.strip().lower()).strip("_")
    return slug or "entry"


def unique_id(base, existing_ids):
    candidate = base
    suffix = 2
    while candidate in existing_ids:
        candidate = f"{base}_{suffix}"
        suffix += 1
    return candidate


def all_ids(dataset):
    ids = set()
    for field in ("entities", "sources", "discoveryGates", "statements", "relationships"):
        for record in dataset.get(field, []):
            if isinstance(record, dict) and record.get("id"):
                ids.add(record["id"])
    return ids


def load_dataset(path):
    if path.exists():
        return vld.load_json(path)
    return {
        "datasetVersion": 1,
        "entities": [],
        "sources": [],
        "discoveryGates": [],
        "statements": [],
        "relationships": [],
    }


def load_vocabulary():
    return vld.load_json(vld.VOCABULARY_PATH)["relationships"]


class NewSourceDialog(tk.Toplevel):
    def __init__(self, parent):
        super().__init__(parent)
        self.title("New Source")
        self.result = None
        self.resizable(False, False)

        fields = [
            ("title", "Title"),
            ("publisher", "Publisher"),
            ("reference", "Reference"),
            ("attribution", "Attribution"),
            ("license", "License"),
        ]
        self.entries = {}
        for row, (key, label) in enumerate(fields):
            tk.Label(self, text=label + ":").grid(row=row, column=0, sticky="w", padx=6, pady=4)
            entry = tk.Entry(self, width=40)
            entry.grid(row=row, column=1, padx=6, pady=4)
            self.entries[key] = entry

        offset = len(fields)
        self.kind_var = tk.StringVar(value=vld.SOURCE_KINDS_LIST[0])
        tk.Label(self, text="Kind:").grid(row=offset, column=0, sticky="w", padx=6, pady=4)
        ttk.OptionMenu(self, self.kind_var, self.kind_var.get(), *vld.SOURCE_KINDS_LIST).grid(
            row=offset, column=1, sticky="w", padx=6, pady=4
        )

        self.classification_var = tk.StringVar(value=vld.SOURCE_CLASSIFICATIONS_LIST[0])
        tk.Label(self, text="Classification:").grid(row=offset + 1, column=0, sticky="w", padx=6, pady=4)
        ttk.OptionMenu(
            self, self.classification_var, self.classification_var.get(), *vld.SOURCE_CLASSIFICATIONS_LIST
        ).grid(row=offset + 1, column=1, sticky="w", padx=6, pady=4)

        self.verification_var = tk.StringVar(value=vld.VERIFICATION_STATUSES_LIST[0])
        tk.Label(self, text="Verification:").grid(row=offset + 2, column=0, sticky="w", padx=6, pady=4)
        ttk.OptionMenu(
            self, self.verification_var, self.verification_var.get(), *vld.VERIFICATION_STATUSES_LIST
        ).grid(row=offset + 2, column=1, sticky="w", padx=6, pady=4)

        button_row = offset + 3
        tk.Button(self, text="Cancel", command=self.destroy).grid(row=button_row, column=0, pady=8)
        tk.Button(self, text="Add Source", command=self._submit).grid(row=button_row, column=1, pady=8)

        self.transient(parent)
        self.grab_set()

    def _submit(self):
        values = {key: entry.get().strip() for key, entry in self.entries.items()}
        if not values["title"] or not values["publisher"] or not values["reference"]:
            messagebox.showerror("Missing fields", "Title, publisher, and reference are required.", parent=self)
            return
        values["kind"] = self.kind_var.get()
        values["classification"] = self.classification_var.get()
        values["verificationStatus"] = self.verification_var.get()
        if not values["attribution"]:
            values["attribution"] = values["publisher"]
        if not values["license"]:
            values["license"] = "Unspecified; confirm before publishing"
        self.result = values
        self.destroy()


class AddConnectionDialog(tk.Toplevel):
    def __init__(self, parent, predicates, entity_options, self_label):
        super().__init__(parent)
        self.title("Add Connection")
        self.result = None
        self.resizable(False, False)

        tk.Label(self, text="Predicate:").grid(row=0, column=0, sticky="w", padx=6, pady=4)
        self.predicate_var = tk.StringVar(value=predicates[0] if predicates else "")
        ttk.Combobox(self, textvariable=self.predicate_var, values=predicates, width=30, state="readonly").grid(
            row=0, column=1, padx=6, pady=4
        )

        tk.Label(self, text="Target entity:").grid(row=1, column=0, sticky="w", padx=6, pady=4)
        self.target_var = tk.StringVar()
        self.target_labels = [label for label, _ in entity_options]
        self.target_map = dict(entity_options)
        ttk.Combobox(
            self, textvariable=self.target_var, values=self.target_labels, width=30, state="readonly"
        ).grid(row=1, column=1, padx=6, pady=4)

        tk.Label(self, text="Direction:").grid(row=2, column=0, sticky="w", padx=6, pady=4)
        self.direction_var = tk.StringVar(value="forward")
        tk.Radiobutton(
            self, text=f"{self_label} \u2192 Target", variable=self.direction_var, value="forward"
        ).grid(row=2, column=1, sticky="w")
        tk.Radiobutton(
            self, text=f"Target \u2192 {self_label}", variable=self.direction_var, value="reverse"
        ).grid(row=3, column=1, sticky="w")

        tk.Button(self, text="Cancel", command=self.destroy).grid(row=4, column=0, pady=8)
        tk.Button(self, text="Add Connection", command=self._submit).grid(row=4, column=1, pady=8)

        self.transient(parent)
        self.grab_set()

    def _submit(self):
        predicate = self.predicate_var.get()
        target_label = self.target_var.get()
        if not predicate or target_label not in self.target_map:
            messagebox.showerror("Missing fields", "Choose a predicate and a target entity.", parent=self)
            return
        self.result = (predicate, self.target_map[target_label], self.direction_var.get())
        self.destroy()


class AuthorApp(tk.Tk):
    def __init__(self, dataset_path):
        super().__init__()
        self.title("LoreBuddy Author")
        self.geometry("1000x650")

        self.dataset_path = dataset_path
        self.dataset = load_dataset(dataset_path)
        self.vocabulary = load_vocabulary()
        self.current_entity_id = None
        self.current_sources = set()

        self._build_layout()
        self._refresh_entity_list()

    # -- layout -----------------------------------------------------------------
    def _build_layout(self):
        left = tk.Frame(self, width=260)
        left.pack(side="left", fill="y", padx=6, pady=6)
        left.pack_propagate(False)

        tk.Label(left, text="\U0001F9D9 LORE BUDDY AUTHOR", font=("Segoe UI", 12, "bold")).pack(anchor="w")

        self.search_var = tk.StringVar()
        self.search_var.trace_add("write", lambda *_: self._refresh_entity_list())
        search_entry = tk.Entry(left, textvariable=self.search_var)
        search_entry.pack(fill="x", pady=(8, 4))
        search_entry.insert(0, "")
        search_entry.bind("<KeyRelease>", lambda *_: None)
        search_entry.focus_set()
        self._set_placeholder(search_entry, "Search lore...")

        list_frame = tk.Frame(left)
        list_frame.pack(fill="both", expand=True)
        scrollbar = tk.Scrollbar(list_frame)
        scrollbar.pack(side="right", fill="y")
        self.entity_listbox = tk.Listbox(list_frame, yscrollcommand=scrollbar.set, exportselection=False)
        self.entity_listbox.pack(side="left", fill="both", expand=True)
        scrollbar.config(command=self.entity_listbox.yview)
        self.entity_listbox.bind("<<ListboxSelect>>", self._on_select_entity)

        tk.Button(left, text="+ NEW ENTRY", command=self._new_entity).pack(fill="x", pady=(6, 0))
        tk.Button(left, text="\U0001F50E Research", command=self._open_research).pack(fill="x", pady=(4, 0))
        self.status_label = tk.Label(left, text="", wraplength=240, justify="left", fg="#2e7d32")
        self.status_label.pack(fill="x", pady=(8, 0))

        right = tk.Frame(self)
        right.pack(side="left", fill="both", expand=True, padx=6, pady=6)

        header_row = tk.Frame(right)
        header_row.pack(fill="x")
        tk.Label(header_row, text="Type:").grid(row=0, column=0, sticky="w")
        self.type_var = tk.StringVar(value=vld.ENTITY_TYPES_LIST[0])
        ttk.OptionMenu(header_row, self.type_var, self.type_var.get(), *vld.ENTITY_TYPES_LIST).grid(
            row=0, column=1, sticky="w", padx=(4, 16)
        )
        tk.Label(header_row, text="Status:").grid(row=0, column=2, sticky="w")
        self.entity_status_var = tk.StringVar(value=ENTITY_STATUSES[0])
        ttk.OptionMenu(header_row, self.entity_status_var, self.entity_status_var.get(), *ENTITY_STATUSES).grid(
            row=0, column=3, sticky="w", padx=(4, 16)
        )
        tk.Label(header_row, text="Canon:").grid(row=0, column=4, sticky="w")
        self.canon_var = tk.StringVar(value=vld.CANON_STATUSES_LIST[0])
        ttk.OptionMenu(header_row, self.canon_var, self.canon_var.get(), *vld.CANON_STATUSES_LIST).grid(
            row=0, column=5, sticky="w", padx=(4, 16)
        )
        tk.Label(header_row, text="Epistemic:").grid(row=0, column=6, sticky="w")
        self.epistemic_var = tk.StringVar(value=vld.EPISTEMIC_STATUSES_LIST[0])
        ttk.OptionMenu(header_row, self.epistemic_var, self.epistemic_var.get(), *vld.EPISTEMIC_STATUSES_LIST).grid(
            row=0, column=7, sticky="w"
        )

        name_row = tk.Frame(right)
        name_row.pack(fill="x", pady=(8, 0))
        tk.Label(name_row, text="Name:").pack(side="left")
        self.name_var = tk.StringVar()
        tk.Entry(name_row, textvariable=self.name_var, font=("Segoe UI", 14, "bold")).pack(
            side="left", fill="x", expand=True, padx=6
        )

        aliases_row = tk.Frame(right)
        aliases_row.pack(fill="x", pady=(4, 0))
        tk.Label(aliases_row, text="Aliases (comma-separated):").pack(side="left")
        self.aliases_var = tk.StringVar()
        tk.Entry(aliases_row, textvariable=self.aliases_var).pack(side="left", fill="x", expand=True, padx=6)

        summary_row = tk.Frame(right)
        summary_row.pack(fill="x", pady=(4, 8))
        tk.Label(summary_row, text="Summary:").pack(side="left")
        self.summary_var = tk.StringVar()
        tk.Entry(summary_row, textvariable=self.summary_var).pack(side="left", fill="x", expand=True, padx=6)

        self.quick_text = self._labeled_text(right, "QUICK", 3)
        self.story_text = self._labeled_text(right, "STORY", 5)
        self.deep_text = self._labeled_text(right, "DEEP LORE", 7)

        lists_row = tk.Frame(right)
        lists_row.pack(fill="both", expand=True, pady=(8, 0))

        connections_frame = tk.Frame(lists_row)
        connections_frame.pack(side="left", fill="both", expand=True, padx=(0, 6))
        tk.Label(connections_frame, text="CONNECTIONS", font=("Segoe UI", 9, "bold")).pack(anchor="w")
        self.connections_listbox = tk.Listbox(connections_frame, height=6, exportselection=False)
        self.connections_listbox.pack(fill="both", expand=True)
        conn_buttons = tk.Frame(connections_frame)
        conn_buttons.pack(fill="x")
        tk.Button(conn_buttons, text="+ Add", command=self._add_connection).pack(side="left")
        tk.Button(conn_buttons, text="- Remove", command=self._remove_connection).pack(side="left", padx=4)

        sources_frame = tk.Frame(lists_row)
        sources_frame.pack(side="left", fill="both", expand=True, padx=(6, 0))
        tk.Label(sources_frame, text="SOURCES", font=("Segoe UI", 9, "bold")).pack(anchor="w")
        self.sources_listbox = tk.Listbox(sources_frame, height=6, exportselection=False)
        self.sources_listbox.pack(fill="both", expand=True)
        source_buttons = tk.Frame(sources_frame)
        source_buttons.pack(fill="x")
        tk.Button(source_buttons, text="+ Existing", command=self._add_existing_source).pack(side="left")
        tk.Button(source_buttons, text="+ New", command=self._add_new_source).pack(side="left", padx=4)
        tk.Button(source_buttons, text="- Remove", command=self._remove_source).pack(side="left")

        tk.Button(right, text="SAVE", font=("Segoe UI", 11, "bold"), command=self._save_entity).pack(
            fill="x", pady=(10, 0)
        )
        self.result_label = tk.Label(right, text="", anchor="w", justify="left")
        self.result_label.pack(fill="x", pady=(6, 0))

        self._clear_detail_panel()

    def _labeled_text(self, parent, label, height):
        frame = tk.Frame(parent)
        frame.pack(fill="both", expand=False, pady=(4, 0))
        tk.Label(frame, text=label, font=("Segoe UI", 9, "bold")).pack(anchor="w")
        text = tk.Text(frame, height=height, wrap="word")
        text.pack(fill="both", expand=True)
        return text

    def _set_placeholder(self, entry, text):
        entry.insert(0, text)
        entry.config(fg="grey")

        def on_focus_in(_event):
            if entry.get() == text:
                entry.delete(0, tk.END)
                entry.config(fg="black")

        def on_focus_out(_event):
            if not entry.get():
                entry.insert(0, text)
                entry.config(fg="grey")

        entry.bind("<FocusIn>", on_focus_in)
        entry.bind("<FocusOut>", on_focus_out)

    # -- entity list --------------------------------------------------------
    def _search_text(self):
        text = self.search_var.get().strip().lower()
        return "" if text == "search lore..." else text

    def _refresh_entity_list(self, keep_selection=True):
        if not hasattr(self, "entity_listbox"):
            return
        selected_id = self.current_entity_id if keep_selection else None
        query = self._search_text()
        entities = sorted(self.dataset["entities"], key=lambda e: (e.get("type", ""), e.get("name", "")))
        self.entity_listbox.delete(0, tk.END)
        self._entity_ids_by_row = []
        select_row = None
        for entity in entities:
            haystack = " ".join(
                [entity.get("name", ""), entity.get("type", ""), " ".join(entity.get("aliases", []))]
            ).lower()
            if query and query not in haystack:
                continue
            label = f"{entity.get('type', '').upper():<10} {entity.get('name', '')}"
            self.entity_listbox.insert(tk.END, label)
            self._entity_ids_by_row.append(entity["id"])
            if entity["id"] == selected_id:
                select_row = len(self._entity_ids_by_row) - 1
        if select_row is not None:
            self.entity_listbox.selection_set(select_row)

    def _find_entity(self, entity_id):
        for entity in self.dataset["entities"]:
            if entity["id"] == entity_id:
                return entity
        return None

    def _on_select_entity(self, _event):
        selection = self.entity_listbox.curselection()
        if not selection:
            return
        entity_id = self._entity_ids_by_row[selection[0]]
        self._load_entity(entity_id)

    def _new_entity(self):
        self.current_entity_id = None
        self._clear_detail_panel()
        self.name_var.set("New Entry")

    def _open_research(self):
        import subprocess

        subprocess.Popen(
            [sys.executable, str(Path(__file__).resolve().parent / "lorebuddy_research.py"), str(self.dataset_path)]
        )

    def _clear_detail_panel(self):
        self.current_sources = set()
        self.name_var.set("")
        self.aliases_var.set("")
        self.summary_var.set("")
        self.type_var.set(vld.ENTITY_TYPES_LIST[0])
        self.entity_status_var.set(ENTITY_STATUSES[0])
        self.canon_var.set(vld.CANON_STATUSES_LIST[0])
        self.epistemic_var.set(vld.EPISTEMIC_STATUSES_LIST[0])
        self.quick_text.delete("1.0", tk.END)
        self.story_text.delete("1.0", tk.END)
        self.deep_text.delete("1.0", tk.END)
        self.connections_listbox.delete(0, tk.END)
        self.sources_listbox.delete(0, tk.END)
        self.result_label.config(text="")

    def _load_entity(self, entity_id):
        entity = self._find_entity(entity_id)
        if not entity:
            return
        self.current_entity_id = entity_id
        self.name_var.set(entity.get("name", ""))
        self.aliases_var.set(", ".join(entity.get("aliases", [])))
        self.summary_var.set(entity.get("summary", ""))
        self.type_var.set(entity.get("type", vld.ENTITY_TYPES_LIST[0]))
        self.entity_status_var.set(entity.get("status", ENTITY_STATUSES[0]))

        statements = [s for s in self.dataset["statements"] if s.get("entityId") == entity_id]
        by_level = {s.get("detailLevel"): s for s in statements}
        self.quick_text.delete("1.0", tk.END)
        self.story_text.delete("1.0", tk.END)
        self.deep_text.delete("1.0", tk.END)
        if "quick" in by_level:
            self.quick_text.insert("1.0", by_level["quick"].get("text", ""))
        if "story" in by_level:
            self.story_text.insert("1.0", by_level["story"].get("text", ""))
        if "deep" in by_level:
            self.deep_text.insert("1.0", by_level["deep"].get("text", ""))

        collected_sources = set()
        primary_statement = statements[0] if statements else None
        if primary_statement:
            self.canon_var.set(primary_statement.get("canonStatus", vld.CANON_STATUSES_LIST[0]))
            self.epistemic_var.set(primary_statement.get("epistemicStatus", vld.EPISTEMIC_STATUSES_LIST[0]))
        for statement in statements:
            collected_sources.update(statement.get("sourceIds", []))

        self.connections_listbox.delete(0, tk.END)
        self._connection_ids_by_row = []
        for relationship in self.dataset["relationships"]:
            if relationship.get("subjectId") == entity_id:
                other = self._find_entity(relationship.get("objectId"))
                label = f"{relationship.get('predicate')} \u2192 {other.get('name') if other else relationship.get('objectId')}"
            elif relationship.get("objectId") == entity_id:
                other = self._find_entity(relationship.get("subjectId"))
                label = f"{other.get('name') if other else relationship.get('subjectId')} \u2192 {relationship.get('predicate')}"
            else:
                continue
            self.connections_listbox.insert(tk.END, label)
            self._connection_ids_by_row.append(relationship["id"])
            collected_sources.update(relationship.get("sourceIds", []))

        self.current_sources = collected_sources
        self._refresh_sources_listbox()
        self.result_label.config(text="")

    def _refresh_sources_listbox(self):
        self.sources_listbox.delete(0, tk.END)
        self._source_ids_by_row = sorted(self.current_sources)
        for source_id in self._source_ids_by_row:
            source = next((s for s in self.dataset["sources"] if s["id"] == source_id), None)
            title = source.get("title", source_id) if source else source_id
            self.sources_listbox.insert(tk.END, f"{title} ({source_id})")

    # -- connections ----------------------------------------------------------
    def _add_connection(self):
        if not self.current_entity_id:
            messagebox.showinfo("Save first", "Save this entry before adding connections.")
            return
        predicates = sorted(self.vocabulary.keys())
        entity_options = [
            (f"{e.get('type', '').upper()}: {e.get('name', '')}", e["id"])
            for e in self.dataset["entities"]
            if e["id"] != self.current_entity_id
        ]
        if not entity_options:
            messagebox.showinfo("No targets", "Create another entry first to connect to.")
            return
        dialog = AddConnectionDialog(self, predicates, entity_options, self.name_var.get() or "This entry")
        self.wait_window(dialog)
        if not dialog.result:
            return
        predicate, target_id, direction = dialog.result
        if not self.current_sources:
            messagebox.showerror("Missing source", "Add at least one source before creating connections.")
            return
        subject_id, object_id = (
            (self.current_entity_id, target_id) if direction == "forward" else (target_id, self.current_entity_id)
        )
        relationship_id = unique_id(f"{subject_id}_{predicate}_{object_id}", all_ids(self.dataset))
        self.dataset["relationships"].append(
            {
                "id": relationship_id,
                "subjectId": subject_id,
                "predicate": predicate,
                "objectId": object_id,
                "sourceIds": sorted(self.current_sources),
                "canonStatus": self.canon_var.get(),
                "epistemicStatus": self.epistemic_var.get(),
            }
        )
        self._load_entity(self.current_entity_id)

    def _remove_connection(self):
        selection = self.connections_listbox.curselection()
        if not selection:
            return
        relationship_id = self._connection_ids_by_row[selection[0]]
        self.dataset["relationships"] = [
            r for r in self.dataset["relationships"] if r["id"] != relationship_id
        ]
        self._load_entity(self.current_entity_id)

    # -- sources ----------------------------------------------------------------
    def _add_existing_source(self):
        available = [s for s in self.dataset["sources"] if s["id"] not in self.current_sources]
        if not available:
            messagebox.showinfo("No sources", "No other existing sources to add. Create a new one instead.")
            return
        picker = tk.Toplevel(self)
        picker.title("Add Existing Source")
        labels = [f"{s.get('title', s['id'])} ({s['id']})" for s in available]
        chosen = tk.StringVar(value=labels[0])
        ttk.Combobox(picker, textvariable=chosen, values=labels, width=50, state="readonly").pack(padx=8, pady=8)

        def confirm():
            index = labels.index(chosen.get())
            self.current_sources.add(available[index]["id"])
            self._refresh_sources_listbox()
            picker.destroy()

        tk.Button(picker, text="Add", command=confirm).pack(pady=(0, 8))
        picker.transient(self)
        picker.grab_set()

    def _add_new_source(self):
        dialog = NewSourceDialog(self)
        self.wait_window(dialog)
        if not dialog.result:
            return
        values = dialog.result
        source_id = unique_id(slugify(values["title"]), all_ids(self.dataset))
        source = {"id": source_id, **values}
        self.dataset["sources"].append(source)
        self.current_sources.add(source_id)
        self._refresh_sources_listbox()

    def _remove_source(self):
        selection = self.sources_listbox.curselection()
        if not selection:
            return
        if len(self.current_sources) <= 1:
            messagebox.showerror("At least one source required", "Every entry needs at least one source.")
            return
        source_id = self._source_ids_by_row[selection[0]]
        self.current_sources.discard(source_id)
        self._refresh_sources_listbox()

    # -- save ---------------------------------------------------------------------
    def _save_entity(self):
        name = self.name_var.get().strip()
        if not name:
            messagebox.showerror("Missing name", "Enter a name before saving.")
            return

        has_text = any(
            widget.get("1.0", tk.END).strip() for widget in (self.quick_text, self.story_text, self.deep_text)
        )
        if has_text and not self.current_sources:
            messagebox.showerror("Missing source", "Add at least one source before saving lore text.")
            return

        if self.current_entity_id is None:
            entity_id = unique_id(slugify(name), all_ids(self.dataset))
            entity = {"id": entity_id, "name": name, "type": self.type_var.get()}
            self.dataset["entities"].append(entity)
            self.current_entity_id = entity_id
        else:
            entity_id = self.current_entity_id
            entity = self._find_entity(entity_id)
            entity["name"] = name
            entity["type"] = self.type_var.get()

        entity["status"] = self.entity_status_var.get()
        aliases = [a.strip() for a in self.aliases_var.get().split(",") if a.strip()]
        if aliases:
            entity["aliases"] = aliases
        elif "aliases" in entity:
            del entity["aliases"]
        summary = self.summary_var.get().strip()
        if summary:
            entity["summary"] = summary
        elif "summary" in entity:
            del entity["summary"]

        for level, widget in (("quick", self.quick_text), ("story", self.story_text), ("deep", self.deep_text)):
            text = widget.get("1.0", tk.END).strip()
            existing = next(
                (s for s in self.dataset["statements"] if s.get("entityId") == entity_id and s.get("detailLevel") == level),
                None,
            )
            if not text:
                continue
            if existing:
                existing["text"] = text
                existing["canonStatus"] = self.canon_var.get()
                existing["epistemicStatus"] = self.epistemic_var.get()
                existing["sourceIds"] = sorted(self.current_sources)
            else:
                statement_id = unique_id(f"{entity_id}_{level}", all_ids(self.dataset))
                self.dataset["statements"].append(
                    {
                        "id": statement_id,
                        "entityId": entity_id,
                        "detailLevel": level,
                        "text": text,
                        "canonStatus": self.canon_var.get(),
                        "epistemicStatus": self.epistemic_var.get(),
                        "sourceIds": sorted(self.current_sources),
                    }
                )

        with self.dataset_path.open("w", encoding="utf-8") as handle:
            json.dump(self.dataset, handle, indent=2, ensure_ascii=False)
            handle.write("\n")

        self._refresh_entity_list()
        self._validate_and_report()

    def _validate_and_report(self):
        report = vld.validate_dataset(self.dataset_path, self.vocabulary)
        if report["errors"]:
            self.result_label.config(
                fg="#c62828", text="Saved with errors:\n" + "\n".join(report["errors"][:5])
            )
        else:
            warning_text = f" ({len(report['warnings'])} warning(s))" if report["warnings"] else ""
            self.result_label.config(fg="#2e7d32", text=f"Saved and valid{warning_text}.")


def main(argv=None):
    parser = argparse.ArgumentParser(description="LoreBuddy authoring GUI")
    parser.add_argument("dataset", nargs="?", type=Path, default=DEFAULT_DATASET, help="dataset file to edit")
    args = parser.parse_args(argv)
    app = AuthorApp(args.dataset)
    app.mainloop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
