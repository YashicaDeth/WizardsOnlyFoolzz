# Prompts for Agent B and Agent C — the Final V push

**Read these three before touching anything:**

1. `DESIGN/THE_REWORK.md` — what this game is about. Eighteen pages from Greg,
   organised. It answers why, not what.
2. `DESIGN/FINAL_V.md` — the sixteen rules the finished build obeys, plus the
   TouchDesigner and Blender pipeline.
3. `BUILD_INDEX.md` / `BUILD_INDEX.json` — every one of the **1,574 segments**
   flattened to one line each, so a lane can be cut by script instead of by hand.
   Generated from `CHECKLIST.md`; never edit it, regenerate it.

**First thing you type:** `git -C <your worktree> status`. Work in your own
worktree, never in `P:\GameDev\AllusionsTooGrandeur`. This has cost us three
incidents, one of which broke every run.

## The rules, short

- **I0**: no screen is a list of text in a box. It never meant *no information* —
  that misreading stripped every readout out of the derby. A gauge is an object.
- **Rule 3**: every hard cut is a bug.
- **The ladder**: `vN+1` may only fix what `vN` produced or exposed. A version
  that cannot name a real fault is not written. **v10 is the ceiling.**
- **Never claim a visual result you have not looked at.** Capture it, open the
  PNG, say what is in it.
- **Wire what you build.** M2 was ticked off a screenshot and sat unused for days
  while the thing it was built for stayed broken.
- Satire lands on institutions — the agency, the bank, the military, the elite
  class, the godhead — and **never** on congregations or any group of people.
- No assets or implementations from commercial games. Experiential reference only.

---

# Agent B — the world at night, and the psychedelic pipeline

Two jobs. The first is visible in ten minutes; the second is the thing the whole
back half of the game depends on.

## Job one: AS, the lamp and the dark

Everything here now has something to read from — `world_clock.gd` landed, so
there is a real hour, a real night, a daylight curve and a month.

> *"the light can become really warped at night and distorted. Phone has a %
> possibly… as well as having light coming off the phone when you have it in your
> hand, then you can wave it around or pocket it… pockets and clothes should be
> integral, or at least a part of the world system, layers and strategy to
> everything."*

- **AS1.1–AS1.5** The handheld throws real light. Raising it occupies a hand. A
  battery that genuinely runs out. Pocketing it is a movement. And the one that
  turns a torch into a mechanic: **its light is what gives you away at night.**
- **AS2.1–AS2.4** Light *warps and distorts* at night rather than dimming.
  Minimal lighting is the default; a light source is a decision.
- **AS3.1–AS3.4** Clothes and pockets as a world system — weather, radiation, and
  who is willing to talk to you. Not a paperdoll.
- **AS4.1–AS4.5** Storms are a **readout of how much magick is loose**, not
  ambience. Severity tracks the chaos-magick level in `WorldHistory`. **Anvil
  crawlers** — the long horizontal crawl across the underside of a storm, not a
  flash. Get that right and it is the best-looking thing in the build.

## Job two: the psychedelic pipeline (FINAL_V §16)

Greg wants Everhood 1 and 2 grade sequences. **Read `DESIGN/FINAL_V.md`'s
pipeline section in full before starting** — the short version is that
TouchDesigner cannot run inside a shipped Godot game, so TD is the *lab*, Godot
shaders are the *engine*, and Blender supplies the rigs.

Build, in this order:

1. **`psychedelic.gdshader`** — one shader with six effects behind six uniforms,
   all at zero by default: palette LUT, kaleidoscope UV fold, feedback,
   chromatic separation, noise displacement, beat-locked cuts. **One shader, many
   dials**, not six shaders.
2. **A `SubViewport` feedback rig.** Feedback is the single effect that cannot be
   faked and is half of what makes Everhood look like Everhood — a viewport that
   samples its own previous frame.
3. **An OSC bridge for development.** TD sends values over UDP, Godot writes them
   straight into shader uniforms, and you dial the look in TD while watching the
   game change. About thirty lines of GDScript. **It does not ship** — it exists
   so that porting a TD graph is a five-minute job.
4. **Vertex Animation Texture import** for Blender deformation Godot cannot rig —
   melting, splitting, fracturing, geometry nodes. Per-frame vertex positions
   baked to a texture, read back in a vertex shader.

Then the drugs, the meditation, the shadow realms (AQ1.4) and the godhead's
approach are all **the same shader with different dials**, and none of them needs
its own system. That is the whole point.

