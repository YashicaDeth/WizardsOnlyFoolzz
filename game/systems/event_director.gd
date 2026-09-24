class_name OverworldEventDirector
extends Node3D

## Plays the overworld's random events (DESIGN/OVERWORLD_EVENTS.md): picks one
## from `OverworldEventGenerator`, stages it near the player as a short
## in-engine mini cutscene (its own camera, letterbox, subtitles), then hands
## off to what the event resolves into:
##   quest - a task subject written into WorldHistory (freeing the splinter is
##           filed under the main task, END ALL SUFFERING);
##   trade - a simple offer the player accepts [Y] or refuses [N];
##   fight - a boss or mini-boss. Inside the Hunt it is spawned through the
##           Hunt's own `_spawn_encounter_actor`, so the Hunt's combat, AI,
##           looting and records own it; anywhere else a plain BaselineHuman
##           stands in.
## Every event writes `overworld_event_started`, and every ending writes
## `overworld_event_resolved` with the outcome.
##
## Staging: "generic" (people standing in the way), "vehicle_ram" (the rift
## derby's own chassis and scrap skiff, aimed at the player), "monk_rite" (the
## splinter monks around a spirit vision).
##
## Owner contract: call `tick(delta, player_position)` every physics frame.
## It fires on its own only when `autoplay` is true, which it never is under
## ATG_TEST_MODE unless ATG_OVERWORLD_EVENTS=1 asks for it.

signal event_started(event: Dictionary)
signal handed_off(event: Dictionary, outcome: Dictionary)
signal event_resolved(event: Dictionary, record: Dictionary)

const Generator := preload("res://systems/event_generator.gd")
const Parts := preload("res://systems/event_parts.gd")
const VEHICLE := preload("res://systems/arcade_vehicle.gd")
const SCRAP_SKIFF := preload("res://art/scrap_skiff.glb")
## Matches rift_derby.gd's seat for the same shell.
const SKIFF_WHEEL_BOTTOM := 0.030

const STATE_IDLE := "idle"
const STATE_CUTSCENE := "cutscene"
const STATE_TRADE := "trade_offer"
const STATE_FIGHT := "fight"
const STATE_DONE := "done"

## Assistant proposal, not Greg's: the first event after two and a half
## minutes in the region, then one every five minutes at most.
## Greg, 24 September: "often, GTA-style" -- roughly one every one to two
## minutes, the first a minute in.
var first_delay := 60.0
var cooldown := 90.0
var trade_timeout := 30.0
var linger_seconds := 45.0
var autoplay := false

var state := STATE_IDLE
var event: Dictionary = {}
var origin := Vector3.ZERO
var player_position := Vector3.ZERO
var beat_index := 0
var beat_time := 0.0
var elapsed := 0.0
var cutscene_length := 0.0
var records: Array[Dictionary] = []
var last_task_id := ""

var stage: Node3D
var cast: Array[BaselineHuman] = []
var lead: BaselineHuman
var vehicle: RigidBody3D
var vehicle_phase := ""
var vision: SpiritVision
var boss_rig: BaselineHuman
var boss_subject := ""
var camera: Camera3D
var _previous_camera: Camera3D
var _camera_snapped := false
var _overlay: CanvasLayer
var _card: EventCard
var _timer := 0.0
var _state_time := 0.0
var _approach := Vector3.FORWARD
var _side := Vector3.RIGHT
var _charge_aim := Vector3.INF
var _spin_kick := 0.0
var _came_past := false


func _ready() -> void:
	var testing := OS.get_environment("ATG_TEST_MODE") == "1"
	autoplay = not testing or OS.get_environment("ATG_OVERWORLD_EVENTS") == "1"


