extends Node

## AD1.6. "All of it reads through the anatomy: a broken leg cannot vault."
## `mobility_ratio()` already existed and already gated running speed
## (B6.5) — this proves the same real signal now gates and scales the
## three AD1 verbs too, rather than a second injury number invented for
## traversal: a leg destroyed outright refuses a vault and a wall run
## outright, a merely-hurt body still gets through but slower, and a
## healthy jump is not the same height as a hobbled one.

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
	WorldHistory.record_event("player_vaulted", {})
	WorldHistory.record_event("player_vaulted", {})
	WorldHistory.record_event("player_vaulted", {})
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
	var low_wall := _make_wall(Vector3(0, 0.4, 19.5), Vector3(2.0, 0.8, 0.4))
	add_child(low_wall)
	var tall_wall := _make_wall(Vector3(0, 1.4, 19) + side * 0.9, Vector3(0.4, 3.0, 40.0))
	add_child(tall_wall)
	await get_tree().physics_frame
	await get_tree().physics_frame

	print("AD1.6 - a healthy body clears the gate and vaults/runs at full strength")
	check(hunt.player_rig.anatomy.mobility_ratio() >= 0.999, "starts fully healthy")
	check(not hunt._vault_target(forward).is_empty(), "a healthy body can vault the low wall")
	hunt._jump()
	hunt._update_player(1.0 / 60.0)
	var healthy_jump_velocity: float = hunt.player_body.velocity.y
	check(is_equal_approx(healthy_jump_velocity, hunt.JUMP_IMPULSE), "a healthy jump gets the full, unscaled impulse (%.2f)" % healthy_jump_velocity)

	print("AD1.6 - one leg destroyed reads as a real, literal 'broken leg'")
	hunt.player_body.position = Vector3(0, 0.9, 19)
	hunt.player_body.velocity = Vector3.ZERO
	await _settle(hunt)
	hunt.player_rig.anatomy.zones.left_leg.health = 0.0
	var mobility: float = hunt.player_rig.anatomy.mobility_ratio()
	check(mobility < hunt.PLAYER_INJURY_FLOOR, "one leg gone drops mobility below the same floor B6.5 already gates speed on (%.2f)" % mobility)
	check(hunt._vault_target(forward).is_empty(), "...and a vault the healthy body could make is now refused outright")
	check(hunt._wall_run_surface(forward).is_empty(), "...and so is a wall run the healthy body could hold")
	hunt._jump()
	hunt._update_player(1.0 / 60.0)
	var hobbled_jump_velocity: float = hunt.player_body.velocity.y
	check(hobbled_jump_velocity > 0.0 and hobbled_jump_velocity < healthy_jump_velocity, "a jump is still possible - basic traversal never fully locks out - but it is a visibly smaller one (%.2f vs %.2f)" % [hobbled_jump_velocity, healthy_jump_velocity])

	print("AD1.6 - merely hurt, not broken: still gets through, just not at full health's pace")
	hunt.player_rig.anatomy.zones.left_leg.health = 60.0
	hunt.player_rig.anatomy.zones.right_leg.health = 60.0
	var bruised: float = hunt.player_rig.anatomy.mobility_ratio()
	check(bruised >= hunt.PLAYER_INJURY_FLOOR, "a bruised, not broken, pair of legs clears the same floor (%.2f)" % bruised)
	hunt.player_body.position = Vector3(0, 0.9, 19)
	hunt.player_body.velocity = Vector3.ZERO
	await _settle(hunt)
	var bruised_target: Dictionary = hunt._vault_target(forward)
	check(not bruised_target.is_empty(), "...so the vault still goes through")
	if not bruised_target.is_empty():
		hunt._vault(bruised_target.landing)
		check(hunt.vault_duration > hunt.VAULT_DURATION, "...but takes visibly longer than a healthy one would (%.3f vs %.3f)" % [hunt.vault_duration, hunt.VAULT_DURATION])

	print("ANATOMY_TRAVERSAL_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
