extends Node

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var colosseum := (load("res://underground_colosseum.tscn") as PackedScene).instantiate()
	add_child(colosseum)
	await get_tree().physics_frame
	check(colosseum.gore_festival != null, "the underground heat has a physical festival press")
	check(colosseum.festival_victim.visible, "the press begins with a whole human silhouette")
	check(not colosseum.festival_slabs.visible, "the result is not displayed before the press closes")
	colosseum._update_gore_festival(2.3)
	check(not colosseum.festival_victim.visible, "the body is consumed by the press")
	check(colosseum.festival_slabs.visible, "the press produces genuine visible slabs")
	var numbered_slabs: Array = colosseum.festival_slabs.get_children().filter(func(child: Node): return child.name.begins_with("LOT_0C7_"))
	check(numbered_slabs.size() == 3, "the result is three numbered pieces, not a blood decal")
	check(colosseum.festival_slabs.get_node_or_null("Bone_00") != null, "pressed anatomy remains visible in the slab face")
	colosseum._update_gore_festival(2.2)
	check(colosseum.festival_completed, "the festival completes inside the existing pre-heat countdown")
	check(WorldHistory.event_count("gore_festival_witnessed") == 1, "witnessing the festival enters the world record once")
	colosseum._update_gore_festival(1.0)
	check(WorldHistory.event_count("gore_festival_witnessed") == 1, "the completed spectacle cannot spam the ledger")
	colosseum.queue_free()
	await get_tree().process_frame

	var surface_derby := (load("res://rift_derby.tscn") as PackedScene).instantiate()
	add_child(surface_derby)
	await get_tree().physics_frame
	check(surface_derby.gore_festival == null, "the surface derby does not inherit the institutional festival")
	surface_derby.queue_free()

	print("GORE_FESTIVAL_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
