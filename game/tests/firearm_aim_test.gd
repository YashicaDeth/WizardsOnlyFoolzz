extends Node

const HUNT := preload("res://bone_yard_hunt.tscn")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _mouse(button: MouseButton, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	return event


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var hunt := HUNT.instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame

	# RMB used to call `_attack(true)` for firearms, spending a round without
	# ever creating an aiming state. It now owns a held stance and LMB remains
	# the only trigger.
	hunt._equip_weapon(2)
	var rounds_before := int(hunt.arsenal.ammo.sidearm.loaded)
	hunt._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT, true))
	check(hunt.firearm_aiming, "holding RMB shoulders an equipped firearm")
	check(int(hunt.arsenal.ammo.sidearm.loaded) == rounds_before,
		"entering aim does not silently fire or spend a round")

	# The same deterministic shot seed gives a direct spread comparison: aim
	# changes precision, not luck or damage.
	var forward := Vector3.FORWARD
	var hip: Array[Vector3] = hunt.arsenal.shot_directions(forward, Vector3.UP, 1.0)
	var aimed: Array[Vector3] = hunt.arsenal.shot_directions(forward, Vector3.UP, 0.38)
	check(aimed[0].angle_to(forward) < hip[0].angle_to(forward),
		"aiming measurably tightens the same firearm shot")

	var ordinary_fov: float = hunt.camera.fov
	for frame in range(20):
		hunt._update_camera()
	check(hunt.firearm_aim_blend > 0.9 and hunt.camera.fov < ordinary_fov - 10.0,
		"the sight eases toward the eye instead of snapping or doing nothing")
	hunt._update_player(0.05)
	check(is_zero_approx(hunt.body_motion.combat_pose),
		"first person keeps the exterior shoulder pose out of the camera")
	hunt.body_motion.set_perspective(false)
	hunt._update_player(0.05)
	check(hunt.body_motion.combat_pose > 0.99 and hunt.body_motion.combat_kind == "firearm",
		"third person carries the full shouldered aiming silhouette")

	hunt._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT, false))
	check(not hunt.firearm_aiming, "releasing RMB lowers the firearm")
	hunt.body_motion.set_perspective(true)
	hunt._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT, true))
	hunt._toggle_panel("index")
	check(not hunt.firearm_aiming, "opening a reader cannot strand a held aiming state")
	hunt._toggle_panel("index")
	hunt._equip_weapon(0)
	hunt._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT, true))
	check(not hunt.pending_attack.is_empty() and bool(hunt.pending_attack.get("heavy", false)),
		"RMB still commits a heavy melee attack when a firearm is not equipped")

	print("FIREARM_AIM_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
