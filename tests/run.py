"""Run integration checks in a temporary, portable copy of Rejuvenation under Linux."""
import argparse
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--game", type=Path, required=True, help="Root of the compatible game")
parser.add_argument("--engine", type=Path, required=True, help="Extracted mkxp-z AppRun or binary")
parser.add_argument("--mod-zip", type=Path, help="Install the packaged mod instead of the source tree")
parser.add_argument("--french", type=Path, help="Original RejuvFR distribution ZIP")
parser.add_argument("--log", type=Path, help="Write the complete list of passing checks here")
args = parser.parse_args()
game, engine = args.game.resolve(), args.engine.resolve()
with tempfile.TemporaryDirectory(prefix="rejuv-nuit-") as temp:
    run = Path(temp)
    for name in ("Data", "Scripts", "Game.ini", "stdlib", "gems", "Fonts", "Graphics", "Audio", "cacert.pem"):
        src, dst = game / name, run / name
        if src.is_dir():
            if name in ("Audio", "Graphics", "Fonts", "gems", "stdlib"):
                dst.symlink_to(src, target_is_directory=True)
            else:
                shutil.copytree(src, dst)
        elif src.is_file():
            shutil.copy2(src, dst)
    cfg = dict(rgssVersion=1, defScreenW=512, defScreenH=384, dataPathApp="ModeNuit-Integration",
               pathCache=False, patches=["patch"], vsync=False, fixedFramerate=60, midiSoundFont="")
    (run / "mkxp.json").write_text(json.dumps(cfg))
    profile = run / "Save Data"
    profile.mkdir()
    (profile / ".portable").touch()
    if args.mod_zip:
        expected = {p.relative_to(ROOT).as_posix() for p in (ROOT / "patch").rglob("*.rb")}
        with ZipFile(args.mod_zip) as archive:
            if sorted(archive.namelist()) != sorted(expected):
                raise ValueError("Unexpected files in the mod package")
            for name in expected:
                path = run / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(archive.read(name))
    else:
        shutil.copytree(ROOT / "patch", run / "patch")
    if args.french:
        with ZipFile(args.french) as archive:
            for entry in archive.infolist():
                parts = Path(entry.filename).parts
                if entry.is_dir() or not parts or parts[0] != "patch" or ".." in parts:
                    continue
                dest = run.joinpath(*parts)
                dest.parent.mkdir(parents=True, exist_ok=True)
                with dest.open("xb") as target, archive.open(entry) as source:
                    shutil.copyfileobj(source, target)
    shutil.copy2(ROOT / "tests" / "entry.rb", run / "patch/Mods/zzz_nuit_test.rb")
    env = dict(os.environ, SDL_VIDEODRIVER="offscreen", SDL_AUDIODRIVER="dummy",
               ALSOFT_DRIVERS="null", LIBGL_ALWAYS_SOFTWARE="true",
               XDG_DATA_HOME=str(run / "profile"), NUIT_TEST_LANG="fr" if args.french else "en")
    for case in ("integration.rb", "reload.rb"):
        test = ROOT / "tests" / case
        env["NUIT_TEST_FILE"] = str(test)
        with (run / "engine.log").open("wb") as console:
            status = subprocess.run([str(engine)], cwd=run, env=env, stdout=console, stderr=subprocess.STDOUT, timeout=100)
        failure, passed = run / "nuit-failure.txt", run / ("passed-" + case)
        if failure.exists() or status.returncode or not passed.exists():
            details = (failure if failure.exists() else run / "engine.log").read_text(errors="replace")
            log = run / "nuit-results.txt"
            if log.exists():
                print("\n".join(log.read_text().splitlines()[-6:]))
            raise SystemExit(details[-3000:] if not failure.exists() else details[:3500])
    report = (run / "nuit-results.txt").read_text()
    if args.log:
        args.log.write_text(report, encoding="utf-8")
    print(f'{env["NUIT_TEST_LANG"]}: {len(report.splitlines())} checks passed in two native engine sessions')
