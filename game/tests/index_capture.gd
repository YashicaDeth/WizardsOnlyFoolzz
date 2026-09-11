extends Node

## Captures all three World Index pages so the rebuild can be looked at rather
## than described. Seeds the population directly for the same reason
## `wire_test.gd` does: loading the Hunt Grounds runs the whole Ashbloom
## generator, which is minutes of work for a panel that reads `WorldHistory`.

const WORLD_INDEX := preload("res://systems/world_index.gd")


func _seed() -> void:
	WorldHistory.register_subject("player", {
		"name": "THE HUNTER", "kind": "person", "role": "Unindexed survivor", "faction": "Unbound",
		"elo": 1000, "grudge": 0, "status": "awake", "memory": "The derby door opened into Limbo.",
		"anatomy": {"blood_type": "unresolved", "cybernetics": ["salvaged torque arm"]},
		"relations": {"nix_arden": {"kind": "bond", "strength": 12}, "mara_voss": {"kind": "grudge", "strength": 1}},
	})
	WorldHistory.register_subject("nix_arden", {
		"name": "Nix Arden", "kind": "person", "role": "Scrap medic", "faction": "Gate Lanterns", "faction_id": "gate_lanterns",
		"elo": 930, "bond": 12, "status": "waiting", "memory": "Kept a gate open for you.",
		"wounds": ["spore-burned right lung"],
		"anatomy": {"blood_type": "A-ASH", "cybernetics": ["copper lung bellows", "dose counter"]},
		"relations": {"player": {"kind": "saved", "strength": 22}, "moth_jerrow": {"kind": "ally", "strength": 35}},
	})
	WorldHistory.register_subject("gate_lanterns", {
		"name": "Gate Lanterns", "kind": "faction", "role": "Ascending counter-order", "threat": "LOW",
		"territory": "Waystations between the tunnels and the surface",
		"doctrine": "Carry a light for whoever comes after. A kept promise outlasts a kept grudge.",
	})
	WorldHistory.register_subject("mara_voss", {
		"name": "Mara Voss", "kind": "person", "role": "Bone Yard Captain", "faction": "Ashline Wreckers", "faction_id": "ashline_wreckers",
		"elo": 1180, "grudge": 41, "injury": "fractured left clavicle", "status": "active",
		"memory": "You put her into the wall on the second lap and she has not forgotten the sound.",
		"wounds": ["fractured left clavicle"],
		"anatomy": {"blood_type": "O-RUST", "cybernetics": ["jaw telemetry nail", "left clavicle rail"]},
		"relations": {"player": {"kind": "hunts", "strength": 8}, "ashline_wreckers": {"kind": "command", "strength": 72}, "rook_sable": {"kind": "grudge", "strength": 31}},
	})
	WorldHistory.register_subject("ashline_wreckers", {
		"name": "Ashline Wreckers", "kind": "faction", "role": "Road murder syndicate", "threat": "SEVERE",
		"territory": "Bone Yard / Burnt Highway",
		"doctrine": "Every machine is a coffin awaiting an owner. Rank is won by remembered impact.",
	})
	# Enough of one faction to show the pyramid with depth. With a single member
	# every tier below the crown reads VACANT, which is honest but makes a
	# working screen look broken.
	WorldHistory.register_subject("dray_kell", {
		"name": "Dray Kell", "kind": "person", "role": "Pit sergeant", "faction": "Ashline Wreckers", "faction_id": "ashline_wreckers",
		"elo": 1102, "grudge": 6, "status": "active", "memory": "Counts the heat out loud so nobody can argue with the number.",
		"wounds": ["crushed right hand"], "anatomy": {"blood_type": "O-RUST", "cybernetics": ["load-bearing spine cage"]},
		"relations": {"ashline_wreckers": {"kind": "command", "strength": 48}, "mara_voss": {"kind": "ally", "strength": 29}},
	})
	WorldHistory.register_subject("sook_pell", {
		"name": "Sook Pell", "kind": "person", "role": "Recruiter", "faction": "Ashline Wreckers", "faction_id": "ashline_wreckers",
		"elo": 902, "status": "roaming", "memory": "Signs people up at the gate before they know what the debt is.",
		"wounds": [], "anatomy": {"blood_type": "A-ASH", "cybernetics": ["ledger thumb"]},
		"relations": {"ashline_wreckers": {"kind": "command", "strength": 31}, "dray_kell": {"kind": "ally", "strength": 14}},
	})
	WorldHistory.register_subject("tam_orrery", {
		"name": "Tam Orrery", "kind": "person", "role": "Wrecker", "faction": "Ashline Wreckers", "faction_id": "ashline_wreckers",
		"elo": 988, "status": "active", "memory": "Third heat, still owes the entry fee.",
		"wounds": ["burst eardrum"], "anatomy": {"blood_type": "UNKNOWN", "cybernetics": []},
		"relations": {"sook_pell": {"kind": "known", "strength": 9}},
	})
	WorldHistory.register_subject("rook_sable", {
		"name": "Rook Sable", "kind": "person", "role": "Rail-gang adjudicator", "faction": "Black Mile", "faction_id": "black_mile",
		"elo": 1325, "grudge": 18, "status": "unlocated", "memory": "Paid three drivers to lose the same race.",
		"wounds": ["missing left eye"],
		"anatomy": {"blood_type": "B-9", "cybernetics": ["rangefinder eye", "ceramic sternum"]},
		"relations": {"iris_coil": {"kind": "command", "strength": 61}},
	})
	WorldHistory.register_subject("black_mile", {
		"name": "Black Mile", "kind": "faction", "role": "Toll cartel", "threat": "HIGH",
		"territory": "The cut between the quarry and the salt",
		"doctrine": "Everything that moves owes. Collection is a service we provide to ourselves.",
	})
	WorldHistory.register_subject("iris_coil", {
		"name": "Iris Coil", "kind": "person", "role": "Sporeline scout", "faction": "Black Mile", "faction_id": "black_mile",
		"elo": 1096, "status": "roaming", "memory": "Photographed the fungus moving against the wind.",
		"wounds": ["glass scars"], "anatomy": {"blood_type": "AB-", "cybernetics": ["optic spool", "ankle compass"]},
		"relations": {"rook_sable": {"kind": "bond", "strength": 17}},
	})
	WorldHistory.register_subject("moth_jerrow", {
		"name": "Moth Jerrow", "kind": "person", "role": "Fungus shepherd", "faction": "Soft Rot Communion", "faction_id": "soft_rot",
		"elo": 1004, "status": "cultivating", "memory": "Claims the great caps remember rain from before the flash.",
		"wounds": ["mycelial graft"], "anatomy": {"blood_type": "SAP", "cybernetics": ["filter trachea"]},
		"relations": {"nix_arden": {"kind": "ally", "strength": 35}, "vale_nine": {"kind": "bond", "strength": 13}},
	})
	WorldHistory.register_subject("vale_nine", {
		"name": "Vale Nine", "kind": "person", "role": "Storm stalker", "faction": "None",
		"elo": 1244, "grudge": 7, "status": "following", "memory": "Leaves clean footprints through radioactive mud.",
		"wounds": ["thoracic puncture", "burned fingertips"],
		"anatomy": {"blood_type": "UNKNOWN", "cybernetics": ["quiet-heart regulator", "heel anchors"]},
		"relations": {"moth_jerrow": {"kind": "bond", "strength": 13}},
	})
	WorldHistory.record_event("derby_round_won", {"subject": "player", "rival": "mara_voss"})
	WorldHistory.record_event("rival_injured", {"subject": "mara_voss", "zone": "left clavicle"})
	WorldHistory.record_event("wire_expose", {"subject": "rook_sable"})
	WorldHistory.record_event("derby_session_started", {"subject": "player"})


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	WorldHistory.clear_history()
	_seed()
	var layer := CanvasLayer.new()
	add_child(layer)
	var index: Control = WORLD_INDEX.new()
	layer.add_child(index)
	index.open()
	# The fourth pass is the pyramid again with the X-ray on, because the skull
	# state is the half of the icon that cannot be reviewed from the flesh shot.
	var pages := ["file", "pyramid", "wire", "pyramid_xray", "body", "body_organ"]
	for page_index in pages.size():
		index.page = [0, 1, 2, 1, 3, 3][page_index]
		index.rail_index = [3, 0, 0, 0, 3, 2][page_index]
		index.xray = page_index == 3
		for icon in index._icons:
			icon.set_xray(index.xray)
		index._rebuild_rail()
		if page_index == 5:
			# Mara Voss with the heart pulled out: the case the whole page is for.
			index._inspector.set_subject(WorldHistory.subject("mara_voss"))
			index._inspector.part_index = 2
			index._inspector._begin_lift()
		index.queue_redraw()
		for _settle in 60:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := "%s/index_%s.png" % [out_dir, pages[page_index]]
		if image.save_png(path) != OK:
			print("CAPTURE_FAILED ", path)
			get_tree().quit(1)
			return
		print("CAPTURED: ", path, " ", image.get_width(), "x", image.get_height())
	get_tree().quit()
