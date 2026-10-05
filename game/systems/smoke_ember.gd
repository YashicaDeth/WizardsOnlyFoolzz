class_name SmokeEmber
extends Node

## drug-70. The lit end of a smokeable as a physical thing.
##
## `Smokeables.set_draw()` already turns a draw into a brighter coal and a
## light; what it cannot do on its own is remember. This does:
##
## - **The coal has thermal mass.** It does not snap to the draw: it climbs
##   while you pull (fast) and fades after (slow), and the wind across it feeds
##   it a little, the way blowing on a coal does.
## - **Ash builds.** A column of ash grows off the lit end as it burns, faster
##   while drawing, and droops under its own weight as it lengthens.
## - **Ash falls.** A flick knocks it off. So does moving hard: the column holds
##   against the hand's acceleration up to a limit that drops as it gets longer,
##   so long ash goes on a sharp turn and short ash survives a sprint. Past its
##   own length it falls by itself. A fallen column is a real rigid body that
##   lands and crumbles into flecks.
## - **The lit end smokes** a thin sidestream into `SmokeVolume` while you are
##   not drawing on it.
##
## Rolled smokeables (cigarette, joint, spliff) carry an ash column; the vape
## has no coal and the bong's bowl goes to ash in place (`Smokeables`), so for
## those this only carries the heat.

## Longest the column grows before it falls on its own, in metres. A joint's
## loose roll drops ash sooner than a machine-made cigarette.
const ASH_LIMIT := {"cigarette": 0.024, "spliff": 0.02, "joint": 0.015}
## Metres of ash per second, at rest and at a full draw.
const ASH_IDLE_RATE := 0.0003
const ASH_DRAW_RATE := 0.006
## Acceleration (m/s^2) a column of full length holds against. Shorter ash
## holds much more (the limit scales with 1/length^1.5).
const ASH_HOLD_AT_LIMIT := 9.0
## Coal heat: how fast it climbs to a draw and how fast it falls back, per second.
const HEAT_RISE := 5.0
const HEAT_FALL := 1.1
const SIDESTREAM_EVERY := 0.18

## Dial: scale the ash's grip (higher holds longer).
static var ash_grip := 1.0

var model: Node3D
var device_id := ""
var smoke: SmokeVolume
## Where a fallen ash column goes (the world, not the hand).
var world: Node3D
var heat := 0.0
var ash_length := 0.0
var drops := 0
var last_drop_reason := ""
## Wind speed across the coal, m/s. Written by the owner.
var wind_speed := 0.0

var _column: MeshInstance3D
var _column_mesh: CylinderMesh
var _last_tip := Vector3.ZERO
var _last_velocity := Vector3.ZERO
var _has_last := false
var _side_clock := 0.0


func attach(device_model: Node3D, device: String, smoke_volume: SmokeVolume, world_node: Node3D) -> void:
	model = device_model
	device_id = device
	smoke = smoke_volume
	world = world_node
	heat = 0.0
	ash_length = 0.0
	_has_last = false
	if not ASH_LIMIT.has(device_id) or model == null or not model.has_meta("parts"):
		return
	var parts: Dictionary = model.get_meta("parts")
	var coal := parts.get("coal") as Node3D
	if coal == null:
		return
	_column_mesh = CylinderMesh.new()
	var radius := 0.0036
	var coal_mesh := (coal as MeshInstance3D).mesh as CylinderMesh
	if coal_mesh != null:
		radius = coal_mesh.top_radius * 1.02
	_column_mesh.top_radius = radius * 0.94
	_column_mesh.bottom_radius = radius
	_column_mesh.height = 0.001
	_column_mesh.radial_segments = 10
	_column_mesh.rings = 1
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("aaa398")
	material.roughness = 1.0
	_column_mesh.material = material
	_column = MeshInstance3D.new()
	_column.name = "AshColumn"
	_column.mesh = _column_mesh
	_column.visible = false
	model.add_child(_column)


func detach() -> void:
	if _column != null and is_instance_valid(_column):
		_column.queue_free()
	_column = null
	model = null


## `draw` is the live draw heat the owner computes (`Smokeables.draw_heat`),
## 0 when not drawing. `light_scale` passes through to `set_draw`.
func tick(delta: float, draw: float, light_scale := 1.0) -> void:
	if model == null or not is_instance_valid(model) or delta <= 0.0:
		return
	# Thermal mass, and a draught across the coal feeds it a little.
	var target := maxf(draw, clampf(wind_speed * 0.06, 0.0, 0.18))
	heat = move_toward(heat, target, delta * (HEAT_RISE if target > heat else HEAT_FALL))
	Smokeables.set_draw(model, heat, light_scale, sin(Time.get_ticks_msec() * 0.011) * 0.5 + 0.5)
	if _column == null:
		return
	var limit := float(ASH_LIMIT[device_id])
	ash_length += (ASH_IDLE_RATE + ASH_DRAW_RATE * clampf(draw, 0.0, 1.4)) * delta
	var tip := _tip_world()
	# The hand's acceleration, from the tip's own track.
	if _has_last:
		var velocity := (tip - _last_tip) / delta
		var accel := (velocity - _last_velocity) / delta
		_last_velocity = velocity
		# A teleport is not a hand movement.
		if ash_length > 0.002 and velocity.length() < 25.0 and accel.length() > hold_limit():
			_drop(velocity, "moved hard")
	else:
		_last_velocity = Vector3.ZERO
	_last_tip = tip
	_has_last = true
	if ash_length >= limit:
		_drop(_last_velocity, "too long")
	_shape_column()
	# A lit end you are not drawing on smokes a thin stream.
	if smoke != null and draw <= 0.05:
		_side_clock -= delta
		if _side_clock <= 0.0:
			_side_clock = SIDESTREAM_EVERY
			smoke.sidestream(tip)


