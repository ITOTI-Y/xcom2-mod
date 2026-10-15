# xcom2-mod

English | [简体中文](README.zh-CN.md)

Script mods for XCOM 2: War of the Chosen. Each mod lives in its own folder with its UnrealScript source, configuration, the compiled script, and the scripts that build and publish it.

| Mod | Purpose |
|---|---|
| [x2locWeaponCatNames](x2locWeaponCatNames) | Replaces the internal codes of mod weapon categories in the "valid weapons" line of ability descriptions with localized names |
| [UniversalSoldierLW](UniversalSoldierLW) | Lets every new soldier choose specializations from the ability columns of all soldier classes, and buy stat upgrades with ability points |
| [CommandsUI](CommandsUI) | Opens a menu of console commands with a hotkey, so commands run with a click instead of being typed |

## x2locWeaponCatNames

[WOTCMusashiModFixes](https://steamcommunity.com/sharedfiles/filedetails/?id=2569592723) appends a "valid weapons" line to ability descriptions, in which weapon categories added by mods appear as internal codes such as `combatknife`. This mod replaces each code with the localized name of the category's own weapons, in the language the game runs in. It requires War of the Chosen, [X2WOTCCommunityHighlander](https://steamcommunity.com/sharedfiles/filedetails/?id=1134256495), and WOTCMusashiModFixes.

The scripts run with [uv](https://docs.astral.sh/uv/), which installs their only dependency, Typer, on first use:

```bash
uv run x2locWeaponCatNames/build.py --sdk <WOTC SDK> --mods-dir <XComGame/Mods>
uv run x2locWeaponCatNames/publish.py --steamcmd <steamcmd.exe> --username <Steam account>
```

`build.py` compiles the mod with the War of the Chosen SDK, keeps the compiled script in `Script/`, and installs the mod into the game. `publish.py` uploads it to the Steam Workshop with [SteamCMD](https://developer.valvesoftware.com/wiki/SteamCMD), taking the description from `workshop/description.bbcode` and the preview from `ModPreview.jpg`. SteamCMD asks for the password and the Steam Guard code itself. The first upload creates a hidden item and records its id in `workshop/publishedfileid`; later uploads update the same item. Tags and required items are set on the item's Workshop page, since SteamCMD cannot set them.

## UniversalSoldierLW

Every soldier who would join a class from the soldier deck becomes a universal soldier at the first promotion instead, and the class choice of WOTC_ChooseMyClass is skipped. When the promotion screen first shows such a soldier, it asks for the specializations, three by default, and then for two origin abilities the soldier starts with. Each specialization is one ability column of another class, so the soldier combines columns from several classes and then buys their abilities with ability points as usual. The screen lists the choices on the right, where a click removes one, and previews every ability of the highlighted entry. The mod is written for Long War of the Chosen, but names no class: every class in the soldier deck, including those of class packs, offers its columns. It requires War of the Chosen, [X2WOTCCommunityHighlander](https://steamcommunity.com/sharedfiles/filedetails/?id=1134256495), [X2WOTCCommunityPromotionScreen](https://steamcommunity.com/sharedfiles/filedetails/?id=2550561145), and [Ability To Slot Reassignment](https://steamcommunity.com/sharedfiles/filedetails/?id=2133397762), and cannot run with RPG Overhaul.

- Columns: a class's column is the slot at the same index in every rank, leaving out the random XCOM row and the LWOTC pistol row. The first specialization chosen is the primary one: its class adds the squaddie abilities it shares across its columns, such as the Specialist's protocols, and its XCOM and pistol rows follow the chosen columns.
- Weapons: any specializations combine. In each weapon slot a universal soldier may equip what any of its specializations' classes allows there. Ability To Slot Reassignment moves each ability it lists onto a fitting weapon in a mission, or drops it. For the rest, a column ability on the secondary slot is granted only while the soldier carries a weapon category its classes allow there; primary slot, origin, XCOM row, and pistol row abilities are always granted.
- Origin abilities: the pool is every passive ability in the random decks (the XCOM row) of the source classes, adjusted by `ORIGIN_EXTRA_ABILITIES` and `ORIGIN_EXCLUDED_ABILITIES`. An ability that needs a weapon none of the chosen specializations' classes allow is not offered. The chosen ones join the squaddie abilities.
- Conflicts: two abilities from different columns form a family when an `ABILITY_GROUPS` entry lists both, when one replaces the other through `OverrideAbilities` without being its upgrade, or when both show the same name. Learning one locks the rest, and of the squaddie abilities only the family member with the highest priority is granted.
- Stat training: a button on the promotion screen buys the stat upgrades in `STAT_UPGRADES` with the soldier's ability points, then the shared XCOM pool. Every soldier can use it.
- Retraining in the Training Center clears the specializations, the origin abilities, and the stat upgrades, and refunds the soldier's own ability points.

`Config/XComUniversalSoldierLW.ini` sets the number of specializations and origin abilities, the excluded classes and abilities, the ability groups, and the stat upgrades. Removing the mod from a running campaign leaves its universal soldiers without a class.

```bash
uv run UniversalSoldierLW/build.py --sdk <WOTC SDK> --mods-dir <XComGame/Mods> --highlander <Highlander Workshop directory>
```

The mod overrides Highlander hooks, so `build.py` first copies the Highlander's `Core`, `Engine`, and `XComGame` sources over the SDK's `Development/Src`. It also reads Ability To Slot Reassignment's config class, whose sources do not build with the current SDK, so a stand-in with the same declarations in `BuildStubs/` is compiled into the SDK first and left out of the mod. It then compiles and installs the mod as for x2locWeaponCatNames.

## CommandsUI

F10 opens a menu of the console commands that apply to the current layer, the Avenger or a mission, grouped by category; F10 again or Esc closes it. Choosing a command asks for its parameters in order: numbers and text in an input box, everything else from a list that can be filtered by name, such as resources, items, abilities, research, soldier classes, or soldiers. The menu then runs the command line as if it had been typed, and stays open. Only the common commands are listed until **Show all** is clicked; the choice is remembered. Toggles such as unlimited actions show a checkbox with their current state, and the ones left on are turned on again at the start of each later mission until they are turned off. Retail builds create the cheat manager only with the `-allowconsole` launch option, so the menu creates it itself; a few commands still check the option, and the menu says when it is missing. It requires War of the Chosen and [X2WOTCCommunityHighlander](https://steamcommunity.com/sharedfiles/filedetails/?id=1134256495).

`Config/XComCommandsUI.ini` sets the hotkey and lists the commands. Each entry is a command line whose `%1`, `%2`, ... take its parameters, the layer it applies to, the kind of each parameter, and optionally the mod that adds the command, whether it is advanced, and the toggle state it shows; the labels are in `Localization/CommandsUI.*`. The default list holds base game commands, plus the commands of LWOTC, [Additional Soldier Console Commands](https://steamcommunity.com/sharedfiles/filedetails/?id=1370543410), and [XpanD's Console Commands](https://steamcommunity.com/sharedfiles/filedetails/?id=3113132590), each listed only while its mod is active. The base game's mission win ends the mission as a win without completing its objectives; XpanD's command completes every objective first.

```bash
uv run CommandsUI/build.py --sdk <WOTC SDK> --mods-dir <XComGame/Mods> --highlander <Highlander Workshop directory>
uv run CommandsUI/publish.py --steamcmd <steamcmd.exe> --username <Steam account>
```

`publish.py` uploads it to the Steam Workshop as described for x2locWeaponCatNames.

## License

MIT
