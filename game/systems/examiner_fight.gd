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
## Placeholder body and tools (a BaselineHuman dressed by `ExaminerLook`, a
## box scalpel and syringe); his moves are timed wind-ups you can read and
## step out of.

const LOOK := preload("res://systems/examiner_look.gd")
const CARRY := preload("res://systems/carry.gd")
const CLOTHING := preload("res://systems/clothing.gd")
const VAT_REBIRTH := preload("res://systems/vat_rebirth.gd")

const SUBJECT := "examiner_fight"
const LOCATION := "examination_room"
const KEYCARD := "STAFF KEYCARD"
const COAT := "examiner_coat"

const HEALTH := 100.0
## What each thing you can hit him with takes off him.
const DAMAGE := {"axe": 30.0, "restraint": 16.0, "": 9.0, "gun": 45.0}
const PLAYER_REACH := 2.3
const REACH := 1.45
const SPEED := 2.3
const NOTICE_DISTANCE := 2.6
const NOTICE_LINGER := 10.0
const TURN_SECONDS := 1.4
const COOLDOWN := 1.25
const SCALPEL_WINDUP := 0.5
const SYRINGE_WINDUP := 0.85
## A scalpel cut: a real cut on the anatomy plus 6% of your blood.
const SCALPEL_DAMAGE := 11.0
const SCALPEL_BLOOD := 0.06
const SYRINGE_DAMAGE := 5.0
const SYRINGE_SLOW := 6.0
const STAGGER := 0.45
## Lose when your blood is under this share, or your body goes down.
const LOSE_AT := 0.45

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
var _fall := 0.0


## `owner_route` is the DoctorRoute (for its room bounds and `_can_act`).
func setup(owner_route: Node3D, bench_at: Vector3, room_x: Vector2, room_z: Vector2) -> void:
	name = "ExaminerFight"
	route = owner_route
	chamber = owner_route.get("chamber")
	room_min = Vector2(room_x.x + 0.45, room_z.x + 0.6)
	room_max = Vector2(room_x.y - 0.45, room_z.y - 0.5)
	body = BaselineHuman.new()
	body.name = "OfficeExaminer"
	add_child(body)
	body.build("office_examiner", BaselineHuman.config_from_subject({"race": "decanted"}).merged({"gore": true}, true))
	var appearance := HunterAppearance.new()
	body.add_child(appearance)
	appearance.configure(body, {"axes": {"brow": 0.7, "jaw": 0.6, "cheek": 0.2, "eyes": 0.3, "nose": 0.55, "mouth": 0.4}})
	mask = LOOK.dress(body, false)
	scalpel = _tool(body.parts.get("right_arm") as Node3D, Vector3(0.012, 0.012, 0.16), Color("c9ccc8"), 0.6)
	syringe = _tool(body.parts.get("left_arm") as Node3D, Vector3(0.022, 0.022, 0.14), Color("dfe8e0"), 0.1)
	var record := WorldHistory.subject(SUBJECT)
	if str(record.get("status", "")) == "won":
		# Beaten: he is where he fell, coatless.
		state = "won"
		position = Vector3(float(record.get("x", bench_at.x + 0.8)), 0.0, float(record.get("z", bench_at.z)))
		_lie_down(1.0)
		return
	# At his bench, his back to the door, working.
	position = bench_at + Vector3(0.8, 0.0, 0.0)
	body.rotation.y = -PI * 0.5
	_build_bar()


func is_active() -> bool:
	return state in ["idle", "noticed", "fighting"]


## A click from the player in his room. True when it was used on him.
func player_strike(weapon: String) -> bool:
	if not is_active() or chamber == null:
		return false
	var player: Node3D = chamber.player
	var to_him := global_position - player.global_position
	to_him.y = 0.0
	if to_him.length() > PLAYER_REACH:
		return false
	var forward: Vector3 = -chamber.camera.global_transform.basis.z
	forward.y = 0.0
	if forward.normalized().dot(to_him.normalized()) < 0.55:
		return false
	var damage: float = DAMAGE.get(weapon, DAMAGE[""])
	health = maxf(0.0, health - damage)
	hits_landed += 1
	stagger_left = STAGGER
	winding = ""
	windup = 0.0
	# His body shows the hit where it lands (the rig's own wound and blood).
	body.hit("torso" if hits_landed % 2 == 1 else "right_arm", damage * 0.5, 2.0, "cut" if weapon == "axe" else "blunt")
	if chamber.get("breach_shake") != null:
		chamber.breach_shake = maxf(float(chamber.breach_shake), 0.18)
	WorldHistory.record_event("examiner_fight_hit", {"weapon": weapon if weapon != "" else "fists", "damage": damage, "left": health})
	if state == "idle":
		_notice()
	if health <= 0.0:
		_win()
	_update_bar()
	return true


