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
var arm_damage := 0.0

const PHI := 1.61803398875
const GOLDEN_ANGLE := TAU / (PHI * PHI)
const LOOP_SECONDS := 22.0
const FIT_WIDTH := 2.18
const FIT_HEIGHT := 1.62
const ORBIT_VERTICAL_ALLOWANCE := 0.22


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
		# Every newly presented object begins at the same readable three-quarter
		# register. Carrying the previous object's arbitrary orbit phase across a
		# switch could introduce a pistol or cigarette edge-on.
		_clock = 0.0
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


func set_arm_damage(value: float) -> void:
	arm_damage = clampf(value, 0.0, 1.0)
	queue_redraw()


func _rebuild(source: Node3D) -> void:
	_clear_stage()
	_bounds = AABB()
	_has_bounds = false
	mesh_count = 0
	var inverse := source.global_transform.affine_inverse()
	_copy_geometry(source, inverse)
	if not _has_bounds:
		return
	# Yaw spends most of the loop turning X/Z into one another, while pitch is
	# deliberately shallow. A full bounding sphere treated a metre-long sword as
	# though it might stand vertically and made every long, thin object needlessly
	# tiny. Fit the actual orbit envelope: radial length against the wide aperture,
	# height plus the maximum authored pitch contribution against its height.
	var radial := Vector2(_bounds.size.x, _bounds.size.z).length()
	var orbit_height := _bounds.size.y + radial * ORBIT_VERTICAL_ALLOWANCE
	_fit_scale = minf(FIT_WIDTH / maxf(radial, 0.01), FIT_HEIGHT / maxf(orbit_height, 0.01))
	_stage.scale = Vector3.ONE * _fit_scale
	_stage.position = Vector3.ZERO
	_content.position = -_bounds.get_center()


func _copy_geometry(node: Node, inverse: Transform3D) -> void:
	var lower := node.name.to_lower()
	if "hand" in lower or "forearm" in lower or "cuff" in lower or "sleeve" in lower:
		return
	if node is MeshInstance3D:
		var source_mesh := node as MeshInstance3D
		if source_mesh.mesh != null and source_mesh.visible:
			var clone := MeshInstance3D.new()
			clone.mesh = source_mesh.mesh
			clone.material_override = source_mesh.material_override
			for surface in source_mesh.get_surface_override_material_count():
				var override := source_mesh.get_surface_override_material(surface)
				if override != null:
					clone.set_surface_override_material(surface, override)
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
		_content.remove_child(child)
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
	# I4.3v2/I10.9. Arm damage destabilises the object the arms are presenting,
	# not the map or portrait elsewhere on screen.
	_stage.rotation.z += sin(_clock * 11.0) * arm_damage * 0.045
	_stage.position.x = sin(_clock * 8.3) * arm_damage * 0.045
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
	var shown_detail := CellOutzType.fit_condensed(detail, 68.0, 8.0, 0.62) if not detail.is_empty() else ""
	var detail_width := CellOutzType.width_condensed(shown_detail, 8.0, 0.62) if not shown_detail.is_empty() else 0.0
	var label_room := 192.0 - detail_width - (9.0 if detail_width > 0.0 else 0.0)
	var shown_label := CellOutzType.fit_condensed(label, label_room, 9.0, 0.72)
	CellOutzType.draw_condensed(self, Vector2(20, 174), shown_label, 9.0, BONE, 0.72)
	if not shown_detail.is_empty():
		CellOutzType.draw_condensed(self, Vector2(220 - detail_width, 175), shown_detail, 8.0, COPPER, 0.62)
	if arm_damage > 0.08:
		var break_at := Vector2(228, 44)
		var elbow := break_at + Vector2(-22, 23)
		var end := elbow + Vector2(-38, 17) * arm_damage
		draw_polyline(PackedVector2Array([break_at, elbow, end]), BLOOD * Color(1, 1, 1, 0.30 + arm_damage * 0.55), 1.2 + arm_damage)
		draw_rect(Rect2(8, 104 + sin(_clock * 6.0) * 4.0, 220 * arm_damage, 3 + arm_damage * 4), Color(0.01, 0.003, 0.006, 0.82))
