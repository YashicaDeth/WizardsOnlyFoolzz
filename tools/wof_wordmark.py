"""Wizards Only Fools — the wordmark, cut rather than typed.

Greg's two existing marks set the brief. The CellOutz logo is a death-metal
wordmark: chiselled gothic letters fused into one mass, thorns sweeping off
every terminal and interlocking between letters, the whole thing pulled into a
lens-shaped envelope with a heraldic device dropped through the middle. The
Allusions Too Grandeur mark is the same language set on two lines.

WIZARDSONLYFOOLS is sixteen letters. At CellOutz's density that is a smear on
one line, so the default lockup stacks it the way Illusions does.

There is no font here and there is no font to buy. Every letter is built out of
one primitive — a broad-nib stroke, which is what blackletter actually is — and
the thorns are the same primitive with the width run down to nothing. That
means the mark is resolution-free, editable, and the SVG opens in Illustrator
with its layers intact.

Outputs, all into art/brand/:

  wof-wordmark-<variant>.svg   layered vector master, Illustrator-ready
  wof-wordmark-<variant>.png   finished raster with the metal treatment

Run:  python tools/wof_wordmark.py
"""

from __future__ import annotations

import math
import os
import random

# ---------------------------------------------------------------- geometry --

def _add(a, b):  return (a[0] + b[0], a[1] + b[1])
def _sub(a, b):  return (a[0] - b[0], a[1] - b[1])
def _mul(a, k):  return (a[0] * k, a[1] * k)

def _unit(v):
    length = math.hypot(v[0], v[1])
    if length < 1e-9:
        return (0.0, 0.0)
    return (v[0] / length, v[1] / length)

def _perp(v):
    return (-v[1], v[0])


def blade(a, b, wa, wb, skew_a=0.0, skew_b=0.0):
    """One broad-nib stroke.

    A pen with a flat nib does not make a rectangle: the ends are cut at the
    nib's angle, which is where blackletter's diamond terminals come from.
    `skew` slides the two corners of a cap in opposite directions along the
    stroke, so a stroke can be cut square (0.0) or raked (towards 1.0).
    """
    direction = _unit(_sub(b, a))
    normal = _perp(direction)
    return [
        _add(_add(a, _mul(normal, wa * 0.5)), _mul(direction, -skew_a * wa * 0.5)),
        _add(_add(b, _mul(normal, wb * 0.5)), _mul(direction, skew_b * wb * 0.5)),
        _add(_sub(b, _mul(normal, wb * 0.5)), _mul(direction, -skew_b * wb * 0.5)),
        _add(_sub(a, _mul(normal, wa * 0.5)), _mul(direction, skew_a * wa * 0.5)),
    ]


def thorn(base, tip, bend, width, steps=18, taper=2.3):
    """A spike: the same nib stroke with its width run down to a needle point.

    The centreline is a quadratic bezier so the thorn curves as it leaves the
    letter — a straight spike reads as a pin, a curved one reads as grown.
    `bend` is the control point.
    """
    left, right = [], []
    for step in range(steps + 1):
        t = step / steps
        inv = 1.0 - t
        at = (
            inv * inv * base[0] + 2 * inv * t * bend[0] + t * t * tip[0],
            inv * inv * base[1] + 2 * inv * t * bend[1] + t * t * tip[1],
        )
        ahead = (
            2 * inv * (bend[0] - base[0]) + 2 * t * (tip[0] - bend[0]),
            2 * inv * (bend[1] - base[1]) + 2 * t * (tip[1] - bend[1]),
        )
        normal = _perp(_unit(ahead))
        half = width * 0.5 * (inv ** taper)
        left.append(_add(at, _mul(normal, half)))
        right.append(_sub(at, _mul(normal, half)))
    return left + list(reversed(right))


def ring_segments(centre, radius, width, count=5, gap=0.10, steps=20):
    """A struck circle rather than a drawn one — it lifts where a stamp would."""
    out = []
    for index in range(count):
        start = math.tau * (index / count) + gap
        end = math.tau * ((index + 1) / count) - gap
        outer, inner = [], []
        for step in range(steps + 1):
            angle = start + (end - start) * (step / steps)
            unit = (math.cos(angle), math.sin(angle))
            outer.append(_add(centre, _mul(unit, radius + width * 0.5)))
            inner.append(_add(centre, _mul(unit, radius - width * 0.5)))
        out.append(outer + list(reversed(inner)))
    return out


# ------------------------------------------------------------------ glyphs --
#
# Cap height is 1.0 with y running down: 0.0 is the cap line, 1.0 the baseline.
# Everything below is in those units, so the whole alphabet scales as one.

STEM = 0.265          # stem width — heavy, because thin gothic dies at favicon size
NIB = 0.62            # how far the diamond terminals overhang the stem
RAKE = 0.55           # how hard the nib cuts the ends of a stroke

