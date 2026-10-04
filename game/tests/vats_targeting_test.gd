extends Node

## Aimed X-ray (Greg, 2026-10-04): slowed time, one body's parts as targets,
## armour on some of them, and a stat effect when one breaks. The first half
## proves the rules on a bare rig; the second drives the real Hunt the way a
## pad does: L2+R2 held, a stick flick, R2 again.

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


func _rig(id: String) -> BaselineHuman:
	var rig := BaselineHuman.new()
	add_child(rig)
	rig.build(id, {"cybernetics": {
		"torso": {"id": "ceramic sternum"},
		"head": {"id": "rangefinder eye"},
		"right_arm": {"id": "salvaged torque arm"},
		"left_arm": {"id": "dose counter"},
	}})
	return rig


func _find(parts: Array, id: String) -> Dictionary:
	for part in parts:
		if str((part as Dictionary).id) == id:
			return part
	return {}


func _shots_to_break(rig: BaselineHuman, id: String, damage: float) -> int:
	for shot in 12:
		var part := _find(VatsTargeting.parts_of(rig), id)
		if part.is_empty():
			return shot
		var result := VatsTargeting.strike(rig, part, damage, 4.0, Vector3.FORWARD)
		if bool(result.broken):
			return shot + 1
	return 99


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	_rules()
	await _in_the_hunt()
	Engine.time_scale = 1.0
	print("VATS_TARGETING_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _rules() -> void:
	print("-- the targets are the body's own parts, head to toe --")
	var rig := _rig("vats_rules")
	var parts := VatsTargeting.parts_of(rig)
	var kinds := {}
	for part in parts:
		kinds[str(part.kind)] = int(kinds.get(str(part.kind), 0)) + 1
	check(int(kinds.get("implant", 0)) == 4, "every installed piece of hardware is a target (%d)" % int(kinds.get("implant", 0)))
	check(int(kinds.get("organ", 0)) == BaselineHuman.ORGAN_LAYOUT.size(), "so is every intact organ (%d)" % int(kinds.get("organ", 0)))
	check(int(kinds.get("limb", 0)) == 4 and int(kinds.get("sense", 0)) == 1, "and the four limbs and the eyes")
	check(str(parts[0].zone) == "head" and str(parts[parts.size() - 1].zone).ends_with("leg"), "ordered head to toe (%s .. %s)" % [str(parts[0].id), str(parts[parts.size() - 1].id)])

	print("-- armour is the armour a round actually meets --")
	var sternum := _find(parts, "implant:torso")
	var heart := _find(parts, "heart")
	var thigh := _find(parts, "left_leg")
	check(VatsTargeting.is_plated(sternum), "the ceramic sternum reads as plate (%.2f)" % float(sternum.armour))
	check(is_equal_approx(float(heart.armour), rig.anatomy.zone_armor("torso")) and float(heart.armour) > 0.0,
		"the heart sits behind the torso's hardware (%.2f)" % float(heart.armour))
	check(float(thigh.armour) == 0.0 and not VatsTargeting.is_plated(thigh), "a bare thigh is bare")
	var counter := _find(parts, "implant:left_arm")
	check(not VatsTargeting.is_plated(counter), "the dose counter is not plated (%.2f)" % float(counter.armour))
	var plated_shots := _shots_to_break(rig, "implant:torso", 24.0)
	var bare_shots := _shots_to_break(rig, "implant:left_arm", 24.0)
	check(plated_shots > bare_shots, "plate takes more rounds to blow apart than bare hardware (%d vs %d)" % [plated_shots, bare_shots])
	check(rig.anatomy.implant_condition("torso") <= 0.0 and _find(VatsTargeting.parts_of(rig), "implant:torso").is_empty(),
		"blown-apart hardware is spent and leaves the target list")
	check(float(_find(VatsTargeting.parts_of(rig), "heart").armour) < float(heart.armour),
		"and what was behind it is now less covered")

	print("-- cycling --")
	var session := VatsTargeting.new()
	check(session.begin(rig) and str(session.current().kind) == "implant", "it opens on hardware (%s)" % str(session.current().id))
	var first := session.index
	check(session.read_stick(Vector2(0.9, 0.0)) == 1 and session.index == wrapi(first + 1, 0, session.parts.size()), "a right flick steps to the next part")
	check(session.read_stick(Vector2(0.95, 0.0)) == 0, "holding the stick over does not run through the body")
	session.read_stick(Vector2.ZERO)
	check(session.read_stick(Vector2(0.0, -0.9)) == -1 and session.index == first, "back to rest, an up flick steps back")
	session.index = 0
	session.step(-1)
	check(session.index == session.parts.size() - 1, "it wraps from the head to the feet")
	check(session.tick(1.0) and not session.tick(VatsTargeting.FOCUS_SECONDS), "held time runs out on its own")
	session.end()
	check(not session.is_active(), "and ends")

	print("-- breaking a part does what it says --")
	var fresh := _rig("vats_effects")
	var actor := {"subject_id": "vats_effects", "speed": 3.7, "rig": fresh}
	var arm := _find(VatsTargeting.parts_of(fresh), "implant:right_arm")
	check(str(arm.effect) == "disarm", "hardware in the arm disarms")
	var arm_result := {}
	for shot in 8:
		arm_result = VatsTargeting.strike(fresh, arm, 24.0, 4.0, Vector3.FORWARD)
		if bool(arm_result.broken):
			break
	check(bool(arm_result.broken) and str(arm_result.effect) == "disarm", "shot out, it breaks with its effect")
	check(VatsTargeting.apply_effect(actor, "disarm") and bool(actor.disarmed) and bool(actor.vats_disarmed), "and the fighter is disarmed for good")
	var eyes := _find(VatsTargeting.parts_of(fresh), "eyes")
	var brain_before := float(fresh.anatomy.organs.brain.health)
	var eye_result := VatsTargeting.strike(fresh, eyes, 24.0, 4.0, Vector3.FORWARD)
	check(bool(eye_result.broken) and str(eye_result.effect) == "blind", "a round through the eyes blinds")
	check(is_equal_approx(float(fresh.anatomy.organs.brain.health), brain_before), "without being sent on into the brain")
	check(_find(VatsTargeting.parts_of(fresh), "eyes").is_empty(), "and the eyes are gone from the list")
	VatsTargeting.apply_effect(actor, "blind")
	check(is_equal_approx(VatsTargeting.sight(actor), VatsTargeting.BLIND_SIGHT), "a blind fighter sees a fifth as well")
	var lung := _find(VatsTargeting.parts_of(fresh), "left_lung")
	var lung_result := VatsTargeting.strike(fresh, lung, 24.0, 4.0, Vector3.FORWARD)
	check(not bool(lung_result.broken), "behind the sternum's plate one sidearm round does not burst a lung")
	lung_result = VatsTargeting.strike(fresh, lung, 24.0, 4.0, Vector3.FORWARD)
	check(bool(lung_result.broken) and not fresh.anatomy.organ_ok("left_lung"), "the second aimed round does")
	var bare := _rig("vats_bare")
	bare.anatomy.damage_implant("torso", 9999.0)
	var bare_lung := VatsTargeting.strike(bare, _find(VatsTargeting.parts_of(bare), "left_lung"), 24.0, 4.0, Vector3.FORWARD)
	check(bool(bare_lung.broken), "with the plate shot off, one round is enough")
	check(VatsTargeting.apply_effect(actor, "slow") and is_equal_approx(float(actor.speed), 3.7 * VatsTargeting.SLOWED_PACE), "a burst lung slows them")
	check(not VatsTargeting.apply_effect(actor, "slow") and is_equal_approx(float(actor.speed), 3.7 * VatsTargeting.SLOWED_PACE), "and a second slow does not stack")
	var leg := _find(VatsTargeting.parts_of(fresh), "left_leg")
	var leg_result := {}
	for shot in 6:
		leg_result = VatsTargeting.strike(fresh, leg, 24.0, 4.0, Vector3.FORWARD)
		if bool(leg_result.broken):
			break
	check(bool(leg_result.broken) and str(leg_result.effect) == "slow", "a crippled leg slows (%s)" % str(leg_result.get("effect", "")))
	check(VatsTargeting.strike(fresh, leg, 24.0, 4.0, Vector3.FORWARD).broken == false, "a leg already crippled does not break twice")


func _in_the_hunt() -> void:
	print("-- in the Hunt: L2+R2 held opens it, slowed --")
	var hunt := HUNT.instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	# Open air above the yard: a plumbing test, not a cover test, so no wall
	# can stand between the barrel and the part.
	hunt.player_body.position = Vector3(0, 60.0, 0)
	hunt.player = hunt.player_body.position + Vector3.UP * 0.6
	hunt.yaw = 0.0
	hunt.pitch = 0.0
	hunt._equip_weapon(2)
	var actor: Dictionary = hunt._spawn_encounter_actor({
		"instance_id": "vats_subject", "kind": "hostile", "display_name": "VATS PROBE",
		"implant": {"zone": "right_arm", "name": "salvaged torque arm", "armor": 0.22},
	}, hunt.player + Vector3(0, -1.5, 4.0))
	(actor.node as Node3D).position = hunt.player + Vector3(0, -1.5, 4.0)
	actor.node.set_physics_process(false)
	for frame in 3:
		hunt._update_camera()
		await get_tree().physics_frame
	var rounds_before := int(hunt.arsenal.ammo.sidearm.loaded)

	# A quick aim then a shot is still a shot.
	hunt._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT, true))
	hunt._update_vats(0.4)
	hunt._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, true))
	check(not hunt._vats_chord_pending, "L2 held well before R2 is ordinary aimed fire")
	hunt._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, false))
	hunt._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT, false))
	check(not hunt.vats.is_active() and int(hunt.arsenal.ammo.sidearm.loaded) == rounds_before - 1, "and it fired one round")
	hunt.attack_cooldown = 0.0
	hunt.arsenal.cooldown = 0.0

	# Both together, and held.
	rounds_before = int(hunt.arsenal.ammo.sidearm.loaded)
	hunt._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT, true))
	hunt._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, true))
	check(hunt._vats_chord_pending and int(hunt.arsenal.ammo.sidearm.loaded) == rounds_before, "R2 inside the window holds its round back")
	hunt._update_vats(VatsTargeting.CHORD_WINDOW + 0.01)
	check(hunt.vats.is_active() and str(hunt.vats.subject_id) == str(actor.subject_id), "held together, aimed X-ray opens on the body in the sights")
	check(is_equal_approx(Engine.time_scale, VatsTargeting.TIME_SCALE), "and the world slows (%.2f)" % Engine.time_scale)
	check((actor.rig as BaselineHuman)._xray, "and the body is seen through")
	hunt._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, false))
	check(int(hunt.arsenal.ammo.sidearm.loaded) == rounds_before, "letting go of the chord's R2 does not fire")
	hunt._update_vats(0.05)
	check(not (hunt.vats_overlay.marks as Array).is_empty() and hunt.vats_overlay.selected >= 0, "the overlay marks the parts (%d) and the chosen one" % (hunt.vats_overlay.marks as Array).size())

	print("-- the stick picks, R2 fires at the part --")
	var target_index := -1
	for position in hunt.vats.parts.size():
		if str(hunt.vats.parts[position].id) == "implant:right_arm":
			target_index = position
	check(target_index >= 0, "the arm hardware is a target")
	hunt.vats.index = wrapi(target_index - 1, 0, hunt.vats.parts.size())
	hunt.vats.read_stick(Vector2.ZERO)
	hunt.vats.read_stick(Vector2(0.9, 0.0))
	check(str(hunt.vats.current().id) == "implant:right_arm", "one flick lands on it")
	var condition_before: float = actor.anatomy.implant_condition("right_arm")
	var broke := false
	for shot in 6:
		hunt.attack_cooldown = 0.0
		hunt.arsenal.cooldown = 0.0
		hunt.arsenal.jammed.clear()
		if not hunt.vats.is_active():
			hunt._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT, false))
			hunt._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT, true))
			hunt._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, true))
			hunt._update_vats(VatsTargeting.CHORD_WINDOW + 0.01)
			hunt._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, false))
			for position in hunt.vats.parts.size():
				if str(hunt.vats.parts[position].id) == "implant:right_arm":
					hunt.vats.index = position
		var fired_before: int = hunt._shot_counter
		hunt._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, true))
		hunt._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, false))
		check(hunt._shot_counter == fired_before + 1, "shot %d leaves the barrel" % (shot + 1))
		for frame in 40:
			await get_tree().physics_frame
			if actor.anatomy.implant_condition("right_arm") < condition_before:
				break
		var after: float = actor.anatomy.implant_condition("right_arm")
		check(after < condition_before, "shot %d reaches the arm hardware (%.2f -> %.2f)" % [shot + 1, condition_before, after])
		condition_before = after
		hunt._update_vats(VatsTargeting.FOLLOW_SECONDS + 0.01)
		if bool(actor.get("vats_disarmed", false)):
			broke = true
			break
	check(broke and bool(actor.get("disarmed", false)), "blown apart, it disarms the fighter it was in")
	check(WorldHistory.event_count("vats_part_broken") >= 1, "and the break is on the record")
	check(not hunt.vats.is_active() and is_equal_approx(Engine.time_scale, 1.0), "after the round lands time comes back (%.2f)" % Engine.time_scale)
	check(not (actor.rig as BaselineHuman)._xray, "and the body is solid again")
	hunt.queue_free()
