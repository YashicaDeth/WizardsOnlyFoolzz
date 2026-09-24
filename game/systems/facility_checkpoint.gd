class_name FacilityCheckpoint
extends Node3D

## Vertebra 5 of the Dust to Bones spine, the biometric door:
## "The facility authenticates tissue, not consent. Coerce a living guard, drag
## an unconscious one, bring a dead one, or bring only the hand."
##
## `BiometricBarrier` and `FacilityGuardLoadout` were written and tested and
## nothing placed them. This places both as one guard at one gate with one
## first gun, which is the whole of the vertebra:
##
## - **Coerce.** Get behind him unseen (crouch), E puts the restraint's sheared
##   edge to his throat, and he walks you to his own reader.
## - **Drag.** Club him from behind (click) and drag him to the reader.
## - **Dead.** Keep hitting him once he is down. The reader does not care.
## - **The hand.** X saws his arm off with the same edge. The reader only wanted
##   the hand.
##
## If he sees you first he draws. He has three rounds and two will put you on
## the grating, and then he walks over and finishes it. Each round he fires is
## one fewer in the gun you take off him, because a round is an object.
##
## Self-contained on purpose so it can move between scenes: the owner places
## it at the gate, calls `bind_player()`, forwards E / X / click, sets
## `active`, and asks `prompt()` and `status_text()` what to show.

const BODY := preload("res://systems/baseline_human.gd")
const BARRIER := preload("res://systems/biometric_barrier.gd")
const LOADOUT := preload("res://systems/facility_guard_loadout.gd")
const ARSENAL := preload("res://systems/hunter_arsenal.gd")
const CARRY := preload("res://systems/carry.gd")
const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")

signal opened(method: String)
signal message(text: String)

const GUARD_ID := "guard_hollis"
const RESTRAINT_LABEL := "BROKEN MEDICAL RESTRAINT"
const GUN_LABEL := "CELL OUTZ BREACH NINE"
const ARM_LABEL := "HOLLIS'S RIGHT ARM"

const DOOR_WIDTH := 3.4
const DOOR_HEIGHT := 3.0
const GUARD_POST := Vector3(0.4, 0.0, 1.9)
const READER_AT := Vector3(2.3, 1.35, 0.26)

const SIGHT_RANGE := 13.0
## Facing dot above which he can see you. About 63 degrees either side.
const SIGHT_CONE := 0.45
const REACH := 1.8
const READER_REACH := 2.2
## One watch cycle: up the aisle, turn, check his reader, turn back.
const WATCH_SECONDS := 5.5
const CHECK_SECONDS := 3.0
const CYCLE_SECONDS := 9.4

const SHOT_DAMAGE := 52.0
const DRAW_SECONDS := 0.9
const SHOT_INTERVAL := 1.3
const STRIKE_COOLDOWN := 0.55
const EXECUTE_DELAY := 1.6
const GUARD_WALK := 1.6

var active := false
var is_open := false
var guard: Node3D
var barrier: Node3D
var loadout
var arsenal: Node
var awareness := 0.0
## post, alert, coerced, down, dead, released
var state := "post"
var dragging := false
var carrying_arm := false
var arm_taken := false
var gun_taken := false

var _player: Node3D
var _player_anatomy: Node
var _door: StaticBody3D
var _door_shape: CollisionShape3D
var _reader_light: OmniLight3D
var _readout: Label3D
var _muzzle: OmniLight3D
var _gun_mesh: MeshInstance3D
var _post_clock := 0.0
var _fire_clock := 0.0
var _strike_cooldown := 0.0
var _execute_clock := 0.0
var _flash := 0.0
var _announced := false
var _rng := RandomNumberGenerator.new()


## `half_width` and `height` are the corridor's inner half-width and ceiling,
## so the gate closes the aisle wall to wall and nobody walks around it.
func build(half_width: float, height: float) -> void:
	_rng.seed = hash(GUARD_ID)
	_build_gate(half_width, height)
	_build_reader()
	_build_guard()
	arsenal = ARSENAL.new()
	arsenal.name = "TakenGuns"
	add_child(arsenal)


func bind_player(player: Node3D, player_anatomy: Node) -> void:
	_player = player
	_player_anatomy = player_anatomy


