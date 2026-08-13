# LoreBuddy Data Model

This is the contract for lore data before UI work begins. It is designed to
support the project philosophy: contextual delivery, player control, spoiler
boundaries, remembered discovery, explicit uncertainty, provenance, offline
operation, and optional AI.

## Entities And Statements

An entity answers **what is this?** It provides stable identity only: an ID,
name, type, aliases, summary metadata, and game-version scope.

A `LoreStatement` answers **what do we say about it?** Statements are separate
so each claim can have its own detail level, source, canon status, epistemic
status, and discovery gate. `quick`, `story`, and `deep` are presentation levels,
not three unsourced fields on an entity.

Initial entity types are `character`, `location`, `faction`, `event`, `item`,
`quest`, `creature`, `organization`, `concept`, `book`, `dialogue`, `dungeon`,
`raid`, and `zone`.

## Relationships

Relationships are first-class records with a subject, controlled predicate,
object, source IDs, and optional uncertainty or discovery metadata. The machine-
readable vocabulary is in [relationship-vocabulary.json](../database/relationship-vocabulary.json).

Predicates such as `located_at` and `participated_in` are directional. Predicates
such as `related_to`, `allied_with`, `enemy_of`, and `associated_with` are
symmetric concepts; an importer may materialize both directions if querying
requires it, but authors record one canonical relationship.

## Provenance And Uncertainty

Statements and relationships require at least one source ID. A source records
its kind, reference, attribution, license or usage note, and verification status.
Blizzard API metadata can additionally record namespace, region, locale, and
retrieval time.

`canonStatus` and `epistemicStatus` are intentionally separate. A confirmed
source can support an interpretation without turning that interpretation into a
confirmed fact.

## Discovery And Offline State

Discovery gates describe the minimum milestone needed before showing detail.
They may be tied to a quest, event, zone, achievement, encounter, or manual
confirmation while addon detection is still being developed.

Player discovery state is local and separate from packaged lore. It may be
absent, reset, or incomplete without invalidating the canonical dataset. The
core addon must use local packaged data when no network is available.

## Validation

Run the offline validator from the repository root:

```sh
./tools/validate_lore_data.py
```

The validator checks stable IDs, required provenance, entity references,
relationship predicates, and discovery-gate references. It intentionally has no
network or Blizzard credential dependency.

Do not add bulk Warcraft lore entries until the schema and source/licensing
workflow have been reviewed.