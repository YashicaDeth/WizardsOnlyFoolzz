extends Node

## Greg: *"im really getting sick of the cars in the derby the fact you still
## cant shoot and the fact there no car hud for hull parts"*.
##
## Firing is bound and `dash_cluster.gd` does draw the remaining rounds — but a
## capture of the derby shows no dashboard, no wheel and no cluster at all, so
## whatever is drawn is drawn somewhere the player never looks. This reports the
## state the capture cannot: whether the cab was built, what layers its parts are
## on, and what the camera is actually allowed to see.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var tree := get_tree()
	await tree.process_frame
	var derby: Node = load("res://rift_derby.tscn").instantiate()
	tree.root.add_child(derby)
	tree.current_scene = derby
	for _settle in 120:
		await tree.process_frame

	var camera: Camera3D = derby.get("camera")
	var interior: Node3D = derby.get("interior")
	print("in_cab=%s round_state=%s rounds_left=%s" % [
		str(derby.get("in_cab")), str(derby.get("round_state")), str(derby.get("rounds_left")),
	])
	check(interior != null and is_instance_valid(interior), "the cab was built")
	if interior == null:
		tree.quit(1)
		return

	print("camera.cull_mask=%d (binary %s)" % [camera.cull_mask, String.num_int64(camera.cull_mask, 2)])
	print("camera.current=%s global=%s" % [str(camera.current), str(camera.global_position)])
	print("interior.global=%s visible=%s" % [str(interior.global_position), str(interior.visible)])

	# Every VisualInstance3D under the cab, and whether the camera can see it.
	var seen := 0
	var hidden := 0
	var offenders: Array[String] = []
	var stack: Array[Node] = [interior]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is VisualInstance3D:
			var layers := (node as VisualInstance3D).layers
			if (layers & camera.cull_mask) != 0:
				seen += 1
			else:
				hidden += 1
				if offenders.size() < 8:
					offenders.append("%s layers=%s" % [node.name, String.num_int64(layers, 2)])
		for child in node.get_children():
			stack.append(child)
	print("cab visuals the camera can see: %d, culled: %d" % [seen, hidden])
	for offender in offenders:
		print("   culled: ", offender)

	check(seen > 0, "the camera can see at least some of the cab it is sitting in")
	check(hidden == 0, "no part of the cab is culled away from the cab camera")

	# The regression this test was written for: the countdown branch returned
	# before `_update_camera()`, so the camera sat at the world origin for the
	# whole of it while the car was twenty-two metres away.
	var seat: Vector3 = interior.global_position
	check(camera.global_position.distance_to(seat) < 2.0,
		"the camera is in the cab during the countdown, not parked at the origin")

	var cluster_screen: Node = interior.get("cluster_screen")
	if cluster_screen != null and cluster_screen is VisualInstance3D:
		var face := cluster_screen as VisualInstance3D
		print("cluster face layers=%s visible=%s global=%s" % [
			String.num_int64(face.layers, 2), str(face.visible), str(face.global_position),
		])
		check((face.layers & camera.cull_mask) != 0, "the instrument cluster is on a layer the cab camera renders")
		# In front of the eye, not behind it: the readout is only a readout if it
		# is between the player and the windscreen.
		var to_face := face.global_position - camera.global_position
		var forward := -camera.global_transform.basis.z
		check(to_face.dot(forward) > 0.0, "the instrument cluster is in front of the camera, not behind it")
	else:
		check(false, "the interior has an instrument cluster face")

	# Running the HUD during the countdown means `_update_hud()`'s own mode line
	# now runs during it too, and it used to blank the objective back out on the
	# same frame the countdown set it.
	var mode: Label = derby.get("mode_label")
	print("mode_label visible=%s text=%s" % [str(mode.visible), mode.text])
	check(mode.visible and mode.text.contains("WRECKERS"),
		"the countdown still says what the objective is")

	if failures.is_empty():
		print("derby cab: fine")
		tree.quit(0)
	else:
		print("derby cab FAILURES: ", failures)
		tree.quit(1)
