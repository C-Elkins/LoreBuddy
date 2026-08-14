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
its publisher, title, kind, authority classification, reference, attribution,
license or usage note, and verification status. A source may also include a URL.
Blizzard API metadata can additionally record namespace, region, locale, and
retrieval time.

`classification` is deliberately separate from `kind`:

- `primary`: official Blizzard or in-game material.
- `secondary`: reputable references such as Warcraft Wiki or Wowhead.
- `community`: forums, Reddit, and user discussions.
- `speculation`: theory or interpretation that is not established canon.

These classifications express authority, not whether a source is useful. A
secondary source can help locate a primary source, while a community source can
provide context without becoming authoritative. Statements still carry their
own `canonStatus` and `epistemicStatus`; a speculative source must not be
rendered as confirmed fact.

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

Player memory tracks which characters, locations, events, and factions a
player has already encountered (`discoveredCharacters`, `discoveredLocations`,
`discoveredEvents`, `discoveredFactions`) plus which statements they have seen
(`seenLore`). It powers messages such as "You've encountered this character
before." and lives in the same per-character save data as discovery gates.

## Validation

Run the offline validator from the repository root:

```sh
./tools/validate_lore_data.py
```

The validator checks stable IDs, required provenance, entity references,
relationship predicates, discovery-gate references, invalid source types, and
orphaned entities. It intentionally has no network or Blizzard credential
dependency. The repository command is:

```sh
./LoreBuddy validate
```

Errors make the database invalid and return a non-zero exit code. Warnings, such
as an entry without a secondary source, are reported without blocking a valid
database.

Do not add bulk Warcraft lore entries until the schema and source/licensing
workflow have been reviewed.