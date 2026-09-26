#!/usr/bin/env python3
"""Bring a generated asset into the game, logged.

Greg, 26 September: "use all these in game creation" -- the asset tools in
DESIGN/ASSET_TOOLS.md run on his RTX and write into P:\\GameDev\\gen\\<tool>.
This copies one output into game/art/generated/<category>/ and appends its
line to game/art/GENERATED.md, so every generated file can always be told
apart from Greg's own art and replaced by it. It never overwrites a file.

    python tools/import_generated_asset.py P:\\GameDev\\gen\\clay\\crate.glb \\
        --tool clay --category props --prompt "rusted supply crate" \\
        --lane A --for "Support Unit closet stash"

Hunyuan-based outputs are refused unless --accept-hunyuan-license is given:
Tencent's Hunyuan licence is non-commercial when self-hosted and excludes the
EU, UK and South Korea. The TRELLIS / Pixal3D / Hi3DGen paths are MIT.
"""
import argparse
import datetime
import json
import pathlib
import shutil
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
ART = ROOT / "game" / "art"
LOG = ART / "GENERATED.md"
SECTION = "## Asset-generator imports"
HEADER = "| File | Tool | Model | Licence | Prompt | Date | Lane | For |\n|---|---|---|---|---|---|---|---|\n"

# The tools in DESIGN/ASSET_TOOLS.md, pinned, and the licence each output carries.
TOOLS = {
    "game-asset-generation": ("joe-lloyd/game-asset-generation@49175414180e", "SDXL / TRELLIS.2", "MIT tool; model per checkpoint"),
    "clay": ("OpenX-Inc/clay@eb41696224cc", "TRELLIS-2 / Hi3DGen", "MIT"),
    "image-to-3dlab": ("Bingeljell/image-to-3dlab@1e6972d351f6", "Pixal3D / TRELLIS.2", "Apache-2.0 tool, MIT model"),
    "hunyuan-trellis-fast": ("FishWoWater/hunyuan_trellis_fast@a893cd54a721", "Hunyuan3D-2 + TRELLIS", "Tencent Hunyuan Community (non-commercial self-host)"),
    "ai-game-asset-generator": ("mohabash/ai-game-asset-generator@3738f2b52c68", "FLUX.1-dev + ControlNet", "MIT tool; FLUX.1-dev non-commercial"),
    "higgsfield": ("Higgsfield", "per prompt", "per Higgsfield terms"),
}
ALLOWED = {".glb", ".gltf", ".png", ".webp", ".jpg", ".ogv", ".wav", ".ogg"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source", type=pathlib.Path)
    parser.add_argument("--tool", required=True, choices=sorted(TOOLS))
    parser.add_argument("--category", required=True, help="props, enemies, rooms, sprites, plates ...")
    parser.add_argument("--prompt", required=True)
    parser.add_argument("--lane", default="?")
    parser.add_argument("--for", dest="purpose", required=True)
    parser.add_argument("--model", help="override the model name, e.g. read from a provenance file")
    parser.add_argument("--provenance", type=pathlib.Path, help="image-to-3dlab .provenance.json; copied alongside")
    parser.add_argument("--accept-hunyuan-license", action="store_true")
    args = parser.parse_args()

    source: pathlib.Path = args.source
    if not source.is_file():
        print(f"no such file: {source}", file=sys.stderr)
        return 2
    if source.suffix.lower() not in ALLOWED:
        print(f"{source.suffix} is not a format the game loads ({', '.join(sorted(ALLOWED))})", file=sys.stderr)
        return 2
    repo, model, licence = TOOLS[args.tool]
    provenance_text = ""
    if args.provenance:
        provenance_text = args.provenance.read_text(encoding="utf-8")
        try:
            data = json.loads(provenance_text)
            model = str(data.get("backend") or data.get("model") or model)
            licence = str(data.get("license") or data.get("licence") or licence)
        except json.JSONDecodeError:
            pass
    if args.model:
        model = args.model
    if "hunyuan" in (args.tool + model + licence).lower() and not args.accept_hunyuan_license:
        print("refused: Hunyuan output. Its licence is non-commercial when self-hosted and excludes the EU, UK "
              "and South Korea. Use a TRELLIS/Pixal3D/Hi3DGen backend, or pass --accept-hunyuan-license.", file=sys.stderr)
        return 3

    target_dir = ART / "generated" / args.category
    target_dir.mkdir(parents=True, exist_ok=True)
    target = target_dir / source.name
    if target.exists():
        print(f"refused: {target.relative_to(ROOT)} already exists; rename the source", file=sys.stderr)
        return 4
    shutil.copy2(source, target)
    if args.provenance:
        shutil.copy2(args.provenance, target_dir / args.provenance.name)

    today = datetime.date.today().isoformat()
    relative = target.relative_to(ART).as_posix()
    row = f"| `{relative}` | {repo} | {model} | {licence} | {args.prompt} | {today} | {args.lane} | {args.purpose} |\n"
    log = LOG.read_text(encoding="utf-8") if LOG.exists() else "# Generated assets\n"
    if SECTION not in log:
        log = log.rstrip("\n") + f"\n\n{SECTION}\n\nFrom the tools in DESIGN/ASSET_TOOLS.md. Placeholder until Greg's own art.\n\n" + HEADER
    log = log.rstrip("\n") + "\n" + row
    LOG.write_text(log, encoding="utf-8")
    print(f"imported {relative} and logged it in game/art/GENERATED.md")
    if target.suffix.lower() in {".glb", ".gltf", ".png", ".webp", ".jpg", ".ogv"}:
        print("media goes through Git LFS: commit with git lfs installed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
