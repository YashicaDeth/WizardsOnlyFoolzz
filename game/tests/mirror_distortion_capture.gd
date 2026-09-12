extends Node

## D7.4 v2. The mirror's wobble compared across two very different bodies -
## a plated Roadborn (should barely move) and a hollow-skeleton Unreset
## (should swim).

const VAT_INTAKE := preload("res://systems/vat_intake.gd")


func _shot(out_dir: String, name: String) -> void:
	for _settle in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [out_dir, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURED: ", path)


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	WorldHistory.clear_history()
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	var layer := CanvasLayer.new()
	add_child(layer)
	var intake: Control = VAT_INTAKE.new()
	layer.add_child(intake)
	intake.page = 3

	intake.sheet.race = "roadborn"
	intake.sheet.under_skin["skeleton"] = "plated"
	await _shot(out_dir, "mirror_plated_roadborn")

	intake.sheet.race = "unreset"
	intake.sheet.under_skin["skeleton"] = "hollow"
	await _shot(out_dir, "mirror_hollow_unreset")

	get_tree().quit()
