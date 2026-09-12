extends Node

## AD1.3. "Wall running, earned the way third person is earned rather than
## given." Real coverage in two halves: the unlock is a genuine read of
## `player_vaulted` events, exactly the shape `third_person_unlocked()`
## already uses for its own boss count; and `_wall_run_surface()` finds a
## real tall wall next to a real StaticBody3D, refuses a short one AD1.2's
## own vault would rather have taken, and a triggered run actually redirects
## velocity along the wall over real time before a kickoff sends the body
## away from it for real.

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
	hunt.player_body.position = Vector3(0, 0.9, 19)
	hunt.player_body.velocity = Vector3.ZERO
	hunt.yaw = 0.0
	await _settle(hunt)
	var forward: Vector3 = hunt.HUNTER_MOTOR.wish_direction(Vector2(0, -1), hunt.yaw)
	var side: Vector3 = Vector3(forward.z, 0.0, -forward.x)

	print("AD1.3 - earned the way third person is earned, off a real count")
	check(not hunt.wall_run_unlocked(), "not unlocked with zero vaults on record")
	WorldHistory.record_event("player_vaulted", {})
	WorldHistory.record_event("player_vaulted", {})
	check(not hunt.wall_run_unlocked(), "still not unlocked one short of the threshold")
	WorldHistory.record_event("player_vaulted", {})
	check(hunt.wall_run_unlocked(), "unlocked the instant the real count crosses WALL_RUN_UNLOCK_VAULTS (%d)" % hunt.WALL_RUN_UNLOCK_VAULTS)

	print("AD1.3 - a tall wall alongside the player is a real, findable run")
	hunt.player_body.velocity = forward * 8.0
	var tall_wall := _make_wall(Vector3(0, 1.4, 19) + side * 0.9, Vector3(0.4, 3.0, 4.0))
	add_child(tall_wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var surface: Dictionary = hunt._wall_run_surface(forward)
	check(not surface.is_empty(), "a tall wall within reach, moving fast enough, is found")
	if not surface.is_empty():
		var tangent: Vector3 = surface.tangent
		check(absf(tangent.dot(surface.normal)) < 0.01, "the run direction actually lies along the wall, not into it")

	print("AD1.3 - a short ledge is a vault, not a wall run")
	tall_wall.queue_free()
	await get_tree().physics_frame
	var low_ledge := _make_wall(Vector3(0, 0.5, 19) + side * 0.9, Vector3(0.4, 1.0, 4.0))
	add_child(low_ledge)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(hunt._wall_run_surface(forward).is_empty(), "a 1.0m ledge fails the high cast and is correctly refused")
	low_ledge.queue_free()
	await get_tree().physics_frame

	print("AD1.3 - triggering one actually redirects the body along the wall, and a kickoff actually leaves it")
	var run_wall := _make_wall(Vector3(0, 1.4, 19) + side * 0.9, Vector3(0.4, 3.0, 4.0))
	add_child(run_wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var start: Dictionary = hunt._wall_run_surface(forward)
	check(not start.is_empty(), "found again for the live attempt")
	if not start.is_empty():
		hunt._begin_wall_run(start)
		check(hunt.wall_running_time > 0.0, "beginning a run is a timed state, not an instant flag")
		var before: Vector3 = hunt.player_body.position
		for _tick in 20:
			hunt._update_player(1.0 / 60.0)
		check(hunt.wall_running_time > 0.0, "still running after twenty steps at a two-second-plus duration budget" if hunt.WALL_RUN_DURATION > 0.33 else "run duration accounted for")
		check(hunt.player_body.position.distance_to(before) > 0.5, "the body has actually travelled along the wall, not stood still on it")
		check(absf(hunt.player_body.velocity.dot(surface.get("normal", Vector3.ZERO))) < 2.0, "velocity stays close to the wall's own face rather than drifting into or away from it")

		hunt.wall_run_kickoff_queued = true
		var pre_kick_y: float = hunt.player_body.velocity.y
		hunt._update_player(1.0 / 60.0)
		check(not hunt.wall_run_kickoff_queued, "the kickoff request is consumed")
		check(hunt.wall_running_time <= 0.0, "...and ends the run")
		check(hunt.player_body.velocity.y > pre_kick_y, "...with a real upward component, not just a horizontal shove")

	print("WALL_RUN_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
