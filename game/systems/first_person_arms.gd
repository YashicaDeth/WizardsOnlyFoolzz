class_name FirstPersonArms
extends Node3D

## imp-64. Greg, 5 Oct ~19:00: *"The first person needs a lot of work"*:
## animated first-person arms for swings. Before this the lab and the
## facility route hung a weapon in front of the eye with no hands, and a swing
## was a small rotation of that weapon about its own grip.
##
## Now the weapon is carried by the hunter's gloved hands (the same
## `HunterArsenal` mount the Hunt uses, so the hands sit on the authored grip
## anchors and cannot slide off), and the arm moves it: the whole hand swings
## round the right shoulder, the wrist turns the blade, and a forearm runs
## from the hand out of the bottom of the frame. Layers, added each frame:
##   idle breathing sway, walk bob from the owner's velocity, look lag,
##   the swing (wind-up, strike, follow-through, recovery) read from the
##   driving `SwordMoveset`'s own phase, so timing is `MeleeDriver`'s,
##   heavy charge, block, parry flick, hit flinch and contact bounce,
##   pistol recoil, reload (the magazine drops), aim (the owner's
##   `AimDownSights`), and inspect.
## Bare hands use the moveset's `fists` table (jab, hook, shove) the same way.

## Right shoulder in camera space: the pivot every swing turns about.
const SHOULDER := Vector3(0.22, -0.46, 0.12)
const LEFT_SHOULDER := Vector3(-0.22, -0.46, 0.12)
## Grip rest per held thing, camera space, and the weapon's turn there.
const REST := {
	"": {"at": Vector3(0.16, -0.21, -0.40), "turn": Vector3(0.35, 0.10, -0.20)},
	"cleaver": {"at": Vector3(0.24, -0.27, -0.45), "turn": Vector3(0.95, 0.22, -0.32)},
	"staff": {"at": Vector3(0.20, -0.28, -0.42), "turn": Vector3(0.16, 0.32, -0.30)},
	"sidearm": {"at": Vector3(0.14, -0.20, -0.55), "turn": Vector3(0.02, 0.04, 0.0)},
	"default": {"at": Vector3(0.22, -0.27, -0.45), "turn": Vector3(0.80, 0.22, -0.30)},
}
## The free left hand (cleaver, bare): where it hangs and where it guards.
const LEFT_REST := {"at": Vector3(-0.17, -0.27, -0.40), "turn": Vector3(0.35, -0.10, 0.20)}
const LEFT_GUARD := {"at": Vector3(-0.12, -0.15, -0.38), "turn": Vector3(0.70, -0.25, 0.35)}
## Swing keys, for a right-side blow. Each key: `swing` turns the arm about
## the shoulder (euler), `wrist` turns the weapon in the hand, `reach` moves
## the hand. A left-side blow mirrors them.
const ARCS := {
	"side": {
		"windup": {"swing": Vector3(0.30, -0.40, -0.15), "wrist": Vector3(0.35, -0.85, -0.60), "reach": Vector3(0.02, 0.06, 0.0)},
		"strike": {"swing": Vector3(0.0, 0.20, 0.0), "wrist": Vector3(-0.75, 0.45, 1.10), "reach": Vector3(-0.04, 0.0, -0.12)},
		"follow": {"swing": Vector3(-0.30, 0.70, 0.20), "wrist": Vector3(-0.95, 0.85, 1.30), "reach": Vector3(-0.04, -0.06, -0.08)},
	},
	"overhead": {
		"windup": {"swing": Vector3(0.42, -0.10, 0.0), "wrist": Vector3(0.90, 0.0, 0.10), "reach": Vector3(0.02, 0.06, -0.04)},
		"strike": {"swing": Vector3(-0.05, 0.08, 0.0), "wrist": Vector3(-0.60, 0.0, 0.0), "reach": Vector3(-0.04, 0.02, -0.16)},
		"follow": {"swing": Vector3(-0.55, 0.15, 0.05), "wrist": Vector3(-1.00, 0.10, 0.0), "reach": Vector3(-0.05, -0.06, -0.08)},
	},
	"thrust": {
		"windup": {"swing": Vector3(0.06, -0.10, 0.0), "wrist": Vector3(-0.12, -0.08, 0.10), "reach": Vector3(0.02, 0.0, 0.12)},
		"strike": {"swing": Vector3(0.02, 0.04, 0.0), "wrist": Vector3(-0.18, 0.05, 0.10), "reach": Vector3(-0.06, 0.04, -0.30)},
		"follow": {"swing": Vector3(0.0, 0.06, 0.0), "wrist": Vector3(-0.20, 0.06, 0.05), "reach": Vector3(-0.07, 0.03, -0.36)},
	},
}
## A left-side blow with a weapon in the right hand is a backhand: it comes
## from in front of the chest, so it travels less far round the shoulder.
const BACKHAND := 0.6
const GUARD := {"swing": Vector3(0.30, 0.30, 0.0), "wrist": Vector3(-0.55, 1.25, 0.25), "reach": Vector3(-0.04, 0.10, 0.04)}
const PARRY := {"swing": Vector3(0.22, 0.30, 0.15), "wrist": Vector3(-0.30, 0.90, 0.60), "reach": Vector3(0.0, 0.05, -0.06)}
const INSPECT := {"swing": Vector3(0.18, 0.25, 0.0), "wrist": Vector3(-0.60, 1.35, 1.10), "reach": Vector3(-0.06, 0.04, -0.06)}
const INSPECT_SECONDS := 2.4
const RELOAD := {"swing": Vector3(-0.20, -0.20, 0.0), "wrist": Vector3(0.55, 0.35, 0.75), "reach": Vector3(-0.05, -0.04, 0.06)}
const MAGAZINE_DROP := Vector3(0, -0.145, 0.012)

