extends Node

## AF1.7. "It reads through the anatomy already built: a round finds a zone,
## not a hitbox." `_trace_actor` already resolves a real raycast against real
## collision geometry, and `BaselineHuman.hit_at` already turns the exact
## world-space impact point into `zone_nearest(point)` rather than reading a
## name off whatever collider answered. What was missing was proof: nothing
## in this project exercised that a shot's outcome actually tracks *where it
## was aimed*, as opposed to a fixed or round-robin zone table that would
## also pass `combat_integration_test.gd`'s weaker "some canonical zone"
## check.
##
## The target stays at one ordinary spawn height throughout — only the aim
## changes, computed from that actor's own real part positions rather than a
## guessed number, so the test cannot pass by accident the way moving the
## target into an unspawned height range nearly did during authoring (a body
## sunk far enough into the floor stopped registering hits at all, which is
## its own small proof that this is real physics rather than an abstract
## lookup).

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


## One shot at one real target, aimed at whichever of its own zones is named,
## using the exact angle that zone's own current world position demands.
## Returns the set of zones the shot actually wounded.
func _fire_at_zone(target_zone: String) -> Array[String]:
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	hunt.player_body.position = Vector3(175, 0.9, 125)
	hunt.player = hunt.player_body.position + Vector3.UP * 0.6
	hunt.yaw = 0.0
	hunt.pitch = 0.0
	hunt.third_person = false
	hunt._update_camera()
	# One ordinary spawn height, same as every other actor test in this
	# project uses — the aim does the work, not the target's placement.
	hunt._spawn_encounter_actor({"instance_id": "zone_probe_%s" % target_zone, "kind": "hostile", "summary": "zone probe"}, hunt.player + Vector3(0, -0.5, 6))
	var actor: Dictionary = hunt.encounter_actors.back()
	actor.node.position = hunt.player + Vector3(0, -0.5, 6)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var rig := actor.rig as BaselineHuman
	var target_point: Vector3 = (rig.parts.get(target_zone) as Node3D).global_position
	var origin: Vector3 = hunt.camera.global_position
	var to_target := target_point - origin
	# yaw stays 0 (the target sits dead ahead on the same X); pitch alone
	# carries the whole aim, read back out of the real geometry rather than
	# asserted, so a future change to the rig's proportions cannot leave this
	# test quietly aiming at the wrong height.
	hunt.pitch = atan2(to_target.y, Vector2(to_target.x, to_target.z).length())

	hunt._equip_weapon(2) # sidearm: one pellet, 0.008 spread — as close to a laser as this arsenal has
	hunt._attack()
	# AF1.1. The round travels now — a few real physics frames, not the
	# frame the trigger went down, before the wound this test checks for
	# actually lands.
	for _tick in 10:
		await get_tree().physics_frame
	var zones: Array[String] = []
	for wound in actor.anatomy.wounds:
		var zone := str(wound.get("zone", ""))
		if not zones.has(zone):
			zones.append(zone)
	hunt.queue_free()
	await get_tree().process_frame
	return zones


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	# Same body, same distance, same weapon — the only thing that changes
	# between shots is the pitch, read straight off each zone's own real
	# position. A hardcoded or round-robin zone could not track this.
	var head_zones := await _fire_at_zone("head")
	check(head_zones.has("head"), "aiming at the real position of \"head\" actually wounds it (%s)" % str(head_zones))
	check(not head_zones.has("left_leg") and not head_zones.has("right_leg"), "and not a leg (%s)" % str(head_zones))

	var torso_zones := await _fire_at_zone("torso")
	check(torso_zones.has("torso"), "the same weapon aimed at \"torso\"'s own position wounds torso (%s)" % str(torso_zones))
	check(not torso_zones.has("head"), "and not the head (%s)" % str(torso_zones))

	var leg_zones := await _fire_at_zone("left_leg")
	check(leg_zones.has("left_leg"), "aimed at \"left_leg\"'s own position, that is what gets hit (%s)" % str(leg_zones))
	check(not leg_zones.has("head") and not leg_zones.has("torso"), "and neither the head nor the torso (%s)" % str(leg_zones))

	if failures.is_empty():
		print("zone precision: the round finds where it was actually aimed, not a table")
		get_tree().quit(0)
	else:
		print("zone precision FAILURES: ", failures)
		get_tree().quit(1)
