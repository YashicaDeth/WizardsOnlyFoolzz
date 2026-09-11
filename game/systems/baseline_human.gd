class_name BaselineHuman
extends Node3D

## One rig for every person in the world.
##
## Before this, each call site built its own body with its own zone vocabulary:
## the derby tagged a driver hitbox "legs", the hunt recorded Mara's wounds as
## "left arm", and AnatomyComponent only knows left_arm/left_leg/right_leg.
## Names it does not recognise silently resolve to "torso", so a severed leg was
## recorded as a chest wound and nothing downstream could tell the difference.
## Derby drivers skipped anatomy altogether and carried a loose driver_health
## integer instead.
##
## The rig owns the vocabulary, the hit geometry and the anatomy state together,
## so a body behaves the same wherever it is spawned. That is what "bodies
## remember" needs in order to apply to anyone rather than to hand-authored
## characters only. `head_anchor` exists so proximity voice has one consistent
## place to speak from.

signal zone_disabled(zone_id: String)

const ZONES := ["head", "torso", "left_arm", "right_arm", "left_leg", "right_leg"]
const LIMBS := ["left_arm", "right_arm", "left_leg", "right_leg"]

## Every loose spelling that existed at a call site, mapped onto the canonical
## zone. Kept so old saves and old events stay readable rather than resolving to
## the torso forever.
const ZONE_ALIASES := {
	"legs": "left_leg", "leg": "left_leg", "arm": "left_arm",
	"left arm": "left_arm", "right arm": "right_arm",
	"left leg": "left_leg", "right leg": "right_leg",
	"chest": "torso", "body": "torso", "skull": "head",
}

const STANDING := {
	"head": {"at": Vector3(0, 1.62, 0), "size": Vector3(0.26, 0.28, 0.26)},
	"torso": {"at": Vector3(0, 1.12, 0), "size": Vector3(0.48, 0.66, 0.28)},
	"left_arm": {"at": Vector3(-0.34, 1.12, 0), "size": Vector3(0.17, 0.62, 0.19)},
	"right_arm": {"at": Vector3(0.34, 1.12, 0), "size": Vector3(0.17, 0.62, 0.19)},
	"left_leg": {"at": Vector3(-0.14, 0.42, 0), "size": Vector3(0.21, 0.84, 0.23)},
	"right_leg": {"at": Vector3(0.14, 0.42, 0), "size": Vector3(0.21, 0.84, 0.23)},
}

## Same zones, folded into a cab. A seated driver still has to be hittable in
## the right place, so this is a layout change rather than a different rig.
const SEATED := {
	"head": {"at": Vector3(0, 1.16, 0), "size": Vector3(0.26, 0.28, 0.26)},
	"torso": {"at": Vector3(0, 0.74, 0), "size": Vector3(0.48, 0.60, 0.28)},
	"left_arm": {"at": Vector3(-0.32, 0.76, -0.12), "size": Vector3(0.17, 0.52, 0.19)},
	"right_arm": {"at": Vector3(0.32, 0.76, -0.12), "size": Vector3(0.17, 0.52, 0.19)},
	"left_leg": {"at": Vector3(-0.14, 0.34, -0.30), "size": Vector3(0.21, 0.26, 0.62)},
	"right_leg": {"at": Vector3(0.14, 0.34, -0.30), "size": Vector3(0.21, 0.26, 0.62)},
}

const BONE := Color("cfc2a4")
const BLOOD := Color("6b0f0c")
const BLOOD_DARK := Color("3d0907")
const ORGAN := Color("7a1a16")
## Below this share of a zone's health the bone has gone through the skin and
## stays gone: a compound fracture is a state of the body, not an effect.
const FRACTURE_RATIO := 0.4
## Loose gore is capped across every body at once. Twelve drivers shedding
## unbounded blood in a pileup is a frame-rate bug, not atmosphere.
const MAX_LIVE_GORE := 140

static var live_gore := 0
## Scales every effect count at once, driven by the GORE setting in the menu
## rather than by a hotkey over the pit. 0 is handled by the `gore` flag.
static var detail := 1.0

