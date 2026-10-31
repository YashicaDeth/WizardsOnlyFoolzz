class_name HorneeCard
extends Control
## Greg, 24 September: "Hornee the zombie mutant, your handmade plush: a
## trading card in the Brain Index with TouchDesigner-style effects from your
## edit, switchable to a 3D model rebuilt from your photos."
##
## The card face is Greg's own Zombie Minion art. Space turns it into the
## plush itself (art/generated/items/hornee_plush.glb, rebuilt from his
## photos), turning in your hands; drag to turn it yourself. The 3D view only
## renders while it is showing.

const CARD_ART := preload("res://art/items/hornee/zombie_minion.jpg")
const PLUSH := preload("res://art/generated/items/hornee_plush.glb")
const INK := Color("ead4ad")
const DIM := Color("8a7e6c")
const HOT := Color("c8452a")

var show_model := false
var _viewport: SubViewport
var _view: TextureRect
var _pivot: Node3D
var _spin := 0.0
var _clock := 0.0
var _dragging := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.size = Vector2i(640, 640)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	var plush := PLUSH.instantiate() as Node3D
	_pivot.add_child(plush)
	# Tripo marks the whole plush fully metallic (metallic 1.0 plus a metal
	# map), which reads as grey chrome. Corduroy is not metal.
	for node in plush.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		for surface in mesh_node.mesh.get_surface_count():
			var material := mesh_node.mesh.surface_get_material(surface) as StandardMaterial3D
			if material != null:
				var cloth := material.duplicate() as StandardMaterial3D
				cloth.metallic = 0.0
				cloth.metallic_texture = null
				mesh_node.set_surface_override_material(surface, cloth)
	# The model is a metre tall with its origin at its centre; stand it up.
	plush.position = Vector3(0, 0, 0)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0.05, 1.55)
	camera.fov = 40.0
	_viewport.add_child(camera)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.5, 0.4, 0)
	key.light_energy = 0.8
	_viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-0.2, PI + 0.6, 0)
	rim.light_energy = 0.35
	rim.light_color = Color(1.0, 0.55, 0.45)
	_viewport.add_child(rim)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_CLEAR_COLOR
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.22, 0.2, 0.19)
	_viewport.add_child(world)
	_view = TextureRect.new()
	_view.texture = _viewport.get_texture()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	resized.connect(_layout)
	visible = false


func open() -> void:
	show_model = false
	visible = true
	_apply()


func close() -> void:
	visible = false
	_apply()


func toggle_model() -> void:
	show_model = not show_model
	_apply()


func _apply() -> void:
	_view.visible = visible and show_model
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _view.visible else SubViewport.UPDATE_DISABLED
	_layout()
	queue_redraw()


func _layout() -> void:
	if _view != null:
		_view.position = Vector2(0, 40)
		_view.size = size - Vector2(0, 80)


## Space turns the card over into the plush; a drag turns the plush.
func handle_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_SPACE:
		toggle_model()
		return true
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed and show_model
		return true
	if event is InputEventMouseMotion and _dragging:
		_spin += (event as InputEventMouseMotion).relative.x * 0.012
		return true
	return false


func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	if show_model and not _dragging:
		_spin += delta * 0.6
	if _pivot != null:
		_pivot.rotation.y = _spin
		_pivot.rotation.x = sin(_clock * 0.7) * 0.08
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var area := Rect2(Vector2.ZERO, size)
	draw_rect(area, Color(0.03, 0.02, 0.02, 0.92))
	CellOutzType.draw_condensed(self, Vector2(16, 12), "HORNEE  //  ZOMBIE MINION", 12.0, INK, 0.9)
	if not show_model:
		# The card: Greg's art, fitted, with a thin frame and a slow glow.
		var art_size := Vector2(CARD_ART.get_size())
		var room := area.size - Vector2(40, 90)
		var scale_by := minf(room.x / art_size.x, room.y / art_size.y)
		var shown := art_size * scale_by
		var at := Vector2((area.size.x - shown.x) * 0.5, 40 + (room.y - shown.y) * 0.5)
		var glow := 0.35 + 0.25 * sin(_clock * 2.2)
		draw_rect(Rect2(at - Vector2(6, 6), shown + Vector2(12, 12)), HOT * Color(1, 1, 1, glow), false, 2.0)
		draw_texture_rect(CARD_ART, Rect2(at, shown), false)
	var hint := "SPACE: TURN THE CARD BACK OVER  //  DRAG TO TURN HIM" if show_model else "SPACE: HOLD HIM  //  ESC OR TAB: BACK TO THE INDEX"
	CellOutzType.draw_condensed(self, Vector2(16, size.y - 22), hint, 8.0, DIM, 0.7)
