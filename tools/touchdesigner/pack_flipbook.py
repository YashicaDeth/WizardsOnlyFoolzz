"""Pack a TouchDesigner image sequence into the trip's flipbook atlas.

DESIGN/TOUCHDESIGNER_PIPELINE.md, "A baked sequence as a trip". TouchDesigner
writes frames (Movie File Out TOP, Type: Image Sequence); this lays them out in
a grid and writes the two files the game reads:

    game/art/materia/trip_flipbook.png    the atlas, left to right, top to bottom
    game/art/materia/trip_flipbook.json   {columns, rows, frames, fps, loop}

    python tools/touchdesigner/pack_flipbook.py P:/GameDev/Temp/td_frames --fps 12
    python tools/touchdesigner/pack_flipbook.py FRAMES --cell 640x360 --fps 24 --once

Frames are sorted by file name. The atlas is kept to 8192 px a side (what every
GPU the game targets accepts); too many frames for that at the chosen cell size
is an error rather than a silent shrink. Needs Pillow.
"""
import argparse
import json
import math
import pathlib
import sys

from PIL import Image

MAX_SIDE = 8192
OUT = pathlib.Path(__file__).resolve().parents[2] / "game" / "art" / "materia"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("frames", help="folder of PNG/JPG/TIF frames")
    parser.add_argument("--cell", default="640x360", help="size of one frame in the atlas, WxH")
    parser.add_argument("--fps", type=float, default=12.0)
    parser.add_argument("--once", action="store_true", help="hold the last frame instead of looping")
    parser.add_argument("--name", default="trip_flipbook")
    args = parser.parse_args()

    files = sorted(p for p in pathlib.Path(args.frames).iterdir()
                   if p.suffix.lower() in (".png", ".jpg", ".jpeg", ".tif", ".tiff"))
    if not files:
        sys.exit("no frames in %s" % args.frames)
    cell_w, cell_h = (int(v) for v in args.cell.lower().split("x"))
    columns = max(1, min(len(files), MAX_SIDE // cell_w))
    rows = math.ceil(len(files) / columns)
    if rows * cell_h > MAX_SIDE:
        sys.exit("%d frames at %dx%d need %d px tall, over %d. Use a smaller --cell or fewer frames."
                 % (len(files), cell_w, cell_h, rows * cell_h, MAX_SIDE))

    atlas = Image.new("RGB", (columns * cell_w, rows * cell_h))
    for index, path in enumerate(files):
        frame = Image.open(path).convert("RGB").resize((cell_w, cell_h), Image.LANCZOS)
        atlas.paste(frame, ((index % columns) * cell_w, (index // columns) * cell_h))

    OUT.mkdir(parents=True, exist_ok=True)
    atlas.save(OUT / (args.name + ".png"))
    spec = {"columns": columns, "rows": rows, "frames": len(files), "fps": args.fps, "loop": not args.once}
    (OUT / (args.name + ".json")).write_text(json.dumps(spec, indent=1))
    megabytes = atlas.width * atlas.height * 4 / 1e6
    print("wrote %s (%dx%d, %d frames, %.1f s) and its .json" % (
        OUT / (args.name + ".png"), atlas.width, atlas.height, len(files), len(files) / args.fps))
    print("uncompressed in video memory: %.0f MB. In Godot's Import dock set Compress > Mode to VRAM Compressed"
          " for about a quarter of that." % megabytes)


if __name__ == "__main__":
    main()
