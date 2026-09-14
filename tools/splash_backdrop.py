"""Derive the title-screen backdrop from Greg's own artwork.

Greg: *"the splash screen fades in with this as the backround image ... also make
the backround images be theese 2 the blue invertred side attacking the screen and
then ofc the backround is from my room"*.

The source lives in `C:\\Users\\Greg\\Desktop\\Art Collections`, which is
**read-only**: nothing here ever writes back to it. The derived asset goes to
`game/art/derived/`, and this script is how it rebuilds from scratch, so the
repository never carries a binary nobody can regenerate.

What it does *not* do is bake the blue/inverted half into the image. That
half is a transformation of the same photograph, and `splash_backdrop.gd`
performs it live on the GPU — which means the invert can move, tear and sweep
across the screen ("attacking" it) instead of being a fixed seam, and it keeps
working when the source picture is swapped for a different one.

Run:  python tools/splash_backdrop.py [--source PATH]
"""

from __future__ import annotations

import argparse
import os
import sys

# Greg's own art: the room, the hands over the face, the rune, the posters.
# `Documeninvertt.jpg` beside it is his own inverted cut of the same shot — the
# shader performs that transformation live, so only the unaltered photograph is
# derived here and the invert stays something that can move.
DEFAULT_SOURCE = r"C:\Users\Greg\Desktop\Art Collections\Cellout Wizards Only Fools.2.jpg"

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(HERE, "game", "art", "derived")
OUT_NAME = "splash_backdrop.png"

# 1920 wide is the most the title screen can ever show at full-bleed on the
# builds this ships to, and the source is 4050px — carrying the extra three
# thousand pixels into the pack costs tens of megabytes for detail no display
# resolves.
TARGET_WIDTH = 1920


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", default=DEFAULT_SOURCE)
    parser.add_argument("--width", type=int, default=TARGET_WIDTH)
    args = parser.parse_args()

    try:
        from PIL import Image
    except ImportError:
        print("Pillow is required: python -m pip install pillow")
        return 2

    if not os.path.exists(args.source):
        print("source not found: %s" % args.source)
        return 1

    Image.MAX_IMAGE_PIXELS = None
    with Image.open(args.source) as source:
        source = source.convert("RGB")
        width, height = source.size
        scale = args.width / float(width)
        target = (args.width, max(1, int(round(height * scale))))
        # LANCZOS: this is a glitch composite full of hard chromatic edges, and
        # a cheaper filter turns those edges into mush, which is the one thing
        # the picture cannot afford to lose.
        derived = source.resize(target, Image.LANCZOS)

    os.makedirs(OUT_DIR, exist_ok=True)
    out_path = os.path.join(OUT_DIR, OUT_NAME)
    derived.save(out_path, "PNG", optimize=True)
    print("source  : %s (%dx%d)" % (args.source, width, height))
    print("derived : %s (%dx%d, %.1f MB)" % (
        out_path, target[0], target[1], os.path.getsize(out_path) / 1048576.0))
    return 0


if __name__ == "__main__":
    sys.exit(main())
