# xcom2-mod

[English](README.md) | 简体中文

《XCOM 2：天选者之战》的脚本 mod 合集。每个 mod 位于单独的目录中，包含 UnrealScript 源码、配置、编译好的脚本，以及构建和发布脚本。

| Mod | 用途 |
|---|---|
| [x2locWeaponCatNames](x2locWeaponCatNames) | 把技能说明“可用武器”一行中 mod 武器类别的内部代号替换为本地化名称 |
| [UniversalSoldierLW](UniversalSoldierLW) | 新兵从所有兵种的技能列中自选专精，并可用能力点提升属性 |
| [CheatUI](CheatUI) | 用快捷键打开控制台指令菜单，点击即可执行，无需手动输入 |

## x2locWeaponCatNames

[WOTCMusashiModFixes](https://steamcommunity.com/sharedfiles/filedetails/?id=2569592723) 会在技能说明末尾追加一行“可用武器”，其中由 mod 新增的武器类别显示为内部代号，例如 `combatknife`。本 mod 把每个代号替换为该类别武器自身的本地化名称，语言跟随游戏当前设置。它需要天选者之战、[X2WOTCCommunityHighlander](https://steamcommunity.com/sharedfiles/filedetails/?id=1134256495) 和 WOTCMusashiModFixes。

脚本用 [uv](https://docs.astral.sh/uv/) 运行，首次运行时 uv 会自动安装唯一的依赖 Typer：

```bash
uv run x2locWeaponCatNames/build.py --sdk <WOTC SDK> --mods-dir <XComGame/Mods>
uv run x2locWeaponCatNames/publish.py --steamcmd <steamcmd.exe> --username <Steam 账号>
```

`build.py` 用天选者之战 SDK 编译该 mod，把编译好的脚本保存在 `Script/` 中，并安装到游戏。`publish.py` 用 [SteamCMD](https://developer.valvesoftware.com/wiki/SteamCMD) 把它上传到 Steam 创意工坊，简介取自 `workshop/description.bbcode`，预览图为 `ModPreview.jpg`。密码和 Steam 令牌验证码由 SteamCMD 直接询问。首次上传创建一个隐藏条目，并把条目 ID 记录在 `workshop/publishedfileid` 中；之后的上传更新同一条目。SteamCMD 无法设置标签和必需物品，二者需要在条目的创意工坊页面上设置。

## UniversalSoldierLW

凡是会从兵种池中分到兵种的士兵，第一次晋升时都改为通用士兵，WOTC_ChooseMyClass 的选兵种步骤也会被跳过。晋升界面第一次显示这样的士兵时，会先要求选择专精（默认 3 个），再选择 2 个起始技能。每个专精是另一个兵种的一列技能，士兵因此可以组合多个兵种的技能列，再照常用能力点购买其中的技能。界面右侧列出已选项，点击即可移除，并预览当前高亮项的全部技能。本 mod 为 Long War of the Chosen 编写，但没有写死任何兵种：兵种池中的所有兵种，包括兵种包新增的，都会提供自己的技能列。它需要天选者之战、[X2WOTCCommunityHighlander](https://steamcommunity.com/sharedfiles/filedetails/?id=1134256495)、[X2WOTCCommunityPromotionScreen](https://steamcommunity.com/sharedfiles/filedetails/?id=2550561145) 和 [Ability To Slot Reassignment](https://steamcommunity.com/sharedfiles/filedetails/?id=2133397762)，不能与 RPG Overhaul 同时启用。

- 技能列：兵种的一列是每个军衔中同一位置的技能槽，不含随机的 XCOM 行和 LWOTC 的手枪行。第一个选择的专精为主专精：它的兵种提供各列共有的新兵级技能（例如专家的各项协议），所选各列之后也接该兵种的 XCOM 行和手枪行。
- 武器：专精可以任意组合。通用士兵每个武器槽可装备的武器，是所选专精各兵种在该槽位允许的武器的并集。Ability To Slot Reassignment 登记过的技能会在任务中改挂到匹配的武器上，找不到就移除。其余技能中，挂在副武器上的兵种列技能，只有士兵携带其兵种在该槽位允许的武器类别时才会获得；主武器技能、起始技能、XCOM 行和手枪行的技能始终会获得。
- 起始技能：技能池是各来源兵种随机牌组（即 XCOM 行）中的全部被动技能，可用 `ORIGIN_EXTRA_ABILITIES` 和 `ORIGIN_EXCLUDED_ABILITIES` 增减。所需武器不在所选专精兵种允许范围内的技能不会列出。选中的技能并入新兵级技能。
- 技能冲突：来自不同列的两个技能，若同时出现在 `ABILITY_GROUPS` 的同一组中，或一个通过 `OverrideAbilities` 取代另一个且不是它的升级版，或两者显示名称相同，就归为同一族。学会其中一个后，其余的锁定；新兵级技能只授予同族中优先级最高的一个。
- 属性训练：晋升界面上的按钮可用能力点购买 `STAT_UPGRADES` 中的属性提升，先扣士兵自己的能力点，不足部分从 XCOM 共享能力点中扣除。所有士兵都可使用。
- 在训练中心重训会清除专精、起始技能和属性提升，并退还士兵自己的能力点。

专精和起始技能的数量、排除的兵种和技能、技能组以及属性提升都在 `Config/XComUniversalSoldierLW.ini` 中设置。在进行中的战役里移除本 mod，会使通用士兵失去兵种。

```bash
uv run UniversalSoldierLW/build.py --sdk <WOTC SDK> --mods-dir <XComGame/Mods> --highlander <Highlander 创意工坊目录>
```

本 mod 重写了 Highlander 的钩子，所以 `build.py` 会先把 Highlander 的 `Core`、`Engine` 和 `XComGame` 源码覆盖到 SDK 的 `Development/Src`。它还要读取 Ability To Slot Reassignment 的配置类，而该 mod 的源码无法用当前 SDK 编译，所以先把 `BuildStubs/` 中声明一致的替身类编译进 SDK，替身类不随 mod 发布。随后像 x2locWeaponCatNames 一样编译并安装。

## CheatUI

按 F10 打开菜单，按类别列出当前场景（复仇者号或任务中）适用的控制台指令；再按 F10 或 Esc 关闭。选择一条指令后，菜单依次询问它的参数：数字和文本在输入框中填写，其余参数从可按名称筛选的列表中选择，例如资源、物品、技能、研究、兵种和士兵。随后菜单执行这条指令，效果与手动输入相同，菜单保持打开。正式版游戏只在使用 `-allowconsole` 启动参数时才创建作弊管理器，因此菜单会自行创建；少数指令仍会检查该参数，缺少时菜单顶部会给出提示。它需要天选者之战和 [X2WOTCCommunityHighlander](https://steamcommunity.com/sharedfiles/filedetails/?id=1134256495)。

快捷键和指令清单都在 `Config/XComCheatUI.ini` 中设置。每条指令写明命令行（`%1`、`%2` 等依次代入参数）、适用场景和每个参数的类型；显示名称在 `Localization/CheatUI.*` 中。默认清单包含原版指令和 LWOTC 的 `RespecSelectedSoldier`。

```bash
uv run CheatUI/build.py --sdk <WOTC SDK> --mods-dir <XComGame/Mods> --highlander <Highlander 创意工坊目录>
```

## 许可证

MIT
