"""The trailer, read as a sheet instead of played.

`art/trailer/build_trailer.jsx` is the edit. This renders that same edit as
still frames so the cut can be judged — copy, shot order, where the type sits —
without opening After Effects and without waiting on a render.

The beat sheet is parsed straight out of the .jsx, so the sheet cannot drift
from the script. Change the trailer in one place and re-run this.

Outputs into art/trailer/out/:

  storyboard-<n>-<slug>.png   one composed frame per story moment
  storyboard-sheet.png        all of them on one sheet, with timecodes

Run:  python tools/trailer_storyboard.py
"""

from __future__ import annotations

import json
import os
import re

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT        = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRAILER_DIR = os.path.join(ROOT, "art", "trailer")
SCRIPT      = os.path.join(TRAILER_DIR, "build_trailer.jsx")
PLATES      = os.path.join(TRAILER_DIR, "plates")
BRAND       = os.path.join(TRAILER_DIR, "brand")
OUT         = os.path.join(TRAILER_DIR, "out")

# The comp, matching CONFIG in the .jsx.
W, H, FPS, DURATION = 1920, 1080, 24, 80.0
BAR = 139

# The grade, also matching CONFIG. The plates are 4-20 mean luminance, so this
# lifts rather than crushes; past ~2.4 the shader's dither hatching shows.
GRADE_GAMMA = 2.10
GRADE_WHITE = 0.90
VIGNETTE    = 0.40

BONE     = (230, 212, 172)
BONE_DIM = (157, 144, 117)
ROT      = (184, 24, 24)
TAR      = (8, 2, 2)

# Consolas Bold stands in for Share Tech Mono, which is a web font and may not
# be installed. Same register: mono, square, no humanist curves.
FONT_CANDIDATES = [
    r"C:\Windows\Fonts\consolab.ttf",
    r"C:\Windows\Fonts\courbd.ttf",
    r"C:\Windows\Fonts\ARIALNB.TTF",
]


# --------------------------------------------------------------- beat sheet --

def load_beats(path: str) -> list[dict]:
    """Pull the BEATS array out of the ExtendScript and read it as data.

    The array is plain object literals, so it becomes JSON with three fixes:
    strip the /* */ comments, quote the keys, and drop trailing commas.
    """
    with open(path, "r", encoding="utf-8") as handle:
        source = handle.read()

    match = re.search(r"var BEATS = (\[.*?\n\]);", source, re.S)
    if not match:
        raise SystemExit("Could not find the BEATS array in " + path)

    body = match.group(1)
    body = re.sub(r"/\*.*?\*/", "", body, flags=re.S)   # block comments
    body = re.sub(r"//[^\n]*", "", body)                # line comments
    body = re.sub(r"(\{|,)\s*([A-Za-z_][A-Za-z0-9_]*)\s*:", r'\1"\2":', body)
    body = re.sub(r",(\s*[\]\}])", r"\1", body)         # trailing commas
    return json.loads(body)


def active(beats: list[dict], kinds: tuple[str, ...], t: float) -> list[dict]:
    """Everything of `kinds` that is on screen at time `t`, topmost first.

    The .jsx adds beats back to front, so an earlier entry ends up on a higher
    layer. Keeping BEATS order here reproduces that stacking.
    """
    return [b for b in beats
            if b.get("type") in kinds
            and b.get("tin", -1) <= t <= b.get("tout", -1)]


def opacity_at(beat: dict, t: float) -> float:
    """The fade the .jsx builds: up, hold, down."""
    edge = 0.10 if beat.get("hard") else 0.45
    if beat["type"] == "card":
        up, down = 0.30, 0.45
    elif beat["type"] == "mark":
        up, down = 0.60, 0.70
    elif beat["type"] == "black":
        up, down = 0.25, 0.55
    else:
        up = down = edge

    tin, tout = beat["tin"], beat["tout"]
    if t <= tin or t >= tout:
        return 0.0
    if t < tin + up:
        return (t - tin) / up
    if t > tout - down:
        return (tout - t) / down
    return 1.0


# -------------------------------------------------------------- compositing --

def font_at(size: int) -> ImageFont.FreeTypeFont:
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def cover_scale(size: tuple[int, int]) -> float:
    return max(W / size[0], H / size[1])


