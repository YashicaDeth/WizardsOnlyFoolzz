class_name V01Guard
extends V01Foe

## A numbered CellOutz guard (job 9; Greg 5 Oct 02:10: "2-3 numbered CellOutz
## guards in the service arcade (shock staffs, pistols)"). Dressed like the
## arcade's numbered guard (`FacilityGuardPost.dress_security`), on a rigged
## `BaselineHuman`.
##
## He fights with the player's own disciplines and button layers:
## - **PRODSTAFF (Brawler)**: light (R1) and its follow-up, heavy (R2) sweep,
##   charged shock (hold R2), block (L1), parry (L2). Every wind-up is the
##   player's `SwordMoveset["staff"]` move times `TELEGRAPH_SCALE`. The
##   charged shock glints RED and goes through a block: step out or dodge.
##   Three light blows in a row at him and he parries the third and answers:
##   spamming is punished, reading him is not (as the examiner's guard).
## - **Pistol (Marksman)**: aim (L2) with a red sight line that locks before
##   the shot, fire (R2), reload (Y) when the magazine is out (an opening).
##   Up close he pistol-whips; otherwise he keeps his distance and strafes.
##
## They work as a squad: the first to see you radios (a copper lamp on his
## shoulder, `call`), and every guard in range comes; only one melee guard
## winds up at a time (`V01Encounters` hands out the token) while the rest
## press in at a step outside reach, so a careful player always has one blow
## to read.

const BODY_KIT := preload("res://systems/facility_guard_post.gd")
const MOVESET := preload("res://systems/sword_moveset.gd")

## DIAL: guard health per weapon kind.
const HEALTH := {"staff": 230.0, "pistol": 170.0}
const SPEED := {"staff": 2.6, "pistol": 2.2}
## Share of the player's blood each blow takes (V01Encounters.hurt_player).
const SHARE := {"light": 0.07, "light_2": 0.07, "heavy": 0.11, "shock": 0.14, "riposte": 0.07, "shot": 0.09, "whip": 0.05}
## Fixed staff order so it can be learned.
const STAFF_PATTERN := ["light", "light_2", "heavy", "light", "shock"]
const REST := 1.15
## Notice: sight cone and range, and any-direction range.
const SIGHT_RANGE := 15.0
const SIGHT_DOT := 0.35
const NEAR_NOTICE := 4.0
const CALL_SECONDS := 0.9
const BLOCK_HOLD := 0.55
const BLOCK_STAMINA := 3
## A spent block comes back one blow at a time.
const BLOCK_REGEN := 3.0
## Lights in a row at him before he parries the next.
const PARRY_AFTER := 2
## The pistol: where he likes to stand, how long the sight line holds,
## when it locks, and how far off the locked line you must be to be missed.
const PISTOL_RANGE := Vector2(5.0, 10.5)
const AIM_SECONDS := 1.05
const AIM_LOCK := 0.72
const MISS_WIDTH := 0.75
const MAGAZINE := 5
const RELOAD_SECONDS := 1.7
const WHIP_RANGE := 2.1

var weapon := "staff"
var number := ""
var called := false
var calling := 0.0
var blocking := 0.0
var block_stamina := BLOCK_STAMINA
var lights_in_a_row := 0
var _light_clock := 0.0
var _regen_clock := 0.0
var attacks_made := 0
var rounds := MAGAZINE
var reloading := 0.0
var shots_fired := 0
var aim_from := Vector3.ZERO
var aim_dir := Vector3.FORWARD
var _strafe_side := 1.0
var _strafe_clock := 0.0
var held: Node3D
var radio_lamp: StandardMaterial3D
var sight_line: MeshInstance3D
var watch_heading := 0.0


func configure(guard_weapon: String, guard_number: String, heading: float) -> void:
	weapon = guard_weapon
	number = guard_number
	kind = "guard_%s" % weapon
	max_health = float(HEALTH[weapon])
	max_poise = 3
	watch_heading = heading


func _subject_record() -> Dictionary:
	return {"kind": "person", "status": "on post", "faction": "CellOutz Security", "place": "service_arcade", "role": "numbered guard", "number": number, "weapon": weapon}


