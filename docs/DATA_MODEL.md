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

Every entity may optionally carry:

- `eraId`: a reference into [eras.json](../database/entries/eras.json) (see
  Eras And Chronology below). Omit if not yet classified; never guess.
- `loreRelevance`: `core`, `important`, `supporting`, `flavor`, `comedic`, or
  `unknown` (default). This is how central the entity is to the major story,
  not how much has been written about it yet.
- `priority`: `p0`–`p4`, an authoring priority (see Priority System below).
  It guides what to research next; it has no runtime effect.
- `chronology`: see Eras And Chronology below.

## Eras And Chronology

Lore is grouped into chronological eras, defined as **data**, not code, in
[eras.json](../database/entries/eras.json): Ancient/Foundational History, War
of the Ancients, First War, Second War, Third War, The Fall of Lordaeron, The
Frozen Throne, Classic, The Dark Portal Reopens, and The Burning Crusade. Each
era has an `id`, a `name`, and a sort `order` (not a literal year). Adding
Wrath, Cataclysm, or any later era is a one-line addition to that file; nothing
in the engine hard-codes Classic or TBC specifically.

An entity's optional `chronology` object never fabricates dates:

```json
"chronology": {
  "absolute": "unknown",
  "relative": "Long before the First War.",
  "beforeEventIds": ["some_event_id"],
  "afterEventIds": [],
  "notes": "Optional free-text clarification."
}
```

Use the literal string `"unknown"` for `absolute`/`relative` when a precise
placement isn't established. `beforeEventIds`/`afterEventIds` reference other
entity IDs (typically `event` entities) to express relative ordering without
inventing a calendar.

## Priority System

Authoring work is prioritized, not attempted all at once:

- `p0`: essential lore.
- `p1`: major story.
- `p2`: important worldbuilding.
- `p3`: supporting lore.
- `p4`: flavor / completionist lore.

The first complete playable build should prioritize `p0` and `p1`. See
Coverage Tracking below for how priority feeds the "what's missing" report.

## Relationships

Relationships are first-class records with a subject, controlled predicate,
object, source IDs, and optional uncertainty or discovery metadata. The machine-
readable vocabulary is in [relationship-vocabulary.json](../database/relationship-vocabulary.json).

Predicates such as `located_at`, `participated_in`, `created`, `contains`,
`appears_in`, `parent_of`, `member_of`, `rules`, `led_by`, `part_of`, and
`supports` are directional. Predicates such as `related_to`, `allied_with`,
`enemy_of`, `associated_with`, `sibling_of`, `loved`, and `opposes` are
symmetric; an importer may materialize both directions if querying requires
it, but authors record one canonical relationship.

A few testplan phrasings map onto existing predicates rather than duplicating
them: "LOCATED_IN" → `located_at`; "CONNECTED_TO" → `associated_with"`;
"LEADS" → record the reverse relationship as `led_by` instead of adding a
separate forward predicate.

The vocabulary (and its directional/symmetric flags) is baked into
`core/GeneratedVocabulary.lua` by `tools/generate_lua_dataset.py`, so
`ValidationEngine` and `RelationshipManager` read predicate validity and
symmetry from data at runtime instead of a hard-coded Lua table -- adding a
new predicate to the JSON file is enough; no engine code changes are needed.

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

A source may optionally declare `confidence` (`confirmed`,
`strongly_supported`, `uncertain`, `conflicting`, or `speculation`) -- a second,
independent axis from `classification`. A primary source can still be
`conflicting` if it contradicts a later, more authoritative primary source.

### Contradictions And Retcons

Warcraft lore contains retcons and conflicting accounts. Never silently
overwrite a conflicting statement or source. Instead:

- Keep both statements/sources on file.
- Use `canonStatus: disputed` or `unknown` where appropriate.
- Use `epistemicStatus: interpretation`/`theory`/`speculation` for the less
  certain account.
- Add a `retconNotes` string to the superseded source explaining what changed
  and why both records remain.

See `sample_src_conflicting_retcon` and `sample_illidan_stormrage_disputed_motive`
in [architecture-sample-illidan-dataset.json](../database/entries/architecture-sample-illidan-dataset.json)
for a worked (placeholder) example.

