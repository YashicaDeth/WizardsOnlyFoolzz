extends Node

## Visual check for the transit plate after the green-to-blood pass: the seal,
## the runnels and the readout, held open rather than travelling so the plate
## can be photographed without a scene swap underneath it.

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	Interstitial.hold_open("walking out into the ashbloom expanse")
	Interstitial.destination = "res://bone_yard_hunt.tscn"
	Interstitial._seal_seed = hash("res://bone_yard_hunt.tscn")
	Interstitial.progress = 0.62
	for _tick in 90:
		await get_tree().process_frame
	Interstitial.progress = 0.62
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/interstitial_plate.png" % out_dir)

	# A second destination, to prove the seal is the door's and not the screen's.
	Interstitial._seal_seed = hash("res://vat_chamber.tscn")
	Interstitial.caption = "DECANTING FLOOR"
	for _tick in 30:
		await get_tree().process_frame
	Interstitial.progress = 0.24
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/interstitial_plate_b.png" % out_dir)
	print("CAPTURE_DONE")
	get_tree().quit()