func _build_body() -> void:
	var rig := BaselineHuman.new()
	rig.name = "Guard%s" % number
	add_child(rig)
	rig.build(foe_id, {"flesh": Color("7a5f48").lerp(Color("5c4a3a"), float(number.hash() % 7) / 7.0), "variation": 11 + number.hash() % 5, "build": 1.05, "rigged": true})
	var uniform := ClothingShell.fresh_wardrobe()
	uniform.erase("head")
	rig.dress(uniform)
	BODY_KIT.dress_security(rig, number)
	body = rig
	body.rotation.y = watch_heading
	held = HeldGear.build_weapon("staff" if weapon == "staff" else "breach_nine")
	held.name = "Held_%s" % weapon
	var arm := rig.parts.get("right_arm") as Node3D
	(arm if arm != null else rig).add_child(held)
	held.position = Vector3(0.0, -0.3, -0.2) if weapon == "staff" else Vector3(0.0, -0.36, -0.08)
	# The telegraph glows on the weapon's head.
	var tip := held.find_child("shock_tip", true, false) as MeshInstance3D
	if tip != null:
		tip.material_override = glow_material(Color("3a2a20"))
	else:
		var lamp := MeshInstance3D.new()
		lamp.name = "MuzzleLamp"
		var ball := SphereMesh.new()
		ball.radius = 0.02
		ball.height = 0.04
		lamp.mesh = ball
		lamp.material_override = glow_material(Color("2a201a"))
		lamp.position = Vector3(0, 0.02, 0.2)
		held.add_child(lamp)
	# The radio on his shoulder: copper while he calls.
	var torso := rig.parts.get("torso") as Node3D
	if torso != null:
		var radio := MeshInstance3D.new()
		radio.name = "Radio"
		var box := BoxMesh.new()
		box.size = Vector3(0.06, 0.09, 0.04)
		radio.mesh = box
		radio_lamp = StandardMaterial3D.new()
		radio_lamp.albedo_color = Color("2a221c")
		radio_lamp.emission_enabled = true
		radio_lamp.emission = COPPER
		radio_lamp.emission_energy_multiplier = 0.0
		radio.material_override = radio_lamp
		radio.position = Vector3(-0.17, 0.2, -0.06)
		torso.add_child(radio)
	if weapon == "pistol":
		_build_sight_line()


func glint_anchor() -> Node3D:
	if held != null:
		var tip := held.find_child("shock_tip", true, false) as Node3D
		if tip == null:
			tip = held.find_child("MuzzleLamp", true, false) as Node3D
		if tip != null:
			return tip
	return body


func weak_points() -> Array:
	# The head: a pistol round there bites harder (V01Encounters).
	var head := (body as BaselineHuman).parts.get("head") as Node3D if body is BaselineHuman else null
	return [{"at": head.global_position if head != null else global_position + Vector3(0, 1.65, 0), "radius": 0.14, "part": "head"}]


# --- His mind. ------------------------------------------------------------------

func facts(distance: float) -> Dictionary:
	var swing: Dictionary = host.player_swing_at(self)
	var front := _player_in_front()
	var ready := attack_clock >= REST
	var f := {
		"reeling": reeling(),
		"winding": winding != "" or calling > 0.0 or reloading > 0.0 or blocking > 0.0,
		"unaware": state == "idle",
		"needs_call": state != "idle" and not called,
		"can_parry": weapon == "staff" and not swing.is_empty() and front and str(swing.get("move", "")).begins_with("light") and lights_in_a_row >= PARRY_AFTER,
		"can_block": weapon == "staff" and not swing.is_empty() and front and block_stamina > 0,
	}
	if weapon == "staff":
		f["in_reach"] = distance <= _reach_for(_next_move())
		f["ready"] = ready
		f["token"] = host.token_free_for(self, "melee")
	else:
		f["too_close"] = distance < PISTOL_RANGE.x * 0.75
		f["whip_range"] = distance <= WHIP_RANGE
		f["empty"] = rounds <= 0
		f["in_range"] = distance >= PISTOL_RANGE.x * 0.6 and distance <= PISTOL_RANGE.y + 2.0 and host.line_of_sight(self)
		f["too_far"] = distance > PISTOL_RANGE.y
		f["ready"] = ready
		f["token"] = host.token_free_for(self, "ranged")
	return f


func branches() -> Array:
	var common := [
		[[["reeling", true]], "reel"],
		[[["winding", true]], "busy"],
		[[["unaware", true]], "watch"],
		[[["needs_call", true]], "call"],
	]
	if weapon == "staff":
		return common + [
			[[["can_parry", true]], "parry"],
			[[["can_block", true]], "block"],
			[[["in_reach", true], ["ready", true], ["token", true]], "attack"],
			[[["in_reach", false]], "close"],
			[[], "pressure"],
		]
	return common + [
		[[["whip_range", true], ["ready", true]], "whip"],
		[[["empty", true]], "reload"],
		[[["too_close", true]], "back"],
		[[["in_range", true], ["ready", true], ["token", true]], "aim"],
		[[["too_far", true]], "close"],
		[[], "strafe"],
	]


