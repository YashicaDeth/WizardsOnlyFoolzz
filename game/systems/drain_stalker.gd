class_name DrainStalker
extends Node3D

## The threat in the old drains (Greg, 24 September): "something that hunts
## you", and it is "a bingyanger, freed long ago": an escapee from an earlier
## cycle, always hostile, living down here. It is what makes the second way out
## cost something, the way the sentinel does on the lift route.
##
## It hunts by sound, because it has lived in the dark for longer than the
## player has been alive:
##
## - **Running is loud**, walking is heard close up, and creeping (crouch) or
##   standing still is nearly silent. It goes to where it last heard you.
## - **Slipping it** is going quiet until it loses the trail, or discharging
##   the breach tool into it, which stuns it the way it interrupts the
##   sentinel.
## - **If it reaches you it tears at you:** blood, the same currency as the
##   sentinel, and no floor any more (Greg, 24 September): it can kill you, and
##   the vat of whoever claims you grows you back.
##
## Everything it does is filed in `WorldHistory`, and it talks: the lines are
## horror, funny-insane and prophetic, per Greg, spoken in the game's generated
## voice (`NPCSpeechOutput`) and shown over its head.

const BODY := preload("res://systems/baseline_human.gd")

signal struck(damage: float)
signal said(line: String)

const SUBJECT_ID := "drain_bingyanger"
const HEAR_RUNNING := 17.0
const HEAR_WALKING := 7.5
const HEAR_CREEPING := 2.2
const LOSES_TRAIL_AFTER := 6.0
const HUNT_SPEED := 2.6
const PROWL_SPEED := 0.9
const REACH := 1.5
const STRIKE_BLOOD := 8.0
const STRIKE_COOLDOWN := 1.5
const BLOOD_FLOOR := 0.0
const STUN_SECONDS := 9.0
const BREACH_RANGE := 7.0

## Greg's three registers. Placeholder writing, his to replace.
const LINES := {
	"heard": [
		"THERE YOU ARE. THERE YOU ARE. THERE YOU ARE.",
		"I HEAR YOUR WET LITTLE FEET.",
		"THE WATER TOLD ME YOU WERE COMING. THE WATER TELLS ME EVERYTHING.",
	],
	"lost": [
		"GONE. GONE LIKE THE LAST ONE. HE WAS DELICIOUS.",
		"NO NO NO. COME BACK. I WAS BEING NICE.",
		"QUIET ONES LIVE LONGER. I WAS A QUIET ONE ONCE.",
	],
	"strike": [
		"HOLD STILL, I ONLY WANT A LITTLE.",
		"YOU'RE SO WARM. WHY ARE YOU SO WARM.",
		"THEY GREW YOU TOO FAST. I CAN TASTE IT.",
	],
	"prowl": [
		"CYCLE ELEVEN. CYCLE ELEVEN. NOBODY CAME FOR CYCLE ELEVEN.",
		"THE MAN IN THE COAT IS NOT A MAN. ASK HIM TO SHAKE YOUR HAND.",
		"THE SUFFERING ENDS WHEN THE LAST VAT IS DRY. I DRANK MINE.",
		"I USED TO HAVE A NUMBER. NOW I HAVE TEETH.",
	],
	"stunned": [
		"OW. OW. THAT WAS RUDE. THAT WAS VERY RUDE.",
		"LIGHTNING IN A BOX. THEY HAD THAT IN MY CYCLE TOO.",
	],
}

var player: Node3D
var blood := 100.0
var state := "prowl"
var heard_at := Vector3.ZERO
var since_heard := 999.0
var stunned_for := 0.0
var patrol: Array[Vector3] = []
var patrol_index := 0
var rig: Node3D
var voice
var _cooldown := 0.0
var _label: Label3D
var _line_life := 0.0
var _mutter_in := 6.0
var _rng := RandomNumberGenerator.new()


func build(patrol_points: Array[Vector3]) -> void:
	_rng.seed = hash(SUBJECT_ID)
	patrol = patrol_points
	if not patrol.is_empty():
		position = patrol[0]
	WorldHistory.register_subject(SUBJECT_ID, {
		"name": "BINGYANGER, CYCLE UNKNOWN", "kind": "person", "role": "Escapee in the old drains",
		"faction": "none", "status": "loose", "condition": "bingyang", "attitude": "hostile",
		"memory": "Freed long before you, by a cycle nobody recorded. Lives in the drains and hunts by sound.",
	})
	rig = BODY.new()
	rig.name = "Body"
	# Ghoul skin: cooked, peeled, wasted.
	rig.build(SUBJECT_ID, {"variation": 7, "flesh": Color("6e3a2c"), "build": 0.78})
	# Hunched low to the water, the way something that has been down here for
	# years moves.
	rig.rotation.x = 0.35
	add_child(rig)
	_add_growths()
	_label = Label3D.new()
	_label.position = Vector3(0, 2.25, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 26
	_label.pixel_size = 0.004
	_label.outline_size = 8
	_label.modulate = Color("d9c49a")
	_label.width = 520.0
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_label)
	voice = NPCSpeechOutput.make("en_AU", self)


