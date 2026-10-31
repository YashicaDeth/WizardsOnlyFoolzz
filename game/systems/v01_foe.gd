class_name V01Foe
extends Node3D

## Job 9 (v0.1 "Escape"): the small enemy cast's shared body. Greg, 5 Oct
## 02:10: "2-3 numbered CellOutz guards in the service arcade (shock staffs,
## pistols), one freed vat subject that turns hostile, the Lower Works
## sentinel (a machine with armour plates for the X-ray)". 02:20: "hard but
## fair, soulslike, checkpoints close together".
##
## What every foe shares, so the three read the same way:
## - **Every blow is read before it lands.** A wind-up glints on the weapon:
##   COPPER for a blow you can block or parry, deep RED for one you can only
##   step out of (Greg 5 Oct: red only on danger). A guard's own block or
##   parry flashes BONE.
## - **Choices are a LimboAI behaviour tree** built in code from the same
##   branch list the GDScript twin `decide` reads (as `ExaminerFight`): the
##   plugin is a gitignored GDExtension, so naming its classes would stop
##   this file parsing where it is absent.
## - **Its fight owns its death.** Blows wound the real anatomy (cuts, blood,
##   hardware) but the rig only goes down when `health` says so, so a stray
##   organ hit never drops a foe early and a fight can be tuned in one table.
##   Death goes through `AnatomyComponent.finish`, so the corpse is the same
##   gore-capable body every finisher, rip and X-ray already reads.
## - **The world does not rewind.** A dead foe is filed in `WorldHistory` and
##   lies where it fell on every later load.
##
## `V01Encounters` places foes, ticks them (`step`) only near the player, and
## owns the player's side: swings, gun, block, parry, dodge, and the wound a
## landed blow leaves on you (`hurt_player`).

signal died(foe: V01Foe)

## Telegraph palette (Greg 5 Oct: house palette, no neon).
const COPPER := Color("c8662e")
const RED := Color("b3261a")
const BONE := Color("efe6d2")

## DIAL (REMASTER_LOG job9): a foe's wind-up is this many times the same
## move's wind-up in `SwordMoveset` for the player. The player's own timings
## are for a weapon you already know is coming; an enemy's must be read.
const TELEGRAPH_SCALE := 2.4
## Seconds after the player's parry press in which a parryable blow is
## turned aside (the examiner uses the same 0.3).
const PARRY_WINDOW := 0.3

var host: Node
var foe_id := ""
var kind := ""
var body: Node3D
var max_health := 100.0
var health := 100.0
## idle / alert / fighting / dead
var state := "idle"
var winding := ""
var windup := 0.0
var windup_needed := 0.0
var move: Dictionary = {}
var stagger_left := 0.0
var parried_left := 0.0
var recover_left := 0.0
var attack_clock := 0.0
var poise := 3
var max_poise := 3
var area_min := Vector2(-1e6, -1e6)
var area_max := Vector2(1e6, 1e6)
var floor_y := 0.0
## [Vector3 centre, radius] circles the foe walks round (tanks, columns).
var avoid: Array = []
var brain: Node
var tree_choices := 0
var last_action := ""
var telegraphs := 0
var landed_on_player := 0
var hits_taken := 0
var parried_by_player := 0
var alert_at := Vector3.INF
var _glint: OmniLight3D
var _glow_materials: Array = []
var _recoil := 0.0
var _say_label: Label3D
var _say_left := 0.0


## Called by the encounter after the foe is in the tree.
func setup(owner_host: Node, id: String, at: Vector3, area: Rect2, ground_y: float) -> void:
	host = owner_host
	foe_id = id
	name = id
	floor_y = ground_y
	area_min = area.position
	area_max = area.end
	global_position = Vector3(at.x, ground_y, at.z)
	health = max_health
	poise = max_poise
	_build_body()
	_build_glint()
	brain = _build_brain()
	var record := WorldHistory.subject(foe_id)
	if str(record.get("status", "")) == "dead":
		_restore_dead(record)
	else:
		WorldHistory.register_subject(foe_id, _subject_record())


# --- What each kind supplies. ------------------------------------------------

func _build_body() -> void:
	pass


func _subject_record() -> Dictionary:
	return {"kind": "enemy", "status": "alive", "place": "facility"}


## The facts its tree reads, as blackboard values (all bool).
func facts(_distance: float) -> Dictionary:
	return {}


## [[[fact, value], ...], action]: first branch whose facts all match wins.
func branches() -> Array:
	return []


