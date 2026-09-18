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

## W1.2. `chaos_magick()` decays on its own with nothing feeding it, so read
## on its own the air got *better* on every quiet night — the opposite of
## what "contamination has weather" asked for. A watermark fixes that without
## touching `WorldHistory`: a spike raises what "normal" reads as immediately,
## and only a full quiet day earns back a small piece of that ceiling. The
## instant `chaos_magick()` term can still spike air above the watermark on a
## bad night; it just cannot silently erase yesterday's on a calm one.
const WATERMARK_RELIEF := 0.08

var _process_material: ParticleProcessMaterial
var _mesh_material: StandardMaterial3D
var _severity := 0.0
var _watermark := 0.0
var _watermark_day := -1
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
	severity = clampf(severity, 0.0, 1.0)
	var day := WorldClock.day()
	if severity > _watermark:
		# It just got worse. That is the new floor until a quiet day earns
		# relief against it — not a number this frame's reading can undo.
		_watermark = severity
		_watermark_day = day
	elif _watermark_day >= 0 and day > _watermark_day:
		_watermark = maxf(severity, _watermark - WATERMARK_RELIEF * float(day - _watermark_day))
		_watermark_day = day
	_severity = maxf(severity, _watermark)
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


## AU7.7. A breath joins the same air system the world already uses. This is a
## short-lived local plume, not a second weather layer: the same lit billboard,
## turbulence and settling logic, emitted once from the player's mouth and then
## left to drift through whatever light is really there.
func emit_exhale(at: Vector3, direction: Vector3, density := 1.0, tint := Color(0.72, 0.74, 0.69)) -> GPUParticles3D:
	var plume := GPUParticles3D.new()
	plume.name = "SmokeExhale"
	plume.set_meta("smoke_tint", tint)
	plume.one_shot = true
	plume.amount = roundi(lerpf(15.0, 30.0, clampf(density / 2.4, 0.0, 1.0)))
	plume.lifetime = lerpf(2.2, 3.8, clampf(density / 2.4, 0.0, 1.0))
	plume.explosiveness = 0.86
	plume.fixed_fps = 30
	plume.visibility_aabb = AABB(Vector3(-2.5, -1.2, -2.5), Vector3(5.0, 4.5, 5.0))

	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	motion.emission_sphere_radius = 0.035
	motion.direction = Vector3(0.0, 0.08, -1.0)
	motion.spread = 13.0
	motion.initial_velocity_min = 0.32
	motion.initial_velocity_max = lerpf(0.58, 1.05, clampf(density / 2.4, 0.0, 1.0))
	# Smoke rises, then turbulence breaks the single stream into a breath.
	motion.gravity = Vector3(0.0, 0.18, 0.0)
	motion.damping_min = 0.12
	motion.damping_max = 0.34
	motion.turbulence_enabled = true
	motion.turbulence_noise_strength = 0.62
	motion.turbulence_noise_scale = 2.1
	motion.turbulence_influence_min = 0.25
	motion.turbulence_influence_max = 0.72
	motion.angle_min = -32.0
	motion.angle_max = 32.0
	# Long narrow cards overlap into threads. Square cards, even with a radial
	# texture, resolve as a stream of bright beads in front of the face.
	motion.scale_min = 0.48
	motion.scale_max = 1.0
	plume.process_material = motion

	var quad := QuadMesh.new()
	quad.size = Vector2(0.020, 0.180)
	var smoke := StandardMaterial3D.new()
	smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smoke.billboard_keep_scale = true
	# Keep a stable grey under the close Zippo instead of accepting its tiny
	# point light as a miniature sun. Low alpha makes this smoke, not neon.
	smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke.albedo_texture = _soft_smoke_texture()
	smoke.albedo_color = Color(tint.r, tint.g, tint.b, 0.032)
	smoke.disable_receive_shadows = true
	quad.material = smoke
	motion.color_ramp = _smoke_lifetime_ramp(0.46)
	plume.draw_pass_1 = quad
	# A softer crossing layer stops the thin pass reading as hair. Both passes
	# share the same particles, so this does not double the simulation cost.
	plume.draw_passes = 2
	var haze_quad := QuadMesh.new()
	haze_quad.size = Vector2(0.095, 0.066)
	var haze := smoke.duplicate() as StandardMaterial3D
	haze.albedo_color = Color(tint.r, tint.g, tint.b, 0.014)
	haze_quad.material = haze
	plume.draw_pass_2 = haze_quad
	plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plume.gi_mode = GeometryInstance3D.GI_MODE_DISABLED

	get_parent().add_child(plume)
	plume.global_position = at
	var forward := direction.normalized()
	if forward.length_squared() > 0.001:
		plume.look_at(at + forward, Vector3.UP)
	plume.emitting = true
	get_tree().create_timer(plume.lifetime + 0.5).timeout.connect(plume.queue_free)
	return plume


