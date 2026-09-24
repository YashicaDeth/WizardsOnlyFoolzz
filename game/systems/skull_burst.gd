class_name SkullBurst
extends RefCounted

## When a head comes apart, and what is left of it when it does.
##
## The rifle was calibrated so that a head hit would be past argument: a brain
## holds 18 points and ASHLINE LONGVIEW lands 78. That kills, ruptures the
## brain, and earns the X-ray finisher -- and then leaves a perfectly intact
## ovoid head sitting on the corpse. `BaselineHuman.LIMBS` names four limbs,
## the head is not one of them, and `_accumulate_sever_stress()` refuses the
## zone on that line before it looks at the damage at all. So the skull came
## apart on the plate and nowhere else, and the body the player walks up to
## afterwards is unmarked above the neck.
##
## This is the other half of it. A system rather than four lines inside the rig
## for the same reason `KillShot` is one: the failure it can have is taking
## somebody's head off over a graze, or over a jaw wound they were going to
## walk away from, and that is worth being able to test without instantiating a
## world.

## Blows that open a skull rather than cave it in. Blunt trauma is ruinous to a
## head and it is not this -- what this does is take a piece *away*, and a club
## does not remove anything. `GoreChunks.depth_for()` already gives blunt its
## own rule for the same reason.
const OPENING_DAMAGE := ["ballistic", "shear", "cut"]

## Twice what a brain can take.
##
## The sidearm's 24 already reaches the brain and kills with it, and that is a
## hole in a head rather than a head coming apart. The rifle's 78 is the round
## that takes the cranium off. The line sits between them on purpose: if
## anything that killed via a head did this, the sniper's shot would stop being
## the one you line up, which is the same argument `KillShot.FINISHER_WEAPONS`
## is making about the camera.
const CRANIUM_THRESHOLD := 36.0

## Shallower than a chest. `Cavity.WALL_DEPTH` is sized for a torso, and on a
## head it puts the plane near the middle of the skull and takes half the head
## off in one piece -- which reads as a bisection rather than a blowout.
const CRANIUM_DEPTH := 0.032


## Whether this blow takes the top off, given the anatomy *after* it landed.
##
## Empty and false are the normal answers. Most head wounds are not this, and
## the caller is expected to carry on without one.
static func earned(zone: String, damage: float, damage_type: String, snapshot: Dictionary) -> bool:
	# Where the round landed, not only what it found. A ruptured brain is a
	# lasting fact about a body: without this line, putting a rifle round into
	# the chest of a corpse that was killed earlier by a sidearm to the head
	# would take the top off a head nothing had just hit.
	if zone != "head":
		return false
	if not OPENING_DAMAGE.has(damage_type):
		return false
	if damage < CRANIUM_THRESHOLD:
		return false
	# A head that comes apart on somebody still standing has a very short window
	# before the player notices, so this takes the rule `KillShot` already uses:
	# the body has to actually be finished.
	if not bool(snapshot.get("dead", false)):
		return false
	var organs: Dictionary = snapshot.get("organs", {}) if snapshot.get("organs") is Dictionary else {}
	var brain: Dictionary = organs.get("brain", {}) if organs.get("brain") is Dictionary else {}
	# The brain is what makes it a head shot rather than a hit on a head. A
	# round through the jaw at the same energy is a ruined face, not this.
	return bool(brain.get("ruptured", false))


## Take the cranium off, on the side the round left by.
##
## `travel` is the direction the round was going, so the piece that comes away
## is the exit side: a hole in the forehead blows the back of the head out, not
## the front of it. Returns empty when the cut found nothing, which includes a
## head already opened -- a second rifle round into the same corpse does not get
## to keep shaving it down.
static func open(rig: Node3D, travel: Vector3) -> Dictionary:
	if rig == null or not is_instance_valid(rig):
		return {}
	var cut := Cavity.open_zone(rig, "head", travel, CRANIUM_DEPTH)
	if cut.is_empty():
		return {}
	# Bone, because the piece is a cranium. It is what decides the sound it
	# lands with and what the Choir is being offered.
	var cranium := Cavity.shed_wall(rig, cut, travel, GoreChunks.Layer.BONE)
	return {
		"zone": "head",
		"cranium": cranium,
		"organs": cut.get("organs", []),
		"area": float(cut.get("area", 0.0)),
	}
