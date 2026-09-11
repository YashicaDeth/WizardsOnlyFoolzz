# Rituals, karma and the two ladders

Captured whole from Greg, 2026-09-11.

## Is it coherent? Yes — it is one system wearing four faces

Greg asked directly whether this all hangs together. It does, and the reason is
worth stating plainly because it changes how it should be built.

The project already has an **Ascent / Descent axis**. `WorldHistory` carries
`FACTION_TREE_AXIS`, `tree_alignment()` and `tree_axis_label()`; the X-ray
dossier already draws a subject's position on it; faction birth sets a baseline
pull and personal bonds and grudges drift a subject away from it. It is
implemented, it is live, and almost nothing in the game currently *uses* it.

Everything in this capture plugs into that one axis:

| Greg's idea | What it actually is |
| --- | --- |
| Demonic sigil ritual app | The Descent route, transacted through the handheld |
| Angels, higher-frequency gods, DMT entities | The Ascent route — same machinery, opposite sign |
| Karma, washing away sins | The axis itself, made visible and consequential |
| Becoming a demon / giving your soul away | Running the axis to its end and being changed by it |
| Drugs as minigames | The access verb for the entity layer, plus an economy |
| Chunk physics down to bone and organ | The evidence rituals need, and the way cybernetics are robbed |
| Clickable spinning 3D organs | Already scheduled as Tier 1c |
| Radial menu instead of sliders | The handheld's input grammar |

So this is not eight new systems. It is **one existing axis finally being given
teeth**, plus a gore depth increase, plus two interface items already on the
list. That is the coherent version and it is how it should be scoped.

The honest risk is not incoherence, it is **volume**. See `CHECKLIST.md`.

## The ritual app

A mode on the handheld, alongside INDEX / MAP / TREE / WIRE / CARRY. Same
salvaged junk device — Greg's framing is a Garry's Mod tool gun with a bad
internet connection, not a polished military computer.

**The sigils.** The 72 seals of the Ars Goetia, from the *Lesser Key of
Solomon*. This is 17th-century material and Mathers' 1904 edition is long out
of copyright, so the seals themselves are free to use — but per non-negotiable 1
they should be **drawn in code** in the same stroke vocabulary as
`celloutz_type.gd` and `natal_sigil.gd` rather than pasted in as scans. That
keeps them part of this game's hand instead of someone else's artwork sitting
inside it, and it means they can animate, corrupt and burn.

"And more": the roster extends past the Goetia with original seals for things
this world grew on its own — the Choir of Marrow's saints, the Communion's
caps, whatever the Reset left in the ground.

**The camera is the ritual instrument.** The handheld has a camera mode and
rituals are completed by *photographing evidence*. Greg's worked example: kill
five people and photograph their gored heads. This is excellent because it
makes the ritual system depend on the gore system rather than sitting beside
it — the photograph has to actually contain a destroyed head, which means the
game has to check the real anatomy state of a real body in frame.

It also makes rituals **playable rather than menu-driven**. You do not select a
ritual and press confirm. You are sent to do something, and you have to bring
back a picture of it.

**Boosts are temporary and always cost.** Never permanent. The cost should be
paid in the body or in standing, because those are the two ledgers the game
already keeps: blood volume, an organ, a limb's condition, Wire reach, a bond.
A ritual that costs nothing is a cheat menu.

## Gore depth — chunk physics and layers

Greg: *"obviously the gore will be extremely good and accurate and have chunk
physics that then get down to the layers of blood bones organs chunks."*

This is a real escalation of `baseline_human.gd`, and it earns its place because
**three separate systems need it**:

1. **Rituals** need photographable evidence with actual state behind it.
2. **Robbing cybernetics** is Greg's stated method — you dig through the layers
   to get the part out. That turns looting into a physical act on a body
   instead of a menu transfer, and `install_prosthetic()` already exists on the
   other end of it.
3. **The 1.0 body** in `ROADMAP.md` already asks for dismemberment as a combat
   verb rather than a death effect.