# A stroke is (x0, y0, x1, y1, w0, w1) with the last two optional; a missing
# width falls back to STEM. Skew is applied globally by the nib angle.
def _stroke(x0, y0, x1, y1, w0=STEM, w1=None, skew=RAKE):
    return blade((x0, y0), (x1, y1), w0, w1 if w1 is not None else w0, skew, skew)


def _stem(cx, top=0.0, bottom=1.0, width=STEM):
    """A vertical with a blackletter head and foot.

    The head and foot are separate nib strokes laid across the stem at the pen
    angle. That is how a real broad nib makes them, and it is why they slant
    the same way at both ends instead of mirroring.
    """
    over = width * NIB
    return [
        _stroke(cx, top, cx, bottom, width),
        _stroke(cx - over, top + width * 0.46, cx + over, top - width * 0.16, width * 0.60),
        _stroke(cx - over, bottom - width * 0.16, cx + over, bottom + width * 0.46, width * 0.60),
    ]


# Each entry: advance width, the strokes, and the thorn roots.
# A thorn root is (x, y, angle_degrees, length, curl, width) — angle is measured
# with 0 pointing right and negative pointing up, curl bends it anticlockwise.
GLYPHS: dict[str, dict] = {}


def _glyph(char, advance, strokes, thorns=()):
    GLYPHS[char] = {"advance": advance, "strokes": strokes, "thorns": list(thorns)}


_glyph("I", 0.62, _stem(0.31),
       [(0.31, 0.02, -74, 0.52, 0.30, 0.17), (0.31, 0.98, 104, 0.34, -0.28, 0.15)])

_glyph("L", 0.98, _stem(0.30, bottom=0.94) + [
    _stroke(0.24, 0.96, 0.92, 0.88, STEM * 0.92, STEM * 0.55),
], [(0.30, 0.02, -78, 0.50, 0.26, 0.17), (0.92, 0.88, -8, 0.44, -0.30, 0.13)])

_glyph("F", 0.94, _stem(0.32, bottom=1.0) + [
    _stroke(0.28, 0.10, 0.90, 0.02, STEM * 0.82, STEM * 0.48),
    _stroke(0.20, 0.50, 0.82, 0.45, STEM * 0.68, STEM * 0.44),
], [(0.90, 0.02, -30, 0.52, 0.26, 0.15), (0.32, 0.98, 100, 0.32, -0.22, 0.13)])

_glyph("N", 1.26, _stem(0.30) + _stem(0.96) + [
    _stroke(0.30, 0.08, 0.96, 0.92, STEM * 0.80),
], [(0.30, 0.02, -80, 0.46, 0.24, 0.15), (0.96, 0.02, -68, 0.50, 0.22, 0.15)])

_glyph("W", 1.52, [
    _stroke(0.08, 0.02, 0.40, 1.00, STEM * 0.98, STEM * 0.70),
    _stroke(0.40, 1.00, 0.72, 0.16, STEM * 0.70, STEM * 0.88),
    _stroke(0.72, 0.16, 1.04, 1.00, STEM * 0.88, STEM * 0.70),
    _stroke(1.04, 1.00, 1.42, 0.02, STEM * 0.70, STEM * 0.98),
    _stroke(0.00, 0.06, 0.20, -0.06, STEM * 0.52),
    _stroke(1.30, -0.06, 1.50, 0.06, STEM * 0.52),
], [(0.06, 0.00, -104, 0.68, 0.34, 0.18), (1.44, 0.00, -76, 0.68, -0.34, 0.18),
    (0.72, 0.16, -90, 0.40, 0.00, 0.13)])

_glyph("Z", 1.02, [
    _stroke(0.04, 0.10, 0.92, 0.04, STEM * 0.80),
    _stroke(0.88, 0.10, 0.14, 0.90, STEM * 0.92),
    _stroke(0.02, 0.92, 0.98, 0.97, STEM * 0.80),
], [(0.92, 0.04, -34, 0.50, 0.24, 0.15), (0.02, 0.92, 150, 0.44, 0.26, 0.15)])

_glyph("A", 1.10, [
    _stroke(0.04, 1.00, 0.52, 0.04, STEM * 1.00, STEM * 0.74),
    _stroke(0.52, 0.04, 1.02, 1.00, STEM * 0.74, STEM * 1.00),
    _stroke(0.20, 0.68, 0.86, 0.64, STEM * 0.62),
], [(0.52, 0.02, -90, 0.56, 0.00, 0.17), (0.04, 1.00, 168, 0.38, -0.22, 0.13)])

_glyph("R", 1.12, _stem(0.28) + [
    _stroke(0.26, 0.08, 0.92, 0.22, STEM * 0.80),
    _stroke(0.92, 0.22, 0.34, 0.54, STEM * 0.80),
    _stroke(0.52, 0.50, 1.06, 1.00, STEM * 0.84),
], [(0.28, 0.02, -80, 0.48, 0.24, 0.15), (1.06, 1.00, 12, 0.46, -0.26, 0.15)])

