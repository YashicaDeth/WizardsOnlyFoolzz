class_name ExaminerFight
extends Node3D

## Greg, 26 September (question boxes): an optional fight, revenge or escape,
## in the examiner's office. He fights with surgical tools and a syringe that
## slows you. Win: his keycard and his coat. Lose: back in the vat, and he
## keeps the coat.
##
## Built into the office by `DoctorRoute` (the room behind his door, which you
## break down). He is at his bench with his back to the door, working. Get
## close, hit him or stay in his room long enough and he turns, pulls the mask
## up and comes at you. Escape stays open: the pit door out of the Growing
## Floor, or the lift past him.
##
## Job 6 (v0.1 "Escape", Greg 4 Oct: "it's a boss fight"): about thirty
## seconds. Every blow is read before it lands: the scalpel glints bone-white
## through its wind-up and can be parried (PARRY: X / L2) into a long stagger
## where your blows bite double; the syringe glints sick green, lunges and
## cannot be parried, only stepped out of. He takes blows on his poise and
## only reels when it breaks. Under half health he is desperate: quicker
## wind-ups, a follow-up cut, less rest. His decisions are a LimboAI behaviour
## tree when the plugin is on disk (`build_tree`), the same selector in
## GDScript when it is not (`decide`). On death his keycard falls to the floor
## as a pickup; the staff door reads that same inventory item (`has_keycard`).
##
## Placeholder body and tools (a BaselineHuman dressed by `ExaminerLook`, a
## box scalpel and syringe) until Greg draws him.

const LOOK := preload("res://systems/examiner_look.gd")
const CARRY := preload("res://systems/carry.gd")
const CLOTHING := preload("res://systems/clothing.gd")
const VAT_REBIRTH := preload("res://systems/vat_rebirth.gd")
const EXAMINER_VOICE := preload("res://systems/examiner_voice.gd")

const SUBJECT := "examiner_fight"
const LOCATION := "examination_room"
const KEYCARD := "STAFF KEYCARD"
const KEYCARD_OPENS := "staff_door"
const COAT := "examiner_coat"

## Greg's playtest: too easy, "hit him twice... he's dead". Job 6 dial: about
## nine clean cleaver blows, fewer with parry ripostes, for a ~30 s fight.
const HEALTH := 260.0
## What each thing you can hit him with takes off him.
## Bare-fist damage is a dial (was 9.0), pending Greg's confirmation.
const DAMAGE := {"axe": 30.0, "restraint": 16.0, "": 15.0, "gun": 45.0}
const PLAYER_REACH := 2.3
const REACH := 1.45
const SPEED := 2.3
const NOTICE_DISTANCE := 2.6
const NOTICE_LINGER := 10.0
const TURN_SECONDS := 1.4
## Rest between blows, and each wind-up, per phase [calm, desperate].
const COOLDOWN := [1.1, 0.7]
const SCALPEL_WINDUP := [0.6, 0.45]
const SYRINGE_WINDUP := [0.95, 0.75]
## Phase 2's follow-up cut comes quicker than a fresh one.
const FOLLOW_WINDUP := 0.38
## His attack order, per phase: fixed so it can be learned.
const PATTERN := [["scalpel", "scalpel", "syringe"], ["scalpel", "follow", "syringe"]]
## Under this share of his health he is desperate.
const PHASE_TWO_AT := 0.5
## A scalpel cut: a real cut on the anatomy plus 6% of your blood.
const SCALPEL_DAMAGE := 14.0
const SCALPEL_BLOOD := 0.06
const SYRINGE_DAMAGE := 5.0
const SYRINGE_SLOW := 6.0
## The syringe is a lunge: from this far he closes the gap in its last beat.
const SYRINGE_REACH := 2.6
const SYRINGE_LUNGE := 5.5
## A short reel when your blows break his poise.
const STAGGER := 0.45
## Blows he takes without reeling, per phase. A reel only cuts short a calm
## scalpel wind-up; the syringe, and anything once desperate, comes through.
const POISE := [3, 4]
## Every this-many blows that catch him at rest (not winding, not reeling) he
## turns aside with his forearm for a fraction of the damage and answers with
## a quick cut: spamming him is punished, reading him is not.
const GUARD_EVERY := 3
const GUARDED_SHARE := 0.2
## Parry: pressed this long before a scalpel lands, it is turned aside.
const PARRY_WINDOW := 0.3
## A parried cut leaves him open this long; your blows bite this much harder.
const PARRIED_STAGGER := 1.6
const RIPOSTE := 2.0
## Between blows he circles you instead of standing still.
const CIRCLE_SPEED := 1.1
## The blade darts in with the cut: the last part of the wind-up closes distance.
const LUNGE := 2.6
## Lose when your blood is under this share, or your body goes down.
const LOSE_AT := 0.45
## Job 6 dial: a cold overhead pool on the fight so his wind-ups read.
const ARENA_LIGHT_ENERGY := 2.4
const ARENA_LIGHT_COLOUR := Color("d2ecc0")
## Telegraph glints: bone-white for the parryable scalpel, sick green for the
## syringe you must step out of (Greg 5 Oct palette: no neon).
const GLINT_SCALPEL := Color("efe6d2")
const GLINT_SYRINGE := Color("9fb38a")
## How close the dropped keycard is picked up just by walking over it.
const KEYCARD_WALK_OVER := 0.6
const KEYCARD_REACH := 1.8
const KEYCARD_DROP := 1.0