func act(action: String, delta: float, to_player: Vector3, distance: float) -> void:
	_light_clock = maxf(0.0, _light_clock - delta)
	_regen_clock += delta
	if _regen_clock >= BLOCK_REGEN:
		_regen_clock = 0.0
		block_stamina = mini(BLOCK_STAMINA, block_stamina + 1)
	if _light_clock <= 0.0:
		lights_in_a_row = 0
	if radio_lamp != null:
		radio_lamp.emission_energy_multiplier = 4.0 * float(calling > 0.0 and fmod(calling, 0.3) > 0.12)
	var speed: float = SPEED[weapon]
	match action:
		"reel":
			_release()
			if parried_left <= 0.0:
				walk(-to_player.normalized() * 1.4 * delta)
		"busy":
			_busy(delta, to_player, distance)
		"watch":
			_watch(delta, to_player, distance)
		"call":
			calling = CALL_SECONDS
			flash(COPPER, 3.0)
			var rigged = (body as BaselineHuman).rigged
			if rigged != null:
				rigged.play_action("interact", 1.4)
			WorldHistory.record_event("v01_guard_calling", {"guard": foe_id})
		"parry":
			_parry()
		"block":
			blocking = BLOCK_HOLD
			flash(BONE, 2.5)
			var rigged = (body as BaselineHuman).rigged
			if rigged != null:
				rigged.play_action("sword_idle", 1.0)
		"attack":
			_begin_staff(_next_move())
		"whip":
			_begin_whip()
		"reload":
			reloading = RELOAD_SECONDS
			var rigged = (body as BaselineHuman).rigged
			if rigged != null:
				rigged.play_action("pistol_reload", 1.0)
			WorldHistory.record_event("v01_guard_reload", {"guard": foe_id})
		"aim":
			_begin_aim(to_player)
		"close":
			face(to_player, delta * 6.0)
			walk(to_player.normalized() * speed * delta)
		"back":
			face(to_player, delta * 6.0)
			walk(-to_player.normalized() * speed * 0.9 * delta)
		"strafe", "pressure":
			# Pressure: a step outside his reach, sidestepping, facing you;
			# he closes a little at a time so you cannot just wait.
			face(to_player, delta * 6.0)
			_strafe_clock -= delta
			if _strafe_clock <= 0.0:
				_strafe_clock = 1.2 + float((foe_id.hash() + attacks_made) % 5) * 0.25
				_strafe_side = -_strafe_side
			var side := to_player.normalized().cross(Vector3.UP) * _strafe_side * 1.1
			var hold := 3.6 if weapon == "staff" else (PISTOL_RANGE.x + PISTOL_RANGE.y) * 0.5
			var inward := to_player.normalized() * clampf(distance - hold, -1.0, 1.0) * 0.8
			walk((side + inward) * delta)


func _busy(delta: float, to_player: Vector3, distance: float) -> void:
	if calling > 0.0:
		calling = maxf(0.0, calling - delta)
		face(to_player, delta * 5.0)
		if calling <= 0.0:
			called = true
			host.squad_call(self)
		return
	if reloading > 0.0:
		reloading = maxf(0.0, reloading - delta)
		walk(-to_player.normalized() * 0.8 * delta)
		if reloading <= 0.0:
			rounds = MAGAZINE
		return
	if blocking > 0.0:
		blocking = maxf(0.0, blocking - delta)
		face(to_player, delta * 8.0)
		return
	if winding == "aim":
		_advance_aim(delta, to_player)
		return
	# A staff blow or the pistol whip: the last third darts in.
	face(to_player, delta * (6.0 if windup < windup_needed * 0.75 else 1.5))
	if windup > windup_needed * 0.66 and distance > 1.4:
		walk(to_player.normalized() * float(move.get("lunge", 2.4)) * delta)
	if advance(delta):
		var landed := winding
		var flat: Vector3 = host.player_body().global_position - global_position
		flat.y = 0.0
		land(landed, flat.length())


func _watch(delta: float, to_player: Vector3, distance: float) -> void:
	# On post: a slow look either side of where he watches.
	var sweep := watch_heading + sin(Time.get_ticks_msec() * 0.0004 + float(number.hash() % 10)) * 0.6
	body.rotation.y = lerp_angle(body.rotation.y, sweep, clampf(delta * 1.5, 0.0, 1.0))
	if distance <= NEAR_NOTICE or (distance <= SIGHT_RANGE and forward().dot(to_player.normalized()) >= SIGHT_DOT and host.line_of_sight(self)):
		alert(host.player_body().global_position)