_glyph("D", 1.16, _stem(0.26) + [
    _stroke(0.24, 0.06, 0.98, 0.32, STEM * 0.82),
    _stroke(0.98, 0.32, 0.98, 0.68, STEM * 0.82),
    _stroke(0.98, 0.68, 0.24, 0.96, STEM * 0.82),
], [(0.26, 0.02, -82, 0.48, 0.26, 0.15), (0.98, 0.50, -4, 0.40, 0.00, 0.13)])

_glyph("S", 1.04, [
    _stroke(0.94, 0.18, 0.34, 0.04, STEM * 0.74),
    _stroke(0.34, 0.04, 0.12, 0.30, STEM * 0.74, STEM * 0.84),
    _stroke(0.12, 0.30, 0.80, 0.58, STEM * 0.84),
    _stroke(0.80, 0.58, 0.96, 0.78, STEM * 0.84),
    _stroke(0.96, 0.78, 0.30, 0.98, STEM * 0.84, STEM * 0.72),
], [(0.94, 0.18, -52, 0.50, 0.28, 0.15), (0.30, 0.98, 152, 0.46, 0.26, 0.15)])

_glyph("O", 1.02, [
    _stroke(0.50, 0.00, 0.94, 0.26, STEM * 0.78),
    _stroke(0.94, 0.26, 0.90, 0.72, STEM * 0.78),
    _stroke(0.90, 0.72, 0.50, 1.00, STEM * 0.78),
    _stroke(0.50, 1.00, 0.10, 0.72, STEM * 0.78),
    _stroke(0.10, 0.72, 0.06, 0.26, STEM * 0.78),
    _stroke(0.06, 0.26, 0.50, 0.00, STEM * 0.78),
], [(0.50, 0.00, -90, 0.42, 0.12, 0.15), (0.50, 1.00, 90, 0.34, -0.12, 0.13)])

_glyph("Y", 1.10, [
    _stroke(0.04, 0.04, 0.54, 0.54, STEM * 0.92, STEM * 0.76),
    _stroke(1.06, 0.04, 0.54, 0.54, STEM * 0.92, STEM * 0.76),
    _stroke(0.54, 0.50, 0.54, 1.00, STEM),
    _stroke(0.54 - STEM * NIB, 1.00 - STEM * 0.16, 0.54 + STEM * NIB, 1.00 + STEM * 0.46, STEM * 0.60),
], [(0.04, 0.04, -106, 0.60, 0.30, 0.17), (1.06, 0.04, -74, 0.60, -0.30, 0.17)])

# Added for "ALLUSIONS TOO GRANDEUR" — the original twelve only covered
# WIZARDSONLYFOOLS. Same primitive, same unit system, same rule: a thorn root
# only where a stroke actually ends in open air.

_glyph("E", 0.92, _stem(0.32, bottom=1.0) + [
    _stroke(0.28, 0.10, 0.88, 0.02, STEM * 0.80, STEM * 0.46),
    _stroke(0.20, 0.50, 0.78, 0.45, STEM * 0.66, STEM * 0.42),
    _stroke(0.28, 0.96, 0.90, 0.90, STEM * 0.80, STEM * 0.48),
], [(0.90, 0.02, -30, 0.48, 0.24, 0.14), (0.90, 0.90, -10, 0.42, -0.22, 0.13)])

# The bowl reuses O's six-point circle almost exactly, broken open on the
# right where a real G's bowl stops, with a short inward spur closing part of
# the gap — the one feature that keeps it from just being a broken O.
_glyph("G", 1.06, [
    _stroke(0.54, 0.00, 0.96, 0.26, STEM * 0.78),
    _stroke(0.96, 0.26, 0.94, 0.62, STEM * 0.78),
    _stroke(0.94, 0.62, 0.60, 0.58, STEM * 0.70, STEM * 0.85),
    _stroke(0.94, 0.72, 0.54, 1.00, STEM * 0.78),
    _stroke(0.54, 1.00, 0.12, 0.72, STEM * 0.78),
    _stroke(0.12, 0.72, 0.08, 0.26, STEM * 0.78),
    _stroke(0.08, 0.26, 0.54, 0.00, STEM * 0.78),
], [(0.54, 0.00, -90, 0.42, 0.12, 0.15), (0.54, 1.00, 90, 0.34, -0.12, 0.13)])

_glyph("T", 0.96, [
    _stroke(0.48, 0.10, 0.48, 1.00, STEM),
    _stroke(0.48 - STEM * NIB * 0.7, 1.00 - STEM * 0.16, 0.48 + STEM * NIB * 0.7, 1.00 + STEM * 0.46, STEM * 0.60),
    _stroke(0.04, 0.14, 0.92, 0.02, STEM * 0.95, STEM * 0.68),
], [(0.04, 0.14, -104, 0.54, 0.30, 0.16), (0.92, 0.02, -66, 0.54, -0.28, 0.16)])

