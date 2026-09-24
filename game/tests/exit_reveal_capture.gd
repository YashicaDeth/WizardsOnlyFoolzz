extends Node

## Visual proof for the arrival reveal (systems/exit_reveal.gd) in the real
## Hunt: for two exits, three moments each -- on the exit point, over the
## first settlement as it is marked, and pulled up over everything it showed.
## Run windowed: ... res://tests/exit_reveal_capture.tscn -- --out=DIR

const EXITS := [
	["outfall", "maintenance_ascent", ["waste_gallery", "maintenance_cistern", "storm_outfall"]],
	["lift", "heat_elevator_ascent", ["heat_elevator"]],
	["shaft", "executive_breach", ["containment_concourse", "executive_transit", "blast_shaft"]],
]
const ASSAULT_POINTS := ["concourse", "transit", "shaft"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	for exit in EXITS:
		WorldHistory.clear_history()
		WorldHistory.world_minute = 14.0 * 60.0
		FacilityRoutes.begin(str(exit[1]))
		for index in (exit[2] as Array).size():
			if str(exit[1]) == FacilityRoutes.ROUTE_ASSAULT:
				FacilityRoutes.record_assault_breakthrough(ASSAULT_POINTS[index], "capture")
			FacilityRoutes.traverse(str(exit[2][index]))
		var hunt = load("res://bone_yard_hunt.tscn").instantiate()
		add_child(hunt)
		var reveal: ExitReveal = hunt.exit_reveal
		if reveal == null:
			print("CAPTURE_FAILED: no reveal for ", exit[0])
			continue
		# Driven by hand here, so a slow software renderer cannot move it on
		# between setting a moment and capturing it.
		reveal.set_process(false)
		await _hold(4)
		print("REVEAL %s: exit %s at %s, starts at %s, settlements %s, duration %.1f, hour %.1f" % [exit[0], reveal.exit_name, str(reveal.exit_at), str(reveal.keys[0][1]), str(reveal.settlements.map(func(r): return r.id)), reveal.duration, WorldHistory.world_minute / 60.0])
		var first_key := float(reveal.settlements[0].key_time)
		var moments := [["a_exit", 0.5], ["b_first_settlement", first_key - 0.2], ["c_overview", reveal.duration - ExitReveal.HAND_BACK - 0.1]]
		for moment in moments:
			while reveal.active and reveal.clock < float(moment[1]):
				reveal.advance(1.0 / 30.0)
			await _hold(6)
			await _capture("%s/reveal_%s_%s.png" % [out_dir, str(exit[0]), str(moment[0])])
		reveal.finish(false)
		hunt.queue_free()
		await _hold(3)
	get_tree().quit()


func _hold(frames: int) -> void:
	for _frame in frames:
		await get_tree().process_frame


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("CAPTURED: " if image.save_png(path) == OK else "CAPTURE_FAILED: ", path)
