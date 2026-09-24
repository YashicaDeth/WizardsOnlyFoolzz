extends Node

## The bone that breaks is the bone that was there.
##
## `_make_chunk()` called `BodyMesh.long_bone()` for every zone, which is the
## one shape in a body that only a limb has. A skull shattered into femur
## shards, and so did a ribcage -- and now that `SkullBurst` opens a head, that
## is the debris a player is looking at from close range.
##
## The shapes are told apart by their own geometry rather than by which call
## made them: `arc_tube()` lies in XZ with its thickness in Y, so a plate is
## flat; `long_bone()` revolves along Y, so a shaft is long.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func rng_at(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng


func size_of(fragment: Dictionary) -> Vector3:
	var mesh := fragment.get("mesh") as ArrayMesh
	if mesh == null:
		return Vector3.ZERO
	return mesh.get_aabb().size


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	print("-- a cranium comes away as plate --")
	var head := GoreChunks.bone_fragment("head", rng_at(11))
	var head_size := size_of(head)
	check(head_size != Vector3.ZERO, "a head bone fragment has geometry (%.3f, %.3f, %.3f)" % [head_size.x, head_size.y, head_size.z])
	# Flat: the thickness axis is the smallest of the three.
	check(head_size.y < head_size.x and head_size.y < head_size.z, "and is flatter than it is wide")
	check(float(head.get("extent", 0.0)) > 0.0, "and reports a radius the collider can use")

	print("-- a chest comes away as rib --")
	var torso := GoreChunks.bone_fragment("torso", rng_at(12))
	var torso_size := size_of(torso)
	check(torso_size.y < torso_size.x and torso_size.y < torso_size.z, "a rib section is curved plate, not a shaft")
	check(torso_size.x > head_size.x, "and a longer run of it than a skull gives (%.3f against %.3f)" % [torso_size.x, head_size.x])

	print("-- a limb is the only thing with a long bone in it --")
	for zone in ["left_arm", "right_arm", "left_leg", "right_leg"]:
		var limb := GoreChunks.bone_fragment(zone, rng_at(13))
		var limb_size := size_of(limb)
		# Long: the revolve axis is the largest, which is the opposite of a plate.
		check(limb_size.y > limb_size.x and limb_size.y > limb_size.z, "%s sheds a shaft, longer than it is thick" % zone)

	print("-- and an unknown zone still sheds something --")
	var stray := GoreChunks.bone_fragment("tail", rng_at(14))
	check(size_of(stray) != Vector3.ZERO, "a zone nobody has modelled falls back to a shaft rather than to nothing")

	print("-- the shapes are actually different --")
	var same_seed_head := size_of(GoreChunks.bone_fragment("head", rng_at(21)))
	var same_seed_limb := size_of(GoreChunks.bone_fragment("left_arm", rng_at(21)))
	check(same_seed_head != same_seed_limb, "the same seed in a head and an arm does not give the same bone")

	print("BONE_FRAGMENT_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