var route: Node3D
var chamber: Node3D
var body: BaselineHuman
var mask: Node3D
var scalpel: Node3D
var syringe: Node3D
var state := "idle"
var health := HEALTH
var clock := 0.0
var linger := 0.0
var attack_clock := 0.0
var windup := 0.0
var winding := ""
var attacks_made := 0
var stagger_left := 0.0
var walk_phase := 0.0
var hits_landed := 0
var hits_taken := 0
var room_min := Vector2.ZERO
var room_max := Vector2.ZERO
var bar: CanvasLayer
var _bar_fill: ColorRect
var _bar_title: Label
var _fall := 0.0
## Where he works, and goes back to when you leave his room.
var post := Vector3.ZERO
var _circle_side := 1.0
var _recoil := 0.0
## The house hitstop: only he catches on your blow, not the world.
var feel := ImpactFeel.new()
## 1 calm, 2 desperate (under PHASE_TWO_AT of his health).
var phase := 1
var poise := 0
## Seconds since the player last pressed parry (large = not recently).
var parry_age := 99.0
var parries := 0
var parried_left := 0.0
var guards := 0
var _rest_blows := 0
var telegraphs := 0
var last_action := ""
## Choices made by the LimboAI tree (0 when it is absent and `decide` runs).
var tree_choices := 0
## The keycard on his office floor once he is down, until taken.
var keycard_pickup: Node3D
## Walking over the card takes it only once you have been clear of it, so it
## is seen on the floor rather than vanishing under you at the killing blow.
var _card_armed := false
## The LimboAI player driving his choices, or null (GDScript selector).
var brain: Node
var arena_light: SpotLight3D
var _glint: OmniLight3D
var _tool_glow: Dictionary = {}
var voice: ExaminerVoice


## `owner_route` is the DoctorRoute (for its room bounds and `_can_act`).
func setup(owner_route: Node3D, bench_at: Vector3, room_x: Vector2, room_z: Vector2) -> void:
	name = "ExaminerFight"
	add_child(feel)
	route = owner_route
	chamber = owner_route.get("chamber")
	room_min = Vector2(room_x.x + 0.45, room_z.x + 0.6)
	room_max = Vector2(room_x.y - 0.45, room_z.y - 0.5)
	body = BaselineHuman.new()
	body.name = "OfficeExaminer"
	add_child(body)
	body.build("office_examiner", BaselineHuman.config_from_subject({"race": "decanted"}).merged({"gore": true, "rigged": true}, true))
	voice = EXAMINER_VOICE.new()
	voice.level = 0.42
	body.add_child(voice)
	var appearance := HunterAppearance.new()
	body.add_child(appearance)
	appearance.configure(body, {"axes": {"brow": 0.7, "jaw": 0.6, "cheek": 0.2, "eyes": 0.3, "nose": 0.55, "mouth": 0.4}})
	mask = LOOK.dress(body, false)
	scalpel = _tool(body.parts.get("right_arm") as Node3D, Vector3(0.02, 0.02, 0.24), Color("c9ccc8"), 0.6)
	syringe = _tool(body.parts.get("left_arm") as Node3D, Vector3(0.022, 0.022, 0.14), Color("dfe8e0"), 0.1)
	var record := WorldHistory.subject(SUBJECT)
	if str(record.get("status", "")) == "won":
		# Beaten: he is where he fell, coatless; his card where it fell, if you
		# left it there.
		state = "won"
		position = Vector3(float(record.get("x", bench_at.x + 0.8)), 0.0, float(record.get("z", bench_at.z)))
		_lie_down(1.0)
		if not has_keycard() and WorldHistory.event_count("examiner_keycard_taken") == 0:
			_drop_keycard(Vector3(float(record.get("card_x", position.x)), 0.0, float(record.get("card_z", position.z + KEYCARD_DROP))))
		return
	# At his bench, his back to the door, working.
	position = bench_at + Vector3(0.8, 0.0, 0.0)
	post = position
	body.rotation.y = -PI * 0.5
	poise = POISE[0]
	_build_bar()
	_build_arena_light(room_x, room_z)
	brain = _build_brain()


func is_active() -> bool:
	return state in ["idle", "noticed", "fighting"]


