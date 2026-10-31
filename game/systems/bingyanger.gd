class_name Bingyanger
extends Node3D

## A bingyanga held in the Support Unit, and the bingyanger it becomes when the
## player lets it out (Greg, 24 September; the rules are `DESIGN/BINGYANG.md`):
##
## - **Held**, it is restrained in its cell and cannot help itself. It pleads.
## - **The player frees it.** `release()` is the only way out.
## - **Attitude re-rolls every meeting.** Walk away far enough for long enough
##   and the next time you come close is a new meeting, rolled fresh.
## - **Friendly**, it does one of: fights beside you (goes for the nearest
##   guard), gives you something (a round, an organ, junk), tells you something
##   (crazy talk that is sometimes true: where a camera looks, who holds the
##   last door), or distracts the guards.
## - **Hostile**, it does one of: attacks you, screams until the guards come,
##   steals something you carry and runs, or stalks you at a distance and
##   taunts.
## - **It dies like anyone**: the same `BaselineHuman` anatomy, guards can shoot
##   it, you can kill it, and the world records it.
## - **Its lines** are horror, funny-insane and prophetic, spoken in the game's
##   generated voice (`NPCSpeechOutput`) and shown over its head.
##
## Each one rolls its own body from its seed: ghoul skin, growths, fused parts,
## an extra limb, unfinished and half-grown. Everything it does is filed in
## `WorldHistory`; only its mood is rolled fresh.
##
## What the Support Unit does to them, beyond restraint and "torture", is still
## Greg's to say; nothing here shows a procedure.

signal struck_player(damage: float)
signal took_item(label: String)
signal gave_item(label: String)
signal said(line: String)

const BODY := preload("res://systems/baseline_human.gd")
const CARRY := preload("res://systems/carry.gd")

const FRIENDLY_ACTS := ["fight", "give", "tell", "distract"]
const HOSTILE_ACTS := ["attack", "scream", "steal", "stalk"]
## A meeting is over once the player has been this far off for this long.
const APART_DISTANCE := 12.0
const APART_SECONDS := 6.0
const MEET_DISTANCE := 4.5
const WALK := 1.6
const RUN := 3.4
const REACH := 1.5
const STRIKE_COOLDOWN := 1.4
const PLAYER_STRIKE := 7.0
const GUARD_STRIKE := 24.0
const STALK_DISTANCE := 7.0
## Greg's list of things a friendly one hands over. The key card waits until
## there is a door in the Unit it opens.
const GIFTS := [
	{"label": "A LOOSE ROUND", "kind": "ammo", "mass": 0.02},
	{"label": "AN ORGAN IN A SURGICAL GLOVE", "kind": "organ", "mass": 0.4},
	{"label": "A TOOTH ON A STRING", "kind": "junk", "mass": 0.01},
	{"label": "HALF A NAME TAG", "kind": "junk", "mass": 0.01},
]

## Greg's three registers. Placeholder writing, his to replace.
const LINES := {
	"held": [
		"PLEASE. PLEASE. NOT THE BRIGHT ROOM AGAIN.",
		"I CAN'T FEEL MY OTHER HANDS.",
		"OUR FATHER WHO ART IN THE VAT. OUR FATHER WHO ART IN THE VAT.",
		"LET ME OUT LET ME OUT I'LL BE GOOD I'LL BE SO GOOD.",
	],
	"freed_friendly": [
		"OUT! I'M OUT! I'M GOING TO EAT A WHOLE CHAIR!",
		"YOU OPENED IT. NOBODY OPENS IT. ARE YOU GOD? YOU'RE SHORTER THAN GOD.",
	],
	"freed_hostile": [
		"YOU LET ME OUT. BIG MISTAKE, LITTLE BROTHER.",
		"FREE. FREE TO DO WHAT THEY DID TO ME.",
	],
	"fight": [
		"THAT ONE. THAT ONE HELD THE STRAPS.",
		"I'LL HOLD HIM, YOU HOLD THE REST OF HIM.",
	],
	"give": [
		"HERE. I KEPT IT WARM FOR YOU. DON'T ASK WHERE.",
		"A PRESENT. IT WAS INSIDE ME. NOW IT'S INSIDE YOU. SPIRITUALLY.",
	],
	"distract": [
		"HEY! HEY, MEAT BOYS! LOOK AT MY EXTRA ELBOW!",
		"OVER HERE! I'M THE PROBLEM! I'VE ALWAYS BEEN THE PROBLEM!",
	],
	"attack": [
		"YOU SMELL LIKE THE VAT. I HATE THE VAT.",
		"HOLD STILL. I'M FIXING YOU.",
	],
	"scream": [
		"HEEEERE! IT'S HEEEERE! THE NEW ONE IS HEEEERE!",
		"GUARDS! GUARDS! I'M TELLING! I'M TELLING ON YOU!",
	],
	"steal": [
		"MINE NOW. FINDERS KEEPERS, LOSERS WEEPERS.",
		"SHINY. SHINY SHINY SHINY.",
	],
	"stalk": [
		"I CAN SEE THE BACK OF YOUR HEAD. IT'S A NICE HEAD.",
		"THEY'LL GROW YOU BACK. THEY GREW ME BACK FOUR TIMES.",
		"KEEP WALKING. I'LL KEEP WALKING.",
	],
	"prophecy": [
		"CELLOUTZ OWNS THE MEAT, BUT THE GODHEAD OWNS THE DEBT.",
		"THE LAST VAT IS DRY. WHEN IT FILLS, WE ALL COME HOME.",
		"THE DOCTOR ISN'T THERE. THE DOCTOR WAS NEVER THERE.",
	],
	"struck": [
		"OW. OKAY. OKAY. I DESERVED THAT ONE.",
		"NOT THE FACE. I'M STILL GROWING THE FACE.",
	],
	"dying": [
		"FINALLY. FINALLY IT'S QUIET.",
		"TELL THE VAT I SAID NO.",
	],
}

