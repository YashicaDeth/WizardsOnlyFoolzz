extends Node

## L1 verification. The Board has to be looked at, not asserted about: the whole
## claim is that it reads as a wall somebody made rather than as a screen.

const BOARD := preload("res://systems/pin_board.gd")


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person", "role": "Unindexed survivor"})
	WorldHistory.register_subject("mara_voss", {
		"name": "Mara Voss", "kind": "person", "role": "Bone Yard Captain",
		"faction_id": "ashline_wreckers", "status": "active", "injury": "fractured left clavicle",
	})
	WorldHistory.register_subject("dolan_kreeg", {"name": "Dolan Kreeg", "kind": "person", "role": "Choir surgeon", "status": "executed"})
	WorldHistory.register_subject("sil_fenmark", {"name": "Sil Fenmark", "kind": "person", "role": "Signal runner", "status": "active"})
	WorldHistory.register_subject("ashline_wreckers", {"name": "Ashline Wreckers", "kind": "faction", "doctrine": "Rank is won by remembered impact"})
	WorldHistory.register_subject("choir_of_marrow", {"name": "Choir of Marrow", "kind": "faction", "doctrine": "The body is a congregation"})
	WorldHistory.register_subject("celloutz", {"name": "CellOutz", "kind": "faction", "doctrine": "Ownership, downward"})
	WorldHistory.record_event("derby_round_won", {"subject": "player", "rival": "mara_voss"})
	WorldHistory.record_event("rival_injured", {"subject": "mara_voss", "zone": "left clavicle"})
	WorldHistory.record_event("execution", {"subject": "dolan_kreeg"})
	WorldHistory.record_event("carried_part", {"subject": "mara_voss", "part": "HEART"})
	WorldHistory.record_event("signal_lost", {"subject": "sil_fenmark"})

	var layer := CanvasLayer.new()
	add_child(layer)
	var board: Control = BOARD.new()
	layer.add_child(board)
	board.open()
	# L2. The wall is the player's doing now, so the capture has to do what a
	# player would: take things off the other screens and put them up.
	for entry in [
		["mara_voss", "photo"], ["dolan_kreeg", "photo"], ["sil_fenmark", "photo"],
		["ashline_wreckers", "record"], ["choir_of_marrow", "record"], ["celloutz", "record"],
		["event:0", "cutting"], ["event:2", "cutting"], ["event:3", "cutting"],
		["part:HEART@mara_voss", "cutting"],
	]:
		board.pin(str(entry[0]), str(entry[1]))
	# L3. And strings the player drew. Two of these the world bears out and two
	# it does not, and the wall says nothing about which is which.
	for link in [
		["part:HEART@mara_voss", "theory_ownership"],
		["mara_voss", "ashline_wreckers"],
		["dolan_kreeg", "choir_of_marrow"],
		["event:2", "theory_absent_god"],
		["celloutz", "theory_inside"],
		["sil_fenmark", "theory_frequency"],
		["player", "theory_absent_god"],
		["player", "theory_inside"],
		["mara_voss", "theory_rotation"],
	]:
		board.lay_string(str(link[0]), str(link[1]))
	# L4. One of these went out on the Wire. The stamp says it was published,
	# never whether it held.
	board.publish("theory_ownership")

	for shot in [{"zoom": 1.0, "pan": Vector2.ZERO, "name": "board"}, {"zoom": 1.9, "pan": Vector2(240, 120), "name": "board_close"}]:
		board.zoom = float(shot["zoom"])
		board.pan = shot["pan"]
		for _settle in 40:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s.png" % [out_dir, str(shot["name"])]
		if get_viewport().get_texture().get_image().save_png(path) != OK:
			print("CAPTURE_FAILED ", path)
			get_tree().quit(1)
			return
		print("CAPTURED: ", path)
	get_tree().quit()