## The one call an owner makes, every physics frame.
func tick(delta: float, player_at: Vector3) -> void:
	player_position = player_at
	match state:
		STATE_IDLE:
			if not autoplay:
				return
			_timer += delta
			var wait := first_delay if WorldHistory.event_count("overworld_event_started") == 0 and records.is_empty() else cooldown
			if _timer >= wait:
				_timer = 0.0
				play(pick_event(), player_at)
		STATE_CUTSCENE:
			_advance_cutscene(delta)
		STATE_TRADE:
			_state_time += delta
			_update_vehicle(delta)
			if _state_time >= trade_timeout:
				refuse_trade("walked_away")
		STATE_FIGHT:
			_state_time += delta
			_update_vehicle(delta)
			if boss_rig == null or not is_instance_valid(boss_rig):
				_resolve_fight("gone")
			elif boss_rig.is_downed() or (boss_rig.anatomy != null and (boss_rig.anatomy.dead or boss_rig.anatomy.downed)):
				_resolve_fight("boss_down")
			elif _flat_distance(player_position, boss_rig.global_position) > 90.0:
				_resolve_fight("player_left")
		STATE_DONE:
			_state_time += delta
			_update_vehicle(delta)
			if _state_time >= linger_seconds or _flat_distance(player_position, origin) > 70.0:
				clear_stage()
				state = STATE_IDLE


## The seed is the run's own salt plus how many events this world has seen,
## so a run replays the same sequence and two runs differ.
func pick_event(filter: Dictionary = {}) -> Dictionary:
	var seed_value := int(WorldHistory.run_salt) * 31 + WorldHistory.event_count("overworld_event_started") * 7919 + 17
	return Generator.pick(seed_value, filter)


## Play `chosen` now, staged in front of the player.
func play(chosen: Dictionary, player_at: Vector3) -> bool:
	if chosen.is_empty():
		return false
	if state != STATE_IDLE and state != STATE_DONE:
		return false
	clear_stage()
	player_position = player_at
	_approach = _view_forward()
	_side = _approach.cross(Vector3.UP).normalized()
	origin = _ground_at(player_at + _approach * (9.0 if str(chosen.staging) != "monk_rite" else 11.0), player_at.y - 1.0)
	# A car needs ground to drive on; without any, the director does not fake
	# one - it picks an event that does not need it.
	if str(chosen.staging) == "vehicle_ram" and not _has_ground(player_at + _approach * 38.0):
		chosen = pick_event({"exclude_staging": ["vehicle_ram"]})
		if chosen.is_empty():
			return false
	event = chosen.duplicate(true)
	state = STATE_CUTSCENE
	beat_index = 0
	beat_time = 0.0
	elapsed = 0.0
	_state_time = 0.0
	cutscene_length = 0.0
	for beat in event.beats:
		cutscene_length += float(beat.get("seconds", 2.4))
	stage = Node3D.new()
	stage.name = "EventStage"
	add_child(stage)
	stage.global_transform = Transform3D.IDENTITY
	match str(event.staging):
		"vehicle_ram":
			_stage_vehicle()
		"monk_rite":
			_stage_monks()
		_:
			_stage_generic()
	if bool(event.get("vision", false)) and vision == null:
		_spawn_vision(origin + (Vector3.ZERO if str(event.staging) == "monk_rite" else -_side * 1.8 - _approach * 1.5))
	_record("overworld_event_started", {
		"title": str(event.title), "act": str(event.act), "escalation": str(event.escalation),
		"outcome_kind": str((event.outcome as Dictionary).kind),
		"signature": bool(event.signature), "placeholder": bool(event.placeholder),
	})
	_begin_camera()
	_open_overlay()
	_show_beat()
	event_started.emit(event)
	return true


## Test and gallery helper: play an actor's written-in-full event.
func play_signature(actor_id: String, player_at: Vector3) -> bool:
	return play(Generator.signature_event(actor_id), player_at)


func skip_cutscene() -> void:
	if state == STATE_CUTSCENE:
		_hand_off()


# --- the cutscene ------------------------------------------------------------

func _advance_cutscene(delta: float) -> void:
	beat_time += delta
	elapsed += delta
	_update_vehicle(delta)
	_update_cast(delta)
	var beats: Array = event.beats
	var beat: Dictionary = beats[beat_index]
	if str(beat.get("shot", "")) == "vision" and vision != null:
		vision.target_presence = 1.0
	_update_camera(delta, str(beat.get("shot", "wide")))
	if beat_time >= float(beat.get("seconds", 2.4)):
		beat_time = 0.0
		beat_index += 1
		if beat_index >= beats.size():
			_hand_off()
			return
		_show_beat()


func _show_beat() -> void:
	if _card == null:
		return
	var beat: Dictionary = (event.beats as Array)[beat_index]
	_card.title = str(event.title) if beat_index == 0 else ""
	_card.speaker = str(beat.get("speaker", ""))
	_card.set_line(str(beat.get("line", "")))
	_card.queue_redraw()


