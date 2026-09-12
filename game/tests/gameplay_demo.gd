extends Node

## A gameplay pass, captured. Not a feature screenshot — this drives the Hunt
## Grounds through a run of real beats and photographs what the player would be
## looking at: walking, the weapon in hand, a fight, the handheld, the chart, the
## Board, and the derby cab.

var shots: Array = []
var out_dir := "P:/GameDev/Temp/demo"


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	var tree := get_tree()
	await tree.process_frame

	var hunt: Node = load("res://bone_yard_hunt.tscn").instantiate()
	tree.root.add_child(hunt)
	tree.current_scene = hunt
	for _settle in 110:
		await tree.process_frame

	# ---- 01. Standing in it. The Ashbloom, first person, weapon in hand.
	await _shoot(tree, "01_first_person", "standing in the Ashbloom")

	# ---- 02. Moving, with the arm actually being thrown by the look.
	for step in 50:
		hunt.call("apply_look", Vector2(0.020, 0.0))
		hunt.get("player_body").velocity = Vector3(0, 0, -4.2)
		await tree.physics_frame
	await _shoot(tree, "02_moving", "turning while moving, the weapon lagging the hand")

	# ---- 03. A swing. Committed, so the arm is worth something.
	for step in 14:
		hunt.call("apply_look", Vector2(0.085, 0.0))
		await tree.physics_frame
	var arm = hunt.get("arm")
	print("   commitment on that swing: %.2f" % (arm.commitment() if arm else 0.0))
	hunt.call("_attack", true)
	for _frame in 5:
		await tree.physics_frame
	await _shoot(tree, "03_swing", "mid-swing, heavy")

	# ---- 04. The blood that ends up on you.
	var veil = hunt.get("blood_veil")
	if veil != null:
		for index in 4:
			veil.call("splash", 0.85, Vector2(cos(index * 1.7), sin(index * 1.7)))
			for _gap in 4:
				await tree.process_frame
	await _shoot(tree, "04_wearing_it", "blood on the lens after close work")

	# ---- 05. The handheld, raised.
	hunt.call("_toggle_handheld") if hunt.has_method("_toggle_handheld") else hunt.call("_toggle_panel", "index")
	for _settle in 40:
		await tree.process_frame
	await _shoot(tree, "05_handheld", "the black mirror, raised")

	# ---- 06. The chart, with the satellite under it.
	hunt.call("_toggle_panel", "map")
	for _settle in 40:
		await tree.process_frame
	await _shoot(tree, "06_map", "the living map over the satellite")

	# ---- 07. The Board.
	hunt.call("_toggle_panel", "board")
	for _settle in 40:
		await tree.process_frame
	await _shoot(tree, "07_board", "the conspiracy wall")

	# ---- 08. The derby cab, which is a different scene entirely.
	hunt.queue_free()
	await tree.process_frame
	var derby: Node = load("res://rift_derby.tscn").instantiate()
	tree.root.add_child(derby)
	tree.current_scene = derby
	for _settle in 90:
		await tree.physics_frame
	derby.set("round_state", "active")
	derby.set("integrity", 62)
	derby.call("_update_hud")
	for _settle in 20:
		await tree.process_frame
	await _shoot(tree, "08_derby_cab", "in the cab, instruments on the dash")

	print("\n%d frames in %s" % [shots.size(), out_dir])
	for line in shots:
		print("  ", line)
	tree.quit(0)


func _shoot(tree: SceneTree, name: String, caption: String) -> void:
	for _frame in 3:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, name]
	var ok := image.save_png(path) == OK
	shots.append("%s  %s" % [name, caption if ok else "FAILED"])
	print("shot %s — %s" % [name, caption])