func alert(at: Vector3) -> void:
	super.alert(at)
	# The others hear a fight close by even before the radio.
	host.hear(self, at)


# --- Staff. -----------------------------------------------------------------------

func _next_move() -> String:
	return STAFF_PATTERN[attacks_made % STAFF_PATTERN.size()]


func _reach_for(move_id: String) -> float:
	var table: Dictionary = MOVESET.WEAPON_TABLES["staff"]
	var key := {"light": "light_1", "light_2": "light_2", "heavy": "heavy", "shock": "charged_heavy", "riposte": "light_1"}.get(move_id, "light_1") as String
	return float((table[key] as Dictionary).reach) * 0.82


## The player's own staff move, read slower.
func staff_spec(move_id: String) -> Dictionary:
	var key := {"light": "light_1", "light_2": "light_2", "heavy": "heavy", "shock": "charged_heavy", "riposte": "light_1"}.get(move_id, "light_1") as String
	var source: Dictionary = (MOVESET.WEAPON_TABLES["staff"] as Dictionary)[key]
	var unblockable := move_id == "shock"
	return {
		"windup": float(source.windup) * TELEGRAPH_SCALE * (0.7 if move_id == "riposte" else 1.0),
		"active": float(source.active),
		"reach": _reach_for(move_id),
		"colour": RED if unblockable else COPPER,
		"parryable": move_id in ["light", "light_2", "riposte"],
		"blockable": not unblockable,
		"share": float(SHARE[move_id]),
		"shock": unblockable,
		"zone": "torso" if move_id != "heavy" else "left_arm",
		"type": "blunt",
		"lunge": 2.6 if move_id != "heavy" else 1.6,
		"clip": "sword_attack",
		"recovery": float(source.recovery) * 1.8,
	}


func _begin_staff(move_id: String) -> void:
	if not host.take_token(self, "melee"):
		return
	attacks_made += 1
	begin(move_id, staff_spec(move_id))


func land(move_id: String, distance: float) -> void:
	var spec := move
	cancel_windup()
	attack_clock = 0.0
	recover_left = float(spec.get("recovery", 0.4))
	_release()
	if distance > float(spec.get("reach", 2.5)) + 0.3:
		WorldHistory.record_event("v01_foe_missed", {"foe": foe_id, "move": move_id})
		return
	landed_on_player += 1
	host.hurt_player(self, move_id, spec)


## His block took your blow, or your third light in a row met his parry.
func take_blow(packet: Dictionary) -> Dictionary:
	if state == "dead":
		return {"result": "miss", "damage": 0.0}
	var move_id := str(packet.get("move", ""))
	if move_id.begins_with("light"):
		lights_in_a_row += 1
		_light_clock = 2.0
	else:
		lights_in_a_row = 0
	var from: Vector3 = packet.get("from", global_position)
	var to_attacker := from - global_position
	to_attacker.y = 0.0
	var front := forward().dot(to_attacker.normalized()) > 0.2
	if blocking > 0.0 and front and str(packet.get("weapon", "")) != "gun":
		var heavy := move_id in ["heavy", "charged_heavy"] or bool(packet.get("shock", false))
		if heavy or block_stamina <= 1:
			# Guard broken: the heavy blow is what a block is for.
			blocking = 0.0
			block_stamina = BLOCK_STAMINA
			var result := _wound_and_count(packet.merged({"breaks_poise": true, "stagger": 1.0}, true), float(packet.get("damage", 0.0)) * 0.6)
			result["result"] = "guard_broken"
			return result
		block_stamina -= 1
		flash(BONE, 4.0)
		health = maxf(1.0, health - float(packet.get("damage", 0.0)) * 0.15)
		WorldHistory.record_event("v01_guard_blocked", {"guard": foe_id})
		return {"result": "blocked", "damage": float(packet.get("damage", 0.0)) * 0.15}
	if bool(packet.get("shock", false)):
		# The PRODSTAFF's charge through a guard: a long reel, his hardware
		# shorts like anyone's.
		packet = packet.merged({"breaks_poise": true, "stagger": 1.5}, true)
		if body is BaselineHuman and (body as BaselineHuman).anatomy != null:
			OrganSystem.shock((body as BaselineHuman).anatomy, 1.0)
	if calling > 0.0:
		# Hit mid-call: the radio never goes out.
		calling = 0.0
	return _wound_and_count(packet, float(packet.get("damage", 0.0)))


## Your third light in a row: turned aside on his staff; he answers at once
## with a quicker light that is itself parryable and glints copper.
func _parry() -> void:
	lights_in_a_row = 0
	flash(BONE, 6.0)
	host.player_deflected(self)
	WorldHistory.record_event("v01_guard_parried_player", {"guard": foe_id})
	if host.take_token(self, "melee"):
		begin("riposte", staff_spec("riposte"))


