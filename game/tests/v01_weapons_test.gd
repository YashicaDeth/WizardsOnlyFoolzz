extends Node

## Job 3: each v0.1 weapon hits a dummy in the mechanics lab through the real
## InputMap, fed as pad events (R1, R2 held, L2, Circle, R3, d-pad right).
## HOTLINE CLEAVER: light chain with the press buffered mid-swing, hitstop,
## heat that brightens the edge and scorches the wound. PRODSTAFF: reach, and
## a charged R2 that shocks and staggers. MERCY NINE: L2 aims down the
## barrel, R2 fires, the round lands, the casing stays. Then the roll and the
## lock-on.

var failures: Array[String] = []
var lab: Node3D
var swings := 0
var staggers: Array = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	BloodPool.clear()
	lab = load("res://lab/mechanics_lab.tscn").instantiate()
	add_child(lab)
	await _frames(3)
	lab.melee.swing_started.connect(func(_id: String) -> void: swings += 1)
	lab.melee.staggered.connect(func(rig: Node3D, report: Dictionary) -> void: staggers.append(report))
	check(lab.WEAPONS == ["cleaver", "staff", "sidearm"], "the lab carries the three v0.1 weapons")
	check(str(lab.arsenal.current().label) == "HOTLINE CLEAVER", "it starts on the HOTLINE CLEAVER")
	check(lab.held_mount != null and lab.held_mount.find_child("heat_edge", true, false) != null, "the cleaver is held in view with its heated edge")

	await _cleaver()
	await _staff()
	await _pistol()
	await _roll_and_lock()
	await _sparring()

	Engine.time_scale = 1.0
	print("V01_WEAPONS_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _cleaver() -> void:
	var rig: BaselineHuman = lab.bodies.rigs()[0]
	await _face(rig, 1.3)
	var before := _health(rig)
	var contacts_before: int = lab.melee.contacts
	await _button(JOY_BUTTON_RIGHT_SHOULDER)
	# A second R1 while the first is still swinging: the buffer keeps it.
	await _seconds(0.12)
	await _button(JOY_BUTTON_RIGHT_SHOULDER)
	await _hitstop_seen()
	await _seconds(1.2)
	check(lab.melee.contacts > contacts_before, "R1 swings the cleaver into the dummy (%d contacts)" % (lab.melee.contacts - contacts_before))
	check(_health(rig) < before, "and wounds it (%.0f -> %.0f)" % [before, _health(rig)])
	check(swings >= 2, "the R1 pressed mid-swing was buffered into a second swing (%d)" % swings)
	check(lab.melee.heat > 0.0, "hits heat the edge (%.2f)" % lab.melee.heat)
	var edge := lab.held_mount.find_child("heat_edge", true, false) as MeshInstance3D
	check((edge.material_override as StandardMaterial3D).emission_energy_multiplier > float(MeleeDriver.FEEL.cleaver.glow_cold), "and the edge glows brighter than cold")
	check(_burns(rig) > 0, "a hot edge leaves a burn mark on the wound (%d)" % _burns(rig))
	check(is_equal_approx(Engine.time_scale, 1.0), "time comes back after the hitstop")


func _staff() -> void:
	await _button(JOY_BUTTON_DPAD_RIGHT)
	await _frames(2)
	check(str(lab.arsenal.current_id) == "staff", "d-pad right steps to the PRODSTAFF")
	check(lab.held_mount.find_child("shock_tip", true, false) != null, "held in view with its shock tip")
	var rig: BaselineHuman = lab.bodies.rigs()[2]
	# Out of the cleaver's reach, inside the staff's.
	await _face(rig, 2.7)
	var before := _health(rig)
	var contacts_before: int = lab.melee.contacts
	await _button(JOY_BUTTON_RIGHT_SHOULDER)
	await _seconds(0.9)
	check(lab.melee.contacts > contacts_before, "the staff's thrust reaches a dummy 2.7 m off")
	check(_health(rig) < before, "and hurts it")
	staggers.clear()
	await _seconds(0.5)
	await _trigger(JOY_AXIS_TRIGGER_RIGHT, 0.85)
	await _seconds(1.4)
	check(bool(lab.melee.last_packet.get("shock", false)), "R2 held and released is the charged shock (%s)" % str(lab.melee.last_packet.get("attack", "")))
	check(staggers.any(func(report: Dictionary) -> bool: return bool(report.get("shock", false))), "and the shock staggers the dummy")


func _pistol() -> void:
	await _button(JOY_BUTTON_DPAD_RIGHT)
	await _frames(2)
	check(str(lab.arsenal.current().label) == "MERCY NINE", "d-pad right steps to the MERCY NINE")
	var rig: BaselineHuman = lab.bodies.rigs()[3]
	await _face(rig, 4.0)
	var aim := InputEventJoypadMotion.new()
	aim.axis = JOY_AXIS_TRIGGER_LEFT
	aim.axis_value = 1.0
	Input.parse_input_event(aim)
	await _seconds(0.5)
	check(lab.aiming and lab.camera.fov < 70.0, "L2 aims down the barrel (fov %.0f)" % lab.camera.fov)
	check(lab.ads.has_line, "on the line through both sights")
	var before := _health(rig)
	var casings_before: int = lab.ballistics.casings.size()
	await _trigger(JOY_AXIS_TRIGGER_RIGHT, 0.05)
	await _seconds(0.6)
	check(_health(rig) < before, "R2 fires a round into the dummy (%s)" % str(lab.last_hit))
	check(lab.ballistics.casings.size() > casings_before, "and the casing stays")
	aim.axis_value = 0.0
	Input.parse_input_event(aim)
	await _seconds(0.3)
	check(not lab.aiming, "letting go of L2 lowers the gun")


func _roll_and_lock() -> void:
	lab.go_to(1)
	await _frames(3)
	var stamina: float = lab.melee.stamina
	await _button(JOY_BUTTON_B)
	await _frames(2)
	check(lab.mover.roll.is_rolling(), "a Circle tap rolls")
	check(lab.melee.stamina < stamina, "and costs stamina")
	var saw_iframes := false
	for _frame in 30:
		await get_tree().physics_frame
		saw_iframes = saw_iframes or lab.mover.invulnerable()
	check(saw_iframes, "with i-frames in it")
	await _seconds(0.6)
	await _button(JOY_BUTTON_RIGHT_STICK)
	check(lab.lock_target != null, "R3 locks on to a dummy in front")
	await _button(JOY_BUTTON_RIGHT_STICK)
	check(lab.lock_target == null, "and R3 again lets go")


## The fighting partner: its telegraphed swing is parried on L2, soaked on
## L1, and a cleaver blow while it winds up interrupts it.
func _sparring() -> void:
	var partner = lab.sparring
	check(partner != null and not partner.is_dead(), "a sparring partner stands in the lab")
	# Lab-47 put its four physical destruction tools after the sidearm in the
	# same NEXT cycle. Keep driving the real pad action until weapons wrap.
	for _step in lab.DESTRUCTION.TOOLS.size() + 1:
		await _button(JOY_BUTTON_DPAD_RIGHT)
		await _frames(2)
	check(str(lab.arsenal.current_id) == "cleaver", "back round to the cleaver")
	await _face(partner.rig, 2.0)
	# Parry: L2 late in its windup.
	await _until(func() -> bool: return partner.state == "windup" and partner.clock >= WINDUP_PARRY_AT, 4.0)
	var parried_before: int = partner.outcomes.size()
	var parry := InputEventJoypadMotion.new()
	parry.axis = JOY_AXIS_TRIGGER_LEFT
	parry.axis_value = 1.0
	Input.parse_input_event(parry)
	await _until(func() -> bool: return partner.outcomes.size() > parried_before, 2.0)
	parry.axis_value = 0.0
	Input.parse_input_event(parry)
	check(partner.outcomes.size() > parried_before and partner.outcomes[-1] == "parried", "L2 in time parries its swing (%s)" % str(partner.outcomes))
	check(partner.state == "stunned", "and a parried partner is stunned")
	# Block: hold L1 through the next swing.
	await _face(partner.rig, 2.0)
	var guard := InputEventJoypadButton.new()
	guard.button_index = JOY_BUTTON_LEFT_SHOULDER
	guard.pressed = true
	Input.parse_input_event(guard)
	var health: float = lab.player_health
	var blocked_before: int = partner.outcomes.size()
	await _until(func() -> bool: return partner.outcomes.size() > blocked_before, 6.0)
	guard.pressed = false
	Input.parse_input_event(guard)
	check(partner.outcomes.size() > blocked_before and partner.outcomes[-1] == "blocked", "L1 held blocks it (%s)" % str(partner.outcomes))
	check(lab.player_health > health - SparringDamage.FULL, "and the block soaks most of it")
	# Interrupt: a heavy into its windup.
	await _face(partner.rig, 1.4)
	staggers.clear()
	await _until(func() -> bool: return partner.state == "windup", 6.0)
	await _trigger(JOY_AXIS_TRIGGER_RIGHT, 0.05)
	await _until(func() -> bool: return partner.state == "stunned", 1.5)
	check(partner.state == "stunned", "a cleaver heavy into its windup staggers it out of the swing")


# --- helpers -----------------------------------------------------------------

const WINDUP_PARRY_AT := 0.52


class SparringDamage:
	const FULL := 18.0


func _until(condition: Callable, limit: float) -> void:
	var waited := 0.0
	while waited < limit and not condition.call():
		await get_tree().physics_frame
		waited += 1.0 / float(Engine.physics_ticks_per_second)


func _face(rig: BaselineHuman, distance: float) -> void:
	var at := rig.global_position
	lab.player.global_position = at + Vector3(0, 1.0, distance)
	lab.player.velocity = Vector3.ZERO
	await _frames(2)
	var eye: Vector3 = lab.camera.global_position
	var to := at + Vector3(0, 1.2, 0) - eye
	lab.yaw = atan2(-to.x, -to.z)
	lab.pitch = atan2(to.y, Vector2(to.x, to.z).length())
	await _frames(2)


func _health(rig: BaselineHuman) -> float:
	var total := 0.0
	for zone in ["head", "torso", "abdomen", "left_arm", "right_arm"]:
		total += rig.zone_health(zone)
	return total


func _burns(rig: BaselineHuman) -> int:
	return rig.find_children("BurnMark*", "Decal", true, false).size()


func _hitstop_seen() -> void:
	for _frame in 120:
		await get_tree().process_frame
		if lab.melee.hitstop_active():
			check(is_equal_approx(Engine.time_scale, MeleeDriver.HITSTOP_TIME_SCALE), "a contact holds the world in hitstop")
			return
	check(false, "a contact holds the world in hitstop")


func _button(button: JoyButton) -> void:
	var down := InputEventJoypadButton.new()
	down.button_index = button
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	await get_tree().process_frame
	await _frames(1)
	var up := InputEventJoypadButton.new()
	up.button_index = button
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame
	await get_tree().process_frame


func _trigger(axis: JoyAxis, hold: float) -> void:
	var down := InputEventJoypadMotion.new()
	down.axis = axis
	down.axis_value = 1.0
	Input.parse_input_event(down)
	await _seconds(hold)
	var up := InputEventJoypadMotion.new()
	up.axis = axis
	up.axis_value = 0.0
	Input.parse_input_event(up)
	await get_tree().process_frame
	await get_tree().process_frame


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().physics_frame


## Real seconds: a hitstop slows the engine clock on purpose.
func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
