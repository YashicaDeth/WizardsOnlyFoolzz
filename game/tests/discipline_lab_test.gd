extends Node

var failures: Array[String] = []
var lab: Node3D


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	lab = load("res://lab/mechanics_lab.tscn").instantiate()
	add_child(lab)
	await _frames(5)
	var station = lab.disciplines
	check(station.active == "off", "the backlog disciplines default OFF in the lab")

	station.activate("duelist")
	check(CombatInputLayer.verb(CombatInputLayer.discipline("duelist"), CombatInputLayer.L2, "melee") == "duelist_parry", "Duelist owns a distinct shoulder-button layer")
	check(PadBridge.combat_layer_id == "duelist", "the station installs the Duelist layer on the shared pad bridge")
	lab.player.global_position = lab.sparring.holder.global_position + Vector3(0, 0, 2.0)
	lab.yaw = 0.0
	await _frames(3)
	check(lab.toggle_lock() == lab.sparring.rig, "Duelist can lock onto the fighting partner")
	lab.player.global_position.y = 1.0
	await _frames(4)
	check(lab.mover.start_roll(lab.player, Vector2(1, 0), lab.yaw, lab.melee), "Duelist starts the job3 Souls roll")
	lab.mover.roll.tick(SoulsRoll.I_FRAME_START + 0.01)
	check(lab.mover.invulnerable(), "the roll carries its real i-frame window")
	_pad_trigger(JOY_AXIS_TRIGGER_LEFT, true)
	check(str(lab.melee.receive_blow(18.0).result) == "parried", "L2 Duelist input reaches the real parry window")
	_pad_trigger(JOY_AXIS_TRIGGER_LEFT, false)
	station.open_riposte(lab.sparring.rig)
	var riposte: Dictionary = station.modify_melee({"damage": 20.0, "impulse": 8.0}, lab.sparring.rig)
	check(bool(riposte.get("riposte", false)) and is_equal_approx(float(riposte.damage), 40.0), "a parry opens one doubled riposte")

	lab.arsenal.select_weapon("sidearm")
	station.activate("shade")
	check(CombatInputLayer.verb(CombatInputLayer.discipline("shade"), CombatInputLayer.R2, "melee") == "shade_throw", "Shade owns a distinct shoulder-button layer")
	check(PadBridge.combat_layer_id == "shade", "the station swaps the shared pad bridge to Shade")
	check(PadBridge.combat_context == "melee", "the discipline layer owns its verbs even if a firearm was selected")
	var target: BaselineHuman = station.target
	var front := target.global_position - target.global_basis.z * 1.2
	lab.player.global_position = front
	_pad_button(JOY_BUTTON_RIGHT_SHOULDER, true)
	_pad_button(JOY_BUTTON_RIGHT_SHOULDER, false)
	check(station.takedowns == 0 and station.refused_takedowns == 1, "R1 Shade takedown is refused from the front")
	var behind := target.global_position + target.global_basis.z * 1.2
	lab.player.global_position = behind
	_pad_button(JOY_BUTTON_RIGHT_SHOULDER, true)
	_pad_button(JOY_BUTTON_RIGHT_SHOULDER, false)
	check(station.takedowns == 1, "R1 Shade takedown works only from behind")
	_pad_button(JOY_BUTTON_LEFT_SHOULDER, true)
	_pad_button(JOY_BUTTON_LEFT_SHOULDER, false)
	check(station.darkness_left > 0.0 and station.booth_light.light_energy < 0.1, "L1 Shade darkness blacks out the booth")
	_pad_trigger(JOY_AXIS_TRIGGER_LEFT, true)
	check(lab.mover.crouched, "L2 Shade stalk holds the real crouch state")
	_pad_trigger(JOY_AXIS_TRIGGER_LEFT, false)
	check(not lab.mover.crouched, "releasing L2 leaves Shade stalk")
	station._spawn_target()
	lab.camera.global_position = station.to_global(Vector3(0, 1.2, 0.0))
	lab.camera.look_at(station.target.global_position + Vector3.UP)
	_pad_trigger(JOY_AXIS_TRIGGER_RIGHT, true)
	_pad_trigger(JOY_AXIS_TRIGGER_RIGHT, false)
	var thrown := lab.get_node_or_null("ShadeThrowable0") as ShadeThrowable
	check(thrown != null and thrown.velocity.length() > 10.0 and station.throws == 1, "R2 Shade throw launches a physical projectile")
	await _frames(30)
	check(station.throwable_hits == 1, "the throwable crosses the booth and physically hits its target")
	await _frames(2) # Let the impacted projectile's queued free complete.

	print("DISCIPLINE_LAB_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().physics_frame


func _pad_button(index: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = pressed
	PadBridge._input(event)


func _pad_trigger(axis: JoyAxis, pressed: bool) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = 1.0 if pressed else 0.0
	PadBridge._input(event)
