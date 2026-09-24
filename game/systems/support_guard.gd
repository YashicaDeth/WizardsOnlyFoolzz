class_name SupportGuard
extends Node3D

## A CellOutz guard in the Support Unit. The body is the game's own
## `BaselineHuman`, dressed and armed the way Hollis is (`ClothingShell`,
## `FacilityGuardLoadout`), so a guard is hit, bleeds, goes down and dies by the
## same anatomy as anyone else, and the world records it.
##
## Greg, 24 September: sneak so you do not "alert the guards", and once the
## alarm goes "more guards begin piling out ... and they try to kill you".
##
##   patrol       walks a round; sees what is in front of it
##   investigate  goes to look at the last noise or at a distraction
##   hunt         alarm: closes to firing range and shoots
##   down         out of the fight (downed or dead)
##
## Its names wait on Greg (guard names are an open question); the record calls
## each one by its post.
##
## The host calls `step()` once per frame and listens to `shot`.

signal shot(target: Node3D, damage: float)

const BODY := preload("res://systems/baseline_human.gd")
const LOADOUT := preload("res://systems/facility_guard_loadout.gd")

const WALK := 1.3
const RUN := 3.1
const SIGHT := 10.0
const SIGHT_CROUCHED := 5.0
const SIGHT_HALF_ANGLE := deg_to_rad(55.0)
## Held in sight this long and it is a clear sighting: the alarm.
const SPOT_SECONDS := 1.1
const FIRE_RANGE := 9.0
const KEEP_OFF := 4.5
const FIRE_COOLDOWN := 1.5
const SHOT_DAMAGE := 10.0
const HIT_CHANCE := 0.6
## The hallway between the cells; guards keep to it.
const LANE_HALF_WIDTH := 3.9

var rig: Node3D
var loadout: RefCounted
var director: AlarmDirector
var subject_id := ""
var state := "patrol"
var alerted := false
var certainty := 0.0
var route: Array[Vector3] = []
var route_index := 0
var investigate_at := Vector3.ZERO
var distraction: Node3D
var distraction_left := 0.0
var fire_cooldown := 0.0
var muzzle: OmniLight3D
var speech: Label3D
var speech_timer := 0.0
var shots_fired := 0
var _sight := 0.0
var _rng := RandomNumberGenerator.new()
var _pace := 0.0


func build(id: String, at: Vector3, round: Array[Vector3], alarm: AlarmDirector, reinforcement := false) -> void:
	subject_id = id
	director = alarm
	_rng.seed = hash(id)
	route = round
	position = at
	WorldHistory.register_subject(subject_id, {
		"name": "CELLOUTZ SECURITY", "kind": "person", "faction": "CellOutz Security",
		"role": "Support Unit reinforcement" if reinforcement else "Support Unit hallway guard",
		"status": "on post", "place": "support_unit",
	})
	rig = BODY.new()
	rig.name = "Body"
	add_child(rig)
	rig.build(subject_id, {"flesh": Color("5a4938"), "variation": 10 + (hash(id) % 20)})
	# A full wardrobe, hood and all: faceless staff, where Hollis is the one
	# man whose face you have to remember.
	rig.dress(ClothingShell.fresh_wardrobe())
	loadout = LOADOUT.new(subject_id)
	loadout.attach_to(rig)
	muzzle = OmniLight3D.new()
	muzzle.light_color = Color("ffb35a")
	muzzle.light_energy = 0.0
	muzzle.omni_range = 5.0
	muzzle.visible = false
	muzzle.position = Vector3(0.3, 1.25, -0.5)
	add_child(muzzle)
	speech = Label3D.new()
	speech.font_size = 26
	speech.outline_size = 8
	speech.modulate = Color("f2e2c4")
	speech.outline_modulate = Color("120606")
	speech.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	speech.position = Vector3(0, 2.2, 0)
	add_child(speech)
	var record := WorldHistory.subject(subject_id)
	var saved: Dictionary = record.get("anatomy_state", {})
	if not saved.is_empty():
		rig.anatomy.restore(saved)
	if is_down():
		_fall()
	elif reinforcement:
		state = "hunt"


func is_down() -> bool:
	return rig == null or rig.anatomy.downed or rig.anatomy.dead


## The alarm reached this guard.
func alert(at: Vector3) -> void:
	if is_down():
		return
	alerted = true
	certainty = 1.0
	investigate_at = at
	state = "hunt"
	_say("CONTAINMENT BREACH. WEAPONS FREE.", 1.8)


## Something loud or strange drew him: go and look.
func distract(by: Node3D, seconds := 8.0) -> void:
	if is_down():
		return
	distraction = by
	distraction_left = seconds
	if state == "patrol":
		state = "investigate"
	_say("WHAT IS THAT. STAY WHERE YOU ARE.", 1.6)


func hear(at: Vector3) -> void:
	if is_down() or state == "hunt":
		return
	investigate_at = at
	state = "investigate"


func head_position() -> Vector3:
	var anchor: Node3D = rig.get("head_anchor") as Node3D
	return anchor.global_position if anchor != null else global_position + Vector3(0, 1.6, 0)


func facing() -> Vector3:
	return -global_transform.basis.z