## Lore Entry Levels

A `LoreStatement` is a "lore entry" for a given entity at a given detail
level: `micro` (one sentence), `quick` (15-30 seconds), `story` (1-2 minutes),
`deep` (several minutes), or `reference` (structured factual information, not
prose). The player always controls which level they see; `deep` content may
additionally be gated by discovery (see below).

## Spoiler System

Every statement may declare a `spoilerLevel`: `safe`, `context`, `reveal`,
`major_reveal`, or `ending` (default `safe` when omitted -- omission means no
spoiler risk, not "unclassified"). Player state carries a `spoilerPreference`:
`no_spoilers`, `context_only`, `moderate` (default), `full_lore`, or
`show_everything`.

`DiscoveryManager:isVisible(statement)` combines two independent checks with
AND logic:

1. Every `discoveryGateIds` entry on the statement must already be unlocked
   (existing milestone-gating mechanism).
2. The statement's `spoilerLevel` rank must be at or below the player's
   configured `spoilerPreference` rank.

A statement can therefore be spoiler-gated, milestone-gated, both, or
neither. LoreBuddy never spoils future content merely because it exists in
the database -- both mechanisms must independently allow it.

## Discovery And Offline State

Discovery gates describe the minimum milestone needed before showing detail.
They may be tied to a quest, event, zone, achievement, encounter, or manual
confirmation while addon detection is still being developed.

Player discovery state is local and separate from packaged lore. It may be
absent, reset, or incomplete without invalidating the canonical dataset. The
core addon must use local packaged data when no network is available.

Player memory tracks what a player has already encountered, split by category:
`discoveredCharacters`, `discoveredLocations`, `discoveredEvents`,
`discoveredFactions`, `discoveredDungeons`, `discoveredRaids`,
`discoveredBooks`, `discoveredItems`, plus `completedQuestChainIds` and
`seenLore` (statement IDs). It powers messages such as "You've encountered
this character before." and lives in the same per-character save data as
discovery gates and spoiler preference.

WoW addons cannot parse JSON at runtime, so `core/GeneratedDataset.lua` and
`core/GeneratedVocabulary.lua` are committed, generated Lua tables built from
every `database/entries/*-dataset.json` file and
`database/relationship-vocabulary.json`, respectively. Run
`tools/generate_lua_dataset.py` after editing any dataset or the vocabulary;
the packaging script also regenerates them automatically when Python is
available.

## Coverage Tracking

[database/entries/coverage-plan.json](../database/entries/coverage-plan.json)
is a checklist, not lore content: each entry is just `{id, name, category,
era, priority}` for something LoreBuddy should eventually cover (Classic
continents/zones/dungeons/raids/factions/characters, and TBC
zones/factions/dungeons/raids, seeded directly from the project's coverage
plan). It intentionally does not attempt to enumerate every quest.

Run the dashboard:

```sh
python tools/coverage_report.py
python tools/coverage_report.py --missing   # also list what's missing, by priority
```

An entry is `complete` once the real dataset has both a `quick` and a `story`
statement for that ID, `partial` if the entity exists with fewer statements,
and `missing` if the ID doesn't exist in any authored dataset yet. The report
never fails the build -- it exists purely so contributors can see what to
research next, broken down by category and by era.

## Architecture Layering

```
Lore Database (JSON, database/)
        \u2193
Lore Engine (core/*.lua)
        \u2193
Context Engine (core/ContextEngine.lua, LoreEngine:evaluateContext)
        \u2193
Presentation Layer (WoW addon, desktop Explorer, future web/AI clients)
```

The lore database and engine are presentation-agnostic. The WoW addon is one
presentation layer among several already built: the desktop
[Lore Explorer](../tools/lorebuddy_explorer.py) and
[Author](../tools/lorebuddy_author.py) tools consume the same JSON directly,
without WoW. A future web viewer or optional AI companion would sit at the
same layer as the addon, calling the same engine contract.

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

Run the data-model test suite (tests the validator's own behavior against
small fixtures, independent of real content) with:

```sh
python -m unittest tools.test_data_model
```

Do not add bulk Warcraft lore entries until the schema and source/licensing
workflow have been reviewed.