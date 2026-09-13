extends Node

## AB1.1 / AB1.3 / AB1.5. A vehicle deforms rather than losing hit points, and
## what comes off it is real debris rather than a private effect.
##
## Three claims, each one a real bug in the old code:
##  - Detach thresholds and the crush visual read against a flat 100 rather
##    than this chassis's own ceiling, so the rival's authored 160-integrity
##    chassis stayed pristine-looking and kept every panel until well past
##    half its actual health.
##  - `detached_parts` lived as loose `set_meta`, the exact pattern V1.1
##    already fixed for hull integrity on this same file.
##  - A shed panel hung its own 14-second `SceneTree` timer to make itself
##    disappear, instead of the pool-capped, rot-tracked, pickup-eligible
##    registry `GoreChunks` already gives every other broken piece in the game.

const DERBY := preload("res://rift_derby.tscn")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var derby: Node = DERBY.instantiate()
	add_child(derby)
	derby.leaving = true
	for _settle in 20:
		await get_tree().physics_frame

	var boat: ArcadeVehicle = derby.get("boat")
	var targets: Array = derby.get("targets")
	var rival: ArcadeVehicle = null
	for target in targets:
		if bool((target as Node).get_meta("is_rival", false)):
			rival = target
	check(rival != null, "the rival wrecker spawned")
	check(rival.max_integrity == 160, "sanity: the rival really is the tougher chassis")

	# --- proportional thresholds, not an absolute score out of 100 ----------
	boat.integrity = 76
	derby.call("_update_detachable_parts", boat, Vector3.ZERO)
	check(boat.detached_parts.is_empty(), "a 100-max chassis at 76/100 (76%) is still above the first threshold")
	boat.integrity = 74
	derby.call("_update_detachable_parts", boat, Vector3.ZERO)
	check(boat.detached_parts.has("BumperFront"), "and at 74/100 (74%) the first panel goes")

	rival.integrity = 122
	derby.call("_update_detachable_parts", rival, Vector3.ZERO)
	check(rival.detached_parts.is_empty(), "the rival at 122/160 (76%) — proportionally identical to the case above — is also still above the threshold")
	rival.integrity = 118
	derby.call("_update_detachable_parts", rival, Vector3.ZERO)
	check(rival.detached_parts.has("BumperFront"), "and at 118/160 (74%) it sheds its first panel too, at the same fraction as the ordinary car")

	# --- the crush visual reads the same fraction, not the same raw number --
	rival.integrity = 160
	boat.integrity = 100
	derby.call("_update_wrecker_damage_visual", rival, Vector3.ZERO)
	var rival_shell := rival.get_node_or_null("ScrapVehicleShell") as Node3D
	check(rival_shell != null, "sanity: the rival's shell exists")
	var pristine_scale: Vector3 = rival_shell.scale
	rival.integrity = 40
	derby.call("_update_wrecker_damage_visual", rival, Vector3.ZERO)
	check(not rival_shell.scale.is_equal_approx(pristine_scale), "the rival visibly deforms well before it is anywhere near 0 out of its own 160")

	# --- real debris: registered, identified, and not on a private timer ----
	var before_live := GoreChunks.live_count()
	derby.call("_detach_vehicle_part", boat, "Hood", Vector3(0, 0, -1))
	check(boat.detached_parts.has("Hood"), "detaching a named panel records it on the chassis itself, not as loose metadata")
	check(GoreChunks.live_count() == before_live + 1, "the shed panel actually joins the same registry every gore chunk lives in")

	var hood_node: Node3D = null
	for chunk in GoreChunks.live:
		if is_instance_valid(chunk) and chunk.name == "Hood_Detached":
			hood_node = chunk
	check(hood_node != null, "the detached piece is findable in GoreChunks.live by name")
	var info := GoreChunks.identify(hood_node)
	check(not info.is_empty(), "GoreChunks.identify() recognises it as a real chunk, not an anonymous RigidBody3D")
	check(str(info.get("zone", "")) == "Hood", "its identity names the actual part, honestly, not a body zone that never existed")
	check(str(info.get("subject_id", "")) == "vehicle:%s" % str(boat.name), "and it traces back to the specific car it came off")
	check(not bool(info.get("whole_limb", true)), "it is honestly labelled as debris, not mislabelled as a severed limb")

	_report()


func _report() -> void:
	if failures.is_empty():
		print("vehicle debris: a car deforms and what comes off it is real")
		get_tree().quit(0)
	else:
		print("vehicle debris FAILURES: ", failures)
		get_tree().quit(1)
