class_name FluidSurface
extends Node3D

## FluidBody's pour drawn as one liquid surface instead of overlapping spheres.
##
## Greg (5 Oct ~19:00): "Fix and improve the pour (a real liquid surface, not
## spheres)". Screen-space fluid rendering in two passes:
## 1. A SubViewport with its own world (so no game camera ever sees the raw
##    blobs) holds the blobs as additive camera-facing kernels and a camera
##    that copies the game camera every frame. Its float buffer carries
##    density, weighted depth and thickness (shaders/fluid_splat.gdshader).
## 2. A full-screen quad in the game world thresholds that density into a
##    surface, takes its normal from the smoothed depth, and shades it glossy,
##    red and see-through, writing depth so the scene still hides it
##    (shaders/fluid_surface.gdshader).
## Both passes sleep while nothing is in the air. Headless (no renderer) the
## nodes exist and simply draw nothing; the simulation does not depend on them.

## Dials (FluidBody passes its own `surface_*` dials through).
## Buffer size as a share of the game view: 0.5 is a quarter of the pixels.
var resolution := 0.5
var iso := 0.28
## Kernel radius as a multiple of a blob's: bigger merges more into one body.
var blend := 2.8
var absorb := 26.0

var multimesh: MultiMesh
var viewport: SubViewport
var eye: Camera3D
var _splats: MultiMeshInstance3D
var _quad: MeshInstance3D
var _material: ShaderMaterial
var _splat_material: ShaderMaterial
var _body: Node3D
var _live := false


## `body` is the FluidBody whose local space the instance transforms are in,
## `count` the most blobs, `radius` a blob's radius, `extent` the AABB (in
## the body's space) the pour can occupy, used to cull and sort the quad.
func setup(body: Node3D, count: int, radius: float, extent: AABB, colour: Color) -> void:
	_body = body
	viewport = SubViewport.new()
	viewport.name = "FluidSplats"
	viewport.own_world_3d = true
	viewport.world_3d = World3D.new()
	var plain := Environment.new()
	plain.background_mode = Environment.BG_CLEAR_COLOR
	plain.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	plain.glow_enabled = false
	viewport.world_3d.environment = plain
	viewport.transparent_bg = true
	viewport.use_hdr_2d = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.positional_shadow_atlas_size = 0
	viewport.audio_listener_enable_3d = false
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.size = Vector2i(64, 64)
	add_child(viewport)
	eye = Camera3D.new()
	eye.name = "Eye"
	viewport.add_child(eye)
	eye.current = true

	var quad := QuadMesh.new()
	var splat := ShaderMaterial.new()
	splat.shader = preload("res://shaders/fluid_splat.gdshader")
	splat.set_shader_parameter("radius", radius * blend)
	_splat_material = splat
	quad.material = splat
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = quad
	multimesh.instance_count = count
	multimesh.visible_instance_count = 0
	_splats = MultiMeshInstance3D.new()
	_splats.name = "Splats"
	_splats.multimesh = multimesh
	_splats.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_splats.custom_aabb = extent
	viewport.add_child(_splats)

	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/fluid_surface.gdshader")
	_material.set_shader_parameter("field", viewport.get_texture())
	_material.set_shader_parameter("colour", colour)
	var screen := QuadMesh.new()
	screen.material = _material
	_quad = MeshInstance3D.new()
	_quad.name = "Surface"
	_quad.mesh = screen
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The quad covers the screen from its vertex shader; this box is where the
	# pour can be, so it culls when the spill is off screen and sorts with
	# the glass and the sheet as the pour's own volume.
	_quad.custom_aabb = extent
	_quad.visible = false
	add_child(_quad)


## True while the surface is drawing (blobs in the air and a camera to copy).
func live() -> bool:
	return _live


func _process(_delta: float) -> void:
	var wanted := multimesh != null and multimesh.visible_instance_count > 0
	var game_eye := get_viewport().get_camera_3d() if wanted else null
	_live = wanted and game_eye != null
	_quad.visible = _live
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _live else SubViewport.UPDATE_DISABLED
	if not _live:
		return
	var view := get_viewport().get_visible_rect().size
	var size := Vector2i(maxi(int(view.x * resolution), 16), maxi(int(view.y * resolution), 16))
	if viewport.size != size:
		viewport.size = size
	eye.projection = game_eye.projection
	eye.keep_aspect = game_eye.keep_aspect
	eye.fov = game_eye.fov
	eye.size = game_eye.size
	eye.near = game_eye.near
	eye.far = game_eye.far
	eye.h_offset = game_eye.h_offset
	eye.v_offset = game_eye.v_offset
	eye.frustum_offset = game_eye.frustum_offset
	eye.transform = game_eye.global_transform
	_splats.transform = _body.global_transform
	_material.set_shader_parameter("texel", Vector2(1.0 / size.x, 1.0 / size.y))
	_material.set_shader_parameter("iso", iso)
	_material.set_shader_parameter("absorb", absorb)
	# Depth is stored relative to a point 2 m this side of the pour (kept
	# positive: the tonemap may clamp negatives), so the half-float sums keep
	# their precision however far the camera is.
	var origin := maxf(-(game_eye.global_transform.affine_inverse() * _body.to_global(Vector3(0, 1, 0))).z - 2.0, 0.0)
	_splat_material.set_shader_parameter("origin", origin)
	_material.set_shader_parameter("origin", origin)
