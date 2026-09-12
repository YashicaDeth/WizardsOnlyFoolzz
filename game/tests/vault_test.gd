extends Node

## AD1.2. "Vaulting and mantling: waist-high things stop being walls."
## Three raycasts do the deciding (`_vault_target()`); this proves each one
## earns its keep against real collision geometry rather than a story about
## what they should do — a low box gets vaulted, a tall one does not, an
## empty stretch of ground returns nothing, and once triggered the body
## actually arrives at the far side over `VAULT_DURATION`, not instantly.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _make_box(center: Vector3, size: Vector3) -> StaticBody3D:
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
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	hunt.player_body.position = Vector3(0, 0.9, 19)
	hunt.player_body.velocity = Vector3.ZERO
	hunt.yaw = 0.0
	await _settle(hunt)
	check(hunt.player_body.is_on_floor(), "the player starts grounded, facing +Z (yaw 0)")
	var forward: Vector3 = hunt.HUNTER_MOTOR.wish_direction(Vector2(0, -1), hunt.yaw)

	print("AD1.2 - nothing in front of the player is nothing to vault")
	check(hunt._vault_target(forward).is_empty(), "open ground ahead returns no target")

	print("AD1.2 - a waist-high box in front is a real, findable vault")
	var low_wall := _make_box(Vector3(0, 0.4, 19.5), Vector3(2.0, 0.8, 0.4))
	add_child(low_wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var low_target: Dictionary = hunt._vault_target(forward)
	check(not low_target.is_empty(), "a 0.8m box within reach is found")
	if not low_target.is_empty():
		var landing: Vector3 = low_target.landing
		check(landing.z > 19.5, "...landing past the box, not on top of it (z=%.2f)" % landing.z)
		check(absf(landing.y - 0.95) < 0.25, "...landing near the real floor height, not the box's own top (y=%.2f)" % landing.y)

	print("AD1.2 - a real wall stays a wall")
	low_wall.queue_free()
	await get_tree().physics_frame
	var tall_wall := _make_box(Vector3(0, 1.1, 19.5), Vector3(2.0, 2.2, 0.4))
	add_child(tall_wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(hunt._vault_target(forward).is_empty(), "a 2.2m wall in the same spot is correctly refused - the high ray finds it")
	tall_wall.queue_free()
	await get_tree().physics_frame

	print("AD1.2 - triggering one actually carries the body across, over real time")
	var low_wall2 := _make_box(Vector3(0, 0.4, 19.5), Vector3(2.0, 0.8, 0.4))
	add_child(low_wall2)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var target: Dictionary = hunt._vault_target(forward)
	check(not target.is_empty(), "found again for the live attempt")
	if not target.is_empty():
		hunt._vault(target.landing)
		check(hunt.vaulting_time > 0.0, "the vault is a timed motion, not an instant teleport")
		var start_z: float = hunt.player_body.position.z
		hunt._update_player(1.0 / 60.0)
		var mid_z: float = hunt.player_body.position.z
		check(mid_z > start_z, "one physics step in, the body has actually moved toward the far side")
		check(hunt.vaulting_time > 0.0 and hunt.vaulting_time < hunt.VAULT_DURATION, "...and the vault is still in progress, not finished in one step")
		for _tick in 60:
			hunt._update_player(1.0 / 60.0)
			if hunt.vaulting_time <= 0.0:
				break
		check(hunt.vaulting_time <= 0.0, "the vault finishes on its own")
		check(hunt.player_body.position.is_equal_approx(target.landing), "...and lands exactly on the point the raycasts actually found")

	print("AD1.2 - normal movement resumes; a vault is not a soft-lock")
	hunt.player_body.velocity = Vector3(1, 0, 0)
	hunt._update_player(1.0 / 60.0)
	check(hunt.player_body.velocity.length() > 0.0 or hunt.player_body.is_on_floor(), "movement/gravity is back in control once the vault ends")

	print("VAULT_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
