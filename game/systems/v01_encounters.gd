class_name V01Encounters
extends Node3D

## Job 9: v0.1's small enemy cast, placed in the one facility map and fought
## with the route's own weapons. Greg, 5 Oct 02:10: "2-3 numbered CellOutz
## guards in the service arcade (shock staffs, pistols), one freed vat subject
## that turns hostile, the Lower Works sentinel"; 02:20: "hard but fair,
## soulslike, checkpoints close together".
##
## Built by `vat_chamber.gd` when the facility is one map. It owns:
## - **Placement**: three numbered guards in the Service Arcade
##   (`V01Guard`), the freed subject on the Growing Floor (`V01FreedSubject`,
##   out of the near tank: `claim_freed` from `VatSmash`, or breaking out as
##   you pass), and the sentinel on the Lower Works floor (`V01Sentinel`).
##   A foe only thinks while you are on its level and near (fps).
## - **Your side of a fight**, through the real InputMap (pad first, keys
##   equal): R1 / LMB light (chains), R2 / MMB heavy (hold for charged), or
##   fire once you carry a gun; L1 / RMB hold to block; L2 / X parry;
##   B / Space dodge (a short dash with i-frames); Y / R swap cleaver and
##   PRODSTAFF; Q / d-pad up the X-ray on the foe you face. Your moves are
##   `SwordMoveset`'s for the weapon in hand, the same table the guards'
##   staff blows are read from.
## - **Fairness**: one melee foe winds up at a time and one gun aims at a
##   time (`take_token`); everyone else presses in or strafes.
## - **What drops**: the staff guard's PRODSTAFF and the pistol guard's
##   sidearm (the route's first firearm, loading any loose rounds you carry,
##   as `FacilityGuardPost`'s loadout did) lie where they fell until taken.
## - **Checkpoints**: one at the arcade's west door and one at the Lower Works
##   floor, filed through the route's `FacilityCheckpoints`.

const MOVESET := preload("res://systems/sword_moveset.gd")
const VAT_REBIRTH := preload("res://systems/vat_rebirth.gd")
const CARRY := preload("res://systems/carry.gd")

## DIALS (DESIGN/REMASTER_LOG.md, job9). Defaults are the assistant's, not Greg's.
const GUARD_COUNT := 3
## The near tank's living subject breaks out as you pass if you have not
## freed it yourself, so the Growing Floor always has its fight.
const SUBJECT_BREAKS_OUT := true
const SUBJECT_TRIGGER := 3.0
const GUARD_DROPS_WEAPON := true
## Player blows on foes, per weapon (light). Heavy x1.6, charged x2.2,
## riposte (after your parry) x2.
const PLAYER_DAMAGE := {"cleaver": 30.0, "staff": 22.0, "restraint": 16.0, "fists": 9.0, "gun": 45.0}
const HEAVY := 1.6
const CHARGED := 2.2
const RIPOSTE := 2.0
const HEADSHOT := 1.6
## Your parry window and how long a parried foe stays open.
const PARRY_WINDOW := 0.3
const PARRIED_OPEN := 1.5
## A held block takes this share of a blockable blow (the sentinel's slam:
## BLOCK_HEAVY).
const BLOCK_SHARE := 0.25
const BLOCK_HEAVY := 0.5
const DODGE_SECONDS := 0.26
const DODGE_SPEED := 11.0
const IFRAMES := 0.32
const DODGE_COOLDOWN := 0.55
## Your swing turned aside on a guard's parry: no blows for this long.
const DEFLECTED := 0.75
## A charged shock that lands: you reel this long.
const SHOCKED := 0.6
const GUN_COOLDOWN := 0.35
const GUN_RANGE := 40.0
const BODY_RADIUS := 0.38
## You go down under this share of your blood (the examiner's is 0.45; a
## longer fight with several foes gets more room).
const LOSE_AT := 0.3
const ACTIVE_RANGE := 42.0
const ENGAGE_RANGE := 14.0
const CALL_RANGE := 48.0
const HEAR_RANGE := 9.0
const PICKUP_REACH := 1.8
const ARCADE_AREA := Rect2(24.2, -54.0, 9.0, 52.0)
const WORKS_AREA := Rect2(16.5, -126.0, 23.0, 56.0)
const GROWING_AREA := Rect2(-7.0, -24.0, 14.0, 27.0)
const WORKS_Y := -12.0
const GUN_LABEL := "CELL OUTZ BREACH NINE"
const STAFF_LABEL := "PRODSTAFF"

var chamber: Node3D
var foes: Array[V01Foe] = []
var guards: Array[V01Guard] = []
var subject: V01FreedSubject
var sentinel: V01Sentinel
var subject_tank: Dictionary = {}
var feel := ImpactFeel.new()
var xray: XrayScanOverlay
var xray_on := false
var tokens := {"melee": null, "ranged": null}

