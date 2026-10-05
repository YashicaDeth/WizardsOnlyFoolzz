extends Node

## Job 9: the shared harness for the v0.1 enemy duels. It boots the real
## route (vat_chamber on the one facility map), stands the player in the
## room, and plays a CAREFUL player through the real InputMap only, fed as
## pad events: it watches each wind-up's colour, parries (L2) a parryable
## COPPER blow just before it lands, dodges (B with the stick held sideways)
## a RED one, and strikes (R1, or a short R2 heavy after two lights) only into
## an opening: a foe reeling, recovering after its blow, or venting.
## Subclasses run the duels and report `<NAME>_RESULT failures=N`.

const FIELD_MEDS := preload("res://systems/field_meds.gd")
const HIDDEN_CACHE := preload("res://systems/hidden_cache.gd")

var failures: Array[String] = []
var vat: Node3D
var enc: V01Encounters
var _parried_for := {}
var _dodged_for := {}
var _lights := 0
var _stick := Vector2.ZERO
var bot_log: Array[String] = []
## Set by each suite before `boot`.
var result_name := "V01_DUEL_TEST"
const WATCHDOG := 190.0
var last_duel: Dictionary = {}


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func boot() -> void:
	OS.set_environment("ATG_V01_NO_DEATH_BEAT", "1")
	WorldHistory.clear_history()
	BloodPool.clear()
	vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	await get_tree().process_frame
	vat.intake._finish_filing()
	await get_tree().process_frame
	vat.departure_clock = vat.DEPARTURE_SECONDS
	vat._update_departure(0.0)
	vat.clock = vat.DRAINED_AT
	vat.phase = "voiding"
	vat._update_sequence(0.05)
	while not vat.umbilicals.is_empty():
		for _tug in vat.WIRE_TUGS:
			vat._tug_wire(vat.umbilicals[0])
	vat._physics_process(vat.REVENGE_HOLD + 0.1)
	preload("res://systems/clothing.gd").wear("player", "scavenged_coat")
	for _step in 80:
		if vat.can_move:
			break
		vat._physics_process(0.1)
	enc = vat.encounters
	# A hung duel must fail, never sit: real seconds, whatever the time scale.
	get_tree().create_timer(WATCHDOG, true, false, true).timeout.connect(func() -> void:
		print("FAIL watchdog: the duel ran past %d real seconds" % int(WATCHDOG))
		print("%s_RESULT failures=%d" % [result_name, failures.size() + 1])
		get_tree().quit(1))
	# Twice real time: wind-ups and windows scale with it, so the duels read
	# the same and the suite stays inside the runner's timeout.
	Engine.time_scale = 2.0