## One chosen action, carried out this frame.
func act(_action: String, _delta: float, _to_player: Vector3, _distance: float) -> void:
	pass


## The blow at the end of a wind-up.
func land(_move_id: String, _distance: float) -> void:
	pass


## What one of the player's blows does to it. `packet`: weapon, move,
## damage, poise, shock, kind, riposte, from (world point), point (world).
## Returns {"result": hit|blocked|parried|armour|weak, "damage": n}.
func take_blow(packet: Dictionary) -> Dictionary:
	return _wound_and_count(packet, float(packet.get("damage", 0.0)))


## Where the player's gun can hit it: [{"at", "radius", "part"}] spheres;
## the body capsule is checked by the encounter separately.
func weak_points() -> Array:
	return []


# --- The tick. -----------------------------------------------------------------

func is_alive() -> bool:
	return state != "dead"


func is_engaged() -> bool:
	return state in ["alert", "fighting"]


func step(delta: float) -> void:
	if state == "dead" or host == null:
		return
	_say_left = maxf(0.0, _say_left - delta)
	if _say_label != null:
		_say_label.modulate.a = clampf(_say_left / 0.6, 0.0, 1.0)
	var player: Node3D = host.player_body()
	if player == null:
		return
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()
	stagger_left = maxf(0.0, stagger_left - delta)
	parried_left = maxf(0.0, parried_left - delta)
	recover_left = maxf(0.0, recover_left - delta)
	if winding == "" and recover_left <= 0.0:
		attack_clock += delta
	if _recoil > 0.0:
		_recoil = move_toward(_recoil, 0.0, delta * 3.0)
		body.rotation.x = -0.25 * ease(_recoil, 0.6)
	act(think(delta, distance), delta, to_player, distance)


## One tick of its mind: the tree (whose leaves call `_bt_choose`), else `decide`.
func think(delta: float, distance: float) -> String:
	var f := facts(distance)
	last_action = ""
	if brain != null:
		var board: Object = brain.get("blackboard")
		board.call("set_var", &"foe", self)
		for key: String in f:
			board.call("set_var", StringName(key), f[key])
		brain.call("update", delta)
	if last_action == "":
		last_action = decide(f, branches())
	return last_action


## The GDScript twin of `build_tree`.
static func decide(f: Dictionary, list: Array) -> String:
	for branch: Array in list:
		var ok := true
		for condition: Array in branch[0]:
			if bool(f.get(condition[0], false)) != bool(condition[1]):
				ok = false
				break
		if ok:
			return str(branch[1])
	return ""


func _bt_choose(action: String) -> void:
	last_action = action
	tree_choices += 1


## The behaviour tree, built by class name (LimboAI may be absent). Null
## when it is.
static func build_tree(label: String, list: Array) -> Resource:
	if not ClassDB.class_exists("BehaviorTree"):
		return null
	var tree: Resource = ClassDB.instantiate("BehaviorTree")
	tree.set("description", label)
	var root: Resource = ClassDB.instantiate("BTSelector")
	root.set("custom_name", label)
	for branch: Array in list:
		var sequence: Resource = ClassDB.instantiate("BTSequence")
		sequence.set("custom_name", str(branch[1]).capitalize())
		for condition: Array in branch[0]:
			var check: Resource = ClassDB.instantiate("BTCheckVar")
			check.set("variable", StringName(condition[0]))
			check.set("check_type", 0)  # LimboUtility.CHECK_EQUAL
			var value: Resource = ClassDB.instantiate("BBVariant")
			value.set("type", TYPE_BOOL)
			value.set("saved_value", bool(condition[1]))
			check.set("value", value)
			sequence.call("add_child", check)
		var leaf: Resource = ClassDB.instantiate("BTCallMethod")
		leaf.set("custom_name", "Choose %s" % str(branch[1]))
		var node: Resource = ClassDB.instantiate("BBNode")
		node.set("value_source", 1)  # BBParam.BLACKBOARD_VAR
		node.set("variable", &"foe")
		leaf.set("node", node)
		leaf.set("method", &"_bt_choose")
		var arg: Resource = ClassDB.instantiate("BBVariant")
		arg.set("type", TYPE_STRING)
		arg.set("saved_value", str(branch[1]))
		leaf.set("args", [arg])
		sequence.call("add_child", leaf)
		root.call("add_child", sequence)
	tree.call("set_root_task", root)
	return tree


