extends Node

## Visual proof for the production wizard-eyes view in the Growing Floor and
## Support Unit. Run only through AgentHub/render_one.cmd:
##   render_one.cmd wizard_eyes_capture --out=P:/GameDev/Temp/fix57_before

var out_dir := "P:/GameDev/Temp/fix57_wizard_eyes"


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	await _capture_growing_floor()
	await _capture_support_unit()
	get_tree().quit()


func _capture_growing_floor() -> void:
	var vat = load("res://vat_chamber.tscn").instantiate()
	vat.hands_on_breakout = false
	add_child(vat)
	await _frames(30)
	vat.get_node("HUD").visible = false
	if vat.intake != null:
		vat.intake.visible = false
	var spirit: Vector3 = vat.sight.spirits[0]
	var camera := _capture_camera(vat, spirit + Vector3(3.6, 1.6, -4.2), spirit + Vector3(0, 0.85, 0))
	vat.sight.view = camera
	vat.sight.enabled = true
	vat.sight.toggle_wizard()
	vat.sight.clock = 1.35
	await _frames(20)
	await _shot("wizard_eyes_growing_floor")
	vat.queue_free()
	await _frames(3)


func _capture_support_unit() -> void:
	var unit = load("res://support_unit.tscn").instantiate()
	add_child(unit)
	await _frames(20)
	var hud := unit.get_node_or_null("HUD") as CanvasItem
	if hud != null:
		hud.visible = false
	# Default route state may have no player remains yet. Put one capture-only
	# spirit in the live corridor so the same renderer can be judged here.
	var spirit := Vector3(0, 0, 5.0)
	unit.sight.spirits = [spirit]
	var camera := _capture_camera(unit, Vector3(2.8, 1.65, -1.5), spirit + Vector3(0, 0.85, 0))
	unit.sight.view = camera
	unit.sight.toggle_wizard()
	unit.sight.clock = 1.35
	await _frames(20)
	await _shot("wizard_eyes_support_unit")
	unit.queue_free()
	await _frames(3)


func _capture_camera(host: Node3D, at: Vector3, target: Vector3) -> Camera3D:
	var camera := Camera3D.new()
	host.add_child(camera)
	camera.global_position = at
	camera.look_at(target, Vector3.UP)
	camera.fov = 68.0
	camera.current = true
	return camera


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [out_dir, name]
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURED: " if error == OK else "CAPTURE_FAILED: ", path)
