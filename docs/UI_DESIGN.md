# LoreBuddy UI Design

This documents the proposed layout, component hierarchy, and non-invasive
rules for the WoW addon's presentation layer, per the UI design brief. It is
written before implementation, as required by that brief. Only the "First UI
Milestone" section below is implemented now; everything else describes the
target design for later milestones.

## Design Philosophy

Old adventurer's journal + magical field guide, not a fantasy website or a
modern flat-UI addon. Parchment, antique gold, deep purple/violet, dark
carved wood/charcoal. Gold for borders/headings/important actions; purple for
lore/magic/branding; parchment for readable body text. No bright white
backgrounds, no neon, no giant popups, no constant animation.

## Non-Invasive Rules

LoreBuddy must never take over the screen or interrupt play:

- **No forced center-screen windows.** The main popup defaults to a screen
  corner and avoids action bars, unit frames, the minimap, and the quest
  tracker unless the player explicitly repositions it.
- **Everything is draggable and its position is remembered** per character.
- **Combat suppresses everything except a tiny indicator.** Normal popups are
  queued while `PLAYER_REGEN_DISABLED` is active and released as a single
  "Lore Buddy found something interesting" prompt after `PLAYER_REGEN_ENABLED`.
- **Tempt, don't lecture.** Default popups are 1-3 sentences with a "tell me
  more" action, not the full deep-lore text.
- **The player can turn off any layer** (notifications, NPC/quest/item
  indicators, animations) independently.
- **UI never hardcodes lore data.** Every component reads from `LoreEngine`;
  none of them own lore text.

## Component Hierarchy

```
LoreBuddyTheme          -- shared colors/fonts/backdrop helpers (no UI of its own)
LoreBuddyIndicator       -- tiny persistent draggable medallion icon
LoreBuddyPopup           -- the contextual card ("Did you know...", NEW LORE DISCOVERED, etc.)
LoreBuddyJournal         -- the expanded book-style window (search, Encyclopedia, Deep Dive, Lore Book)
LoreBuddySettings        -- basic settings panel opened from the Journal
LoreBuddyNotification    -- (future) tiny top-center 3-5s auto-dismiss toast
LoreBuddyTooltip         -- (future) NPC/item/quest lore indicators + hover previews
LoreBuddyTimeline        -- (future) "My Journey" personal timeline tab
LoreBuddyMap             -- (future) optional interactive lore map
LoreBuddySearch          -- (present today as part of LoreBuddyJournal; may split out later)
```

Every component is a presentation-only consumer of `LoreEngine`
(`core/LoreEngine.lua`); none of them contain lore content or game-rule logic.

## Layout (First Milestone)

**Indicator:** a small circular medallion using the existing mascot portrait
(`assets/logo/lorebuddy-portrait.png`, packaged as `addon/Media/portrait.tga`),
anchored to a screen edge by default, draggable, with a brief glow/pulse when
new lore is queued.

**Popup:** a parchment card, gold border, purple header cloth, mascot
portrait thumbnail, 1-3 sentence body, optional "Connected to X" line, and
`[ READ MORE ] [ LATER ] [ CLOSE ]` actions. Replaces the earlier plain
`LorePopup`/`DiscoveryToast` styling with the themed version described here
(the underlying behavior from Phase 15 -- Read opens the Journal, Later
records a dismissed hint -- is unchanged).

**Journal:** the existing search/Encyclopedia/Deep Dive/Lore Book window,
reskinned with the parchment/gold/purple theme instead of default Blizzard
frame colors, plus a settings entry point.

## WoW API Mapping

- **Frames**: Journal, Popup, Indicator, Settings panel.
- **FontStrings**: lore text, headers, names, source lines.
- **Buttons**: Read More / Later / Close, tabs, navigation, settings controls.
- **Textures**: parchment background, gold border art, mascot portrait,
  purple glow accent.
- **Backdrop** (`BackdropTemplate`): panel framing for Popup/Journal/Indicator.
  TBC Anniversary runs on the modern client engine (confirmed in
  [TBC_ANNIVERSARY_COMPATIBILITY.md](TBC_ANNIVERSARY_COMPATIBILITY.md)), so
  `BackdropTemplate` is the correct mixin rather than the legacy `frame:SetBackdrop`
  path some older Classic-only code uses.
- **ScrollFrames**: deferred; not needed until the Timeline/longer Deep Dive
  content in a later milestone.
- **Tooltips**: deferred to the NPC/item/quest indicator milestone.

Do not copy Retail-only widget templates or examples wholesale. Verify each
template/API actually exists on the installed TBC Anniversary client (per the
existing compatibility-verification workflow) before relying on it; community
reference projects such as `pfUI` (Vanilla/TBC-era addon) and the historic
`wow-ui-source` mirrors are useful only to understand *how a Classic/TBC-era
interface is structured*, not as code to copy into this addon.

