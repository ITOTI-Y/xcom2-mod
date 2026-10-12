# xcom2-mod

[English](README.md) | 简体中文

《XCOM 2：天选者之战》的脚本 mod 合集。每个 mod 位于单独的目录中，包含 UnrealScript 源码、配置、编译好的脚本，以及构建和发布脚本。

| Mod | 用途 |
|---|---|
| [x2locWeaponCatNames](x2locWeaponCatNames) | 把技能说明“可用武器”一行中 mod 武器类别的内部代号替换为本地化名称 |

## x2locWeaponCatNames

[WOTCMusashiModFixes](https://steamcommunity.com/sharedfiles/filedetails/?id=2569592723) 会在技能说明末尾追加一行“可用武器”，其中由 mod 新增的武器类别显示为内部代号，例如 `combatknife`。本 mod 把每个代号替换为该类别武器自身的本地化名称，语言跟随游戏当前设置。它需要天选者之战、[X2WOTCCommunityHighlander](https://steamcommunity.com/sharedfiles/filedetails/?id=1134256495) 和 WOTCMusashiModFixes。

脚本用 [uv](https://docs.astral.sh/uv/) 运行，首次运行时 uv 会自动安装唯一的依赖 Typer：

```bash
uv run x2locWeaponCatNames/build.py --sdk <WOTC SDK> --mods-dir <XComGame/Mods>
uv run x2locWeaponCatNames/publish.py --steamcmd <steamcmd.exe> --username <Steam 账号>
```

`build.py` 用天选者之战 SDK 编译该 mod，把编译好的脚本保存在 `Script/` 中，并安装到游戏。`publish.py` 用 [SteamCMD](https://developer.valvesoftware.com/wiki/SteamCMD) 把它上传到 Steam 创意工坊，简介取自 `workshop/description.bbcode`，预览图为 `ModPreview.jpg`。密码和 Steam 令牌验证码由 SteamCMD 直接询问。首次上传创建一个隐藏条目，并把条目 ID 记录在 `workshop/publishedfileid` 中；之后的上传更新同一条目。SteamCMD 无法设置标签和必需物品，二者需要在条目的创意工坊页面上设置。

## 许可证

MIT
