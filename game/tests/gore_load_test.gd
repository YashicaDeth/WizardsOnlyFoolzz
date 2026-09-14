extends Node

## Greg: "gore sandbox is just mad laggy have a look."
##
## Measured at idle the sandbox runs at 124-153 fps, so the cost is not the room
## — it is what the room fills up with. This wrecks every body the way a player
## would and measures the same scene again, reporting the object count each
## time, because "it got slow" and "it grew four thousand nodes" are the same
## sentence and only one of them tells you what to fix.

func _count(scene: Node) -> Dictionary:
	var meshes := 0
	var lights := 0
	var bodies := 0
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			meshes += 1
		elif n is Light3D:
			lights += 1
		elif n is RigidBody3D:
			bodies += 1
		for c in n.get_children():
			stack.append(c)
	return {"meshes": meshes, "lights": lights, "rigid": bodies}


func _measure(tree: SceneTree, frames: int) -> float:
	var start := Time.get_ticks_usec()
	for _s in frames:
		await tree.process_frame
	var seconds := float(Time.get_ticks_usec() - start) / 1000000.0
	return float(frames) / maxf(0.0001, seconds)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var tree := get_tree()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	get_window().size = Vector2i(1920, 1080)
	await tree.process_frame

	var scene: Node = load("res://gore_demo.tscn").instantiate()
	tree.root.add_child(scene)
	tree.current_scene = scene
	for _w in 180:
		await tree.process_frame

	var before := _count(scene)
	var fps_idle := await _measure(tree, 150)
	print("IDLE        %7.1f fps   meshes %d  lights %d  rigid %d" % [
		fps_idle, before.meshes, before.lights, before.rigid])

	# Wreck everything, the way a player with a shotgun does.
	var bodies: Array = scene.get("bodies")
	var zones := ["head", "torso", "left_arm", "right_arm", "left_leg", "right_leg"]
	for pass_index in 4:
		for entry: Dictionary in bodies:
			var rig = entry["rig"]
			if rig == null or not is_instance_valid(rig):
				continue
			for z: String in zones:
				rig.hit(z, 55.0, 30.0, "ballistic", "", Vector3(0, 0.2, -1))
			await tree.process_frame
		for _settle in 20:
			await tree.process_frame

	var after := _count(scene)
	var fps_gore := await _measure(tree, 150)
	print("AFTER GORE  %7.1f fps   meshes %d  lights %d  rigid %d" % [
		fps_gore, after.meshes, after.lights, after.rigid])
	print("meshes +%d   frame cost %.2f ms -> %.2f ms   (%.2fx slower)" % [
		after.meshes - before.meshes,
		1000.0 / maxf(0.0001, fps_idle), 1000.0 / maxf(0.0001, fps_gore),
		fps_idle / maxf(0.0001, fps_gore)])
	print("gore load: measured")
	tree.quit(0)
