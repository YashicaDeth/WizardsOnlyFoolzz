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
}


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
