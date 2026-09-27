class_name ExaminerLook
extends RefCounted

## Greg, 26 September (question boxes): the examiner is tall and gaunt, in a
## bloodied coat, with a surgical mask and loupe glasses. One place builds him
## so the man at the glass, on the intake feed and in his office is the same
## man. Placeholder geometry in the house palette (a BaselineHuman plus
## boxes), to swap for an authored model; his face stays the ordinary human
## one Greg chose on 24 September.
##
## The mask hangs at his throat while he talks to you through the glass (the
## lip sync Greg liked stays visible) and goes up over his nose for the work,
## and for the fight.

const TALL := 1.08
const GAUNT := 0.88
const MASK_COLOUR := Color("93aaa2")
const LOUPE_METAL := Color("2d2a26")
const LENS := Color("5f7d74")


## Stains and dresses `body` as the examiner and adds the mask and loupes.
## Returns the mask node so a scene can raise or lower it (`set_mask`).
static func dress(body: BaselineHuman, mask_up := false) -> Node3D:
	body.scale = Vector3(GAUNT, TALL, GAUNT)
	var wardrobe := ClothingShell.fresh_wardrobe()
	wardrobe.erase("head")
	wardrobe["style"] = "clinical"
	ClothingShell.stain(body, "torso", 0.55)
	ClothingShell.stain(body, "right_arm", 0.5)
	ClothingShell.stain(body, "left_arm", 0.35)
	ClothingShell.stain(body, "left_leg", 0.2)
	ClothingShell.stain(body, "right_leg", 0.15)
	body.dress(wardrobe)
	return add_gear(body, mask_up)


## Just the mask and loupes, for a body already dressed (the intake feed's
## close-up keeps its own framing and proportions).
static func add_gear(body: BaselineHuman, mask_up := false) -> Node3D:
	var head := body.parts.get("head") as Node3D
	if head == null:
		return null
	var mask := Node3D.new()
	mask.name = "SurgicalMask"
	head.add_child(mask)
	_box(mask, Vector3(0.19, 0.105, 0.035), Vector3.ZERO, _matte(MASK_COLOUR))
	# Pleats: three darker lines across it.
	for row in 3:
		_box(mask, Vector3(0.188, 0.006, 0.037), Vector3(0, -0.03 + row * 0.03, 0), _matte(MASK_COLOUR.darkened(0.25)))
	# Ear loops back to the sides of the head.
	for side in [-1.0, 1.0]:
		_box(mask, Vector3(0.008, 0.008, 0.13), Vector3(side * 0.1, 0.01, 0.07), _matte(Color("d8d2c4")))
	set_mask(mask, mask_up)

	var loupes := Node3D.new()
	loupes.name = "Loupes"
	head.add_child(loupes)
	loupes.position = Vector3(0, 0.035, -0.13)
	_box(loupes, Vector3(0.2, 0.022, 0.02), Vector3(0, 0.02, 0.005), _matte(LOUPE_METAL))
	for side in [-1.0, 1.0]:
		var barrel := MeshInstance3D.new()
		var tube := CylinderMesh.new()
		tube.top_radius = 0.017
		tube.bottom_radius = 0.021
		tube.height = 0.075
		tube.radial_segments = 10
		tube.material = _matte(LOUPE_METAL)
		barrel.mesh = tube
		barrel.rotation.x = PI * 0.5
		barrel.position = Vector3(side * 0.045, 0.0, -0.035)
		loupes.add_child(barrel)
		var lens := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.015
		disc.bottom_radius = 0.015
		disc.height = 0.004
		disc.radial_segments = 10
		var glass := StandardMaterial3D.new()
		glass.albedo_color = LENS
		glass.emission_enabled = true
		glass.emission = LENS
		glass.emission_energy_multiplier = 0.25
		disc.material = glass
		lens.mesh = disc
		lens.rotation.x = PI * 0.5
		lens.position = Vector3(side * 0.045, 0.0, -0.074)
		loupes.add_child(lens)
	return mask


## Up over the mouth and nose, or down at the throat.
static func set_mask(mask: Node3D, up: bool) -> void:
	if mask == null:
		return
	mask.position = Vector3(0, -0.035, -0.128) if up else Vector3(0, -0.17, -0.1)
	mask.rotation.x = 0.0 if up else 0.55


static func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	node.mesh = mesh
	node.position = at
	parent.add_child(node)
	return node


static func _matte(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.9
	return material
