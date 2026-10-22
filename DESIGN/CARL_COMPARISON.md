# Project C.A.R.L. against our body stack

Reference: **Project C.A.R.L. 0.8.71 DEV** (Unity 6000.6.1f1, IL2CPP), played by
Greg on 2026-10-23 and captured in three stills plus one live frame of our own.
Evidence and the failed decompilation are in `carl_reference/_NOTES.md`
(gitignored — it holds somebody else's binaries).

The rule for this file: **a row may only say "adopt" when it names an observable
difference**, and "already ahead" is a first-class verdict. Comparing against a
project two years of work behind ours is only useful if it is allowed to say so.

## Method, and what it cannot tell us

Observed: the lab room at rest, the X-ray closed and open at two ranges, the
part-name readout under the reticle, and a corpse after a kill. Plus the names of
the six real classes from the player's own log (`ImpactLab.LabSession`,
`LabCursor`, `NpcBrain`, `LabHUD`, `OrganXRay`, `OfficialContent`).

Observed later, 2026-10-23: 49 s of the X-ray at work and 156 s of gore, sent as
two screen recordings. Frames were extracted with ffmpeg and read. That footage
settles the motion rows and adds three things the stills could not show; the
section at the end lists them.

Not observed even now: a limb being taken off by a blade, and blood settling on
a vertical surface.

## The table

| | Carl 0.8.71 | Wizards Only Fools | Delta | Verdict |
|---|---|---|---|---|
| See into a body at range | Yes, layered shell groups (`OrganXRay.set_ShellGroup`) | `WorldXray`: 22 m, fades from 65%, draws over walls | Ours is range-aware and beats occlusion; theirs is a toggle | **Already ahead** |
| Pre-fight intel from the X-ray | None seen | `XrayScanOverlay`: implant tags on the body, organ health bars, damage rings, loot estimate | They have no equivalent at all | **Already ahead** |
| **Round history drawn on the body** | **`GREEN LINE = THE LAT[EST]`, `WHITE LINES = EARLI[ER]`, `WHITE EDGE = REACHED BY A RO[UND]`, `FAINT = A PISTOL ROU[ND]`** | `WoundMarks` places craters at real hit points but says nothing about which round or how far it went | **They show the forensics; we show the holes** | **Adopted** — `RoundTrails` |
| Structure named under the reticle | **Three at once**: `RIGHT LUNG  RIGHT RIB 3  T5 VERTEBRA` | Organ states in a right-hand column; implant tags anchored in 3D | Ours names organs in a panel, theirs names every structure the reticle crosses | **Adopt next** (not built here) |
| Blood on the floor | Flat decal ovals, wide throw across several metres, some landing on the body | `BloodPool` grows and merges two wet edges, `BloodFlow` drips and streaks, `BloodVeil`, `Footprints`, drying to a darker tone | Ours accumulates; theirs only arrives | **Already ahead** |
| Blood carried by a moving body | **Confirmed in footage**: a body dragged by the physics gun leaves long red smears across the tiles | No system found that streaks a dragged torso or a crawling player; `BloodPool` grows where drops land but nothing drags them | **Ours pools, theirs is carried** | **Adopt** — the largest remaining gap |
| Ragdoll | Bodies go limp immediately and can be grabbed, thrown and turned with a physics gun | `RagdollBody`: joint limits, per-zone masses, settle/sleep/freeze, reuses the live rig so scars and X-ray survive | Theirs is playable with; ours is authored to settle | **Unverified** — no side-by-side motion |
| Slow motion | `TIME 1.0x` HUD dial | `gore_cam`, `kill_cam`, `execution_beat`, `vats_targeting` | Both have it; presentation not compared | **Unverified** |
| Gun feel | 9 mm pistol, 12/12, reserve counter | `Ballistics` rounds as travelling objects, `LimbMomentum` for the arm | Ours is more physically committed | **Already ahead** |

## What was taken

**`game/systems/round_trails.gd` (AN6.7).** Every round fired into a body is
drawn as a path through the limb: newest green, earlier white, the end brightened
where the round reached bone, and the shaft faint when the round barely entered.

