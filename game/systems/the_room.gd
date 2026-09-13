class_name TheRoom
extends Node3D

## AH1. The room you remember the Cloud from.
##
## Greg: *"i want you to make it a room on the phone somewhat, when you check
## the pinboard then you can be in a room with a massive mirror on the wall and
## a bed, and then you can turn to the conspiracy quest board"* — and, later,
## *"a trapped menu inside the phone of a 3d modelled version of my room."*
##
## So this is not a menu background. It is a place with four walls that the
## player is standing in, and the pages of the handheld are things in it rather
## than tabs on it. House rule I0 — no screen is a list of text in a box — taken
## to the last screens that were still lists.
##
## Built the way everything else here is built: procedural geometry from
## primitives, nothing imported, generated from a seed. AH1.10 will want real
## photographs projected onto the poster wall; the wall is laid out here so that
## is a texture swap rather than a rebuild.

const BODY_MIRROR := preload("res://systems/body_mirror.gd")

## A real bedroom, in metres. Small on purpose: the reference photograph is a
## corner room with a bed against one wall and posters over every surface, and
## a generous room would read as an apartment in a game about scraping by.
const SIZE := Vector3(3.4, 2.5, 3.8)
const WALL := Color("cfc9bb")
const FLOOR := Color("4a4038")
const CEILING := Color("6b3630")
const FRAME := Color("2a2420")
const GLASS_BACK := Color("0d0f0d")

## Visual layers. The reflection camera stands *behind* the glass — that is
## what a reflection is — which puts the mirror wall directly between it and
## the room, and a mirror that renders the back of its own wall is black. So
## the mirror assembly is coplanar with it and would z-fight in its own
## reflection. So the assembly goes on its own layer and the mirror camera
## drops it, while the wall stays and is handled by the near plane instead.
const LAYER_ROOM := 1 << 0
const LAYER_MIRROR_WALL := 1 << 2

## Which wall is which, so a caller turns to a name rather than to an angle.
const NORTH := "board"
const EAST := "cloud"
const SOUTH := "mirror"
const WEST := "posters"

var mirror: SubViewport
var _mirror_plane_origin := Vector3.ZERO
var _mirror_normal := Vector3(0, 0, -1)


func _ready() -> void:
	_build_shell()
	_build_window()
	_build_bed()
	_build_poster_wall()


func _panel(size: Vector3, at: Vector3, colour: Color, rough := 0.9) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = rough
	instance.material_override = material
	add_child(instance)
	return instance


func _build_shell() -> void:
	var half := SIZE * 0.5
	_panel(Vector3(SIZE.x, 0.06, SIZE.z), Vector3(0, -0.03, 0), FLOOR)
	# AH1.8. The rug is on the ceiling in the reference photograph and it is the
	# first thing anybody notices about that room, so it is not a detail.
	_panel(Vector3(SIZE.x, 0.06, SIZE.z), Vector3(0, SIZE.y + 0.03, 0), CEILING, 0.98)
	_panel(Vector3(SIZE.x, SIZE.y, 0.06), Vector3(0, half.y, -half.z), WALL)
	# The wall stays visible to the reflection camera; `BodyMirror` clips at the
	# glass instead, so there is no hole for the camera to see the void through.
	_panel(Vector3(SIZE.x, SIZE.y, 0.06), Vector3(0, half.y, half.z), WALL)
	_panel(Vector3(0.06, SIZE.y, SIZE.z), Vector3(-half.x, half.y, 0), WALL)
	_panel(Vector3(0.06, SIZE.y, SIZE.z), Vector3(half.x, half.y, 0), WALL)


## AH1.2. The light of one window. One, and low, because a room lit evenly is a
## menu background and a room lit from a single opening is a place.
func _build_window() -> void:
	var at := Vector3(SIZE.x * 0.5 - 0.04, 1.45, -0.6)
	_panel(Vector3(0.02, 1.10, 0.92), at, Color("9fb4c4"), 0.2)
	_panel(Vector3(0.04, 1.18, 1.00), at + Vector3(-0.01, 0, 0), FRAME)
	var light := SpotLight3D.new()
	light.position = at + Vector3(-0.25, 0.1, 0)
	# A SpotLight3D points down its local -Z. Yaw +90 aimed it into the wall it
	# is set in, which lit nothing and made the mirror black as well — a
	# reflection of an unlit room is an unlit reflection.
	light.rotation_degrees = Vector3(-10, -90, 0)
	light.light_energy = 4.2
	light.light_color = Color("cfd8dd")
	light.spot_range = 7.0
	light.spot_angle = 58.0
	light.spot_attenuation = 0.6
	add_child(light)
	# The bounce. One window in a small room with dark walls is a hard key and
	# nothing else; real rooms have the light coming back off the floor.
	var bounce := OmniLight3D.new()
	bounce.position = Vector3(0, 1.1, 0.2)
	bounce.light_energy = 1.6
	bounce.light_color = Color("b9a98e")
	bounce.omni_range = 6.0
	bounce.omni_attenuation = 1.4
	add_child(bounce)


