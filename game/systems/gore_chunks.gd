class_name GoreChunks
extends RefCounted

## Pieces of people, as physical objects that know what they are.
##
## Greg's brief: *"chunk physics that then get down to the layers of blood bones
## organs chunks — that's how you can rob cybernetics."* The second half is why
## this is a system rather than an effect. A chunk is not decoration that
## despawns; it is an **identified object** carrying its layer, its zone, the
## subject it came off and, where relevant, which organ or which implant. Three
## unbuilt things need exactly that and cannot be built without it:
##
## - **B5, robbing cybernetics.** You dig through the layers and the part that
##   comes out is the part that was installed, with a name and an owner.
## - **Camera rituals** (`DESIGN/RITUAL_AND_KARMA.md`). A ritual that says
##   "photograph five gored heads" has to be able to check that what is in frame
##   is actually a head and actually gored.
## - **The economy.** Organs and hardware are worth something to the Choir, and
##   the thing you sell has to be a specific thing.
##
## Depth is the other half. A hit does not produce a generic red spray — it
## reaches a *layer*, and what comes off is everything it went through. A sword
## into a healthy arm throws skin and muscle. The same sword into an arm already
## opened reaches bone. Blunt trauma barely breaks the skin and shatters what is
## underneath, which is why it gets its own rule.

enum Layer {SKIN, FAT, MUSCLE, BONE, ORGAN, CYBERNETIC}

const LAYER_NAMES := ["skin", "fat", "muscle", "bone", "organ", "cybernetic"]

## Tints per layer. Fat is the one that sells it: a wound that is only red reads
## as paint, and a wound with yellow in it reads as a body.
const LAYER_TINTS := {
	Layer.SKIN: "9a6c5c",
	Layer.FAT: "c8b26a",
	Layer.MUSCLE: "7a1a16",
	Layer.BONE: "cfc2a4",
	Layer.ORGAN: "6d100e",
	Layer.CYBERNETIC: "7d8894",
}

const ORGAN_TINTS := {
	"brain": "9c8a86", "heart": "6d100e", "left_lung": "8a4d4a", "right_lung": "8a4d4a",
	"liver": "5a2015", "gut": "8d7a52", "spine": "cfc2a4",
}

## Chunks are rigid bodies, so this cap is a frame-rate contract rather than an
## aesthetic one. The same reasoning as `BaselineHuman.MAX_LIVE_GORE`: twelve
## drivers shedding unbounded physics bodies in a pileup is a bug, not atmosphere.
const MAX_CHUNKS := 90

static var live: Array[Node3D] = []


## How deep a blow reached, as a `Layer`. The zone's current condition is part of
## the answer — the second cut into the same arm goes further than the first,
## which is the whole reason a fight escalates visually.
static func depth_for(damage: float, damage_type: String, health_ratio: float) -> int:
	var penetrating := damage_type in ["cut", "puncture", "ballistic", "shear"]
	var reach := damage / (10.0 if penetrating else 20.0)
	reach += (1.0 - clampf(health_ratio, 0.0, 1.0)) * 3.0
	if not penetrating:
		# Blunt does not open a body the way an edge does, but it does break what
		# is under the skin - so it reaches bone without passing through muscle
		# in the way a cut would.
		reach -= 0.6
		if damage >= 25.0:
			reach = maxf(reach, float(Layer.BONE))
	return clampi(int(reach), 0, Layer.CYBERNETIC)


## Throws the layers a blow went through. `subject_id` is what makes the pieces
## traceable back to a person, which is the point of the whole system.
static func burst(host: Node3D, origin: Vector3, heading: Vector3, info: Dictionary, detail: float = 1.0) -> Array:
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return []
	var depth := int(info.get("depth", Layer.SKIN))
	var zone := str(info.get("zone", "torso"))
	var subject_id := str(info.get("subject_id", ""))
	var rng := RandomNumberGenerator.new()
	rng.seed = (hash(subject_id + zone) + int(origin.x * 1000.0) + Time.get_ticks_msec()) & 0x7fffffff
	var produced: Array = []
	var direction := heading.normalized() if heading.length() > 0.01 else Vector3.UP
	for layer in range(0, depth + 1):
		# Deeper layers shed fewer, larger pieces. Skin tears into flaps; bone
		# gives you a shard, not a shower of them.
		var count := maxi(1, roundi(float(3 - mini(layer, 2)) * detail))
		if layer == Layer.CYBERNETIC:
			count = 1
		for index in count:
			if live.size() >= MAX_CHUNKS:
				_recycle_oldest()
			var chunk := _make_chunk(layer, zone, subject_id, info, rng)
			if chunk == null:
				continue
			host.get_tree().current_scene.add_child(chunk)
			chunk.global_position = origin + Vector3(rng.randf_range(-0.06, 0.06), rng.randf_range(-0.06, 0.06), rng.randf_range(-0.06, 0.06))
			var scatter := direction * rng.randf_range(1.4, 3.6) + Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(0.4, 2.0), rng.randf_range(-1.2, 1.2))
			chunk.apply_impulse(scatter * chunk.mass)
			chunk.angular_velocity = Vector3(rng.randf_range(-9, 9), rng.randf_range(-9, 9), rng.randf_range(-9, 9))
			live.append(chunk)
			produced.append(chunk)
	return produced