var weapon_id := "-"
var held: Node3D
var left_hand: Node3D
## The one driving blows: `MeleeDriver` when one is given, else our own
## (bare hands, or a scripted swing in a room with no driver).
var driver: MeleeDriver
var arsenal: HunterArsenal
var moveset := SwordMoveset.new()
var body: CharacterBody3D
var ads: AimDownSights
var aim_blend := 0.0
var inspect_left := 0.0
## Last pose's key weights, for tests and captures.
var last_phase := ""
var last_swing := Vector3.ZERO

var _time := 0.0
var _step := 0.0
var _jolt := Vector3.ZERO
var _jolt_turn := Vector3.ZERO
var _look_lag := Vector2.ZERO
var _last_forward := Vector3.ZERO
var _magazine: Node3D
var _magazine_rest := Vector3.ZERO
var _guard_amount := 0.0
## Own blows (no driver) whoosh through their own `FpCombatAudio`.
var _audio: FpCombatAudio
var _whoosh_due := false
var _heavy_due := false


func _init() -> void:
	name = "FirstPersonArms"


## Follow a `MeleeDriver` (and its arsenal) for timing, guard and contact.
func drive(melee: MeleeDriver) -> void:
	driver = melee
	arsenal = melee.arsenal
	melee.set_model(self)
	melee.kicked.connect(func(amount: float) -> void: bounce(amount))
	melee.blow_received.connect(_on_blow)
	if arsenal != null:
		arsenal.fired.connect(func(_id: String, _report: Dictionary) -> void: recoil())


func _on_blow(result: String) -> void:
	match result:
		"parried": bounce(0.04)
		"blocked": flinch(0.35)
		"guard_broken": flinch(1.3)
		_: flinch(1.0)


