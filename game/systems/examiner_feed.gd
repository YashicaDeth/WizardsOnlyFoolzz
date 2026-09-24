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
## 1 is the resting width; rounded vowels purse it, E and I stretch it.
var width := 1.0
var _target_width := 1.0
## The face pieces the lips and jaw are, and where they rest.
var _lip_upper: Node3D
var _lip_lower: Node3D
var _jaw: Node3D
var _rest: Dictionary = {}
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
	_dress_as_staff(appearance)
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


## Greg on first launch wanted "a better examiner model". He was built as a
## decanted subject -- the same grained lab-grown flesh, the subject's harness
## strap, a bare torso under a scrap of coat -- which read, at this close-up,
## as a patchwork of pixel blocks. He is staff: a clinical coat over dark
## trousers, no harness, and skin smooth enough to read as a face on a feed.
func _dress_as_staff(appearance: Node) -> void:
	var wardrobe := ClothingShell.fresh_wardrobe()
	wardrobe.erase("head")
	wardrobe["style"] = "clinical"
	# Greg, 24 September: stained and bloodied from the procedures, not clean.
	# The rig's own soak, so it reads as dried into the weave: heaviest down
	# the front and the forearms that did the work, least on the trousers.
	ClothingShell.stain(rig, "torso", 0.55)
	ClothingShell.stain(rig, "right_arm", 0.5)
	ClothingShell.stain(rig, "left_arm", 0.35)
	ClothingShell.stain(rig, "left_leg", 0.2)
	ClothingShell.stain(rig, "right_leg", 0.15)
	rig.dress(wardrobe)
	var coat := Color("d8d4c6").lerp(Color("5a1a12"), 0.38)
	var pieces: Dictionary = appearance.get("details")
	for piece_name in ["Coat_Front", "Collar_L", "Collar_R"]:
		var piece := pieces.get(piece_name) as MeshInstance3D
		if piece != null and piece.mesh != null:
			var cloth := StandardMaterial3D.new()
			cloth.albedo_color = coat.darkened(0.08 if piece_name != "Coat_Front" else 0.0)
			cloth.roughness = 0.9
			piece.mesh.material = cloth
	var strap := pieces.get("Torque_Strap") as Node3D
	if strap != null:
		strap.visible = false
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color("b79a86")
	skin.roughness = 0.55
	skin.rim_enabled = true
	skin.rim = 0.25
	var head := rig.parts.get("head") as MeshInstance3D
	if head != null:
		head.material_override = skin
	# The face HunterAppearance builds is the player's: grown wrong in a tank,
	# mismatched eyes, exposed teeth, raw lips. He was grown properly, or not
	# grown at all. Same geometry, an ordinary face on it.
	var sclera := StandardMaterial3D.new()
	sclera.albedo_color = Color("d9d4c8")
	sclera.roughness = 0.35
	var iris := StandardMaterial3D.new()
	iris.albedo_color = Color("1c1512")
	var lips := StandardMaterial3D.new()
	lips.albedo_color = Color("8a5a4e")
	lips.roughness = 0.6
	var eye_l := pieces.get("Eye_L") as MeshInstance3D
	var eye_r := pieces.get("Eye_R") as MeshInstance3D
	var pupil_l := pieces.get("Pupil_L") as MeshInstance3D
	var pupil_r := pieces.get("Pupil_R") as MeshInstance3D
	if eye_l != null and eye_r != null:
		eye_r.mesh = eye_l.mesh.duplicate()
		eye_r.position = Vector3(-eye_l.position.x, eye_l.position.y, eye_l.position.z)
	if pupil_l != null and pupil_r != null:
		pupil_r.mesh = pupil_l.mesh.duplicate()
		pupil_r.position = Vector3(-pupil_l.position.x, pupil_l.position.y, pupil_l.position.z)
	for piece_name: String in pieces:
		var piece := pieces[piece_name] as MeshInstance3D
		if piece == null or piece.mesh == null or piece.get_parent() != head:
			continue
		if piece_name.begins_with("Eye_"):
			piece.material_override = sclera
		elif piece_name.begins_with("Pupil_"):
			piece.material_override = iris
		elif piece_name.begins_with("Mouth_"):
			piece.material_override = lips
		elif piece_name.begins_with("Tooth_"):
			piece.visible = false
		else:
			piece.material_override = skin
	_lip_upper = pieces.get("Mouth_Upper") as Node3D
	_lip_lower = pieces.get("Mouth_Lower") as Node3D
	_jaw = pieces.get("Jaw_Line") as Node3D
	for part in [_lip_upper, _lip_lower, _jaw]:
		if part != null:
			_rest[part] = part.position


## `revealed` is what he has said so far; its last letter sets the mouth.
## An empty string, or a line already finished, lets it close.
##
## Greg, 24 September: better lip sync. Each letter picks a mouth shape, not
## just an amount of open: A drops the jaw, O and U purse it round, E and I
## stretch it wide and shallow, M B P press the lips shut, F and V tuck the
## lower lip, and a gap between words lets it rest.
func say(revealed: String, still_talking: bool) -> void:
	if not still_talking or revealed.is_empty():
		_target = 0.0
		_target_width = 1.0
		return
	var shape := mouth_shape(revealed.right(1))
	_target = float(shape.open)
	_target_width = float(shape.width)


static func mouth_shape(letter: String) -> Dictionary:
	var last := letter.to_lower()
	if last == "a":
		return {"open": 1.0, "width": 1.0}
	if last in ["o", "u", "w"]:
		return {"open": 0.7, "width": 0.62}
	if last in ["e", "i", "y"]:
		return {"open": 0.4, "width": 1.25}
	if last in ["m", "b", "p"]:
		return {"open": 0.0, "width": 0.95}
	if last in ["f", "v"]:
		return {"open": 0.12, "width": 1.05}
	if last in [" ", ".", ",", "?", "!", "-", ";", ":", "\"", "'"]:
		return {"open": 0.0, "width": 1.0}
	return {"open": 0.25, "width": 1.0}


func _process(delta: float) -> void:
	_clock += delta
	openness = move_toward(openness, _target, delta * 14.0)
	width = move_toward(width, _target_width, delta * 10.0)
	if mouth != null and is_instance_valid(mouth):
		mouth.scale = Vector3(width * (1.0 - openness * 0.2), 0.3 + openness * 3.0, 1.0)
		mouth.position.y = -0.062 - openness * 0.010
	# The lips part around the opening and the jaw carries the lower one down.
	if _lip_upper != null and _rest.has(_lip_upper):
		_lip_upper.position = (_rest[_lip_upper] as Vector3) + Vector3(0, openness * 0.004, 0)
		_lip_upper.scale.x = width
	if _lip_lower != null and _rest.has(_lip_lower):
		_lip_lower.position = (_rest[_lip_lower] as Vector3) + Vector3(0, -openness * 0.020, 0)
		_lip_lower.scale.x = width
	if _jaw != null and _rest.has(_jaw):
		_jaw.position = (_rest[_jaw] as Vector3) + Vector3(0, -openness * 0.016, 0)
	if rig != null and is_instance_valid(rig):
		# He is watching the tank, not posing: a slow weight shift and a tilt.
		# The face is built on the rig's -Z side, which is where the camera is.
		rig.rotation.y = sin(_clock * 0.31) * 0.08
		var head := rig.parts.get("head") as Node3D
		if head != null:
			head.rotation.x = sin(_clock * 0.47) * 0.03 - openness * 0.02
