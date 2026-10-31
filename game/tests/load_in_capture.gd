extends Node
## The load-in at set moments: a broadcast pass, a flash, the face frame.

func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	var load_in = TortureLoadIn.new()
	add_child(load_in)
	load_in.set_process(false)
	for shot in [[4.7, "loadin_1_lamp"], [6.2, "loadin_2_opened"], [8.15, "loadin_3_vitals_jolt"], [9.5, "loadin_4_spirits"], [3.9, "loadin_5_whisper"], [8.67, "loadin_6_face"]]:
		load_in.clock = float(shot[0])
		load_in.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("P:/GameDev/Temp/lighting/%s.png" % shot[1])
	get_tree().quit()