func _build_gate(half_width: float, height: float) -> void:
	var side := half_width - DOOR_WIDTH * 0.5
	for sign in [-1.0, 1.0]:
		_slab(Vector3(side, height, 0.4), Vector3(sign * (DOOR_WIDTH * 0.5 + side * 0.5), height * 0.5, 0.0), "rust", Color("1f1a14"))
	_slab(Vector3(DOOR_WIDTH, height - DOOR_HEIGHT, 0.4), Vector3(0, DOOR_HEIGHT + (height - DOOR_HEIGHT) * 0.5, 0.0), "rust", Color("1f1a14"))
	_door = _slab(Vector3(DOOR_WIDTH - 0.1, DOOR_HEIGHT, 0.24), Vector3(0, DOOR_HEIGHT * 0.5, 0.0), "rust", Color("3a3f3a"))
	_door.name = "BiometricDoor"
	_door_shape = _door.get_child(1) as CollisionShape3D
	# A hazard stripe so the door reads as the thing that opens.
	var stripe := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(DOOR_WIDTH - 0.2, 0.18, 0.02)
	bar.material = WorldLook.surface(Color("a8741a"), "paint", 57)
	stripe.mesh = bar
	stripe.position = Vector3(0, 0.6, 0.14)
	_door.add_child(stripe)


func _build_reader() -> void:
	barrier = BARRIER.new()
	barrier.name = "Reader"
	var cleared: Array[String] = [GUARD_ID]
	barrier.authorized_subject_ids = cleared
	barrier.position = READER_AT
	add_child(barrier)
	barrier.access_granted.connect(_on_access_granted)
	var housing := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.34, 0.46, 0.1)
	box.material = WorldLook.surface(Color("2a2d2b"), "paint", 58)
	housing.mesh = box
	barrier.add_child(housing)
	var palm := MeshInstance3D.new()
	var plate := BoxMesh.new()
	plate.size = Vector3(0.22, 0.26, 0.02)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("7a1d14")
	glass.emission_enabled = true
	glass.emission = Color("c8281a")
	glass.emission_energy_multiplier = 1.4
	plate.material = glass
	palm.mesh = plate
	palm.name = "Palm"
	palm.position = Vector3(0, -0.02, 0.06)
	barrier.add_child(palm)
	_reader_light = OmniLight3D.new()
	_reader_light.position = Vector3(0, 0, 0.3)
	_reader_light.light_color = Color("c8281a")
	_reader_light.light_energy = 1.6
	_reader_light.omni_range = 2.6
	barrier.add_child(_reader_light)
	_readout = Label3D.new()
	_readout.position = Vector3(0, 0.48, 0.08)
	_readout.pixel_size = 0.0055
	_readout.font_size = 32
	_readout.modulate = Color("e6d4ac")
	_readout.outline_size = 6
	_readout.text = barrier.last_readout
	barrier.add_child(_readout)


func _build_guard() -> void:
	WorldHistory.register_subject(GUARD_ID, {
		"name": "HOLLIS", "kind": "person", "role": "D-section barrier guard",
		"faction": "CellOutz", "status": "on post",
		"memory": "Keeps the tissue-keyed gate off the Growing Floor. Three rounds, and he counts them.",
	})
	guard = BODY.new()
	guard.name = "GuardHollis"
	guard.build(GUARD_ID, {"variation": 3, "flesh": Color("5c4a3a")})
	guard.position = GUARD_POST
	guard.rotation.y = PI
	add_child(guard)
	loadout = LOADOUT.new(GUARD_ID)
	loadout.attach_to(guard)
	# Placeholder kit, primitives on the palette like the rest of the floor:
	# a visor so he reads as staff, and the gun you are about to want.
	var head_anchor: Node3D = guard.get("head_anchor")
	if head_anchor != null:
		var visor := MeshInstance3D.new()
		var band := BoxMesh.new()
		band.size = Vector3(0.3, 0.08, 0.3)
		band.material = WorldLook.surface(Color("1b2226"), "paint", 59)
		visor.mesh = band
		visor.position = Vector3(0, -0.13, -0.03)
		head_anchor.add_child(visor)
	var hand: Node3D = (guard.get("parts") as Dictionary).get("right_arm")
	_gun_mesh = MeshInstance3D.new()
	var frame := BoxMesh.new()
	frame.size = Vector3(0.06, 0.13, 0.22)
	frame.material = WorldLook.surface(Color("16181a"), "paint", 60)
	_gun_mesh.mesh = frame
	_gun_mesh.name = "Sidearm"
	if hand != null:
		_gun_mesh.position = hand.position + Vector3(0.02, -0.32, -0.1)
	guard.add_child(_gun_mesh)
	_muzzle = OmniLight3D.new()
	_muzzle.position = _gun_mesh.position + Vector3(0, 0, -0.2)
	_muzzle.light_color = Color("ffc070")
	_muzzle.light_energy = 0.0
	_muzzle.omni_range = 7.0
	guard.add_child(_muzzle)
	guard.get("anatomy").went_down.connect(_on_guard_went_down)
	guard.get("anatomy").died.connect(_on_guard_died)