var subject_id := ""
var rig: Node3D
var voice
var player: Node3D
var director: AlarmDirector
var guards: Array = []
## True things a friendly one might say, filled in by the host (where a camera
## looks, who holds the last door). Mixed with prophecy.
var hints: Array[String] = []
var state := "held"
var attitude := ""
var act := ""
var meetings := 0
var met := false
var holding := ""
var home := Vector3.ZERO
var alerted := false
var certainty := 1.0
var mutations: Array[String] = []
var _apart := 0.0
var _cooldown := 0.0
var _act_done := false
var _scream_left := 0.0
var _taunt_in := 0.0
var _label: Label3D
var _line_life := 0.0
var _mutter_in := 3.0
var _clock := 0.0
var _pace := 0.0
var _rng := RandomNumberGenerator.new()


func build(id: String, seed_value: int, held := true) -> void:
	subject_id = id
	_rng.seed = seed_value
	home = position
	WorldHistory.register_subject(subject_id, {
		"name": "BINGYANGA", "kind": "person", "faction": "none", "condition": "bingyang",
		"role": "Held in the Mental and Physical Support Unit", "status": "held",
		"place": "support_unit", "meetings": 0, "attitude": "",
		"memory": "A vat subject that came out wrong, moved into the Support Unit and kept there.",
	})
	var record := WorldHistory.subject(subject_id)
	meetings = int(record.get("meetings", 0))
	holding = str(record.get("holding", ""))
	rig = BODY.new()
	rig.name = "Body"
	add_child(rig)
	_roll_body(seed_value)
	_label = Label3D.new()
	_label.position = Vector3(0, 2.3, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 26
	_label.pixel_size = 0.004
	_label.outline_size = 8
	_label.modulate = Color("d9c49a")
	_label.outline_modulate = Color("100604")
	_label.width = 560.0
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_label)
	voice = NPCSpeechOutput.make("en_AU", self)
	# Pitched per bingyanger (DESIGN/BINGYANG.md): the same pipeline as the
	# examiner, bent differently for each one.
	var bend := 0.62 + _rng.randf() * 0.7
	if voice != null and voice.get("pitch") != null:
		voice.set("pitch", bend)
	if voice != null and voice.get("player") is AudioStreamPlayer:
		(voice.get("player") as AudioStreamPlayer).pitch_scale = bend
	var status := str(record.get("status", "held"))
	if status == "dead":
		state = "dead"
		rig.anatomy.dead = true
		rig.rotation.x = -PI * 0.46
	elif status == "loose" or not held:
		state = "loose"
	else:
		state = "held"
		_restrain()


