extends Node

## The examiner leaving by his own door behind the vat, seen from the aisle
## (the player in the tank faces away from it; this camera does not).

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	await get_tree().process_frame
	vat.intake._finish_filing()
	var eye := Camera3D.new()
	vat.add_child(eye)
	eye.global_position = Vector3(5.2, 1.9, -0.4)
	eye.look_at(DoctorRoute.DOOR_AT + Vector3(0, 1.1, -0.6))
	eye.fov = 70.0
	eye.current = true
	vat.get_node("HUD").visible = false
	for moment in [[1.6, "examiner_exit_walking"], [3.05, "examiner_exit_door"]]:
		while vat.departure_clock < float(moment[0]):
			vat._update_departure(1.0 / 30.0)
		for _frame in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, moment[1]])
	get_tree().quit()
