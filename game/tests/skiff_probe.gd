extends Node3D

## Greg: "fix the car models so the wheels are on the ground not touching the
## body or dragging". The car's visual is an authored .glb parented to a raycast
## suspension body, so the two have to agree about where the ground is — and
## nothing in the code says where the model thinks its wheels are. Measure it.

const SKIFF := preload("res://art/scrap_skiff.glb")
const VEHICLE := preload("res://systems/arcade_vehicle.gd")

func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var skiff := SKIFF.instantiate()
	add_child(skiff)
	await get_tree().process_frame
	print("--- every mesh in scrap_skiff.glb (local to the skiff root) ---")
	var overall := AABB()
	var first := true
	var wheels: Array = []
	_walk(skiff, skiff, func(node: MeshInstance3D, box: AABB) -> void:
		if first:
			overall = box
			first = false
		else:
			overall = overall.merge(box)
		var n := node.name.to_lower()
		if n.contains("wheel") or n.contains("tyre") or n.contains("tire"):
			wheels.append({"name": node.name, "box": box})
		print("  %-28s pos %-30s size %-26s y %.3f..%.3f" % [
			node.name, str(box.position.snapped(Vector3.ONE * 0.001)),
			str(box.size.snapped(Vector3.ONE * 0.001)), box.position.y, box.end.y]))

	print("")
	print("MODEL BOUNDS  y %.3f .. %.3f   (height %.3f)" % [overall.position.y, overall.end.y, overall.size.y])
	print("MODEL BOUNDS  x %.3f .. %.3f   z %.3f .. %.3f" % [overall.position.x, overall.end.x, overall.position.z, overall.end.z])
	if wheels.is_empty():
		print("NO node named wheel/tyre/tire — the wheels are not separate parts in this model")
	else:
		var lowest := 9999.0
		for w in wheels:
			lowest = minf(lowest, (w["box"] as AABB).position.y)
			print("WHEEL %-22s y %.3f..%.3f  radius~%.3f" % [w["name"], (w["box"] as AABB).position.y, (w["box"] as AABB).end.y, (w["box"] as AABB).size.y * 0.5])
		print("LOWEST WHEEL POINT y = %.3f" % lowest)

	print("")
	print("--- what the physics believes ---")
	print("WHEEL_ANCHORS y      = %.3f" % (VEHICLE.WHEEL_ANCHORS[0] as Vector3).y)
	print("WHEEL_RADIUS         = %.3f" % VEHICLE.WHEEL_RADIUS)
	print("SUSPENSION_REST      = %.3f" % VEHICLE.SUSPENSION_REST)
	var reach: float = VEHICLE.SUSPENSION_REST + VEHICLE.WHEEL_RADIUS
	print("ray reach            = %.3f  (ground at body y %.3f when fully extended)" % [reach, (VEHICLE.WHEEL_ANCHORS[0] as Vector3).y - reach])
	print("anchor - radius      = %.3f  (where a wheel bottom sits if drawn at the anchor)" % ((VEHICLE.WHEEL_ANCHORS[0] as Vector3).y - VEHICLE.WHEEL_RADIUS))
	print("SKIFF_PROBE_RESULT done")
	get_tree().quit(0)

func _walk(node: Node, root: Node3D, fn: Callable) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			var box := mi.mesh.get_aabb()
			var xf := root.global_transform.affine_inverse() * mi.global_transform
			fn.call(mi, xf * box)
	for c in node.get_children():
		_walk(c, root, fn)
