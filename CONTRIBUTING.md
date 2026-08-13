# Contributing

Thanks for contributing to LoreBuddy.

## Before You Start

Read [Project Philosophy](docs/PROJECT_PHILOSOPHY.md), [Data Model](docs/DATA_MODEL.md),
and [Source System](docs/SOURCE_SYSTEM.md) before proposing data or schema changes.
LoreBuddy is designed to provide contextual, optional, spoiler-aware lore while
keeping the core addon useful offline.

## Philosophy Review

Before coding, explain how the proposed change supports the relevant philosophy
principles. During implementation and review, check that it:

- Adds context without overwhelming the player.
- Keeps lore optional and respects the player's discovery history.
- Avoids unnecessary spoilers and distinguishes fact from interpretation.
- Preserves provenance for every lore entry or external source.
- Keeps the core addon functional without an internet connection.
- Treats AI as an optional explanation layer, never as the source of truth.

Record any deliberate tradeoff in the issue or pull request description.

## What to Contribute

- Code, tests, and documentation that improve the core experience.
- Lore data with clear provenance, attribution, and licensing information.
- Bug reports and focused feature proposals that respect player control and
	spoiler boundaries.

Do not submit third-party lore, artwork, trademarks, or other content unless
you have confirmed that its use is permitted. The MIT License covers LoreBuddy
software; it does not automatically cover third-party lore or source material.

## Development Workflow

1. Open an issue or comment on an existing issue for substantial changes.
2. Create a focused branch from `main`.
3. Keep changes small and explain the user-facing or technical reason for them.
4. Add or update tests and documentation when behavior changes.
5. Run the relevant checks locally before opening a pull request.
6. Open a pull request with a clear summary, testing notes, and any source or
	 attribution details.

## Lore Data Expectations

Every lore entry should identify its source and distinguish established facts
from interpretation or theory. New content should avoid unnecessary spoilers,
respect the player's discovery history, and work with the offline core design.

## Pull Requests

Pull requests should be focused, clearly described, and ready for review. Be
open to feedback about accuracy, sourcing, accessibility, performance, and the
player's control over how much lore is shown.

## Questions

For questions or uncertain licensing and attribution cases, open an issue
before adding the material.
