extends Node

## Fix-58 in the Hunt: a downed body, E (or X on the pad) opens the window,
## EXECUTE runs the finisher beat with the held v0.1 weapon, and it always
## ends with the body dead, the record written once, the kill cam played out
## and the controls back. Also: E beside a downed body near the bedroll opens
## the window instead of sleeping seven hours.

var failures: Array[String] = []
var hunt: Node


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	var waited := 0
	while hunt.kill_cam == null and waited < 600:
		await get_tree().process_frame
		waited += 1
	hunt.set_physics_process(true)
	await get_tree().physics_frame
	for existing: Dictionary in hunt.encounter_actors:
		(existing.node as Node3D).position = Vector3(-220, 1, -170)
	await _bedroll()
	await _weapon("cleaver", false, Vector3(65, 1, 115))
	await _weapon("staff", false, Vector3(70, 1, 115))
	await _weapon("sidearm", false, Vector3(75, 1, 115))
	await _weapon("cleaver", true, Vector3(80, 1, 115))
	print("HUNT_EXECUTION_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _downed_at(id: String, at: Vector3) -> Dictionary:
	hunt._spawn_encounter_actor({"instance_id": id, "kind": "hostile", "display_name": "Probe %s" % id, "role": "TEST", "summary": "On the floor."}, at)
	var actor: Dictionary = hunt.encounter_actors.back()
	actor.rig.hit("left_leg", 30.0, 4.0, "cut")
	actor.anatomy.go_down()
	await _frames(4)
	var body: Vector3 = actor.node.global_position
	hunt.player_body.global_position = body + Vector3(0, 0, 1.6)
	hunt.player_body.velocity = Vector3.ZERO
	hunt.player = hunt.player_body.global_position + Vector3.UP * 0.6
	await _frames(2)
	return actor


func _bedroll() -> void:
	if hunt.sleep_site == null or not is_instance_valid(hunt.sleep_site):
		check(false, "bedroll: the Hunt has a sleep site to test against")
		return
	var site: Vector3 = hunt.sleep_site.global_position
	var actor := await _downed_at("bedroll", site + Vector3(1.2, 0, 0))
	hunt.player_body.global_position = site + Vector3(1.2, 0, 1.0)
	hunt.player = hunt.player_body.global_position + Vector3.UP * 0.6
	var minutes_before: float = WorldClock.minutes()
	hunt._interact()
	check(hunt.resolution_ui.visible and hunt.resolution_target == str(actor.subject_id), "bedroll: E beside a downed body opens the window, not the bedroll")
	check(WorldClock.minutes() - minutes_before < 30.0, "bedroll: and no hours pass (%.0f min)" % (WorldClock.minutes() - minutes_before))
	hunt.resolution_ui.cancel_menu()
	(actor.node as Node3D).position = Vector3(-220, 1, -170)
	await _frames(2)


func _weapon(id: String, pad: bool, at: Vector3) -> void:
	hunt.arsenal.acquire_melee(id)
	check(hunt.arsenal.select_weapon(id), "%s: in hand" % id)
	var tag := "%s%s" % [id, " (pad)" if pad else ""]
	var actor := await _downed_at("exec_%s_%s" % [id, "pad" if pad else "key"], at)
	var subject := str(actor.subject_id)
	var before_resolutions := _resolutions(subject)
	if pad:
		await _pad(JOY_BUTTON_X)
	else:
		await _key(KEY_E)
	check(hunt.resolution_ui.visible, "%s: USE opens the downed window" % tag)
	if pad:
		# SPARE has the focus; up to EXECUTE, A to choose.
		await _pad(JOY_BUTTON_DPAD_UP)
		await _pad(JOY_BUTTON_A)
	else:
		var key := InputEventKey.new()
		key.keycode = KEY_1
		key.pressed = true
		Input.parse_input_event(key)
		await get_tree().process_frame
		await get_tree().process_frame
	check(not hunt.resolution_ui.visible, "%s: choosing closes the window" % tag)
	check(hunt.execution.active or actor.rig.anatomy.dead, "%s: EXECUTE starts the finisher" % tag)
	check(hunt.execution.style_id == id, "%s: with the weapon in hand (%s)" % [tag, hunt.execution.style_id])
	var clock := 0.0
	while hunt.execution.active and clock < 4.0:
		await get_tree().process_frame
		clock += get_process_delta_time() / maxf(Engine.time_scale, 0.001)
	check(not hunt.execution.active and str(hunt.execution.report.get("reason", "")) == "done", "%s: the beat completes (%s, %.2fs)" % [tag, str(hunt.execution.report.get("reason", "")), clock])
	check(actor.rig.anatomy.dead, "%s: the body is dead" % tag)
	check(not hunt.encounter_actors.has(actor), "%s: and gone the one death route" % tag)
	var resolutions := _resolutions(subject)
	check(resolutions.size() == before_resolutions.size() + 1, "%s: one npc_resolution is written" % tag)
	if not resolutions.is_empty():
		var details: Dictionary = resolutions.back().get("details", {})
		check(str(details.get("outcome", "")) == "execute" and str(details.get("finisher", "")) == id, "%s: recorded as an execution by %s" % [tag, str(details.get("finisher", ""))])
	var stand: float = Vector2(hunt.player_body.global_position.x - hunt.execution.stand_at.x, hunt.player_body.global_position.z - hunt.execution.stand_at.z).length()
	check(stand < 0.4, "%s: the player stands at the finisher's spot (%.2f m off)" % [tag, stand])
	check(absf(wrapf(hunt.yaw - hunt.execution.view_yaw, -PI, PI)) < 0.5, "%s: the view is on the body" % tag)
	check(hunt.kill_cam.active, "%s: the X-ray kill cam plays the execution" % tag)
	clock = 0.0
	while hunt.kill_cam.active and clock < 5.0:
		await get_tree().process_frame
		clock += get_process_delta_time() / maxf(Engine.time_scale, 0.001)
	check(not hunt.kill_cam.active and is_equal_approx(Engine.time_scale, 1.0), "%s: the kill cam ends and time runs at 1" % tag)
	# Hunt bodies are built without ragdoll (an open call of Greg's): the
	# corpse keeps the fall pose rather than standing back up or animating.
	var lying: bool = actor.rig.ragdoll_body != null or (actor.rig.rigged != null and actor.rig.rigged.ragdolled) or actor.rig.rotation.x < -1.2
	check(lying, "%s: the corpse lies where it was finished" % tag)
	check(not hunt.resolution_ui.visible and hunt._pending_execution.is_empty(), "%s: nothing is left holding the controls" % tag)
	(actor.node as Node3D).position = Vector3(-220, 1, -170)
	await _frames(2)


func _resolutions(subject: String) -> Array:
	return WorldHistory.events.filter(func(event: Dictionary):
		return str(event.get("type", "")) == "npc_resolution" and str((event.get("details", {}) as Dictionary).get("subject_id", "")) == subject)


func _key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame
		await get_tree().process_frame


func _pad(button: JoyButton) -> void:
	for down in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = 0
		event.button_index = button
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame
		await get_tree().process_frame


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().physics_frame