# A blackletter U keeps its head serifs (like N's own two stems) and drops
# the feet, closing in a shallow three-segment bowl instead — a full circle
# reads as a second O, and a real broad-nib U is flatter than that.
_glyph("U", 1.26, [
    _stroke(0.30, 0.00, 0.30, 0.76, STEM),
    _stroke(0.30 - STEM * NIB, STEM * 0.46, 0.30 + STEM * NIB, -STEM * 0.16, STEM * 0.60),
    _stroke(0.96, 0.00, 0.96, 0.76, STEM),
    _stroke(0.96 - STEM * NIB, STEM * 0.46, 0.96 + STEM * NIB, -STEM * 0.16, STEM * 0.60),
    _stroke(0.30, 0.76, 0.40, 0.96, STEM * 0.90, STEM * 0.70),
    _stroke(0.40, 0.96, 0.86, 0.96, STEM * 0.70),
    _stroke(0.86, 0.96, 0.96, 0.76, STEM * 0.70, STEM * 0.90),
], [(0.30, 0.02, -80, 0.46, 0.24, 0.15), (0.96, 0.02, -68, 0.50, 0.22, 0.15)])

SPACE_ADVANCE = 0.34


# ------------------------------------------------------------------ device --

def algiz(centre, height, bar, facing=1.0):
    """ᛉ in solid bars — the mark that is already on the game's own logo.

    Greg's existing Wizards Only Fools artwork has this rune stamped over the
    photographed hand sign, cut as hard-edged bars of one weight with the ends
    square. The hand sign is the rune: two finger pairs are the arms, the wrist
    is the stem. So it goes in the middle of the wordmark, where CellOutz puts
    its padlock — the device is not decoration, it is the title.

    `facing` is 1 for upright and -1 for reversed. Upright is life and
    protection, which is the one that goes on the logo. Reversed is ᛦ, death,
    and the same three strokes inside a ring are the peace badge — that is the
    game's argument about the symbol, and it belongs in the game, not on the
    front of the box.
    """
    cx, cy = centre
    half = height * 0.5
    root = cy + half * facing
    crown = cy - half * facing
    # The arms leave the stem below halfway and climb to exactly the stem's own
    # top. Overshooting reads as a Y in a circle; stopping short reads as an
    # arrow. Level with the crown is what makes it algiz.
    joint = root - height * 0.56 * facing
    rise = height * 0.44 * facing
    span = height * 0.46
    return [
        blade((cx, crown), (cx, root), bar, bar),
        blade((cx, joint), (cx - span, joint - rise), bar, bar),
        blade((cx, joint), (cx + span, joint - rise), bar, bar),
    ]


# ------------------------------------------------------------------ layout --

def _transform(points, scale, offset):
    return [(p[0] * scale + offset[0], p[1] * scale + offset[1]) for p in points]


def layout_line(text, tracking=-0.055):
    """Place one line's glyphs. Tracking is negative so the letters fuse."""
    placed, pen = [], 0.0
    for char in text:
        if char == " ":
            pen += SPACE_ADVANCE
            continue
        glyph = GLYPHS[char]
        placed.append((char, pen))
        pen += glyph["advance"] + tracking
    return placed, max(pen - tracking, 0.0)


