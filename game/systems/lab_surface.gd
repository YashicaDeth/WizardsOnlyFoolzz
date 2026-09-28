class_name LabSurface
extends RefCounted

## The facility's real surfaces. Greg on first launch (2026-09-24): the lab's
## procedural grain "looks like poo", and it should read as an Outlast-style
## underground asylum lab -- clinical tile, bare concrete, peeling paint, plate
## steel -- seen on body-cam. These are CC0 photo-scanned sets from ambientCG
## (see art/textures/lab/CREDITS.md), mapped in world space so a tile is the
## same size on a two-metre wall and a forty-metre corridor.

const ROOT := "res://art/textures/lab/"
## role -> [texture set, world metres per repeat, tint, has metalness map]
const ROLES := {
	"floor": ["Tiles074", 1.6, Color(0.62, 0.60, 0.56), false],
	# Warm red-brown concrete (Greg, 26 September, the Higgsfield hall and
	# doorway renders), not the green-grey the scan tinted to.
	"wall": ["Concrete034", 2.4, Color(0.55, 0.47, 0.43), false],
	"ceiling": ["Concrete034", 3.0, Color(0.26, 0.26, 0.25), false],
	"grime": ["PaintedMetal009", 2.0, Color(0.70, 0.68, 0.60), true],
	"plate": ["MetalPlates006", 1.2, Color(0.80, 0.82, 0.80), true],
	"rust": ["Rust004", 1.8, Color(0.85, 0.80, 0.75), true],
}

static var _cache: Dictionary = {}


static func material(role: String) -> StandardMaterial3D:
	if _cache.has(role):
		return _cache[role]
	var spec: Array = ROLES.get(role, ROLES.wall)
	var set_name := str(spec[0])
	var material := StandardMaterial3D.new()
	material.albedo_texture = _texture(set_name + "_Color.jpg")
	material.albedo_color = spec[2]
	var normal := _texture(set_name + "_NormalGL.jpg")
	if normal != null:
		material.normal_enabled = true
		material.normal_texture = normal
		material.normal_scale = 1.2
	material.roughness_texture = _texture(set_name + "_Roughness.jpg")
	material.roughness = 1.0
	if bool(spec[3]):
		material.metallic_texture = _texture(set_name + "_Metalness.jpg")
		material.metallic = 1.0
	# World-space triplanar: box meshes of any size tile at a real scale.
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	var repeat := 1.0 / float(spec[1])
	material.uv1_scale = Vector3(repeat, repeat, repeat)
	# Texels you can see, like every in-world concept render (Greg, 26
	# September): photo scans filtered smooth are what made the lab read as a
	# clean engine demo. Nearest within a mip level, mipmapped so distance
	# does not shimmer.
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	_cache[role] = material
	return material


## A structural box, read by its shape: thin and low is floor, thin and high is
## ceiling, anything standing is wall.
static func for_slab(dimensions: Vector3, at: Vector3) -> StandardMaterial3D:
	if dimensions.y <= 0.6:
		return material("floor" if at.y < 1.0 else "ceiling")
	return material("wall")


static func _texture(file: String) -> Texture2D:
	var path := ROOT + file
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## The lamp on the body cam. The facility is lit for the people who work in it,
## not for you, and the new surfaces only read where light lands on them: a
## narrow warm cone that goes where you look is what makes it body-cam footage.
static func attach_body_cam(camera: Camera3D) -> SpotLight3D:
	var lamp := SpotLight3D.new()
	lamp.name = "BodyCamLamp"
	lamp.light_color = Color("ffe6c7")
	lamp.light_energy = 7.0
	lamp.spot_range = 22.0
	lamp.spot_angle = 30.0
	lamp.spot_attenuation = 0.9
	lamp.shadow_enabled = true
	lamp.position = Vector3(0.18, -0.12, 0.0)
	camera.add_child(lamp)
	return lamp


## The breach tool: a pneumatic ram with a charge canister and two prongs.
## Greg on first launch: it "doesn't look like anything" when picked up.
## One model for the floor, the hand, and Lower Works.
static func breach_tool() -> Node3D:
	var tool := Node3D.new()
	tool.name = "BreachTool"
	var plate := material("plate")
	var grime := material("grime")
	var barrel := MeshInstance3D.new()
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.045
	barrel_mesh.bottom_radius = 0.055
	barrel_mesh.height = 0.95
	barrel_mesh.material = plate
	barrel.mesh = barrel_mesh
	barrel.rotation_degrees.x = 90.0
	tool.add_child(barrel)
	var canister := MeshInstance3D.new()
	var canister_mesh := CylinderMesh.new()
	canister_mesh.top_radius = 0.075
	canister_mesh.bottom_radius = 0.075
	canister_mesh.height = 0.30
	canister_mesh.material = grime
	canister.mesh = canister_mesh
	canister.rotation_degrees.x = 90.0
	canister.position = Vector3(0.0, -0.09, 0.22)
	tool.add_child(canister)
	for side in [-1.0, 1.0]:
		var prong := MeshInstance3D.new()
		var prong_mesh := BoxMesh.new()
		prong_mesh.size = Vector3(0.02, 0.02, 0.16)
		prong_mesh.material = material("rust")
		prong.mesh = prong_mesh
		prong.position = Vector3(side * 0.035, 0.0, -0.54)
		tool.add_child(prong)
	var charge := OmniLight3D.new()
	charge.name = "Charge"
	charge.light_color = Color("f0a24b")
	charge.light_energy = 0.5
	charge.omni_range = 0.8
	charge.position = Vector3(0.0, -0.09, 0.22)
	tool.add_child(charge)
	return tool


## Put a tool in view, lower right, the way a body cam sees a held object.
static func hold_in_view(camera: Camera3D, tool: Node3D) -> void:
	if tool.get_parent() != null:
		tool.get_parent().remove_child(tool)
	camera.add_child(tool)
	tool.position = Vector3(0.34, -0.30, -0.62)
	tool.rotation_degrees = Vector3(4.0, 8.0, -6.0)