def draw_plate(canvas: Image.Image, beat: dict, t: float) -> None:
    path = os.path.join(PLATES, beat["file"])
    plate = Image.open(path).convert("RGB")

    push = beat.get("push", [1.0, 1.0])
    span = beat["tout"] - beat["tin"]
    k = 0.0 if span <= 0 else (t - beat["tin"]) / span
    factor = push[0] + (push[1] - push[0]) * k

    scale = cover_scale(plate.size) * factor
    new = (max(1, int(plate.width * scale)), max(1, int(plate.height * scale)))
    plate = plate.resize(new, Image.LANCZOS)

    layer = Image.new("RGB", (W, H), (0, 0, 0))
    layer.paste(plate, ((W - new[0]) // 2, (H - new[1]) // 2))

    alpha = opacity_at(beat, t)
    canvas.paste(Image.blend(canvas, layer, alpha))


def draw_mark(canvas: Image.Image, beat: dict, t: float) -> None:
    path = os.path.join(BRAND, beat["file"])
    mark = Image.open(path).convert("RGBA")

    target = beat["width"] / mark.width
    new = (max(1, int(mark.width * target)), max(1, int(mark.height * target)))
    mark = mark.resize(new, Image.LANCZOS)

    span = beat["tout"] - beat["tin"]
    k = 0.0 if span <= 0 else (t - beat["tin"]) / span
    rise = beat.get("rise", 0)
    y = beat["y"] - rise + rise * k

    alpha = opacity_at(beat, t)
    if alpha < 1.0:
        faded = mark.split()[3].point(lambda v: int(v * alpha))
        mark.putalpha(faded)

    canvas.paste(mark, (int(W / 2 - new[0] / 2), int(y - new[1] / 2)), mark)


COLORS = {"rot": ROT, "boneDim": BONE_DIM, "tar": TAR, None: BONE, "bone": BONE}


def draw_card(canvas: Image.Image, beat: dict, t: float) -> None:
    text = beat["text"]
    size = beat.get("size", 56)
    font = font_at(size)
    color = COLORS.get(beat.get("color"), BONE)

    # The .jsx tracks the type out at 180/1000 em; PIL has no tracking, so the
    # glyphs get spaced by hand to keep the same width on the sheet.
    track = size * 0.18
    advances = [font.getlength(ch) for ch in text]
    width = sum(advances) + track * (len(text) - 1)

    alpha = opacity_at(beat, t)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    pen = ImageDraw.Draw(layer)

    # AE positions a text layer by its BASELINE, so the sheet does too —
    # otherwise the safe area reads differently here than it does in the comp.
    baseline = beat.get("y", 880)
    x = W / 2 - width / 2
    for ch, advance in zip(text, advances):
        if ch != " ":
            pen.text((x, baseline), ch, font=font,
                     fill=color + (int(255 * alpha),), anchor="ls")
        x += advance + track

    canvas.paste(Image.alpha_composite(canvas.convert("RGBA"), layer).convert("RGB"))


def finish(canvas: Image.Image) -> Image.Image:
    """Grade, vignette and bars — the .jsx's top three layers."""
    # Grade: lift the shadows, then pull the white point in behind them.
    canvas = canvas.point(
        lambda v: min(255, int(255 * ((v / 255) ** (1 / GRADE_GAMMA)) / GRADE_WHITE)))

    # Vignette: a feathered ellipse, subtracted.
    veil = Image.new("L", (W, H), 255)
    ImageDraw.Draw(veil).ellipse([-320, -280, W + 320, H + 280], fill=0)
    veil = veil.filter(ImageFilter.GaussianBlur(150))
    veil = veil.point(lambda v: int(v * VIGNETTE))
    canvas = Image.composite(Image.new("RGB", (W, H), (0, 0, 0)), canvas, veil)

    # Letterbox.
    pen = ImageDraw.Draw(canvas)
    pen.rectangle([0, 0, W, BAR], fill=(0, 0, 0))
    pen.rectangle([0, H - BAR, W, H], fill=(0, 0, 0))
    return canvas


def frame_at(beats: list[dict], t: float) -> Image.Image:
    canvas = Image.new("RGB", (W, H), (0, 0, 0))

    beds = active(beats, ("plate", "black"), t)
    for bed in reversed(beds):
        if bed["type"] == "plate":
            draw_plate(canvas, bed, t)
        else:
            layer = Image.new("RGB", (W, H), TAR)
            canvas.paste(Image.blend(canvas, layer, opacity_at(bed, t)))

    for beat in reversed(active(beats, ("mark",), t)):
        draw_mark(canvas, beat, t)
    for beat in reversed(active(beats, ("card",), t)):
        draw_card(canvas, beat, t)

    return finish(canvas)


# ------------------------------------------------------------------- moments --

def moments(beats: list[dict]) -> list[tuple[float, str]]:
    """The times worth showing: every card, plus any plate no card sits on."""
    picks: list[tuple[float, str]] = []

    for beat in beats:
        if beat.get("type") == "card":
            mid = (beat["tin"] + beat["tout"]) / 2
            picks.append((mid, beat["text"]))

    cards = [b for b in beats if b.get("type") == "card"]
    for beat in beats:
        if beat.get("type") != "plate":
            continue
        covered = any(c["tin"] < beat["tout"] and c["tout"] > beat["tin"]
                      for c in cards)
        if not covered:
            mid = (beat["tin"] + beat["tout"]) / 2
            picks.append((mid, beat["file"].replace("demo_", "").replace(".png", "")))

    picks.sort(key=lambda p: p[0])
    return picks


def timecode(t: float) -> str:
    return "%02d:%02d:%02d" % (int(t) // 60, int(t) % 60, round((t % 1) * FPS))


def slug(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")[:34]


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    beats = load_beats(SCRIPT)
    picks = moments(beats)

    label_font = font_at(19)
    thumbs: list[tuple[Image.Image, str, str]] = []

    for index, (t, name) in enumerate(picks, start=1):
        frame = frame_at(beats, t)
        path = os.path.join(OUT, "storyboard-%02d-%s.png" % (index, slug(name)))
        frame.save(path)
        print(os.path.relpath(path, ROOT))
        thumbs.append((frame.resize((640, 360), Image.LANCZOS), timecode(t), name))

    # The sheet: four across, timecode and line under each.
    cols, pad, caption = 4, 16, 46
    rows = (len(thumbs) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * 640 + pad * (cols + 1),
                              rows * (360 + caption) + pad * (rows + 1)), (10, 6, 6))
    pen = ImageDraw.Draw(sheet)

    for index, (thumb, code, name) in enumerate(thumbs):
        col, row = index % cols, index // cols
        x = pad + col * (640 + pad)
        y = pad + row * (360 + caption + pad)
        sheet.paste(thumb, (x, y))
        pen.text((x + 2, y + 366), code, font=label_font, fill=ROT)
        pen.text((x + 92, y + 366), name[:52], font=label_font, fill=BONE_DIM)

    sheet_path = os.path.join(OUT, "storyboard-sheet.png")
    sheet.save(sheet_path)
    print(os.path.relpath(sheet_path, ROOT))
    print("\n%d moments, %.1fs cut at %d fps" % (len(picks), DURATION, FPS))


if __name__ == "__main__":
    main()