func _slab(dimensions: Vector3, at: Vector3, kind: String, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	box.material = WorldLook.surface(color, kind, int(at.x * 29.0 + at.y * 13.0) + 61)
	mesh_instance.mesh = box
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	return body


func _physics_process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	_muzzle.light_energy = 7.0 if _flash > 0.0 else 0.0
	_strike_cooldown = maxf(0.0, _strike_cooldown - delta)
	_readout.text = barrier.last_readout
	if _player == null or not active:
		return
	match state:
		"post":
			_update_post(delta)
		"alert":
			_update_alert(delta)
		"coerced":
			_walk_ahead_of_player()
	if dragging:
		_drag_behind_player(delta)


# --- What he does.

func _update_post(delta: float) -> void:
	_post_clock = fmod(_post_clock + delta, CYCLE_SECONDS)
	var target := Vector3(0, 0, 1)
	if _post_clock >= WATCH_SECONDS + 0.45 and _post_clock < WATCH_SECONDS + 0.45 + CHECK_SECONDS:
		target = (READER_AT - GUARD_POST) * Vector3(1, 0, 1)
	_turn_toward(target, delta * 3.2)
	var to_player := _flat(_player.global_position - guard.global_position)
	var distance := to_player.length()
	if not _announced and distance < SIGHT_RANGE + 4.0:
		_announced = true
		message.emit("D-SECTION  //  TISSUE-KEYED GATE  //  ONE GUARD, AND HE IS ARMED")
	var crouched := Input.is_action_pressed("crouch")
	var gain := 0.0
	if distance < SIGHT_RANGE and _facing().dot(to_player.normalized()) > SIGHT_CONE:
		gain = (1.4 - distance / SIGHT_RANGE) * (0.35 if crouched else 1.0) * 0.9
	# He hears a body that is not creeping, whichever way he is looking.
	var moving := _player is CharacterBody3D and (_player as CharacterBody3D).velocity.length() > 0.6
	if distance < 2.4 and moving and not crouched:
		gain += 0.9
	if gain > 0.0:
		awareness = minf(1.0, awareness + gain * delta)
	else:
		awareness = maxf(0.0, awareness - 0.22 * delta)
	if awareness >= 1.0:
		_alert()


func _alert() -> void:
	if state != "post":
		return
	state = "alert"
	awareness = 1.0
	_fire_clock = DRAW_SECONDS
	WorldHistory.amend_subject(GUARD_ID, {"status": "alerted"})
	message.emit("HOLLIS: \"Back in the tank. BACK IN THE TANK.\"")


func _update_alert(delta: float) -> void:
	var to_player := _flat(_player.global_position - guard.global_position)
	var distance := to_player.length()
	_turn_toward(to_player, delta * 6.0)
	var rounds := int(guard.get_meta("facility_rounds", 0))
	if bool(_player_anatomy.get("dead")):
		return
	if bool(_player_anatomy.get("downed")):
		# He does not leave it there.
		if distance > 1.3:
			guard.position += to_player.normalized() * GUARD_WALK * delta
			return
		_execute_clock += delta
		if _execute_clock >= EXECUTE_DELAY:
			message.emit("HOLLIS FINISHES IT")
			_player_anatomy.call("finish", "executed at the D-section gate")
		return
	_execute_clock = 0.0
	_fire_clock -= delta
	if rounds > 0:
		if _fire_clock <= 0.0:
			_fire(distance)
		return
	# Out of rounds: he comes and does it by hand.
	if distance > 1.3:
		guard.position += to_player.normalized() * GUARD_WALK * delta
	elif _fire_clock <= 0.0:
		_fire_clock = 1.4
		_player_anatomy.call("apply_hit", "head", 20.0, 6.0, "blunt")
		message.emit("HOLLIS HITS YOU WITH THE EMPTY GUN")


func _fire(distance: float) -> void:
	_fire_clock = SHOT_INTERVAL
	var rounds := int(guard.get_meta("facility_rounds", 0)) - 1
	guard.set_meta("facility_rounds", rounds)
	_flash = 0.07
	var chance := clampf(0.9 - distance * 0.035, 0.3, 0.9)
	var hit := _rng.randf() < chance
	if hit:
		_player_anatomy.call("apply_hit", "torso", SHOT_DAMAGE, 30.0, "ballistic")
	WorldHistory.record_event("facility_guard_fired", {"subject_id": GUARD_ID, "hit": hit, "rounds_left": rounds})
	var count := "%d LEFT" % rounds if rounds > 0 else "HE IS EMPTY"
	message.emit(("HOLLIS FIRES  //  HIT  //  " if hit else "HOLLIS FIRES  //  MISS  //  ") + count)


func _walk_ahead_of_player() -> void:
	var forward := _player_forward()
	guard.position = to_local(_player.global_position) * Vector3(1, 0, 1) + forward * 0.95
	guard.rotation.y = atan2(-forward.x, -forward.z)


func _drag_behind_player(delta: float) -> void:
	var anchor := to_local(_player.global_position) * Vector3(1, 0, 1) - _player_forward() * 1.35
	guard.position = guard.position.lerp(anchor, clampf(delta * 6.0, 0.0, 1.0))
	var toward := _flat(_player.global_position - guard.global_position)
	if toward.length() > 0.05:
		guard.rotation.y = atan2(toward.x, toward.z)


func _on_guard_went_down() -> void:
	if state == "dead":
		return
	state = "down"
	WorldHistory.amend_subject(GUARD_ID, {"status": "downed"})


func _on_guard_died(_report: Dictionary) -> void:
	state = "dead"
	WorldHistory.amend_subject(GUARD_ID, {"status": "dead"})


# --- What the player does. Each returns true if it consumed the input.

## E. Coerce, take the gun, drag, present — whichever the moment is for.
func interact() -> bool:
	if _player == null or not active:
		return false
	# Taking him comes first: his post is within reach of his own reader, and
	# the player standing behind him means him, not the glass.
	if _near_guard() and state == "post" and _behind_guard() and _carries_restraint():
		state = "coerced"
		guard.set_meta("disarmed", true)
		WorldHistory.amend_subject(GUARD_ID, {"status": "coerced"})
		PLAYER_ACTION_LEDGER.record("facility_guard_coerced", {"subject_id": GUARD_ID})
		message.emit("THE SHEARED EDGE AT HIS THROAT  //  HOLLIS: \"Easy. Easy. It only wants my hand.\"")
		return true
	if not is_open and _near_reader():
		return _present()
	if _near_guard():
		if state in ["coerced", "released", "down", "dead"] and not gun_taken:
			return _take_gun()
		if state in ["down", "dead"] and not is_open:
			dragging = not dragging
			message.emit("YOU DRAG HIM BY THE COLLAR" if dragging else "YOU LET HIM DROP")
			return true
	return false


## Click. The restraint as a club.
func strike() -> bool:
	if _player == null or not active or _strike_cooldown > 0.0:
		return false
	if not _carries_restraint() or not _near_guard() or state == "dead":
		return false
	_strike_cooldown = STRIKE_COOLDOWN
	var direction := _flat(guard.global_position - _player.global_position).normalized()
	if state in ["down", "coerced"] and bool(guard.get("anatomy").downed):
		guard.call("execute", "beaten to death with a medical restraint")
		PLAYER_ACTION_LEDGER.record("facility_guard_killed", {"subject_id": GUARD_ID})
		message.emit("YOU KEEP HITTING HIM UNTIL HE STOPS")
		return true
	var unseen := state in ["post", "coerced"] and _behind_guard()
	# One blow he never saw drops him (45 measured as the first that does);
	# one he sees coming takes three, and he is shooting while you land them.
	guard.call("hit", "head", 45.0 if unseen else 18.0, 6.0, "blunt", "", direction)
	if state in ["coerced", "released"]:
		state = "post"
	if not bool(guard.get("anatomy").downed):
		_alert()
		message.emit("THE RESTRAINT CRACKS OFF HIS SKULL  //  HE IS STILL UP")
	else:
		PLAYER_ACTION_LEDGER.record("facility_guard_downed", {"subject_id": GUARD_ID, "unseen": unseen})
		message.emit("HE GOES DOWN ON THE GRATING")
	return true


## X. Only the hand.
func take_arm() -> bool:
	if _player == null or not active or arm_taken:
		return false
	if not (state in ["down", "dead"]) or not _near_guard() or not _carries_restraint():
		return false
	var direction := _player_forward().cross(Vector3.UP)
	for attempt in 8:
		guard.call("hit", "right_arm", 60.0, 10.0, "cut", "", direction, 1.0)
		if (guard.get("severed") as Array).has("right_arm"):
			break
	if not (guard.get("severed") as Array).has("right_arm"):
		return false
	arm_taken = true
	carrying_arm = true
	dragging = false
	_add_item({"label": ARM_LABEL, "kind": "body_part", "mass": 3.6, "perishes": true, "age": 0.0,
		"from": GUARD_ID, "subject_id": GUARD_ID, "zone": "right_hand"})
	PLAYER_ACTION_LEDGER.record("facility_guard_arm_taken", {"subject_id": GUARD_ID})
	message.emit("THE SHEARED EDGE TAKES A LONG TIME  //  YOU HAVE HIS HAND, AND THE REST OF THE ARM")
	return true


func _take_gun() -> bool:
	var taken: Dictionary = loadout.take_sidearm(guard, arsenal)
	if not bool(taken.get("accepted", false)):
		if str(taken.get("reason", "")) == "empty":
			gun_taken = true
			message.emit("HIS GUN IS EMPTY  //  HE SPENT ALL THREE ON YOU")
			return true
		return false
	gun_taken = true
	_gun_mesh.visible = false
	_add_item({"label": GUN_LABEL, "kind": "weapon", "weapon_id": "facility_sidearm",
		"rounds": int(taken.rounds), "mass": 1.1, "perishes": false, "age": 0.0, "from": GUARD_ID})
	message.emit("%s  //  %d ROUNDS, NO SPARES" % [GUN_LABEL, int(taken.rounds)])
	return true


func _present() -> bool:
	var result: Dictionary
	if state == "coerced":
		result = barrier.present_body(guard)
	elif dragging:
		result = barrier.present_body(guard)
	elif carrying_arm:
		result = barrier.present_anatomy({"subject_id": GUARD_ID, "zone": "right_hand"})
	else:
		# Your own hand, which the facility grew and does not recognise.
		result = barrier.present_anatomy({"subject_id": "player", "zone": "right_hand"})
		message.emit("YOUR PALM ON THE GLASS  //  %s" % barrier.last_readout)
	return true


func _on_access_granted(_subject_id: String, method: String) -> void:
	is_open = true
	dragging = false
	_door_shape.disabled = true
	create_tween().tween_property(_door, "position:y", DOOR_HEIGHT * 1.5 + 0.1, 1.4).set_trans(Tween.TRANS_QUAD)
	_reader_light.light_color = Color("5fd38a")
	var palm := barrier.get_node("Palm") as MeshInstance3D
	var glass := (palm.mesh as BoxMesh).material as StandardMaterial3D
	glass.emission = Color("5fd38a")
	var how := {
		"whole_body": "HIS BODY" if state != "coerced" else "HIS OWN PALM, UNDER DURESS",
		"removed_anatomy": "HIS HAND, WITHOUT HIM",
	}
	if state == "coerced":
		state = "released"
		WorldHistory.amend_subject(GUARD_ID, {"status": "let go at the gate"})
	PLAYER_ACTION_LEDGER.record("facility_gate_passed", {"barrier_id": barrier.barrier_id, "method": method, "guard_state": state})
	message.emit("IDENTITY ACCEPTED  //  THE GATE LIFTS FOR %s" % str(how.get(method, method)).to_upper())
	opened.emit(method)


# --- What the owner shows.

func prompt() -> String:
	if _player == null or not active:
		return ""
	var armed_and_close := _near_guard() and _carries_restraint()
	if armed_and_close and state == "post":
		if _behind_guard():
			return "[E] RESTRAINT TO HIS THROAT   //   [CLICK] CLUB HIM"
		return "[CLICK] CLUB HIM   //   HE CAN SEE YOU"
	if not is_open and _near_reader():
		if state == "coerced":
			return "[E] PRESS HIS PALM TO THE READER"
		if dragging:
			return "[E] PRESS HIS HAND TO THE READER"
		if carrying_arm:
			return "[E] PRESS THE SEVERED HAND TO THE READER"
		return "[E] TRY YOUR OWN HAND ON THE READER"
	if not armed_and_close:
		return ""
	match state:
		"alert":
			return "[CLICK] CLUB HIM"
		"coerced", "released":
			if not gun_taken:
				return "[E] TAKE HIS SIDEARM"
			return "WALK HIM TO THE READER   //   [CLICK] CLUB HIM" if state == "coerced" else ""
		"down", "dead":
			if not gun_taken:
				return "[E] TAKE HIS SIDEARM"
			var parts: Array[String] = []
			if not is_open:
				parts.append("[E] LET HIM DROP" if dragging else "[E] DRAG HIM")
			if not arm_taken:
				parts.append("[X] SAW OFF HIS HAND")
			if state == "down":
				parts.append("[CLICK] FINISH HIM")
			return "   //   ".join(parts)
	return ""


func status_text() -> String:
	match state:
		"post":
			if awareness <= 0.02:
				return "HOLLIS: UNAWARE"
			var bars := int(ceil(awareness * 5.0))
			return "HOLLIS: " + "#".repeat(bars) + "-".repeat(5 - bars)
		"alert":
			return "HOLLIS: ALERTED  //  %d ROUNDS" % int(guard.get_meta("facility_rounds", 0))
		"coerced":
			return "HOLLIS: AT YOUR MERCY"
		"down":
			return "HOLLIS: DOWN"
		"dead":
			return "HOLLIS: DEAD"
		"released":
			return "HOLLIS: LET GO"
	return ""


## Movement multiplier: a whole man is heavy, an arm is not.
func burden() -> float:
	return 0.55 if dragging else 1.0


# --- Geometry helpers.

func _near_guard() -> bool:
	return _flat(guard.global_position - _player.global_position).length() <= REACH


func _near_reader() -> bool:
	return _flat(barrier.global_position - _player.global_position).length() <= READER_REACH


func _behind_guard() -> bool:
	var from_guard := _flat(_player.global_position - guard.global_position)
	if from_guard.length() < 0.01:
		return false
	return _facing().dot(from_guard.normalized()) < -0.25


func _facing() -> Vector3:
	var yaw := guard.rotation.y
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func _turn_toward(direction: Vector3, weight: float) -> void:
	var flat := _flat(direction)
	if flat.length() < 0.01:
		return
	var target := atan2(-flat.x, -flat.z)
	guard.rotation.y = lerp_angle(guard.rotation.y, target, clampf(weight, 0.0, 1.0))


func _player_forward() -> Vector3:
	var forward := _flat(-_player.global_transform.basis.z)
	return forward.normalized() if forward.length() > 0.01 else Vector3(0, 0, -1)


func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)


func _carries_restraint() -> bool:
	for entry in WorldHistory.subject("inventory").get("items", []):
		if entry is Dictionary and str((entry as Dictionary).get("label", "")) == RESTRAINT_LABEL:
			return true
	return false


func _add_item(item: Dictionary) -> void:
	var carry := CARRY.new()
	carry.items.append(item)
	carry.save_to_history()
