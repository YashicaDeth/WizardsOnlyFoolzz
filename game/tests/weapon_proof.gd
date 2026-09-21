extends Node

## Proof that an imported weapon model loads and renders in 4.7.2: one MIT
## sidearm on a stand, windowed capture. Mount surgery on the real arsenal
## waits for the binding to commit — this proves the asset pipeline, not the
## hand that will hold it.
##
## Run WINDOWED (see brutalism_capture for why), with --capture=<png>.

var failures: Array[String] = []


func check(c: bool, label: String) -> void:
	print("PASS " if c else "FAIL ", label)
	if not c:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var camera := Camera3D.new()
	camera.position = Vector3(0.7, 0.55, 1.1)
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.35, 0.0))
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0.0)
	sun.light_energy = 1.2
	add_child(sun)
	var stand := MeshInstance3D.new()
	var top := BoxMesh.new()
	top.size = Vector3(0.5, 0.04, 0.5)
	stand.mesh = top
	stand.position = Vector3(0.0, 0.0, 0.0)
	add_child(stand)

	var scene: PackedScene = load("res://art/weapons/fps_sidearm.glb")
	check(scene != null, "the imported sidearm loads as a scene")
	if scene == null:
		_report()
		return
	var gun := scene.instantiate() as Node3D
	check(gun != null, "and instantiates to a Node3D")
	add_child(gun)
	gun.position = Vector3(0.0, 0.12, 0.0)
	gun.rotation.y = -0.5
	var meshes := 0
	var stack: Array = [gun]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			meshes += 1
		for child in node.get_children():
			stack.append(child)
	check(meshes > 0, "carrying %d meshes, not an empty shell" % meshes)

	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			var path := argument.trim_prefix("--capture=")
			check(get_viewport().get_texture().get_image().save_png(path) == OK, "proof capture saved to %s" % path)
	_report()


func _report() -> void:
	print("WEAPON_PROOF_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