def build(lines, seed=1312, line_gap=0.30, device=True):
    """Assemble the whole mark and return it as named layers of polygons.

    Every line is scaled to the width of the widest one. That is what makes a
    death-metal lockup read as a single block rather than as stacked words, and
    it is the same thing the Illusions Too Grandeur mark does.
    """
    rng = random.Random(seed)
    measured = [layout_line(text) for text in lines]
    target = max(width for _, width in measured)

    letters, thorns = [], []
    line_edges = []
    y_cursor = 0.0
    last_scale = 1.0

    for (placed, width) in measured:
        scale = target / width if width > 0 else 1.0
        for char, pen in placed:
            glyph = GLYPHS[char]
            offset = (pen * scale, y_cursor)
            for polygon in glyph["strokes"]:
                letters.append(_transform(polygon, scale, offset))
            for (tx, ty, angle, length, curl, tw) in glyph["thorns"]:
                base = (tx * scale + offset[0], ty * scale + offset[1])
                jitter = rng.uniform(-7.0, 7.0)
                radians = math.radians(angle + jitter)
                reach = length * scale * rng.uniform(0.85, 1.20)
                direction = (math.cos(radians), math.sin(radians))
                base = _sub(base, _mul(direction, STEM * scale * 0.55))
                tip = _add(base, _mul(direction, reach))
                sideways = _mul(_perp(direction), curl * scale * 1.05)
                bend = _add(_add(base, _mul(direction, reach * 0.5)), sideways)
                thorns.append(thorn(base, tip, bend, tw * scale))
        line_edges.append((0.0, width * scale, y_cursor + 0.5 * scale, scale))
        last_scale = scale
        y_cursor += (1.0 + line_gap) * scale

    height = y_cursor - line_gap * last_scale
    centre = (target * 0.5, height * 0.5)

    # The long sweeping spikes that close the silhouette into a lens. They are
    # anchored on the outermost letter of each line, at that line's own middle,
    # so they grow out of the W and the S rather than out of thin air — a spike
    # that starts in the gap between lines reads as a separate starburst.
    #
    # Two per side, not three, and both swept away from the centre line: three
    # evenly-spread spikes came out as a horizontal arrow, which is a dart and
    # not a thorn. These carry a low taper so they stay a blade most of their
    # length instead of collapsing to a hair as soon as they leave the letter.
    for (left_x, right_x, middle, line_h) in line_edges:
        for side, edge in ((-1, left_x), (1, right_x)):
            anchor = (edge + side * line_h * 0.04, middle)
            for (rise, reach, weight, lift) in (
                (-0.86, 1.28, 0.26, -0.46), (0.46, 0.52, 0.15, 0.30),
            ):
                tip = (anchor[0] + side * line_h * reach, middle + line_h * rise)
                bend = (anchor[0] + side * line_h * reach * 0.62,
                        middle + line_h * lift * 0.30)
                thorns.append(thorn(anchor, tip, bend, weight * line_h, taper=1.35))

    layers = {"letters": letters, "thorns": thorns, "device": []}

    if device:
        # It rides above the word rather than sitting in the middle. Centred,
        # a device big enough to read swallowed the A and the F and the mark
        # stopped saying its own name — which is the one thing it has to do.
        # Above is where an upright rune wants to be anyway: its mass is at the
        # top, so hung underneath it buries itself in the letters, and the gap
        # between the crown thorns is already open.
        size = height * 0.52
        seat = (centre[0], -height * 0.30)
        layers["device"] += ring_segments(seat, size * 0.50, size * 0.095)
        layers["device"] += algiz(seat, size * 0.84, size * 0.150)

    bounds = _bounds([p for group in layers.values() for p in group])
    return layers, bounds


def _bounds(polygons):
    xs = [p[0] for polygon in polygons for p in polygon]
    ys = [p[1] for polygon in polygons for p in polygon]
    return (min(xs), min(ys), max(xs), max(ys))


# ------------------------------------------------------------------- emit ----

LAYER_ORDER = ("thorns", "letters", "device")

# How far the letters are cleared back around the device, as a fraction of the
# device's own size. Without this the rune is drawn in the same black as the
# letters on top of the densest part of the word and simply disappears — which
# is what a first pass did. The reference solves it the same way: the padlock
# sits in a well the letters arch around.
WELL = 0.15
LINE_BREAK = chr(10)


def _well_width(layers, bounds):
    if not layers.get("device"):
        return 0.0
    x0, y0, x1, y1 = _bounds(layers["device"])
    return max(x1 - x0, y1 - y0) * WELL


def to_svg(layers, bounds, pad=0.12, fill="#0a0806", stroke="#a8281a"):
    """The vector master. One SVG group per layer, named, so Illustrator opens
    it with Thorns / Letters / Device as separate editable layers.

    The letters and thorns are masked by a fattened copy of the device, so the
    well is part of the artwork rather than something to clean up by hand after
    import.
    """
    x0, y0, x1, y1 = bounds
    margin = (y1 - y0) * pad
    x0, y0, x1, y1 = x0 - margin, y0 - margin, x1 + margin, y1 + margin
    width, height = x1 - x0, y1 - y0
    well = _well_width(layers, bounds)

    def polygons(group, extra=""):
        out = []
        for polygon in group:
            points = " ".join(f"{x:.4f},{y:.4f}" for x, y in polygon)
            out.append(f'<polygon points="{points}"{extra}/>')
        return out

    out = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        f'<svg xmlns="http://www.w3.org/2000/svg" '
        f'xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape" viewBox="{x0:.4f} {y0:.4f} '
        f'{width:.4f} {height:.4f}" width="{width * 260:.0f}" '
        f'height="{height * 260:.0f}">',
        '<title>Wizards Only Fools</title>',
    ]

    if well > 0.0:
        out.append('<defs><mask id="device-well" maskUnits="userSpaceOnUse" '
                   f'x="{x0:.4f}" y="{y0:.4f}" width="{width:.4f}" height="{height:.4f}">')
        out.append(f'<rect x="{x0:.4f}" y="{y0:.4f}" width="{width:.4f}" '
                   f'height="{height:.4f}" fill="#fff"/>')
        out.append(f'<g fill="#000" stroke="#000" stroke-width="{well:.4f}" '
                   'stroke-linejoin="round">')
        out += polygons(layers["device"])
        out.append('</g></mask></defs>')

    masked = ' mask="url(#device-well)"' if well > 0.0 else ""
    line = f'{width * 0.0012:.4f}'
    for name in LAYER_ORDER:
        group = layers.get(name, [])
        if not group:
            continue
        attrs = "" if name == "device" else masked
        out.append(f'<g id="{name}" inkscape:label="{name.title()}"{attrs} '
                   f'fill="{fill}" stroke="{stroke}" stroke-width="{line}">')
        out += polygons(group)
        out.append('</g>')
    out.append('</svg>')
    return LINE_BREAK.join(out)


