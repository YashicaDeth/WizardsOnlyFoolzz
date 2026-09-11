extends SceneTree


func _init() -> void:
	var packed: PackedScene = load("res://bone_yard_hunt.tscn")
	if packed == null:
		push_error("Ashbloom scene did not load")
		quit(1)
		return
	var hunt := packed.instantiate()
	root.add_child(hunt)
	hunt.call("_toggle_panel", "tree")
	var archive: Control = hunt.get_node("HUD/CharacterArchive")
	var history: Node = root.get_node("WorldHistory")
	var mara: Dictionary = history.call("subject", "mara_voss")
	var subjects: Dictionary = history.call("all_subjects")
	if not archive.visible or subjects.size() < 9 or int(mara.get("elo", 0)) < 1000:
		push_error("Archive integration failed: visible=%s subjects=%d elo=%d" % [archive.visible, subjects.size(), int(mara.get("elo", 0))])
		quit(1)
		return
	print("ASHBLOOM_VALIDATION_OK subjects=%d selected=%s elo=%d" % [subjects.size(), archive.selected_id, int(mara.get("elo", 0))])
	quit(0)