## Compatibility Findings (Pre-Implementation Check)

I cannot launch the actual TBC Anniversary client from this environment, so
this is a documented-basis check, not a live one -- confirm it for real via
`/lorebuddy test` (see Test Chamber below) before treating it as final, the
same way the client interface number itself was verified in
[TBC_ANNIVERSARY_COMPATIBILITY.md](TBC_ANNIVERSARY_COMPATIBILITY.md).

| Element | Template/API used | Basis |
|---|---|---|
| Panel framing | `BackdropTemplate` mixin, `frame:SetBackdrop` | Standard on the unified modern client engine (confirmed TBC Anniversary build 2.5.6 runs on this engine); this is the correct mixin path, not the legacy pre-Legion backdrop API some older Classic-only guides show. |
| Buttons | `UIPanelButtonTemplate`, `UIPanelCloseButton` | Present in Blizzard FrameXML since Vanilla and unchanged across every Classic-family branch (per `Gethe/wow-ui-source`). |
| Checkbox | `UICheckButtonTemplate` | Same as above; long-standing, unchanged. |
| Text input | `InputBoxTemplate` | Same as above. |
| Fonts | `GameFontNormal`, `GameFontNormalLarge`, `GameFontHighlightSmall` | Standard shared font objects defined in every Blizzard UI branch. |
| Scrollable content | `UIPanelScrollFrameTemplate` (real `ScrollFrame`, not a fixed FontString) | Long-standing shared template; used here for the Journal's long-form lore text so it scrolls instead of clipping. |
| Fade | `UIFrameFadeIn`/`UIFrameFadeOut` | Shared utility functions bundled with FrameXML; code falls back to an instant show/hide if unavailable. |
| Textures | Direct `Texture:SetTexture()` on a packaged PNG under `addon/Media/` | Needs live confirmation -- the unified modern engine added PNG support, but if the installed client rejects it, convert `addon/Media/portrait.png` to `.tga` and update the one texture path in `LoreBuddyIndicator.lua`/`LoreBuddyPopup.lua`. |

None of these are Retail-only or Dragonflight/War Within-era APIs (e.g. no
`NineSliceUtil`, no Edit Mode, no modern Settings API); everything listed has
existed since Vanilla/TBC FrameXML and is still present in the unified engine.

## Test Chamber

`/lorebuddy test` opens `LoreBuddyTestChamber`, a small panel of buttons that
manually trigger each UI surface with synthetic data, so the UI can be
iterated on while standing still (e.g. in Stormwind) instead of hunting for
real triggers in Outland. First-milestone buttons: Test Popup, Test New
Character, Test New Location, Test Connection Discovery, Test Journal, Test
Long Lore (Deep Dive), Test Combat Queue, Reset Positions. Buttons for
components that don't exist yet (Tooltip, Quest Lore indicator) are
intentionally omitted rather than added as inert placeholders.

## Performance Rules

- No `OnUpdate` polling; every trigger is a real WoW event (`PLAYER_TARGET_CHANGED`,
  `ZONE_CHANGED_NEW_AREA`, `QUEST_ACCEPTED`, `QUEST_TURNED_IN`,
  `PLAYER_REGEN_DISABLED`/`ENABLED`).
- Frames are created once at load and reused (shown/hidden), never recreated
  per event.

## First UI Milestone (implemented now)

1. `LoreBuddyIndicator` -- floating draggable medallion, position persisted.
2. `LoreBuddyPopup` -- themed contextual popup (Read More / Later / Close).
3. `LoreBuddyJournal` -- themed expanded journal (existing Encyclopedia/Deep
   Dive/Lore Book, reskinned).
4. `LoreBuddySettings` -- basic panel: verbosity, spoiler level, combat
   suppression toggle, mascot enable toggle.
5. One mascot portrait (`assets/logo/lorebuddy-portrait.png`).
6. Open/close fade animation (short, via `UIFrameFadeIn`/`UIFrameFadeOut` when
   available, otherwise a minimal manual alpha tween).
7. Drag-and-position support, persisted per character.
8. Combat suppression (queue during combat, single prompt after).
9. One test lore entry (existing dataset content; no new data needed).
10. Discovery notification (satisfied by `LoreBuddyPopup`'s "NEW LORE
    DISCOVERED" card; the separate tiny 3-5s auto-dismiss toast from the
    design brief's section 10 is deferred to a later milestone to avoid
    building two near-duplicate widgets in the same pass).

Everything else in the design brief (Tooltip indicators, Timeline, Map,
sound design, full verbosity/spoiler settings matrix, accessibility options)
is intentionally deferred to later milestones.