def _raster_mask(layers, bounds, width_px, pad=0.12, supersample=3):
    """One black silhouette of the whole mark, drawn big and shrunk back down —
    PIL has no anti-aliased polygon fill, so the supersample is the anti-alias.

    Returns the mask and the placement (x0, y0, scale) so other passes — the
    blood, the texture — can put things in the same coordinate space.
    """
    from PIL import Image, ImageChops, ImageDraw, ImageFilter

    x0, y0, x1, y1 = bounds
    margin = (y1 - y0) * pad
    x0, y0, x1, y1 = x0 - margin, y0 - margin, x1 + margin, y1 + margin
    scale = width_px / (x1 - x0)
    height_px = max(1, int(round((y1 - y0) * scale)))
    size = (width_px * supersample, height_px * supersample)

    def stamp(groups):
        image = Image.new("L", size, 0)
        pen = ImageDraw.Draw(image)
        for group in groups:
            for polygon in layers.get(group, []):
                pen.polygon(
                    [((x - x0) * scale * supersample, (y - y0) * scale * supersample)
                     for x, y in polygon],
                    fill=255,
                )
        return image

    art = stamp(("thorns", "letters"))
    device = stamp(("device",))

    well = _well_width(layers, bounds) * scale * supersample
    if well > 0.5:
        # MaxFilter needs an odd kernel; this is the dilation that opens the well.
        radius = int(well) | 1
        spread = device
        while radius > 1:
            step = min(radius, 9) | 1
            spread = spread.filter(ImageFilter.MaxFilter(step))
            radius -= step - 1
            if step <= 1:
                break
        art = ImageChops.subtract(art, spread)

    combined = ImageChops.lighter(art, device)
    return combined.resize((width_px, height_px), Image.LANCZOS), (x0, y0, scale)


# -------------------------------------------------------------- treatment ---
#
# The palette is read off Greg's own CellOutz mark: a black core, arterial red
# through the middle of every stroke, a bone rim light along the top-left of
# each edge where a light source above and left would catch cast metal, and a
# black spray halo holding the whole thing off the page. Then blood.

VOID = (10, 6, 5)
RUST = (86, 16, 12)
ARTERIAL = (168, 34, 22)
EMBER = (222, 62, 34)
BONE = (240, 205, 180)


def _shift(image, dx, dy):
    from PIL import Image
    moved = Image.new(image.mode, image.size, 0)
    moved.paste(image, (dx, dy))
    return moved


def _erode(image, radius):
    from PIL import ImageFilter
    out = image
    left = max(1, int(radius))
    while left > 0:
        step = min(left, 4) * 2 + 1
        out = out.filter(ImageFilter.MinFilter(step))
        left -= step // 2
    return out


def _vertical_ramp(size, stops):
    """A vertical gradient built from (position, colour) stops."""
    from PIL import Image
    width, height = size
    column = Image.new("RGB", (1, height))
    pixels = column.load()
    for y in range(height):
        t = y / max(1, height - 1)
        lower = stops[0]
        upper = stops[-1]
        for index in range(len(stops) - 1):
            if stops[index][0] <= t <= stops[index + 1][0]:
                lower, upper = stops[index], stops[index + 1]
                break
        span = max(1e-6, upper[0] - lower[0])
        local = (t - lower[0]) / span
        pixels[0, y] = tuple(
            int(round(lower[1][channel] + (upper[1][channel] - lower[1][channel]) * local))
            for channel in range(3)
        )
    return column.resize((width, height))