## Put `id` in the hands ("" is bare hands). Rebuilt only when it changes.
func take(id: String) -> void:
	if id == weapon_id and held != null:
		return
	weapon_id = id
	if held != null:
		held.queue_free()
	if left_hand != null:
		left_hand.queue_free()
		left_hand = null
	_magazine = null
	if id.is_empty():
		held = Node3D.new()
		held.name = "bare_mount"
		var fist := HeldGear.build_humiliation_hand(1)
		fist.name = "RightGripHand"
		HeldGear.set_pose(fist, "fist")
		fist.rotation = Vector3(-PI * 0.5, 0.0, PI * 0.5)
		fist.set_meta("forearm_entry", Vector3(0.47, -0.53, -0.30))
		held.add_child(fist)
	else:
		held = HunterArsenal._build_weapon_model(id)
	add_child(held)
	if held.get_node_or_null("LeftGripHand") == null:
		left_hand = HeldGear.build_humiliation_hand(-1)
		left_hand.name = "FreeLeftHand"
		left_hand.set_meta("forearm_entry", Vector3(-0.47, -0.53, -0.31))
		add_child(left_hand)
	_magazine = held.find_child("magazine", true, false) as Node3D
	if _magazine != null:
		_magazine_rest = _magazine.position
	if driver == null:
		moveset.configure("fists" if id.is_empty() else (id if SwordMoveset.WEAPON_TABLES.has(id) else "sword"), "two_hand" if id == "staff" else "one_hand")


## A blow with no `MeleeDriver` behind it (bare hands, a scripted room).
func strike(heavy := false) -> bool:
	var result := moveset.request_heavy(100.0) if heavy else moveset.request_light(100.0)
	var accepted := bool(result.get("accepted", false))
	if accepted:
		_whoosh_due = true
		_heavy_due = heavy
	return accepted


func inspect() -> void:
	inspect_left = INSPECT_SECONDS


## Struck: the arms are knocked back and down.
func flinch(strength := 1.0) -> void:
	_jolt += Vector3(0.02, -0.05, 0.07) * strength
	_jolt_turn += Vector3(0.35, 0.10, 0.20) * strength


## The blade met something: it stops and springs back off it.
func bounce(amount: float) -> void:
	_jolt += Vector3(0.0, 0.02, 0.9) * amount
	_jolt_turn += Vector3(6.0, 0.0, 0.0) * amount


func recoil() -> void:
	_jolt += Vector3(0.0, 0.012, 0.05)
	_jolt_turn += Vector3(0.22, 0.0, 0.0)


func active_moveset() -> SwordMoveset:
	return driver.moveset if driver != null else moveset


func _process(delta: float) -> void:
	if arsenal != null:
		take(str(arsenal.current_id))
	elif held == null:
		take("")
	if driver == null:
		moveset.tick(delta)
		if _whoosh_due and moveset.phase() == "active":
			_whoosh_due = false
			if _audio == null:
				_audio = FpCombatAudio.new()
				add_child(_audio)
			_audio.whoosh("bare" if weapon_id.is_empty() else weapon_id, _heavy_due)
	pose(delta)


