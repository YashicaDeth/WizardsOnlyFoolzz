class_name V01Sentinel
extends V01Foe

## The Lower Works sentinel (job 9; Greg 5 Oct 02:10: "the Lower Works
## sentinel (a machine with armour plates for the X-ray)"). A tracked CellOutz
## machine, red eye, patrol lamp, a piston ram arm, and four armour plates:
## front, left, right and the sensor cowl. Its coolant core is caged on its
## back.
##
## The plates are why it needs the right weapon (Greg: "need the right weapon
## or a shot to a weak point"), and the X-ray (Q / d-pad up) shows where each
## plate is, how much is left of it, and the two weak points:
## - **Cleaver / fists** on a plate: sparks and a chip; the plate takes the
##   blow. Heavy blows break plates off. Behind it, on the core, blows bite
##   double. It turns slowly: circle it.
## - **PRODSTAFF charged shock** conducts through the plates: full damage and
##   a long overload stun (eye dark, core venting).
## - **Pistol** rounds ricochet off plates. A round in the EYE blinds it for a
##   few seconds (it loses you and only swings at what touches it); a round in
##   the CORE takes two and a half times the damage.
##
## Its blows: the RAM (red: its eye flares, it rears back, then charges along
## the line it locked; it overshoots and vents, core open) and the piston
## SLAM up close (copper: blockable, never parryable; it is a machine).

## DIALS (REMASTER_LOG job9).
const HEALTH := 320.0
const SPEED := 1.7
const TURN_RATE := 1.5
const SIGHT_RANGE := 13.0
const SIGHT_DOT := 0.5
const NEAR_NOTICE := 3.0
const RAM_RANGE := Vector2(3.6, 12.0)
const RAM_WINDUP := 1.0
const RAM_LOCK := 0.8
const RAM_SPEED := 9.0
## It charges through where you stood and this far past, then vents.
const RAM_OVERSHOOT := 2.6
const RAM_DISTANCE := 9.0
const RAM_HIT := 1.15
const VENT_SECONDS := 2.0
const SLAM_RANGE := 2.3
const SLAM_WINDUP := 0.85
const REST := 1.2
const SHARE := {"ram": 0.17, "slam": 0.11}
## Through an intact plate, a blow does this share of its damage.
const PLATE_PASS := 0.15
## Behind a plate that has come off, the works take this share.
const EXPOSED_SHARE := 0.5
## How much of a blow a plate soaks as wear: light blows chip, heavies break.
const CHIP_LIGHT := 0.35
const CHIP_HEAVY := 1.2
const PLATE_HEALTH := {"front": 130.0, "left": 90.0, "right": 90.0, "cowl": 60.0}
const PLATE_ARMOUR := 0.85
const CORE_MULTIPLIER := 2.0
const CORE_SHOT_MULTIPLIER := 2.5
const SHOCK_STUN := 2.6
const BLIND_SECONDS := 3.0
## Its patrol line along the Lower Works' painted route.
var patrol: Array[Vector3] = []
var _patrol_index := 0

var plates := {}
var core: MeshInstance3D
var eye: MeshInstance3D
var eye_light: OmniLight3D
var lamp: SpotLight3D
var arm: Node3D
var blinded := 0.0
var overloaded := 0.0
var venting := 0.0
var ramming := 0.0
var ram_dir := Vector3.FORWARD
var ram_left := 0.0
var ram_hit_done := false
var rams := 0
var slams := 0
var plates_broken := 0
var _core_material: StandardMaterial3D
var _eye_material: StandardMaterial3D


func configure(points: Array[Vector3]) -> void:
	kind = "sentinel"
	max_health = HEALTH
	max_poise = 99
	patrol = points


func _subject_record() -> Dictionary:
	return {"kind": "machine", "status": "patrolling", "faction": "CellOutz Security", "place": "lower_works", "role": "sentinel"}