func _build_brain() -> Node:
	var tree := build_tree("%s: %s" % [kind, foe_id], branches())
	if tree == null:
		return null
	var player: Node = ClassDB.instantiate("BTPlayer")
	player.name = "Brain"
	player.set("update_mode", 2)  # BTPlayer.MANUAL: ticked from `think`
	player.set("behavior_tree", tree)
	player.call("set_scene_root_hint", self)
	add_child(player)
	return player


# --- Wind-ups and blows. ---------------------------------------------------------

## Starts a telegraphed blow. `spec`: windup (s), colour, parryable,
## blockable, plus whatever `land` reads back from `move`.
func begin(move_id: String, spec: Dictionary) -> void:
	winding = move_id
	move = spec
	windup = 0.0
	windup_needed = float(spec.get("windup", 0.5))
	telegraphs += 1
	_set_glint(spec.get("colour", COPPER))
	WorldHistory.record_event("v01_foe_telegraph", {"foe": foe_id, "move": move_id})
	var clip := str(spec.get("clip", ""))
	var rigged = body.get("rigged") if body != null else null
	if clip != "" and rigged != null:
		var length: float = rigged.player.get_animation(str(RiggedBody.CLIPS[clip])).length
		rigged.play_action(clip, clampf(length / maxf(windup_needed + float(spec.get("active", 0.12)), 0.1), 0.5, 3.0))


## Advances the wind-up; true on the frame it lands.
func advance(delta: float) -> bool:
	windup += delta
	var amount := clampf(windup / maxf(windup_needed, 0.01), 0.0, 1.0)
	_glow(amount)
	return windup >= windup_needed


func cancel_windup() -> void:
	winding = ""
	windup = 0.0
	move = {}
	_set_glint(Color.BLACK)


## The player's parry turned this blow aside: it stands open.
func on_parried(open_for: float) -> void:
	parried_by_player += 1
	cancel_windup()
	parried_left = open_for
	stagger_left = 0.0
	_recoil = 1.0
	var rigged = body.get("rigged") if body != null else null
	if rigged != null:
		rigged.play_action("hit_front", 0.8)
	WorldHistory.record_event("v01_foe_parried", {"foe": foe_id})


func reeling() -> bool:
	return stagger_left > 0.0 or parried_left > 0.0


## Counts a blow against health and poise and leaves its wound on the body.
func _wound_and_count(packet: Dictionary, damage: float) -> Dictionary:
	if state == "dead":
		return {"result": "miss", "damage": 0.0}
	hits_taken += 1
	health = maxf(0.0, health - damage)
	poise -= int(packet.get("poise", 1))
	_recoil = clampf(damage / 40.0, 0.3, 1.0)
	if poise <= 0 or bool(packet.get("breaks_poise", false)):
		poise = max_poise
		stagger(float(packet.get("stagger", 0.55)))
	_mark_body(packet, damage)
	if state == "idle":
		alert(host.player_body().global_position if host != null else global_position)
	WorldHistory.record_event("v01_foe_hit", {"foe": foe_id, "weapon": str(packet.get("weapon", "")), "damage": snappedf(damage, 0.1), "left": snappedf(health, 0.1)})
	if health <= 0.0:
		kill(str(packet.get("weapon", "")))
	return {"result": "hit", "damage": damage}


func stagger(seconds: float) -> void:
	# A reel cuts any wind-up short: that is what a heavy hit is for.
	cancel_windup()
	stagger_left = maxf(stagger_left, seconds)
	var rigged = body.get("rigged") if body != null else null
	if rigged != null:
		rigged.play_action("hit_front", 1.2)


## The wound on the real anatomy, held short of dropping it (its fight owns
## its death).
func _mark_body(packet: Dictionary, damage: float) -> void:
	if not (body is BaselineHuman):
		return
	var rig := body as BaselineHuman
	var anatomy := rig.anatomy
	if anatomy == null:
		return
	var zone := str(packet.get("zone", "torso"))
	var blood_before := float(anatomy.get("blood_remaining"))
	var direction: Vector3 = packet.get("direction", Vector3.ZERO)
	rig.hit(zone, damage * 0.5, float(packet.get("impulse", 2.0)), str(packet.get("kind", "blunt")), "", direction)
	if health > 0.0 and (anatomy.dead or anatomy.downed):
		anatomy.dead = false
		anatomy.downed = false
		anatomy.blood_remaining = maxf(blood_before * 0.9, anatomy.blood_capacity * 0.5)


