extends Node

## AD1.5. "Momentum carries between moves — run into vault into climb is one
## motion." `_vault()` and `_begin_climb()`/the climb-to-mantle handoff in
## `_update_player()` used to leave the far side of every obstacle at a dead
## stop, `move_toward()`'s own ground acceleration rebuilding a run from zero
## on landing — a real stutter this segment names directly. Two halves: a
## vault hands back the speed it interrupted, and a climb's own mantle hands
## back the run that led into the climb, not the climb loop's small
## into-the-wall vector.

## Off the district's centre line: a prop at (0.4, 2, 21.4) now stands
## where x=0 used to be open ground, and blocked the vault's high ray.
const LANE_X := -4.0

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _make_wall(center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	return body


func _settle(hunt) -> void:
	for _tick in 6:
		hunt._update_player(1.0 / 60.0)
		await get_tree().physics_frame


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	hunt.player_body.position = Vector3(LANE_X, 0.9, 19)
	hunt.player_body.velocity = Vector3.ZERO
	hunt.yaw = 0.0
	await _settle(hunt)
	var forward: Vector3 = hunt.HUNTER_MOTOR.wish_direction(Vector2(0, -1), hunt.yaw)

	print("AD1.5 - a vault hands back the run it interrupted, not a dead stop")
	var low_box := _make_wall(Vector3(LANE_X, 0.4, 19.5), Vector3(2.0, 0.8, 0.4))
	add_child(low_box)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var entry_speed := 8.0
	hunt.player_body.velocity = forward * entry_speed
	var target: Dictionary = hunt._vault_target(forward)
	check(not target.is_empty(), "a real vault target is found to trigger against")
	if not target.is_empty():
		hunt._vault(target.landing)
		check(hunt.player_body.velocity.is_zero_approx(), "velocity sits at zero while the scripted lerp is in control")
		for _tick in 40:
			hunt._update_player(1.0 / 60.0)
			if hunt.vaulting_time <= 0.0:
				break
		check(hunt.vaulting_time <= 0.0, "the vault actually finished within the tick budget")
		var landed_speed: float = Vector2(hunt.player_body.velocity.x, hunt.player_body.velocity.z).length()
		check(landed_speed > entry_speed * 0.9, "landing speed (%.2f) is close to the speed that went in (%.2f), not rebuilt from zero" % [landed_speed, entry_speed])
	low_box.queue_free()
	await get_tree().physics_frame

	print("AD1.5 - a climb's own mantle hands back the run that led into it, not the climb's own hug-the-wall vector")
	WorldHistory.record_event("player_wall_run_kickoff", {})
	WorldHistory.record_event("player_wall_run_kickoff", {})
	# The vault above already carried the body past z=19.5 — reset to a
	# fresh approach rather than testing a climb wall the player is
	# standing behind.
	hunt.player_body.position = Vector3(LANE_X, 0.9, 19)
	hunt.player_body.velocity = Vector3.ZERO
	await _settle(hunt)
	var climb_wall := _make_wall(Vector3(LANE_X, 1.5, 19.5), Vector3(2.0, 3.0, 0.4))
	add_child(climb_wall)
	# Flush with the wall's own top — without a real roof to land on,
	# `_vault_target()`'s floor query has nothing to find no matter how
	# far the climb gets, since it searches close to the height the climb
	# has actually reached, not all the way down to the ground far below.
	var roof := _make_wall(Vector3(LANE_X, 2.9, 21.0), Vector3(4.0, 0.2, 4.0))
	add_child(roof)
	await get_tree().physics_frame
	await get_tree().physics_frame
	hunt.player_body.velocity = forward * entry_speed
	var climb_start: Dictionary = hunt._climb_wall(forward)
	check(not climb_start.is_empty(), "a real climb is found to trigger against")
	if not climb_start.is_empty():
		hunt._begin_climb(forward, climb_start.normal)
		check(is_equal_approx(hunt.climb_entry_speed, entry_speed) or hunt.climb_entry_speed >= entry_speed * 0.9, "the run speed the climb replaced is actually recorded (%.2f)" % hunt.climb_entry_speed)
		var mantled := false
		for _tick in 90:
			hunt._update_player(1.0 / 60.0)
			if hunt.climbing_time <= 0.0:
				mantled = hunt.vaulting_time > 0.0
				break
		check(mantled, "the climb actually chained into a mantle within the tick budget")
		if mantled:
			for _tick in 40:
				hunt._update_player(1.0 / 60.0)
				if hunt.vaulting_time <= 0.0:
					break
			check(hunt.vaulting_time <= 0.0, "...and the mantle itself finished")
			var post_climb_speed: float = Vector2(hunt.player_body.velocity.x, hunt.player_body.velocity.z).length()
			check(post_climb_speed > entry_speed * 0.5, "speed on the far side of the climb (%.2f) reflects the run that led into it, not the climb loop's own small vector" % post_climb_speed)

	print("MOMENTUM_CARRY_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