func _build_body() -> void:
	body = Node3D.new()
	body.name = "SentinelChassis"
	add_child(body)
	var grime := _tinted("grime", Color("4a4136"))
	var dark := _tinted("rust", Color("2c241e"))
	# Tracks and hull.
	for side in [-1.0, 1.0]:
		_box(body, "Track", Vector3(0.34, 0.46, 1.7), Vector3(side * 0.56, 0.23, 0), dark)
	_box(body, "Hull", Vector3(0.86, 0.36, 1.3), Vector3(0, 0.52, 0), grime)
	# The torso on its turret ring.
	var torso := _box(body, "Torso", Vector3(0.92, 1.0, 0.72), Vector3(0, 1.2, 0), grime)
	# Plates: proud of the torso, each its own piece so it can come off.
	var plate_mat := _tinted("plate", Color("6e6a5e"))
	plates["front"] = {"node": _box(body, "PlateFront", Vector3(0.98, 0.9, 0.08), Vector3(0, 1.22, -0.42), plate_mat), "health": PLATE_HEALTH.front, "tag": "FRONT PLATE"}
	plates["left"] = {"node": _box(body, "PlateLeft", Vector3(0.08, 0.86, 0.74), Vector3(-0.51, 1.2, 0), plate_mat), "health": PLATE_HEALTH.left, "tag": "LEFT PLATE"}
	plates["right"] = {"node": _box(body, "PlateRight", Vector3(0.08, 0.86, 0.74), Vector3(0.51, 1.2, 0), plate_mat), "health": PLATE_HEALTH.right, "tag": "RIGHT PLATE"}
	var head := _box(body, "Head", Vector3(0.5, 0.32, 0.46), Vector3(0, 1.88, -0.05), dark)
	plates["cowl"] = {"node": _box(body, "PlateCowl", Vector3(0.58, 0.1, 0.56), Vector3(0, 2.08, -0.05), plate_mat), "health": PLATE_HEALTH.cowl, "tag": "SENSOR COWL"}
	# The eye: always red (Greg 5 Oct: red only on danger; this is danger).
	eye = MeshInstance3D.new()
	eye.name = "Eye"
	var ball := SphereMesh.new()
	ball.radius = 0.07
	ball.height = 0.14
	eye.mesh = ball
	_eye_material = glow_material(Color("3a0a08"), 0.2)
	_eye_material.emission = RED
	_eye_material.emission_energy_multiplier = 2.5
	eye.material_override = _eye_material
	eye.position = Vector3(0, 1.88, -0.29)
	body.add_child(eye)
	eye_light = OmniLight3D.new()
	eye_light.light_color = RED
	eye_light.light_energy = 1.2
	eye_light.omni_range = 3.5
	eye_light.position = Vector3(0, 1.88, -0.5)
	body.add_child(eye_light)
	# The patrol lamp sweeping ahead of it.
	lamp = SpotLight3D.new()
	lamp.name = "PatrolLamp"
	lamp.light_color = Color("d2ecc0")
	lamp.light_energy = 3.0
	lamp.spot_range = 11.0
	lamp.spot_angle = 18.0
	lamp.shadow_enabled = false
	lamp.position = Vector3(0, 1.95, -0.3)
	lamp.rotation.x = -0.32
	body.add_child(lamp)
	# The core on its back, in a cage: the weak point.
	core = MeshInstance3D.new()
	core.name = "CoolantCore"
	var cell := CylinderMesh.new()
	cell.top_radius = 0.16
	cell.bottom_radius = 0.16
	cell.height = 0.5
	core.mesh = cell
	_core_material = StandardMaterial3D.new()
	_core_material.albedo_color = Color("3c4a3a")
	_core_material.emission_enabled = true
	_core_material.emission = Color("9fb38a")
	_core_material.emission_energy_multiplier = 1.2
	core.material_override = _core_material
	core.position = Vector3(0, 1.22, 0.44)
	body.add_child(core)
	for bar_x in [-0.12, 0.0, 0.12]:
		_box(body, "CoreCage", Vector3(0.025, 0.56, 0.025), Vector3(bar_x, 1.22, 0.62), dark)
	# The piston arm on its right, a ram head at the end.
	arm = Node3D.new()
	arm.name = "RamArm"
	arm.position = Vector3(0.62, 1.45, -0.1)
	body.add_child(arm)
	_box(arm, "Piston", Vector3(0.16, 0.16, 0.9), Vector3(0, -0.1, -0.45), dark)
	var ram_head := _box(arm, "RamHead", Vector3(0.3, 0.3, 0.22), Vector3(0, -0.1, -0.95), plate_mat)
	ram_head.material_override = glow_material(Color("4e4a40"))
	body.rotation.y = 0.0
	if not patrol.is_empty():
		var first := patrol[0] - global_position
		face(first, 1.0)


func _tinted(role: String, tint: Color) -> StandardMaterial3D:
	var material := LabSurface.material(role).duplicate() as StandardMaterial3D
	material.albedo_color = tint
	return material