## The one check the staff door and the route use: the card is in the shared
## inventory (Carry / WorldHistory "inventory"), by its label or what it opens.
static func has_keycard() -> bool:
	for entry in WorldHistory.subject("inventory").get("items", []):
		if entry is Dictionary and (str((entry as Dictionary).get("label", "")) == KEYCARD or str((entry as Dictionary).get("opens", "")) == KEYCARD_OPENS):
			return true
	return false


## The player pressed parry (X / L2). A scalpel landing inside PARRY_WINDOW of
## this is turned aside. True while it could matter (he is fighting you).
func player_parry() -> bool:
	if state != "fighting":
		return false
	parry_age = 0.0
	return true


## A click from the player in his room. True when it was used on him.
func player_strike(weapon: String) -> bool:
	if not is_active() or chamber == null:
		return false
	var player: Node3D = chamber.player
	var to_him := global_position - player.global_position
	to_him.y = 0.0
	if to_him.length() > PLAYER_REACH or not bool(route.call("_in_room")):
		return false
	var forward: Vector3 = -chamber.camera.global_transform.basis.z
	forward.y = 0.0
	if forward.normalized().dot(to_him.normalized()) < 0.55:
		return false
	var damage: float = DAMAGE.get(weapon, DAMAGE[""])
	var riposte := parried_left > 0.0
	if riposte:
		# One riposte per parry: the opening closes with it.
		damage *= RIPOSTE
		parried_left = 0.0
	if state == "fighting" and not riposte and winding == "" and stagger_left <= 0.0 and weapon != "gun":
		_rest_blows += 1
		if _rest_blows % GUARD_EVERY == 0:
			_guard(damage * GUARDED_SHARE)
			return true
	health = maxf(0.0, health - damage)
	hits_landed += 1
	# Poise: he takes blows through a wind-up until it breaks; a parried man
	# is already open and stays open.
	poise -= 1
	if poise <= 0 and not riposte:
		poise = POISE[phase - 1]
		if winding == "" or (phase == 1 and winding == "scalpel"):
			stagger_left = STAGGER
			_cancel_windup()
			if body.rigged != null:
				body.rigged.play_action("hit_front", 1.4)
	# His body shows the hit where it lands (the rig's own wound and blood).
	# Wounds, never his death: the rig only goes down when the fight says so,
	# so a blow can never drop or break him early (Greg's "head all broken").
	_wound(weapon, damage)
	# Greg's playtest: hits felt weightless. The world catches, he reels, you feel it.
	_recoil = 1.0
	_circle_side = -_circle_side
	BodyCamFeel.hit(chamber.camera, 0.03 + damage * 0.001)
	if chamber.get("opening_audio") != null and chamber.opening_audio != null:
		chamber.opening_audio.cue("rip" if weapon == "axe" else "tap")
	feel.strike(clampf(damage / 45.0, 0.3, 1.0), "cut" if weapon == "axe" else "blunt", false, [SUBJECT])
	if chamber.get("breach_shake") != null:
		chamber.breach_shake = maxf(float(chamber.breach_shake), 0.18)
	WorldHistory.record_event("examiner_fight_hit", {"weapon": weapon if weapon != "" else "fists", "damage": damage, "left": health, "riposte": riposte})
	if state == "idle":
		_notice()
	if phase == 1 and health <= HEALTH * PHASE_TWO_AT and health > 0.0:
		_desperate()
	if health <= 0.0:
		_win()
	_update_bar()
	return true


func _physics_process(delta: float) -> void:
	delta *= feel.scale_for(SUBJECT)
	if state == "won":
		if _fall < 1.0:
			_fall = minf(1.0, _fall + delta * 1.6)
			_lie_down(_fall)
		_watch_keycard()
		return
	if not is_active() or chamber == null or route == null or not bool(route.call("_can_act")):
		return
	parry_age += delta
	var player: Node3D = chamber.player
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()
	match state:
		"idle":
			if bool(route.call("_in_room")):
				linger += delta
				if distance <= NOTICE_DISTANCE or linger >= NOTICE_LINGER:
					_notice()
		"noticed":
			clock += delta
			_face(to_player, delta * 4.0)
			if clock >= TURN_SECONDS:
				state = "fighting"
				_say("HE COMES AT YOU  //  HIT HIM  //  PARRY THE WHITE GLINT  //  STEP OUT OF THE GREEN")
		"fighting":
			# Greg's playtest: the fight is in his room. Step out and he stops,
			# goes back to his bench and waits; step back in and he comes again.
			if not bool(route.call("_in_room")):
				_cancel_windup()
				var home := post - global_position
				home.y = 0.0
				if home.length() > 0.1:
					walk_phase += delta * 8.0
					_step(home.normalized() * SPEED * delta)
					_face(home, delta * 6.0)
					_pose(0.0, 1.0)
				else:
					_face(to_player, delta * 4.0)
					_pose(0.0, 0.0)
				return
			_fight(delta, to_player, distance)


