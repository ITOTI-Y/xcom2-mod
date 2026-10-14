# /// script
# requires-python = ">=3.12"
# dependencies = ["typer>=0.24"]
# ///
"""Build CheatUI with the WOTC SDK and install it into the game.

The mod uses Community Highlander functions, so the SDK compiles against the
Highlander's XComGame sources, copied from its Workshop item over the SDK's own.
The compiled script is also kept in `Script/`, where publish.py uploads it from.

uv run CheatUI/build.py --sdk <SDK dir> --mods-dir <XComGame/Mods> --highlander <Highlander Workshop dir>
"""

import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Annotated, Final

import typer

MOD: Final = "CheatUI"
HERE: Final = Path(__file__).parent


def make(sdk: Path, *args: str) -> None:
    compiler = sdk / "Binaries" / "Win64" / "XComGame.com"
    result = subprocess.run(
        [str(compiler), "make", "-nopause", "-unattended", *args],
        cwd=compiler.parent,
        capture_output=True,
        text=True,
        errors="replace",
    )
    lines = result.stdout.splitlines()
    if result.returncode != 0 or not any(line.startswith("Success") for line in lines):
        errors = [line for line in lines if "error" in line.lower()]
        raise RuntimeError("SDK make failed:\n" + "\n".join(errors[-30:]))
    for line in dict.fromkeys(line for line in lines if f"\\{MOD}\\" in line and "Warning" in line):
        typer.echo(line)


def overlay_highlander(highlander: Path, src: Path) -> None:
    """Copies the Highlander's Core, Engine and XComGame sources over the SDK's.

    copyfile gives the copies a new modification time, so the compiler rebuilds
    those packages from them.
    """
    for package in ("Core", "Engine", "XComGame"):
        for source in (highlander / "Src" / package).rglob("*"):
            if source.is_file():
                target = src / package / source.relative_to(highlander / "Src" / package)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, target)


def main(
    sdk: Annotated[Path, typer.Option(help="XCOM 2 War of the Chosen SDK directory")],
    mods_dir: Annotated[Path, typer.Option(help="The game's XComGame/Mods directory")],
    highlander: Annotated[Path, typer.Option(help="Community Highlander Workshop directory (1134256495)")],
) -> None:
    src = sdk / "Development" / "Src"
    if not src.is_dir():
        # copytree keeps modification times; newer copies would make the
        # compiler rebuild Core.u, which it holds open and cannot replace.
        shutil.copytree(sdk / "Development" / "SrcOrig", src)
    overlay_highlander(highlander, src)
    shutil.rmtree(src / MOD, ignore_errors=True)
    shutil.copytree(HERE / "Src" / MOD, src / MOD)

    with tempfile.TemporaryDirectory() as tmp:
        stage = Path(tmp) / MOD
        for folder in ("Config", "Localization", "Src"):
            shutil.copytree(HERE / folder, stage / folder)
        shutil.copy2(HERE / f"{MOD}.XComMod", stage)

        make(sdk)
        make(sdk, "-mods", MOD, str(stage))
        (HERE / "Script").mkdir(exist_ok=True)
        shutil.copy2(sdk / "XComGame" / "Script" / f"{MOD}.u", HERE / "Script")
        shutil.copytree(HERE / "Script", stage / "Script")

        installed = mods_dir / MOD
        shutil.rmtree(installed, ignore_errors=True)
        shutil.copytree(stage, installed)
    typer.echo(f"Installed {installed}")


if __name__ == "__main__":
    typer.run(main)
