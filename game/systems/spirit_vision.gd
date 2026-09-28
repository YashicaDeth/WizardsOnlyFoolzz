class_name SpiritVision
extends Node3D

## A spirit the splinter monks invoke (DESIGN/OVERWORLD_EVENTS.md): shown as a
## projection, not a body. An animated 2D layer is drawn every frame into a
## small SubViewport and thrown onto upright billboards with
## `shaders/spirit_hologram.gdshader` (scanlines, colour split, torn rows,
## dropouts). Two layers - the figure and a lagging echo - so it reads as
## projected light with depth rather than a sprite.
##
## [PLACEHOLDER] What the spirits are (the dead, the planes, real or not) is
## still open. The figure drawn here is a stand-in shape: a tall robed form
## with raised arms and a seal forming where its face would be. TouchDesigner
## loops can replace `SpiritFigure` later, as proposed for the doctor's call.

const HOLOGRAM := preload("res://shaders/spirit_hologram.gdshader")

var presence := 0.0
var target_presence := 1.0
var height := 3.4
var seed_value := 7
var _viewport: SubViewport
var _figure: Node2D
var _layers: Array[MeshInstance3D] = []
var _age := 0.0


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "SpiritLayer"
	_viewport.size = Vector2i(256, 512)
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_figure = SpiritFigure.new()
	_figure.set("seed_value", seed_value)
	_viewport.add_child(_figure)
	var texture := _viewport.get_texture()
	for index in 2:
		var quad := QuadMesh.new()
		quad.size = Vector2(height * 0.5, height)
		var layer := MeshInstance3D.new()
		layer.name = "HologramLayer%d" % index
		layer.mesh = quad
		layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = HOLOGRAM
		material.set_shader_parameter("layer", texture)
		material.set_shader_parameter("time_offset", float(index) * 0.37 + float(seed_value))
		if index == 1:
			# The echo: bigger, fainter, redder, torn more often.
			material.set_shader_parameter("tint", Color(0.9, 0.35, 0.4))
			material.set_shader_parameter("intensity", 0.9)
			material.set_shader_parameter("tear", 0.14)
			material.set_shader_parameter("split", 0.03)
			layer.scale = Vector3(1.12, 1.08, 1.0)
		layer.material_override = material
		layer.position = Vector3(0, height * 0.5 * layer.scale.y, 0)
		add_child(layer)
		_layers.append(layer)
	# The projection's source: a faint ring on the ground under it.
	var ring := MeshInstance3D.new()
	ring.name = "ProjectionRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	ring.mesh = torus
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_mat.albedo_color = Color(0.3, 0.7, 0.65)
	ring.material_override = ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position.y = 0.03
	add_child(ring)
	_apply_presence()


func _process(delta: float) -> void:
	_age += delta
	presence = move_toward(presence, target_presence, delta * 0.7)
	for index in _layers.size():
		# The echo lags and drifts, so the two layers never quite agree.
		var layer := _layers[index]
		if index == 1:
			layer.position.x = sin(_age * 1.3) * 0.08
	_apply_presence()


func dismiss() -> void:
	target_presence = 0.0


## For captures and tests: jump straight to a state.
func set_presence_now(value: float) -> void:
	presence = value
	target_presence = value
	_apply_presence()


func _apply_presence() -> void:
	for index in _layers.size():
		var material := _layers[index].material_override as ShaderMaterial
		material.set_shader_parameter("presence", presence * (0.55 if index == 1 else 1.0))


## The animated layer itself. Drawn fresh every frame; white on transparent,
## the shader does the colour.
class SpiritFigure extends Node2D:
	var seed_value := 7
	var clock := 0.0

	func _process(delta: float) -> void:
		clock += delta
		queue_redraw()

	func _draw() -> void:
		var w := 256.0
		var h := 512.0
		var cx := w * 0.5
		var sway := sin(clock * 0.9) * 6.0
		var breath := sin(clock * 1.7) * 0.03
		var white := Color(1, 1, 1, 0.85)
		# The robe: a long tapering form, hem dissolving into lines.
		var robe := PackedVector2Array([
			Vector2(cx - 22 + sway * 0.4, 118), Vector2(cx + 22 + sway * 0.4, 118),
			Vector2(cx + 44 + sway, 300), Vector2(cx + 62 + sway * 1.4, 470),
			Vector2(cx - 62 + sway * 1.4, 470), Vector2(cx - 44 + sway, 300),
		])
		draw_colored_polygon(robe, Color(1, 1, 1, 0.32))
		draw_polyline(robe + PackedVector2Array([robe[0]]), white, 2.0)
		for line in 9:
			var y := 300.0 + line * 19.0
			var spread := 44.0 + line * 2.0
			draw_line(Vector2(cx - spread + sway, y), Vector2(cx + spread + sway, y), Color(1, 1, 1, 0.25 + 0.05 * line), 1.0)
		# Arms raised, slowly opening and closing.
		var open := 0.55 + 0.25 * sin(clock * 0.8)
		for side in [-1.0, 1.0]:
			var shoulder := Vector2(cx + 20.0 * side + sway * 0.4, 132)
			var elbow := shoulder + Vector2(side * 46.0, -40.0 - 30.0 * open).rotated(side * breath)
			var hand := elbow + Vector2(side * 18.0, -62.0 * open - 20.0)
			draw_polyline(PackedVector2Array([shoulder, elbow, hand]), white, 6.0)
			for finger in 3:
				draw_line(hand, hand + Vector2(side * (finger - 1) * 7.0, -18.0), white, 2.0)
		# The head: an empty hood, and in it a seal forming and unforming.
		var head := Vector2(cx + sway * 0.3, 92)
		draw_circle(head, 30.0, Color(1, 1, 1, 0.18))
		draw_arc(head, 30.0, PI * 1.05, PI * 1.95, 18, white, 3.0)
		var progress := 0.5 + 0.5 * sin(clock * 0.6)
		CellOutzType.draw_seal_forming(self, head, 22.0, seed_value, Color(1, 1, 1, 0.95), progress, 6, 2.0)
		# A halo seal behind it all, turning.
		draw_set_transform(head, clock * 0.25, Vector2.ONE)
		CellOutzType.draw_seal_corrupted(self, Vector2.ZERO, 64.0, seed_value + 11, Color(1, 1, 1, 0.5), 0.35, 8, 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
