class_name SilhouetteRim
extends RefCounted

## Greg, 29 September (question box): in the dark rooms enemies keep a faint
## readable silhouette between the pools of light, so you can always read a
## fight; the rooms stay black and bodies do not disappear. A thin cold rim
## (`shaders/silhouette_rim.gdshader`) worn as a `material_overlay` by every
## mesh of a hostile's body. It lights nothing and changes no numbers.

const SHADER := preload("res://shaders/silhouette_rim.gdshader")

static var _material: ShaderMaterial


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
	return _material


## Rims every body (`BaselineHuman`) at or under `root`: its meshes, clothes
## and whatever it holds. Props, lights and cones beside it are left alone, as
## is any mesh already wearing an overlay (the undying flame). Returns how
## many meshes were rimmed.
static func dress(root: Node) -> int:
	if root == null:
		return 0
	var bodies: Array[Node] = []
	if root is BaselineHuman:
		bodies.append(root)
	for node in root.find_children("*", "", true, false):
		if node is BaselineHuman:
			bodies.append(node)
	var rimmed := 0
	for body in bodies:
		for node in body.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			if mesh.material_overlay == null:
				mesh.material_overlay = material()
				rimmed += 1
	return rimmed
