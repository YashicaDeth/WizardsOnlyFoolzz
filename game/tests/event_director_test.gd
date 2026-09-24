extends Node3D

## The overworld event director plays events end to end and WorldHistory
## remembers how each one ended: the splinter monks' trade (with their spirit
## vision), a monk quest filed under END ALL SUFFERING, a stand-in fight to a
## boss going down, and the crazed driver's car really driving at the player
## on the derby chassis before the driver gets out to fight. It must not fire
## on its own under ATG_TEST_MODE.

const Generator := preload("res://systems/event_generator.gd")

var failures: Array[String] = []
var director: OverworldEventDirector
var player_camera: Camera3D
var player := Vector3(0, 0, 0)


func _ready() -> void:
	_build_floor()
	player_camera = Camera3D.new()
	add_child(player_camera)
	player_camera.global_position = Vector3(0, 1.7, 0)
	player_camera.make_current()
	director = OverworldEventDirector.new()
	add_child(director)
	await get_tree().physics_frame

	# Guarded in tests.
	_check(not director.autoplay, "autoplay is off under ATG_TEST_MODE")
	var started_before := WorldHistory.event_count("overworld_event_started")
	for i in 100:
		director.tick(5.0, player)
	_check(WorldHistory.event_count("overworld_event_started") == started_before and director.state == "idle", "nothing fires on its own in a test")

	await _monk_trade()
	await _monk_quest()
	await _generic_fight()
	await _driver()

	for failure in failures:
		print("FAIL ", failure)
	print("EVENT_DIRECTOR_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _monk_trade() -> void:
	var event := Generator.signature_event("splinter_monks")
	_check(director.play(event, player), "the monks' event plays")
	_check(director.state == "cutscene", "it opens as a cutscene")
	_check(director.cast.size() == 5, "five monks are staged (%d)" % director.cast.size())
	_check(director.vision != null, "a spirit vision is staged")
	_check(get_viewport().get_camera_3d() == director.camera, "the event camera takes over")
	var monk := director.lead
	_check(monk != null and monk.parts.torso.get_node_or_null("Schema") != null and monk.parts.head.get_node_or_null("Koukoulion") != null, "the eldest wears the hood and the schema")
	var saw_vision := false
	var guard := 0
	while director.state == "cutscene" and guard < 200:
		director.tick(0.25, player)
		if str(director.current_beat().get("shot", "")) == "vision" and director.vision.target_presence >= 1.0:
			saw_vision = true
		guard += 1
		await get_tree().process_frame
	_check(saw_vision, "the vision is called up during its beat")
	_check(director.state == "trade_offer", "the monks end in a trade offer (state %s)" % director.state)
	_check(get_viewport().get_camera_3d() == player_camera, "the player's camera is given back")
	director.accept_trade()
	var resolved := _last("overworld_event_resolved")
	var details: Dictionary = resolved.get("details", {})
	_check(str(details.get("event_id", "")) == str(event.id) and str(details.get("outcome", "")) == "trade" and bool(details.get("accepted", false)), "WorldHistory records the accepted trade")
	_check(str(details.get("gives", "")).begins_with("[PLACEHOLDER]"), "what the monks trade is flagged as a placeholder")
	director.clear_stage()
	director.state = "idle"
	await get_tree().process_frame


func _monk_quest() -> void:
	var chosen: Dictionary = {}
	for event in Generator.events_matching({"actor": "splinter_monks", "outcome": "quest"}):
		if str(event.want) == "to_be_freed":
			chosen = event
			break
	_check(not chosen.is_empty() and director.play(chosen, player), "a monk quest plays")
	director.skip_cutscene()
	var task_id := director.last_task_id
	var task := WorldHistory.subject(task_id)
	_check(str(task.get("kind", "")) == "task" and str(task.get("status", "")) == "open", "a task subject is opened (%s)" % task_id)
	_check(str(task.get("parent_task", "")) == "end_all_suffering", "freeing the splinter is part of END ALL SUFFERING")
	var details: Dictionary = _last("overworld_event_resolved").get("details", {})
	_check(str(details.get("outcome", "")) == "quest" and str(details.get("task_id", "")) == task_id, "WorldHistory records the quest outcome")
	director.clear_stage()
	director.state = "idle"
	await get_tree().process_frame


func _generic_fight() -> void:
	var chosen: Dictionary = {}
	for event in Generator.events_matching({"actor": "guild_enforcer", "outcome": "fight"}):
		chosen = event
		break
	_check(director.play(chosen, player), "a guild enforcer fight plays")
	director.skip_cutscene()
	_check(director.state == "fight" and director.boss_rig != null, "the fight hands off to a boss body")
	_check(str(_last("overworld_event_handoff").get("details", {}).get("outcome", "")) == "fight", "the hand-off to a fight is recorded")
	await _down(director.boss_rig)
	director.tick(0.1, player)
	var details: Dictionary = _last("overworld_event_resolved").get("details", {})
	_check(str(details.get("outcome", "")) == "fight" and str(details.get("result", "")) == "boss_down", "WorldHistory records the boss going down (%s)" % str(details.get("result", "")))
	director.clear_stage()
	director.state = "idle"
	await get_tree().process_frame


func _driver() -> void:
	var event := Generator.signature_event("crazed_driver")
	_check(director.play(event, player), "the crazed driver plays")
	_check(director.vehicle != null, "a real derby chassis is staged")
	var start: Vector3 = director.vehicle.global_position
	var closest := 1.0e9
	var travelled := 0.0
	var last := start
	var spun := 0.0
	var frames := 0
	while director.state == "cutscene" and frames < 60 * 30:
		await get_tree().physics_frame
		director.tick(1.0 / 60.0, player)
		if director.vehicle != null:
			var now: Vector3 = director.vehicle.global_position
			travelled += now.distance_to(last)
			last = now
			closest = minf(closest, Vector2(now.x - player.x, now.z - player.z).length())
			if director.vehicle_phase == "crazy":
				spun += absf(director.vehicle.angular_velocity.y) / 60.0
			if frames % 30 == 0 and OS.get_environment("ATG_EVENT_DEBUG") == "1":
				print("  t=%.1f phase=%s pos=%s speed=%.1f yaw_rate=%.2f" % [frames / 60.0, director.vehicle_phase, str(now.snapped(Vector3.ONE * 0.1)), director.vehicle.linear_velocity.length(), director.vehicle.angular_velocity.y])
		frames += 1
	print("EVENT_DIRECTOR driver start=%.1fm closest=%.1fm travelled=%.1fm spun=%.1frad frames=%d" % [Vector2(start.x, start.z).length(), closest, travelled, spun, frames])
	_check(travelled > 25.0, "the car really drives (%.1fm)" % travelled)
	_check(closest < 8.0, "it comes at the player (closest %.1fm)" % closest)
	_check(spun > 3.0, "it goes crazy and spins (%.1f rad)" % spun)
	_check(director.state == "fight" and director.boss_rig != null, "the driver gets out to fight")
	_check(director.vehicle.get_node_or_null("DriverRig") == null or director.vehicle.get_node("DriverRig").is_queued_for_deletion(), "the driver has left the cab")
	await _down(director.boss_rig)
	director.tick(0.1, player)
	var details: Dictionary = _last("overworld_event_resolved").get("details", {})
	_check(str(details.get("event_id", "")) == str(event.id) and str(details.get("result", "")) == "boss_down", "WorldHistory records the driver's fight ending")
	director.clear_stage()


func _down(rig: BaselineHuman) -> void:
	var guard := 0
	while rig != null and is_instance_valid(rig) and not rig.is_downed() and guard < 60:
		rig.hit("torso", 60.0, 1.0, "blunt")
		rig.hit("head", 40.0, 1.0, "blunt")
		guard += 1
		await get_tree().process_frame


func _last(event_type: String) -> Dictionary:
	for index in range(WorldHistory.events.size() - 1, -1, -1):
		if str(WorldHistory.events[index].type) == event_type:
			return WorldHistory.events[index]
	return {}


func _build_floor() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -0.5, 0)
	add_child(floor_body)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok ", what)
	else:
		failures.append(what)