func current_beat() -> Dictionary:
	if state != STATE_CUTSCENE or event.is_empty():
		return {}
	return (event.beats as Array)[beat_index]


# --- hand-off -----------------------------------------------------------------

func _hand_off() -> void:
	_end_camera()
	var outcome: Dictionary = event.outcome
	_state_time = 0.0
	match str(outcome.kind):
		Parts.OUTCOME_QUEST:
			_hand_off_quest(outcome)
		Parts.OUTCOME_TRADE:
			state = STATE_TRADE
			if _card != null:
				_card.show_offer(outcome.offer as Dictionary)
		Parts.OUTCOME_FIGHT:
			_hand_off_fight(outcome)
	handed_off.emit(event, outcome)


func _hand_off_quest(outcome: Dictionary) -> void:
	var task: Dictionary = outcome.task
	last_task_id = "overworld_task:%s:%06d" % [str(event.actor), WorldHistory.next_sequence]
	WorldHistory.register_subject(last_task_id, {
		"kind": "task", "name": str(task.title), "title": str(task.title), "status": "open",
		"source_event": str(event.id), "from_actor": str(event.actor), "place": str(event.place),
		"parent_task": str(task.get("parent", "")), "placeholder": true,
		"opened_at": WorldClock.long_stamp(),
	})
	_close_overlay()
	_resolve({"outcome": Parts.OUTCOME_QUEST, "task_id": last_task_id, "task_title": str(task.title), "parent_task": str(task.get("parent", ""))})


func accept_trade() -> void:
	if state != STATE_TRADE:
		return
	var offer: Dictionary = (event.outcome as Dictionary).offer
	_close_overlay()
	_resolve({"outcome": Parts.OUTCOME_TRADE, "accepted": true, "gives": str(offer.gives), "asks": str(offer.asks), "placeholder": bool(offer.get("placeholder", true))})


func refuse_trade(reason := "refused") -> void:
	if state != STATE_TRADE:
		return
	var offer: Dictionary = (event.outcome as Dictionary).offer
	_close_overlay()
	_resolve({"outcome": Parts.OUTCOME_TRADE, "accepted": false, "reason": reason, "gives": str(offer.gives), "asks": str(offer.asks)})


func _unhandled_input(input: InputEvent) -> void:
	if state != STATE_TRADE:
		return
	var key := input as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_Y:
		accept_trade()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_N:
		refuse_trade()
		get_viewport().set_input_as_handled()


func _hand_off_fight(outcome: Dictionary) -> void:
	var boss: Dictionary = outcome.boss
	var at := origin
	var is_monk := str(event.staging) == "monk_rite"
	# The one who fights is the lead: the eldest monk, the driver out of the
	# cab, the first person standing in the road.
	if vehicle != null and is_instance_valid(vehicle):
		var seat := vehicle.get_node_or_null("DriverRig")
		if seat != null:
			seat.queue_free()
		at = vehicle.global_position + vehicle.global_transform.basis.x * 2.2
		vehicle_phase = "parked"
	elif lead != null and is_instance_valid(lead):
		at = lead.global_position
	boss_subject = ""
	boss_rig = null
	var host := get_parent()
	if host != null and host.has_method("_spawn_encounter_actor"):
		if lead != null and is_instance_valid(lead):
			cast.erase(lead)
			lead.get_parent().queue_free()
			lead = null
		var actor: Dictionary = host.call("_spawn_encounter_actor", {
			"instance_id": "overworld_%s_%06d" % [str(event.actor), WorldHistory.next_sequence],
			"kind": str(boss.kind), "display_name": str(boss.name), "elo": int(boss.elo),
			"role": "overworld_%s" % str(event.actor), "disposition": "hostile",
		}, at)
		if not actor.is_empty():
			boss_rig = actor.get("rig") as BaselineHuman
			boss_subject = str(actor.get("subject_id", ""))
			if is_monk and boss_rig != null:
				SplinterMonkLook.dress(boss_rig, 1, true)
	else:
		# No Hunt to fight in: the lead stands in (or a new body at the car).
		if lead != null and is_instance_valid(lead):
			boss_rig = lead
		else:
			boss_rig = _spawn_person("boss", at, false)
		boss_subject = boss_rig.subject_id
		var plate := Label3D.new()
		plate.text = "%s\n%s" % [str(boss.name).to_upper(), "BOSS" if str(outcome.tier) == Parts.TIER_BOSS else "MINI-BOSS"]
		plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		plate.position = Vector3(0, 2.3, 0)
		boss_rig.add_child(plate)
	state = STATE_FIGHT
	if _card != null:
		_card.title = "%s  //  %s" % [str(boss.name).to_upper(), "BOSS" if str(outcome.tier) == Parts.TIER_BOSS else "MINI-BOSS"]
		_card.speaker = ""
		_card.set_line("")
		_card.letterbox = false
		_card.queue_redraw()
	_record("overworld_event_handoff", {"outcome": Parts.OUTCOME_FIGHT, "tier": str(outcome.tier), "boss": str(boss.name), "boss_subject": boss_subject, "in_hunt": host != null and host.has_method("_spawn_encounter_actor")})


