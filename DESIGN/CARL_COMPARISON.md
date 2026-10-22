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

Not observed: motion. No clip of a body being dragged, a limb coming off, a
ragdoll settling, or blood spreading. Those rows are **unverified** and carry no
verdict until footage exists — a still of a corpse cannot describe how it got
there.

## The table

| | Carl 0.8.71 | Wizards Only Fools | Delta | Verdict |
|---|---|---|---|---|
| See into a body at range | Yes, layered shell groups (`OrganXRay.set_ShellGroup`) | `WorldXray`: 22 m, fades from 65%, draws over walls | Ours is range-aware and beats occlusion; theirs is a toggle | **Already ahead** |
| Pre-fight intel from the X-ray | None seen | `XrayScanOverlay`: implant tags on the body, organ health bars, damage rings, loot estimate | They have no equivalent at all | **Already ahead** |
| **Round history drawn on the body** | **`GREEN LINE = THE LAT[EST]`, `WHITE LINES = EARLI[ER]`, `WHITE EDGE = REACHED BY A RO[UND]`, `FAINT = A PISTOL ROU[ND]`** | `WoundMarks` places craters at real hit points but says nothing about which round or how far it went | **They show the forensics; we show the holes** | **Adopted** — `RoundTrails` |
| Structure named under the reticle | `LEFT LUNG / LEFT RIB 3`, `SKULL / BRAIN`, with a swatch per layer | Organ states in a right-hand column; implant tags anchored in 3D | Ours names organs in a panel, theirs names the exact structure you are pointing at | **Adopt next** (not built here) |
| Blood on the floor | Flat decal ovals, wide throw across several metres, some landing on the body | `BloodPool` grows and merges two wet edges, `BloodFlow` drips and streaks, `BloodVeil`, `Footprints`, drying to a darker tone | Ours accumulates; theirs only arrives | **Already ahead** |
| Blood carried by a moving body | Not observed | No system found that streaks a dragged torso or a crawling player | Unknown — needs footage | **Unverified** |
| Ragdoll | Curled corpse pose, plausible | `RagdollBody`: joint limits, per-zone masses, settle/sleep/freeze, reuses the live rig so scars and X-ray survive | Theirs may read better; ours is architecturally stricter | **Unverified** — needs motion |
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
