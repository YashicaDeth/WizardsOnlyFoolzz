# Style rules

**What this fixes:** why some of this game reads as authored and some reads as
generated, and the small number of rules that separate the two.

It is a gate, not a mood board. Every rule below is checkable on a screenshot or
in a diff, and every one of them is derived from a decision already recorded in
this project — nothing here is new taste.

---

## 1. The failure this prevents

Three things make a build read as generated, in this order:

1. **It shows a system instead of a place.** A panel floats over the world, the
   numbers are the interesting part, and nothing in the room explains why it is
   there.
2. **It uses a grammar nobody chose.** Default UI chrome, a health bar, a
   percentage, a "!" marker, a tooltip in sentence case, a font that is not the
   house voice.
3. **It invents a word to get unstuck.** A faction, a name, a rank or a reason,
   written by whoever was building at the time, which then has to be lived with.

The rules that follow are the antidote to each.

## 2. Naming

- **CellOutz names its products like industrial catalogue items.** The register
  is `HOTLINE CLEAVER`, `PRODSTAFF`, `MERCY NINE`, `BREACH NINE`. Noun, weight,
  model number — never a fantasy name, never a pun that undercuts the threat.
- **People are named by `cast_names.gd`'s grammar** (`THE_CAST.md` §1): short
  blunt forename, surname that is a material or a part of a building.
- **No name is invented to unblock a build.** If a thing needs a name the
  documents do not have, the build stops and asks. "Bingyanger" and the "Support
  Unit" are placeholders and stay internal ids.
- **Names are identifiers, never parse keys.** `implant_catalog.gd` says it and
  the whole codebase follows it: nothing branches on the text of a name.

## 3. Colour

The palette, in the order it is allowed to appear:

```text
near-black ground · bone (type, paper) · dried blood · arterial red
copper (structure, trim) · sickly green-white (facility light) · acid green (rare)
```

- **Red means danger, and only danger.** Not selection, not "enemy faction", not
  "locked", not a warm accent. If red is on screen, something is about to hurt.
- **Copper is furniture.** Frames, plates, brackets, dividers.
- **Green-white is the facility's own light**, not a UI tint. It belongs to rooms,
  not panels.
- **No team colours.** Rank and faction are trim, strap and badge, never a fill.

## 4. Type

- **`celloutz_type.gd` is the house voice and there is no font file.** It draws
  procedural stroke glyphs.
- It is a **caps alphabet**: mixed case reads as missing glyphs. No arrows.
- It **does not wrap.** Every string is fitted by the caller; `living_map.gd` has
  a `_wrap_condensed` helper and `broken_web.gd` needs one before it can be
  touched.
- `draw_string` wants a **baseline**; `CellOutzType` wants **top-left**. Lift by
  the cap height or every converted line lands low.
- **A Button cannot be themed to it.** Use `menu_plate.gd`: the control keeps its
  hit-testing and signals, its own font is made transparent, and the plate draws
  over it.
- Prose — dialogue, notes, dossier text — keeps a readable body font. The house
  voice is for labels, titles and the world's own signage.

## 5. Screens are objects

Law 14, applied:

- Every panel exists somewhere a body can stand: a wall, a slab in your hand, a
  CRT, a print, a page under a clip.
- **If a screen has no object, it is not finished**, even if it is beautiful.
- A screen that can be broken, taken or read by someone else is better than one
  that cannot.
- The phone is the one object allowed to carry several screens, because the phone
  is a physical thing you raise and lower, and its battery and wear are visible.

## 6. Silhouette before texture

`silhouette.gd` exists because a textured world still reads as boxes when every
shape is the same box. The rule for everything:

- **One distinguishing silhouette per class of thing**, legible at 20 m in the
  dark.
- Texture is the last 10% of the read and the first thing an agent reaches for.
  Shape first, then material, then detail.
- In unlit rooms a body keeps a faint edge (`silhouette_rim.gd`); nothing else
  glows to be noticed.

## 7. Motion

`celloutz_motion.gd`'s rule — **nothing in this game snaps** — applies to UI as
well as to bodies. Menus settle, cards slide, the cab rocks. If an element
appears instantly, it is either a debug affordance or unfinished.

## 8. Sound is a property of the world

Law 15. A sound with no source is an effect; a sound with a source is a place.
Every row in `THE_SPINE.md` names the sound it needs, and a build that adds a
verb without a sound is incomplete in the same way a screen without an object is.

## 9. Assets and references

- **Greg's own art is the foundation.** Generated images guide models and
  textures; they do not ship as final art.
- **Free assets, credited**: CC0 first (Quaternius, Kenney, Poly Pizza,
  ambientCG, Poly Haven), Mixamo animations, all listed in `CREDITS.md`.
- **Never rip assets from another game.** References (Shadow of Mordor's army
  screen, enRAGE's hierarchy, Lain's wiring) are grammar and quality targets.
  Every asset is original.
- **A reference is never a screenshot to match.** If a build's justification is
  "it looks like the reference", it has not been designed yet.

## 10. The gate

Ask these of any screenshot or diff before it is called done. One "no" is a
finding; three is a rebuild.

1. Can I say where this screen physically is?
2. Is the most interesting thing here a number, or a thing that happened?
3. Would a person in this world say the text out loud?
4. Is red doing anything other than warning?
5. Is every string in the house voice, fitted, in caps — or deliberately prose?
6. Can I tell the two silhouettes apart in the dark?
7. Does anything snap?
8. Does every sound have a source?
9. Was any word, name or reason invented today to get unstuck?
10. Does this still hold at 144 fps and at 720p?

## 11. Where the gate is applied

- In the brief: `PROOF` requires a capture, opened and described.
- In review: the ten questions above.
- In the documents: `THE_SPINE.md` cannot have a row with an empty object or
  sound column; `THE_CAST.md` cannot have a trait that is not a sentence;
  `THE_LADDER.md` cannot have a band whose threat is a number.