## The player's swing: {move, weapon, table, t, windup, active, recovery, target, landed}.
var swing: Dictionary = {}
var _buffered := ""
var _chain := 0
var _chain_left := 0.0
var parry_age := 99.0
var iframes := 0.0
var dodge_left := 0.0
var dodge_dir := Vector3.ZERO
var dodge_cooldown := 0.0
var deflected := 0.0
var shocked := 0.0
var shove_left := 0.0
var shove_dir := Vector3.ZERO
var gun_cooldown := 0.0
var heavy_down := false
var heavy_held := 0.0
var staff_in_hand := false
var held_staff: Node3D
var pickups: Array[Dictionary] = []
var dead := false
var last_result := ""
var blows := 0
var shots := 0
var blocked := 0
var parries := 0
var dodges := 0
var _taught := {}
var _filed := {}


func setup(owner_chamber: Node3D) -> void:
	chamber = owner_chamber
	name = "V01Encounters"
	add_child(feel)
	_build_guards()
	_build_sentinel()
	_restore_subject()
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	xray = XrayScanOverlay.new()
	xray.name = "EncounterXray"
	xray.visible = false
	layer.add_child(xray)
	staff_in_hand = _carries(STAFF_LABEL) and WorldHistory.subject("v01_held").get("weapon", "") == "staff"
	if staff_in_hand:
		_hold_staff()


func player_body() -> Node3D:
	return chamber.player if chamber != null else null


func _player_at() -> Vector3:
	return (chamber.player as Node3D).global_position


# --- Placement. ------------------------------------------------------------------

func _build_guards() -> void:
	# [number, weapon, at, heading (PI faces the west door's side, +z)]
	var posts := [
		["47", "staff", Vector3(27.0, 0.0, -15.5), PI],
		["48", "staff", Vector3(30.6, 0.0, -29.0), PI],
		["49", "pistol", Vector3(28.0, 0.0, -44.5), PI],
	]
	for index in mini(GUARD_COUNT, posts.size()):
		var post: Array = posts[index]
		var guard := V01Guard.new()
		guard.configure(str(post[1]), str(post[0]), float(post[3]))
		add_child(guard)
		guard.setup(self, "v01_guard_%s" % post[0], post[2], ARCADE_AREA, 0.0)
		guard.died.connect(_on_foe_died)
		guards.append(guard)
		foes.append(guard)
		if guard.state == "dead":
			_restore_drop(guard)


func _build_sentinel() -> void:
	sentinel = V01Sentinel.new()
	var patrol: Array[Vector3] = [Vector3(28.0, WORKS_Y, -84.0), Vector3(28.0, WORKS_Y, -106.0)]
	sentinel.configure(patrol)
	add_child(sentinel)
	sentinel.setup(self, "v01_lower_works_sentinel", Vector3(28.0, WORKS_Y, -95.0), WORKS_AREA, WORKS_Y)
	sentinel.avoid = [[Vector3(18.0, WORKS_Y, -82.0), 2.0], [Vector3(38.0, WORKS_Y, -98.0), 2.0], [Vector3(18.0, WORKS_Y, -114.0), 2.0]]
	sentinel.died.connect(_on_foe_died)
	foes.append(sentinel)


## A subject freed on an earlier load is where it was left.
func _restore_subject() -> void:
	var record := WorldHistory.subject("v01_freed_subject")
	if record.is_empty():
		return
	_spawn_subject(Vector3(float(record.get("x", 3.0)), 0.0, float(record.get("z", -6.0))), int(record.get("seed", 1)))


## `VatSmash._free`: the first tank opened in v0.1 holds the hostile subject.
## True when this encounter took it (no random subject is made).
func claim_freed(tank: Dictionary) -> bool:
	if subject != null:
		return false
	var at: Vector3 = tank.get("at", Vector3.ZERO)
	var toward_aisle := -signf(at.x) if absf(at.x) > 0.01 else 1.0
	for key in ["curled", "cradled"]:
		var inside = tank.get(key)
		if inside != null and is_instance_valid(inside):
			(inside as Node3D).visible = false
	_spawn_subject(at + Vector3(toward_aisle * 1.25, 0, 0), int(tank.get("seed", 1)))
	tank["freed"] = subject
	return true


func _spawn_subject(at: Vector3, seed_value: int) -> void:
	subject = V01FreedSubject.new()
	subject.configure(seed_value)
	add_child(subject)
	subject.setup(self, "v01_freed_subject", at, GROWING_AREA, 0.0)
	var circles: Array = [[Vector3.ZERO, 1.5]]
	var centres = chamber.get("tank_centres")
	if centres is Array:
		for centre: Vector3 in centres:
			circles.append([centre, 1.1])
	subject.avoid = circles
	subject.died.connect(_on_foe_died)
	foes.append(subject)
	if subject.state != "dead":
		WorldHistory.update_subject("v01_freed_subject", {"x": at.x, "z": at.z, "seed": seed_value}, "v01_subject_freed")


## The near tank's living subject (seed 1, the aisle side nearest the staff
## door), once the player is up and walking.
func _watch_subject_tank() -> void:
	if not SUBJECT_BREAKS_OUT or subject != null or chamber == null or not bool(chamber.get("breakout_complete")):
		return
	var smash = chamber.get("vat_smash")
	if smash == null:
		return
	if subject_tank.is_empty():
		for tank: Dictionary in smash.tanks:
			if int(tank.seed) == 1 and (subject_tank.is_empty() or float((tank.at as Vector3).x) > float((subject_tank.at as Vector3).x)):
				subject_tank = tank
		if subject_tank.is_empty():
			return
	if bool(subject_tank.broken):
		return
	var to: Vector3 = subject_tank.at - _player_at()
	to.y = 0.0
	if to.length() <= SUBJECT_TRIGGER:
		# It breaks its own glass: the same glass, spill and climb-out as a
		# tank you smash (`VatSmash`), from the inside.
		smash._break(subject_tank, "inside")
		WorldHistory.record_event("v01_subject_broke_out", {"tank": int(subject_tank.seed)})


