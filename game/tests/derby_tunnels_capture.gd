extends Node

## Visual proof for the derby tunnels: the driver's view at the gate, in the
## gate bore, the sump hall, the long bore, and the drain mouth.
## Run windowed: ... res://tests/derby_tunnels_capture.tscn -- --out=DIR

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	var tunnels = load("res://derby_tunnels.tscn").instantiate()
	add_child(tunnels)
	for _frame in 200:
		await get_tree().physics_frame
	var line: Array[Vector3] = tunnels.drive_line
	var shots := {"gate": 4, "gate_bore": 30, "sump_hall": 75, "long_bore": 130, "outfall_bore": line.size() - 20}
	for shot in shots:
		var index: int = shots[shot]
		var at: Vector3 = line[index]
		var ahead: Vector3 = line[mini(index + 3, line.size() - 1)]
		tunnels.car.recover(at + Vector3.UP * 1.0, Basis.looking_at((ahead - at).slide(Vector3.UP).normalized(), Vector3.UP))
		for _frame in 90:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := "%s/tunnels_%s.png" % [out_dir, shot]
		image.save_png(path)
		var sum := 0.0
		var count := 0
		for y in range(0, image.get_height(), 8):
			for x in range(0, image.get_width(), 8):
				sum += image.get_pixel(x, y).get_luminance()
				count += 1
		print("CAPTURED: %s mean luminance %.1f/255" % [path, sum / count * 255.0])
	get_tree().quit()
