"""G1. Greg's own artwork, cut into a texture set the game can actually use.

The source collection is read-only and stays where it is. Nothing in here
writes to the Desktop; every output goes into `game/art/derived/`, so the
pipeline can be re-run and the results thrown away and rebuilt at any time.

Why a pipeline rather than hand-exported PNGs: the sources are 10-70MB
Affinity/Photoshop exports at print resolution, and the game needs tiling
512px surfaces. Doing it by script means the crops are reproducible, the
manifest records exactly which artwork each texture came from, and re-running
after Greg adds a piece costs nothing.

The operations are the ones named in the checklist - **cut, glitch and shade**:

  cut     take a region with real detail in it rather than the whole canvas
  glitch  row displacement and channel offset, the CRT/digital-decay register
          ART-DIRECTION.md already asks for
  shade   pull the result toward the Ashbloom palette so a texture sits in the
          world instead of floating on top of it

Usage:  python tools/art_pipeline.py --source "<art folder>" [--limit N]
"""

from __future__ import annotations

import argparse
import json
import random
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter

# Anything under these is an application install that happens to live in the
# same folder, not artwork.
EXCLUDE_PARTS = ("Adobe Photoshop", "Adobe After Effects", "New folder")
SUFFIXES = (".jpg", ".jpeg", ".png")

# The Ashbloom palette, from the constants the interface is already built on.
BONE = (230, 212, 172)
BLOOD = (107, 15, 12)
COPPER = (176, 85, 42)
MOSS = (138, 154, 74)
BRUISE = (107, 63, 110)
PLATE = (26, 30, 26)

Image.MAX_IMAGE_PIXELS = None


def art_files(source: Path) -> list[Path]:
    found = []
    for path in sorted(source.rglob("*")):
        if path.suffix.lower() not in SUFFIXES or not path.is_file():
            continue
        if any(part in str(path) for part in EXCLUDE_PARTS):
            continue
        found.append(path)
    return found


def load(path: Path, longest: int = 1600) -> Image.Image:
    """Sources are print-resolution; nothing here needs more than a screen."""
    image = Image.open(path)
    image.draft("RGB", (longest, longest))
    image = image.convert("RGB")
    image.thumbnail((longest, longest), Image.LANCZOS)
    return image


def palette_of(image: Image.Image, count: int = 6) -> list[str]:
    small = image.copy()
    small.thumbnail((96, 96), Image.LANCZOS)
    reduced = small.convert("P", palette=Image.ADAPTIVE, colors=count).convert("RGB")
    counts = {}
    for pixel in reduced.getdata():
        counts[pixel] = counts.get(pixel, 0) + 1
    ordered = sorted(counts.items(), key=lambda item: -item[1])[:count]
    return ["%02x%02x%02x" % rgb for rgb, _ in ordered]


def busiest_crop(image: Image.Image, size: int, rng: random.Random) -> Image.Image:
    """Pick the region with the most going on in it.

    A random crop of a painting is very often an empty corner. Scoring a
    handful of candidates by edge energy keeps the texture set made of the
    parts of the artwork that actually look like something.
    """
    width, height = image.size
    span = min(width, height, max(size, int(min(width, height) * 0.55)))
    best, best_score = None, -1.0
    for _ in range(12):
        left = rng.randint(0, max(0, width - span))
        top = rng.randint(0, max(0, height - span))
        candidate = image.crop((left, top, left + span, top + span))
        probe = candidate.copy()
        probe.thumbnail((64, 64), Image.LANCZOS)
        edges = probe.convert("L").filter(ImageFilter.FIND_EDGES)
        score = sum(edges.getdata()) / (probe.size[0] * probe.size[1])
        if score > best_score:
            best, best_score = candidate, score
    return best.resize((size, size), Image.LANCZOS)