def _crack_texture(size, seed, density=0.34):
    """The broken, corroded fill. Noise pushed through a blur and a threshold
    breaks into plates and veins, which is close enough to cast-and-cracked."""
    from PIL import Image, ImageFilter
    rng = random.Random(seed)
    small = Image.new("L", (max(2, size[0] // 4), max(2, size[1] // 4)))
    small.putdata([rng.randrange(256) for _ in range(small.size[0] * small.size[1])])
    grown = small.resize(size, Image.BICUBIC).filter(ImageFilter.GaussianBlur(1.2))
    cut = int(255 * (1.0 - density))
    return grown.point(lambda value: 255 if value > cut else int(value * 0.55))


def render(layers, bounds, width_px=2200, seed=1312, pad=0.12, blood=True):
    """The finished raster: the same geometry as the SVG, dressed."""
    from PIL import Image, ImageChops, ImageDraw, ImageFilter

    mask, placement = _raster_mask(layers, bounds, width_px, pad=pad)
    size = mask.size
    rng = random.Random(seed + 7)

    # The halo first, so everything else sits on top of it.
    halo = mask.filter(ImageFilter.GaussianBlur(width_px * 0.0055))
    halo = halo.point(lambda v: min(255, int(v * 2.6)))

    body = _vertical_ramp(size, [
        (0.00, RUST), (0.18, ARTERIAL), (0.46, EMBER),
        (0.72, ARTERIAL), (1.00, RUST),
    ])
    body = ImageChops.multiply(body, Image.merge("RGB", (_crack_texture(size, seed),) * 3))

    # A thin black outline and then red all the way in. The first pass eroded
    # the core hard and laid a fat bone bevel over the rest, which turned every
    # stroke into pink piping — cast metal is a dark body with a bright line
    # where one edge catches, not a tube.
    outline = max(1, int(width_px * 0.0020))
    core = _erode(mask, outline)
    art = Image.new("RGB", size, VOID)
    art.paste(body, (0, 0), core)

    # One light, above and to the left: the rim sits inside the outline on the
    # upper-left of every edge and nowhere else.
    rim = max(1, int(width_px * 0.0016))
    lip = ImageChops.subtract(core, _shift(_erode(core, rim), rim, rim))
    art.paste(Image.new("RGB", size, BONE), (0, 0), lip.point(lambda v: int(v * 0.82)))

    # A dull heat on the opposite edge so the metal has a back, well under the
    # rim so it never competes with it.
    under = ImageChops.subtract(core, _shift(_erode(core, rim), -rim, -rim))
    art.paste(Image.new("RGB", size, EMBER), (0, 0), under.point(lambda v: int(v * 0.30)))

    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.paste((0, 0, 0, 255), (0, 0), halo)
    out.paste(art.convert("RGBA"), (0, 0), mask)

    if blood:
        # Room under the mark for the blood to actually run into. Greg: the mark
        # "needs more blood that drips into the backround and melts" — nothing
        # can melt into anything while the canvas stops where the letters do,
        # which is why the old drips all ended in a bead a few pixels short of
        # the edge. The mask is extended with it so `_bleed` still finds the
        # same lowest-lit row per column.
        room = int(width_px * 0.17)
        tall = Image.new("RGBA", (size[0], size[1] + room), (0, 0, 0, 0))
        tall.paste(out, (0, 0))
        tall_mask = Image.new("L", (size[0], size[1] + room), 0)
        tall_mask.paste(mask, (0, 0))
        out, mask, size = tall, tall_mask, tall.size
        _bleed(out, mask, rng, width_px)

    grain = Image.new("L", size)
    grain.putdata([rng.randrange(228, 256) for _ in range(size[0] * size[1])])
    out = Image.composite(ImageChops.multiply(out.convert("RGB"),
                                              Image.merge("RGB", (grain,) * 3)).convert("RGBA"),
                          out, mask)
    return out


def _bleed(canvas, mask, rng, width_px):
    """Blood off the lowest edge of the mark.

    Greg: the mark *"needs more blood that drips into the backround and melts"*.
    The first pass gave it six stubby runs that each ended on a hard bead a few
    pixels below the letters, which reads as six thermometers rather than as
    something bleeding.

    So: sixteen runs instead of six, lengths spread from a bead to a long
    runner, and every run losing both weight *and* opacity as it falls, so the
    tail goes into the page instead of stopping on an edge. A few beads let go
    and fall on their own under the longest runs. The part that actually reads
    as melting is the blurred wash underneath them.

    Drawn on two transparent layers and alpha-composited, because PIL's draw
    *replaces* pixels rather than blending them — drawing a half-alpha drip
    straight onto the canvas punches a hole through the letter behind it.
    """
    from PIL import Image, ImageDraw, ImageFilter
    columns = mask.size[0]
    floor = mask.load()

    picks = []
    for _ in range(220):
        x = rng.randrange(int(columns * 0.14), int(columns * 0.88))
        if any(abs(x - taken) < width_px * 0.019 for taken, _ in picks):
            continue
        lowest = None
        for y in range(mask.size[1] - 1, 0, -1):
            if floor[x, y] > 140:
                lowest = y
                break
        if lowest is not None:
            picks.append((x, lowest))
    picks = picks[:16]

    # Geometry first, so the wash can be laid down under the drips that cast it
    # without drawing either of them twice.
    runs = []
    for index, (x, top) in enumerate(picks):
        runner = index % 3 == 0
        length = (rng.uniform(0.11, 0.27) if runner else rng.uniform(0.015, 0.075)) * width_px
        runs.append({
            "x": x, "top": top, "length": length, "runner": runner,
            "head": rng.uniform(0.0030, 0.0058) * width_px,
            "drift": rng.uniform(-0.5, 0.5),
            "bead": rng.random() < 0.8,
            "bead_at": rng.uniform(1.08, 1.45),
            "bead_size": rng.uniform(0.45, 0.8),
            "bead_alpha": rng.randrange(70, 150),
        })

    wash = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    wash_pen = ImageDraw.Draw(wash)
    drips = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    pen = ImageDraw.Draw(drips)

    for run in runs:
        steps = max(8, int(run["length"] / 1.6))
        for step in range(steps + 1):
            t = step / steps
            y = run["top"] + run["length"] * t
            # Heavy where it tears off the metal, necked as it falls, swollen
            # again at the bead.
            radius = run["head"] * (1.0 - 0.78 * t) + run["head"] * 1.05 * (t ** 6)
            # The melt. Opacity falls away with the run, so a long runner is
            # solid where it leaves the letter and gone by the time it lands.
            alpha = int(255 * max(0.0, 1.0 - t ** 1.35))
            if alpha <= 2:
                continue
            cx = run["x"] + run["drift"] * run["length"] * (t ** 2)
            pen.ellipse([cx - radius, y - radius, cx + radius, y + radius],
                        fill=(146, 12, 9, alpha))
            if run["runner"]:
                halo = radius * 3.4
                wash_pen.ellipse([cx - halo, y - halo, cx + halo, y + halo],
                                 fill=(96, 8, 6, int(alpha * 0.20)))
        if run["runner"] and run["bead"]:
            fall = run["top"] + run["length"] * run["bead_at"]
            size = run["head"] * run["bead_size"]
            cx = run["x"] + run["drift"] * run["length"]
            pen.ellipse([cx - size, fall - size, cx + size, fall + size],
                        fill=(146, 12, 9, run["bead_alpha"]))

    canvas.alpha_composite(wash.filter(ImageFilter.GaussianBlur(width_px * 0.011)))
    canvas.alpha_composite(drips)


# ------------------------------------------------------------------ export --

OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                       "art", "brand")

# Three lockups, because one shape cannot do all three jobs. The stacked mark is
# the logo. The banner is what fits a site header without shrinking to nothing.
# The seal is what survives at 32 pixels, where letters never do.
VARIANTS = {
    "stacked": dict(lines=["WIZARDS", "ONLYFOOLS"], line_gap=0.30, device=True),
    "banner": dict(lines=["WIZARDS ONLY FOOLS"], line_gap=0.30, device=False),
    "seal": dict(lines=[], line_gap=0.0, device=True),
    # The algiz rune is Wizards Only Foolz's own device — Allusions to
    # Grandeur is the game itself, not that faction, so this carries no
    # device at all: letters, thorns and blood only.
    "grandeur": dict(lines=["ALLUSIONS", "TOO GRANDEUR"], line_gap=0.30, device=False),
}


def build_variant(name, seed=1312):
    spec = VARIANTS[name]
    if not spec["lines"]:
        # The seal on its own: the ring and the rune at the size they would be
        # inside the stacked lockup, lifted out of it.
        size = 1.0
        centre = (0.0, 0.0)
        layers = {
            "letters": [], "thorns": [],
            "device": ring_segments(centre, size * 0.50, size * 0.095)
                      + algiz(centre, size * 0.84, size * 0.150),
        }
        return layers, _bounds(layers["device"])
    return build(spec["lines"], seed=seed, line_gap=spec["line_gap"],
                 device=spec["device"])


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    written = []
    for name in VARIANTS:
        layers, bounds = build_variant(name)
        pad = 0.22 if name == "seal" else 0.12

        svg_path = os.path.join(OUT_DIR, f"wof-wordmark-{name}.svg")
        with open(svg_path, "w", encoding="utf-8") as handle:
            handle.write(to_svg(layers, bounds, pad=pad))
        written.append(svg_path)

        for width in (2400, 960):
            image = render(layers, bounds, width_px=width, pad=pad,
                           blood=(name != "seal"))
            png_path = os.path.join(OUT_DIR, f"wof-wordmark-{name}-{width}.png")
            image.save(png_path)
            written.append(png_path)

        # Flat black, for screen print, stencils and anywhere one colour is all
        # there is. Same geometry, no treatment.
        mask, _ = _raster_mask(layers, bounds, 2400, pad=pad)
        from PIL import Image
        flat = Image.new("RGBA", mask.size, (0, 0, 0, 0))
        flat.paste((10, 6, 5, 255), (0, 0), mask)
        flat_path = os.path.join(OUT_DIR, f"wof-wordmark-{name}-flat.png")
        flat.save(flat_path)
        written.append(flat_path)

    for path in written:
        print(os.path.relpath(path, os.path.dirname(OUT_DIR)))


if __name__ == "__main__":
    main()