# --- The tick. ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if chamber == null or chamber.player == null or dead:
		return
	if not bool(chamber.get("can_move")):
		return
	_watch_subject_tank()
	_file_checkpoints()
	parry_age += delta
	iframes = maxf(0.0, iframes - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	deflected = maxf(0.0, deflected - delta)
	shocked = maxf(0.0, shocked - delta)
	gun_cooldown = maxf(0.0, gun_cooldown - delta)
	_chain_left = maxf(0.0, _chain_left - delta)
	if heavy_down:
		heavy_held += delta
		if heavy_held >= MOVESET.CHARGED_HEAVY_SECONDS + 0.4:
			_release_heavy()
	_move_player(delta)
	_advance_swing(delta)
	var at: Vector3 = _player_at()
	for foe in foes:
		if not is_instance_valid(foe) or not foe.is_alive():
			continue
		var gap := foe.global_position - at
		if absf(gap.y) > 6.0 or Vector2(gap.x, gap.z).length() > ACTIVE_RANGE:
			continue
		foe.step(delta * feel.scale_for(foe.foe_id))
	_watch_pickups()
	_update_xray()
	if _player_beaten():
		_lose()


func _file_checkpoints() -> void:
	var checkpoints = chamber.get("checkpoints")
	if checkpoints == null:
		return
	var at: Vector3 = _player_at()
	if not _filed.has("arcade") and at.y > -2.0 and at.x > 21.5 and at.x < 24.5 and at.z > -5.0:
		_filed["arcade"] = true
		checkpoints.file("service_arcade_west_door", at)
	if not _filed.has("works") and at.y < WORKS_Y + 2.0 and at.z < -68.0 and at.z > -74.0:
		_filed["works"] = true
		checkpoints.file("lower_works_floor", at)


## The dodge's dash and a blow's shove, on top of the route's own movement.
func _move_player(delta: float) -> void:
	var body: CharacterBody3D = chamber.player
	if dodge_left > 0.0:
		dodge_left = maxf(0.0, dodge_left - delta)
		body.move_and_collide(dodge_dir * DODGE_SPEED * delta)
	if shove_left > 0.0:
		shove_left = maxf(0.0, shove_left - delta)
		body.move_and_collide(shove_dir * 6.0 * delta)


# --- Input: the player's side. --------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if chamber == null or dead or not bool(chamber.get("can_move")):
		return
	if handle_input(event):
		get_viewport().set_input_as_handled()


## True when the event was spent on a fight (or a fight's pickup).
func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("interact") and _take_pickup():
		return true
	if event.is_action_pressed("xray"):
		xray_on = not xray_on
		if not xray_on and xray != null:
			xray.show_scan(null, chamber.camera)
		return _nearest_foe(ENGAGE_RANGE) != null or xray_on
	if event.is_action_pressed("reload") and _carries(STAFF_LABEL) and _carries_cleaver():
		_swap_weapon()
		return true
	if not _in_a_fight():
		return false
	if event.is_action_pressed("attack"):
		press_light()
		return true
	if event.is_action("heavy"):
		if event.is_action_pressed("heavy") and not heavy_down:
			press_heavy()
		elif event.is_action_released("heavy") and heavy_down:
			_release_heavy()
		return true
	if event.is_action("parry"):
		if event.is_action_pressed("parry"):
			press_parry()
		return true
	if event.is_action_pressed("dodge"):
		press_dodge()
		return true
	if event.is_action("guard"):
		return true
	return false


func _in_a_fight() -> bool:
	return _nearest_foe(ENGAGE_RANGE) != null


func blocking() -> bool:
	return Input.is_action_pressed("guard") and swing.is_empty() and deflected <= 0.0


func held_weapon() -> String:
	if staff_in_hand:
		return "staff"
	var route = chamber.get("doctor_route")
	var tool := str(route.held_weapon()) if route != null else ""
	return {"axe": "cleaver", "restraint": "restraint"}.get(tool, "fists")


static func table_for(weapon: String) -> String:
	return {"cleaver": "cleaver", "staff": "staff"}.get(weapon, "fists")


func press_light() -> void:
	if deflected > 0.0 or shocked > 0.0:
		return
	if not swing.is_empty():
		# Buffered: a press near the end of a swing is kept.
		var left := float(swing.windup) + float(swing.active) + float(swing.recovery) - float(swing.t)
		if left <= MOVESET.INPUT_BUFFER_WINDOW + float(swing.recovery):
			_buffered = "light"
		return
	_chain = (_chain % 3) + 1 if _chain_left > 0.0 else 1
	_start_swing("light_%d" % _chain)


func press_heavy() -> void:
	if _gun_rounds() > 0:
		fire_gun()
		return
	heavy_down = true
	heavy_held = 0.0


func _release_heavy() -> void:
	if not heavy_down:
		return
	heavy_down = false
	if deflected > 0.0 or shocked > 0.0 or not swing.is_empty():
		return
	_start_swing("charged_heavy" if heavy_held >= MOVESET.CHARGED_HEAVY_SECONDS else "heavy")


func press_parry() -> void:
	parry_age = 0.0


func press_dodge() -> void:
	if dodge_cooldown > 0.0:
		return
	var input := Vector3(Input.get_axis("move_left", "move_right"), 0.0, Input.get_axis("move_forward", "move_back"))
	var yaw := float(chamber.get("yaw"))
	dodge_dir = (Basis(Vector3.UP, yaw) * input).normalized() if input.length() > 0.2 else Basis(Vector3.UP, yaw) * Vector3(0, 0, 1)
	dodge_left = DODGE_SECONDS
	iframes = IFRAMES
	dodge_cooldown = DODGE_COOLDOWN
	dodges += 1
	swing = {}
	WorldHistory.record_event("v01_player_dodge", {})


func _start_swing(move_id: String) -> void:
	var weapon := held_weapon()
	var table: Dictionary = (MOVESET.WEAPON_TABLES[table_for(weapon)] as Dictionary)[move_id]
	swing = {
		"move": move_id, "weapon": weapon, "t": 0.0,
		"windup": float(table.windup), "active": float(table.active), "recovery": float(table.recovery),
		"reach": float(table.reach) * (0.9 if weapon != "staff" else 0.95),
		"target": _target(float(table.reach)), "landed": false,
		"shock": bool(table.get("shock", false)), "breaks_poise": bool(table.get("breaks_poise", false)),
		"kind": str(table.damage_type),
	}
	_swing_visual()


func _advance_swing(delta: float) -> void:
	if swing.is_empty():
		return
	swing.t = float(swing.t) + delta
	if not bool(swing.landed) and float(swing.t) >= float(swing.windup):
		swing.landed = true
		_contact()
	if float(swing.t) >= float(swing.windup) + float(swing.active) + float(swing.recovery):
		var was: String = swing.move
		swing = {}
		_chain_left = MOVESET.CHAIN_WINDOW if was.begins_with("light") else 0.0
		if was.begins_with("light") and _chain >= 3:
			_chain = 0
		if _buffered == "light":
			_buffered = ""
			press_light()


## What the guards read: your swing, while it is still winding at `foe`.
func player_swing_at(foe: V01Foe) -> Dictionary:
	if swing.is_empty() or bool(swing.landed) or swing.target != foe:
		return {}
	return swing


func _contact() -> void:
	var foe: V01Foe = swing.target
	if foe == null or not is_instance_valid(foe) or not foe.is_alive() or not _in_cone(foe, float(swing.reach) + 0.4, 0.4):
		foe = _target(float(swing.reach))
	if foe == null:
		feel.whiff()
		return
	var move_id: String = swing.move
	var damage := float(PLAYER_DAMAGE[swing.weapon])
	if move_id == "heavy":
		damage *= HEAVY
	elif move_id == "charged_heavy":
		damage *= CHARGED
	var riposte := foe.parried_left > 0.0
	if riposte:
		damage *= RIPOSTE
		foe.parried_left = 0.0
	var direction := (foe.global_position - _player_at())
	direction.y = 0.0
	var packet := {
		"weapon": swing.weapon, "move": move_id, "damage": damage,
		"poise": 2 if move_id in ["heavy", "charged_heavy"] else 1,
		"breaks_poise": bool(swing.breaks_poise) or riposte, "stagger": 0.9 if move_id == "charged_heavy" else 0.55,
		"shock": bool(swing.shock), "kind": str(swing.kind), "riposte": riposte,
		"from": _player_at(), "direction": direction.normalized(),
		"zone": ["torso", "right_arm", "left_arm", "torso"][blows % 4], "impulse": 2.0 + damage * 0.05,
	}
	var result := foe.take_blow(packet)
	blows += 1
	last_result = str(result.get("result", ""))
	var strength := clampf(float(result.get("damage", 0.0)) / 45.0, 0.25, 1.0)
	match last_result:
		"blocked":
			_cue("tug")
			feel.strike(0.3, "blunt", false, [foe.foe_id])
			_teach("blocked", "HE BLOCKS  //  A HEAVY BREAKS HIS GUARD")
		"armour":
			_cue("glass")
			feel.strike(0.35, "blunt", false, [foe.foe_id])
			_teach("armour", "THE PLATE TAKES IT  //  GET BEHIND IT, SHOCK IT, OR SHOOT THE EYE AND CORE")
		_:
			_cue("rip" if str(swing.kind) == "cut" else "tap")
			feel.strike(strength, "cut" if str(swing.kind) == "cut" else "blunt", false, [foe.foe_id])
	BodyCamFeel.hit(chamber.camera, 0.02 + strength * 0.04)


## The foe you face within `reach`, or null.
func _target(reach: float) -> V01Foe:
	var best: V01Foe = null
	var best_score := -1.0
	for foe in foes:
		if not is_instance_valid(foe) or not foe.is_alive():
			continue
		if _in_cone(foe, reach + 0.4, 0.5):
			var to := foe.global_position - _player_at()
			to.y = 0.0
			var score := 1.0 / maxf(to.length(), 0.1)
			if score > best_score:
				best_score = score
				best = foe
	return best


func _in_cone(foe: V01Foe, reach: float, dot: float) -> bool:
	var to := foe.global_position - _player_at()
	if absf(to.y) > 2.5:
		return false
	to.y = 0.0
	if to.length() > reach:
		return false
	var forward: Vector3 = -chamber.camera.global_transform.basis.z
	forward.y = 0.0
	return to.length() < 0.6 or forward.normalized().dot(to.normalized()) >= dot


func _swing_visual() -> void:
	if staff_in_hand and held_staff != null:
		var rest := held_staff.rotation_degrees
		var tween := create_tween()
		tween.tween_property(held_staff, "rotation_degrees", rest + Vector3(-25.0, 0.0, 12.0), float(swing.windup)).set_ease(Tween.EASE_OUT)
		tween.tween_property(held_staff, "position", held_staff.position + Vector3(0, 0, -0.35), 0.08)
		tween.tween_property(held_staff, "position", held_staff.position, 0.2)
		tween.parallel().tween_property(held_staff, "rotation_degrees", rest, 0.25)
		return
	var route = chamber.get("doctor_route")
	if route != null:
		route._swing_held()


# --- The gun. -----------------------------------------------------------------------

func _gun_rounds() -> int:
	for entry in WorldHistory.subject("inventory").get("items", []):
		if entry is Dictionary and str((entry as Dictionary).get("label", "")) == GUN_LABEL:
			return int((entry as Dictionary).get("rounds", 0))
	return 0


func _spend_round() -> void:
	var carry := CARRY.new()
	for item in carry.items:
		if str(item.get("label", "")) == GUN_LABEL:
			item["rounds"] = maxi(0, int(item.get("rounds", 0)) - 1)
			break
	carry.save_to_history()


## R2 with rounds in the gun: down the crosshair. Weak points first (the
## sentinel's eye and core, a guard's head), then the body; a wall between
## stops it.
func fire_gun() -> Dictionary:
	if gun_cooldown > 0.0 or _gun_rounds() <= 0 or deflected > 0.0:
		return {}
	gun_cooldown = GUN_COOLDOWN
	_spend_round()
	shots += 1
	var camera: Camera3D = chamber.camera
	var from := camera.global_position
	var direction := -camera.global_transform.basis.z
	BodyCamFeel.hit(camera, 0.05)
	_cue("glass")
	var best: V01Foe = null
	var best_along := GUN_RANGE
	var best_part := ""
	for foe in foes:
		if not is_instance_valid(foe) or not foe.is_alive():
			continue
		for point: Dictionary in foe.weak_points():
			var along := _ray_sphere(from, direction, point.at, float(point.radius))
			if along >= 0.0 and along < best_along:
				best_along = along
				best = foe
				best_part = str(point.part)
		var low := foe.global_position + Vector3(0, 0.3, 0)
		var high := foe.global_position + Vector3(0, 1.75, 0)
		var body_along := _ray_capsule(from, direction, low, high, BODY_RADIUS)
		if body_along >= 0.0 and body_along < best_along - 0.05:
			best_along = body_along
			best = foe
			best_part = ""
	if best == null or not _clear(from, from + direction * best_along, best):
		WorldHistory.record_event("v01_player_shot", {"hit": false})
		return {"hit": false}
	var damage := float(PLAYER_DAMAGE.gun) * (HEADSHOT if best_part == "head" else 1.0)
	var hit_point := from + direction * best_along
	var part := best_part
	if part == "" and best is V01Sentinel:
		part = (best as V01Sentinel).side_facing(from)
		if part == "core":
			part = "rear"
	var result := best.take_blow({
		"weapon": "gun", "move": "shot", "damage": damage, "poise": 1, "kind": "ballistic",
		"from": from, "point": hit_point, "direction": direction, "part": part,
		"zone": "head" if best_part == "head" else "torso", "impulse": 4.0,
	})
	feel.strike(0.5, "blunt", false, [best.foe_id])
	WorldHistory.record_event("v01_player_shot", {"hit": true, "foe": best.foe_id, "part": best_part, "result": str(result.get("result", ""))})
	last_result = str(result.get("result", ""))
	return result.merged({"hit": true, "foe": best, "part": best_part}, true)


static func _ray_sphere(from: Vector3, direction: Vector3, centre: Vector3, radius: float) -> float:
	var along := (centre - from).dot(direction)
	if along < 0.0:
		return -1.0
	var closest := from + direction * along
	return along if closest.distance_to(centre) <= radius else -1.0


static func _ray_capsule(from: Vector3, direction: Vector3, low: Vector3, high: Vector3, radius: float) -> float:
	# Sampled along the ray: plenty for a body and cheap for three foes.
	var axis := high - low
	var length := axis.length()
	axis /= maxf(length, 0.001)
	var step := 0.1
	var along := 0.0
	while along < GUN_RANGE:
		var point := from + direction * along
		var t := clampf((point - low).dot(axis), 0.0, length)
		if point.distance_to(low + axis * t) <= radius:
			return along
		along += step
	return -1.0


## Nothing solid between two points except the player and the foe itself.
func _clear(from: Vector3, to: Vector3, foe: Node3D) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return true
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [chamber.player.get_rid()]
	query.collide_with_areas = false
	for _attempt in 4:
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return true
		var collider := hit.get("collider") as Node
		if collider != null and (foe.is_ancestor_of(collider) or _is_foe_part(collider)):
			query.exclude = query.exclude + [hit.get("rid")]
			continue
		return false
	return true


func _is_foe_part(node: Node) -> bool:
	for foe in foes:
		if is_instance_valid(foe) and foe.is_ancestor_of(node):
			return true
	return false


## The foe can see the player (eye height to head height).
func line_of_sight(foe: V01Foe) -> bool:
	if chamber == null or not is_inside_tree():
		return false
	return _clear(foe.global_position + Vector3(0, 1.6, 0), _player_at() + Vector3(0, 0.6, 0), foe)


# --- Blows on the player. ---------------------------------------------------------------

## A foe's blow reached you. Dodge, parry, block, or it lands.
func hurt_player(foe: V01Foe, move_id: String, spec: Dictionary) -> String:
	if dead:
		return "none"
	var to_foe := foe.global_position - _player_at()
	to_foe.y = 0.0
	var forward: Vector3 = -chamber.camera.global_transform.basis.z
	forward.y = 0.0
	var facing := forward.normalized().dot(to_foe.normalized()) > 0.35
	if iframes > 0.0:
		WorldHistory.record_event("v01_player_dodged", {"foe": foe.foe_id, "move": move_id})
		return "dodged"
	if bool(spec.get("parryable", false)) and parry_age <= PARRY_WINDOW and facing:
		parries += 1
		parry_age = 99.0
		foe.on_parried(PARRIED_OPEN)
		_cue("glass")
		feel.strike(0.6, "blunt", false, [foe.foe_id])
		_say("PARRIED  //  HIT BACK NOW")
		WorldHistory.record_event("v01_player_parried", {"foe": foe.foe_id, "move": move_id})
		return "parried"
	var share := float(spec.get("share", 0.05))
	var outcome := "hit"
	if bool(spec.get("blockable", false)) and blocking() and facing:
		share *= BLOCK_HEAVY if foe is V01Sentinel else BLOCK_SHARE
		outcome = "blocked"
		blocked += 1
		_cue("tug")
	elif not bool(spec.get("blockable", true)) and blocking() and facing:
		_teach("red", "RED GOES THROUGH A BLOCK  //  STEP OUT OR DODGE")
	var anatomy: Node = chamber.anatomy
	var zone := str(spec.get("zone", "torso"))
	anatomy.call("apply_hit", zone, 4.0 + share * 50.0, 0.0, str(spec.get("type", "blunt")))
	var capacity := float(anatomy.get("blood_capacity"))
	anatomy.set("blood_remaining", maxf(0.0, float(anatomy.get("blood_remaining")) - capacity * share))
	BodyCamFeel.hit(chamber.camera, 0.04 + share * 0.5)
	if chamber.get("breach_shake") != null:
		chamber.set("breach_shake", maxf(float(chamber.get("breach_shake")), 0.15 + share * 1.5))
	if outcome == "hit" and bool(spec.get("shock", false)):
		shocked = SHOCKED
		swing = {}
		if anatomy is AnatomyComponent:
			OrganSystem.shock(anatomy as AnatomyComponent, 1.0)
		_say("THE PRODSTAFF  //  YOUR ARMS LOCK")
	if spec.has("shove"):
		shove_dir = -to_foe.normalized()
		shove_left = 0.12 * float(spec.shove) / 3.0
	if outcome == "hit":
		_teach_colour(spec)
	WorldHistory.record_event("v01_player_hurt", {"foe": foe.foe_id, "move": move_id, "outcome": outcome, "share": snappedf(share, 0.001)})
	return outcome


## Your swing met a guard's parry.
func player_deflected(foe: V01Foe) -> void:
	swing = {}
	_buffered = ""
	_chain = 0
	deflected = DEFLECTED
	BodyCamFeel.hit(chamber.camera, 0.06)
	_cue("glass")
	_teach("deflected", "HE PARRIES A THIRD LIGHT IN A ROW  //  MIX IN A HEAVY")
	WorldHistory.record_event("v01_player_deflected", {"foe": foe.foe_id})


func near_miss(_foe: V01Foe) -> void:
	BodyCamFeel.hit(chamber.camera, 0.015)


func _teach_colour(spec: Dictionary) -> void:
	if bool(spec.get("parryable", false)):
		_teach("copper", "COPPER GLINT  //  PARRY IT (L2 / X) OR BLOCK (L1 / RMB)")
	elif not bool(spec.get("blockable", true)):
		_teach("red", "RED GLINT  //  STEP OUT OR DODGE (B / SPACE)")


func _teach(key: String, line: String) -> void:
	if _taught.has(key):
		return
	_taught[key] = true
	_say(line)


func _say(line: String) -> void:
	var label = chamber.get("subtitle")
	if label is Label:
		(label as Label).text = line


func _player_beaten() -> bool:
	var anatomy: Node = chamber.anatomy
	if anatomy == null or _nearest_foe(ENGAGE_RANGE) == null:
		return false
	if bool(anatomy.get("dead")) or bool(anatomy.get("downed")):
		return true
	return float(anatomy.get("blood_remaining")) / maxf(float(anatomy.get("blood_capacity")), 1.0) < LOSE_AT


func _lose() -> void:
	dead = true
	swing = {}
	var killer := _nearest_foe(ENGAGE_RANGE)
	var cause := "cut down in the facility"
	var location := "facility"
	if killer is V01Guard:
		cause = "beaten down by CellOutz %s" % (killer as V01Guard).number
		location = "service_arcade"
	elif killer is V01FreedSubject:
		cause = "torn apart by a freed vat subject"
		location = "growing_floor"
	elif killer is V01Sentinel:
		cause = "crushed by the Lower Works sentinel"
		location = "lower_works"
	WorldHistory.record_event("v01_player_killed", {"by": killer.foe_id if killer != null else "", "location": location})
	var at: Vector3 = _player_at()
	var request := VAT_REBIRTH.die(location, cause, killer.foe_id if killer != null else "facility", at)
	if OS.get_environment("ATG_V01_NO_DEATH_BEAT") == "1":
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	preload("res://systems/death_beat.gd").play(chamber, request, cause)


# --- The squad. ------------------------------------------------------------------------

## A guard's radio went out: every guard in range comes.
func squad_call(caller: V01Guard) -> void:
	var at: Vector3 = _player_at()
	var answered := 0
	for guard in guards:
		if guard == caller or not guard.is_alive():
			continue
		if guard.global_position.distance_to(caller.global_position) <= CALL_RANGE:
			guard.called = true
			guard.alert(at)
			answered += 1
	WorldHistory.record_event("v01_guard_called", {"guard": caller.foe_id, "answered": answered})


## A fight close by is heard without a radio.
func hear(source: V01Foe, at: Vector3) -> void:
	for guard in guards:
		if guard != source and guard.is_alive() and guard.state == "idle" and guard.global_position.distance_to(source.global_position) <= HEAR_RANGE:
			guard.alert(at)


func token_free_for(foe: V01Foe, lane: String) -> bool:
	var holder = tokens.get(lane)
	return holder == null or holder == foe or not is_instance_valid(holder) or not (holder as V01Foe).is_alive()


func take_token(foe: V01Foe, lane: String) -> bool:
	if not token_free_for(foe, lane):
		return false
	tokens[lane] = foe
	return true


func release_token(foe: V01Foe) -> void:
	for lane in tokens:
		if tokens[lane] == foe:
			tokens[lane] = null


func _nearest_foe(reach: float) -> V01Foe:
	if chamber == null or chamber.player == null:
		return null
	var at: Vector3 = _player_at()
	var best: V01Foe = null
	var best_d := reach
	for foe in foes:
		if not is_instance_valid(foe) or not foe.is_alive():
			continue
		var gap := foe.global_position - at
		if absf(gap.y) > 4.0:
			continue
		var d := Vector2(gap.x, gap.z).length()
		if d <= best_d and (foe.is_engaged() or d <= 4.0 or foe is V01FreedSubject):
			best_d = d
			best = foe
	return best


func _on_foe_died(foe: V01Foe) -> void:
	release_token(foe)
	# A body stays worth scanning (what is left to harvest); a dead machine not.
	if xray != null and foe is V01Sentinel and xray.rig == foe:
		xray.show_scan(null, chamber.camera)
	if foe is V01Guard:
		_drop_weapon(foe as V01Guard)
		_say("CELLOUTZ %s IS DOWN" % (foe as V01Guard).number)
	elif foe is V01Sentinel:
		_say("THE SENTINEL POWERS DOWN")
	elif foe is V01FreedSubject:
		_say("IT STOPS MOVING")


# --- What drops. ------------------------------------------------------------------------

func _drop_weapon(guard: V01Guard) -> void:
	if not GUARD_DROPS_WEAPON:
		return
	var label := STAFF_LABEL if guard.weapon == "staff" else GUN_LABEL
	if _carries(label) and label == STAFF_LABEL:
		return
	if WorldHistory.event_count("v01_pickup_%s" % guard.foe_id) > 0:
		return
	var at := guard.global_position + guard.forward() * 0.9
	_place_pickup(guard, label, Vector3(at.x, guard.floor_y, at.z))


func _restore_drop(guard: V01Guard) -> void:
	if GUARD_DROPS_WEAPON and WorldHistory.event_count("v01_pickup_%s" % guard.foe_id) == 0:
		var at := guard.global_position + Vector3(0.9, 0, 0)
		_place_pickup(guard, STAFF_LABEL if guard.weapon == "staff" else GUN_LABEL, Vector3(at.x, guard.floor_y, at.z))


func _place_pickup(guard: V01Guard, label: String, at: Vector3) -> void:
	var node := Node3D.new()
	node.name = "Pickup_%s" % guard.foe_id
	add_child(node)
	node.global_position = at + Vector3(0, 0.05, 0)
	var model := HeldGear.build_weapon("staff" if label == STAFF_LABEL else "breach_nine")
	node.add_child(model)
	model.rotation = Vector3(0.0, 0.7, PI * 0.5) if label == STAFF_LABEL else Vector3(PI * 0.5, 0.4, 0.0)
	var light := OmniLight3D.new()
	light.light_color = Color("e8d09a")
	light.light_energy = 1.1
	light.omni_range = 1.6
	light.position = Vector3(0, 0.4, 0)
	node.add_child(light)
	pickups.append({"node": node, "label": label, "guard": guard.foe_id, "rounds": guard.rounds if guard.weapon == "pistol" else 0})


func _pickup_in_reach() -> Dictionary:
	for pickup in pickups:
		var node := pickup.node as Node3D
		if node == null or not is_instance_valid(node):
			continue
		var to := node.global_position - _player_at()
		if absf(to.y) < 2.0 and Vector2(to.x, to.z).length() <= PICKUP_REACH:
			return pickup
	return {}


func _take_pickup() -> bool:
	var pickup := _pickup_in_reach()
	if pickup.is_empty():
		return false
	var carry := CARRY.new()
	var label := str(pickup.label)
	if label == STAFF_LABEL:
		carry.items.append({"label": STAFF_LABEL, "kind": "weapon", "weapon": "staff", "mass": 2.2, "perishes": false, "age": 0.0, "from": str(pickup.guard)})
		carry.save_to_history()
		staff_in_hand = true
		_hold_staff()
		_say("PRODSTAFF  //  HOLD R2 TO CHARGE A SHOCK  //  Y / R SWAPS WEAPON")
	else:
		# His sidearm, loading any loose rounds you carry (as the guard post's
		# loadout did).
		var rounds := int(pickup.rounds)
		for index in range(carry.items.size() - 1, -1, -1):
			var entry = carry.items[index]
			if entry is Dictionary and str((entry as Dictionary).get("label", "")) == "LOOSE ROUNDS":
				rounds += int((entry as Dictionary).get("rounds", 0))
				carry.items.remove_at(index)
		var merged := false
		for entry in carry.items:
			if entry is Dictionary and str((entry as Dictionary).get("label", "")) == GUN_LABEL:
				entry["rounds"] = int(entry.get("rounds", 0)) + rounds
				merged = true
		if not merged:
			carry.items.append({"label": GUN_LABEL, "kind": "weapon", "weapon": "facility_sidearm", "rounds": rounds, "mass": 1.1, "perishes": false, "age": 0.0, "from": str(pickup.guard)})
		carry.save_to_history()
		_say("%s  //  %d ROUNDS  //  R2 / MMB FIRES" % [GUN_LABEL, _gun_rounds()])
	(pickup.node as Node3D).queue_free()
	pickups.erase(pickup)
	WorldHistory.record_event("v01_pickup_%s" % str(pickup.guard), {"label": label})
	return true


func _watch_pickups() -> void:
	for pickup in pickups:
		var node := pickup.node as Node3D
		if node != null and is_instance_valid(node):
			var light := node.get_child(1) as OmniLight3D
			if light != null:
				light.light_energy = 1.0 + 0.35 * sin(Time.get_ticks_msec() * 0.004)


func _hold_staff() -> void:
	if held_staff == null:
		held_staff = HeldGear.build_weapon("staff")
		held_staff.name = "HeldProdstaff"
		LabSurface.hold_in_view(chamber.camera, held_staff)
		held_staff.rotation_degrees = Vector3(-8.0, 6.0, 0.0)
		held_staff.position += Vector3(0.06, -0.08, 0.1)
	held_staff.visible = true
	_show_route_tools(false)
	WorldHistory.update_subject("v01_held", {"weapon": "staff"}, "v01_weapon_swapped")


func _swap_weapon() -> void:
	staff_in_hand = not staff_in_hand
	if staff_in_hand:
		_hold_staff()
	else:
		if held_staff != null:
			held_staff.visible = false
		_show_route_tools(true)
		WorldHistory.update_subject("v01_held", {"weapon": "route"}, "v01_weapon_swapped")


func _show_route_tools(shown: bool) -> void:
	var route = chamber.get("doctor_route")
	if route == null:
		return
	for key in ["held_axe", "held_restraint"]:
		var tool = route.get(key)
		if tool != null and is_instance_valid(tool):
			(tool as Node3D).visible = shown


func _carries(label: String) -> bool:
	for entry in WorldHistory.subject("inventory").get("items", []):
		if entry is Dictionary and str((entry as Dictionary).get("label", "")) == label:
			return true
	return false


func _carries_cleaver() -> bool:
	var route = chamber.get("doctor_route")
	return route != null and bool(route.get("carrying_axe"))


## The prompt line for the route's HUD, or "".
func prompt_text() -> String:
	var pickup := _pickup_in_reach()
	if not pickup.is_empty():
		var glyph := str(chamber.call("_key", "interact")) if chamber.has_method("_key") else "[E]"
		return "%s TAKE THE %s" % [glyph, str(pickup.label)]
	return ""


# --- The X-ray on the foe you face. ---------------------------------------------------

func _update_xray() -> void:
	if xray == null:
		return
	if not xray_on:
		return
	var foe := _target(ENGAGE_RANGE)
	if foe == null:
		foe = _nearest_foe(ENGAGE_RANGE)
	var target: Node3D = null
	if foe != null:
		target = foe if foe is V01Sentinel else foe.body
	if target != xray.rig or xray.camera != chamber.camera:
		xray.show_scan(target, chamber.camera)


func _cue(kind: String) -> void:
	var audio = chamber.get("opening_audio")
	if audio != null:
		audio.cue(kind)
