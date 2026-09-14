# The two things the intake did not answer

`DESIGN/REFERENCE_INTAKE_2026-09-14.md` and `DESIGN/RITUAL_AND_KARMA.md` already
cover most of Greg's reference dump. Neither mentions the Qliphoth or the
swastika, and he asked about both directly. This file is only those two, so it
does not duplicate work another agent already did.

---

## 1. The flipped tree — built

> Greg: *"the evil qliphoth this is the flipped tree i meant"* and *"tree of
> life and how the tree should look in game this should be the ui and the
> qilplithoth should flip this"*

`systems/sephiroth.gd` already carried the ten sephiroth, the tradition's own
twenty-two paths, Da'ath positioned-but-unreachable, and per-node faction
leanings. It had no shadow. It does now.

Added: `QLIPHOTH`, `QLIPHOTH_MEANINGS`, `qliphoth_position()`, `qliphah()` and
`face(inverted)` — one call returns either face of the tree, so the flip is a
parameter rather than a second renderer that drifts out of sync with the first.

The husks are the tradition's own, not invented: Thaumiel, Chaigidel,
Sathariel, Gamchicoth, Golachab, Thagirion, A'arab Zaraq, Samael, Gamaliel,
Nehemoth. Each is the recognised counterpart of the sephirah at the same
position, which is why the flip is literally a flip on the layout already in
`POSITIONS` — no new geometry. Da'ath has no shell, for the same reason it has
no path: the abyss is the gap between things, and a gap does not invert.

Why the game wants it: the tree above is the ascent `AR` charts and `AV` gates.
The husks are the same ladder read downward, and that is where this world's low
register actually lives — the CellOutz side, the things that feed, the debt that
is in the meat. A player descending is not off the tree. They are on its other
face.

---

## 2. The swastika — the fact-check Greg asked for

> *"the lore behind the swastika which should be a sigil you see used by the
> tibetan inspired tribnes that live locally in the mountains also inspired by
> the aborignal elders"*

### The ancient history is real

It is a genuinely ancient and widespread symbol, independently attested across
unconnected cultures: Indus Valley seals, Bronze Age Europe, Greek meander
borders, Ethiopian and Byzantine church decoration, pre-Columbian America. In
Hinduism, Buddhism and Jainism it is a *living* sacred symbol — it marks temple
thresholds and Buddhist texts to this day. The Sanskrit *svastika* means roughly
"conducive to well-being".

The Tibetan link Greg reached for is the strongest part: the left-facing form is
specifically associated with Tibetan Bon and Tibetan Buddhism, where it signifies
**permanence**. "A sigil used by mountain tribes with Tibetan influence" is
historically coherent rather than invented.

### Two corrections, both load-bearing

**The Aboriginal Australian half does not hold.** There is no broad traditional
Aboriginal use comparable to the Dharmic one. Some early-20th-century Australian
material exists, but it is colonial-era, not deep tradition. Fusing "Tibetan
*and* Aboriginal elders" through this symbol would join two unrelated things and
attribute a practice to living peoples that is not theirs. The Tibetan/Bon line
is the one with ground under it; the Aboriginal influence is better carried by
something else entirely — and there is plenty to draw on that is actually
attested.

**The practical reality, which is not a moral objection.** In Europe, Australia
and most of the West this symbol reads as Nazi iconography first and everything
else second — regardless of orientation, context or intent, and regardless of
the five thousand years before 1920. Germany restricts it criminally. Steam,
console certification and storefronts have rejected builds over it.

So the recommendation is **not to use it**, and the reason is not squeamishness:
*it would not do the job*. The meaning Greg wants — ancient, pre-Abrahamic,
about permanence and the turning wheel — is the one meaning it cannot carry in
front of a Western player. The symbol would say something he is not trying to
say, loudly, over the top of what he is.

This project does not need it. `CellOutzType.seal_strokes()` already generates
sigils procedurally from a seed. A mountain-tribe mark that is *this game's own*
carries the intended meaning with no interference. If the specific reading is
"permanence and the turning wheel", the endless knot and the wheel both say it
cleanly and are equally Tibetan.

---

## 3. On the wider lore, since it affects how it should be written

The Qliphoth correspondences above are accurate to the tradition. The Gnostic
demiurge framing — a lesser creator mistaking itself for God, the material world
as a trap — is a real historical current (Sethian and Valentinian Gnosticism, the
*Apocryphon of John*), and it is the actual intellectual ancestor of most of the
meme material in the dump. That matters practically: the game's spine is a real
tradition rather than a pastiche of one, so the primary sources can be drawn on
directly and will be richer than the memes derived from them.

The conspiracy material in the folder — chemtrails, flat earth, Jesuit control,
the 1977 Wow! signal readings, MK-ULTRA as ongoing — is not factually supported.
**For this game that is not a problem and should not be treated as one.** The pin
board, the forums and the Wire are in-world artefacts made by in-world people who
believe them, and that is the whole point of having them.

The line to hold is between the game *depicting people who believe these things*,
which is the game, and the game *asserting them as true*, which would be a
different and worse one. Everything already built respects that line:
`pin_board.gd` is somebody's board, `broken_web.gd` is somebody's forum. Keep new
material on the same footing and the register stays right on its own.
