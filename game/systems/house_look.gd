extends CanvasLayer

## The Dust to Bones look, applied to every scene's 3D view (autoload
## `HouseLook`). Greg, 26 September: reconceptualise the current look from the
## Higgsfield concept set, "without making things feel really AI gen", and
## "pick the distinct and similar enough ... with a grain of salt, there's a
## lot I don't like, but a lot I do like".
##
## So no concept image is drawn in the world. The in-world renders that agree
## with each other (DESIGN/LOOK_FROM_CONCEPTS.md lists which, and which were
## set aside) were measured, and what they share became a limitation of the
## screen: a coarse framebuffer, a short colour depth with ordered dither, a
## black floor, and a per-area colour balance. `shaders/dust_to_bones_look`
## does the work; this picks the grade for whatever is on screen.
##
## It sits on a CanvasLayer below every HUD layer, so text, prompts and menus
## stay sharp; only the world underneath is graded.

const SHADER := preload("res://shaders/dust_to_bones_look.gdshader")
const LAYER := -50

## Off for a session with `WOF_LOOK=clean` (before/after captures), or from
## code. A setting can drive this later.
static var enabled := true

## Every grade starts from this and overrides what it needs.
const BASE := {
	# Greg, 26 September: "subtler". Full resolution, and enough colour
	# steps that the dither only shows where the image is a smooth ramp: fog,
	# light falloff, the haze round a lamp.
	"strength": 1.0, "pixel_size": 1.0, "levels": 40.0, "dither_strength": 1.0,
	"black_point": 0.03, "gamma": 1.05, "exposure": 1.0, "saturation": 0.9,
	"shadow_balance": Color(0.5, 0.5, 0.5), "mid_balance": Color(0.52, 0.5, 0.48),
	"high_balance": Color(0.52, 0.51, 0.48), "balance_amount": 0.35,
	"grain": 0.025, "grain_rate": 12.0, "vignette": 0.3,
}

