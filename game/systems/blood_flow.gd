class_name BloodFlow
extends RefCounted

## Greg: *"even add in blood to there body as a fluid start working on the fluid
## physics starting on the blood leaking from when you kill them"*.
##
## What this is not: a fluid simulation. A real one — SPH, or a grid solver —
## costs more per body than this whole game spends on a body, and would look
## worse, because at the scale that matters here blood is not a volume flowing,
## it is drops leaving a hole and a wet streak spreading down skin. Simulating
## the thing you cannot see in order to get the thing you can is the expensive
## way to arrive somewhere worse.
##
## So blood behaves like blood in the two places it is actually observed:
##
##   - **It leaves the wound and falls.** Reusing the rig's existing `_loose`
##     ballistic list and its splat-on-landing, so a drip lands on whatever
##     surface is under it — a ramp, a car, a body — exactly like every other
##     piece of gore already does. A second falling-blood system beside that one
##     would be a second thing to keep in step with it.
##   - **It runs down the body.** A streak under each wound that lengthens the
##     longer that body bleeds, and darkens as it dries.
##
## The rate is not invented either. `AnatomyComponent.bleed_rate` is already the
## real number the body loses blood by, and is already the thing that decides
## whether someone dies of a wound, so driving the visual off it means the
## bleeding you can see *is* the bleeding that is killing them.

## Drops per second per point of `bleed_rate`.
##
## Calibrated against what the anatomy actually produces rather than guessed,
## because the guess was wrong by an order of magnitude in the direction that
## makes the feature invisible. Measured: a 12-damage round leaves `bleed_rate`
## at 0.38, a 34 at 1.07, a 95 at 2.99. **External bleeding is a small number.**
## The big ones are internal — a ruptured organ puts `internal_bleed_rate` at
## 47.6 — and that is blood going into the body, not out of it.
##
## The first cut used 0.16 with a floor of 2.5, which meant a body shot through
## the chest never visibly bled at all unless an organ burst. At 1.4 a 34-damage
## hit drips about one and a half times a second, which is a wound, and a 12
## drips every two seconds, which is a graze.
const DROPS_PER_BLEED := 1.4
## Nothing below this drips. Low, because real external rates are low — but not
## zero, or every bruise on every body in a crowd is a dripping wound.
const MIN_BLEED := 0.3
## However fast it is bleeding, never more than this many drops a second, so a
## body with six open wounds cannot outspend the gore budget on its own.
const MAX_DROPS_PER_SECOND := 7.0

## How fast a streak grows down the skin, in metres per second of bleeding, and
## how far it can reach before it is running off the body rather than down it.
## Rendering the first cut showed these were all too big: a 0.022-wide bar
## running 0.34 down a limb reads as a red stick glued to the body, and on a
## thin limb it runs past the edge and hangs in the air. A run of blood is
## narrow, and it stops when the limb does.
const STREAK_GROWTH := 0.030
const STREAK_MAX := 0.17
const STREAK_WIDTH := 0.012

const FRESH := Color(0.42, 0.038, 0.03)
const DRIED := Color(0.14, 0.028, 0.025)


## How many drops to emit this frame. Returned as a float and accumulated by the
## caller, because at realistic rates this is well under one per frame and
## rounding it per-frame would either round to zero forever or to one every
## frame — neither of which is a rate.
static func drops_for(bleed_rate: float, delta: float) -> float:
	if bleed_rate < MIN_BLEED:
		return 0.0
	return minf(bleed_rate * DROPS_PER_BLEED, MAX_DROPS_PER_SECOND) * delta


## Arterial bleeding is not a rate, it is beats.
##
## Everything above is a trickle measured in millilitres a second, because a
## wound in tissue leaks. A severed artery does not leak: the heart pushes a
## bolus and it leaves all at once, so the honest clock for it is the one the
## monitor already prints — `AnatomyComponent.pulse_bpm()`. A body keeps one
## beat clock, because it has one heart however many stumps it has open, and
## asks here how hard that beat throws.
##
## Nothing below decides that a body is losing blood. `AnatomyComponent.bleed_rate`
## is still the number doing that, and `_sever_zone()` is what puts the stump's
## share into it. This decides the shape the blood leaves in, so the spurts on
## screen are the millilitres the anatomy is already spending.

## Per beat from one stump, on a body with its full complement of blood. Six is
## a visible handful, and stays inside the gore budget with two limbs off.
const SPURT_DROPS := 6
## A nearly empty body still throws on each beat; it just throws weakly. Never
## zero, because a spurt that stops before the heart does reads as a bug rather
## than as a body running out.
const SPURT_MIN_DROPS := 1
## Stroke volume at the last of the blood. It falls before the rate does — a
## body down to a third of its blood beats faster than it did at rest and moves
## less each time — which is why the pulse climbs while the spurts weaken.
const STROKE_FLOOR := 0.28
## The jet, metres per second. A femoral artery crosses a room and a wrist
## artery marks the wall beside you; both are under the 1.9-5.5 m/s of
## `_spray()`, because an arterial beat has no impact behind it.
const SPURT_SPEED_MIN := 1.1
const SPURT_SPEED_MAX := 2.6
## Every few beats the jet is thick enough to mist as well as to drop. Not every
## beat: sixty puffs a minute is a smoke machine, not a wound.
const SPURT_MIST_EVERY := 3