# --- Pistol. -----------------------------------------------------------------------

func _build_sight_line() -> void:
	sight_line = MeshInstance3D.new()
	sight_line.name = "SightLine"
	var beam := CylinderMesh.new()
	beam.top_radius = 0.004
	beam.bottom_radius = 0.004
	beam.height = 1.0
	beam.radial_segments = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(RED, 0.55)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material = material
	sight_line.mesh = beam
	sight_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sight_line.visible = false
	sight_line.top_level = true
	add_child(sight_line)


func _begin_aim(to_player: Vector3) -> void:
	if not host.take_token(self, "ranged"):
		return
	face(to_player, 1.0)
	begin("aim", {"windup": AIM_SECONDS, "colour": RED, "parryable": false, "blockable": false, "share": SHARE.shot, "zone": "torso", "type": "ballistic", "clip": ""})
	var rigged = (body as BaselineHuman).rigged
	if rigged != null:
		rigged.play_action("pistol_aim", 1.0)
	if sight_line != null:
		sight_line.visible = true


func _advance_aim(delta: float, to_player: Vector3) -> void:
	var eye := global_position + Vector3(0, 1.45, 0)
	var target: Vector3 = host.player_body().global_position + Vector3(0, 0.4, 0)
	if windup < windup_needed * AIM_LOCK:
		# Tracking you: the line follows until it locks.
		face(to_player, delta * 8.0)
		aim_from = eye
		aim_dir = (target - eye).normalized()
	_draw_sight(aim_from, aim_dir)
	if advance(delta):
		_fire()


func _draw_sight(from: Vector3, direction: Vector3) -> void:
	if sight_line == null:
		return
	var length := 14.0
	sight_line.scale = Vector3(1, length, 1)
	sight_line.global_position = from + direction * length * 0.5
	var basis := Basis()
	basis.y = direction
	basis.x = direction.cross(Vector3.UP).normalized() if absf(direction.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	basis.z = basis.x.cross(basis.y)
	sight_line.global_basis = basis.orthonormalized().scaled(Vector3(1, length, 1))


func _fire() -> void:
	var spec := move
	cancel_windup()
	if sight_line != null:
		sight_line.visible = false
	rounds -= 1
	shots_fired += 1
	attack_clock = 0.0
	recover_left = 0.5
	_release()
	flash(Color("ffb35a"), 7.0)
	var rigged = (body as BaselineHuman).rigged
	if rigged != null:
		rigged.play_action("pistol_shoot", 1.0)
	# Missed if you are off the locked line, or something stands between.
	var target: Vector3 = host.player_body().global_position + Vector3(0, 0.4, 0)
	var along := (target - aim_from).dot(aim_dir)
	var off := (aim_from + aim_dir * along).distance_to(target)
	var hit: bool = along > 0.0 and off <= MISS_WIDTH and host.line_of_sight(self)
	WorldHistory.record_event("v01_guard_shot", {"guard": foe_id, "hit": hit, "off": snappedf(off, 0.01)})
	if hit:
		landed_on_player += 1
		host.hurt_player(self, "shot", spec)
	else:
		host.near_miss(self)


func _begin_whip() -> void:
	if not host.take_token(self, "melee"):
		return
	var source: Dictionary = (MOVESET.WEAPON_TABLES["fists"] as Dictionary)["heavy"]
	attacks_made += 1
	begin("whip", {"windup": float(source.windup) * TELEGRAPH_SCALE, "active": float(source.active), "reach": WHIP_RANGE + 0.3, "colour": COPPER, "parryable": true, "blockable": true, "share": SHARE.whip, "zone": "torso", "type": "blunt", "lunge": 1.4, "clip": "punch_cross", "recovery": 0.6, "shove": 3.0})


func cancel_windup() -> void:
	super.cancel_windup()
	if sight_line != null:
		sight_line.visible = false


func stagger(seconds: float) -> void:
	super.stagger(seconds)
	calling = 0.0
	blocking = 0.0
	_release()


func _release() -> void:
	if host != null:
		host.release_token(self)


func _player_in_front() -> bool:
	var to: Vector3 = host.player_body().global_position - global_position
	to.y = 0.0
	return forward().dot(to.normalized()) > 0.3


func kill(cause: String) -> void:
	_release()
	if sight_line != null:
		sight_line.visible = false
	if radio_lamp != null:
		radio_lamp.emission_energy_multiplier = 0.0
	super.kill(cause)