func _box(parent: Node3D, label: String, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node


func glint_anchor() -> Node3D:
	if winding == "slam" and arm != null:
		return arm.get_node_or_null("RamHead") as Node3D
	return eye


func weak_points() -> Array:
	var out := []
	if eye != null and blinded <= 0.0:
		out.append({"at": eye.global_position, "radius": 0.13, "part": "eye"})
	if core != null:
		out.append({"at": core.global_position, "radius": 0.2, "part": "core"})
	return out


# --- What the X-ray reads (XrayScanOverlay, `xray_report`). -------------------------

func xray_report() -> Dictionary:
	var out := {"subject": foe_id, "implants": [], "plates": [], "organs": [], "damaged": [], "value": 0}
	for side: String in ["front", "left", "right", "cowl"]:
		var plate: Dictionary = plates[side]
		var condition := clampf(float(plate.health) / float(PLATE_HEALTH[side]), 0.0, 1.0)
		var entry := {"site": side, "zone": side, "name": str(plate.tag), "tag": str(plate.tag), "role": "plate", "condition": snappedf(condition, 0.01), "armour": PLATE_ARMOUR * float(condition > 0.0), "active": condition > 0.0, "shorted": false, "burnt": condition <= 0.0}
		out.implants.append(entry)
		if condition > 0.0:
			out.plates.append(entry)
	out.implants.append({"site": "core", "zone": "core", "name": "COOLANT CORE", "tag": "CORE  WEAK POINT", "role": "core", "condition": snappedf(health / max_health, 0.01), "armour": 0.0, "active": true, "shorted": overloaded > 0.0, "burnt": false})
	out.implants.append({"site": "eye", "zone": "eye", "name": "EYE", "tag": "EYE  SHOOT TO BLIND", "role": "sensor", "condition": 1.0, "armour": 0.0, "active": blinded <= 0.0, "shorted": blinded > 0.0, "burnt": false})
	out.value = 40 + plates_broken * 10
	return out


## Where an X-ray tag hangs for one report entry.
func xray_point(entry: Dictionary) -> Vector3:
	match str(entry.get("site", "")):
		"core":
			return core.global_position
		"eye":
			return eye.global_position
	var plate: Dictionary = plates.get(str(entry.get("site", "")), {})
	var node := plate.get("node") as Node3D
	return node.global_position if node != null and is_instance_valid(node) and node.is_inside_tree() else global_position + Vector3.UP


# --- Its mind. ----------------------------------------------------------------------

func facts(distance: float) -> Dictionary:
	var to: Vector3 = host.player_body().global_position - global_position
	to.y = 0.0
	return {
		"reeling": overloaded > 0.0 or venting > 0.0,
		"winding": winding != "" or ramming > 0.0,
		"unaware": state == "idle",
		"blind": blinded > 0.0,
		"slam_range": distance <= SLAM_RANGE and forward().dot(to.normalized()) > 0.3,
		"ram_range": distance >= RAM_RANGE.x and distance <= RAM_RANGE.y and host.line_of_sight(self),
		"ready": attack_clock >= REST,
	}


func branches() -> Array:
	return [
		[[["reeling", true]], "vent"],
		[[["winding", true]], "busy"],
		[[["unaware", true]], "patrol"],
		[[["slam_range", true], ["ready", true]], "slam"],
		[[["blind", true]], "grope"],
		[[["ram_range", true], ["ready", true]], "ram"],
		[[], "advance"],
	]


func step(delta: float) -> void:
	blinded = maxf(0.0, blinded - delta)
	overloaded = maxf(0.0, overloaded - delta)
	venting = maxf(0.0, venting - delta)
	var dark := blinded > 0.0 or overloaded > 0.0
	_eye_material.emission_energy_multiplier = 0.2 if dark else (2.5 if winding == "" else _eye_material.emission_energy_multiplier)
	eye_light.light_energy = 0.0 if dark else 1.2
	lamp.visible = not dark
	_core_material.emission_energy_multiplier = 5.0 if (overloaded > 0.0 or venting > 0.0) else 1.2
	super.step(delta)


func act(action: String, delta: float, to_player: Vector3, distance: float) -> void:
	match action:
		"vent":
			# Overloaded or venting after a ram: still, core blazing.
			body.rotation.z = sin(Time.get_ticks_msec() * 0.05) * 0.015 if overloaded > 0.0 else 0.0
		"busy":
			_busy(delta, to_player, distance)
		"patrol":
			_patrol(delta, to_player, distance)
		"slam":
			slams += 1
			begin("slam", {"windup": SLAM_WINDUP, "colour": COPPER, "parryable": false, "blockable": true, "share": SHARE.slam, "zone": "torso", "type": "blunt", "shove": 4.0})
			_set_glint(COPPER)
		"ram":
			rams += 1
			begin("ram", {"windup": RAM_WINDUP, "colour": RED, "parryable": false, "blockable": false, "share": SHARE.ram, "zone": "torso", "type": "blunt", "shove": 6.0})
			ram_dir = to_player.normalized()
		"grope":
			# Blind: it swings its lamp-less head about and creeps forward.
			body.rotation.y += sin(Time.get_ticks_msec() * 0.003) * delta * 1.2
			walk(forward() * SPEED * 0.4 * delta)
		_:
			_turn_toward(to_player, delta)
			if distance > SLAM_RANGE * 0.8:
				walk(forward() * SPEED * delta)


func _turn_toward(to: Vector3, delta: float) -> void:
	if to.length_squared() < 0.0001:
		return
	var target := atan2(-to.x, -to.z)
	var gap := wrapf(target - body.rotation.y, -PI, PI)
	body.rotation.y += clampf(gap, -TURN_RATE * delta, TURN_RATE * delta)


func _patrol(delta: float, to_player: Vector3, distance: float) -> void:
	if not patrol.is_empty():
		var goal := patrol[_patrol_index % patrol.size()]
		var to_goal := goal - global_position
		to_goal.y = 0.0
		if to_goal.length() < 0.5:
			_patrol_index += 1
		else:
			_turn_toward(to_goal, delta)
			walk(forward() * SPEED * 0.6 * delta)
	lamp.rotation.y = sin(Time.get_ticks_msec() * 0.0011) * 0.5
	if distance <= NEAR_NOTICE or (distance <= SIGHT_RANGE and forward().dot(to_player.normalized()) >= SIGHT_DOT and host.line_of_sight(self)):
		alert(host.player_body().global_position)
		lamp.rotation.y = 0.0
		flash(RED, 6.0)


func _busy(delta: float, to_player: Vector3, distance: float) -> void:
	if ramming > 0.0:
		var stride := minf(RAM_SPEED * delta, ram_left)
		ram_left -= stride
		walk(ram_dir * stride)
		ramming = maxf(0.0, ramming - delta)
		var to: Vector3 = host.player_body().global_position - global_position
		to.y = 0.0
		if not ram_hit_done and to.length() <= RAM_HIT:
			ram_hit_done = true
			landed_on_player += 1
			host.hurt_player(self, "ram", move)
		if ramming <= 0.0 or ram_left <= 0.0:
			ramming = 0.0
			move = {}
			# It overshoots and vents: the core is open.
			venting = VENT_SECONDS
			attack_clock = 0.0
			body.rotation.x = 0.0
			WorldHistory.record_event("v01_sentinel_vent", {"hit": ram_hit_done})
		return
	if winding == "ram":
		var amount := windup / RAM_WINDUP
		# It rears back; it tracks you until the line locks.
		body.rotation.x = 0.18 * ease(clampf(amount, 0.0, 1.0), 0.5)
		if amount < RAM_LOCK:
			_turn_toward(to_player, delta * 2.0)
			ram_dir = forward()
		_eye_material.emission_energy_multiplier = 3.0 + amount * 9.0
		if advance(delta):
			var spec := move
			cancel_windup()
			move = spec
			ram_hit_done = false
			var gap: Vector3 = host.player_body().global_position - global_position
			gap.y = 0.0
			ram_left = clampf(gap.length() + RAM_OVERSHOOT, 4.0, RAM_DISTANCE)
			ramming = ram_left / RAM_SPEED + 0.05
			body.rotation.x = -0.08
		return
	# The slam: the arm draws up, then comes down.
	var raise := clampf(windup / SLAM_WINDUP, 0.0, 1.0)
	arm.rotation.x = 0.9 * ease(raise, 0.6)
	_turn_toward(to_player, delta)
	if advance(delta):
		land(winding, distance)


func land(move_id: String, distance: float) -> void:
	var spec := move
	cancel_windup()
	arm.rotation.x = -0.35
	create_tween().tween_property(arm, "rotation:x", 0.0, 0.4)
	attack_clock = 0.0
	recover_left = 0.7
	var to: Vector3 = host.player_body().global_position - global_position
	to.y = 0.0
	if distance <= SLAM_RANGE + 0.35 and forward().dot(to.normalized()) > 0.1:
		landed_on_player += 1
		host.hurt_player(self, move_id, spec)


# --- What hits it. ------------------------------------------------------------------

## Which plate a blow from `from` meets, or "core" from behind.
func side_facing(from: Vector3) -> String:
	var to := from - global_position
	to.y = 0.0
	var dot := forward().dot(to.normalized())
	if dot >= 0.45:
		return "front"
	if dot <= -0.45:
		return "core"
	var right := forward().cross(Vector3.UP)
	return "right" if right.dot(to) > 0.0 else "left"


func take_blow(packet: Dictionary) -> Dictionary:
	if state == "dead":
		return {"result": "miss", "damage": 0.0}
	if state == "idle":
		alert(host.player_body().global_position)
	var damage := float(packet.get("damage", 0.0))
	var weapon := str(packet.get("weapon", ""))
	var part := str(packet.get("part", ""))
	if weapon == "gun":
		match part:
			"eye":
				blinded = BLIND_SECONDS
				cancel_windup()
				ramming = 0.0
				WorldHistory.record_event("v01_sentinel_blinded", {})
				return _count(packet, damage * 0.3, "weak")
			"core":
				return _count(packet, damage * CORE_SHOT_MULTIPLIER, "weak")
	if bool(packet.get("shock", false)):
		# The PRODSTAFF's charge goes through the plates into everything.
		overloaded = SHOCK_STUN
		cancel_windup()
		ramming = 0.0
		WorldHistory.record_event("v01_sentinel_overloaded", {})
		return _count(packet, damage, "weak")
	var side := part if part in ["front", "left", "right", "cowl"] else side_facing(packet.get("from", global_position))
	if side == "core":
		return _count(packet, damage * (CORE_MULTIPLIER if weapon != "gun" else 1.0), "weak")
	var plate: Dictionary = plates.get(side, {})
	if plate.is_empty() or float(plate.health) <= 0.0:
		# The plate is gone: into the works, still braced by the frame.
		return _count(packet, damage * EXPOSED_SHARE, "hit")
	if weapon == "gun":
		# A ricochet: nothing gets through, the plate barely marks.
		plate.health = maxf(0.0, float(plate.health) - damage * 0.1)
		flash(Color("ffcf6a"), 3.0)
		return {"result": "armour", "damage": 0.0}
	var chip := damage * (CHIP_HEAVY if str(packet.get("move", "")) in ["heavy", "charged_heavy"] else CHIP_LIGHT)
	plate.health = maxf(0.0, float(plate.health) - chip)
	flash(Color("ffcf6a"), 3.5)
	if float(plate.health) <= 0.0:
		_shed(side)
	var result := _count(packet, damage * PLATE_PASS, "armour")
	return result


func _count(packet: Dictionary, damage: float, result: String) -> Dictionary:
	hits_taken += 1
	health = maxf(0.0, health - damage)
	_recoil = clampf(damage / 60.0, 0.2, 0.8)
	WorldHistory.record_event("v01_foe_hit", {"foe": foe_id, "weapon": str(packet.get("weapon", "")), "damage": snappedf(damage, 0.1), "left": snappedf(health, 0.1), "result": result})
	if health <= 0.0:
		kill(str(packet.get("weapon", "")))
	return {"result": result, "damage": damage}


## A plate breaks off and falls where it stood.
func _shed(side: String) -> void:
	var plate: Dictionary = plates[side]
	var node := plate.get("node") as Node3D
	plates_broken += 1
	WorldHistory.record_event("v01_sentinel_plate_off", {"plate": side})
	if node == null or not is_instance_valid(node):
		return
	var at := node.global_transform
	node.get_parent().remove_child(node)
	host.add_child(node)
	node.global_transform = at
	var tween := node.create_tween()
	tween.tween_property(node, "global_position:y", floor_y + 0.05, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(node, "rotation:x", PI * 0.5, 0.35)


func stagger(_seconds: float) -> void:
	# A machine does not reel; only the shock and its own vent stop it.
	pass


func _die_body(_cause: String) -> void:
	# It powers down where it stands: eye out, lamp out, core dark, slumped.
	if _eye_material != null:
		_eye_material.emission_energy_multiplier = 0.0
	if eye_light != null:
		eye_light.light_energy = 0.0
	if lamp != null:
		lamp.visible = false
	if _core_material != null:
		_core_material.emission_energy_multiplier = 0.0
	if body != null:
		body.rotation.x = -0.12
		body.rotation.z = 0.06
	if arm != null:
		arm.rotation.x = -0.5
