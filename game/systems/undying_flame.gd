class_name UndyingFlame
extends Node3D

## A8.1 / A8.2. The spirit, burning on the body, and the frame coming apart
## around it.
##
## THE_REWORK §2 says the essence cannot be banished by torture, killing or
## violence — *"it stays in pure bright flames that are vibrant and melt the
## game's screen"* — and the checklist's own word for what was wrong with every
## previous attempt at it is *overlay*. So the flame is a `material_overlay` on
## the player's own zone meshes: it follows every limb the anatomy moves, is
## occluded by whatever occludes the player, leaves with a limb that comes off,
## and is simply absent from a frame the player is not in. The melt is a shell
## around the body, the same construction A3.2 arrived at for a lamp.
##
## Both are driven by one number. The body failing is what lets the spirit show,
## so the worse the anatomy's condition, the harder this burns — which makes the
## flame a readout of the one thing the game keeps saying about this character
## rather than an effect that happens to be on.

const FLAME_SHADER := preload("res://shaders/undying_flame.gdshader")
const MELT_SHADER := preload("res://shaders/flame_melt.gdshader")

## What the spirit shows at full health. Never zero: undying is not conditional.
const FLOOR := 0.28
## How far out the frame melts, in metres. Measured down from 1.75, which from
## a third-person camera three metres back subtends sixty degrees and smeared
## half the frame — at which point it is the fullscreen effect this segment
## exists to replace, wearing a different name.
const MELT_REACH := 1.1

static var _shared_noise: Texture2D = null

var _overlays: Array[ShaderMaterial] = []
var _melt: ShaderMaterial
var _shell: MeshInstance3D


## Sets a rig alight. Every `MeshInstance3D` under `rig` takes the flame as an
## overlay — overlay rather than override, so A5's materials underneath are
## untouched and a zone keeps answering light as flesh while it burns.
func ignite(rig: Node3D) -> void:
	for node in rig.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var overlay := ShaderMaterial.new()
		overlay.shader = FLAME_SHADER
		overlay.set_shader_parameter("flame_noise", _noise())
		overlay.set_shader_parameter("intensity", FLOOR)
		mesh.material_overlay = overlay
		_overlays.append(overlay)

	_shell = MeshInstance3D.new()
	_shell.name = "FlameMelt"
	var shell_mesh := SphereMesh.new()
	shell_mesh.radius = 0.5
	shell_mesh.height = 1.0
	shell_mesh.radial_segments = 18
	shell_mesh.rings = 10
	_shell.mesh = shell_mesh
	_shell.scale = Vector3.ONE * MELT_REACH * 2.0
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shell.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_shell.sorting_offset = -1.0
	# Chest height, not the rig origin. The origin is between the feet, which
	# put the melt in a puddle on the floor in third person and left it below
	# the camera entirely in first — where the player is the burning thing and
	# the frame is supposed to be what comes apart.
	_shell.position = Vector3(0, 1.3, 0)
	_melt = ShaderMaterial.new()
	_melt.shader = MELT_SHADER
	_melt.set_shader_parameter("melt_noise", _noise())
	_melt.set_shader_parameter("reach", MELT_REACH)
	_melt.set_shader_parameter("amount", FLOOR)
	_shell.material_override = _melt
	add_child(_shell)


## `condition` is 1 for an intact body and 0 for one that has nothing left.
## Inverted here: this is the one thing in the game that gets stronger as the
## player gets worse.
func set_condition(condition: float) -> void:
	var showing := lerpf(1.0, FLOOR, clampf(condition, 0.0, 1.0))
	for overlay in _overlays:
		overlay.set_shader_parameter("intensity", showing)
	if _melt != null:
		# The melt lags the flame: a body at full health burns quietly without
		# taking the frame with it, and the screen only starts failing once the
		# spirit is doing more than showing.
		_melt.set_shader_parameter("amount", clampf(showing * showing * showing * 1.25, 0.0, 1.0))


## Generated, like every other field in this project, and shared: one flame
## texture for every limb rather than one per mesh.
static func _noise() -> Texture2D:
	if _shared_noise != null:
		return _shared_noise
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.045
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.62
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.seamless = true
	texture.width = 128
	texture.height = 128
	_shared_noise = texture
	return texture
