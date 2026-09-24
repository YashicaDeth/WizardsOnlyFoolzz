class_name FacilityGuardPost
extends Node3D

## AX route beat 5: the barrier and the gun, placed.
##
## `BiometricBarrier` and `FacilityGuardLoadout` were written and tested and
## had no production caller (Greg, 24 September: "the biometric door and the
## guard's gun first"). This is the post that owns both: one security door
## across the artery, one reader beside it, and one guard, Hollis, whose tissue
## opens the door and whose gun becomes the player's first firearm.
##
## Greg's rules for the encounter (PLAYER_DIRECTION_INTERVIEW_2026-09-18.md):
## the reader "admits coercing a living guard, presenting an unconscious/dead
## body or removing the required hand/finger/head"; the gun is "powerful but
## ammunition-starved". Both answers here are physical and both are recorded.
## Removing a hand needs a blade the facility has not handed over yet, so that
## answer waits; the barrier already accepts it.
##
## The host scene feeds this one call per frame and forwards E and LMB. It
## never reaches into the guard; it reads `door_open` and listens to `shot`.

signal shot(damage: float)
signal door_opened(method: String)

const BODY := preload("res://systems/baseline_human.gd")
const BARRIER := preload("res://systems/biometric_barrier.gd")
const LOADOUT := preload("res://systems/facility_guard_loadout.gd")
const CARRY := preload("res://systems/carry.gd")
const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")

const GUARD_ID := "guard_hollis"
const GUARD_NAME := "HOLLIS"
const GUN_LABEL := "CELL OUTZ BREACH NINE"
## The artery the post is built across: the Service Arcade's walls sit at
## x = +/-7.25, so the security wall spans exactly that and nothing leaks round
## its ends.
const ARTERY_HALF_WIDTH := 7.25
const DOOR_WIDTH := 3.0
const DOOR_HEIGHT := 3.6
const WALL_HEIGHT := 8.2
## Where he stands and where the reader hangs, in post-local space. The player
## approaches from +z.
const GUARD_AT := Vector3(2.3, 0.0, 1.3)
## Proud of the wall face (z = 0.25), or the wall swallows the readout.
const READER_AT := Vector3(2.05, 1.35, 0.42)
const WARN_RANGE := 11.0
const FIRE_RANGE := 7.5
const REACH := 2.4
const FIRE_COOLDOWN := 1.6
## Greg, 24 September: warning shots, then wounds, then lethal. One shot over
## your head, then every shot lands; six landed shots empty a fresh body.
const WARNING_SHOTS := 1
const SHOT_DAMAGE := 18.0
## One swing of the ram. Blunt, to the chest; three put a man down.
const RAM_DAMAGE := 55.0

var guard: Node3D
var barrier: Node3D
var loadout: RefCounted
var door_open := false
var coerced := false
var warned := false
var fire_cooldown := 0.0
var door_body: StaticBody3D
var door_panel: MeshInstance3D
var reader_label: Label3D
var speech: Label3D
var muzzle: OmniLight3D
var speech_timer := 0.0
var warning_shots_left := WARNING_SHOTS
## He has killed the player before and knows what comes back out of the vat.
var knows_player := false


func build() -> void:
	_build_wall()
	_build_reader()
	_build_guard()
	muzzle = OmniLight3D.new()
	muzzle.light_color = Color("ffb35a")
	muzzle.light_energy = 0.0
	muzzle.omni_range = 5.0
	muzzle.position = GUARD_AT + Vector3(0.3, 1.2, 0.4)
	add_child(muzzle)
	WorldHistory.register_subject(GUARD_ID, {
		"name": GUARD_NAME, "kind": "person", "role": "D-section door guard", "faction": "CellOutz Security",
		"status": "on post", "memory": "Holds the biometric door in the Service Arcade.",
	})
	_restore_from_history()


## The world does not rewind (Greg, 24 September): a player regrown in a vat
## walks back into the arcade Hollis left, not a fresh one. His body, his gun,
## his door and whether he has killed you before all come from the record.
func _restore_from_history() -> void:
	var record := WorldHistory.subject(GUARD_ID)
	var saved: Dictionary = record.get("anatomy_state", {})
	if not saved.is_empty():
		guard.anatomy.restore(saved)
		if guard.anatomy.downed or guard.anatomy.dead:
			guard.rotation.x = -PI * 0.46
	if str(record.get("status", "")) == "coerced":
		coerced = true
		guard.set_meta("disarmed", true)
	if WorldHistory.event_count("facility_guard_weapon_taken") > 0:
		loadout.gun_available = false
		guard.set_meta("facility_weapon", "")
		guard.set_meta("facility_rounds", 0)
	knows_player = int(record.get("killed_player", 0)) > 0
	if knows_player:
		warning_shots_left = 0
	for event in WorldHistory.events:
		var details: Dictionary = event.get("details", {})
		if str(event.get("type", "")) == "facility_biometric_access" and str(details.get("barrier_id", "")) == barrier.barrier_id:
			_open_door("restored")
			break


