extends Node

## The overworld events inside the real Hunt: the director is there and
## silent under ATG_TEST_MODE, a monk fight hands its boss to the Hunt's own
## encounter system (dressed as the eldest), and the crazed driver finds ground
## to drive on. With `-- --out=DIR` it also renders the monks' vision beat and
## the driver's charge in the Hunt's world.

const Generator := preload("res://systems/event_generator.gd")

var failures: Array[String] = []
var out_dir := ""


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	WorldHistory.world_minute = 11.0 * 60.0
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	for i in 20:
		await get_tree().physics_frame
	var director: OverworldEventDirector = hunt.overworld_events
	check(director != null, "the Hunt owns an overworld event director")
	if director == null:
		_finish()
		return
	check(not director.autoplay or OS.get_environment("ATG_OVERWORLD_EVENTS") == "1", "it does not fire on its own in a test")
	for i in 30:
		await get_tree().physics_frame
	check(director.state == "idle", "nothing has fired after the Hunt ran")

	# The monks' vision, in the Hunt's world.
	var at: Vector3 = hunt.player
	check(director.play_signature("splinter_monks", at), "the monks play in the Hunt")
	var guard := 0
	while director.state == "cutscene" and not (director.beat_index == 3 and director.beat_time > 1.4) and guard < 900:
		await get_tree().physics_frame
		guard += 1
	await _shoot("hunt_monks_vision")
	director.skip_cutscene()
	check(director.state == "trade_offer", "they end in a trade in the Hunt too")
	director.refuse_trade()
	var refused: Dictionary = _last("overworld_event_resolved").get("details", {})
	check(str(refused.get("outcome", "")) == "trade" and not bool(refused.get("accepted", true)), "a refused trade is recorded")
	director.clear_stage()
	director.state = "idle"

	# A monk fight goes to the Hunt's encounter system.
	var fight: Dictionary = {}
	for event in Generator.events_matching({"actor": "splinter_monks", "outcome": "fight"}):
		fight = event
		break
	check(director.play(fight, hunt.player), "a monk fight plays in the Hunt")
	director.skip_cutscene()
	var handoff: Dictionary = _last("overworld_event_handoff").get("details", {})
	check(bool(handoff.get("in_hunt", false)), "the boss is spawned through the Hunt")
	var found := false
	for actor in hunt.encounter_actors:
		if str(actor.get("subject_id", "")) == director.boss_subject:
			found = true
	check(found, "the boss is one of the Hunt's encounter actors (%s)" % director.boss_subject)
	check(director.boss_rig != null and director.boss_rig.parts.head.get_node_or_null("Koukoulion") != null, "the Hunt's boss body is dressed as the eldest")
	director.clear_stage()
	director.state = "idle"

	# The driver needs ground; the Hunt has it.
	var before: Vector3 = hunt.player
	check(director.play_signature("crazed_driver", before), "the crazed driver plays in the Hunt")
	check(director.vehicle != null, "the Hunt has ground for the car (%s)" % str(director.event.get("id", "")))
	var t := 0.0
	while director.state == "cutscene" and t < 3.2:
		await get_tree().physics_frame
		t += 1.0 / 60.0
	await _shoot("hunt_driver_charge")
	_finish()


func _finish() -> void:
	print("OVERWORLD_EVENTS_HUNT_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _shoot(shot_name: String) -> void:
	if out_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, shot_name])
	print("shot ", shot_name)


func _last(event_type: String) -> Dictionary:
	for index in range(WorldHistory.events.size() - 1, -1, -1):
		if str(WorldHistory.events[index].type) == event_type:
			return WorldHistory.events[index]
	return {}