func _resolve_fight(result: String) -> void:
	var outcome: Dictionary = event.outcome
	_close_overlay()
	_resolve({"outcome": Parts.OUTCOME_FIGHT, "tier": str(outcome.tier), "result": result, "boss_subject": boss_subject})


func _resolve(details: Dictionary) -> void:
	var record := _record("overworld_event_resolved", details)
	records.append(record)
	state = STATE_DONE
	_state_time = 0.0
	if vision != null and is_instance_valid(vision):
		vision.dismiss()
	event_resolved.emit(event, record)


func _record(event_type: String, details: Dictionary) -> Dictionary:
	var full := {"event_id": str(event.get("id", "")), "actor": str(event.get("actor", "")), "want": str(event.get("want", "")), "place": str(event.get("place", ""))}
	full.merge(details, true)
	return WorldHistory.record_event(event_type, full)


## Removes everything the director staged. A boss spawned into the Hunt is
## the Hunt's now and is left alone.
func clear_stage() -> void:
	_end_camera()
	_close_overlay()
	if stage != null and is_instance_valid(stage):
		stage.queue_free()
	stage = null
	cast.clear()
	lead = null
	vehicle = null
	vision = null
	vehicle_phase = ""


# --- staging ------------------------------------------------------------------

func _stage_generic() -> void:
	var group := bool(event.get("group", false))
	var count := 3 if group else 1
	var armed := (Parts.ACTORS[str(event.actor)].tags as Array).has("violent")
	for index in count:
		var offset := _side * (float(index) - float(count - 1) * 0.5) * 1.4 - _approach * (0.6 if index != 0 else 0.0)
		var rig := _spawn_person(str(index), origin + offset, armed)
		if index == 0:
			lead = rig


func _stage_monks() -> void:
	# Four monks in an arc behind the vision, the eldest at the head of it.
	var angles := [-1.25, -0.6, 0.0, 0.6, 1.25]
	for index in angles.size():
		var elder: bool = index == 2
		var away := (_approach).rotated(Vector3.UP, float(angles[index]))
		var at := _ground_at(origin + away * (2.9 if elder else 2.5), origin.y)
		var holder := Node3D.new()
		holder.name = "Monk%d" % index
		stage.add_child(holder)
		holder.global_position = at
		var rig := SplinterMonkLook.build_monk("overworld_monk_%d" % index, 11 + index * 5, elder, holder)
		# The eldest faces the player; the rest face what they are calling up.
		var look_target := player_position if elder else origin
		_face(holder, look_target)
		_raise_arms(rig, 0.4 if elder else 1.0)
		cast.append(rig)
		if elder:
			lead = rig
	vision = null


