# Lore Engine

The `core/` modules are LoreBuddy's offline brain. They consume a validated,
packaged dataset and local discovery state. They do not call the Blizzard API,
require an internet connection, invoke AI, or author canonical lore.

## Module Responsibilities

- `LoreEngine`: public orchestration API for addon features.
- `EntityManager`: stable entity indexing and name/alias lookup.
- `RelationshipManager`: directional and symmetric relationship traversal.
- `SourceManager`: provenance lookup and authority ordering.
- `SearchEngine`: entity and statement search with discovery filtering.
- `ContextEngine`: contextual statement retrieval from zone, NPC, quest, event,
  location, entity, and tag context.
- `DiscoveryManager`: local gates, seen statements, and spoiler visibility.
- `PlayerMemory`: per-character memory of encountered characters, locations,
  events, and factions, and which lore has been seen.
- `ValidationEngine`: runtime reference checks before the engine is constructed.

## Public Queries

The addon should call `LoreEngine` rather than coupling UI code to individual
managers:

```lua
local engine = LoreBuddyCore.LoreEngine.new(dataset, playerDiscoveryState)

local characters = engine:findCharacter("Illidan")
local lore = engine:findLoreAbout("Black Temple")
local connections = engine:findConnections("Illidan")
local contextualLore = engine:findRelevantLore({ zoneId = "shadowmoon_valley" })
local akamaLore = engine:findRelevantLore({ npcId = "akama" })
local discovered = engine:hasPlayerDiscovered("Illidan")
local encounter = engine:rememberEntity("illidan_stormrage")
-- encounter.message is "You've encountered this character before." on repeat visits.

local decision = engine:evaluateContext({ zoneId = "black_temple" })
-- decision.suggestions lists entities connected to the current context (up to
-- two relationship hops by default) that the player has not yet encountered,
-- each with a reason, the connecting relationship, and a quick introduction
-- statement -- e.g. "Akama" reachable via Illidan even though the player is
-- only standing in Black Temple.
```

Results include the entity, statement or relationship, and source records where
applicable. Source classification remains available to the eventual UI so
primary, secondary, community, and speculative material are not presented as
equally authoritative.

## Spoiler Behavior

Statements with unsatisfied discovery gates are hidden by default. An explicit
player request may pass `{ allowSpoilers = true }` to a lore query, but ordinary
contextual display should not do so. The engine does not infer that a player has
discovered an entity merely because a search matched its name; discovery comes
from local state or an explicit game signal.

## Offline Boundary

The engine accepts data. It does not fetch data. Blizzard API imports, source
refreshes, and AI explanations belong outside `core/` and must produce validated
records before they are packaged or made available to the engine.