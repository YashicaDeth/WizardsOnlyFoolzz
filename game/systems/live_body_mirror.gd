class_name LiveBodyMirror
extends Node3D

## A physical B9 mirror.  Its image comes from a second camera in the same
## World3D as the hunter, so it can only show geometry that is actually on the
## live player rig: severed limbs, exposed layers, factory hardware and flame.
## It deliberately does not construct a portrait or copy anatomy data into a
## substitute mesh.

const MirrorBodyState := preload("res://systems/mirror_body_state.gd")

const FRAME_LAYER := 2
const VIEW_SIZE := Vector2i(512, 704)

var target: BaselineHuman
var live_state: Dictionary = {"ok": false, "reason": "NO TARGET"}

var _feed: SubViewport
var _camera: Camera3D
var _surface: MeshInstance3D
var _readout: Label3D


func _ready() -> void:
	_build_frame()
	_build_feed()


func set_target(value: BaselineHuman) -> void:
	target = value
	# A caller can inspect the connection immediately (and a paused world still
	# has an honest last-known body state), rather than waiting for its first
	# process tick.
	live_state = MirrorBodyState.snapshot(target)


func _process(_delta: float) -> void:
	live_state = MirrorBodyState.snapshot(target)
	if not bool(live_state.get("ok", false)):
		return
	_update_camera()
	_update_readout()


func _build_feed() -> void:
	_feed = SubViewport.new()
	_feed.name = "LiveRigFeed"
	_feed.size = VIEW_SIZE
	_feed.transparent_bg = false
	_feed.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Sharing the world is the critical bit: this is a second view of the
	# HunterBody, not a replicated player staged in a separate viewport.
	_feed.world_3d = get_viewport().world_3d
	add_child(_feed)
	_camera = Camera3D.new()
	_camera.name = "WitnessCamera"
	_camera.current = true
	_camera.fov = 37.0
	_camera.cull_mask = 1
	_feed.add_child(_camera)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _feed.get_texture()
	material.roughness = 0.16
	material.metallic = 0.65
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_surface.material_override = material


func _build_frame() -> void:
	# The panel itself lives on layer two.  The feed camera only renders layer
	# one, preventing a recursive mirror-within-mirror while ordinary cameras
	# still see both the frame and the live image.
	_surface = MeshInstance3D.new()
	_surface.name = "LiveReflection"
	var glass := QuadMesh.new()
	glass.size = Vector2(1.45, 2.15)
	_surface.mesh = glass
	_surface.layers = FRAME_LAYER
	add_child(_surface)
	var backing := MeshInstance3D.new()
	backing.name = "MirrorBack"
	var back_mesh := BoxMesh.new()
	back_mesh.size = Vector3(1.68, 2.4, 0.13)
	backing.mesh = back_mesh
	backing.position = Vector3(0.0, 0.0, 0.08)
	backing.layers = FRAME_LAYER
	var back_material := StandardMaterial3D.new()
	back_material.albedo_color = Color("16100f")
	back_material.metallic = 0.86
	back_material.roughness = 0.31
	backing.material_override = back_material
	add_child(backing)
	for side in [-1.0, 1.0]:
		_add_rail(Vector3(side * 0.86, 0.0, -0.06), Vector3(0.12, 2.55, 0.12))
	for height in [-1.22, 1.22]:
		_add_rail(Vector3(0.0, height, -0.06), Vector3(1.82, 0.12, 0.12))
	_readout = Label3D.new()
	_readout.name = "RigReadout"
	_readout.position = Vector3(0.0, -1.43, -0.1)
	_readout.pixel_size = 0.004
	_readout.outline_size = 3
	_readout.modulate = Color("ff9a8a")
	_readout.text = "BODY WITNESS // CONNECTING"
	_readout.layers = FRAME_LAYER
	add_child(_readout)


func _add_rail(at: Vector3, size: Vector3) -> void:
	var rail := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	rail.mesh = mesh
	rail.position = at
	rail.layers = FRAME_LAYER
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("6d261e")
	material.emission_enabled = true
	material.emission = Color("c64a36")
	material.emission_energy_multiplier = 0.45
	rail.material_override = material
	add_child(rail)


func _update_camera() -> void:
	var focus := target.global_position + Vector3(0.0, 0.1, 0.0)
	var facing := target.global_transform.basis.z
	facing.y = 0.0
	if facing.length_squared() < 0.001:
		facing = Vector3.FORWARD
	facing = facing.normalized()
	_camera.global_position = focus + facing * 3.1 + Vector3(0.0, 0.18, 0.0)
	_camera.look_at(focus + Vector3(0.0, 0.25, 0.0), Vector3.UP)


func _update_readout() -> void:
	var severed := 0
	var opened := 0
	for zone: Dictionary in (live_state.get("zones", {}) as Dictionary).values():
		severed += 1 if bool(zone.get("severed", false)) else 0
		opened += 1 if int(zone.get("opened_layer", 0)) > 0 else 0
	_readout.text = "BODY WITNESS  //  %d SEVERED  %d OPEN" % [severed, opened]
	_readout.modulate = Color("ff4f3d") if severed > 0 else Color("ff9a8a")
