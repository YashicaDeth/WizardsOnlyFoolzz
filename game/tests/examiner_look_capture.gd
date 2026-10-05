extends Node

## Greg, 5 Oct: the examiner on the stylised rigged base, not the generated
## skin. Shoots him on the intake feed, at his terminal behind the glass, and
## at his bench in his office.
## Run windowed: render_one.cmd examiner_look_capture --out=DIR

var out_dir := "P:/GameDev/Temp"


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	var vat = load("res://vat_chamber.tscn").instantiate()
	vat.hands_on_breakout = false
	add_child(vat)
	await get_tree().process_frame
	if vat.load_in != null:
		vat.load_in.skip()
	for _frame in 30:
		await get_tree().process_frame
	await _capture("examiner_1_intake_feed")

	vat.intake._finish_filing()
	vat.get_node("HUD").visible = false
	var eye := Camera3D.new()
	vat.add_child(eye)
	var face: Vector3 = vat.examiner_node.global_position + Vector3(0, 1.75, 0)
	var front: Vector3 = vat.examiner_node.global_transform.basis.z
	eye.global_position = face + front * 1.6 + Vector3(0.3, -0.15, 0)
	eye.look_at(face - Vector3(0, 0.35, 0))
	eye.fov = 55.0
	eye.current = true
	for _frame in 20:
		await get_tree().process_frame
	await _capture("examiner_2_at_the_glass")

	var fight = vat.doctor_route.fight
	var body: Node3D = fight.body
	var at: Vector3 = body.global_position
	var facing: Vector3 = -body.global_transform.basis.z
	eye.global_position = at + facing * 2.0 + Vector3(0.4, 1.5, 0)
	eye.look_at(at + Vector3(0, 1.1, 0))
	for _frame in 20:
		await get_tree().process_frame
	await _capture("examiner_3_office")
	get_tree().quit()


func _capture(shot: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [out_dir, shot]
	print("CAPTURED: " if get_viewport().get_texture().get_image().save_png(path) == OK else "CAPTURE_FAILED: ", path)
