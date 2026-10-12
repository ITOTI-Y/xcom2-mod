# xcom2-mod

English | [简体中文](README.zh-CN.md)

Script mods for XCOM 2: War of the Chosen. Each mod lives in its own folder with its UnrealScript source, configuration, the compiled script, and the scripts that build and publish it.

| Mod | Purpose |
|---|---|
| [x2locWeaponCatNames](x2locWeaponCatNames) | Replaces the internal codes of mod weapon categories in the "valid weapons" line of ability descriptions with localized names |

## x2locWeaponCatNames

[WOTCMusashiModFixes](https://steamcommunity.com/sharedfiles/filedetails/?id=2569592723) appends a "valid weapons" line to ability descriptions, in which weapon categories added by mods appear as internal codes such as `combatknife`. This mod replaces each code with the localized name of the category's own weapons, in the language the game runs in. It requires War of the Chosen, [X2WOTCCommunityHighlander](https://steamcommunity.com/sharedfiles/filedetails/?id=1134256495), and WOTCMusashiModFixes.

The scripts run with [uv](https://docs.astral.sh/uv/), which installs their only dependency, Typer, on first use:

```bash
uv run x2locWeaponCatNames/build.py --sdk <WOTC SDK> --mods-dir <XComGame/Mods>
uv run x2locWeaponCatNames/publish.py --steamcmd <steamcmd.exe> --username <Steam account>
```

`build.py` compiles the mod with the War of the Chosen SDK, keeps the compiled script in `Script/`, and installs the mod into the game. `publish.py` uploads it to the Steam Workshop with [SteamCMD](https://developer.valvesoftware.com/wiki/SteamCMD), taking the description from `workshop/description.bbcode` and the preview from `ModPreview.jpg`. SteamCMD asks for the password and the Steam Guard code itself. The first upload creates a hidden item and records its id in `workshop/publishedfileid`; later uploads update the same item. Tags and required items are set on the item's Workshop page, since SteamCMD cannot set them.

## License

MIT
