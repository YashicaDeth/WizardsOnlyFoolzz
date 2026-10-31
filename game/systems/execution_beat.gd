class_name ExecutionBeat
extends Node

## Fix-58. Finishing someone who is on the floor, as one short beat that always
## ends with them dead.
##
## Greg (5 Oct): "when someone is downed the execution is still super bugged".
## Every place that could finish a downed body did it differently or not at all:
## the Hunt killed on the menu press with the player wherever they stood and the
## body still tipped on its feet; the mechanics lab had no verb (a downed
## sparring partner lay there until it was deleted, even with a hand inside it);
## the Service Arcade's downed guard could only be dragged to the reader. This
## is the one beat they all call.
##
## The beat, on the real clock so hitstop and the kill cam cannot stall it:
##   close  the attacker steps to the body at the weapon's distance, facing it
##   wind   the blow is drawn back (hosts pose their held model off `wind()`)
##   strike the lethal blow lands on the body, through the body's own anatomy
##   hold   a moment over the corpse while the ragdoll takes it
## and then `finished`. A body freed, already dead or out of the tree mid-beat
## ends it at once, and `DEADLINE` ends it whatever else happens, so a host that
## gates its input on `active` can never be left locked.
##
## The organ rip from lab-48 is one of the finishers: if the body is already
## open (`OrganSystem.rip_refusal` is empty for its heart) the hand goes in
## through that wound and the heart comes out. Without a wound it never does;
## the held weapon finishes them instead.

signal landed(report: Dictionary)
signal finished(report: Dictionary)

const CLOSE := 0.2
const WIND := 0.24
const HOLD := 0.5
## Real seconds. Nothing is allowed to keep a beat open longer than this.
const DEADLINE := 2.0

## How each held weapon ends it. `stand` is metres from the body's centre;
## `damage` is chosen against the anatomy: every one is past what the organ it
## names can take, and the sidearm's stays under `SkullBurst.CRANIUM_THRESHOLD`
## so a point-blank round is a hole in a head, not the rifle's blowout.
const STYLES := {
	"cleaver": {"stand": 0.95, "zone": "head", "organ": "brain", "damage": 60.0, "impulse": 22.0,
		"damage_type": "shear", "method": "behead", "verb": "CLEAVED", "kick": 0.09},
	"staff": {"stand": 1.35, "zone": "torso", "organ": "heart", "damage": 70.0, "impulse": 34.0,
		"damage_type": "puncture", "shock": true, "method": "executed", "verb": "SPITTED", "kick": 0.07},
	"sidearm": {"stand": 1.25, "zone": "head", "organ": "brain", "damage": 30.0, "impulse": 18.0,
		"damage_type": "ballistic", "method": "executed", "verb": "SHOT", "kick": 0.06},
	"ram": {"stand": 1.1, "zone": "head", "organ": "brain", "damage": 80.0, "impulse": 40.0,
		"damage_type": "blunt", "method": "executed", "verb": "CAVED IN", "kick": 0.1},
	"rip": {"stand": 0.75, "zone": "torso", "organ": "heart", "damage": 0.0, "impulse": 6.0,
		"damage_type": "cut", "method": "organ_ripped", "verb": "HEART TAKEN", "kick": 0.05},
	"": {"stand": 1.0, "zone": "torso", "organ": "heart", "damage": 100.0, "impulse": 30.0,
		"damage_type": "puncture", "method": "executed", "verb": "EXECUTED", "kick": 0.06},
}

var active := false
var phase := ""
var clock := 0.0
var style_id := ""
var victim: BaselineHuman
var attacker: Node3D
var report: Dictionary = {}
## Where the attacker stands and which way they face, for hosts that own their
## own yaw (the lab and the Hunt rebuild the view from it every frame).
var stand_at := Vector3.ZERO
var view_yaw := 0.0
var _from := Vector3.ZERO
var _zone := "torso"
var _organ := "heart"
var _style: Dictionary = {}


## Which finisher this body gets with this weapon: the rip if a hand can get
## to the heart through a wound already made, otherwise the weapon's own.
static func style_for(rig: BaselineHuman, weapon_id: String) -> String:
	if rig != null and is_instance_valid(rig) and OrganSystem.rip_refusal(rig, "heart") == "":
		return "rip"
	return weapon_id if STYLES.has(weapon_id) else ""