func _fight(delta: float, to_player: Vector3, distance: float) -> void:
	if _player_beaten():
		_lose()
		return
	_face(to_player, delta * 6.0)
	if parried_left > 0.0:
		parried_left = maxf(0.0, parried_left - delta)
	if winding == "":
		attack_clock += delta
	match think(delta, distance):
		"reel":
			# Parried, he stands open in front of you; knocked, he gives a step.
			if parried_left <= 0.0:
				stagger_left = maxf(0.0, stagger_left - delta)
				_step(-to_player.normalized() * 1.8 * delta)
			_pose(0.0, 0.0)
		"windup":
			_advance_windup(delta, to_player, distance)
		"attack":
			_begin_attack()
		"close":
			walk_phase += delta * 8.0
			_step(to_player.normalized() * SPEED * delta)
			_pose(0.0, 1.0)
		_:
			# Circling, not standing: a sidestep round you while he waits.
			walk_phase += delta * 6.0
			_step(to_player.normalized().cross(Vector3.UP) * _circle_side * CIRCLE_SPEED * delta)
			_pose(0.0, 0.6)


# --- His choices. One selector, two hosts: LimboAI when it is installed, this
# --- file when it is not. Both read the same four facts.

## The facts the selector reads, as blackboard values.
func facts(distance: float) -> Dictionary:
	return {
		"reeling": stagger_left > 0.0 or parried_left > 0.0,
		"winding": winding != "",
		"in_reach": distance <= _reach_for(_next_attack()),
		"ready": attack_clock >= COOLDOWN[phase - 1],
	}


## The GDScript twin of `build_tree`: first true branch wins.
static func decide(f: Dictionary) -> String:
	if bool(f.get("reeling", false)):
		return "reel"
	if bool(f.get("winding", false)):
		return "windup"
	if bool(f.get("in_reach", false)) and bool(f.get("ready", false)):
		return "attack"
	if not bool(f.get("in_reach", false)):
		return "close"
	return "circle"


## One tick of his mind: the tree (whose leaves call `_bt_choose`), else `decide`.
func think(delta: float, distance: float) -> String:
	var f := facts(distance)
	last_action = ""
	if brain != null:
		var board: Object = brain.get("blackboard")
		board.call("set_var", &"fight", self)
		for key: String in f:
			board.call("set_var", StringName(key), f[key])
		brain.call("update", delta)
	if last_action == "":
		last_action = decide(f)
	return last_action


## Called by the LimboAI tree's action leaves.
func _bt_choose(action: String) -> void:
	last_action = action
	tree_choices += 1


## The behaviour tree, built in code by name (as `RivalTactics.build_tree`):
## LimboAI is a gitignored GDExtension, so naming its classes directly would
## stop this file parsing where it is absent. Null when it is absent.
static func build_tree() -> Resource:
	if not ClassDB.class_exists("BehaviorTree"):
		return null
	var tree: Resource = ClassDB.instantiate("BehaviorTree")
	tree.set("description", "The examiner: reel, finish the wind-up, strike in reach, close, circle.")
	var root: Resource = ClassDB.instantiate("BTSelector")
	root.set("custom_name", "ExaminerSelector")
	root.call("add_child", _branch([["reeling", true]], "reel"))
	root.call("add_child", _branch([["winding", true]], "windup"))
	root.call("add_child", _branch([["in_reach", true], ["ready", true]], "attack"))
	root.call("add_child", _branch([["in_reach", false]], "close"))
	root.call("add_child", _choose("circle"))
	tree.call("set_root_task", root)
	return tree


static func _branch(conditions: Array, action: String) -> Resource:
	var sequence: Resource = ClassDB.instantiate("BTSequence")
	sequence.set("custom_name", action.capitalize())
	for condition: Array in conditions:
		var check: Resource = ClassDB.instantiate("BTCheckVar")
		check.set("variable", StringName(condition[0]))
		check.set("check_type", 0)  # LimboUtility.CHECK_EQUAL
		var value: Resource = ClassDB.instantiate("BBVariant")
		value.set("type", TYPE_BOOL)
		value.set("saved_value", condition[1])
		check.set("value", value)
		sequence.call("add_child", check)
	sequence.call("add_child", _choose(action))
	return sequence


static func _choose(action: String) -> Resource:
	var leaf: Resource = ClassDB.instantiate("BTCallMethod")
	leaf.set("custom_name", "Choose %s" % action)
	var node: Resource = ClassDB.instantiate("BBNode")
	node.set("value_source", 1)  # BBParam.BLACKBOARD_VAR
	node.set("variable", &"fight")
	leaf.set("node", node)
	leaf.set("method", &"_bt_choose")
	var arg: Resource = ClassDB.instantiate("BBVariant")
	arg.set("type", TYPE_STRING)
	arg.set("saved_value", action)
	leaf.set("args", [arg])
	return leaf


