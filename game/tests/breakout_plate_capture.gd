extends Node

## Visual proof for the Phase 3 breakout plates: the seal inside the skull,
## the seal shrinking into the die, and the hacked die, laid under the rune
## the sequence draws.
## Run windowed: ... res://tests/breakout_plate_capture.tscn -- --out=DIR

const SHOTS := [
	["1_seal", 1.2],
	["2_seal_to_die", 2.9],
	["3_die", 4.0],
	["4_hacking", 5.1],
	["5_die_hacked", 5.9],
]


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	vat.set_physics_process(false)
	await get_tree().process_frame
	if vat.load_in != null:
		# It frees itself on `finished`; until then it is the last HUD child
		# and paints over the hack.
		var overlay: Control = vat.load_in
		overlay.skip()
		for _frame in 400:
			await get_tree().process_frame
			if not is_instance_valid(overlay):
				break
	vat.intake.filed.emit(vat.intake.sheet.apply_to_world())
	vat.phase = "departure"
	vat._update_departure(10.0)
	var hack = vat.brain_hack
	hack.set_process(false)
	var next := 0
	for _tick in 200:
		if next >= SHOTS.size():
			break
		hack.step(0.05)
		while next < SHOTS.size() and hack.clock >= float(SHOTS[next][1]):
			await _capture("%s/bp_%s.png" % [out_dir, SHOTS[next][0]])
			next += 1
	get_tree().quit(0 if next == SHOTS.size() else 1)


func _capture(path: String) -> void:
	for _frame in 2:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("CAPTURED: " if image.save_png(path) == OK else "CAPTURE_FAILED: ", path)
