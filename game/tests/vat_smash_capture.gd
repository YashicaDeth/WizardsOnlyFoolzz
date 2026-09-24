extends Node

## A Growing Floor tank smashed open: glass gone, medium drained into a spill,
## and the freed subject standing in it. Run: ... -- --out=DIR

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	WorldHistory.world_minute = WorldClock.OPENING_MINUTE
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	vat.set_physics_process(false)
	await _hold(3)
	vat.intake._finish_filing()
	await _hold(2)
	vat._breach()
	vat.phase = "aisle"
	vat.can_move = true
	vat.fade.color.a = 0.0
	var smash = vat.vat_smash
	var tank: Dictionary = smash.tanks[3]
	var at: Vector3 = tank.at
	var eye := Camera3D.new()
	add_child(eye)
	eye.fov = 68.0
	eye.current = true
	vat.player.visible = false
	for child in vat.get_children():
		if child is Node3D and (child as Node3D).global_position.distance_to(vat.VAT_POSITION) < 0.8 and child.name.contains("Rig"):
			(child as Node3D).visible = false
	eye.global_position = at + Vector3(-signf(at.x) * 3.0, 1.5, 0.0)
	eye.look_at(at + Vector3(0, 1.0, 0), Vector3.UP)
	print("TANK ", at, " seed ", tank.seed)
	smash.strike(3, "")
	await _hold(6)
	await _capture("%s/vat_cracked.png" % out_dir)
	for _blow in 3:
		smash.strike(3, "")
	for _step in 3:
		smash.step(0.1)
		vat._update_shards(0.1)
	await _hold(3)
	await _capture("%s/vat_breaking.png" % out_dir)
	for _step in 8:
		smash.step(0.1)
		vat._update_shards(0.1)
	await _hold(4)
	await _capture("%s/vat_climbing_out.png" % out_dir)
	for _step in 22:
		smash.step(0.1)
		vat._update_shards(0.1)
	await _hold(6)
	await _capture("%s/vat_freed.png" % out_dir)
	print("BROKEN ", tank.broken, " freed ", tank.freed != null, " level ", (tank.medium as Node3D).scale.y)
	get_tree().quit()


func _hold(frames: int) -> void:
	for _frame in frames:
		await get_tree().process_frame


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	print("CAPTURED: " if get_viewport().get_texture().get_image().save_png(path) == OK else "CAPTURE_FAILED: ", path)
