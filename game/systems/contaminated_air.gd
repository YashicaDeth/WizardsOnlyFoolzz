class_name ContaminatedAir
extends GPUParticles3D

## A9.1 / A9.2. The air between the player and everything else, which for nine
## passes has been perfectly clean.
##
## A5 made contamination a property of every surface. This is the same material
## fact in the one place it was still missing: the space in between. Motes drift
## and settle rather than hang, because whatever is in this air came off
## something and is on its way to the ground — the fall is slow and the
## turbulence is what keeps it from reading as rain.
##
## They are lit rather than unshaded, which costs more and is the point: A4 put
## eleven lamps in the region and a torch in the player's hand, and air you
## cannot see until a light crosses it is the whole reason for both. Away from a
## lamp this is nearly invisible. Standing in one, it is the first thing you see.
##
## A9.2 asks for storm severity to be visible in the air before it is audible.
## AS4.2 — the segment that owns the storm — is not built, but it says severity
## tracks chaos magick in `WorldHistory`, and that is live: `chaos_magick()` is
## fed by rituals and, since A7.2, by seeing a god. So the air reads the number
## AS4.2 says the storm will read, which means the storm arriving later inherits
## an air that already answers it rather than needing a second source of truth.

## The volume that follows the player. Wide and shallow: the player sees across
## the region, not up it.
const EXTENTS := Vector3(17.0, 6.5, 17.0)
## How many motes at nothing, and at the worst the sky gets.
const CALM_MOTES := 260
const STORM_MOTES := 1500
## How far the player moves before the volume is re-centred. Snapped, because a
## volume that follows continuously drags its own particles along with it and
## the air ends up moving with the player instead of past them.
const RECENTRE_STEP := 6.0

var _process_material: ParticleProcessMaterial
var _mesh_material: StandardMaterial3D
var _severity := 0.0
var _centre := Vector3.ZERO


func _init() -> void:
	name = "ContaminatedAir"
	amount = STORM_MOTES
	lifetime = 11.0
	# Pre-rolled, or the player walks into a clean pocket every time the volume
	# re-centres and watches the air fill in.
	preprocess = 6.0
	fixed_fps = 30
	interpolate = true
	visibility_aabb = AABB(-EXTENTS * 1.2, EXTENTS * 2.4)

	_process_material = ParticleProcessMaterial.new()
	_process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_process_material.emission_box_extents = EXTENTS
	_process_material.direction = Vector3(0.35, -1.0, 0.15)
	_process_material.spread = 32.0
	_process_material.initial_velocity_min = 0.08
	_process_material.initial_velocity_max = 0.5
	# Barely falling. Dust that drops at anything like real gravity reads as
	# rain, and this has been in the air since the world ended.
	_process_material.gravity = Vector3(0.0, -0.22, 0.0)
	_process_material.damping_min = 0.02
	_process_material.damping_max = 0.12
	_process_material.turbulence_enabled = true
	_process_material.turbulence_noise_strength = 0.28
	_process_material.turbulence_noise_scale = 1.8
	_process_material.turbulence_influence_min = 0.05
	_process_material.turbulence_influence_max = 0.4
	_process_material.scale_min = 0.5
	_process_material.scale_max = 1.6
	process_material = _process_material

	var quad := QuadMesh.new()
	quad.size = Vector2(0.045, 0.045)
	_mesh_material = StandardMaterial3D.new()
	_mesh_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mesh_material.billboard_keep_scale = true
	_mesh_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_mesh_material.albedo_color = Color(0.62, 0.66, 0.44, 0.55)
	# A floor of its own light, so the far half of the region is not simply
	# black air. Small enough that a lamp still doubles it.
	_mesh_material.emission_enabled = true
	_mesh_material.emission = Color(0.24, 0.3, 0.14)
	_mesh_material.emission_energy_multiplier = 0.35
	_mesh_material.disable_receive_shadows = true
	quad.material = _mesh_material
	draw_pass_1 = quad
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED


## A9.2. `severity` is 0 to 1. Everything it touches is something you can see
## before anything makes a sound: how much is up, how fast it is going, how hard
## it is being pushed around, and how dirty it looks doing it.
func set_severity(severity: float) -> void:
	_severity = clampf(severity, 0.0, 1.0)
	amount_ratio = lerpf(float(CALM_MOTES) / float(STORM_MOTES), 1.0, _severity)
	speed_scale = lerpf(1.0, 2.6, _severity)
	if _process_material != null:
		_process_material.turbulence_noise_strength = lerpf(0.28, 1.35, _severity)
		_process_material.initial_velocity_max = lerpf(0.5, 2.4, _severity)
		# Pushed sideways as it worsens: settling dust becomes driven dust.
		_process_material.direction = Vector3(0.35 + _severity * 1.6, -1.0 + _severity * 0.55, 0.15)
	if _mesh_material != null:
		_mesh_material.albedo_color = Color(0.62, 0.66, 0.44).lerp(Color(0.74, 0.53, 0.3), _severity)
		_mesh_material.albedo_color.a = lerpf(0.55, 0.8, _severity)


func severity() -> float:
	return _severity


## Keeps the volume around `at` without dragging the air along with it.
func follow(at: Vector3) -> void:
	if _centre.distance_to(at) < RECENTRE_STEP:
		return
	_centre = at
	global_position = Vector3(at.x, at.y + 1.5, at.z)