func _stage_vehicle() -> void:
	var start := _ground_at(player_position + _approach * 38.0 + _side * 3.0, player_position.y) + Vector3.UP * 0.8
	vehicle = VEHICLE.new()
	vehicle.name = "CrazedDriverSkiff"
	stage.add_child(vehicle)
	vehicle.global_position = start
	_face(vehicle, player_position)
	var shell := SCRAP_SKIFF.instantiate() as Node3D
	shell.name = "ScrapVehicleShell"
	shell.scale = Vector3.ONE * 1.05
	vehicle.add_child(shell)
	shell.position.y = VEHICLE.rest_contact_y() - SKIFF_WHEEL_BOTTOM * shell.scale.y
	# The derby's own grime pass, so it is one of the region's cars.
	WorldLook.regrime(shell, 7)
	var driver := BaselineHuman.new()
	driver.name = "DriverRig"
	driver.position = Vector3(0, -0.15, 0.25)
	vehicle.add_child(driver)
	driver.build("overworld_driver", {"seated": true, "flesh": Color("6b5842"), "variation": 9, "blood": 5200.0})
	driver.dress(ClothingShell.fresh_wardrobe())
	_charge_aim = Vector3.INF
	_spin_kick = 0.0
	_came_past = false
	vehicle.enabled = true
	vehicle_phase = "charge"


func _update_vehicle(delta: float) -> void:
	if vehicle == null or not is_instance_valid(vehicle):
		return
	# The shape of the driver's scene: charge (a near miss), then go crazy
	# (spinning, throttle pinned, the handbrake yanked), then stop and get out.
	if state == STATE_CUTSCENE and cutscene_length > 0.0:
		var fraction := elapsed / cutscene_length
		if fraction < 0.5:
			vehicle_phase = "charge"
		elif fraction < 0.82:
			vehicle_phase = "crazy"
		else:
			vehicle_phase = "stopping"
	match vehicle_phase:
		"charge":
			# Aimed just beside the player and through them: the first pass is
			# a warning. Steered by throttle and steering only, like every
			# driver on this chassis. (DerbyAIDriver was tried first: its
			# arena break-off peeled away 12m short of the player.)
			vehicle.enabled = true
			if _charge_aim == Vector3.INF:
				_charge_aim = player_position + _side * 2.4
			var behind := (vehicle.global_position - player_position).dot(_approach)
			if behind < -4.0:
				_came_past = true
			if _came_past:
				# Past and well clear: haul it round and come back at them.
				var back := _steer_toward(player_position - _side * 3.0, 0.8)
				if absf(back) > 0.7 and vehicle.linear_velocity.length() > 6.0:
					# Stand on the brakes to get it round.
					vehicle.throttle = -1.0 if vehicle.signed_speed > 0.0 else 0.4
			else:
				_steer_toward(_charge_aim + (_charge_aim - vehicle.global_position).normalized() * 30.0, 1.0)
		"crazy":
			vehicle.enabled = true
			# A tight doughnut: hold the speed down so the lock can turn it.
			var speed := vehicle.linear_velocity.length()
			vehicle.throttle = 1.0 if speed < 5.5 else 0.2
			vehicle.steering = 1.0
			_spin_kick -= delta
			if _spin_kick <= 0.0:
				_spin_kick = 0.7
				vehicle.apply_torque_impulse(Vector3.UP * vehicle.mass * -4.5)
		"stopping", "parked":
			vehicle.throttle = 0.0
			vehicle.steering = 0.0
			if vehicle.linear_velocity.length() < 1.5:
				vehicle.enabled = false


func _steer_toward(point: Vector3, throttle: float) -> float:
	var to := vehicle.global_transform.basis.inverse() * (point - vehicle.global_position)
	var angle := atan2(to.x, -to.z)
	vehicle.steering = clampf(angle * 2.2, -1.0, 1.0)
	vehicle.throttle = throttle
	return angle


func _update_cast(_delta: float) -> void:
	if str(event.get("staging", "")) != "monk_rite":
		return
	# A slow sway while they hold the rite, so they are not statues.
	for index in cast.size():
		var rig := cast[index]
		if rig != null and is_instance_valid(rig):
			rig.rotation.z = sin(elapsed * 0.9 + index) * 0.03


func _spawn_person(tag: String, at: Vector3, armed: bool) -> BaselineHuman:
	var holder := Node3D.new()
	holder.name = "Person_%s" % tag
	stage.add_child(holder)
	holder.global_position = _ground_at(at, at.y)
	var rig := BaselineHuman.new()
	rig.name = "Body"
	holder.add_child(rig)
	var id := "overworld_%s_%s" % [str(event.get("actor", "someone")), tag]
	rig.build(id, {"flesh": Color("6b5842").darkened(float(abs(hash(id)) % 5) * 0.05), "variation": abs(hash(id)) % 17})
	rig.dress(ClothingShell.fresh_wardrobe())
	HunterAppearance.style_world_rig(rig, id, armed)
	_face(holder, player_position)
	cast.append(rig)
	return rig


