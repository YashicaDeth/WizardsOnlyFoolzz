# Gore and combat, in the order I would take them

**Status: an assistant proposal, not a rule.** Greg decides the queue; this is
the list I would hand him, ordered so each piece is small, provable, and makes
the next one cheaper. Nothing here is started.

`DESIGN/CARL_COMPARISON.md` is the reference side of this; `goal/SKILL.md`'s
"combat overhaul" line (omnidirectional swinging on both sides, a skill curve
you can learn and read, AI tuned to what is achievable) is the queue this feeds.

## What is already built

Listed so this file does not propose work that exists.

**Wounds and bodies.** `AnatomyComponent` (zones, organs, dose, chill), the
wound table in `wound_catalog`, `WoundMarks`, severing (`BaselineHuman.severed`,
`SEVER_HEALTH_RATIO` / `SEVER_THRESHOLD_RATIO`, `limb_severed`), stump bleeding,
`Perfusion` (flow and oxygen, with a heart, spine, volume, open vessels and the
loss still running out of the hole as its inputs).

**Gore on the ground.** `BloodSmear` (240 segments, drying, retired pool),
`BloodPool` (volume grows the spill, old blood reads matte), `GoreChunks` (18
pieces actively simulating, then frozen), `RoundTrails` (entry / exit / stop
dots, magenta cut strokes, the latest round green, earlier ones white, bone
reached as a white edge, depth fade), `BloodVeil`, `BloodLedger`.

**Readouts.** `MedicalMonitor` (body, blood, bleed, internal, oxygen /
perfusion, consciousness / pain, vessels, spine, fractures, exposed, hit,
absorbed), `LockReadout` on the locked body's real zones, the X-ray.

**Combat.** `MeleeDriver` (light and heavy, commitment measured from mouse
motion, 0.24 s parry window, stamina with a 0.55 s delay, per-target poise and
stagger, hitstop), `SwordMoveset`, `CombatStance`, `Clinch`, `LimbMomentum`,
`Knockback`, `RagdollBody`, `FighterTier` (scavenger / hunter / captain / elite,
side and feint data), `ThreatCompass`, `BlockTracker`, five fighter effects
measured at 0.43-0.46 ms.

**Movement.** Sprint with the winded state, climb, dodge, stamina drain and
recovery, lock-on, `hunter_body_motion`.

## What Carl has that we do not

1. **Pulse.** The monitor has no PULSE row at all, and nothing in the game has
   a heart *rate*: the heart is a 0.06 factor when ruptured. Every "is this body
   alive" readout is a state, not a rhythm.
2. **Arterial spurting in time with it.** The decal art exists
   (`assets/decals/decal_baker.gd` D1 and D6). Nothing simulated sprays in
   beats, and nothing stops spraying when the heart does.
3. **Fragment paths.** A round that breaks up inside a body writes one trail
   here. Carl draws the thin lines of what it broke into, and the monitor does
   not count pellets.
4. **A body you can move.** `Carry` handles parts and their mass. There is no
   way to drag a whole corpse and see what it leaves.
5. **A hit line that names the wound.** The monitor's HIT and ABSORBED rows
   exist; the reference's `BUCKSHOT · 8 OF 9 PELLETS · LEFT THIGH / NO PULSE`
   is richer than what we print.

## Gore, in order

**G1. Pulse, in the model rather than the HUD.** `Perfusion` gains a rate
derived the same way flow is — from volume, flow, pain and oxygen, raised by
compensation and falling through the arrest to nothing. The monitor prints
`PULSE 142 BPM`, or `NO PULSE`. This is first because it is the missing half of
"the body is the health bar", and because G2 and C1 both need it.
*Proof:* `vitals_test` walks healthy → bleeding → arrested → stopped with a BPM
at each step; a capture of the panel.

**G2. Arterial pulse on the ground.** A severed artery sprays in beats taken
from G1's rate, into the existing `BloodVeil` / `BloodPool` / `BloodSmear`
rather than a new gore system. A heart-ruptured body does not spray at all.
*Proof:* a headless test counting spray beats a second against the rate, with
the arrest case asserting zero; one frame of the spray.