var anatomy: AnatomyComponent
var head_anchor: Node3D
var subject_id := ""
var parts: Dictionary = {}
var severed: Array[String] = []
var gore := true

var _flesh := Color("6b5842")
var _seated := false
var _variation := 0
var _loose: Array[Dictionary] = []


static func canonical_zone(zone_id: String) -> String:
	var lowered := zone_id.strip_edges().to_lower()
	if ZONES.has(lowered):
		return lowered
	return str(ZONE_ALIASES.get(lowered, "torso"))


func build(id: String, config: Dictionary = {}) -> void:
	subject_id = id
	_seated = bool(config.get("seated", false))
	_flesh = config.get("flesh", Color("6b5842")) as Color
	_variation = int(config.get("variation", 0))
	var layout: Dictionary = SEATED if _seated else STANDING

	for zone_id in ZONES:
		var spec: Dictionary = layout[zone_id]
		var part := MeshInstance3D.new()
		part.name = zone_id
		part.mesh = _zone_mesh(zone_id, spec.size)
		part.position = spec.at
		part.set_meta("rest_position", spec.at)
		add_child(part)
		parts[zone_id] = part

		var hitbox := Area3D.new()
		hitbox.name = "%s_hitbox" % zone_id
		hitbox.position = spec.at
		hitbox.set_meta("body_zone", zone_id)
		add_child(hitbox)
		var shape_node := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec.size
		shape_node.shape = box
		hitbox.add_child(shape_node)

	head_anchor = Node3D.new()
	head_anchor.name = "HeadAnchor"
	head_anchor.position = (layout.head as Dictionary).at + Vector3(0, 0.12, 0)
	add_child(head_anchor)

	anatomy = AnatomyComponent.new()
	anatomy.name = "Anatomy"
	add_child(anatomy)
	anatomy.configure(id, float(config.get("blood", 5000.0)), config.get("cybernetics", {}))
	if config.get("restore") is Dictionary:
		anatomy.restore(config.restore)
		for zone_id in ZONES:
			_refresh_zone(zone_id)


## Where a blow actually landed, rather than a round-robin through the zone
## list. This is the difference between hit geometry and a hit counter.
func zone_nearest(global_point: Vector3) -> String:
	var best := "torso"
	var best_distance := INF
	for zone_id in parts:
		var part := parts[zone_id] as Node3D
		if part == null or not is_instance_valid(part) or severed.has(zone_id):
			continue
		var distance: float = part.global_position.distance_to(global_point)
		if distance < best_distance:
			best_distance = distance
			best = str(zone_id)
	return best


func hit(zone_id: String, damage: float, impulse: float, damage_type := "blunt") -> Dictionary:
	var zone := canonical_zone(zone_id)
	var result := anatomy.apply_hit(zone, damage, impulse, damage_type)
	_refresh_zone(zone)
	if gore and damage >= 5.0:
		# Something that cuts opens you up; something that hits you bruises and
		# breaks. The wet count follows from which one landed.
		var penetrating := damage_type in ["cut", "puncture", "ballistic", "shear"]
		_spray(_zone_origin(zone), Vector3.UP, clampi(roundi(damage / (5.5 if penetrating else 11.0)), 1, 9))
	if bool(result.get("disabled", false)):
		zone_disabled.emit(zone)
	return result


func hit_at(global_point: Vector3, damage: float, impulse: float, damage_type := "blunt") -> Dictionary:
	return hit(zone_nearest(global_point), damage, impulse, damage_type)


func install_prosthetic(zone_id: String, part_data: Dictionary) -> void:
	var zone := canonical_zone(zone_id)
	anatomy.installed_parts[zone] = part_data.duplicate(true)
	# A replacement limb restores function; it does not restore the person.
	var restored := float(part_data.get("restores", 0.6))
	var zone_state: Dictionary = anatomy.zones.get(zone, {})
	if not zone_state.is_empty():
		var ceiling := float(AnatomyComponent.DEFAULT_ZONES[zone].health)
		zone_state["health"] = maxf(float(zone_state.health), ceiling * clampf(restored, 0.0, 1.0))
		anatomy.zones[zone] = zone_state
	severed.erase(zone)
	_refresh_zone(zone)