## The acceleration the current column survives.
func hold_limit() -> float:
	var limit := float(ASH_LIMIT.get(device_id, 0.02))
	var fraction := clampf(ash_length / limit, 0.05, 1.0)
	return ASH_HOLD_AT_LIMIT * ash_grip / pow(fraction, 1.5)


## A flick of the thumb. Knocks off whatever has built, if anything has.
func flick(direction := Vector3.DOWN) -> bool:
	if _column == null or ash_length < 0.002:
		return false
	_drop(direction.normalized() * 0.6 + _last_velocity, "flicked")
	return true


func _tip_world() -> Vector3:
	var parts: Dictionary = model.get_meta("parts")
	var coal := parts.get("coal") as Node3D
	return coal.global_position if coal != null else model.global_position


func _shape_column() -> void:
	var parts: Dictionary = model.get_meta("parts")
	var coal := parts.get("coal") as Node3D
	_column.visible = ash_length > 0.0008
	if not _column.visible or coal == null:
		return
	_column_mesh.height = ash_length
	# The column grows off the coal, outward (-Z in the device's frame), and
	# droops toward the ground as it lengthens: its own weight on a brittle stem.
	var down_local := model.global_basis.inverse() * Vector3.DOWN
	var droop := clampf(pow(ash_length / float(ASH_LIMIT[device_id]), 2.0) * 0.35, 0.0, 0.35)
	var outward := Vector3(0, 0, -1).lerp(down_local.normalized(), droop).normalized()
	_column.basis = Basis(Quaternion(Vector3.UP, outward))
	_column.position = coal.position + outward * (ash_length * 0.5 + 0.0012)


func _drop(velocity: Vector3, reason: String) -> void:
	if _column == null or ash_length < 0.0015:
		ash_length = 0.0
		return
	drops += 1
	last_drop_reason = reason
	var at := _column.global_position
	var length := ash_length
	ash_length = 0.0
	_column.visible = false
	if world == null or not is_instance_valid(world) or not world.is_inside_tree():
		return
	var body := RigidBody3D.new()
	body.name = "FallenAsh"
	body.mass = 0.002
	body.contact_monitor = true
	body.max_contacts_reported = 1
	body.continuous_cd = true
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = _column_mesh.bottom_radius
	cylinder.height = length
	shape.shape = cylinder
	body.add_child(shape)
	var look := MeshInstance3D.new()
	var mesh := _column_mesh.duplicate() as CylinderMesh
	mesh.height = length
	look.mesh = mesh
	body.add_child(look)
	world.add_child(body)
	body.global_position = at
	body.global_basis = _column.global_basis
	body.linear_velocity = velocity
	body.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	body.body_entered.connect(func(_other: Node) -> void: _crumble(body), CONNECT_ONE_SHOT)
	world.get_tree().create_timer(5.0).timeout.connect(func() -> void:
		if is_instance_valid(body):
			body.queue_free())


## It lands and comes apart: a few grey flecks that bounce once and lie there.
func _crumble(body: RigidBody3D) -> void:
	if not is_instance_valid(body):
		return
	var at := body.global_position
	body.queue_free()
	var flecks := GPUParticles3D.new()
	flecks.name = "AshFlecks"
	flecks.one_shot = true
	flecks.amount = 10
	flecks.lifetime = 2.4
	flecks.explosiveness = 1.0
	var motion := ParticleProcessMaterial.new()
	motion.direction = Vector3.UP
	motion.spread = 70.0
	motion.initial_velocity_min = 0.08
	motion.initial_velocity_max = 0.3
	motion.gravity = Vector3(0, -3.0, 0)
	motion.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
	motion.collision_bounce = 0.15
	motion.collision_friction = 0.9
	flecks.process_material = motion
	var fleck := BoxMesh.new()
	fleck.size = Vector3(0.003, 0.0015, 0.003)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("8d867b")
	material.roughness = 1.0
	fleck.material = material
	flecks.draw_pass_1 = fleck
	world.add_child(flecks)
	flecks.global_position = at
	flecks.emitting = true
	world.get_tree().create_timer(3.0).timeout.connect(flecks.queue_free)