func _spawn_vision(at: Vector3) -> void:
	vision = SpiritVision.new()
	vision.name = "SpiritVision"
	vision.seed_value = abs(hash(str(event.get("id", "")))) % 97
	vision.target_presence = 0.0
	stage.add_child(vision)
	vision.global_position = at


## Arms up in invocation, pivoted at the shoulder. `amount` 1 is fully raised.
func _raise_arms(rig: BaselineHuman, amount: float) -> void:
	for zone_id in ["left_arm", "right_arm"]:
		var arm := rig.parts.get(zone_id) as Node3D
		if arm == null:
			continue
		var rest: Vector3 = arm.get_meta("rest_position", arm.position)
		var half := 0.31
		var shoulder := rest + Vector3(0, half, 0)
		var angle := lerpf(0.0, 2.3, amount)
		var basis := Basis(Vector3.RIGHT, angle).rotated(Vector3.FORWARD, (0.25 if zone_id == "left_arm" else -0.25) * amount)
		arm.transform = Transform3D(basis, shoulder + basis * Vector3(0, -half, 0))


func _face(node: Node3D, target: Vector3) -> void:
	var flat := Vector3(target.x, node.global_position.y, target.z)
	if flat.distance_to(node.global_position) > 0.01:
		node.look_at(flat, Vector3.UP)


# --- camera -------------------------------------------------------------------

func _begin_camera() -> void:
	var viewport := get_viewport()
	_previous_camera = viewport.get_camera_3d() if viewport != null else null
	camera = Camera3D.new()
	camera.name = "EventCamera"
	camera.fov = 58.0
	camera.far = 900.0
	add_child(camera)
	camera.make_current()
	_camera_snapped = false
	_update_camera(1.0, "wide")


func _end_camera() -> void:
	if camera != null and is_instance_valid(camera):
		camera.clear_current(false)
		camera.queue_free()
	camera = null
	if _previous_camera != null and is_instance_valid(_previous_camera):
		_previous_camera.make_current()
	_previous_camera = null


func _update_camera(delta: float, shot: String) -> void:
	if camera == null:
		return
	var eye := Vector3.ZERO
	var look := Vector3.ZERO
	var focus := origin
	if lead != null and is_instance_valid(lead):
		focus = lead.global_position
	match shot:
		"actor":
			if vehicle != null and is_instance_valid(vehicle) and str(event.staging) == "vehicle_ram":
				focus = vehicle.global_position
			eye = focus - _approach * 3.4 + _side * 2.2 + Vector3.UP * 1.75
			look = focus + Vector3.UP * 1.45
		"vision":
			eye = origin - _approach * 5.2 + _side * 0.8 + Vector3.UP * 0.7
			look = origin + Vector3.UP * 2.4
		"vehicle":
			var car := vehicle.global_position if vehicle != null and is_instance_valid(vehicle) else origin
			eye = player_position + _side * 4.0 - _approach * 2.0 + Vector3.UP * 2.2
			look = car + Vector3.UP * 0.8
		"chase":
			var car3 := vehicle.global_position if vehicle != null and is_instance_valid(vehicle) else origin
			var from_player := car3 - player_position
			from_player.y = 0.0
			var back := from_player.normalized() if from_player.length() > 0.5 else -_approach
			eye = car3 - back * 9.0 + back.cross(Vector3.UP) * 3.0 + Vector3.UP * 3.2
			look = car3 + Vector3.UP * 0.6
		"vehicle_pass":
			var car2 := vehicle.global_position if vehicle != null and is_instance_valid(vehicle) else origin
			eye = player_position - _side * 2.2 - _approach * 1.2 + Vector3.UP * 0.9
			look = car2 + Vector3.UP * 0.6
		_:
			var centre := (origin + player_position) * 0.5
			if str(event.get("staging", "")) == "vehicle_ram" and vehicle != null and is_instance_valid(vehicle):
				centre = (vehicle.global_position + player_position) * 0.5
			eye = player_position - _approach * 6.0 + _side * 3.0 + Vector3.UP * 4.2
			look = centre + Vector3.UP * 1.0
	var target := Transform3D(Basis.IDENTITY, eye).looking_at(look, Vector3.UP)
	if not _camera_snapped:
		camera.global_transform = target
		_camera_snapped = true
	else:
		var weight := 1.0 - exp(-3.5 * delta)
		camera.global_transform = camera.global_transform.interpolate_with(target, weight)