func finish(result_name: String) -> void:
	Engine.time_scale = 1.0
	_release_all()
	print("%s_RESULT failures=%d" % [result_name, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)


# --- Placing and healing. -------------------------------------------------------

func stand(at: Vector3, look: Vector3) -> void:
	vat.player.global_position = Vector3(at.x, at.y + vat.BODY_HALF_HEIGHT + 0.02, at.z)
	vat.player.velocity = Vector3.ZERO
	face_point(look)


func face_point(point: Vector3) -> void:
	var eye: Vector3 = vat.camera.global_position
	var to := point - eye
	vat.yaw = atan2(-to.x, -to.z)
	vat.pitch = atan2(to.y, Vector2(to.x, to.z).length())


func heal() -> void:
	var anatomy: Node = vat.anatomy
	anatomy.set("bleed_rate", 0.0)
	anatomy.set("internal_bleed_rate", 0.0)
	anatomy.set("downed", false)
	anatomy.set("pain", 0.0)
	var zones: Dictionary = anatomy.get("zones")
	var full: Dictionary = anatomy.get("DEFAULT_ZONES")
	for zone_id: String in zones:
		(zones[zone_id] as Dictionary)["health"] = float((full.get(zone_id, {}) as Dictionary).get("health", 100.0))
	anatomy.set("blood_remaining", float(anatomy.get("blood_capacity")))
	enc.dead = false


func blood() -> float:
	return float(vat.anatomy.get("blood_remaining")) / maxf(float(vat.anatomy.get("blood_capacity")), 1.0)


## Only `foe` thinks for the length of a duel.
func isolate(foe: V01Foe) -> Array[V01Foe]:
	var all: Array[V01Foe] = enc.foes.duplicate()
	enc.foes.clear()
	enc.foes.append(foe)
	return all


func restore(all: Array[V01Foe]) -> void:
	enc.foes = all


# --- The pad. ------------------------------------------------------------------------

func button(index: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = pressed
	event.device = 0
	Input.parse_input_event(event)


func axis(index: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = index
	event.axis_value = value
	event.device = 0
	Input.parse_input_event(event)


func tap(index: JoyButton) -> void:
	button(index, true)
	await get_tree().physics_frame
	button(index, false)


## Square: through the chamber's own pad handler (as the route tests feed
## it), so a pickup goes through the real use path.
func square() -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_X
	event.pressed = true
	vat._unhandled_input(event)
	await get_tree().physics_frame
	event = event.duplicate()
	event.pressed = false
	vat._unhandled_input(event)


func trigger(index: JoyAxis, hold_seconds: float) -> void:
	axis(index, 1.0)
	await seconds(hold_seconds)
	axis(index, 0.0)


func stick(value: Vector2) -> void:
	if value == _stick:
		return
	_stick = value
	axis(JOY_AXIS_LEFT_X, value.x)
	axis(JOY_AXIS_LEFT_Y, value.y)


func _release_all() -> void:
	stick(Vector2.ZERO)
	axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	button(JOY_BUTTON_LEFT_SHOULDER, false)


func seconds(amount: float) -> void:
	var until := Time.get_ticks_msec() + int(amount * 1000.0 / Engine.time_scale)
	while Time.get_ticks_msec() < until:
		await get_tree().physics_frame


# --- The careful player. ---------------------------------------------------------------

## One frame of careful play against `foe`. `keep` is the distance to hold
## when not striking; `reach` is how close to step in to strike.
func careful(foe: V01Foe, reach: float, keep: float, weapon := "melee", aim_part := "") -> void:
	var to: Vector3 = foe.global_position - (vat.player as Node3D).global_position
	to.y = 0.0
	var distance: float = to.length()
	if aim_part != "":
		var target := foe.global_position + Vector3(0, 1.3, 0)
		for point: Dictionary in foe.weak_points():
			if str(point.part) == aim_part:
				target = point.at
		face_point(target)
	else:
		face_point(foe.global_position + Vector3(0, 1.3, 0))
	# The telegraph: colour and time left.
	if foe.winding != "" and not foe.move.is_empty():
		var left := foe.windup_needed - foe.windup
		var key := foe.telegraphs
		var colour: Color = foe.move.get("colour", V01Foe.COPPER)
		if colour == V01Foe.COPPER and bool(foe.move.get("parryable", false)) and left <= 0.16 and not _parried_for.has(key):
			_parried_for[key] = true
			axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
			await get_tree().physics_frame
			axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
			return
		if colour == V01Foe.COPPER and not bool(foe.move.get("parryable", false)) and left <= 0.25:
			# Blockable, not parryable (the sentinel's slam): step back out.
			stick(Vector2(0, 1))
			return
		if colour == V01Foe.RED and left <= 0.12 and not _dodged_for.has(key):
			_dodged_for[key] = true
			stick(Vector2(1.0 if key % 2 == 0 else -1.0, 0.0))
			await get_tree().physics_frame
			await tap(JOY_BUTTON_B)
			await get_tree().physics_frame
			stick(Vector2.ZERO)
			return
	var open := foe.reeling() or foe.recover_left > 0.05 or (foe is V01FreedSubject and (foe as V01FreedSubject).dazed > 0.0)
	if foe is V01Sentinel:
		var s := foe as V01Sentinel
		open = s.venting > 0.0 or s.overloaded > 0.0 or s.blinded > 0.0
	if weapon == "gun":
		stick(Vector2(0, -1) if distance > keep + 1.0 else (Vector2(0, 1) if distance < keep - 1.0 else Vector2.ZERO))
		if (open or foe.winding == "" or aim_part == "eye") and enc.gun_cooldown <= 0.0 and enc._gun_rounds() > 0:
			await trigger(JOY_AXIS_TRIGGER_RIGHT, 0.05)
		return
	if open or (foe.winding == "" and foe.attack_clock < 0.3 and foe is V01FreedSubject):
		if distance > reach:
			stick(Vector2(0, -1))
			return
		stick(Vector2.ZERO)
		if enc.swing.is_empty():
			if _lights >= 2 or (enc.last_result == "blocked"):
				_lights = 0
				await trigger(JOY_AXIS_TRIGGER_RIGHT, 0.12)
			else:
				_lights += 1
				await tap(JOY_BUTTON_RIGHT_SHOULDER)
		return
	# Not open: hold just outside its reach and let it commit.
	if distance > keep + 0.6:
		stick(Vector2(0, -1))
	elif distance < keep - 0.6:
		stick(Vector2(0, 1))
	else:
		stick(Vector2.ZERO)


## Plays careful until `foe` dies or `limit` seconds pass. True on a win.
func duel(foe: V01Foe, reach: float, keep: float, limit: float, weapon := "melee", aim_part := "") -> bool:
	var started := Time.get_ticks_msec()
	var blood_before := blood()
	var until := Time.get_ticks_msec() + int(limit * 1000.0 / Engine.time_scale)
	while foe.is_alive() and not enc.dead and Time.get_ticks_msec() < until:
		await careful(foe, reach, keep, weapon, aim_part)
		await get_tree().physics_frame
	stick(Vector2.ZERO)
	last_duel = {"seconds": (Time.get_ticks_msec() - started) * 0.001 * Engine.time_scale, "blood_lost": blood_before - blood(), "telegraphs": foe.telegraphs, "landed": foe.landed_on_player}
	print("DUEL %s: %.1f s, blood lost %.0f%%, telegraphs %d, its blows that reached you %d" % [foe.foe_id, float(last_duel.seconds), float(last_duel.blood_lost) * 100.0, foe.telegraphs, foe.landed_on_player])
	return not foe.is_alive() and not enc.dead
