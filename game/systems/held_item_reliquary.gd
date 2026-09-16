class_name HeldItemReliquary
extends Control

## Bottom-right presentation for anything the hands can own. It copies only
## render geometry from the live held node into a tiny lit 3D stage; guns,
## smokeables and severed limbs therefore need no parallel icon language.

const CellOutzType := preload("res://systems/celloutz_type.gd")
const BONE := Color("ead4ad")
const COPPER := Color("dc5827")
const BLOOD := Color("a81716")

var displayed_source_id := 0
var label := ""
var detail := ""
var mesh_count := 0
var _viewport: SubViewport
var _stage: Node3D
var _content: Node3D
var _texture: TextureRect
var _bounds := AABB()
var _has_bounds := false
var _clock := 0.0
var _fit_scale := 1.0

const PHI := 1.61803398875
const GOLDEN_ANGLE := TAU / (PHI * PHI)
const LOOP_SECONDS := 22.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -258.0
	offset_top = -226.0
	offset_right = -18.0
	offset_bottom = -24.0

	_viewport = SubViewport.new()
	_viewport.name = "ObjectStage"
	_viewport.size = Vector2i(420, 300)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)

	_stage = Node3D.new()
	_stage.name = "Turntable"
	_viewport.add_child(_stage)
	_content = Node3D.new()
	_content.name = "CentredObject"
	_stage.add_child(_content)
	var camera := Camera3D.new()
	camera.name = "ReliquaryCamera"
	camera.position = Vector3(0, 0.05, 3.1)
	camera.fov = 34.0
	_viewport.add_child(camera)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -28, 0)
	key.light_color = Color("ffd39a")
	key.light_energy = 2.1
	_viewport.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.4, -0.5, 1.8)
	fill.light_color = Color("8f3026")
	fill.light_energy = 3.0
	fill.omni_range = 6.0
	_viewport.add_child(fill)

	_texture = TextureRect.new()
	_texture.name = "LiveObject"
	_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture.position = Vector2(15, 12)
	_texture.size = Vector2(210, 154)
	_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture.texture = _viewport.get_texture()
	add_child(_texture)
	visible = false


func show_item(source: Node3D, item_label: String, item_detail := "") -> void:
	if source == null or not is_instance_valid(source):
		clear_item()
		return
	label = item_label.to_upper()
	detail = item_detail.to_upper()
	var source_id := source.get_instance_id()
	if source_id != displayed_source_id:
		displayed_source_id = source_id
		_rebuild(source)
	visible = mesh_count > 0
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	queue_redraw()


func clear_item() -> void:
	displayed_source_id = 0
	label = ""
	detail = ""
	mesh_count = 0
	visible = false
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_clear_stage()


func _rebuild(source: Node3D) -> void:
	_clear_stage()
	_bounds = AABB()
	_has_bounds = false
	mesh_count = 0
	var inverse := source.global_transform.affine_inverse()
	_copy_geometry(source, inverse)
	if not _has_bounds:
		return
	# Fit the whole bounding sphere, not only the longest axis seen at rest. A
	# sword or limb can therefore turn broadside without clipping the aperture.
	var diameter := _bounds.size.length()
	_fit_scale = 1.62 / maxf(diameter, 0.01)
	_stage.scale = Vector3.ONE * _fit_scale
	_stage.position = Vector3.ZERO
	_content.position = -_bounds.get_center()


func _copy_geometry(node: Node, inverse: Transform3D) -> void:
	var lower := node.name.to_lower()
	if "hand" in lower or "forearm" in lower or "cuff" in lower or "sleeve" in lower:
		return
	if node is MeshInstance3D:
		var source_mesh := node as MeshInstance3D
		if source_mesh.mesh != null:
			var clone := MeshInstance3D.new()
			clone.mesh = source_mesh.mesh
			clone.material_override = source_mesh.material_override
			clone.transform = inverse * source_mesh.global_transform
			_content.add_child(clone)
			var transformed: AABB = clone.transform * clone.mesh.get_aabb()
			_bounds = transformed if not _has_bounds else _bounds.merge(transformed)
			_has_bounds = true
			mesh_count += 1
	for child in node.get_children():
		if child is Node3D:
			_copy_geometry(child, inverse)


func _clear_stage() -> void:
	if _stage == null:
		return
	if _content == null:
		return
	for child in _content.get_children():
		child.queue_free()
	_stage.position = Vector3.ZERO
	_stage.scale = Vector3.ONE
	_stage.rotation = Vector3.ZERO
	_content.position = Vector3.ZERO
	_fit_scale = 1.0


func _process(delta: float) -> void:
	if not visible or _stage == null:
		return
	_clock = fposmod(_clock + delta, LOOP_SECONDS)
	var phase := (_clock / LOOP_SECONDS) * TAU
	# A closed screensaver orbit. Yaw completes one full revolution but the
	# doubled wave briefly reverses it twice, so this never reads as a shop-model
	# turntable. Pitch/roll use Fibonacci harmonics (3, 5, 8) separated by the
	# golden angle; every channel lands exactly back at its start after 22s.
	_stage.rotation.y = phase + sin(phase * 2.0 + GOLDEN_ANGLE) * 0.72
	_stage.rotation.x = sin(phase * 3.0) * 0.14 + sin(phase * 5.0 + GOLDEN_ANGLE) * 0.045
	_stage.rotation.z = sin(phase * 8.0 + GOLDEN_ANGLE * 2.0) * 0.035
	var breathe := 1.0 + sin(phase * 5.0 + GOLDEN_ANGLE) * 0.018
	_stage.scale = Vector3.ONE * _fit_scale * breathe
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	# A tall cut-crystal recess, deliberately unlike the retired oblong mouth.
	var shell := PackedVector2Array([
		Vector2(24, 5), Vector2(211, 5), Vector2(232, 28),
		Vector2(228, 166), Vector2(199, 194), Vector2(36, 194),
		Vector2(8, 166), Vector2(8, 31), Vector2(24, 5),
	])
	draw_colored_polygon(shell, Color(0.025, 0.009, 0.014, 0.82))
	draw_polyline(shell, BONE * Color(1, 1, 1, 0.34), 1.5)
	draw_line(Vector2(20, 169), Vector2(219, 169), COPPER * Color(1, 1, 1, 0.5), 1.2)
	for side in [0.0, 1.0]:
		var x := 15.0 if side == 0.0 else 225.0
		draw_circle(Vector2(x, 26), 4.0 + sin(_clock * 1.2 + side * PI) * 0.5, BLOOD)
		draw_line(Vector2(x, 34), Vector2(x + (8 if side == 0.0 else -8), 55), BONE * Color(1, 1, 1, 0.28), 1.0)
	CellOutzType.draw_condensed(self, Vector2(20, 174), label, 9.0, BONE, 0.72)
	if not detail.is_empty():
		var width := CellOutzType.width_condensed(detail, 8.0, 0.62)
		CellOutzType.draw_condensed(self, Vector2(220 - width, 175), detail, 8.0, COPPER, 0.62)
