# TBC Anniversary Compatibility

LoreBuddy targets the Burning Crusade Classic Anniversary Edition only for its
initial addon release.

## Current Status

- Client flavor: TBC Classic Anniversary
- Game type: `tbc`
- Expected patch family: 2.5.5 / 2.5.6
- Verified TOC interface: `20506`
- Verification status: verified on 2026-08-13
- Verified client build: `2.5.6` (`69110`), build date `Aug 3 2026`, locale `enUS`, region `1`

The TOC interface value has been verified in an installed TBC Anniversary
client and is ready for release and CurseForge packaging.

Run this in the TBC Anniversary client:

```text
/dump select(1, GetBuildInfo()), select(2, GetBuildInfo()), select(3, GetBuildInfo()), select(4, GetBuildInfo()), GetLocale(), GetCurrentRegion()
```

Most recent verification output (2026-08-13):

```text
[1]="2.5.6"
[2]="69110"
[3]="Aug 3 2026"
[4]=20506
[5]="enUS"
[6]=1
```

The client-provided interface number is authoritative over web posts or a
different client installation.

## Packaging

The repository keeps `core/` and `addon/` separate so the lore engine remains
client-neutral. WoW cannot load sibling repository directories from a TOC file,
so assemble an installable addon with:

```sh
./tools/package_tbc_addon.sh
```

The generated `build/LoreBuddy/` directory contains the TBC TOC and copied
`Core/` and `Addon/` files. The build output is local packaging output and is
ignored by Git.

## Sources

- [Warcraft Wiki TOC format](https://warcraft.wiki.gg/wiki/TOC_format)
- [Gethe WoW UI source](https://github.com/Gethe/wow-ui-source)
- [World of Warcraft API](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API)

The Gethe mirror is a git mirror of Blizzard's shipped FrameXML/Lua UI source.
Use it to confirm whether a global or namespaced API (for example,
`C_Map.GetBestMapForUnit`) actually exists for the target client build before
relying on editor linting alone.

This document records compatibility evidence only. It does not grant rights to
Blizzard software, UI source, lore, artwork, or trademarks.