## A deliberate shape pushed through the fresh exhale. Ring emission is real
## particle geometry — the puffs begin around a hollow circle and inherit the
## player's look direction — so an O expands and frays instead of being a flat
## sprite pasted over the camera.
func emit_smoke_trick(at: Vector3, direction: Vector3, trick: String, density := 1.0, tint := Color(0.72, 0.74, 0.69)) -> Node3D:
	var rig := Node3D.new()
	rig.name = "SmokeTrick_%s" % trick.replace(" ", "_")
	rig.set_meta("smoke_tint", tint)
	get_parent().add_child(rig)
	rig.global_position = at
	var forward := direction.normalized()
	if forward.length_squared() > 0.001:
		rig.look_at(at + forward, Vector3.UP)
	var rings := 2 if trick == "DOUBLE O" else 1
	for index in rings:
		# A continuous, translucent core makes the trick legible on the first
		# frame; particles around it provide the breakup and drift. Depending on
		# random puffs alone produced a cloud whose intended O was only visible
		# in a debugger.
		if trick != "GHOST":
			var core := MeshInstance3D.new()
			core.name = "SmokeRingCore%d" % index
			var torus := TorusMesh.new()
			torus.inner_radius = 0.108
			torus.outer_radius = 0.142
			torus.rings = 40
			torus.ring_segments = 10
			var core_smoke := StandardMaterial3D.new()
			core_smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			core_smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			core_smoke.albedo_color = Color(tint.r, tint.g, tint.b, 0.09)
			core_smoke.disable_receive_shadows = true
			torus.material = core_smoke
			core.mesh = torus
			core.rotation.x = PI * 0.5
			core.position = Vector3((float(index) - 0.5) * 0.07 if rings > 1 else 0.0, float(index) * 0.035, -0.05 - float(index) * 0.04)
			rig.add_child(core)
			var core_tween := core.create_tween().set_parallel(true)
			core_tween.tween_property(core, "position:z", -1.25, 2.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			core_tween.tween_property(core, "scale", Vector3.ONE * 1.85, 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			core_tween.tween_property(core_smoke, "albedo_color", Color(tint.r, tint.g, tint.b, 0.0), 2.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var ring := GPUParticles3D.new()
		ring.name = "Ring%d" % index
		ring.one_shot = true
		ring.amount = roundi(lerpf(34.0, 56.0, clampf(density / 2.4, 0.0, 1.0)))
		ring.lifetime = 3.2
		ring.explosiveness = 0.94
		ring.fixed_fps = 30
		ring.position = Vector3((float(index) - 0.5) * 0.07 if rings > 1 else 0.0, float(index) * 0.035, -float(index) * 0.04)
		var motion := ParticleProcessMaterial.new()
		motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		motion.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
		motion.emission_ring_radius = 0.145 if trick != "GHOST" else 0.17
		motion.emission_ring_inner_radius = 0.128 if trick != "GHOST" else 0.035
		motion.emission_ring_height = 0.012
		motion.direction = Vector3(0.0, 0.02, -1.0)
		motion.spread = 4.0 if trick != "GHOST" else 12.0
		motion.initial_velocity_min = 0.62
		motion.initial_velocity_max = 0.88
		motion.gravity = Vector3(0.0, 0.12, 0.0)
		motion.damping_min = 0.08
		motion.damping_max = 0.2
		motion.turbulence_enabled = true
		motion.turbulence_noise_strength = 0.28 if trick != "GHOST" else 0.72
		motion.turbulence_noise_scale = 1.8
		motion.turbulence_influence_min = 0.08
		motion.turbulence_influence_max = 0.34
		motion.scale_min = 0.62
		motion.scale_max = 1.0
		ring.process_material = motion
		var quad := QuadMesh.new()
		quad.size = Vector2(0.020, 0.046)
		var smoke := StandardMaterial3D.new()
		smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smoke.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		smoke.billboard_keep_scale = true
		smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smoke.albedo_texture = _soft_smoke_texture()
		smoke.albedo_color = Color(tint.r, tint.g, tint.b, 0.11)
		smoke.disable_receive_shadows = true
		quad.material = smoke
		motion.color_ramp = _smoke_lifetime_ramp()
		ring.draw_pass_1 = quad
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		rig.add_child(ring)
		ring.emitting = true
	get_tree().create_timer(3.8).timeout.connect(rig.queue_free)
	return rig


## A radial alpha texture turns each billboard into a soft wisp. Without it a
## particle is literally the full QuadMesh, which is why the first capture
## looked like white cards flying out of the camera.
func _soft_smoke_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.34, 0.72, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.92),
		Color(1.0, 1.0, 1.0, 0.62),
		Color(1.0, 1.0, 1.0, 0.16),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	return texture


func _smoke_lifetime_ramp(peak := 1.0) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.035, 0.62, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 1.0, 1.0, peak),
		Color(0.92, 0.94, 0.88, peak * 0.58),
		Color(0.86, 0.89, 0.82, 0.0),
	])
	var texture := GradientTexture1D.new()
	texture.width = 64
	texture.gradient = gradient
	return texture