The layer order is the anatomy the rig already models: skin, fat, muscle,
blood, bone, organ, cybernetic. Chunks are rigid bodies with a layer identity,
so a piece of somebody carries what it was made of and what was inside it.

## The two ladders

**Descent.** Demons, sigils, transactional power, immediate boosts, escalating
prices. Run it far enough and Greg's endpoint applies: you turn into one, and
the soul is signed over. That is a real ending state, not a stat.

**Ascent.** Angels, "higher-frequency gods", and the entities met through drugs.
These are not a shop. They **wash away sins** — they lower accumulated Descent
pull in exchange for positive quests, which is the only mechanism in the game
for undoing karma. Greg's closing note: appeal far enough up the ladder and the
game continues rather than ending, which makes Ascent the long route and Descent
the fast one.

**This is the As Above So Below nemesis system.** The Hunt System is currently
one-signed: rivals, grudges, escalation. `DESIGN/HUNT_SYSTEM.md` §6 already
states that bonds use the same machinery and are the mirror rather than a
separate feature. Entities are that mirror at the top and bottom of the axis:
they remember you, they escalate, they are met repeatedly, and they have
relations with each other. The nemesis code paths serve both ladders.

## Drugs

Substances are the access verb for the entity layer — the DMT entities in
Greg's list are reached by taking something, not by finding an altar. Alongside
that they are a production and sale economy in the register of the recent
weed-growing/dealing games: joints, bongs, pipes, and per-substance minigames
for preparation and consumption.

Design constraint that keeps it from being a toy: **every substance has a body
cost the anatomy component already tracks** — pain, consciousness, blood
chemistry. A drug that opens the Ascent ladder also degrades the body that has
to walk back out of the cave.

Boundary: this is a fictional wasteland economy in the same satirical register
as the rest of the game. It is not instruction, and real substances should be
renamed into the world's own vocabulary the way the conspiracy modifiers were.

## Karma, and why it is not a morality meter

Karma is **not a new number**. It is the existing Ascent/Descent alignment made
visible, accumulated from real recorded events, and given consequences:

- Factions price you by it (`FACTION_TREE_AXIS` already sets their baselines).
- Entities on each ladder open or close.
- The natal chart sets your *starting* position on the axis, which is the
  mechanical link back to `DESIGN/CHARACTER_CREATION.md`.
- Route endings branch from where you finish.

The design rule from the Codex holds: it should never be a good/evil slider
with a number on screen. It is a position on a wheel, read through the Tree
view that already exists.

## The 3D inspection pass — confirmed and extended

Already scheduled as **Tier 1c** in `ROADMAP.md`. Greg has now confirmed it and
added to it:

- Organs **and cybernetics** are clickable, expandable, and spin in place as
  real 3D models — accurate, somewhat stylised, and gross.
- **Limbs and body parts inspect the same way**, so the verb is uniform across
  the whole body rather than organ-only.
- It sits **beside** the X-ray plate and beside the faction/rank view, which is
  the layout Greg has now described twice.

No change to the scheduled design, just more of it and a confirmation it is
wanted. The Tier 1c rule still stands: the part must appear to leave the
diagram, not open a window.

## Radial selection

Greg: *"instead of the slider we can have a circular mouse that has a custom
icon of some sort in the menus once the pip boy thing is made."*

This supersedes the "weapon and cybernetic selection sliders" line in the
reference pass. A radial is the correct answer for the handheld: it is fast, it
works held at arm's length, it does not need a cursor, and it scales to
weapons, cybernetics, ritual seals and handheld modes with one input grammar.
The custom cursor icon is an art item, not a systems one.

Not a Pip-Boy. Greg has said so twice. Same *role*, junk hardware, and no
borrowed interface.

**The cursor carries the X-ray.** Greg's addition: the radial has a circular
X-ray button on it, clickable at any time, purely for the gross and the
visceral. That is the right place for it — it makes seeing through a body a
*constant available verb* rather than a mode you enter, which is what the
Codex's "first person is Self/Perception" line has been pointing at all along,
and it means the anatomy work is on screen whenever the player wants it instead
of only at a kill.
