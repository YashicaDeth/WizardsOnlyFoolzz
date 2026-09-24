class_name ExaminerFeed
extends SubViewportContainer

## The examiner, live, on the camera that watches the tank. Greg on first launch
## (2026-09-24): the flat circle "isn't even linked to what he's saying" and
## should be a 3D model up where the recording notice sits. He is the same
## BaselineHuman + HunterAppearance an overworld person is built from, in his
## own small World3D, framed head and shoulders under cold clinical light.
##
## The mouth is driven by his words, not by audio: `say()` hands over the part
## of the line revealed so far, and each vowel opens the jaw while consonants
## close it. That is "from our voice" in the only sense this scene has one --
## the typewriter is his voice.

const BASELINE_HUMAN := preload("res://systems/baseline_human.gd")
const HUNTER_APPEARANCE := preload("res://systems/hunter_appearance.gd")
const HEAD_HEIGHT := 1.62

var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
var rig: BaselineHuman
var mouth: MeshInstance3D
## 0 shut, 1 open. Eased toward `_target` so a syllable reads as a movement.
var openness := 0.0
var _target := 0.0
var _clock := 0.0


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	viewport = SubViewport.new()
	viewport.name = "ExaminerWorld"
	viewport.size = Vector2i(480, 360)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)
	var environment := WorldEnvironment.new()
	var world := Environment.new()
	world.background_mode = Environment.BG_COLOR
	world.background_color = Color("07090a")
	world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.ambient_light_color = Color("39433f")
	world.ambient_light_energy = 0.5
	environment.environment = world
	stage.add_child(environment)
	camera = Camera3D.new()
	camera.fov = 30.0
	camera.position = Vector3(0.12, HEAD_HEIGHT - 0.02, -1.05)
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, HEAD_HEIGHT - 0.10, 0.0), Vector3.UP)
	_light(Vector3(0.0, 2.6, -0.6), Color("c9d6cf"), 2.4)
	_light(Vector3(-0.9, 1.5, -0.8), Color("4f7f78"), 0.9)
	_light(Vector3(0.7, 1.7, 0.6), Color("8e1714"), 1.1)
	_build_examiner()


func _light(at: Vector3, color: Color, energy: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 4.0
	stage.add_child(light)


func _build_examiner() -> void:
	var config: Dictionary = BASELINE_HUMAN.config_from_subject({"race": "decanted"})
	config["gore"] = false
	rig = BASELINE_HUMAN.new()
	rig.name = "Examiner"
	stage.add_child(rig)
	rig.build("intake_examiner", config)
	var appearance := HUNTER_APPEARANCE.new()
	rig.add_child(appearance)
	appearance.configure(rig, {"axes": {"brow": 0.7, "jaw": 0.6, "cheek": 0.2, "eyes": 0.3, "nose": 0.55, "mouth": 0.4}})
	var head := rig.parts.get("head") as Node3D
	if head == null:
		return
	mouth = MeshInstance3D.new()
	mouth.name = "Mouth"
	var box := BoxMesh.new()
	box.size = Vector3(0.07, 0.022, 0.012)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("1a0806")
	material.roughness = 0.9
	box.material = material
	mouth.mesh = box
	mouth.position = Vector3(0.0, -0.058, -0.118)
	head.add_child(mouth)


## `revealed` is what he has said so far; its last letter sets the mouth.
## An empty string, or a line already finished, lets it close.
func say(revealed: String, still_talking: bool) -> void:
	if not still_talking or revealed.is_empty():
		_target = 0.0
		return
	var last := revealed.right(1).to_lower()
	if last in ["a", "o"]:
		_target = 1.0
	elif last in ["e", "i", "u", "y"]:
		_target = 0.65
	elif last in [" ", ".", ",", "?", "!", "-"]:
		_target = 0.0
	else:
		_target = 0.25


func _process(delta: float) -> void:
	_clock += delta
	openness = move_toward(openness, _target, delta * 14.0)
	if mouth != null and is_instance_valid(mouth):
		mouth.scale = Vector3(1.0 - openness * 0.25, 1.0 + openness * 2.6, 1.0)
		mouth.position.y = -0.058 - openness * 0.010
	if rig != null and is_instance_valid(rig):
		# He is watching the tank, not posing: a slow weight shift and a tilt.
		# The face is built on the rig's -Z side, which is where the camera is.
		rig.rotation.y = sin(_clock * 0.31) * 0.08
		var head := rig.parts.get("head") as Node3D
		if head != null:
			head.rotation.x = sin(_clock * 0.47) * 0.03 - openness * 0.02