## Start the beat. `finish` overrides the zone/organ for the generic style (the
## Hunt finishes the wound that dropped them). False when there is nothing to
## finish: no body, not downed, or a beat already running.
func begin(owner_body: Node3D, rig: BaselineHuman, weapon_id: String, finish: Array = []) -> bool:
	if active or rig == null or not is_instance_valid(rig) or not rig.is_inside_tree():
		return false
	if not rig.is_downed():
		return false
	victim = rig
	attacker = owner_body
	style_id = style_for(rig, weapon_id)
	_style = STYLES[style_id]
	_zone = str(_style.zone)
	_organ = str(_style.organ)
	if style_id == "" and finish.size() >= 2:
		_zone = str(finish[0])
		_organ = str(finish[1])
	var target := _target_point()
	_from = attacker.global_position if attacker != null and is_instance_valid(attacker) else target
	var away := _from - target
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3(0, 0, 1)
	stand_at = target + away.normalized() * float(_style.stand)
	stand_at.y = _from.y
	var toward := target - stand_at
	view_yaw = atan2(-toward.x, -toward.z)
	report = {"style": style_id, "weapon": weapon_id, "zone": _zone, "organ": _organ,
		"verb": str(_style.verb), "subject_id": str(rig.anatomy.subject_id), "dead": false}
	active = true
	phase = "close"
	clock = 0.0
	set_process(true)
	return true


## 0..1 while the blow is drawn back, 1 at the strike, 0 otherwise.
func wind() -> float:
	if phase == "wind":
		return clampf(clock / WIND, 0.0, 1.0)
	return 1.0 if phase == "hold" and clock < 0.08 else 0.0


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	if not active:
		return
	# Real time: hitstop and the kill cam both lower Engine.time_scale.
	step(delta / maxf(Engine.time_scale, 0.001))


## One step of the beat in real seconds. Public so a test can drive it.
func step(real_delta: float) -> void:
	if not active:
		return
	clock += real_delta
	report["elapsed"] = float(report.get("elapsed", 0.0)) + real_delta
	if victim == null or not is_instance_valid(victim) or not victim.is_inside_tree():
		_end("victim_gone")
		return
	if float(report.elapsed) >= DEADLINE:
		if not bool(report.dead):
			_strike()
		_end("deadline")
		return
	match phase:
		"close":
			_place(clampf(clock / CLOSE, 0.0, 1.0))
			if clock >= CLOSE:
				phase = "wind"
				clock = 0.0
		"wind":
			_place(1.0)
			if victim.anatomy.dead:
				# Bled out or killed by somebody else while we drew back.
				report["dead"] = true
				_end("died_first")
				return
			if clock >= WIND:
				_strike()
				phase = "hold"
				clock = 0.0
		"hold":
			if clock >= HOLD:
				_end("done")


## Runs the rest of the beat at once: the blow if it has not landed, then the
## end. For a host leaving the scene, and for tests that check the record.
func complete_now() -> void:
	if not active:
		return
	if victim == null or not is_instance_valid(victim) or not victim.is_inside_tree():
		_end("victim_gone")
		return
	_place(1.0)
	if phase != "hold" and not victim.anatomy.dead:
		_strike()
	_end("done")


func cancel() -> void:
	if active:
		_end("cancelled")


func _place(t: float) -> void:
	if attacker == null or not is_instance_valid(attacker):
		return
	var eased := 1.0 - pow(1.0 - t, 3.0)
	attacker.global_position = _from.lerp(stand_at, eased)
	if attacker is CharacterBody3D:
		(attacker as CharacterBody3D).velocity = Vector3.ZERO


func _target_point() -> Vector3:
	var part := victim.parts.get(_zone) as Node3D
	if part != null and is_instance_valid(part):
		return part.global_position
	return victim.global_position


## The blow. Goes through the rig's own `hit()` so wounds, blood, organs and the
## ragdoll's fall direction are the real ones, then makes sure of it: a downed
## body that somehow survives the blow is finished by the same method, so the
## beat can never leave somebody alive under a corpse's label.
func _strike() -> void:
	var direction := _target_point() - stand_at
	direction.y = minf(direction.y, 0.0) - 0.35
	direction = direction.normalized()
	if style_id == "rip":
		# The body goes the way the hand pulled: set before the heart comes out,
		# because that is the moment it dies and the ragdoll reads the last hit.
		victim.hit("torso", 1.0, float(_style.impulse), "cut", "", -direction)
		var session := OrganSystem.begin_rip(victim, "heart")
		if not session.is_empty():
			session.progress = 1.0
			session.complete = true
			report["taken"] = OrganSystem.finish_rip(session)
	else:
		var result := victim.hit(_zone, float(_style.damage), float(_style.impulse), str(_style.damage_type), _organ, direction)
		report["hit"] = result
		if bool(_style.get("shock", false)):
			report["shorted"] = OrganSystem.shock_rig(victim, 1.0)
		OrganSystem.after_hit(victim, result, direction, str(_style.damage_type))
	if not victim.anatomy.dead:
		victim.execute(str(_style.method))
	elif str(_style.method) == "behead":
		victim.behead()
	report["dead"] = victim.anatomy.dead
	report["at"] = _target_point()
	report["direction"] = direction
	landed.emit(report)


func _end(reason: String) -> void:
	active = false
	phase = ""
	report["reason"] = reason
	if victim != null and is_instance_valid(victim):
		report["dead"] = victim.anatomy.dead
	set_process(false)
	finished.emit(report)