## AH1.2, the bed. Against the wall, unmade, low.
func _build_bed() -> void:
	var at := Vector3(-SIZE.x * 0.5 + 0.72, 0.0, SIZE.z * 0.5 - 1.10)
	_panel(Vector3(1.30, 0.28, 1.95), at + Vector3(0, 0.14, 0), Color("3a332c"))
	_panel(Vector3(1.34, 0.16, 1.99), at + Vector3(0, 0.36, 0), Color("6e6553"), 0.95)
	_panel(Vector3(0.56, 0.12, 0.38), at + Vector3(-0.28, 0.50, -0.72), Color("8d8574"), 0.95)


## AH1.8. The poster wall, laid out as a grid of panels with a gap at the corner
## the way the photograph has it. Flat colours for now; AH1.10 replaces each
## panel's albedo with the real thing and nothing about this layout changes.
func _build_poster_wall() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260913
	var tones := [Color("7d2230"), Color("1d2f4a"), Color("2f4a2a"), Color("4a2f4a"), Color("6b5a20"), Color("22303a")]
	var x := -SIZE.x * 0.5 + 0.18
	while x < SIZE.x * 0.5 - 0.30:
		var width := rng.randf_range(0.26, 0.44)
		var y := 0.55
		while y < SIZE.y - 0.30:
			var height := rng.randf_range(0.34, 0.56)
			if y + height > SIZE.y - 0.22:
				break
			_panel(Vector3(width * 0.94, height * 0.94, 0.012),
				Vector3(x + width * 0.5, y + height * 0.5, -SIZE.z * 0.5 + 0.04),
				tones[rng.randi() % tones.size()], 0.85)
			y += height + 0.035
		x += width + 0.03


## AH1.5 / B10.10. The mirror the size of the wall. Hung rather than built into
## `_ready()` because it needs the world it is reflecting, and that is the
## caller's to give — the same contract `LivingMap.attach_world` uses, and for
## the same reason.
func hang_mirror(world: World3D) -> SubViewport:
	if mirror != null and is_instance_valid(mirror):
		return mirror
	if world == null:
		return null
	var at := Vector3(0, 1.25, SIZE.z * 0.5 - 0.05)
	_panel(Vector3(2.10, 2.00, 0.04), at, GLASS_BACK, 0.1).layers = LAYER_MIRROR_WALL
	_panel(Vector3(2.22, 2.12, 0.02), at + Vector3(0, 0, -0.015), FRAME).layers = LAYER_MIRROR_WALL
	_mirror_plane_origin = at + Vector3(0, 0, -0.03)
	_mirror_normal = Vector3(0, 0, -1)
	mirror = BODY_MIRROR.make(world, Vector2i(768, 720))
	add_child(mirror)
	mirror.call("place", _mirror_plane_origin, _mirror_normal)
	# Everything except the wall the glass is set into. Without this the
	# reflection camera renders the back of that wall and the mirror is black.
	mirror.camera.cull_mask = 0xFFFFF & ~LAYER_MIRROR_WALL

	# A quad, not a box. The glass was a BoxMesh, which puts the reflection on
	# all six faces with the same UVs and leaves which one the viewer is
	# actually reading up to the geometry — the reflection rendered correctly
	# the whole time and the surface showing it did not. A quad has one face
	# and a normal, so there is nothing to get wrong.
	var glass := QuadMesh.new()
	glass.size = Vector2(2.02, 1.92)
	var surface := MeshInstance3D.new()
	surface.mesh = glass
	surface.position = at + Vector3(0, 0, -0.035)
	# QuadMesh faces +Z; the room is on -Z of the glass, so it is turned round.
	surface.rotation.y = PI
	add_child(surface)
	surface.layers = LAYER_MIRROR_WALL
	var material := StandardMaterial3D.new()
	material.albedo_texture = mirror.get_texture()
	# A mirror is not a lamp. Unshaded so the room's own light does not dim the
	# reflection, but no emission, so it does not throw light back either.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	surface.material_override = material
	return mirror


## Called each frame the player is in the room. Everything the glass shows
## follows from where they are standing.
func observe(viewer: Transform3D) -> void:
	if mirror == null or not is_instance_valid(mirror):
		return
	mirror.call("reflect", viewer)
	mirror.call("live")


## AH1.7. Leaving is a movement, not a menu close — so the room stops rendering
## its own reflection rather than being freed and rebuilt.
func leave() -> void:
	if mirror != null and is_instance_valid(mirror):
		mirror.call("sleep")


## Where to stand and what to look at, per wall. A caller turns to `NORTH` and
## gets the Board; it does not compute an angle and hope.
func facing(wall: String) -> Vector3:
	match wall:
		NORTH: return Vector3(0, 1.5, -SIZE.z * 0.5)
		EAST: return Vector3(SIZE.x * 0.5, 1.5, 0)
		SOUTH: return Vector3(0, 1.4, SIZE.z * 0.5)
		_: return Vector3(-SIZE.x * 0.5, 1.5, 0)