func _build_wall() -> void:
	# Two wall leaves either side of the doorway and a lintel over it. Full
	# height, so the only way on is through the door.
	var side_width := ARTERY_HALF_WIDTH - DOOR_WIDTH * 0.5
	for side in [-1.0, 1.0]:
		_slab(Vector3(side_width, WALL_HEIGHT, 0.5), Vector3(side * (DOOR_WIDTH * 0.5 + side_width * 0.5), WALL_HEIGHT * 0.5, 0))
	_slab(Vector3(DOOR_WIDTH, WALL_HEIGHT - DOOR_HEIGHT, 0.5), Vector3(0, DOOR_HEIGHT + (WALL_HEIGHT - DOOR_HEIGHT) * 0.5, 0))
	door_body = _slab(Vector3(DOOR_WIDTH, DOOR_HEIGHT, 0.3), Vector3(0, DOOR_HEIGHT * 0.5, 0))
	door_panel = door_body.get_child(0) as MeshInstance3D
	var stripe := MeshInstance3D.new()
	var stripe_mesh := BoxMesh.new()
	stripe_mesh.size = Vector3(DOOR_WIDTH - 0.2, 0.14, 0.02)
	var stripe_material := StandardMaterial3D.new()
	stripe_material.albedo_color = Color("c8321e")
	stripe_material.emission_enabled = true
	stripe_material.emission = Color("6a140a")
	stripe_mesh.material = stripe_material
	stripe.mesh = stripe_mesh
	stripe.position = Vector3(0, 0.4, 0.17)
	door_body.add_child(stripe)
	var sign := Label3D.new()
	sign.text = "D-SECTION // BIOMETRIC"
	sign.font_size = 40
	sign.outline_size = 8
	sign.modulate = Color("e0b089")
	sign.outline_modulate = Color("150605")
	sign.position = Vector3(0, DOOR_HEIGHT + 0.35, 0.3)
	add_child(sign)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("d0703a")
	# Far enough off the wall to light the approach rather than burn a
	# white disc onto the concrete (seen on the first capture).
	lamp.light_energy = 2.2
	lamp.omni_range = 8.0
	lamp.position = Vector3(0, DOOR_HEIGHT + 0.8, 2.8)
	add_child(lamp)


func _build_reader() -> void:
	barrier = BARRIER.new()
	barrier.name = "Reader"
	barrier.barrier_id = "service_arcade_d_section"
	var authorized: Array[String] = [GUARD_ID]
	barrier.authorized_subject_ids = authorized
	barrier.position = READER_AT
	add_child(barrier)
	var plate := MeshInstance3D.new()
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(0.34, 0.46, 0.08)
	var plate_material := StandardMaterial3D.new()
	plate_material.albedo_color = Color("1a1411")
	plate_material.emission_enabled = true
	plate_material.emission = Color("3a1208")
	plate_mesh.material = plate_material
	plate.mesh = plate_mesh
	barrier.add_child(plate)
	reader_label = Label3D.new()
	reader_label.font_size = 22
	reader_label.outline_size = 6
	reader_label.modulate = Color("f06a3a")
	reader_label.outline_modulate = Color("120404")
	reader_label.position = Vector3(0, 0.42, 0.06)
	reader_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	barrier.add_child(reader_label)
	barrier.access_granted.connect(_on_access_granted)
	_refresh_reader()


func _build_guard() -> void:
	guard = BODY.new()
	guard.name = "Hollis"
	add_child(guard)
	guard.build(GUARD_ID, {"flesh": Color("5c4a3a"), "variation": 3})
	# Dressed in plain cloth, the rig's default garment; a real CellOutz
	# security model waits on Greg (DESIGN.md, 24 September).
	var uniform := ClothingShell.fresh_wardrobe()
	# Bare-headed: a full wardrobe hoods the head too, and the man whose face
	# the player has to remember should have one.
	uniform.erase("head")
	guard.dress(uniform)
	guard.position = GUARD_AT
	# The rig's forward is -z; he faces the way the player comes.
	guard.rotation.y = PI
	loadout = LOADOUT.new(GUARD_ID)
	loadout.attach_to(guard)
	speech = Label3D.new()
	speech.font_size = 30
	speech.outline_size = 8
	speech.modulate = Color("f2e2c4")
	speech.outline_modulate = Color("120606")
	speech.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	speech.position = GUARD_AT + Vector3(0, 2.25, 0)
	add_child(speech)