func _view_forward() -> Vector3:
	var viewport := get_viewport()
	var current := viewport.get_camera_3d() if viewport != null else null
	var forward := Vector3.FORWARD
	if current != null:
		forward = -current.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		forward = Vector3.FORWARD
	return forward.normalized()


# --- ground -------------------------------------------------------------------

func _ground_hit(at: Vector3) -> Dictionary:
	var world := get_world_3d()
	if world == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at + Vector3.DOWN * 60.0)
	query.collide_with_areas = false
	return world.direct_space_state.intersect_ray(query)


func _has_ground(at: Vector3) -> bool:
	return not _ground_hit(at).is_empty()


func _ground_at(at: Vector3, fallback_y: float) -> Vector3:
	var hit := _ground_hit(at)
	if hit.is_empty():
		return Vector3(at.x, fallback_y, at.z)
	return hit.position


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- overlay ------------------------------------------------------------------

func _open_overlay() -> void:
	_close_overlay()
	_overlay = CanvasLayer.new()
	_overlay.name = "EventOverlay"
	_overlay.layer = 70
	add_child(_overlay)
	_card = EventCard.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_card)


func _close_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_card = null


## Letterbox, title, speaker and subtitle; the trade offer. Names, titles and
## keys in CellOutzType; the spoken line itself in a real font, because
## wrapped prose stays in a real font (wof-lane-hygiene).
class EventCard extends Control:
	var title := ""
	var speaker := ""
	var letterbox := true
	var offer: Dictionary = {}
	var _line: Label

	func _ready() -> void:
		_line = Label.new()
		_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_line.add_theme_font_size_override("font_size", 22)
		_line.add_theme_color_override("font_color", Color("e9e1cf"))
		_line.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_line.add_theme_constant_override("outline_size", 6)
		add_child(_line)
		resized.connect(_layout)
		_layout()

	func _layout() -> void:
		if _line == null:
			return
		var s := size
		_line.position = Vector2(s.x * 0.14, s.y * 0.8)
		_line.size = Vector2(s.x * 0.72, s.y * 0.1)

	func set_line(text: String) -> void:
		if _line != null:
			_line.text = text

	func show_offer(given: Dictionary) -> void:
		offer = given
		letterbox = false
		title = "A TRADE"
		speaker = ""
		set_line("They offer: %s\nThey ask: %s" % [str(given.get("gives", "")), str(given.get("asks", ""))])
		queue_redraw()

	func _draw() -> void:
		var s := size
		if letterbox:
			draw_rect(Rect2(0, 0, s.x, s.y * 0.1), Color(0, 0, 0, 0.92))
			draw_rect(Rect2(0, s.y * 0.9, s.x, s.y * 0.1), Color(0, 0, 0, 0.92))
		if not title.is_empty():
			CellOutzType.draw_text(self, Vector2(s.x * 0.06, s.y * 0.13), title, 26.0, Color("e9e1cf"), 2.0)
			draw_rect(Rect2(s.x * 0.06, s.y * 0.13 + 34.0, CellOutzType.width(title, 26.0, 2.0), 2.0), Color("8f1d16"))
		if not speaker.is_empty():
			var w := CellOutzType.width(speaker, 14.0, 1.5)
			CellOutzType.draw_text(self, Vector2((s.x - w) * 0.5, s.y * 0.8 - 22.0), speaker, 14.0, Color("c9483a"), 1.5)
		if not offer.is_empty():
			draw_rect(Rect2(s.x * 0.12, s.y * 0.76, s.x * 0.76, s.y * 0.2), Color(0.02, 0.015, 0.015, 0.78))
			var keys := "[Y] ACCEPT     [N] REFUSE"
			var kw := CellOutzType.width(keys, 14.0, 1.5)
			CellOutzType.draw_text(self, Vector2((s.x - kw) * 0.5, s.y * 0.93), keys, 14.0, Color("e9e1cf"), 1.5)
