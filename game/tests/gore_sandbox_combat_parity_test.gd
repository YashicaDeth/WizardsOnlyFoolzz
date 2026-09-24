extends Node

## AG5.32. The range teaches the Hunt's firearm and evasive footwork instead
## of binding the same buttons to unrelated sandbox-only actions.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func mouse_button(button: MouseButton, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	return event


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var demo = load("res://gore_demo.tscn").instantiate()
	add_child(demo)
	await get_tree().physics_frame
	demo.set_physics_process(false)

	print("AG5.32 - sandbox RMB is the production firearm stance")
	var rounds_before: int = int((demo.arsenal.ammo[demo.arsenal.current_id] as Dictionary).loaded)
	demo._unhandled_input(mouse_button(MOUSE_BUTTON_RIGHT, true))
	check(demo.firearm_aiming, "holding RMB aims the sandbox firearm")
	check(int((demo.arsenal.ammo[demo.arsenal.current_id] as Dictionary).loaded) == rounds_before, "entering aim does not fire or spend a round")
	var forward := Vector3.FORWARD
	var hip: Vector3 = demo.arsenal.shot_directions(forward, Vector3.UP, 1.0)[0]
	var aimed: Vector3 = demo.arsenal.shot_directions(forward, Vector3.UP, 0.38)[0]
	check(aimed.angle_to(forward) < hip.angle_to(forward), "sandbox aim tightens the shared projectile cone")
	demo._physics_process(0.1)
	check(demo.camera.fov < 78.0 and demo.camera.fov > 55.0, "aim eases the same lens toward the sight")
	demo._unhandled_input(mouse_button(MOUSE_BUTTON_RIGHT, false))
	check(not demo.firearm_aiming, "releasing RMB lowers the firearm")

	print("AG5.32 - directional Space is a paid grounded dodge")
	demo.stamina = 100.0
	demo.dodge_cooldown = 0.0
	demo.vertical_velocity = 0.0
	var eye_before: Vector3 = demo.eye
	check(demo._begin_dodge(Vector3.RIGHT), "a grounded directional dodge is accepted")
	check(is_equal_approx(demo.stamina, 75.0) and demo.dodge_remaining > 0.0, "one dodge spends the same 25 stamina and owns a timed window")
	demo._physics_process(0.05)
	check(demo.eye.x > eye_before.x + 0.5, "the dodge physically carries the sandbox player")
	check(not demo._begin_dodge(Vector3.RIGHT), "the active dodge/cooldown refuses overlap")
	demo.dodge_remaining = 0.0
	demo.dodge_cooldown = 0.0
	demo.vertical_velocity = 1.0
	check(not demo._begin_dodge(Vector3.RIGHT), "an airborne body cannot spend a grounded dodge")
	demo.vertical_velocity = 0.0
	demo.jump_queued = true
	demo._physics_process(0.01)
	check(demo.vertical_velocity > 0.0, "still Space remains a real jump rather than becoming dodge-in-place")

	print("GORE_SANDBOX_COMBAT_PARITY_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
