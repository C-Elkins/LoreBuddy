# LoreBuddy Source System

Every statement and relationship in LoreBuddy references one or more source
records. Sources are provenance records, not just citation strings.

## Source Record

A source includes:

- `id`: stable internal identifier.
- `publisher`: the organization, game, or contributor responsible for the source.
- `title`: human-readable title.
- `kind`: the material's technical origin, such as `blizzard_api`, `quest_text`,
  `npc_dialogue`, `book`, `external_reference`, or `community_contribution`.
- `classification`: authority level: `primary`, `secondary`, `community`, or
  `speculation`.
- `reference`: stable local or external reference.
- `url`: optional canonical web URL when one exists.
- `attribution` and `license`: required rights and credit information.
- `verificationStatus`: `unverified`, `reviewed`, or `verified`.

Blizzard API sources should also record namespace, region, locale, and retrieval
time. API data is source material for optional enrichment, not a replacement for
the offline canonical dataset.

## Authority Classes

### Primary

Official Blizzard or in-game material, including game text, quests, NPC dialogue,
books, and official API data. Primary does not mean every interpretation of the
material is automatically a fact; the statement still needs its own epistemic
status.

### Secondary

Reputable reference works such as Warcraft Wiki, Wowhead, and other documented
reference projects. Secondary sources can summarize or point to primary material,
but they should not silently override it.

### Community

Forums, Reddit, user discussions, and community-maintained commentary. These can
provide leads, context, and player perspectives, but they are not equivalent to
official or well-sourced reference material.

### Speculation

Theory, interpretation, and other claims that are not established canon. Use this
classification when the source itself is speculative. Mark the associated
statement's `epistemicStatus` as `interpretation`, `theory`, or `speculation` as
appropriate.

## Rendering Rule

The source classification must remain visible to authoring and review tools and
available to the eventual player-facing explanation. LoreBuddy should never
present a community or speculative source with the same authority signal as
primary material. A statement's certainty is determined by both its source set
and its own canon/epistemic fields; AI-generated text cannot raise either value.