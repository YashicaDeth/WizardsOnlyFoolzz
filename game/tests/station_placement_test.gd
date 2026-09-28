extends Node

## Greg, 24 September: the examiner and his PC stood in the middle of the vat
## aisle. The workstation stands to the side of the tank now, and his walk
## out never passes through the tank.

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
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	await get_tree().process_frame
	var station := vat.get_node("UnknownExaminerStation") as Node3D
	var nearest_x := INF
	for child in station.get_children():
		if child is MeshInstance3D:
			var box := (child as MeshInstance3D).get_aabb()
			for corner in 8:
				nearest_x = minf(nearest_x, absf((child.global_transform * box.get_endpoint(corner)).x))
	check(nearest_x > 1.4, "no part of the workstation stands in the aisle (nearest %.2f m from the middle)" % nearest_x)
	var closest := INF
	for step in 41:
		var t := float(step) / 40.0
		for inbound in [true, false]:
			var at: Vector3 = vat._examiner_path(t, inbound)
			closest = minf(closest, Vector2(at.x, at.z).length())
	check(closest > 1.2, "his walk to and from the door keeps clear of the tank (%.2f m)" % closest)
	check(vat.examiner_post.distance_to(station.global_position) < 2.0, "and he works at the station, not in front of it")
	print("STATION_PLACEMENT_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
