class_name VatFloat
extends Node

## Slow, bounded buoyancy for a BaselineHuman suspended in a growth vat.
##
## The rig keeps the standing anatomy layout: this node moves that complete
## body through the medium and adds small, independent limb drift. Other
## animation (VatHorror in particular) is composed as an offset instead of
## overwriting either the body's rest pose or its buoyancy.

const LIMBS := ["left_arm", "right_arm", "left_leg", "right_leg"]

var rig: BaselineHuman
var tank_center := Vector3.ZERO
var tank_radius := 0.68
var tank_floor := 0.0
var tank_ceiling := 2.7
var seed_value := 0
var clock := 0.0
var rotation_bias := Vector3.ZERO

var _anchor_position := Vector3.ZERO
var _rest_rotation := Vector3.ZERO
var _part_rest: Dictionary = {}
var _part_offsets: Dictionary = {}
var _phase := 0.0
var _automatic := true


func setup(target: BaselineHuman, center: Vector3, radius: float, floor_y: float, ceiling_y: float, seed: int, automatic := true):
	rig = target
	tank_center = center
	tank_radius = radius
	tank_floor = floor_y
	tank_ceiling = ceiling_y
	seed_value = seed
	_automatic = automatic
	_phase = float(posmod(seed * 37, 101)) * 0.061
	_anchor_position = rig.position
	_rest_rotation = rig.rotation
	for part_id in LIMBS + ["head"]:
		var part := rig.parts.get(part_id) as Node3D
		if part != null:
			_part_rest[part_id] = part.rotation
	name = "VatFloat"
	process_priority = 10
	set_process(_automatic)
	rig.set_meta("vat_float", self)
	rig.set_meta("vat_seated", false)
	apply_pose()
	return self


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if rig == null or not is_instance_valid(rig):
		set_process(false)
		return
	clock += delta
	apply_pose()


func apply_pose() -> void:
	if rig == null or not is_instance_valid(rig):
		return
	# Different, deliberately incommensurate rates prevent the body tracing a
	# short mechanical loop. The excursion is small enough to keep every zone
	# inside the glass, but large enough to read over ten seconds.
	var radial_limit := maxf(0.0, tank_radius - 0.48)
	var x := sin(clock * 0.23 + _phase) * minf(0.055, radial_limit * 0.45)
	var z := sin(clock * 0.19 + _phase * 1.73) * minf(0.045, radial_limit * 0.38)
	var y := sin(clock * 0.41 + _phase * 0.71) * 0.045
	var radial := Vector2(x, z)
	if radial.length() > radial_limit and radial.length() > 0.0:
		radial = radial.normalized() * radial_limit
	rig.position = Vector3(tank_center.x + radial.x, _anchor_position.y + y, tank_center.z + radial.y)
	rig.rotation = _rest_rotation + rotation_bias + Vector3(
		0.045 + sin(clock * 0.29 + _phase) * 0.025,
		sin(clock * 0.17 + _phase * 0.43) * 0.075,
		sin(clock * 0.31 + _phase * 1.19) * 0.035
	)

	_float_limb("left_arm", Vector3(0.09, 0.0, -0.20), 0.0)
	_float_limb("right_arm", Vector3(0.09, 0.0, 0.20), 1.7)
	_float_limb("left_leg", Vector3(0.06, 0.0, -0.045), 3.1)
	_float_limb("right_leg", Vector3(-0.04, 0.0, 0.045), 4.4)
	var head := rig.parts.get("head") as Node3D
	if head != null and _part_rest.has("head"):
		head.rotation = (_part_rest["head"] as Vector3) + Vector3(
			sin(clock * 0.21 + _phase) * 0.018,
			sin(clock * 0.16 + _phase * 0.8) * 0.024,
			0.0
		) + (_part_offsets.get("head", Vector3.ZERO) as Vector3)
	_fit_vertical_bounds()


func _float_limb(part_id: String, buoyant_rest: Vector3, limb_phase: float) -> void:
	var part := rig.parts.get(part_id) as Node3D
	if part == null or not _part_rest.has(part_id):
		return
	var sway := sin(clock * 0.47 + _phase + limb_phase) * 0.055
	var drift := Vector3(sway, sin(clock * 0.23 + limb_phase) * 0.025, sway * 0.45)
	part.rotation = (_part_rest[part_id] as Vector3) + buoyant_rest + drift + (_part_offsets.get(part_id, Vector3.ZERO) as Vector3)


func set_part_offset(part_id: String, offset: Vector3) -> void:
	_part_offsets[part_id] = offset
	apply_pose()


func clear_part_offsets() -> void:
	if _part_offsets.is_empty():
		return
	_part_offsets.clear()
	apply_pose()


func add_rest_rotation(offset: Vector3) -> void:
	_rest_rotation += offset
	apply_pose()


func add_part_rest_rotation(part_id: String, offset: Vector3) -> void:
	if not _part_rest.has(part_id):
		return
	_part_rest[part_id] = (_part_rest[part_id] as Vector3) + offset
	apply_pose()


func nudge_anchor(offset: Vector3) -> void:
	_anchor_position += offset
	apply_pose()


func _fit_vertical_bounds() -> void:
	var bounds := body_vertical_bounds()
	if bounds.x < tank_floor + 0.015:
		rig.position.y += tank_floor + 0.015 - bounds.x
		bounds = body_vertical_bounds()
	if bounds.y > tank_ceiling - 0.015:
		rig.position.y -= bounds.y - (tank_ceiling - 0.015)


## Bounds in the rig parent's coordinate space, including the current loose
## limb and whole-body rotations. Tests use the same geometry the tank shows.
func body_vertical_bounds() -> Vector2:
	if rig == null or not is_instance_valid(rig):
		return Vector2.ZERO
	var low := INF
	var high := -INF
	for part_value in rig.parts.values():
		var part := part_value as MeshInstance3D
		if part == null or part.mesh == null or not part.visible:
			continue
		var box := part.mesh.get_aabb()
		for corner_index in 8:
			var corner := box.position + Vector3(
				box.size.x if corner_index & 1 else 0.0,
				box.size.y if corner_index & 2 else 0.0,
				box.size.z if corner_index & 4 else 0.0
			)
			var point := rig.transform * (part.transform * corner)
			low = minf(low, point.y)
			high = maxf(high, point.y)
	return Vector2(low, high) if low != INF else Vector2(rig.position.y, rig.position.y)


func inside_tank() -> bool:
	if rig == null or not is_instance_valid(rig):
		return false
	var from_center := Vector2(rig.position.x - tank_center.x, rig.position.z - tank_center.z)
	var vertical := body_vertical_bounds()
	return from_center.length() <= tank_radius and vertical.x >= tank_floor - 0.001 and vertical.y <= tank_ceiling + 0.001