**Do not touch:** `living_map.gd`, `satellite_view.gd`, `ballistics.gd`,
`blood_veil.gd`, `dash_cluster.gd`, `vehicle_interior.gd`, `rift_derby.gd`,
`world_clock.gd`.

---

# Agent C — the two charts, and the sky

You own everything that draws the shape of the world.

## Job one: AI, the double pyramid

Greg sent three reference charts and one instruction: *"the pyramid structure in
the tab map and everything needs to be rework with this inspiration… also the
pyramids should be like upside down and then up top"*.

Two pyramids meeting at a point. Upright above, inverted below. **As above, so
below** — and that is not decoration, it is the two-axis system the game already
has: AA hands a holding to the ascent or to corruption, and those are the two
cones. The player stands at the waist, where they touch.

- **AI1.1–AI1.7** Tiers as strata with real edges, not a list with indentation.
  Density carries meaning: the base is crowded, the apex is one thing. The
  references are legible at a glance **and** reward an hour — match both.
- **AI2.1–AI2.6** Every tier populated from `WorldHistory`, never authored.
  Factions sit at their real power and move. The player's position is computed.
  Marginalia in the corners the way the references carry it.
- **Take the density from those charts, never the payload.** Greg steered away
  from the QAnon register himself: *"not as much qanon shit but just black magick
  ect and chaos magick."*

## Job two: AR, the tree of life

> *"it be a big Kabbalah type tree of life or Nordic tree of life diagram for the
> different paths, when they occur in the canon story beats, chapters"*

**The pyramid is where power is; the tree is which way you went.** Two charts, one
document — they pin onto the same Board (L v5, L v6), so build them knowing they
share a wall.

- **AR1.1–AR1.7** The tree drawn and real, charting paths against canon story
  beats. Four paths: the CellOutz demon (needs aura, power or influence), rebel
  and outcast, the low-frequency demons into the elite classes, or turning the
  demons on God. Paths open at chapters, never at levels.
- **AR2.1–AR2.6** The job market underneath: bounty work for the top angels or
  the top demons, targets who block a frequency or an aura, Chainsaw Man style
  consumable contracts. Bank work and agency work are one market.

## Job three: E2.4, the seals on the motherboard

> *"burn and bind seals should have their own animation based on real life, where
> the person's computer motherboard appears in 3D and the seals burn into the
> microscopic copper stuff as sigils on the board, like a full animation for it
> when a seal is burnt"*

The best single image anybody has had for this game's thesis: **a printed circuit
board is already a sigil, drawn in copper, mass-produced by the million.**

- **E2.4–E2.7** A real board — traces, pads, silkscreen, something that reads as a
  chip. Burning is subtractive and scars the copper; binding is additive and
  closes a loop that was open. A bound seal works while the board has power; a
  burnt one is gone for the run. `celloutz_type.gd` already has
  `draw_seal_burning()` and it has only ever run in 2D — **this is the 3D half.**

**Do not touch:** anything in Agent B's list, plus `pin_board.gd` structure (you
are adding to its wall, not rebuilding it).

---

# How to cut a lane from the index

`BUILD_INDEX.json` has every segment as a record with `section`, `version`,
`done` and `text`. To take your own slice without asking anybody:

```python
import json
rows = json.load(open('BUILD_INDEX.json', encoding='utf-8'))['segments']
mine = [r for r in rows if r['section'] in ('AI', 'AR') and not r['done']]
```

**675 of the 1,574 segments are v10 final-pass items.** Those are the last rung
and most of them wait on their section's earlier versions — do not start there.
Work the open `v1` items in your sections first, then the ladder in order.

---

# Already done, do not redo

The derby cab and instruments (AG3), blood on the lens, ballistics with casings
and drop (AF1), `limb_momentum.gd` (AN1.1, built and tested, **not yet wired** —
that is Agent A's when there is an Agent A), the world clock (W1.1), station
schedules (A9.7 v2), kerning (A1.6 v2), run-salted grime (A5.6 v2), intermittent
panel failure (A6.6 v2), the gore/hitstop hole, the map's frame cost, the
satellite, and the sprint jitter.

# Still blocked on Greg

1. **The Horsemen's names** (K2).
2. **AC1.1** — simulated fluid, or painted fluid done well?
3. **"Louka vision"** — named alongside Everhood as a reference and nobody knows
   what it is. Needed before FINAL_V §16 is finished.