## One frame of every layer; public so a test can step it without a tree.
func pose(delta: float) -> void:
	if held == null:
		return
	_time += delta
	inspect_left = maxf(0.0, inspect_left - delta)
	var camera := get_parent() as Node3D
	var rest: Dictionary = REST.get(weapon_id, REST.default)
	var key := {"swing": Vector3.ZERO, "wrist": Vector3.ZERO, "reach": Vector3.ZERO}
	var left_key := {"swing": Vector3.ZERO, "wrist": Vector3.ZERO, "reach": Vector3.ZERO}
	var swinging_left := false
	last_phase = "rest"
	var current := active_moveset()
	if current.is_attacking():
		var definition := current.current_definition()
		var arc: Dictionary = ARCS[_arc_of(definition)]
		var mirror := str(definition.get("side", "right")) == "left"
		if driver != null and driver.swing_mirrored():
			mirror = not mirror
		var progress := current.phase_progress()
		var phase := current.phase()
		last_phase = phase
		var swing: Dictionary
		match phase:
			"windup": swing = _blend(key, arc.windup, ease(progress, 0.4))
			"active":
				swing = _blend(arc.windup, arc.strike, progress * 2.0) if progress < 0.5 else _blend(arc.strike, arc.follow, progress * 2.0 - 1.0)
			_: swing = _blend(arc.follow, key, ease(progress, -2.0))
		# Bare hands: a left-side blow is thrown by the left fist.
		if weapon_id.is_empty() and mirror:
			swinging_left = true
			left_key = swing
		elif mirror and _arc_of(definition) != "thrust":
			key = _mirrored(swing)
			key.swing *= Vector3(1.0, BACKHAND, BACKHAND)
		else:
			key = swing
	elif driver != null and driver.heavy_held >= 0.0:
		var charge := clampf(driver.heavy_held / SwordMoveset.CHARGED_HEAVY_SECONDS, 0.0, 1.0)
		var held_arc: Dictionary = ARCS[_arc_of(driver.moveset.attack_definition("heavy"))]
		key = _blend(key, held_arc.windup, ease(charge, 0.5))
		# A full charge trembles.
		key.reach += Vector3(sin(_time * 53.0), cos(_time * 47.0), 0.0) * 0.004 * charge
		last_phase = "charging"
	elif inspect_left > 0.0:
		var through := 1.0 - inspect_left / INSPECT_SECONDS
		var amount := smoothstep(0.0, 0.2, through) * (1.0 - smoothstep(0.8, 1.0, through))
		key = _blend(key, INSPECT, amount)
		# Turned over halfway through, to see the other face.
		key.wrist += Vector3(0.0, 0.0, -2.2) * smoothstep(0.4, 0.6, through) * amount
		last_phase = "inspect"
	elif arsenal != null and arsenal.reload_remaining > 0.0:
		var total := float(arsenal.current().get("reload", 1.0))
		var through := 1.0 - arsenal.reload_remaining / maxf(total, 0.01)
		key = _blend(key, RELOAD, sin(clampf(through, 0.0, 1.0) * PI))
		last_phase = "reload"
	var guarding := driver != null and driver.guard_held and driver.melee_held()
	_guard_amount = move_toward(_guard_amount, 1.0 if guarding else 0.0, delta * 9.0)
	if _guard_amount > 0.0 and not current.is_attacking():
		key = _blend(key, GUARD, ease(_guard_amount, -1.6))
		if guarding:
			last_phase = "block"
	if driver != null and driver.parry_left > 0.0:
		key = _blend(key, PARRY, sin(driver.parry_left / MeleeDriver.PARRY_WINDOW * PI))
		last_phase = "parry"
	if _magazine != null:
		var dropping := 0.0
		if arsenal != null and arsenal.reload_remaining > 0.0:
			var through := 1.0 - arsenal.reload_remaining / maxf(float(arsenal.current().get("reload", 1.0)), 0.01)
			dropping = smoothstep(0.1, 0.3, through) * (1.0 - smoothstep(0.6, 0.85, through))
		_magazine.position = _magazine_rest + MAGAZINE_DROP * dropping
	last_swing = key.swing
	var sway := _sway(delta, camera)
	held.transform = _compose(SHOULDER, rest, key, sway)
	if left_hand != null:
		var left_rest: Dictionary = LEFT_REST
		if _guard_amount > 0.0 or weapon_id.is_empty():
			left_rest = {"at": LEFT_REST.at.lerp(LEFT_GUARD.at, maxf(_guard_amount, 0.7 if weapon_id.is_empty() else 0.0)), "turn": LEFT_GUARD.turn}
		var placed := _compose(LEFT_SHOULDER, left_rest, _mirrored(left_key) if swinging_left else left_key, sway)
		# Fingers forward, palm in: the same turn the grip mount gives a hand.
		left_hand.transform = Transform3D(placed.basis * Basis.from_euler(Vector3(-PI * 0.5, 0.0, -PI * 0.5)) * Basis.from_scale(Vector3.ONE * 1.16), placed.origin)
		HeldGear.set_pose(left_hand, "fist" if weapon_id.is_empty() or _guard_amount > 0.3 else "cup")
	# The pistol comes up onto its sights through the owner's ADS.
	if ads != null and aim_blend > 0.0 and is_inside_tree() and camera != null:
		ads.pose(held, camera.global_transform, weapon_id, aim_blend)
	_jolt = _jolt.lerp(Vector3.ZERO, clampf(delta * 12.0, 0.0, 1.0))
	_jolt_turn = _jolt_turn.lerp(Vector3.ZERO, clampf(delta * 12.0, 0.0, 1.0))
	if is_inside_tree() and camera is Camera3D:
		for hand in [held.get_node_or_null("RightGripHand"), held.get_node_or_null("LeftGripHand"), left_hand]:
			stretch_forearm(hand as Node3D, camera as Camera3D)