func snapshot() -> Dictionary:
	var state := anatomy.snapshot()
	state["severed"] = severed.duplicate()
	return state


func zone_health(zone_id: String) -> float:
	var zone: Dictionary = anatomy.zones.get(canonical_zone(zone_id), {})
	return float(zone.get("health", 0.0))


func _zone_mesh(zone_id: String, size: Vector3) -> Mesh:
	if zone_id == "head":
		var skull := SphereMesh.new()
		skull.radius = size.x * 0.5
		skull.height = size.y
		skull.material = WorldLook.surface(_flesh.lightened(0.06), "flesh", _variation + 3)
		return skull
	var limb := CapsuleMesh.new()
	limb.radius = minf(size.x, size.z) * 0.5
	limb.height = maxf(size.y, limb.radius * 2.0 + 0.01)
	limb.material = WorldLook.surface(_flesh, "flesh", _variation + ZONES.find(zone_id))
	return limb


## Damage reads on the body itself: a zone darkens as it fails, and a limb that
## reaches zero comes off rather than staying attached at full brightness.
func _refresh_zone(zone_id: String) -> void:
	var part := parts.get(zone_id) as MeshInstance3D
	if part == null or not is_instance_valid(part):
		return
	var zone: Dictionary = anatomy.zones.get(zone_id, {})
	if zone.is_empty():
		return
	var ceiling := float(AnatomyComponent.DEFAULT_ZONES[zone_id].health)
	var ratio := clampf(float(zone.health) / maxf(ceiling, 1.0), 0.0, 1.0)
	var prosthetic := anatomy.installed_parts.has(zone_id)
	var mesh := part.mesh as PrimitiveMesh
	if mesh != null:
		var tint := Color("8d9299") if prosthetic else _flesh.lerp(Color("3d0907"), 1.0 - ratio)
		mesh.material = WorldLook.surface(tint, "chrome" if prosthetic else "flesh", _variation + ZONES.find(zone_id))
	if gore and ratio < FRACTURE_RATIO and ratio > 0.0 and not prosthetic:
		_add_fracture(zone_id)
	if ratio <= 0.0 and LIMBS.has(zone_id) and not prosthetic:
		if not severed.has(zone_id):
			severed.append(zone_id)
			if gore:
				_add_stump(zone_id)
				_spray(_zone_origin(zone_id), Vector3.UP, 14)
		part.visible = false
		var hitbox := get_node_or_null("%s_hitbox" % zone_id) as Area3D
		if hitbox != null:
			hitbox.monitorable = false
	else:
		part.visible = true
		var restored := get_node_or_null("%s_hitbox" % zone_id) as Area3D
		if restored != null:
			restored.monitorable = true
		if prosthetic:
			var old_fracture := part.get_node_or_null("Fracture")
			if old_fracture != null:
				old_fracture.queue_free()
			var old_stump := get_node_or_null("%s_stump" % zone_id)
			if old_stump != null:
				old_stump.queue_free()
	if gore and zone_id == "torso" and ratio <= 0.0:
		_spill_guts()


func _zone_origin(zone_id: String) -> Vector3:
	var part := parts.get(zone_id) as Node3D
	if part != null and is_instance_valid(part) and part.is_inside_tree():
		return part.global_position
	return global_position if is_inside_tree() else Vector3.ZERO


## Gore lives in the world, not on the body, or a driver's blood would ride
## along inside the cab while the car keeps moving.
func _gore_root() -> Node:
	if not is_inside_tree():
		return self
	var scene := get_tree().current_scene
	return scene if scene != null else self


