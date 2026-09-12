class_name LightWarp
extends MeshInstance3D

## A3.2. The air around one light, bending.
##
## The rework's line is *"the light can become really warped at night and
## distorted"*, and AS2.1 built that as a dial on the fullscreen psychedelic
## shader driven by the hour. Two things were wrong with it and both are the
## same mistake. It warped the whole frame — sky, ground, and the index the
## player had open — none of which are light; and it left the nine sodium lamps
## in the Ashbloom, which *are* the light, rendering exactly as they do at noon.
## It also spent the one dial the game reserves for being on something, so a
## sunset and a drug became the same picture. That dial is back to being the
## drugs' (`AG5.6`), and this is the warping, built where the statement
## actually points: at the light.
##
## One of these is a shell of real geometry parented to a real light, sized to
## that light's own throw. Only the part of the screen the shell covers is
## displaced. Nothing else in the scene pays anything, and a room with no lamps
## has no warping — which is the difference between a property and a filter.
##
## The noise is generated here rather than imported, the same way
## `world_look.gd` builds its contamination and `psychedelic_rig.gd` builds its
## placeholders: this is a flow field nobody has designed, and an authored asset
## for it would be a file to keep in agreement with nothing.

const LIGHT_WARP_SHADER := preload("res://shaders/light_warp.gdshader")

## Every shell joins this, so the per-frame update can reach all of them
## without walking the scene to find them. See `set_all`.
const GROUP := "light_warp"

## Shared across every shell. The texture is identical for all of them and the
## per-lamp variation comes from where the shell is in the world, so nine lamps
## cost one texture rather than nine.
static var _shared_noise: Texture2D = null

var _material: ShaderMaterial


## Wraps `light` in a warp shell and returns it. The shell is a child of the
## light, so it follows anything that moves the lamp and dies with it.
##
## `reach` defaults to the light's own range, because the whole claim this
## makes is that the distortion is that light's — a shell bigger than the throw
## would be bending air the lamp does not reach.
static func attach(light: OmniLight3D, reach := -1.0) -> LightWarp:
	var shell := LightWarp.new()
	shell.name = "%s_warp" % light.name
	var span: float = light.omni_range if reach <= 0.0 else reach
	var mesh := SphereMesh.new()
	# Authored as a unit sphere and scaled to the lamp's own throw, so the single
	# number deciding how far the air bends is `omni_range` itself rather than a
	# second radius sitting here to be kept in step with it.
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 20
	mesh.rings = 12
	shell.mesh = mesh
	shell.scale = Vector3.ONE * span * 2.0
	# The shell is see-through by construction, so shadow and GI passes would be
	# spending on something that is not there.
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# Drawn after the opaque world, so `hint_screen_texture` has a world in it.
	shell.sorting_offset = -1.0
	light.add_child(shell)
	shell.add_to_group(GROUP)
	shell._build_material(light.light_color, span)
	return shell


func _build_material(lamp_color: Color, span: float) -> void:
	_material = ShaderMaterial.new()
	_material.shader = LIGHT_WARP_SHADER
	_material.set_shader_parameter("noise_texture", _noise())
	# The shell tints toward the lamp's own colour rather than a constant, so a
	# cold light does not warp the air warm.
	_material.set_shader_parameter("tint", Vector3(lamp_color.r, lamp_color.g, lamp_color.b))
	_material.set_shader_parameter("reach", span)
	_material.set_shader_parameter("amount", 0.0)
	material_override = _material


## How much this lamp is bending the air, 0 to 1. Driven by the hour from the
## scene, so a lamp in daylight is inert and the same lamp after dark is the
## only thing in frame doing this.
func set_amount(value: float) -> void:
	if _material == null:
		return
	_material.set_shader_parameter("amount", clampf(value, 0.0, 1.0))


## Sets every warp shell at once. A convenience for the scene's day/night tick,
## so it does not have to hold a list it would then have to keep correct as
## lamps come and go.
##
## Reads a group rather than searching the tree by class name: this runs every
## physics frame, and `find_children` from the Hunt Grounds root walks the
## several thousand nodes of the Ashbloom to arrive at nine of them. The group
## is maintained by the tree itself, so it costs nothing and there is still no
## list anybody has to remember to update.
static func set_all(root: Node, value: float) -> void:
	var tree := root.get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group(GROUP):
		(node as LightWarp).set_amount(value)


static func _noise() -> Texture2D:
	if _shared_noise != null:
		return _shared_noise
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.035
	noise.fractal_octaves = 2
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.seamless = true
	texture.width = 128
	texture.height = 128
	_shared_noise = texture
	return texture