## Hand transform: the arm turns about `shoulder`, the wrist turns the weapon.
func _compose(shoulder: Vector3, rest: Dictionary, key: Dictionary, sway: Vector3) -> Transform3D:
	var arm := Basis.from_euler(key.swing + _jolt_turn * 0.4)
	var at: Vector3 = shoulder + arm * ((rest.at as Vector3) - shoulder + (key.reach as Vector3)) + sway + _jolt
	return Transform3D(arm * Basis.from_euler((rest.turn as Vector3) + (key.wrist as Vector3) + _jolt_turn * 0.6), at)


## Breathing, walk bob and look lag, in camera space.
func _sway(delta: float, camera: Node3D) -> Vector3:
	var speed := 0.0
	if body != null and is_instance_valid(body):
		speed = Vector2(body.velocity.x, body.velocity.z).length()
		if not body.is_on_floor():
			speed = 0.0
	_step += delta * (1.2 + speed * 1.7)
	var walk := clampf(speed / 4.0, 0.0, 1.4)
	var bob := Vector3(sin(_step) * 0.014 * walk, -absf(cos(_step)) * 0.016 * walk, 0.0)
	var breath := Vector3(sin(_time * 0.9) * 0.003, sin(_time * 1.4) * 0.004, 0.0)
	if camera != null and camera.is_inside_tree():
		var forward := -camera.global_basis.z
		if _last_forward != Vector3.ZERO and delta > 0.0:
			var basis := camera.global_basis
			var turn := Vector2((forward - _last_forward).dot(basis.x), (forward - _last_forward).dot(basis.y))
			_look_lag = _look_lag.lerp(-turn * 2.2, clampf(delta * 10.0, 0.0, 1.0))
		_last_forward = forward
	_look_lag = _look_lag.lerp(Vector2.ZERO, clampf(delta * 6.0, 0.0, 1.0)).limit_length(0.05)
	return bob + breath + Vector3(_look_lag.x, _look_lag.y, 0.0)


static func _arc_of(definition: Dictionary) -> String:
	var motion := str(definition.get("motion", ""))
	if motion.contains("thrust") or motion in ["jab", "shove"]:
		return "thrust"
	if str(definition.get("side", "")) == "high" or motion == "overhead":
		return "overhead"
	return "side"


static func _blend(a: Dictionary, b: Dictionary, weight: float) -> Dictionary:
	var out := {}
	for part in ["swing", "wrist", "reach"]:
		out[part] = (a.get(part, Vector3.ZERO) as Vector3).lerp(b.get(part, Vector3.ZERO) as Vector3, weight)
	return out


static func _mirrored(key: Dictionary) -> Dictionary:
	var flip := Vector3(1, -1, -1)
	return {"swing": (key.swing as Vector3) * flip, "wrist": (key.wrist as Vector3) * flip, "reach": (key.reach as Vector3) * Vector3(-1, 1, 1)}


## The sleeve from the hand's wrist out to its off-screen elbow entry, the
## same stretch the Hunt gives its first-person hands.
static func stretch_forearm(hand: Node3D, camera: Camera3D) -> void:
	if hand == null or not is_instance_valid(hand):
		return
	var forearm := hand.get_node_or_null("FirstPersonForearm") as Node3D
	if forearm == null:
		return
	forearm.top_level = true
	var side := int(hand.get_meta("screen_entry_side", 1))
	var entry: Vector3 = hand.get_meta("forearm_entry", Vector3(0.43 * float(side), -0.49, -0.30))
	var start := camera.to_global(entry)
	var end := hand.to_global(Vector3(0.0, 0.0, -0.035))
	var along := end - start
	var length := maxf(along.length(), 0.08)
	forearm.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, along.normalized())), start)
	var sleeve := forearm.get_node_or_null("TaperedSleeve") as MeshInstance3D
	if sleeve != null:
		(sleeve.mesh as CylinderMesh).height = length
		sleeve.position.y = length * 0.5