func _build_brain() -> Node:
	var tree := build_tree()
	if tree == null:
		return null
	var player: Node = ClassDB.instantiate("BTPlayer")
	player.name = "ExaminerBrain"
	player.set("update_mode", 2)  # BTPlayer.MANUAL: ticked from `think`
	player.set("behavior_tree", tree)
	player.call("set_scene_root_hint", self)
	add_child(player)
	return player


# --- His blows. ---

func _next_attack() -> String:
	var pattern: Array = PATTERN[phase - 1]
	return str(pattern[attacks_made % pattern.size()])


## Where he starts a blow from: the cut's own dart (LUNGE) covers the rest.
func _reach_for(kind: String) -> float:
	return SYRINGE_REACH if kind == "syringe" else REACH + 0.5


func _windup_for(kind: String) -> float:
	if kind == "syringe":
		return SYRINGE_WINDUP[phase - 1]
	if kind == "follow":
		return FOLLOW_WINDUP
	return SCALPEL_WINDUP[phase - 1]


func _begin_attack() -> void:
	winding = _next_attack()
	attacks_made += 1
	windup = 0.0
	telegraphs += 1
	_set_glint(GLINT_SYRINGE if winding == "syringe" else GLINT_SCALPEL)
	WorldHistory.record_event("examiner_fight_telegraph", {"tool": winding, "phase": phase})
	if body.rigged != null:
		# The clip's strike lands as the wind-up ends.
		var clip := "spell_cast" if winding == "syringe" else "sword_attack"
		var length := body.rigged.player.get_animation(str(RiggedBody.CLIPS[clip])).length
		body.rigged.play_action(clip, length / _windup_for(winding))


func _advance_windup(delta: float, to_player: Vector3, distance: float) -> void:
	windup += delta
	var needed := _windup_for(winding)
	var amount := clampf(windup / needed, 0.0, 1.0)
	_pose(ease(amount, 2.4), 0.0)
	_glow(amount)
	if winding == "syringe":
		# The lunge: the last 40% of the wind-up covers the gap.
		if amount > 0.6 and distance > REACH * 0.6:
			_step(to_player.normalized() * SYRINGE_LUNGE * delta)
	elif amount > 0.7 and distance > REACH * 0.7:
		_step(to_player.normalized() * LUNGE * delta)
	if windup < needed:
		return
	var kind := winding
	_cancel_windup()
	var flat: Vector3 = chamber.player.global_position - global_position
	flat.y = 0.0
	_land(kind, flat.length())
	# Desperate, the first cut is followed straight away by the second.
	attack_clock = COOLDOWN[1] if kind == "scalpel" and phase == 2 else 0.0


func _cancel_windup() -> void:
	winding = ""
	windup = 0.0
	_set_glint(Color.BLACK)


## The blow lands if you are still in reach when the wind-up ends.
func _land(kind: String, distance: float) -> void:
	_pose(0.0, 0.0)
	if distance > REACH + 0.35:
		_say("HE MISSES")
		return
	if kind != "syringe" and parry_age <= PARRY_WINDOW:
		# Turned aside: he is open.
		parries += 1
		parried_left = PARRIED_STAGGER
		stagger_left = 0.0
		parry_age = 99.0
		if body.rigged != null:
			body.rigged.play_action("hit_front", 0.8)
		if chamber.get("opening_audio") != null and chamber.opening_audio != null:
			chamber.opening_audio.cue("glass")
		feel.strike(0.6, "blunt", false, [SUBJECT])
		_say("PARRIED  //  HE IS OPEN  //  HIT HIM")
		WorldHistory.record_event("examiner_fight_parried", {"phase": phase})
		return
	hits_taken += 1
	var anatomy: Node = chamber.anatomy
	if kind == "syringe":
		anatomy.call("apply_hit", "torso", SYRINGE_DAMAGE, 0.0, "puncture")
		chamber.slowed_left = SYRINGE_SLOW
		_say("THE SYRINGE  //  YOUR LEGS GO HEAVY")
	else:
		var zone: String = ["right_arm", "left_arm", "torso"][hits_taken % 3]
		anatomy.call("apply_hit", zone, SCALPEL_DAMAGE, 0.0, "cut")
		var capacity := float(anatomy.get("blood_capacity"))
		anatomy.set("blood_remaining", maxf(0.0, float(anatomy.get("blood_remaining")) - capacity * SCALPEL_BLOOD))
		_say("THE SCALPEL  //  %s" % zone.replace("_", " ").to_upper())
	BodyCamFeel.hit(chamber.camera, 0.07)
	if chamber.get("breach_shake") != null:
		chamber.breach_shake = maxf(float(chamber.breach_shake), 0.3)
	WorldHistory.record_event("examiner_fight_wound", {"tool": kind})