static func _make_chunk(layer: int, zone: String, subject_id: String, info: Dictionary, rng: RandomNumberGenerator) -> RigidBody3D:
	var organ_id := str(info.get("organ_id", ""))
	var implant := str(info.get("implant", ""))
	# The two identified layers only exist if the body actually had one there.
	# Inventing an organ or a piece of hardware that was never installed would
	# make every downstream system - loot, rituals, the economy - lie.
	if layer == Layer.ORGAN and organ_id == "":
		return null
	if layer == Layer.CYBERNETIC and implant == "":
		return null

	var body := RigidBody3D.new()
	body.name = "chunk_%s_%s" % [LAYER_NAMES[layer], zone]
	body.mass = [0.12, 0.18, 0.4, 0.6, 0.5, 0.9][layer]
	body.continuous_cd = true

	var mesh_instance := MeshInstance3D.new()
	var extent := 0.05
	match layer:
		Layer.SKIN:
			var flap := BoxMesh.new()
			flap.size = Vector3(rng.randf_range(0.05, 0.11), 0.008, rng.randf_range(0.05, 0.13))
			mesh_instance.mesh = flap
			extent = 0.07
		Layer.FAT:
			var lump := SphereMesh.new()
			lump.radius = rng.randf_range(0.020, 0.038)
			lump.height = lump.radius * 2.0
			mesh_instance.mesh = lump
			mesh_instance.scale = Vector3(1.0, rng.randf_range(0.6, 1.0), rng.randf_range(0.8, 1.4))
			extent = lump.radius
		Layer.MUSCLE:
			var strand := CapsuleMesh.new()
			strand.radius = rng.randf_range(0.014, 0.026)
			strand.height = rng.randf_range(0.07, 0.16)
			mesh_instance.mesh = strand
			extent = strand.height * 0.5
		Layer.BONE:
			mesh_instance.mesh = BodyMesh.long_bone(rng.randf_range(0.06, 0.13), rng.randf_range(0.007, 0.013))
			extent = 0.07
		Layer.ORGAN:
			var organ := SphereMesh.new()
			organ.radius = 0.055
			organ.height = 0.11
			mesh_instance.mesh = organ
			extent = 0.055
		Layer.CYBERNETIC:
			var core := BoxMesh.new()
			core.size = Vector3(0.06, 0.10, 0.05)
			mesh_instance.mesh = core
			extent = 0.06

	var tint := Color(str(LAYER_TINTS[layer]))
	if layer == Layer.ORGAN:
		tint = Color(str(ORGAN_TINTS.get(organ_id, "6d100e")))
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.45 if layer in [Layer.BONE, Layer.CYBERNETIC] else 0.82
	material.metallic = 0.4 if layer == Layer.CYBERNETIC else 0.0
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = maxf(0.02, extent)
	collider.shape = shape
	body.add_child(collider)

	# The identity. Everything downstream reads this and nothing downstream
	# should ever have to guess from the node name.
	body.set_meta("chunk", {
		"layer": layer,
		"layer_name": LAYER_NAMES[layer],
		"zone": zone,
		"subject_id": subject_id,
		"organ_id": organ_id if layer == Layer.ORGAN else "",
		"implant": implant if layer == Layer.CYBERNETIC else "",
		"taken": false,
	})
	return body


## What this piece is. Returns empty for anything that is not a chunk, so
## callers can test a raycast hit without checking the class first.
static func identify(node: Node) -> Dictionary:
	if node == null or not is_instance_valid(node) or not node.has_meta("chunk"):
		return {}
	return node.get_meta("chunk")


## Pick it up. Removes the physical piece from the world and hands back its
## identity for whoever is carrying it — this is the seam B5 plugs into, and the
## reason it returns the dictionary rather than the node.
static func take(node: Node) -> Dictionary:
	var info := identify(node)
	if info.is_empty() or bool(info.get("taken", false)):
		return {}
	info["taken"] = true
	live.erase(node)
	if is_instance_valid(node):
		node.queue_free()
	return info


## Everything currently on the floor that came off a given person. Rituals and
## the loot pass both want to ask this.
static func from_subject(subject_id: String) -> Array:
	var out: Array = []
	for chunk in live:
		var info := identify(chunk)
		if not info.is_empty() and str(info.get("subject_id", "")) == subject_id:
			out.append(chunk)
	return out


static func _recycle_oldest() -> void:
	while not live.is_empty():
		var oldest: Node3D = live.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
			return


static func clear() -> void:
	for chunk in live:
		if is_instance_valid(chunk):
			chunk.queue_free()
	live.clear()
