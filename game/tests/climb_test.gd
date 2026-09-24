extends Node

## AD1.4. "Climbing a building is a route, not a cutscene." Coverage in three
## halves: the unlock is a real read of `player_wall_run_kickoff` events, the
## same shape `wall_run_unlocked()` already uses one rung down; `_climb_wall()`
## finds a wall too tall for `_vault_target()`'s own high check and refuses one
## that isn't; and a triggered climb actually ascends over real time, chains
## straight into `_vault_target()`'s own scripted mantle the instant a ledge
## comes within reach with no key pressed for either half, and ends honestly
## — falling, not soft-locking — when the wall it was climbing disappears.

## The generated Hunt Grounds contain real collision.  This test has to own
## every raycast target or a new district prop can turn a traversal assertion
## into a test of unrelated scenery.
const ARENA_Y := 400.0

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
	var arena_floor := _make_wall(Vector3(0, ARENA_Y - 0.5, 19), Vector3(30.0, 1.0, 60.0))
	add_child(arena_floor)
	await get_tree().physics_frame
	hunt.player_body.position = Vector3(0, ARENA_Y + 0.9, 19)
	hunt.player_body.velocity = Vector3.ZERO
	hunt.yaw = 0.0
	await _settle(hunt)
	var forward: Vector3 = hunt.HUNTER_MOTOR.wish_direction(Vector2(0, -1), hunt.yaw)

	print("AD1.4 - earned one rung past wall-running, off a real count")
	check(not hunt.climb_unlocked(), "not unlocked with zero kickoffs on record")
	WorldHistory.record_event("player_wall_run_kickoff", {})
	check(not hunt.climb_unlocked(), "still not unlocked one short of the threshold")
	WorldHistory.record_event("player_wall_run_kickoff", {})
	check(hunt.climb_unlocked(), "unlocked the instant the real count crosses CLIMB_UNLOCK_KICKOFFS (%d)" % hunt.CLIMB_UNLOCK_KICKOFFS)

	print("AD1.4 - a wall too tall to vault, dead ahead, is a real, findable climb")
	var tall_wall := _make_wall(Vector3(0, ARENA_Y + 1.5, 19.5), Vector3(2.0, 3.0, 0.4))
	add_child(tall_wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var climb: Dictionary = hunt._climb_wall(forward)
	check(not climb.is_empty(), "a 3m wall within reach, facing it, is found")
	if not climb.is_empty():
		check(climb.normal.dot(forward) < 0.0, "the normal actually points back out of the wall")

	print("AD1.4 - a vaultable box is AD1.2's obstacle, not this one's")
	tall_wall.queue_free()
	await get_tree().physics_frame
	var low_box := _make_wall(Vector3(0, ARENA_Y + 0.4, 19.5), Vector3(2.0, 0.8, 0.4))
	add_child(low_box)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(hunt._climb_wall(forward).is_empty(), "a 0.8m box fails the high cast and is correctly left to the vault")
	check(not hunt._vault_target(forward).is_empty(), "...which finds it fine")
	low_box.queue_free()
	await get_tree().physics_frame

	print("AD1.4/AD1.5 - triggering one actually ascends, and chains into a mantle with no key pressed for either half")
	var climb_wall := _make_wall(Vector3(0, ARENA_Y + 1.5, 19.5), Vector3(2.0, 3.0, 0.4))
	add_child(climb_wall)
	# A wall with nothing to land on top of is not a mantle a real building
	# would offer either — this is the roof `_vault_target()`'s own floor
	# query is looking for, flush with the wall's own top.
	var roof := _make_wall(Vector3(0, ARENA_Y + 2.9, 21.0), Vector3(4.0, 0.2, 4.0))
	add_child(roof)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var start: Dictionary = hunt._climb_wall(forward)
	check(not start.is_empty(), "found again for the live attempt")
	if not start.is_empty():
		hunt._begin_climb(forward, start.normal)
		check(hunt.climbing_time > 0.0, "beginning a climb is a timed state, not an instant flag")
		var before_y: float = hunt.player_body.position.y
		var mantled := false
		for _tick in 90:
			hunt._update_player(1.0 / 60.0)
			if hunt.climbing_time <= 0.0:
				mantled = hunt.vaulting_time > 0.0
				break
		check(mantled, "the climb ends by chaining into a real mantle once a ledge is within reach, not merely by running out of climb")
		if mantled:
			for _tick in 40:
				hunt._update_player(1.0 / 60.0)
				if hunt.vaulting_time <= 0.0:
					break
			check(hunt.vaulting_time <= 0.0, "...and the mantle itself actually finishes")
			check(hunt.player_body.position.y > before_y, "real vertical travel happened, not a teleport to the top")

	print("AD1.4 - a wall that disappears mid-climb is falling, not a soft-lock")
	climb_wall.queue_free()
	await get_tree().physics_frame
	var second_wall := _make_wall(Vector3(0, ARENA_Y + 1.5, 15.5), Vector3(2.0, 3.0, 0.4))
	add_child(second_wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	hunt.player_body.position = Vector3(0, ARENA_Y + 0.9, 15)
	hunt.player_body.velocity = Vector3.ZERO
	await _settle(hunt)
	var second_start: Dictionary = hunt._climb_wall(forward)
	check(not second_start.is_empty(), "the second wall is found on its own")
	if not second_start.is_empty():
		hunt._begin_climb(forward, second_start.normal)
		hunt._update_player(1.0 / 60.0)
		check(hunt.climbing_time > 0.0, "and a real climb has begun")
		second_wall.queue_free()
		await get_tree().physics_frame
		hunt._update_player(1.0 / 60.0)
		check(hunt.climbing_time <= 0.0, "...but ends the instant the wall it depends on is gone, rather than continuing to climb nothing")

	print("CLIMB_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
