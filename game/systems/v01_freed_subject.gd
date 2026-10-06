class_name V01FreedSubject
extends V01Foe

## The freed vat subject that turns hostile (job 9; Greg 5 Oct 02:10: "one
## freed vat subject that turns hostile"). It is the Growing Floor's living
## subject, the one in the near tank (seed 1) that `VatHorror` shows awake:
## out of its glass it stands dazed, twitching, then shrieks and comes at you.
## Erratic, fast, unarmed.
##
## - **Dart**: it never walks at you. Short sideways bursts and still,
##   twitching pauses, closing in a zigzag.
## - **Pounce** (RED, from 2.5-6.5 m): it drops low, its hands glint red,
##   then it leaps along the line it locked as the crouch began. Step aside
##   or dodge; it lands sprawled and open for a beat.
## - **Flurry** (COPPER, in reach): three quick claws, each parryable. A
##   parried claw throws it on its back, open for a long beat.
##
## Light on health for a foe: four or five clean cleaver blows, fewer
## through the opening a parry makes.
## No lines, no name: "bingyanger" is a placeholder (Greg 5 Oct), so its id
## is neutral and nothing it does prints a word.

const MOVESET := preload("res://systems/sword_moveset.gd")

## DIALS (REMASTER_LOG job9).
const HEALTH := 130.0
const DART_SPEED := 5.4
const DAZED_SECONDS := 1.8
const POUNCE_RANGE := Vector2(2.5, 6.5)
const POUNCE_WINDUP := 0.62
const LEAP_SPEED := 11.0
const LEAP_HIT := 1.25
const SPRAWL := 1.1
const CLAW_REACH := 1.55
const FLURRY := 3
const REST := 0.9
const SHARE := {"claw": 0.04, "pounce": 0.08}

var dazed := DAZED_SECONDS
var leaping := 0.0
var leap_dir := Vector3.FORWARD
var leap_left := 0.0
var swipes_left := 0
var pounces := 0
var _dart_clock := 0.0
var _dart_dir := Vector3.ZERO
var _seed := 1


func configure(seed_value: int) -> void:
	_seed = seed_value
	kind = "freed_subject"
	max_health = HEALTH
	max_poise = 3


func _subject_record() -> Dictionary:
	return {"kind": "person", "status": "loose", "place": "growing_floor", "role": "freed vat subject", "attitude": "hostile"}


func _build_body() -> void:
	var rig := BaselineHuman.new()
	rig.name = "FreedSubject"
	add_child(rig)
	rig.build(foe_id, {
		"gore": BaselineHuman.apply_gore_setting(),
		"flesh": Color("6a4a43"),
		"variation": 4 + _seed * 5 + 4,
		"build": 0.96,
		"rigged": true,
		"ragdoll": V01Encounters.RAGDOLL_DEATHS,
	})
	HunterAppearance.style_world_rig(rig, foe_id, false)
	body = rig
	# Its hands glint before the claws come: the telegraph sits on them.
	for zone in ["left_arm", "right_arm"]:
		var arm := rig.parts.get(zone) as Node3D
		if arm == null:
			continue
		var nail := MeshInstance3D.new()
		nail.name = "Claw"
		var ball := SphereMesh.new()
		ball.radius = 0.03
		ball.height = 0.06
		nail.mesh = ball
		nail.material_override = glow_material(Color("4a302a"), 0.0)
		nail.position = Vector3(0.0, -0.33, -0.02)
		arm.add_child(nail)


func glint_anchor() -> Node3D:
	if body is BaselineHuman:
		var arm := (body as BaselineHuman).parts.get("right_arm") as Node3D
		if arm != null:
			var claw := arm.get_node_or_null("Claw") as Node3D
			if claw != null:
				return claw
	return body


func facts(distance: float) -> Dictionary:
	return {
		"reeling": reeling(),
		"winding": winding != "" or leaping > 0.0,
		"dazed": dazed > 0.0 or state == "idle",
		"in_reach": distance <= CLAW_REACH,
		"pounce_range": distance >= POUNCE_RANGE.x and distance <= POUNCE_RANGE.y,
		"ready": attack_clock >= REST,
		"token": host.token_free_for(self, "melee"),
	}


func branches() -> Array:
	return [
		[[["reeling", true]], "reel"],
		[[["winding", true]], "busy"],
		[[["dazed", true]], "turn"],
		[[["in_reach", true], ["ready", true], ["token", true]], "flurry"],
		[[["pounce_range", true], ["ready", true], ["token", true]], "pounce"],
		[[], "dart"],
	]


func act(action: String, delta: float, to_player: Vector3, distance: float) -> void:
	match action:
		"reel":
			host.release_token(self)
			# Twitching where it fell.
			body.rotation.z = sin(Time.get_ticks_msec() * 0.03) * 0.08
		"turn":
			if state == "idle":
				state = "alert"
			dazed = maxf(0.0, dazed - delta)
			face(to_player, delta * 2.0)
			body.rotation.z = sin(Time.get_ticks_msec() * 0.021 + _seed) * 0.12 * (1.0 - dazed / DAZED_SECONDS)
			if dazed <= 0.0:
				body.rotation.z = 0.0
				# The shriek: a red flash, then it is on you.
				flash(RED, 6.0)
				attack_clock = REST * 0.5
				WorldHistory.update_subject(foe_id, {"attitude": "hostile", "status": "hostile"}, "v01_subject_turned")
		"busy":
			_busy(delta, to_player, distance)
		"flurry":
			if host.take_token(self, "melee"):
				swipes_left = FLURRY
				_claw()
		"pounce":
			if host.take_token(self, "melee"):
				pounces += 1
				leap_dir = to_player.normalized()
				leap_left = clampf(distance + 0.4, 2.0, POUNCE_RANGE.y + 0.5)
				begin("pounce", {"windup": POUNCE_WINDUP, "colour": RED, "parryable": false, "blockable": false, "share": SHARE.pounce, "zone": "torso", "type": "cut", "clip": "roll", "recovery": SPRAWL})
				_crouch(true)
		_:
			_dart(delta, to_player, distance)