**G3. Fragments.** A round that breaks up writes two to four thin trails from
its deepest point outward, in the grammar `RoundTrails` already draws, and the
monitor's HIT row counts pellets.
*Proof:* `round_trails_test` extended; a capture of one shotgun spread.

**G4. The body can be moved.** Dragging a corpse leaves smears at the contacts
and reopens stump bleeding at a rate the friction sets. Not a new system: the
smear and the wound already exist, the input does not.
*Proof:* a test that drags a ragdoll N metres and asserts smear length and
millilitres lost; a capture.

**G5. One clock for all of it.** Smear, pool and chunks age together — wet,
matte, flaked — and the ecology reads the age rather than each effect keeping
its own timer.
*Proof:* a timestamped test across the three, and a scene looked at at t+0 and
t+3 minutes.

## Combat, in order

The queue's line is one big job. These are the pieces I would cut it into.

**C1. A telegraph that names the zone.** Every enemy wind-up already drives
`ThreatCompass`. Make it say *which limb, which side* — `FighterTier.SIDES`
already has high / low / left / right — so raising a guard is a decision instead
of a coin flip.
*Proof:* a test asserting the telegraph's zone equals the zone the blow lands
in, for every tier and side; a capture.

**C2. Omnidirectional swinging, both sides.** The queue's own next line.
`_swing_mirror` and `swing_hint` are the seeds; each direction needs its own
commitment and recovery so direction is a skill rather than a skin.
*Proof:* the moveset test across eight directions, plus the strike gallery
showing eight distinct arcs.

**C3. A skill curve you can read.** Whiff, block, parry and stagger already
exist as states. Print which one the exchange was decided by, in `BlockTracker`
and the monitor, so a player can learn from a loss.
*Proof:* a test over the four outcomes; a HUD capture.

**C4. Enemy competence that is actually tuned.** `FighterTier` exists with
feints at 0.82 of the wind-up. Tune per tier — scavenger telegraphs long,
captain feints, elite punishes a whiff — and prove it with a deterministic duel
where the same scripted player beats a scavenger and loses to an elite.
*Proof:* that duel test, run twice for stability.

**C5. Stamina as the spine of the loop.** The costs exist. Make recovery reward
reading the fight: a landed hit returns stamina, a whiff does not, a parry
returns more. Then pressing is a decision with a price rather than a spam.
*Proof:* a test asserting whiff → punishable, hit → recovered, parry → best.

**C6. The clinch as the answer to a guard.** `Clinch` exists and is barely the
counter to anything. Make a held guard grabbable, so a wall becomes a decision.
*Proof:* a test for guard → clinch → throw.

**C7. Movement that opens a combat option.** One at a time: dodge direction
feeding the swing (`dodge_direction` is already there for dust), vault over low
cover into a strike, wall-run as repositioning.
*Proof:* one movement test each, and the Hunt rather than the gallery.

**C8. Difficulty that stays honest.** The body is the health bar, so an enemy
that takes more must be armoured, implanted or regenerating — never a health
multiplier. Worth a guard test that fails if one appears.
*Proof:* a test that scans encounter data for an HP multiplier and a duel
recording at each tier.

## The next three, if Greg agrees

1. **G1, pulse.** It is the monitor's one missing row, and C1, G2 and C5 all
   read better once a body has a rhythm.
2. **C1 + C5, telegraph and stamina.** The two cheapest steps from "click and
   shoot" to "read and answer", and both are wiring rather than new systems.
3. **C2, omnidirectional swinging.** The queue's own line, taken after the two
   above so the directions have something to be read against.

## Rules for anything on this list

- Gore is feedback for a decision — which zone, how hard, with what — never
  decoration. Every effect reads a number the model already owns.
- No second copy of a value. If a new effect needs a new field, the field goes
  in the system that owns the fact.
- Hitstop stays as it is unless Greg asks (`impact_feel.gd` v4: loud is not the
  same as satisfying).
- No health bars, no enemy tiers by multiplier, no invented lore to unblock a
  piece.
- Each piece is done when it is playable in the real route, recorded, seen in a
  capture, covered by one `tests/<name>_test`, and merged — the `goal` skill's
  list, unchanged.