func bind(target: Node3D) -> void:
	player = target


## Growths: tumours and a fused second jaw, placed on the rig's own parts so
## they move with it.
func _add_growths() -> void:
	var parts: Dictionary = rig.get("parts")
	for zone in ["head", "torso", "left_arm", "right_leg"]:
		var part := parts.get(zone) as Node3D
		if part == null:
			continue
		for index in 2:
			var lump := MeshInstance3D.new()
			var mesh := SphereMesh.new()
			mesh.radius = 0.06 + _rng.randf() * 0.07
			mesh.height = mesh.radius * 1.7
			mesh.material = WorldLook.surface(Color("7a4a3a"), "flesh", 900 + index)
			lump.mesh = mesh
			lump.position = part.position + Vector3(_rng.randf_range(-0.15, 0.15), _rng.randf_range(-0.12, 0.12), _rng.randf_range(0.05, 0.14))
			rig.add_child(lump)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_line_life = maxf(0.0, _line_life - delta)
	_label.modulate.a = clampf(_line_life, 0.0, 1.0)
	if stunned_for > 0.0:
		stunned_for -= delta
		rig.rotation.z = sin(stunned_for * 9.0) * 0.2
		if stunned_for <= 0.0:
			rig.rotation.z = 0.0
			state = "prowl"
		return
	_listen(delta)
	match state:
		"hunt":
			_move_toward(heard_at, HUNT_SPEED, delta)
			if since_heard > LOSES_TRAIL_AFTER:
				state = "prowl"
				_say("lost")
				WorldHistory.record_event("drain_bingyanger_lost_you", {"subject_id": SUBJECT_ID})
		"prowl":
			if not patrol.is_empty():
				var target := patrol[patrol_index]
				if _flat(target - global_position).length() < 0.6:
					patrol_index = (patrol_index + 1) % patrol.size()
				_move_toward(target, PROWL_SPEED, delta)
			_mutter_in -= delta
			if _mutter_in <= 0.0:
				_mutter_in = 7.0 + _rng.randf() * 6.0
				if _flat(player.global_position - global_position).length() < 14.0:
					_say("prowl")
	_try_strike()


## How loud the player is right now, as a hearing radius.
func noise_radius() -> float:
	var body := player as CharacterBody3D
	var speed := Vector2(body.velocity.x, body.velocity.z).length() if body != null else 0.0
	if speed < 0.4:
		return 0.0
	if Input.is_action_pressed("crouch"):
		return HEAR_CREEPING
	if Input.is_action_pressed("sprint") or speed > 4.2:
		return HEAR_RUNNING
	return HEAR_WALKING


func _listen(delta: float) -> void:
	since_heard += delta
	var distance := _flat(player.global_position - global_position).length()
	if distance <= noise_radius():
		heard_at = player.global_position
		since_heard = 0.0
		if state != "hunt":
			state = "hunt"
			_say("heard")
			WorldHistory.record_event("drain_bingyanger_heard_you", {"subject_id": SUBJECT_ID, "distance": snappedf(distance, 0.1)})


func _try_strike() -> void:
	var distance := _flat(player.global_position - global_position).length()
	if distance > REACH or _cooldown > 0.0:
		return
	_cooldown = STRIKE_COOLDOWN
	var before := blood
	blood = maxf(BLOOD_FLOOR, blood - STRIKE_BLOOD)
	state = "hunt"
	heard_at = player.global_position
	since_heard = 0.0
	_say("strike")
	WorldHistory.record_event("drain_bingyanger_strike", {"subject_id": SUBJECT_ID, "damage": before - blood})
	struck.emit(before - blood)


## The breach tool: a discharge into it at close range stuns it long enough
## to get past. Returns true if it landed.
func discharge(from: Vector3) -> bool:
	if stunned_for > 0.0 or _flat(global_position - from).length() > BREACH_RANGE:
		return false
	stunned_for = STUN_SECONDS
	state = "stunned"
	_say("stunned")
	WorldHistory.record_event("drain_bingyanger_stunned", {"subject_id": SUBJECT_ID})
	return true


func _move_toward(target: Vector3, speed: float, delta: float) -> void:
	var to := _flat(target - global_position)
	if to.length() < 0.05:
		return
	global_position += to.normalized() * minf(speed * delta, to.length())
	rotation.y = atan2(-to.x, -to.z)


func _say(kind: String) -> void:
	var pool: Array = LINES.get(kind, [])
	if pool.is_empty():
		return
	var line := str(pool[_rng.randi() % pool.size()])
	_label.text = line
	_line_life = 3.2
	if voice != null:
		voice.speak(line.to_lower())
	said.emit(line)


func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)
