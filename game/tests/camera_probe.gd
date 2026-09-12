extends Node

## Which camera is actually rendering? Two captures from the real hunt scene
## have come back near-black, and the first was written off as the ashbloom sky
## being dark by design. Before that explanation is trusted twice, check the
## simplest thing that would produce the same picture: rendering from a camera
## that is not the player's.

func _ready() -> void:
	var hunt: Node = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	for _settle in 90:
		await get_tree().process_frame
	var viewport := get_viewport()
	var active := viewport.get_camera_3d()
	var hunt_camera: Camera3D = hunt.get_node_or_null("CameraRig/Camera3D")
	print("ACTIVE camera path : ", active.get_path() if active != null else "<none>")
	print("HUNT   camera path : ", hunt_camera.get_path() if hunt_camera != null else "<none>")
	print("SAME               : ", active == hunt_camera)
	if hunt_camera != null:
		print("hunt cam current   : ", hunt_camera.current, "  pos=", hunt_camera.global_position)
	if active != null:
		print("active cam pos     : ", active.global_position)
	var cameras := 0
	for node in get_tree().get_nodes_in_group("__cameras__"):
		cameras += 1
	print("cameras in tree    : ", _count_cameras(hunt) + _count_cameras(self))
	get_tree().quit()


func _count_cameras(node: Node) -> int:
	var total := 1 if node is Camera3D else 0
	for child in node.get_children():
		total += _count_cameras(child)
	return total