## Whether he can see `point` from his eyes, the way the cameras check it.
func can_see(point: Vector3, body: Object, crouched := false) -> bool:
	if is_down():
		return false
	var eye := head_position()
	var to := point - eye
	var reach := SIGHT_CROUCHED if crouched else SIGHT
	if Vector2(to.x, to.z).length() > reach:
		return false
	if Vector3(to.x, 0, to.z).angle_to(Vector3(facing().x, 0, facing().z)) > SIGHT_HALF_ANGLE and state != "hunt":
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, point)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == body


func step(delta: float, player: CharacterBody3D, crouched: bool) -> void:
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	muzzle.light_energy = move_toward(muzzle.light_energy, 0.0, delta * 30.0)
	muzzle.visible = muzzle.light_energy > 0.01
	speech_timer = maxf(0.0, speech_timer - delta)
	if speech_timer <= 0.0:
		speech.text = ""
	if is_down():
		return
	var chest := player.global_position + Vector3(0, 0.35, 0)
	var sees := can_see(chest, player, crouched)
	if state != "hunt":
		if sees:
			var close := 1.0 + clampf(1.0 - _flat(chest - global_position).length() / SIGHT, 0.0, 1.0) * 1.5
			_sight += delta * close
			certainty = clampf(_sight / SPOT_SECONDS, 0.0, 1.0)
			director.raise(delta * 0.45 * close, "guard_glimpse", player.global_position)
			investigate_at = player.global_position
			if state == "patrol":
				state = "investigate"
				_say("HEY. WHO'S THERE.", 1.4)
			if _sight >= SPOT_SECONDS:
				WorldHistory.record_event("support_guard_spotted_player", {"subject_id": subject_id})
				director.trip("guard_saw_you", player.global_position)
		else:
			_sight = maxf(0.0, _sight - delta * 0.5)
			certainty = clampf(_sight / SPOT_SECONDS, 0.0, 1.0)
	distraction_left = maxf(0.0, distraction_left - delta)
	if distraction != null and (distraction_left <= 0.0 or not is_instance_valid(distraction) or _target_down(distraction)):
		distraction = null
	match state:
		"patrol":
			if not route.is_empty():
				var target := route[route_index]
				if _flat(target - global_position).length() < 0.5:
					route_index = (route_index + 1) % route.size()
				_walk(target, WALK, delta)
			if director.level == "suspicious":
				state = "investigate"
				investigate_at = director.alarm_at
		"investigate":
			var goal := distraction.global_position if distraction != null else investigate_at
			if _flat(goal - global_position).length() > 1.4:
				_walk(goal, WALK * 1.5, delta)
			elif distraction == null and director.level == "calm":
				state = "patrol"
		"hunt":
			var target_node: Node3D = distraction if distraction != null else player
			var goal := target_node.global_position
			var distance := _flat(goal - global_position).length()
			var visible := sees if target_node == player else distance < FIRE_RANGE
			if distance > FIRE_RANGE - 1.0 or not visible:
				_walk(goal, RUN, delta)
			elif distance > KEEP_OFF:
				_walk(goal, WALK, delta)
			else:
				_face(goal)
			if visible and distance <= FIRE_RANGE and fire_cooldown <= 0.0:
				_fire(target_node)
	_animate(delta)


func _fire(target: Node3D) -> void:
	fire_cooldown = FIRE_COOLDOWN + _rng.randf() * 0.4
	muzzle.light_energy = 9.0
	muzzle.visible = true
	shots_fired += 1
	_face(target.global_position)
	var landed := _rng.randf() < HIT_CHANCE
	WorldHistory.record_event("support_guard_fired", {"subject_id": subject_id, "at": str(target.name), "landed": landed})
	if landed:
		shot.emit(target, SHOT_DAMAGE)


## A blow from the player or a bingyanger. Same anatomy as anyone.
func take_hit(damage: float, direction: Vector3, kind := "blunt", by := "player") -> Dictionary:
	if rig == null or rig.anatomy.dead:
		return {}
	var result: Dictionary = rig.hit("torso", damage, 10.0, kind, "", direction.normalized())
	WorldHistory.amend_subject(subject_id, {"anatomy_state": rig.anatomy.snapshot()})
	if is_down():
		_fall()
		WorldHistory.update_subject(subject_id, {
			"status": "dead" if rig.anatomy.dead else "down",
			"downed_by": by,
		}, "support_guard_downed")
	elif director != null:
		# A guard who takes a blow and stays up calls it in.
		director.trip("guard_struck", global_position)
	return result


func _fall() -> void:
	state = "down"
	alerted = false
	rig.rotation.x = -PI * 0.46
	speech.text = ""


func _target_down(node: Node3D) -> bool:
	return node.has_method("is_down") and bool(node.call("is_down"))


func _walk(goal: Vector3, speed: float, delta: float) -> void:
	var to := _flat(goal - global_position)
	if to.length() < 0.05:
		return
	var step_length := minf(speed * delta, to.length())
	global_position += to.normalized() * step_length
	global_position.x = clampf(global_position.x, -LANE_HALF_WIDTH, LANE_HALF_WIDTH)
	_pace += step_length
	_face(goal)


func _face(goal: Vector3) -> void:
	var to := _flat(goal - global_position)
	if to.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 0.25)


## No walk cycle on the rig yet: a bob and a sway so a moving guard reads as
## walking, not sliding.
func _animate(_delta: float) -> void:
	rig.position.y = absf(sin(_pace * 2.4)) * 0.05
	rig.rotation.z = sin(_pace * 2.4) * 0.03


func _say(text: String, seconds := 2.0) -> void:
	speech.text = text
	speech_timer = seconds


func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)