Nothing new is recorded. `BaselineHuman._record_wound()` already stores the entry
point, the inward normal and `Penetration`'s depth fraction per wound, and they
already survive a save. One field was added — `thickness`, the distance the round
actually had to cross — so the trail is the length of the real path rather than a
guess made later. It is built only while `reveal_organs(true)` holds, rebuilt
only when the wound table changes, and removed when the sweep lets go.

Evidence: `ATG_TEST_MODE=1 Godot --path game res://tests/round_trails_test.tscn`
(23 checks, `failures=0`) and the render produced by
`game/tests/round_trails_capture.tscn` — three rounds in a left arm, two white
through-shots and the newest one green.

## Deliberately not taken

- **Shell groups as the X-ray's unit.** Their `set_ShellGroup(int)` fits a
  Unity demo with seven-segment mannequins. We have real organ meshes, so a
  layered integer would be a downgrade dressed as a feature.
- **The part-name readout**, for now. It is a good idea and it needs the X-ray
  overlay to own a reticle query, which is a larger change than this pass. It is
  the next row to take, not a dropped one.
- **Anything numeric.** No masses, no tuning constants, no shader values: those
  live behind the protector, and guessing them would be worse than our own
  calibrated numbers.

## An open question about us, not them

Every capture of a bare `BaselineHuman` in a minimal scene — including with the
X-ray off and no rounds recorded — shows a black rectangle of noise with orange
dashes sitting on the chest. It is not this change and it is not in the frames
Greg sent from the real game, so it is probably the capture harness missing
whatever initialises the body's materials in-world. Worth a look; not chased
here, and recorded so it is not rediscovered.

## What the two recordings added

**The X-ray's legend is a larger grammar than the stills showed.** The full list,
read off the right edge of the frame:

```
RED DOT        = WHERE A ROUND WENT IN
BLUE DOT       = WHERE IT CAME OUT
PURPLE DOT     = WHERE IT STOPPED
GREEN LINE     = THE LATEST ROUND
WHITE LINES    = EARLIER ROUNDS
WHITE EDGE     = REACHED BY A ROUND
BROWN          = OLD BLOOD
THIN LINES     = FRAGMENTS
PULSING        = ARTERY
YELLOW TO CRIMSON BONE = BROKEN
MAGENTA        = CUT
```

We took the spine of that: the path, the recency, the bone-reached end, the
depth fade. The dots, fragments, artery pulse and cut are not built. They are
the obvious next increment and they all read from the same wound table, so they
are additions to `RoundTrails` rather than a new system.

**A medical monitor that is the health bar we have been describing.** Bound to
`M`, it lists a live body's state while you look at it: blood volume in litres
and percent, bleeding rate in mL/s, oxygen, pulse, brain activity, spinal cord
`INTACT / CUT AT T2`, brain exposure percentage, per-region structural damage
with bone bruising counts, `10 MAJOR VESSELS SEVERED`, and a last-hit line that
names the weapon, the pellet count and the body part — `BUCKSHOT · 8 OF 9
PELLETS · LEFT THIGH / NO PULSE`. Plus `3 FRACTURES: LEFT TIBIA X1, RIGHT TIBIA
X1, PELVIS X1`.

That is `ARCHITECTURE/SYSTEM_MAP.md`'s "the body is the health bar" written out
as a screen. We have the anatomy (`AnatomyComponent`, `BloodLedger`,
`BloodFlow`, `wound_catalog`) and no single readout that states it. **This is the
most valuable thing in either recording**, and it is a UI over systems we
already own.

**An X-ray inside a rifle scope.** The 308 bolt rifle shows the same anatomy
view through a circular, vignetted optic rather than over the whole screen.
Cheap for us: the reveal state is per-rig already, so it is a mask on the
presentation rather than a second X-ray.

**A physics gun, and what it does to the gore.** Dragging a corpse leaves the
smear streaks above; it also sprays a fine pink mist and dust that hangs. Ours
has the spray (`BloodVeil`, `blood_pool`) and no way to move a body except by
cutting it.

## Order I would take next

1. **Blood smearing** — confirmed in footage, absent here, and the only row
   where we are plainly behind.
2. **The medical monitor** — mostly reading what we already record.
3. **The dot grammar** (entry / exit / stop / fragment / artery) on existing
   trails.
4. **The scope-lens X-ray** — presentation of a verb we already have.
