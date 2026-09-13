class_name ContaminatedAir
extends Node3D

## W1.2. "Contamination has weather — it moves, it settles, it gets worse."
## Built the same shape `storm_weather.gd` already uses for chaos-magick: a
## pure `severity()` read off state the world already keeps, never a value
## authored or bumped directly by this file.
##
## - Moves: an upper haze drifts horizontally on a slowly-turning wind rather
##   than sitting still or only falling.
## - Settles: a second, lower layer barely responds to the wind and stays
##   close to the ground — a pool collecting in a dip, not the same haze
##   just closer to the floor.
## - Gets worse: severity climbs with `WorldClock.day()` on its own, no
##   designer push required, because a save left running is supposed to read
##   as more contaminated than a fresh one.

## Days (of the 30-day month `WorldClock`/AB2.4/W10.11 already treat as the
## game's one calendar unit) for the calendar term alone to reach its worst.
## Shorter than the month itself so a lived-in save reads as measurably worse
## before the month turns over and repairs land.
const WORSENING_DAYS := 18.0
## However bad the calendar term gets on its own, loose chaos-magick can push
## the rest of the way — the ecology and the occult are named as the same rot
## in this world ("runaway fungal ecology, decayed cybernetics").
const CHAOS_CONTRIBUTION := 0.35
## Below this the air reads as background dust, not a hazard worth animating.
const SEVERITY_FLOOR := 0.03

var _wind_phase := 0.0
var _upper: GPUParticles3D
var _upper_material: ParticleProcessMaterial
var _ground: GPUParticles3D
var _ground_material: ParticleProcessMaterial


func _ready() -> void:
	_build_upper_haze()
	_build_ground_haze()
	set_process(true)


## W1.2. The one number everything below answers to.
func severity() -> float:
	var worn := clampf(float(WorldClock.day()) / WORSENING_DAYS, 0.0, 1.0)
	var chaos := clampf(WorldHistory.chaos_magick(), 0.0, 1.0)
	return clampf(worn + chaos * CHAOS_CONTRIBUTION, 0.0, 1.0)


## Slowly turning rather than fixed, so the haze reads as weather instead of
## a static hazard marker that looks the same every time you pass it.
func wind_direction() -> Vector2:
	return Vector2(cos(_wind_phase), sin(_wind_phase))


## Same convention as `storm_weather.gd`'s `follow()`: whoever owns the world
## keeps this centred on the player every frame, since the haze has to travel
## with them across a region this large rather than sitting at the origin.
func follow(target_position: Vector3) -> void:
	position = Vector3(target_position.x, position.y, target_position.z)


func _process(delta: float) -> void:
	_wind_phase += delta * 0.05
	var level := severity()
	var wind := wind_direction()

	_upper.emitting = level > SEVERITY_FLOOR
	_upper.amount_ratio = clampf(level * 1.2, 0.0, 1.0)
	if _upper_material != null:
		_upper_material.direction = Vector3(wind.x, 0.05, wind.y)
		_upper_material.initial_velocity_min = 1.2 + level * 1.6
		_upper_material.initial_velocity_max = 2.0 + level * 2.4

	# Settling: the same wind, far less of it reaches this layer, and it
	# stays close to the ground it is pooling in rather than lifting away.
	_ground.emitting = level > SEVERITY_FLOOR * 2.0
	_ground.amount_ratio = clampf(level * 1.4, 0.0, 1.0)
	if _ground_material != null:
		_ground_material.direction = Vector3(wind.x, 0.0, wind.y)
		_ground_material.initial_velocity_min = 0.15
		_ground_material.initial_velocity_max = 0.4 + level * 0.3


func _build_upper_haze() -> void:
	_upper = GPUParticles3D.new()
	_upper.name = "UpperHaze"
	_upper.amount = 260
	_upper.lifetime = 9.0
	_upper.position = Vector3(0, 3.2, 0)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.1, 1.1)
	var mesh_material := StandardMaterial3D.new()
	# Salvage-teal-into-bloom, the same contamination register as
	# `WorldLook`'s "ashbloom" fog rather than a new invented colour.
	mesh_material.albedo_color = Color(0.42, 0.5, 0.34, 0.16)
	mesh_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = mesh_material
	_upper.draw_pass_1 = mesh
	_upper_material = ParticleProcessMaterial.new()
	_upper_material.direction = Vector3(1, 0.05, 0)
	_upper_material.spread = 25.0
	_upper_material.gravity = Vector3(0, -0.05, 0)
	_upper_material.initial_velocity_min = 1.2
	_upper_material.initial_velocity_max = 2.0
	_upper_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_upper_material.emission_box_extents = Vector3(38, 2.4, 38)
	_upper.process_material = _upper_material
	_upper.emitting = false
	add_child(_upper)


func _build_ground_haze() -> void:
	_ground = GPUParticles3D.new()
	_ground.name = "GroundHaze"
	_ground.amount = 220
	_ground.lifetime = 14.0
	_ground.position = Vector3(0, 0.35, 0)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.6, 0.9)
	var mesh_material := StandardMaterial3D.new()
	mesh_material.albedo_color = Color(0.3, 0.38, 0.26, 0.22)
	mesh_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = mesh_material
	_ground.draw_pass_1 = mesh
	_ground_material = ParticleProcessMaterial.new()
	_ground_material.direction = Vector3(1, 0, 0)
	_ground_material.spread = 20.0
	_ground_material.gravity = Vector3(0, -0.01, 0)
	_ground_material.damping_min = 0.2
	_ground_material.damping_max = 0.4
	_ground_material.initial_velocity_min = 0.15
	_ground_material.initial_velocity_max = 0.4
	_ground_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_ground_material.emission_box_extents = Vector3(38, 0.3, 38)
	_ground.process_material = _ground_material
	_ground.emitting = false
	add_child(_ground)
