# TBC Anniversary Compatibility

LoreBuddy targets the Burning Crusade Classic Anniversary Edition only for its
initial addon release.

## Current Status

- Client flavor: TBC Classic Anniversary
- Game type: `tbc`
- Expected patch family: 2.5.5 / 2.5.6
- Provisional TOC interface: `20506`
- Verification status: pending main-PC client verification

The current laptop does not have WoW TBC installed. The provisional value must
be verified in the installed client before release or CurseForge packaging.

Run this in the TBC Anniversary client:

```text
/dump select(1, GetBuildInfo()), select(2, GetBuildInfo()), select(3, GetBuildInfo()), select(4, GetBuildInfo()), GetLocale(), GetCurrentRegion()
```

Record the output here, along with the verification date, before treating the
TOC value as final. The client-provided interface number is authoritative over
web posts or a different client installation.

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

This document records compatibility evidence only. It does not grant rights to
Blizzard software, UI source, lore, artwork, or trademarks.
