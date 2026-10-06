extends Node

## bughunt-79-c. Blood splats and footprints keep their nodes in static lists
## that outlive the scene (a vat rebirth reloads it). After the reload the
## lists hold freed nodes; trimming one through a typed variable was a SCRIPT
## ERROR that also aborted the trim, so every later drop threw again.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	BaselineHuman.clear_gore()
	Footprints.clear()
	# The scene that bled: fill the splat list past its budget, then free it.
	var old_room := Node3D.new()
	add_child(old_room)
	var budget := BaselineHuman.splat_budget()
	for i in budget:
		BaselineHuman.mark_ground_for_chunk(old_room.get_world_3d(), old_room, Vector3(i * 0.1, 1.0, 0.0), Vector3.DOWN, 0.2)
	old_room.name = "ReloadedRoom"
	var walker := Node.new()
	add_child(walker)
	for i in Footprints.MAX_PRINTS:
		Footprints._wet[walker.get_instance_id()] = 1.0
		Footprints.step(old_room, walker, Vector3(i * 0.1, 0, 0), "left")
	check(Footprints.print_count(old_room) == Footprints.MAX_PRINTS, "the first room filled its prints (%d)" % Footprints.print_count(old_room))
	check(BaselineHuman.splats.size() == budget, "the first room filled the splat list (%d)" % BaselineHuman.splats.size())
	old_room.free()
	# The reloaded scene bleeds again.
	var new_room := Node3D.new()
	new_room.name = "ReloadedRoom"
	add_child(new_room)
	var stepped := 0
	for i in 6:
		Footprints._wet[walker.get_instance_id()] = 1.0
		if Footprints.step(new_room, walker, Vector3(i * 0.1, 0, 1), "right"):
			stepped += 1
	check(stepped == 6, "the reloaded room takes six fresh prints (%d)" % stepped)
	check(Footprints.print_count(new_room) <= Footprints.MAX_PRINTS, "the print list is trimmed after a reload (%d)" % Footprints.print_count(new_room))
	for i in 12:
		BaselineHuman.mark_ground_for_chunk(new_room.get_world_3d(), new_room, Vector3(i * 0.1, 1.0, 0.0), Vector3.DOWN, 0.2)
	check(BaselineHuman.splats.size() <= budget, "the splat list is trimmed back to budget after a reload (%d of %d)" % [BaselineHuman.splats.size(), budget])
	var live := 0
	for splat in BaselineHuman.splats:
		if is_instance_valid(splat):
			live += 1
	check(live == 12, "all twelve new splats are kept (%d)" % live)
	print("STATIC_CACHE_RELOAD_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