func _slab(dimensions: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	add_child(body)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh.material = LabSurface.for_slab(dimensions, at)
	visual.mesh = mesh
	body.add_child(visual)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collider.shape = shape
	body.add_child(collider)
	return body


## Alive, standing and still holding the gun: the only state that shoots.
func guard_active() -> bool:
	if guard == null or coerced:
		return false
	return not guard.anatomy.downed and not guard.anatomy.dead


func guard_down() -> bool:
	return guard != null and (guard.anatomy.downed or guard.anatomy.dead)


func _distance_to_guard(player_position: Vector3) -> float:
	var difference := guard.global_position - player_position
	difference.y = 0.0
	return difference.length()


func step(delta: float, player_position: Vector3) -> void:
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	if muzzle != null:
		muzzle.light_energy = move_toward(muzzle.light_energy, 0.0, delta * 30.0)
	speech_timer = maxf(0.0, speech_timer - delta)
	if speech_timer <= 0.0 and speech != null:
		speech.text = ""
	if not guard_active():
		return
	var distance := _distance_to_guard(player_position)
	if distance > WARN_RANGE:
		return
	# He turns to keep you in front of him.
	var to_player := player_position - guard.global_position
	to_player.y = 0.0
	if to_player.length() > 0.1:
		guard.rotation.y = atan2(-to_player.x, -to_player.z)
	if not warned:
		warned = true
		if knows_player:
			_say("%s: \"You again. They grew you back.\"" % GUARD_NAME, 2.8)
		else:
			_say("%s: \"Back in your tank, meat.\"" % GUARD_NAME)
	if distance <= FIRE_RANGE and fire_cooldown <= 0.0:
		fire_cooldown = FIRE_COOLDOWN
		if muzzle != null:
			muzzle.light_energy = 9.0
		if warning_shots_left > 0:
			# Over your head. The only one you get.
			warning_shots_left -= 1
			_say("%s: \"Next one's in you.\"" % GUARD_NAME, 1.6)
			WorldHistory.record_event("facility_guard_fired", {"subject_id": GUARD_ID, "damage": 0.0, "warning": true})
			return
		_say("%s FIRES" % GUARD_NAME, 0.7)
		WorldHistory.record_event("facility_guard_fired", {"subject_id": GUARD_ID, "damage": SHOT_DAMAGE})
		shot.emit(SHOT_DAMAGE)


## The host tells him when his shooting killed the player. He remembers it,
## and he will know them when the vat sends them back.
func player_killed() -> void:
	var record := WorldHistory.subject(GUARD_ID)
	WorldHistory.amend_subject(GUARD_ID, {
		"killed_player": int(record.get("killed_player", 0)) + 1,
		"memory": "Shot the decanted subject dead at his door. CellOutz will grow it back.",
	})
	_say("%s: \"Stay down.\"" % GUARD_NAME, 2.0)


## LMB with the ram in hand. Returns true when the swing was his to take, so
## the host does not also spend it on a gate.
func strike(player_position: Vector3) -> bool:
	if guard == null or guard.anatomy.dead or _distance_to_guard(player_position) > REACH:
		return false
	var direction := guard.global_position - player_position
	direction.y = 0.0
	guard.hit("torso", RAM_DAMAGE, 12.0, "blunt", "", direction.normalized())
	WorldHistory.record_event("facility_guard_rammed", {"subject_id": GUARD_ID, "downed": guard_down()})
	WorldHistory.amend_subject(GUARD_ID, {"anatomy_state": guard.anatomy.snapshot()})
	if guard_down():
		coerced = false
		WorldHistory.amend_subject(GUARD_ID, {
			"status": "dead" if guard.anatomy.dead else "down",
			"memory": "Put down at his own door by a decanted subject with a breach ram.",
		})
		_say("")
	else:
		_say("%s: \"Hh--\"" % GUARD_NAME, 1.0)
	return true


## E. One press, one act, in the order the situation asks for it.
func interact(player_position: Vector3, holding_ram: bool, arsenal: Node = null) -> String:
	if guard == null or _distance_to_guard(player_position) > REACH:
		return ""
	if guard_active():
		if not holding_ram:
			return ""
		return _coerce()
	if not bool(loadout.gun_available) or str(guard.get_meta("facility_weapon", "")) == "":
		if not door_open:
			return _present_body()
		return ""
	if not door_open:
		return _present_body()
	return _take_gun(arsenal)


## A living guard with a ram at his chest palms the reader himself, and lets go
## of the gun. The reader does not care that he did not want to.
func _coerce() -> String:
	coerced = true
	guard.set_meta("disarmed", true)
	_say("%s: \"Easy. Easy. It's my hand it wants.\"" % GUARD_NAME, 2.6)
	WorldHistory.amend_subject(GUARD_ID, {
		"status": "coerced",
		"memory": "Opened his own door with a breach ram at his chest, and dropped the gun.",
	})
	PLAYER_ACTION_LEDGER.record("facility_guard_coerced", {"subject_id": GUARD_ID, "location": "service_arcade"})
	var result: Dictionary = barrier.present_body(guard)
	return "%s PALMS THE READER" % GUARD_NAME if bool(result.get("accepted", false)) else str(result.get("reason", ""))


## Down or dead, his hand is still his. Dragged to the reader it opens the door.
func _present_body() -> String:
	var result: Dictionary = barrier.present_body(guard)
	return "HIS HAND ON THE READER" if bool(result.get("accepted", false)) else str(result.get("reason", ""))


func _take_gun(arsenal: Node) -> String:
	var holder: Node = arsenal
	var temporary := false
	if holder == null:
		# The arcade has no hands to hold a gun yet; the transfer still goes
		# through the real arsenal so its rules decide, then lands in Carry.
		holder = HunterArsenal.new()
		add_child(holder)
		temporary = true
	var result: Dictionary = loadout.take_sidearm(guard, holder)
	if temporary:
		holder.queue_free()
	if not bool(result.get("accepted", false)):
		return ""
	var carry := CARRY.new()
	carry.items.append({
		"label": GUN_LABEL, "kind": "weapon", "weapon": "facility_sidearm",
		"rounds": int(result.get("rounds", 0)), "mass": 1.1, "perishes": false, "age": 0.0,
		"from": GUARD_ID,
	})
	carry.save_to_history()
	PLAYER_ACTION_LEDGER.record("facility_first_firearm", {"subject_id": GUARD_ID, "rounds": int(result.get("rounds", 0))})
	return "%s // %d ROUNDS // NO RESERVE" % [GUN_LABEL, int(result.get("rounds", 0))]


func _on_access_granted(_subject_id: String, method: String) -> void:
	_open_door(method)


func _open_door(method: String) -> void:
	if door_open:
		return
	door_open = true
	if door_body != null:
		for child in door_body.get_children():
			if child is CollisionShape3D:
				(child as CollisionShape3D).disabled = true
		var lift := create_tween()
		lift.tween_property(door_body, "position:y", DOOR_HEIGHT * 1.5, 0.9).set_ease(Tween.EASE_IN_OUT)
	_refresh_reader()
	door_opened.emit(method)


func _refresh_reader() -> void:
	if reader_label == null:
		return
	reader_label.text = "IDENTITY ACCEPTED" if door_open else "PRESENT\nAUTHORIZED\nBIOMETRIC"
	reader_label.modulate = Color("7fd08a") if door_open else Color("f06a3a")


func _say(text: String, seconds := 2.4) -> void:
	if speech == null:
		return
	speech.text = text
	speech_timer = seconds


## What E would do here right now, for the host's prompt line. Empty when the
## post has nothing to offer from where the player stands.
func prompt_for(player_position: Vector3, holding_ram: bool) -> String:
	if guard == null:
		return ""
	var distance := _distance_to_guard(player_position)
	if guard_active():
		if distance <= REACH and holding_ram:
			return "[E] RAM TO HIS CHEST: MAKE HIM OPEN IT   //   [LMB] RAM HIM"
		if distance <= FIRE_RANGE:
			return "%s // ARMED // THE READER WANTS HIS HAND" % GUARD_NAME if holding_ram else "%s // ARMED // YOU HAVE NOTHING TO MEET HIM WITH" % GUARD_NAME
		if distance <= WARN_RANGE:
			return "D-SECTION DOOR // GUARDED"
		return ""
	if distance > REACH:
		return ""
	if not door_open:
		return "[E] DRAG HIS HAND TO THE READER" if guard_down() else "[E] OPEN IT"
	if bool(loadout.gun_available):
		return "[E] TAKE HIS GUN"
	return ""