## Your blow, turned aside on his forearm; he answers at once.
func _guard(damage: float) -> void:
	guards += 1
	health = maxf(1.0, health - damage)
	_recoil = 0.4
	if chamber.get("opening_audio") != null and chamber.opening_audio != null:
		chamber.opening_audio.cue("tap")
	feel.strike(0.3, "blunt", false, [SUBJECT])
	_say("HE TURNS IT ASIDE  //  HE ANSWERS")
	WorldHistory.record_event("examiner_fight_guarded", {"left": health})
	# The answer is the quick follow-up cut: parryable, and it glints.
	winding = "follow"
	windup = 0.0
	telegraphs += 1
	_set_glint(GLINT_SCALPEL)
	if body.rigged != null:
		var length := body.rigged.player.get_animation(str(RiggedBody.CLIPS["sword_attack"])).length
		body.rigged.play_action("sword_attack", length / FOLLOW_WINDUP)
	_update_bar()


## A wound on his rig where the blow lands. The marks stay; what would drop
## him is held back, because his death is the fight's, not a stray organ hit's.
func _wound(weapon: String, damage: float) -> void:
	var zone := "torso" if hits_landed % 2 == 1 else "right_arm"
	var kind := "cut" if weapon == "axe" else ("ballistic" if weapon == "gun" else "blunt")
	var anatomy: Node = body.anatomy
	var blood_before := float(anatomy.get("blood_remaining")) if anatomy != null else 0.0
	body.hit(zone, damage * 0.5, 2.0, kind)
	if anatomy == null or health <= 0.0:
		return
	if bool(anatomy.get("dead")) or bool(anatomy.get("downed")):
		anatomy.set("dead", false)
		anatomy.set("downed", false)
		anatomy.set("blood_remaining", maxf(blood_before * 0.9, float(anatomy.get("blood_capacity")) * 0.5))


func _player_beaten() -> bool:
	var anatomy: Node = chamber.anatomy
	if anatomy == null:
		return false
	if bool(anatomy.get("dead")) or bool(anatomy.get("downed")):
		return true
	return float(anatomy.get("blood_remaining")) / maxf(float(anatomy.get("blood_capacity")), 1.0) < LOSE_AT


func _notice() -> void:
	if state != "idle":
		return
	state = "noticed"
	clock = 0.0
	LOOK.set_mask(mask, true)
	_say("THE EXAMINER  //  \"YOU WERE NOT SUPPOSED TO BE AWAKE YET.\"")
	if voice != null:
		voice.speak("You were not supposed to be awake yet.", TURN_SECONDS, false)
	WorldHistory.update_subject(SUBJECT, {"kind": "fight", "status": "fighting", "losses": int(WorldHistory.subject(SUBJECT).get("losses", 0))}, "examiner_fight_started")
	if bar != null:
		bar.visible = true
	if arena_light != null:
		arena_light.visible = true
	_update_bar()


func _desperate() -> void:
	phase = 2
	poise = POISE[1]
	attack_clock = minf(attack_clock, COOLDOWN[1])
	WorldHistory.record_event("examiner_fight_phase", {"phase": 2})
	if _bar_title != null:
		_bar_title.text = "THE EXAMINER  //  DESPERATE"
	if _bar_fill != null:
		_bar_fill.color = Color("d0251f")


func _win() -> void:
	state = "won"
	_cancel_windup()
	parried_left = 0.0
	stagger_left = 0.0
	CLOTHING.wear("player", COAT)
	# His card falls to his side, a little towards you, inside his room: he
	# falls forward, and a card dropped straight ahead lay under his body in
	# the render.
	var toward: Vector3 = chamber.player.global_position - global_position
	toward.y = 0.0
	toward = toward.normalized() if toward.length() > 0.01 else Vector3(0, 0, -1)
	var card_at := _card_spot(toward, 1.0)
	if not _inside_room(card_at):
		card_at = _card_spot(toward, -1.0)
	card_at.x = clampf(card_at.x, room_min.x, room_max.x)
	card_at.z = clampf(card_at.z, room_min.y, room_max.y)
	card_at.y = 0.0
	if not has_keycard():
		_drop_keycard(card_at)
	WorldHistory.update_subject(SUBJECT, {"status": "won", "x": global_position.x, "z": global_position.z, "coat": "player", "card_x": card_at.x, "card_z": card_at.z}, "examiner_beaten")
	WorldHistory.record_event("examiner_keycard_dropped", {"location": LOCATION})
	_say("HE GOES DOWN  //  HIS COAT IS YOURS  //  HIS KEYCARD IS ON THE FLOOR")
	if bar != null:
		bar.visible = false
	if arena_light != null:
		arena_light.light_energy = ARENA_LIGHT_ENERGY * 0.6