func _physics_process(delta: float) -> void:
	if state == "won":
		if _fall < 1.0:
			_fall = minf(1.0, _fall + delta * 1.6)
			_lie_down(_fall)
		return
	if not is_active() or chamber == null or route == null or not bool(route.call("_can_act")):
		return
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
				_say("HE COMES AT YOU  //  CLICK TO HIT HIM  //  HOLD 4 TO DRESS A WOUND")
		"fighting":
			_fight(delta, to_player, distance)


func _fight(delta: float, to_player: Vector3, distance: float) -> void:
	if _player_beaten():
		_lose()
		return
	_face(to_player, delta * 6.0)
	if stagger_left > 0.0:
		stagger_left = maxf(0.0, stagger_left - delta)
		# Knocked back a step.
		_step(-to_player.normalized() * 1.2 * delta)
		_pose(0.0, 0.0)
		return
	if winding != "":
		windup += delta
		var needed := SYRINGE_WINDUP if winding == "syringe" else SCALPEL_WINDUP
		_pose(windup / needed, 0.0)
		if windup >= needed:
			_land(winding, distance)
			winding = ""
			windup = 0.0
			attack_clock = 0.0
		return
	attack_clock += delta
	if distance > REACH:
		walk_phase += delta * 8.0
		_step(to_player.normalized() * SPEED * delta)
		_pose(0.0, 1.0)
	else:
		_pose(0.0, 0.0)
		if attack_clock >= COOLDOWN:
			attacks_made += 1
			winding = "syringe" if attacks_made % 3 == 0 else "scalpel"
			windup = 0.0


## The blow lands if you are still in reach when the wind-up ends.
func _land(kind: String, distance: float) -> void:
	_pose(0.0, 0.0)
	if distance > REACH + 0.35:
		_say("HE MISSES")
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
	if chamber.get("breach_shake") != null:
		chamber.breach_shake = maxf(float(chamber.breach_shake), 0.3)
	WorldHistory.record_event("examiner_fight_wound", {"tool": kind})


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
	WorldHistory.update_subject(SUBJECT, {"kind": "fight", "status": "fighting", "losses": int(WorldHistory.subject(SUBJECT).get("losses", 0))}, "examiner_fight_started")
	if bar != null:
		bar.visible = true
	_update_bar()


func _win() -> void:
	state = "won"
	winding = ""
	var carry := CARRY.new()
	carry.items.append({"label": KEYCARD, "kind": "key", "mass": 0.05, "perishes": false, "age": 0.0, "opens": "staff_door"})
	carry.save_to_history()
	CLOTHING.wear("player", COAT)
	WorldHistory.update_subject(SUBJECT, {"status": "won", "x": global_position.x, "z": global_position.z, "coat": "player"}, "examiner_beaten")
	WorldHistory.record_event("examiner_keycard_taken", {"location": LOCATION})
	_say("HE GOES DOWN  //  HIS KEYCARD AND HIS COAT ARE YOURS  //  THE STAFF DOOR")
	if bar != null:
		bar.visible = false


func _lose() -> void:
	state = "lost"
	var losses := int(WorldHistory.subject(SUBJECT).get("losses", 0)) + 1
	WorldHistory.update_subject(SUBJECT, {"status": "lost", "losses": losses, "coat": "examiner"}, "examiner_fight_lost")
	_say("HE PUTS YOU DOWN  //  HE KEEPS HIS COAT")
	if bar != null:
		bar.visible = false
	var at: Vector3 = chamber.player.global_position
	at.y = 0.0
	var request := VAT_REBIRTH.die(LOCATION, "the examiner's scalpel", "the_examiner", at)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if OS.get_environment("ATG_TEST_MODE") != "1":
		Interstitial.travel(str(request.scene), "he puts you back // %s grows you again" % str(request.vat.label).to_lower())


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
	mesh.material = material
	tool.mesh = mesh
	tool.position = Vector3(0.0, -0.36, -0.08)
	arm.add_child(tool)
	return tool


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