## How much of a full stroke one beat carries, 0 to 1.
static func stroke_strength(volume_fraction: float) -> float:
	return clampf(STROKE_FLOOR + (1.0 - STROKE_FLOOR) * clampf(volume_fraction, 0.0, 1.0), 0.0, 1.0)


## Drops thrown by one beat. `detail` is the gore setting the rest of the rig
## already scales its spray by, applied here so REDUCED is a sparser spurt
## rather than the same spurt at a lower frame rate.
static func spurt_drops(volume_fraction: float, detail := 1.0) -> int:
	var full := roundi(float(SPURT_DROPS) * stroke_strength(volume_fraction) * clampf(detail, 0.0, 1.0))
	return clampi(full, SPURT_MIN_DROPS, SPURT_DROPS)


## One beat's jet, from the stump's direction away from the body: an arm throws
## sideways and a leg throws down and out, rather than every stump in the game
## throwing the same way up.
static func spurt_velocity(outward: Vector3, volume_fraction: float) -> Vector3:
	var away := outward.normalized() if outward.length_squared() > 0.0001 else Vector3.UP
	var speed: float = lerpf(SPURT_SPEED_MIN, SPURT_SPEED_MAX, stroke_strength(volume_fraction))
	var jet := (away + Vector3.UP * 0.22 + Vector3(randf_range(-0.22, 0.22), randf_range(-0.04, 0.22), randf_range(-0.22, 0.22))).normalized()
	return jet * speed * randf_range(0.82, 1.12)


## A drip leaves the wound slowly and mostly downward — the difference between
## bleeding and being shot. `_spray()` throws blood outward at 1.9-5.5 m/s
## because something just hit it; this leaves at a fraction of that, so the two
## read as different events even though they use the same falling code.
static func drip_velocity(surface_normal: Vector3) -> Vector3:
	var out := surface_normal.normalized() * randf_range(0.12, 0.38)
	out += Vector3.DOWN * randf_range(0.25, 0.6)
	out += Vector3(randf_range(-0.08, 0.08), 0.0, randf_range(-0.08, 0.08))
	return out


## The streak running down from a wound. Grown rather than rebuilt: the mesh is
## replaced but the node is reused, so a body bleeding for a minute is not a
## minute of node churn.
static func build_streak(width: float, length: float, age: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = streak_mesh(width, length)
	node.material_override = streak_material(age)
	return node


static func streak_mesh(width: float, length: float) -> Mesh:
	# A prism rather than a box, so the run actually narrows as it goes — a
	# constant-width bar is the single thing that made the first version read as
	# a painted stripe instead of something that ran.
	var prism := PrismMesh.new()
	prism.size = Vector3(width, length, width * 0.30)
	# Point down: the wide end is at the wound and the taper is at the bottom.
	prism.left_to_right = 0.5
	return prism


static func streak_material(age: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = FRESH.lerp(DRIED, clampf(age, 0.0, 1.0))
	# Fresh blood is wet and dried blood is not, which is most of what tells the
	# two apart at a glance.
	material.roughness = lerpf(0.18, 0.78, clampf(age, 0.0, 1.0))
	material.metallic = 0.0
	material.render_priority = 2
	return material


## Where a streak hangs from a wound, and how it is turned.
##
## Down is world down, not limb down: blood runs the way gravity points, so a
## streak on an arm held out sideways runs across the arm rather than along it,
## and that is the whole reason it reads as a fluid rather than as a texture.
static func streak_transform(part: Node3D, wound_at: Vector3, wound_normal: Vector3, length: float, lift := 0.003) -> Transform3D:
	var world_down := Vector3.DOWN
	var local_down: Vector3 = (part.global_transform.basis.inverse() * world_down)
	if local_down.length_squared() < 0.0001:
		local_down = Vector3.DOWN
	local_down = local_down.normalized()
	# Held just off the surface so it lies on the skin instead of inside it.
	# The lift is a parameter because a streak hanging on a garment rides one
	# cloth-thickness further out than one hanging on bare skin.
	var origin: Vector3 = wound_at + wound_normal.normalized() * lift + local_down * (length * 0.5)
	# `up` points the prism's taper. Downward, so it is wide at the wound and
	# thin where it runs out.
	var up := local_down
	var reference := wound_normal.normalized()
	if absf(up.dot(reference)) > 0.98:
		reference = Vector3.RIGHT
	var right := reference.cross(up).normalized()
	var forward := up.cross(right).normalized()
	return Transform3D(Basis(right, up, forward), origin)
