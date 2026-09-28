extends Node

## Renders the blood popup and the tree view in the real Hunt.
##   Godot --rendering-driver opengl3 --path game res://tests/blood_ledger_capture.tscn -- --out=DIR
## Writes DIR/blood_popup.png and DIR/blood_tree.png.


func _ready() -> void:
	var out_dir := "user://blood_capture"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	for _index in 90:
		WorldHistory.world_minute = WorldClock.OPENING_MINUTE
		await get_tree().process_frame
	var ledger: BloodLedger = hunt.blood_ledger
	ledger.readout.lines.clear()
	# A real swing on a real body in front of the hunter.
	hunt.yaw = 0.0
	hunt.pitch = 0.0
	var at: Vector3 = hunt.player + Vector3(0, -0.5, 2.2)
	hunt._spawn_encounter_actor({"instance_id": "capture_mark", "kind": "hostile"}, at)
	var actor: Dictionary = hunt.encounter_actors.back()
	actor.node.position = at
	await get_tree().process_frame
	hunt._equip_weapon(0)
	hunt.player_unseen = false
	var swing: Dictionary = hunt.arsenal.begin_attack()
	swing["range"] = 9.0
	var landed: bool = hunt._attack_nearest_encounter_actor(swing)
	hunt._kill_encounter_actor(hunt.encounter_actors.find(actor), "capture")
	ledger.credit("sidearm", 6, "hit")
	for _index in 14:
		WorldHistory.world_minute = WorldClock.OPENING_MINUTE
		await get_tree().process_frame
	print("BLOOD_CAPTURE popup landed=%s lines=%d first=%s" % [landed, ledger.readout.active_count(), ledger.readout.text_of(0)])
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("blood_popup.png"))

	# A spread of earned blood across the four styles, two nodes open.
	ledger.credit("sword", 60, "finisher")
	ledger.credit("breach_tool", 77, "record")
	ledger.credit("sidearm", 30, "kill")
	ledger.credit("shotgun", 14, "hit")
	ledger.credit("grapple", 15, "takedown")
	ledger.credit("unseen", 9, "hit")
	ledger.unlock("first_cut")
	ledger.unlock("steady_hand")
	ledger.readout.lines.clear()
	ledger.toggle_tree()
	ledger.tree_view.move(0, 1)
	for _index in 6:
		WorldHistory.world_minute = WorldClock.OPENING_MINUTE
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("blood_tree.png"))
	print("BLOOD_CAPTURE written to ", out_dir)
	get_tree().quit(0)
