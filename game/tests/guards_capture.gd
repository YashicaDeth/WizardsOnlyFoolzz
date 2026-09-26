extends Node

## Visual proof for the two guards: Hollis (the Support Unit's last gate)
## and the numbered guard at the Service Arcade door, front and back.
## Run windowed: ... res://tests/guards_capture.tscn -- --out=DIR

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	var environment := WorldEnvironment.new()
	environment.environment = WorldLook.environment("lower_works")
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.6, 0.5, 0)
	key.light_energy = 1.6
	add_child(key)
	var hollis := FacilityGuardPost.new()
	add_child(hollis)
	hollis.build()
	hollis.position = Vector3(-1.4 - FacilityGuardPost.GUARD_AT.x, 0, -FacilityGuardPost.GUARD_AT.z)
	var numbered := FacilityGuardPost.new()
	numbered.as_arcade_guard()
	add_child(numbered)
	numbered.build()
	numbered.position = Vector3(1.4 - FacilityGuardPost.GUARD_AT.x, 0, -FacilityGuardPost.GUARD_AT.z)
	for post in [hollis, numbered]:
		for child in post.get_children():
			if child != post.guard:
				child.visible = false
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 1.25, 2.9)
	camera.look_at(Vector3(0, 1.05, 0), Vector3.UP)
	camera.current = true
	for _frame in 10:
		await get_tree().process_frame
	await _capture("%s/guards_front.png" % out_dir)
	for post in [hollis, numbered]:
		post.guard.rotation.y = 0.0
	for _frame in 4:
		await get_tree().process_frame
	await _capture("%s/guards_back.png" % out_dir)
	get_tree().quit()


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	print("CAPTURED: " if get_viewport().get_texture().get_image().save_png(path) == OK else "CAPTURE_FAILED: ", path)
