# Opening route — asset needs

Written 2026-09-21, while turning the vat sequence into a playable escape.

Everything in the opening is currently built from Godot primitives in code
(`game/vat_chamber.gd`, `game/systems/vat_body_preview.gd`). That is deliberate
and it works, but it is a temporary coherent form, not the finished look. This
file records what an authored asset would replace, so the placeholder is a
known placeholder rather than something that quietly ships.

Nothing here blocks playing the route. Each entry says what exists now, what is
wanted, and where the swap happens.

---

## 1. The examiner

**Now:** capsule torso, tapered cylinder coat, sphere head, box arms, and a
badge made of a plate, a ring, a stem and a crossbar.
`vat_chamber.gd::_build_examination_station()`.

**Wanted:** one low-poly rigged figure in a dark institutional coat, hard
collar, hands. A walk cycle would replace the position lerp in
`_update_departure()`; without one he currently slides.

**Note:** the badge is a restrained government sigil on purpose — the previous
six-spoke-in-a-ring version read on screen as a ship's wheel. Whatever replaces
it should stay small, dark and off-centre on the chest rather than becoming a
medallion.

**Swap point:** replace the node construction in `_build_examination_station()`;
keep `examiner_node` as the thing `_update_departure()` moves.

---

## 2. The staff door

**Now:** a box frame, a sliding box panel, an emissive lintel strip and an omni
light. `vat_chamber.gd::_build_staff_door()`.

**Wanted:** an authored institutional door with a real mechanism — the closing
is a story beat, and it currently reads because of the lintel light rather than
because of the door.

**Swap point:** `staff_door_panel` is a `Node3D` whose `position.z` is lerped;
any authored panel can hang off it unchanged.

---

## 3. The vat interior and the cradled subjects

**Now:** `BaselineHuman` rigs frozen in a folded pose inside transparent
cylinders, with the neighbouring bays past the first few collapsing to capsules
for budget (`vat_chamber.gd::_dead_tank()`, `_build_cradled_vat_subject()`).

**Wanted:** a small set of authored restrained poses — alive, injured, failed —
and restraint hardware (cuffs, harness, spinal line) that the rig can wear. The
brief asks for subjects facing varied directions; the rigs currently vary by
seed but all sit in one folded pose.

**Known gap:** the far bays are still capsules. That is a deliberate budget
call, not an oversight, but it is visible from the aisle once the player can
walk.

---

## 4. The feed tube

**Now:** a tapered cylinder into the specimen's mouth in the preview panel, and
a two-line drawn overlay at the bottom of the first-person view
(`vat_intake.gd::_draw_tank()`).

**Wanted:** one authored tube asset used in both places, so the thing in the
player's mouth and the thing in the preview are the same object. Right now they
are drawn by two different systems and only approximately agree.

---

## 5. The intake form's surface

**Now:** a cream clipboard with coffee rings, drawn in
`vat_intake.gd::_draw_clipboard()`.

**Wanted:** Greg's brief is explicit that this must read as "damaged, invasive
medical technology ... dark red laboratory glass, cables, veins, corrupted
institutional panels, prototype-like physical hardware", and **not** as a clean
clipboard or office form. The current surface is the office form.

This is the largest outstanding presentation gap in the opening and it is a
design decision rather than an asset swap — the form's whole visual language
changes. Flagged rather than guessed at.

---

## 6. Glass shards

**Now:** 22 alpha boxes thrown outward on breach (`vat_chamber.gd::_breach()`).
They read as pale floating cardboard rather than glass.

**Wanted:** a shard mesh set, or at minimum a material pass — this is small
enough to be worth doing inline next.

---

## Not an asset need — an open route question

The brief asks for "a readable physical access solution: obtain a guard's
biometric access or equivalent prototype access method" on the first gated
door. The route today exits through the pit door at the far end of the aisle,
which opens on proximity and leads to `underground_colosseum.tscn`.

Adding a biometric gate changes where the opening's first obstacle is and what
the player has to do about it. That is a route decision, not an engineering
one, so it is left for Greg rather than invented here. The examiner's staff door
is deliberately built as **not** the player's exit, so it is available as the
gated door if that is the direction wanted.