func _lose() -> void:
	state = "lost"
	_cancel_windup()
	var losses := int(WorldHistory.subject(SUBJECT).get("losses", 0)) + 1
	WorldHistory.update_subject(SUBJECT, {"status": "lost", "losses": losses, "coat": "examiner"}, "examiner_fight_lost")
	_say("HE PUTS YOU DOWN  //  HE KEEPS HIS COAT")
	if bar != null:
		bar.visible = false
	var at: Vector3 = chamber.player.global_position
	at.y = 0.0
	var request := VAT_REBIRTH.die(LOCATION, "the examiner's scalpel", "the_examiner", at)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	preload("res://systems/death_beat.gd").play(chamber, request, "cut open by the examiner's scalpel")


# --- His keycard, on the floor until taken. ---

func _card_spot(toward: Vector3, side: float) -> Vector3:
	return global_position + toward.cross(Vector3.UP) * side * KEYCARD_DROP + toward * 0.5


func _inside_room(at: Vector3) -> bool:
	return at.x >= room_min.x and at.x <= room_max.x and at.z >= room_min.y and at.z <= room_max.y


func _drop_keycard(at: Vector3) -> void:
	if keycard_on_floor():
		return
	keycard_pickup = Node3D.new()
	keycard_pickup.name = "StaffKeycardPickup"
	add_child(keycard_pickup)
	keycard_pickup.global_position = Vector3(at.x, 0.03, at.z)
	keycard_pickup.rotation.y = 0.6
	_card_box(Vector3(0.16, 0.01, 0.1), Vector3.ZERO, Color("d9d1bf"), 0.9, "Card")
	_card_box(Vector3(0.16, 0.012, 0.022), Vector3(0, 0.001, -0.026), Color("b0643a"), 1.8, "Stripe")
	# A small low light so the card reads on a dark floor.
	var light := OmniLight3D.new()
	light.name = "CardLight"
	light.light_color = Color("e8d09a")
	light.light_energy = 1.2
	light.omni_range = 1.4
	light.position = Vector3(0, 0.35, 0)
	keycard_pickup.add_child(light)


func _card_box(size: Vector3, at: Vector3, colour: Color, glow: float, label: String) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.4
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = glow
	mesh.material = material
	node.mesh = mesh
	node.position = at
	keycard_pickup.add_child(node)


func keycard_on_floor() -> bool:
	return keycard_pickup != null and is_instance_valid(keycard_pickup)


func keycard_in_reach() -> bool:
	if not keycard_on_floor() or chamber == null:
		return false
	var to: Vector3 = keycard_pickup.global_position - chamber.player.global_position
	to.y = 0.0
	return to.length() <= KEYCARD_REACH


## Use (E / Square) near the card, or walking over it. True when taken.
func take_keycard() -> bool:
	if not keycard_in_reach():
		return false
	if not has_keycard():
		var carry := CARRY.new()
		carry.items.append({"label": KEYCARD, "kind": "key", "mass": 0.05, "perishes": false, "age": 0.0, "opens": KEYCARD_OPENS})
		carry.save_to_history()
	keycard_pickup.queue_free()
	keycard_pickup = null
	WorldHistory.record_event("examiner_keycard_taken", {"location": LOCATION})
	_say("HIS STAFF KEYCARD  //  IT OPENS THE STAFF DOOR ON THE GROWING FLOOR")
	return true


func _watch_keycard() -> void:
	if not keycard_on_floor() or chamber == null:
		return
	var to: Vector3 = keycard_pickup.global_position - chamber.player.global_position
	to.y = 0.0
	if to.length() > 1.0:
		_card_armed = true
	elif to.length() <= KEYCARD_WALK_OVER and _card_armed:
		take_keycard()
		return
	var light := keycard_pickup.get_node_or_null("CardLight") as OmniLight3D
	if light != null:
		light.light_energy = 1.0 + 0.4 * sin(Time.get_ticks_msec() * 0.004)


func _face(toward: Vector3, weight: float) -> void:
	if toward.length_squared() < 0.0001:
		return
	# The rig's face is built on -Z.
	var target := atan2(-toward.x, -toward.z)
	body.rotation.y = lerp_angle(body.rotation.y, target, clampf(weight, 0.0, 1.0))


func _step(move: Vector3) -> void:
	var next := position + Vector3(move.x, 0.0, move.z)
	next.x = clampf(next.x, room_min.x, room_max.x)
	next.z = clampf(next.z, room_min.y, room_max.y)
	position = next


## Arms: 0..1 of a wind-up (tools raised back) and a walk swing.
func _pose(raise: float, walking: float) -> void:
	# Reeling from your last blow: the whole body rocks back, then settles.
	if _recoil > 0.0:
		_recoil = move_toward(_recoil, 0.0, get_physics_process_delta_time() * 3.0)
		body.rotation.x = -0.3 * ease(_recoil, 0.6)
	# Rigged (RiggedBody): the bones own the arms; the wind-up is a clip.
	if body.rigged != null:
		return
	var right := body.parts.get("right_arm") as Node3D
	var left := body.parts.get("left_arm") as Node3D
	var swing := sin(walk_phase) * 0.35 * walking
	if right != null:
		right.rotation.x = -clampf(raise, 0.0, 1.0) * 1.9 + swing
	if left != null:
		left.rotation.x = (-clampf(raise, 0.0, 1.0) * 1.2 if winding == "syringe" else 0.0) - swing
	for leg_name in ["left_leg", "right_leg"]:
		var leg := body.parts.get(leg_name) as Node3D
		if leg != null:
			leg.rotation.x = sin(walk_phase + (PI if leg_name == "right_leg" else 0.0)) * 0.4 * walking