def glitch(image: Image.Image, rng: random.Random, strength: float = 1.0) -> Image.Image:
    """Row displacement, channel offset and the occasional repeated block."""
    out = image.copy()
    width, height = out.size

    for _ in range(int(7 * strength)):
        top = rng.randint(0, height - 2)
        band = min(rng.randint(2, max(3, height // 18)), height - top)
        shift = rng.randint(-int(width * 0.08), int(width * 0.08))
        if shift == 0:
            continue
        strip = out.crop((0, top, width, top + band))
        out.paste(strip, (shift, top))
        out.paste(strip, (shift - width if shift > 0 else shift + width, top))

    # A block that repeats where it should not, which is what a bad decode does.
    for _ in range(int(2 * strength)):
        size = rng.randint(width // 12, max(width // 12 + 1, width // 5))
        sx, sy = rng.randint(0, width - size), rng.randint(0, height - size)
        dx, dy = rng.randint(0, width - size), rng.randint(0, height - size)
        out.paste(out.crop((sx, sy, sx + size, sy + size)), (dx, dy))

    red, green, blue = out.split()
    offset = max(1, int(width * 0.004 * strength))
    red = red.transform(red.size, Image.AFFINE, (1, 0, -offset, 0, 1, 0))
    blue = blue.transform(blue.size, Image.AFFINE, (1, 0, offset, 0, 1, offset // 2))
    return Image.merge("RGB", (red, green, blue))


def shade(image: Image.Image, tint: tuple[int, int, int], amount: float = 0.38,
          contrast: float = 1.12, saturation: float = 0.72) -> Image.Image:
    """Pull a picture toward one of the world's colours so it sits in it."""
    out = ImageEnhance.Color(image).enhance(saturation)
    out = ImageEnhance.Contrast(out).enhance(contrast)
    wash = Image.new("RGB", out.size, tint)
    return Image.blend(out, wash, amount)


def make_tileable(image: Image.Image) -> Image.Image:
    """Mirror into quarters so a body texture has no visible seam."""
    size = image.size[0] // 2
    quarter = image.resize((size, size), Image.LANCZOS)
    out = Image.new("RGB", (size * 2, size * 2))
    out.paste(quarter, (0, 0))
    out.paste(quarter.transpose(Image.FLIP_LEFT_RIGHT), (size, 0))
    out.paste(quarter.transpose(Image.FLIP_TOP_BOTTOM), (0, size))
    out.paste(quarter.transpose(Image.ROTATE_180), (size, size))
    return out


def scanlines(image: Image.Image, every: int = 3, darkness: float = 0.82) -> Image.Image:
    out = image.copy()
    pixels = out.load()
    width, height = out.size
    for y in range(0, height, every):
        for x in range(width):
            r, g, b = pixels[x, y]
            pixels[x, y] = (int(r * darkness), int(g * darkness), int(b * darkness))
    return out


def collage(sources: list[Image.Image], size: int, rng: random.Random) -> Image.Image:
    """G1.5. Hard cuts, no blending. Torn paper rather than a gradient."""
    out = Image.new("RGB", (size, size), PLATE)
    for index, source in enumerate(sources):
        piece_w = rng.randint(size // 4, size // 2)
        piece_h = rng.randint(size // 5, size // 2)
        piece = busiest_crop(source, max(piece_w, piece_h), rng).resize((piece_w, piece_h), Image.LANCZOS)
        if index % 2 == 0:
            piece = glitch(piece, rng, 0.8)
        piece = shade(piece, [COPPER, MOSS, BRUISE, BLOOD][index % 4], 0.22)
        out.paste(piece, (rng.randint(-piece_w // 6, size - piece_w // 2),
                          rng.randint(-piece_h // 6, size - piece_h // 2)))
    return out


def build(source: Path, out_dir: Path, limit: int | None = None) -> dict:
    rng = random.Random(20260911)
    files = art_files(source)
    if limit:
        files = files[:limit]
    if not files:
        raise SystemExit("no artwork found under %s" % source)

    out_dir.mkdir(parents=True, exist_ok=True)
    for kind in ("body", "plate", "wire"):
        (out_dir / kind).mkdir(exist_ok=True)

    catalogue, loaded = [], []
    for path in files:
        try:
            image = load(path)
        except Exception as error:  # a .psd-adjacent jpg that will not decode
            catalogue.append({"file": path.name, "error": str(error)[:80]})
            continue
        catalogue.append({
            "file": path.name,
            "relative": str(path.relative_to(source)).replace("\\", "/"),
            "width": image.size[0],
            "height": image.size[1],
            "palette": palette_of(image),
        })
        loaded.append((path, image))

    # G1.3 body textures: tiling, wet, pulled toward flesh and bruise.
    bodies = []
    for path, image in loaded[: min(8, len(loaded))]:
        cut = busiest_crop(image, 512, rng)
        cut = shade(glitch(cut, rng, 0.6), BLOOD, 0.30, 1.18, 0.55)
        tile = make_tileable(cut)
        name = "body/%s.png" % path.stem.lower().replace(" ", "_")[:28]
        tile.save(out_dir / name, optimize=True)
        bodies.append({"texture": name, "from": path.name})

    # G1.4 map plates and interface surfaces: flat, inked, scanned.
    plates = []
    for path, image in loaded[: min(6, len(loaded))]:
        cut = busiest_crop(image, 768, rng).resize((1024, 512), Image.LANCZOS)
        cut = shade(cut, PLATE, 0.55, 0.92, 0.35)
        cut = scanlines(ImageEnhance.Brightness(cut).enhance(0.82))
        name = "plate/%s.png" % path.stem.lower().replace(" ", "_")[:28]
        cut.save(out_dir / name, optimize=True)
        plates.append({"texture": name, "from": path.name})

    # G1.5 Wire collage: several pieces, hard cuts, no two alike.
    wires = []
    pool = [image for _, image in loaded]
    for index in range(3):
        sheet = collage(rng.sample(pool, min(5, len(pool))), 768, rng)
        name = "wire/collage_%02d.png" % index
        sheet.save(out_dir / name, optimize=True)
        wires.append({"texture": name})

    manifest = {
        "source": str(source),
        "note": "Generated by tools/art_pipeline.py from Greg's own artwork. "
                "Originals are never modified; re-run to rebuild.",
        "artworks": catalogue,
        "body": bodies,
        "plate": plates,
        "wire": wires,
    }
    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent="\t"), encoding="utf-8")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--out", type=Path, default=Path("game/art/derived"))
    parser.add_argument("--limit", type=int, default=None)
    args = parser.parse_args()
    manifest = build(args.source, args.out, args.limit)
    print("catalogued %d artworks" % len(manifest["artworks"]))
    print("body %d  plate %d  wire %d" % (len(manifest["body"]), len(manifest["plate"]), len(manifest["wire"])))


if __name__ == "__main__":
    main()