func alert(at: Vector3) -> void:
	alert_at = at
	if state == "idle":
		state = "alert"
		WorldHistory.record_event("v01_foe_alerted", {"foe": foe_id})


func kill(cause: String) -> void:
	if state == "dead":
		return
	state = "dead"
	cancel_windup()
	stagger_left = 0.0
	parried_left = 0.0
	_die_body(cause)
	WorldHistory.update_subject(foe_id, {"status": "dead", "x": global_position.x, "y": global_position.y, "z": global_position.z, "killed_by": cause}, "v01_foe_killed")
	died.emit(self)


func _die_body(cause: String) -> void:
	if body is BaselineHuman and (body as BaselineHuman).anatomy != null:
		(body as BaselineHuman).anatomy.finish("killed by the player's %s" % (cause if cause != "" else "hands"))


func _restore_dead(record: Dictionary) -> void:
	state = "dead"
	health = 0.0
	global_position = Vector3(float(record.get("x", global_position.x)), float(record.get("y", global_position.y)), float(record.get("z", global_position.z)))
	_die_body(str(record.get("killed_by", "")))


# --- Moving. ----------------------------------------------------------------------

func face(toward: Vector3, weight: float) -> void:
	if toward.length_squared() < 0.0001 or body == null:
		return
	body.rotation.y = lerp_angle(body.rotation.y, atan2(-toward.x, -toward.z), clampf(weight, 0.0, 1.0))


## A step on the floor, kept inside its area and out of the avoid circles.
func walk(motion: Vector3) -> void:
	var next := global_position + Vector3(motion.x, 0.0, motion.z)
	for circle: Array in avoid:
		var centre: Vector3 = circle[0]
		var radius: float = circle[1]
		var off := Vector2(next.x - centre.x, next.z - centre.z)
		if off.length() < radius:
			off = off.normalized() * radius if off.length() > 0.001 else Vector2(radius, 0.0)
			next.x = centre.x + off.x
			next.z = centre.z + off.y
	next.x = clampf(next.x, area_min.x, area_max.x)
	next.z = clampf(next.z, area_min.y, area_max.y)
	next.y = floor_y
	global_position = next


func forward() -> Vector3:
	return Vector3(-sin(body.rotation.y), 0.0, -cos(body.rotation.y)) if body != null else Vector3.FORWARD


# --- Telegraph light and lines. ------------------------------------------------------

## The node the glint sits on (the weapon head); the body centre by default.
func glint_anchor() -> Node3D:
	return body


func _build_glint() -> void:
	_glint = OmniLight3D.new()
	_glint.name = "TelegraphGlint"
	_glint.omni_range = 2.4
	_glint.light_energy = 0.0
	_glint.visible = false
	_glint.shadow_enabled = false
	add_child(_glint)


func _set_glint(colour: Color) -> void:
	var lit := colour != Color.BLACK
	for material: StandardMaterial3D in _glow_materials:
		material.emission = colour if lit else Color.BLACK
		material.emission_energy_multiplier = 0.0
	if _glint == null:
		return
	_glint.light_color = colour
	_glint.light_energy = 0.0
	_glint.visible = lit
	_follow_glint()


func _glow(amount: float) -> void:
	for material: StandardMaterial3D in _glow_materials:
		material.emission_energy_multiplier = 2.0 + amount * 9.0
	if _glint != null and _glint.visible:
		# A sharp flash as the wind-up starts (the cue you react to), then a
		# steady build to the blow.
		var flash := 4.0 * maxf(0.0, 1.0 - amount / 0.15)
		_glint.light_energy = 0.9 + amount * 3.5 + flash
		_follow_glint()


func _follow_glint() -> void:
	var anchor := glint_anchor()
	if _glint != null and anchor != null and anchor.is_inside_tree():
		_glint.global_position = anchor.global_position


## A short flash of its own (a block, a parry, a call): BONE by default.
func flash(colour: Color = BONE, energy := 5.0) -> void:
	if _glint == null:
		return
	_glint.light_color = colour
	_glint.visible = true
	_glint.light_energy = energy
	_follow_glint()
	var tween := create_tween()
	tween.tween_property(_glint, "light_energy", 0.0, 0.25)
	tween.tween_callback(func() -> void:
		if winding == "":
			_glint.visible = false)


## A small material that glows with the telegraph (a staff head, an eye).
func glow_material(base: Color, metallic := 0.6) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = base
	material.metallic = metallic
	material.roughness = 0.4
	material.emission_enabled = true
	material.emission = Color.BLACK
	_glow_materials.append(material)
	return material