func _spray(origin: Vector3, bias: Vector3, count: int) -> void:
	var root := _gore_root()
	for index in maxi(1, roundi(count * detail)):
		if live_gore >= MAX_LIVE_GORE:
			return
		var drop := MeshInstance3D.new()
		var blob := SphereMesh.new()
		blob.radius = 0.026 + randf() * 0.046
		blob.height = blob.radius * 2.0
		blob.material = WorldLook.surface(BLOOD if index % 2 == 0 else BLOOD_DARK, "flesh", index + _variation)
		drop.mesh = blob
		root.add_child(drop)
		drop.global_position = origin + Vector3(randf_range(-0.09, 0.09), randf_range(-0.09, 0.09), randf_range(-0.09, 0.09))
		var spread := (bias.normalized() + Vector3(randf_range(-0.75, 0.75), randf_range(0.05, 0.7), randf_range(-0.75, 0.75))).normalized()
		_loose.append({"node": drop, "velocity": spread * (1.9 + randf() * 3.6), "life": 1.3 + randf() * 1.0})
		live_gore += 1


## Organs leave the body once the chest does. They are heavier and wetter than
## spray, so they fall short and stay put rather than misting.
func _spill_guts() -> void:
	if has_meta("gutted"):
		return
	set_meta("gutted", true)
	var root := _gore_root()
	var origin := _zone_origin("torso")
	for index in maxi(2, roundi(8 * detail)):
		if live_gore >= MAX_LIVE_GORE:
			return
		var organ := MeshInstance3D.new()
		var blob := SphereMesh.new()
		blob.radius = 0.075 + randf() * 0.07
		blob.height = blob.radius * 2.0 * (1.2 + randf() * 0.9)
		blob.material = WorldLook.surface(ORGAN.lerp(BLOOD_DARK, randf()), "flesh", index + _variation + 9)
		organ.mesh = blob
		root.add_child(organ)
		organ.global_position = origin + Vector3(randf_range(-0.12, 0.12), randf_range(-0.1, 0.1), randf_range(-0.12, 0.12))
		var spill := Vector3(randf_range(-1.0, 1.0), randf_range(-0.1, 0.35), randf_range(-1.0, 1.0)).normalized()
		_loose.append({"node": organ, "velocity": spill * (0.8 + randf() * 1.7), "life": 6.0 + randf() * 3.0})
		live_gore += 1


## A compound fracture is permanent. It rides with the limb because it is part
## of the limb now.
func _add_fracture(zone_id: String) -> void:
	var part := parts.get(zone_id) as Node3D
	if part == null or not is_instance_valid(part) or part.has_node("Fracture"):
		return
	var shard := MeshInstance3D.new()
	shard.name = "Fracture"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.042, 0.15 + randf() * 0.11, 0.042)
	mesh.material = WorldLook.surface(BONE, "bone", _variation + 4)
	shard.mesh = mesh
	shard.position = Vector3(randf_range(-0.05, 0.05), randf_range(-0.13, 0.13), 0.07)
	shard.rotation = Vector3(randf_range(-0.8, 0.8), 0.0, randf_range(-1.0, 1.0))
	part.add_child(shard)


func _add_stump(zone_id: String) -> void:
	if has_node("%s_stump" % zone_id):
		return
	var layout: Dictionary = SEATED if _seated else STANDING
	var spec: Dictionary = layout[zone_id]
	var stump := MeshInstance3D.new()
	stump.name = "%s_stump" % zone_id
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.058
	mesh.height = 0.19
	mesh.material = WorldLook.surface(BONE, "bone", _variation + 6)
	stump.mesh = mesh
	# Sit the exposed bone between the torso and where the limb used to be, so
	# it reads as a joint rather than a floating spike.
	stump.position = (spec.at as Vector3).lerp((layout.torso as Dictionary).at as Vector3, 0.45)
	add_child(stump)


func _process(delta: float) -> void:
	if _loose.is_empty():
		return
	for index in range(_loose.size() - 1, -1, -1):
		var piece: Dictionary = _loose[index]
		var node := piece.node as Node3D
		if node == null or not is_instance_valid(node):
			_loose.remove_at(index)
			live_gore = maxi(0, live_gore - 1)
			continue
		piece.velocity.y -= 11.0 * delta
		node.global_position += piece.velocity * delta
		piece.life -= delta
		if piece.life <= 0.0:
			node.queue_free()
			_loose.remove_at(index)
			live_gore = maxi(0, live_gore - 1)
