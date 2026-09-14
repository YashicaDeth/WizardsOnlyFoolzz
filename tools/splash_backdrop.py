"""Derive the title-screen backdrops from Greg's own artwork.

Greg sent two images: his room — the posters, the hands, the rune, the CellOutz
lettering — and the same shot cut down the middle with the right half inverted
into cyan. He asked for both, with "the blue invertred side attacking the
screen".

The first pass got this wrong twice and it is worth writing down, because the
mistake is an easy one to repeat. It derived a *different* file from the same
folder, and then re-created the inverted half procedurally in a shader. That
second part was the real error: Greg had already made the inverted image. A
shader approximating it replaces his artwork with a guess at his artwork, and
no amount of tuning the guess makes it his.

So both images are derived and the attack is a wipe *between* them. What
crosses the screen is his own inverted cut.

The sources live in `C:\\Users\\Greg\\Desktop\\Art Collections`, which is
read-only: nothing here ever writes back to it. Derived assets go to
`game/art/derived/`, and this script is how they rebuild from scratch, so the
repository never carries a binary nobody can regenerate.

Run:  python tools/splash_backdrop.py
      python tools/splash_backdrop.py --room PATH --invert PATH
"""

from __future__ import annotations

import argparse
import os
import sys

ART = os.path.join("C:" + os.sep, "Users", "Greg", "Desktop", "Art Collections")

# `Background.jpg`     — the room, the hands, the rune. Greg's image 2.
# `Documeninvertt.jpg` — the same shot, right half inverted into cyan. Image 1.
SOURCES = {
    "splash_room": os.path.join(ART, "Background.jpg"),
    "splash_invert": os.path.join(ART, "Documeninvertt.jpg"),
}

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(HERE, "game", "art", "derived")

# 1920 is the most the title screen can ever show at full bleed, and the sources
# are 4050px — carrying the extra three thousand pixels into the pack costs tens
# of megabytes for detail no display resolves.
TARGET_WIDTH = 1920


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--width", type=int, default=TARGET_WIDTH)
    parser.add_argument("--room", default=SOURCES["splash_room"])
    parser.add_argument("--invert", default=SOURCES["splash_invert"])
    args = parser.parse_args()

    try:
        from PIL import Image
    except ImportError:
        print("Pillow is required: python -m pip install pillow")
        return 2

    Image.MAX_IMAGE_PIXELS = None
    os.makedirs(OUT_DIR, exist_ok=True)

    for name, source_path in (("splash_room", args.room), ("splash_invert", args.invert)):
        if not os.path.exists(source_path):
            print("source not found: %s" % source_path)
            return 1
        with Image.open(source_path) as source:
            source = source.convert("RGB")
            width, height = source.size
            scale = args.width / float(width)
            target = (args.width, max(1, int(round(height * scale))))
            # LANCZOS: these are glitch composites made of hard chromatic edges,
            # and a cheaper filter turns exactly those edges to mush — the one
            # thing the pictures cannot afford to lose.
            derived = source.resize(target, Image.LANCZOS)
        out_path = os.path.join(OUT_DIR, name + ".png")
        derived.save(out_path, "PNG", optimize=True)
        print("%-14s %-26s %dx%d -> %dx%d  %.1f MB" % (
            name, os.path.basename(source_path), width, height,
            target[0], target[1], os.path.getsize(out_path) / 1048576.0))
    return 0


if __name__ == "__main__":
    sys.exit(main())