## Each one different (Greg): its own mix of ghoul skin, growths, fused parts,
## an extra limb, and a body that was never finished.
func _roll_body(seed_value: int) -> void:
	var ghoul := _rng.randf() < 0.7
	var half_grown := _rng.randf() < 0.4
	var flesh := Color("6e3a2c").lerp(Color("8a6a4c"), _rng.randf()) if ghoul else Color("7a6450")
	rig.build(subject_id, {"variation": 30 + seed_value % 40, "flesh": flesh, "build": 0.74 if half_grown else 0.9})
	if ghoul:
		mutations.append("ghoul_skin")
	if half_grown:
		mutations.append("half_grown")
	var parts: Dictionary = rig.get("parts")
	# Growths: tumours on the body's own parts, so they move with it.
	var lumps := 2 + _rng.randi() % 4
	mutations.append("growths")
	var zones := ["head", "torso", "left_arm", "right_arm", "left_leg", "right_leg"]
	for index in lumps:
		var part := parts.get(zones[_rng.randi() % zones.size()]) as Node3D
		if part == null:
			continue
		var lump := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.05 + _rng.randf() * 0.09
		mesh.height = mesh.radius * (1.4 + _rng.randf() * 0.6)
		mesh.material = WorldLook.surface(flesh.lerp(Color("9a5a4a"), 0.4), "flesh", 950 + index)
		lump.mesh = mesh
		lump.position = part.position + Vector3(_rng.randf_range(-0.14, 0.14), _rng.randf_range(-0.12, 0.12), _rng.randf_range(-0.14, 0.14))
		rig.add_child(lump)
	# Fused: the head grown down into a shoulder.
	if _rng.randf() < 0.45 and parts.has("head") and parts.has("torso"):
		mutations.append("fused")
		var bridge := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.09
		capsule.height = 0.42
		capsule.material = WorldLook.surface(flesh.darkened(0.15), "flesh", 971)
		bridge.mesh = capsule
		var head := parts.head as Node3D
		var torso := parts.torso as Node3D
		bridge.position = head.position.lerp(torso.position, 0.5) + Vector3(0.14, 0, 0)
		bridge.rotation.z = 0.6
		rig.add_child(bridge)
	# An extra limb: a thin third arm out of the side of the chest.
	if _rng.randf() < 0.5 and parts.has("torso"):
		mutations.append("extra_limb")
		var limb := MeshInstance3D.new()
		var arm := CapsuleMesh.new()
		arm.radius = 0.045
		arm.height = 0.62
		arm.material = WorldLook.surface(flesh.lightened(0.05), "flesh", 983)
		limb.mesh = arm
		limb.position = (parts.torso as Node3D).position + Vector3(-0.22, -0.05, 0.08)
		limb.rotation = Vector3(0.5, 0, -0.9)
		rig.add_child(limb)


func _restrain() -> void:
	# Strapped upright to the frame at the back of the cell, head lolled.
	rig.rotation.x = 0.12


func is_down() -> bool:
	return state == "dead" or rig == null or rig.anatomy.downed or rig.anatomy.dead


func bind(target: Node3D, alarm: AlarmDirector, guard_list: Array) -> void:
	player = target
	director = alarm
	guards = guard_list


## The cell is open. Only the player does this.
func release(method := "cell_broken") -> void:
	if state != "held":
		return
	state = "loose"
	rig.rotation = Vector3.ZERO
	WorldHistory.update_subject(subject_id, {
		"name": "BINGYANGER", "status": "loose", "freed_by": "player",
		"role": "Broken out of the Support Unit",
	}, "bingyanga_freed")
	WorldHistory.record_event("bingyanga_released", {"subject_id": subject_id, "method": method, "mutations": mutations})
	meet()
	_say("freed_friendly" if attitude == "friendly" else "freed_hostile")


## A meeting: the attitude is rolled fresh, and it picks what to do about you.
## Tests and captures may force either.
func meet(forced_attitude := "", forced_act := "") -> void:
	if is_down():
		return
	meetings += 1
	met = true
	_apart = 0.0
	_act_done = false
	attitude = forced_attitude if not forced_attitude.is_empty() else ("friendly" if _rng.randf() < 0.5 else "hostile")
	var acts: Array = FRIENDLY_ACTS if attitude == "friendly" else HOSTILE_ACTS
	act = forced_act if not forced_act.is_empty() else str(acts[_rng.randi() % acts.size()])
	# Nothing to steal is a stalk instead.
	if act == "steal" and CARRY.new().items.is_empty():
		act = "stalk"
	WorldHistory.amend_subject(subject_id, {"meetings": meetings, "attitude": attitude, "last_act": act})
	WorldHistory.record_event("bingyanger_met", {"subject_id": subject_id, "meeting": meetings, "attitude": attitude, "act": act})
	_taunt_in = 1.5


func _process(delta: float) -> void:
	_clock += delta
	_line_life = maxf(0.0, _line_life - delta)
	_label.modulate.a = clampf(_line_life, 0.0, 1.0)