func _lie_down(_amount: float) -> void:
	# The rig owns its own lean (posture); down is its downed pose.
	if body.anatomy != null and not bool(body.anatomy.get("downed")):
		body.anatomy.call("go_down")


func _tool(arm: Node3D, size: Vector3, colour: Color, metallic: float) -> Node3D:
	if arm == null:
		return null
	var tool := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.metallic = metallic
	material.roughness = 0.35
	material.emission_enabled = true
	material.emission = Color.BLACK
	mesh.material = material
	tool.mesh = mesh
	tool.position = Vector3(0.0, -0.36, -0.08)
	arm.add_child(tool)
	_tool_glow[tool] = material
	return tool


# --- Telegraphs and the arena. ---

func _build_arena_light(room_x: Vector2, room_z: Vector2) -> void:
	if ARENA_LIGHT_ENERGY <= 0.0:
		return
	arena_light = SpotLight3D.new()
	arena_light.name = "ExaminerArenaLight"
	arena_light.light_color = ARENA_LIGHT_COLOUR
	arena_light.light_energy = ARENA_LIGHT_ENERGY
	arena_light.spot_range = 5.0
	arena_light.spot_angle = 52.0
	arena_light.spot_attenuation = 0.8
	arena_light.shadow_enabled = false
	arena_light.visible = false
	add_child(arena_light)
	arena_light.global_position = Vector3((room_x.x + room_x.y) * 0.5, 2.95, (room_z.x + room_z.y) * 0.5)
	arena_light.global_rotation = Vector3(-PI * 0.5, 0.0, 0.0)


## A glint on the tool about to be used, lit on the hand that holds it.
func _set_glint(colour: Color) -> void:
	var tool := syringe if colour == GLINT_SYRINGE else scalpel
	var lit := colour != Color.BLACK
	for each: Node3D in _tool_glow:
		var material: StandardMaterial3D = _tool_glow[each]
		material.emission = colour if lit and each == tool else Color.BLACK
		material.emission_energy_multiplier = 0.0
	if _glint == null and lit:
		_glint = OmniLight3D.new()
		_glint.name = "TelegraphGlint"
		_glint.omni_range = 2.0
		add_child(_glint)
	if _glint == null:
		return
	_glint.light_color = colour
	_glint.light_energy = 0.0
	_glint.visible = lit
	if lit and tool != null:
		_glint.global_position = tool.global_position


func _glow(amount: float) -> void:
	var tool := syringe if winding == "syringe" else scalpel
	if tool != null and _tool_glow.has(tool):
		(_tool_glow[tool] as StandardMaterial3D).emission_energy_multiplier = 2.0 + amount * 8.0
	if _glint != null and _glint.visible:
		# A sharp flash as the wind-up starts (the glint you react to), then
		# a steady build to the blow.
		var flash := 4.0 * maxf(0.0, 1.0 - amount / 0.15)
		_glint.light_energy = 0.8 + amount * 3.5 + flash
		if tool != null:
			_glint.global_position = tool.global_position


func _say(text: String) -> void:
	if chamber != null and chamber.get("subtitle") != null:
		(chamber.subtitle as Label).text = text


# --- His bar: a thin strip at the top, only while he is fighting. ---

func _build_bar() -> void:
	bar = CanvasLayer.new()
	bar.name = "ExaminerBar"
	bar.layer = 35
	bar.visible = false
	add_child(bar)
	var title := Label.new()
	_bar_title = title
	title.text = "THE EXAMINER"
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -160.0
	title.offset_right = 160.0
	# Under the subtitle line, clear of the objective box and the REC corner.
	title.offset_top = 146.0
	title.offset_bottom = 166.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("dc5827"))
	title.add_theme_font_size_override("font_size", 15)
	bar.add_child(title)
	var back := ColorRect.new()
	back.color = Color(0.05, 0.01, 0.01, 0.85)
	back.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	back.offset_left = -160.0
	back.offset_right = 160.0
	back.offset_top = 170.0
	back.offset_bottom = 178.0
	bar.add_child(back)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color("a81716")
	_bar_fill.position = Vector2(1, 1)
	_bar_fill.size = Vector2(318, 6)
	back.add_child(_bar_fill)


func _update_bar() -> void:
	if _bar_fill != null:
		_bar_fill.size.x = 318.0 * health / HEALTH