## Per area. Keys are scene file names (for scenes that share an environment
## preset) or WorldLook preset names. Each note names the reference it was
## tuned against and what that reference measured; the numbers are the game's
## own frame moved toward it, not copied from it.
const GRADES := {
	# Growing Floor. Refs: the red vat renders and the doctor walking out past
	# the tank. Median luminance 4-34/255, 44-77% of the frame near black,
	# saturation 0.6; the colour is in the vat glow and the checker floor.
	# The game measured a pastel median of 90, saturation 0.26.
	"growing_floor": {
		"black_point": 0.06, "gamma": 1.2, "exposure": 0.92, "saturation": 1.08,
		"shadow_balance": Color(0.47, 0.52, 0.49), "mid_balance": Color(0.6, 0.47, 0.45),
		"high_balance": Color(0.56, 0.53, 0.47), "balance_amount": 0.4,
	},
	# Support Unit hallways. Ref: the concrete hall with two guards. Median 15,
	# red-brown mids (1c0c0c), bone highlights, saturation 0.45. The game's
	# hall was green-grey with a median of 37.
	"support_unit": {
		"black_point": 0.05, "gamma": 1.15, "exposure": 0.9, "saturation": 0.8,
		"mid_balance": Color(0.59, 0.47, 0.46), "high_balance": Color(0.55, 0.52, 0.47),
	},
	"doctor_vehicle_bay": {
		"black_point": 0.05, "gamma": 1.12, "saturation": 0.8,
		"mid_balance": Color(0.56, 0.49, 0.46),
	},
	# Old drains. Refs: the brick drain with glyphs, and the bingyanger in the
	# water. Median 26-32, brown mids (221911), khaki-green highlights
	# (989567), saturation 0.3-0.46. The game's drains were saturated orange
	# (0.97).
	"old_drains": {
		"black_point": 0.02, "gamma": 0.95, "exposure": 1.1, "saturation": 0.5,
		"shadow_balance": Color(0.48, 0.52, 0.49), "mid_balance": Color(0.49, 0.52, 0.47),
		"high_balance": Color(0.5, 0.53, 0.46),
	},
	# Derby tunnels. Ref: the driver's view down the sodium-lit bore. Median
	# 47, bone-white highlights (e5dabf) off orange lamps, saturation 0.39.
	# NOT YET MEASURED AGAINST THAT: the only capture of this area shoots from
	# the spawn apron outside the mouth, where the ground is unlit black, so the
	# frame's median is a property of where the camera stands and not of the
	# grade. A 2.3 exposure was tried against that number and reverted -- it
	# brightens nothing that matters and clips the lamps. Re-shoot from inside
	# the bore before touching these values.
	"derby_tunnels": {
		"black_point": 0.03, "saturation": 0.78,
		"mid_balance": Color(0.55, 0.5, 0.45), "high_balance": Color(0.54, 0.52, 0.47),
	},
	# The derby pit. Ref: the floodlit arena. 62% near black, warm white
	# floodlight highlights, saturation 0.33. The first look measured 0.62
	# saturation against that 0.33: the whole pit was pink, so the floodlight
	# had no grey to be warm against, and the median of 10 said it was still
	# too dark to read the track.
	"rift_derby": {
		"black_point": 0.05, "gamma": 1.1, "exposure": 1.3, "saturation": 0.5,
		"high_balance": Color(0.54, 0.52, 0.49),
	},
	# The dry falls. Ref: blood from the outfall pipe down the gorge. Grey-
	# brown rock (351c1b mids), saturation 0.33, with the blood the only
	# saturated thing. The first look measured 0.77: the rock had taken the
	# blood's colour too, so the one saturated thing in the frame stopped being
	# the blood.
	"blood_waterfall_exit": {
		"black_point": 0.03, "exposure": 1.1, "saturation": 0.45,
		"mid_balance": Color(0.53, 0.49, 0.48), "high_balance": Color(0.5, 0.5, 0.5),
	},
	# The surface. Refs: the ruined town under the black sphere and the
	# bingyanga on the cracked flats. Median 81-106, only 11-12% near black,
	# khaki mids (72654a), yellowed highlights (a59c6f), saturation 0.32.
	# The first look measured a median of 29 at saturation 0.55: the ashbloom
	# flats were coming back as another night scene with a colour cast, when
	# every surface concept is the one bright, bleached, near-grey place in the
	# game. It is the only area whose grade lifts rather than crushes.
	"ashbloom": {
		"black_point": 0.0, "gamma": 0.78, "exposure": 1.75, "saturation": 0.48,
		"shadow_balance": Color(0.51, 0.5, 0.48), "mid_balance": Color(0.53, 0.51, 0.45),
		"high_balance": Color(0.54, 0.53, 0.44),
	},
	# The doctor's office, inside the Growing Floor's scene (set as an area by
	# DoctorRoute). Ref: the green CRT office with the axe and the lift.
	# Median 62, 25% near black, olive mids (3a4125), pale green highlights
	# (cae2ae), saturation 0.41.
	"doctor_office": {
		"black_point": 0.02, "gamma": 0.95, "exposure": 1.08, "saturation": 0.85,
		"shadow_balance": Color(0.49, 0.51, 0.49), "mid_balance": Color(0.49, 0.54, 0.46),
		"high_balance": Color(0.5, 0.55, 0.49),
	},
	# The title backdrop: graded lightly so the logo scene keeps its reds.
	"front_door": {
		"black_point": 0.02, "saturation": 1.0, "grain": 0.02,
	},
}

var rect: ColorRect
var look: ShaderMaterial
var current_key := ""
## A part of a scene with its own light (the doctor's office inside the
## Growing Floor) asks for its grade here; cleared on a scene change.
var area_key := ""
var _area_scene_id := 0


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("WOF_LOOK").to_lower() == "clean":
		enabled = false
	look = ShaderMaterial.new()
	look.shader = SHADER
	rect = ColorRect.new()
	rect.name = "Look"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.material = look
	add_child(rect)
	apply(key_for_screen())


func _process(_delta: float) -> void:
	rect.visible = enabled
	var key := key_for_screen()
	if key != current_key:
		apply(key)


## Which grade is on screen: a known scene first (several scenes share one
## environment preset), then the WorldLook preset the scene asked for.
func key_for_screen() -> String:
	var scene := get_tree().current_scene if is_inside_tree() else null
	if not area_key.is_empty() and scene != null and scene.get_instance_id() == _area_scene_id and GRADES.has(area_key):
		return area_key
	if scene != null:
		var candidates: Array[Node] = [scene]
		candidates.append_array(scene.get_children())
		for node in candidates:
			var base := node.scene_file_path.get_file().get_basename()
			if GRADES.has(base):
				return base
	if GRADES.has(WorldLook.current_preset):
		return WorldLook.current_preset
	return "house"


## Empty clears it.
func set_area(key: String) -> void:
	area_key = key
	var scene := get_tree().current_scene if is_inside_tree() else null
	_area_scene_id = scene.get_instance_id() if scene != null else 0


static func grade_for(key: String) -> Dictionary:
	var grade := BASE.duplicate()
	grade.merge(GRADES.get(key, {}), true)
	return grade


func apply(key: String) -> void:
	current_key = key
	var grade := grade_for(key)
	for parameter: String in grade:
		look.set_shader_parameter(parameter, grade[parameter])