func step(delta: float) -> void:
	if player == null or is_down():
		if state != "dead" and rig != null and (rig.anatomy.downed or rig.anatomy.dead):
			_die("bled out")
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	var distance := _flat(player.global_position - global_position).length()
	if state == "held":
		# Twitching against the straps, and pleading when you are near.
		rig.rotation.z = sin(_clock * 13.0) * 0.04 * (1.0 if fmod(_clock, 3.0) < 1.2 else 0.2)
		_mutter_in -= delta
		if _mutter_in <= 0.0 and distance < 9.0:
			_mutter_in = 5.0 + _rng.randf() * 4.0
			_say("held")
		return
	# A new meeting after time apart.
	if distance > APART_DISTANCE:
		_apart += delta
		if _apart >= APART_SECONDS:
			met = false
	elif not met and distance <= MEET_DISTANCE:
		meet()
	if not met:
		_wander(delta)
		return
	match act:
		"fight":
			var guard := _nearest_guard(16.0)
			if guard != null:
				_go(guard.global_position, RUN, delta, REACH)
				if _flat(guard.global_position - global_position).length() <= REACH and _cooldown <= 0.0:
					_cooldown = STRIKE_COOLDOWN
					if not _act_done:
						_act_done = true
						_say("fight")
					guard.distract(self, 4.0)
					guard.take_hit(GUARD_STRIKE, guard.global_position - global_position, "blunt", subject_id)
			else:
				_go(player.global_position, WALK, delta, 2.4)
		"give":
			_go(player.global_position, WALK, delta, 1.4)
			if not _act_done and distance <= 1.8:
				_act_done = true
				_give()
		"tell":
			_go(player.global_position, WALK, delta, 2.6)
			if not _act_done and distance <= 3.2:
				_act_done = true
				_tell()
		"distract":
			var guard := _nearest_guard(40.0)
			if guard != null:
				_go(guard.global_position, RUN, delta, 3.0)
				if not _act_done and _flat(guard.global_position - global_position).length() < 8.0:
					_act_done = true
					_say("distract")
					WorldHistory.record_event("bingyanger_distracted_guards", {"subject_id": subject_id})
				if _act_done and _cooldown <= 0.0:
					_cooldown = 3.0
					for other in guards:
						if other != null and is_instance_valid(other) and not other.is_down() and _flat(other.global_position - global_position).length() < 14.0:
							other.distract(self, 10.0)
			else:
				_wander(delta)
		"attack":
			_go(player.global_position, RUN, delta, REACH * 0.8)
			if distance <= REACH and _cooldown <= 0.0:
				_cooldown = STRIKE_COOLDOWN
				_say("attack")
				WorldHistory.record_event("bingyanger_attacked_player", {"subject_id": subject_id, "damage": PLAYER_STRIKE})
				struck_player.emit(PLAYER_STRIKE)
		"scream":
			_face(player.global_position)
			if not _act_done:
				_act_done = true
				_scream_left = 3.0
				_say("scream")
				WorldHistory.record_event("bingyanger_screamed", {"subject_id": subject_id})
				if director != null:
					director.trip("bingyanger_scream", global_position)
			_scream_left = maxf(0.0, _scream_left - delta)
			rig.rotation.z = sin(_clock * 30.0) * 0.08 * (1.0 if _scream_left > 0.0 else 0.0)
		"steal":
			if holding.is_empty():
				_go(player.global_position, RUN, delta, 1.0)
				if distance <= REACH:
					_steal()
			else:
				# Away with it, down the hall the other way.
				var away := global_position + _flat(global_position - player.global_position).normalized() * 6.0
				_go(away, RUN, delta, 0.1)
		"stalk":
			if distance > STALK_DISTANCE + 1.0:
				_go(player.global_position, WALK, delta, STALK_DISTANCE)
			elif distance < STALK_DISTANCE - 2.0:
				var back := global_position + _flat(global_position - player.global_position).normalized() * 2.0
				_go(back, WALK, delta, 0.1)
			else:
				_face(player.global_position)
			_taunt_in -= delta
			if _taunt_in <= 0.0:
				_taunt_in = 6.0 + _rng.randf() * 4.0
				_say("stalk")
				if not _act_done:
					_act_done = true
					WorldHistory.record_event("bingyanger_stalking", {"subject_id": subject_id})
	_animate()


func _give() -> void:
	var gift: Dictionary = (GIFTS[_rng.randi() % GIFTS.size()] as Dictionary).duplicate()
	gift["perishes"] = false
	gift["age"] = 0.0
	gift["from"] = subject_id
	var carry := CARRY.new()
	carry.items.append(gift)
	carry.save_to_history()
	_say("give")
	WorldHistory.record_event("bingyanger_gave", {"subject_id": subject_id, "item": str(gift.label)})
	gave_item.emit(str(gift.label))