func _busy(delta: float, to_player: Vector3, distance: float) -> void:
	if leaping > 0.0:
		var stride := minf(LEAP_SPEED * delta, leap_left)
		leap_left -= stride
		walk(leap_dir * stride)
		leaping = maxf(0.0, leaping - delta)
		if leaping <= 0.0 or leap_left <= 0.0:
			leaping = 0.0
			_land_pounce()
		return
	if winding == "pounce":
		# Low, still, its hands glinting: the line is locked as it drops.
		if advance(delta):
			var spec := move
			cancel_windup()
			move = spec
			_crouch(false)
			leaping = leap_left / LEAP_SPEED + 0.05
		return
	face(to_player, delta * 10.0)
	if windup > windup_needed * 0.6 and distance > 1.0:
		walk(to_player.normalized() * 3.0 * delta)
	if advance(delta):
		land(winding, distance)


func _land_pounce() -> void:
	var spec := move
	move = {}
	attack_clock = 0.0
	recover_left = SPRAWL
	stagger_left = SPRAWL
	host.release_token(self)
	var to: Vector3 = host.player_body().global_position - global_position
	to.y = 0.0
	if to.length() <= LEAP_HIT:
		landed_on_player += 1
		host.hurt_player(self, "pounce", spec)
	else:
		WorldHistory.record_event("v01_foe_missed", {"foe": foe_id, "move": "pounce"})


func _claw() -> void:
	var source: Dictionary = (MOVESET.WEAPON_TABLES["fists"] as Dictionary)["light_1" if swipes_left % 2 == 1 else "light_2"]
	begin("claw", {"windup": float(source.windup) * TELEGRAPH_SCALE, "active": float(source.active), "reach": CLAW_REACH, "colour": COPPER, "parryable": true, "blockable": true, "share": SHARE.claw, "zone": ["left_arm", "torso", "right_arm"][swipes_left % 3], "type": "cut", "clip": "punch_jab" if swipes_left % 2 == 1 else "punch_cross"})


func land(move_id: String, distance: float) -> void:
	var spec := move
	cancel_windup()
	swipes_left -= 1
	if distance <= float(spec.get("reach", CLAW_REACH)) + 0.3:
		landed_on_player += 1
		host.hurt_player(self, move_id, spec)
	if swipes_left > 0 and state != "dead" and not reeling():
		_claw()
		return
	attack_clock = 0.0
	recover_left = 0.5
	host.release_token(self)


func on_parried(open_for: float) -> void:
	# Thrown on its back: a long opening.
	swipes_left = 0
	super.on_parried(open_for * 1.3)
	host.release_token(self)


## Erratic: bursts sideways and in, then a twitching stop. Ready to strike
## it comes in (to claw, or to pounce range); not ready it hangs off at a
## pounce's distance.
func _dart(delta: float, to_player: Vector3, distance: float) -> void:
	face(to_player, delta * 8.0)
	_dart_clock -= delta
	if _dart_clock <= 0.0:
		var beat := (pounces * 7 + hits_taken * 3 + int(Time.get_ticks_msec() / 337)) % 5
		_dart_clock = [0.35, 0.5, 0.28, 0.6, 0.42][beat]
		var side := to_player.normalized().cross(Vector3.UP) * (1.0 if beat % 2 == 0 else -1.0)
		var ready := attack_clock >= REST
		var wanted := (1.0 if distance < POUNCE_RANGE.x else POUNCE_RANGE.x + 0.5) if ready else 3.4
		var inward := to_player.normalized() * clampf(distance - wanted, -1.0, 1.0) * 1.2
		_dart_dir = (side * 0.8 + inward).normalized() if beat != 3 else Vector3.ZERO
	walk(_dart_dir * DART_SPEED * delta)
	body.rotation.z = sin(Time.get_ticks_msec() * 0.04) * 0.05 if _dart_dir == Vector3.ZERO else 0.0


## Low and coiled before a pounce: dropped and leaning in. A body with
## physics hitboxes is never scaled unevenly (Jolt refuses it).
func _crouch(down: bool) -> void:
	if body == null:
		return
	body.position.y = -0.2 if down else 0.0
	body.rotation.x = 0.35 if down else 0.0


func take_blow(packet: Dictionary) -> Dictionary:
	if dazed > 0.0:
		# Hitting it while it is still dazed only makes it turn sooner.
		dazed = 0.0
	if leaping > 0.0:
		# Struck in the air: it drops.
		leaping = 0.0
		packet = packet.merged({"breaks_poise": true, "stagger": SPRAWL}, true)
	return _wound_and_count(packet, float(packet.get("damage", 0.0)))


func stagger(seconds: float) -> void:
	super.stagger(seconds)
	swipes_left = 0
	leaping = 0.0
	_crouch(false)
	if host != null:
		host.release_token(self)
