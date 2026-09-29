extends RefCounted
## Greg's generated models (Higgsfield, 29 September) arrive as a unit box in
## whatever orientation the generator liked. This puts one in the game's
## conventions from *measured* numbers (tests/model_capture.tscn --mode=axes
## prints the principal axes and a profile along them), never guessed angles:
##
##   make("shiv") -> a Node3D whose origin is the model's pivot (the grip, the
##   mount point ...), +Z forward (the tip, the lens), +Y up, in metres.
##
## `null` when the file is missing (an LFS checkout without media), so the
## caller keeps its drawn version and the game still plays.
##
## No class_name on purpose: a new global class is not visible to a scene that
## is already open until the project is re-imported; callers preload this.

const ART := "res://art/generated/"

## file; scale = metres per model unit; right / up / forward = three
## orthonormal, right-handed directions in the model's own space that become
## +X / +Y / +Z; pivot = the model-space point that becomes the origin.
const FIT := {
	# Long axis (thin end = tip) to +Z; the blade's broad direction to X and
	# its thickness to Y, like the drawn blades. 1.28 model units end to end,
	# the handle is t -0.55..+0.05 along it, so the grip sits at t -0.25.
	"shiv": {
		"file": "items/shiv.glb", "scale": 0.265,
		"right": Vector3(0.193, 0.776, 0.601),
		"up": Vector3(-0.972, 0.068, 0.225),
		"forward": Vector3(0.134, -0.627, 0.767),
		"pivot": Vector3(-0.0245, 0.2288, -0.2778),
	},
	# The phone: width to X, the screen normal (the cracked glass faces it) to
	# Y so it lies screen-up, the top to +Z. 1.036 units long -> a 0.34 m
	# brick, 0.19 m wide, 4.4 cm thick. The unit box is already centred.
	"black_mirror": {
		"file": "items/black_mirror.glb", "scale": 0.328,
		"right": Vector3(-0.024, 0.069, 0.997),
		"up": Vector3(0.976, 0.216, 0.008),
		"forward": Vector3(-0.214, 0.974, -0.073),
		"pivot": Vector3.ZERO,
	},
	# The broken restraint: its 1.051-unit strap becomes 0.50 m. The buckle at
	# the positive end is the grip, so the leather and second buckle hang away
	# from the camera along -Z when it is held.
	"restraint": {
		"file": "items/restraint.glb", "scale": 0.476,
		"right": Vector3(0.203, 0.286, 0.937),
		"up": Vector3(-0.216, -0.920, 0.327),
		"forward": Vector3(0.955, -0.269, -0.125),
		"pivot": Vector3(0.404, -0.128, -0.066),
	},
	# The wall CCTV, measured on its canopy (the flat sunshade plate): forward is
	# the canopy's long edge, so the housing looks along +Z exactly level and the
	# game's own head pitch is the only downward tilt. The pivot is the middle of
	# the housing, which is where SecurityCamera's head turns. 0.6 makes the
	# housing 0.42 m long and 0.24 m wide, the box it replaces.
	"cctv": {
		"file": "props/cctv.glb", "scale": 0.6,
		"right": Vector3(0.993, 0.025, -0.115),
		"up": Vector3(-0.009, 0.991, 0.134),
		"forward": Vector3(0.117, -0.132, 0.984),
		"pivot": Vector3(0.01, 0.207, 0.141),
	},
	# The surgical lamp is an articulated arm whose head faces +X and ~20 degrees
	# down. The head disc's normal (PCA of the vertices with x > 0.12, y < 0,
	# signed away from the arm) becomes -Y, so the head looks straight down and
	# the arm climbs at a slant to its ceiling plate, the pivot (the centroid of
	# the top 15%). 0.9 makes the head 0.6 m across; its centre ends up at
	# LAMP_HEAD below and beside the pivot.
	"surgical_lamp": {
		"file": "props/surgical_lamp.glb", "scale": 0.9,
		"right": Vector3(0.345, 0.938, 0.0),
		"up": Vector3(-0.936, 0.344, -0.071),
		"forward": Vector3(-0.067, 0.025, 0.998),
		"pivot": Vector3(-0.234, 0.418, 0.048),
	},
	# The bone drill came upright (bit +Z, a slanted grip down), but that grip
	# would not stand, so it lies on its left side: model +X becomes up. 0.28
	# makes it 0.28 m long; the pivot is the middle of that side, so y = 0 is
	# the surface it lies on.
	"bone_drill": {
		"file": "props/bone_drill.glb", "scale": 0.28,
		"right": Vector3(0.0, -1.0, 0.0),
		"up": Vector3(1.0, 0.0, 0.0),
		"forward": Vector3(0.0, 0.0, 1.0),
		"pivot": Vector3(-0.105, 0.0, 0.0),
	},
}

## Where the lamp head's centre sits relative to the lamp's pivot, in metres
## (the head centroid (0.275, -0.223, -0.021) through the FIT above).
const LAMP_HEAD := Vector3(-0.383, -0.623, -0.107)


## The models' ORM textures mark metal as fully metallic. The Hunt has a dark
## sky and no reflection probes, and a fully metallic surface has no diffuse to
## show, so a generated blade or barrel rendered black. This copies each
## material (the imported one is shared) and caps its metallic factor, which
## scales the texture, so metal keeps a sheen and stays readable.
const METAL_CAP := 0.4


static func tame_metal(root: Node, cap := METAL_CAP) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var instance := node as MeshInstance3D
			for surface in instance.mesh.get_surface_count():
				var material := instance.mesh.surface_get_material(surface) as BaseMaterial3D
				if material != null and material.metallic > cap:
					var copy := material.duplicate() as BaseMaterial3D
					copy.metallic = cap
					instance.set_surface_override_material(surface, copy)


## Wear: multiplies every surface's albedo by a dirtier colour as `condition`
## falls (1 = as generated). Copies the material like tame_metal does.
static func wear(root: Node, condition: float) -> void:
	var dirt := Color.WHITE.lerp(Color(0.55, 0.47, 0.42), clampf(1.0 - condition, 0.0, 1.0))
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var instance := node as MeshInstance3D
			for surface in instance.mesh.get_surface_count():
				var material := (instance.get_surface_override_material(surface) if instance.get_surface_override_material(surface) != null else instance.mesh.surface_get_material(surface)) as BaseMaterial3D
				if material != null:
					var copy := material.duplicate() as BaseMaterial3D
					copy.albedo_color = material.albedo_color * dirt
					instance.set_surface_override_material(surface, copy)


static func has(model_name: String) -> bool:
	return FIT.has(model_name) and ResourceLoader.exists(ART + str(FIT[model_name].file))


static func make(model_name: String) -> Node3D:
	if not has(model_name):
		return null
	var fit: Dictionary = FIT[model_name]
	var scene := load(ART + str(fit.file)) as PackedScene
	if scene == null:
		return null
	var model := scene.instantiate() as Node3D
	if model == null:
		return null
	# Rows are the three source directions, so this maps them onto X, Y and Z.
	var turn := Basis(fit.right, fit.up, fit.forward).transposed()
	var size := float(fit.scale)
	model.transform = Transform3D(turn.scaled(Vector3.ONE * size), -(turn * (fit.pivot as Vector3)) * size)
	tame_metal(model)
	var holder := Node3D.new()
	holder.name = "generated_" + model_name
	holder.add_child(model)
	return holder
