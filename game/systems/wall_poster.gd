class_name WallPoster
extends Node3D
## A piece of Greg's art in the world (ArtGallery). A poster hangs on a wall
## with a fringe of tear-off tabs; E tears one off and the piece joins your
## gallery. A card lies on a surface; E takes it. Self-contained: it shows its
## own prompt when you are close and looking at it, and takes E itself, so a
## scene only has to place one.
##   WallPoster.place(self, "war_time", Vector3(7.34, 1.7, -6), -PI * 0.5)

const REACH := 2.4
const FACING := 0.55
const TAB_COUNT := 7

var piece_id := ""
var kind := "poster"
var _prompt: Label3D
var _tabs: Array[MeshInstance3D] = []
var _card: Node3D


## `yaw` turns the poster to face into the room (0 faces +Z).
static func place(parent: Node, piece: String, at: Vector3, yaw: float) -> WallPoster:
	var poster := WallPoster.new()
	poster.piece_id = piece
	poster.kind = str(ArtGallery.PIECES.get(piece, {}).get("kind", "poster"))
	poster.name = "Art_%s" % piece
	parent.add_child(poster)
	poster.position = at
	poster.rotation.y = yaw
	return poster


func _ready() -> void:
	var texture := ArtGallery.texture(piece_id)
	if texture == null:
		return
	var aspect := float(texture.get_width()) / maxf(1.0, float(texture.get_height()))
	if kind == "card":
		_build_card(texture, aspect)
	else:
		_build_poster(texture, aspect)
	_prompt = Label3D.new()
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.font_size = 28
	_prompt.pixel_size = 0.0022
	_prompt.outline_size = 8
	_prompt.modulate = Color("ead4ad")
	_prompt.position = Vector3(0, -0.78, 0.08) if kind == "poster" else Vector3(0, 0.18, 0)
	_prompt.visible = false
	add_child(_prompt)
	_refresh()


func _build_poster(texture: Texture2D, aspect: float) -> void:
	var height := 0.9
	var width := height * aspect
	var backing := MeshInstance3D.new()
	var board := BoxMesh.new()
	board.size = Vector3(width + 0.06, height + 0.06, 0.012)
	backing.mesh = board
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color("d9ccb0")
	paper.roughness = 0.95
	backing.material_override = paper
	backing.position = Vector3(0, 0, -0.008)
	add_child(backing)
	var art := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	art.mesh = quad
	var ink := StandardMaterial3D.new()
	ink.albedo_texture = texture
	ink.roughness = 0.85
	art.material_override = ink
	add_child(art)
	# The fringe: paper tabs cut along the bottom edge, one per person who
	# wanted the thing on the poster.
	# Its own pool of light (Greg: "darker, with pools of light that lead
	# you"), so art in a dark room can still be found and read.
	var lamp := SpotLight3D.new()
	lamp.position = Vector3(0, height * 0.5 + 0.35, 0.55)
	lamp.rotation.x = -1.0
	lamp.spot_range = 2.2
	lamp.spot_angle = 38.0
	lamp.light_energy = 2.2
	lamp.light_color = Color(1.0, 0.86, 0.66)
	lamp.shadow_enabled = false
	add_child(lamp)
	for index in TAB_COUNT:
		var tab := MeshInstance3D.new()
		var strip := QuadMesh.new()
		strip.size = Vector2(width / TAB_COUNT * 0.8, 0.14)
		tab.mesh = strip
		tab.material_override = paper
		tab.position = Vector3(-width * 0.5 + (index + 0.5) * width / TAB_COUNT, -height * 0.5 - 0.1, 0.001)
		tab.rotation.z = (float(index % 3) - 1.0) * 0.04
		add_child(tab)
		_tabs.append(tab)


func _build_card(texture: Texture2D, aspect: float) -> void:
	_card = Node3D.new()
	add_child(_card)
	var height := 0.09
	var width := height * aspect
	var art := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	art.mesh = quad
	art.rotation.x = -PI * 0.5
	art.position.y = 0.002
	var ink := StandardMaterial3D.new()
	ink.albedo_texture = texture
	art.material_override = ink
	_card.add_child(art)


func _refresh() -> void:
	var taken := ArtGallery.has(piece_id)
	if kind == "card" and _card != null:
		_card.visible = not taken
	elif taken and not _tabs.is_empty():
		_tabs[TAB_COUNT / 2].visible = false


func in_reach() -> bool:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return false
	var to_me := global_position - camera.global_position
	if to_me.length() > REACH:
		return false
	return (-camera.global_transform.basis.z).dot(to_me.normalized()) > FACING


func _process(_delta: float) -> void:
	if _prompt == null:
		return
	var near := in_reach()
	var taken := ArtGallery.has(piece_id)
	_prompt.visible = near and not (taken and kind == "card")
	if _prompt.visible:
		if taken:
			_prompt.text = "IN YOUR GALLERY"
		else:
			_prompt.text = "[E] TEAR OFF A TAB" if kind == "poster" else "[E] TAKE THE CARD"


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if not event.is_action_pressed("interact"):
		return
	if not in_reach() or ArtGallery.has(piece_id):
		return
	take()
	get_viewport().set_input_as_handled()


## Tear the tab / pick up the card: into the gallery, once.
func take() -> bool:
	var got := ArtGallery.collect(piece_id, str(get_tree().current_scene.name) if get_tree().current_scene != null else "")
	_refresh()
	return got