func _tell() -> void:
	# Sometimes true, sometimes not: a host-supplied fact or a prophecy.
	var line: String
	if not hints.is_empty() and _rng.randf() < 0.65:
		line = hints[_rng.randi() % hints.size()]
	else:
		var pool: Array = LINES.prophecy
		line = str(pool[_rng.randi() % pool.size()])
	_speak(line)
	WorldHistory.record_event("bingyanger_told", {"subject_id": subject_id, "line": line})


func _steal() -> void:
	var carry := CARRY.new()
	if carry.items.is_empty():
		act = "stalk"
		return
	var index := _rng.randi() % carry.items.size()
	var item: Dictionary = carry.items[index]
	holding = str(item.get("label", "SOMETHING"))
	carry.items.remove_at(index)
	carry.save_to_history()
	WorldHistory.amend_subject(subject_id, {"holding": holding, "holding_item": item})
	WorldHistory.record_event("bingyanger_stole", {"subject_id": subject_id, "item": holding})
	_say("steal")
	took_item.emit(holding)


## Whatever it stole is on its body once it is dead; the host offers it back.
func take_back() -> String:
	if holding.is_empty() or not is_down():
		return ""
	var record := WorldHistory.subject(subject_id)
	var item: Dictionary = record.get("holding_item", {"label": holding, "kind": "goods", "mass": 0.5})
	var carry := CARRY.new()
	carry.items.append(item)
	carry.save_to_history()
	var label := holding
	holding = ""
	WorldHistory.amend_subject(subject_id, {"holding": "", "holding_item": {}})
	WorldHistory.record_event("bingyanger_item_recovered", {"subject_id": subject_id, "item": label})
	return label


## A blow from anyone: the player, a guard's round.
func take_hit(damage: float, direction: Vector3, kind := "blunt", by := "player") -> Dictionary:
	if rig == null or state == "dead":
		return {}
	var result: Dictionary = rig.hit("torso", damage, 8.0, kind, "", direction.normalized())
	if rig.anatomy.downed or rig.anatomy.dead:
		_die(by)
	else:
		_say("struck")
		# Hit it and it remembers who: a friend struck turns on you.
		if by == "player" and attitude == "friendly":
			attitude = "hostile"
			act = "attack"
			WorldHistory.amend_subject(subject_id, {"attitude": attitude, "last_act": act})
	return result


func _die(by: String) -> void:
	if state == "dead":
		return
	state = "dead"
	rig.anatomy.dead = true
	rig.rotation.x = -PI * 0.46
	_say("dying")
	WorldHistory.update_subject(subject_id, {"status": "dead", "killed_by": by}, "bingyanger_died")


func _nearest_guard(within: float) -> Node3D:
	var best: Node3D
	var best_distance := within
	for guard in guards:
		if guard == null or not is_instance_valid(guard) or guard.is_down():
			continue
		var distance := _flat(guard.global_position - global_position).length()
		if distance < best_distance:
			best_distance = distance
			best = guard
	return best


func _wander(delta: float) -> void:
	var target := home + Vector3(sin(_clock * 0.3) * 1.5, 0, cos(_clock * 0.23) * 1.5)
	_go(target, WALK * 0.5, delta, 0.2)


func _go(goal: Vector3, speed: float, delta: float, stop_at: float) -> void:
	var to := _flat(goal - global_position)
	if to.length() <= stop_at:
		_face(goal)
		return
	var step_length := minf(speed * delta, to.length() - stop_at)
	global_position += to.normalized() * step_length
	global_position.x = clampf(global_position.x, -6.6, 6.6)
	_pace += step_length
	_face(goal)


func _face(goal: Vector3) -> void:
	var to := _flat(goal - global_position)
	if to.length() > 0.05:
		global_rotation.y = lerp_angle(global_rotation.y, atan2(-to.x, -to.z), 0.3)


## A lurch rather than a walk: no gait on the rig yet.
func _animate() -> void:
	rig.position.y = absf(sin(_pace * 3.1)) * 0.07
	rig.rotation.z = sin(_pace * 1.55) * 0.12


func _say(kind: String) -> void:
	var pool: Array = LINES.get(kind, [])
	if pool.is_empty():
		return
	_speak(str(pool[_rng.randi() % pool.size()]))


func _speak(line: String) -> void:
	_label.text = line
	_line_life = 3.4
	if voice != null:
		voice.speak(line.to_lower())
	said.emit(line)


func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)
