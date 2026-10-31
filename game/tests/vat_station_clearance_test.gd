extends Node

## The examination station, measured rather than eyeballed.
##
## The complaint behind moving the desk and the terminal was that the two did
## not read as one workstation, and that the screen could eclipse the man from
## inside the tank. `station_placement_test` cannot catch either: it measures
## distance from the aisle and from the tank, and a screen two metres down the
## table from its own operator passes it happily. So both are asserted here.
##
## Two spaces, on purpose. Overlap is checked in world space, because the
## station is yawed and a yaw must not be able to hide an intersection.
## Reach and support are checked in the station's own local space, because that
## is the space the layout is authored in and world x is meaningless once the
## station is turned 64 degrees away from the aisle.

const MonitorClearance := 0.05
const ReachLimit := 1.20
const DeskReach := 0.45

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _world_box(node: Node3D) -> AABB:
	## World-space bounds of everything visible under this node. The examiner's
	## mesh hangs one level down inside a plain Node3D, so this recurses; the
	## parts are built at runtime, so they are unowned and `find_children` is
	## told so. The node itself counts -- the terminal has no children.
	var box := AABB()
	var first := true
	var parts: Array[Node] = []
	if node is VisualInstance3D:
		parts.append(node)
	parts.append_array(node.find_children("*", "VisualInstance3D", true, false))
	for part in parts:
		var visual := part as VisualInstance3D
		var local := visual.get_aabb()
		var world := AABB(visual.global_transform * local.get_endpoint(0), Vector3.ZERO)
		for corner in 8:
			world = world.expand(visual.global_transform * local.get_endpoint(corner))
		box = world if first else box.merge(world)
		first = false
	return box


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	await get_tree().process_frame

	var station := vat.get_node("UnknownExaminerStation") as Node3D
	var monitor := station.get_node_or_null("ExaminerMonitor") as Node3D
	check(monitor != null, "the examiner's terminal is addressable by name")
	var examiner := station.get_node_or_null("UnknownExaminer") as Node3D
	check(examiner != null, "the examiner stands at the same station")
	if monitor == null or examiner == null:
		print("VAT_STATION_CLEARANCE_TEST_RESULT failures=%d" % failures.size())
		get_tree().quit(1)
		return

	# He is parked at his door and hidden until the opening walks him in, so the
	# workstation has to be asked about at his post rather than mid-arrival. The
	# chamber drives that placement every frame, so its own loop is stopped first
	# -- otherwise the post is overwritten before anything is measured.
	vat.set_process(false)
	vat.set_physics_process(false)
	examiner.position = vat.EXAMINER_AT_DESK
	examiner.rotation.y = vat.EXAMINER_TURN
	examiner.visible = true
	await get_tree().process_frame

	# --- the screen never stands inside the man, in world space -------------
	var screen_box := _world_box(monitor)
	var man_box := _world_box(examiner)
	check(screen_box.has_volume() and man_box.has_volume(), "both the terminal and the man have measurable volume")
	if not screen_box.has_volume() or not man_box.has_volume():
		print("VAT_STATION_CLEARANCE_TEST_RESULT failures=%d" % failures.size())
		get_tree().quit(1)
		return
	var gap := Vector3(
		maxf(screen_box.position.x - man_box.end.x, man_box.position.x - screen_box.end.x),
		maxf(screen_box.position.y - man_box.end.y, man_box.position.y - screen_box.end.y),
		maxf(screen_box.position.z - man_box.end.z, man_box.position.z - screen_box.end.z))
	var overlapping := gap.x < MonitorClearance and gap.y < MonitorClearance and gap.z < MonitorClearance
	check(not overlapping, "the terminal does not stand inside the examiner (gap %s)" % gap)

	# --- and they are one workstation, in the layout's own space -------------
	var reach := Vector2(monitor.position.x - examiner.position.x, monitor.position.z - examiner.position.z).length()
	check(reach <= ReachLimit, "the terminal is within reach of the man (%.2f m, limit %.2f)" % [reach, ReachLimit])

	# The desk is found by its shape, not its name: unnamed parts are renamed
	# `@MeshInstance3D@361` and friends the moment they enter the tree, so a
	# name match here would silently find nothing.
	var desk: MeshInstance3D = null
	for child in station.get_children():
		if child is MeshInstance3D:
			var local := (child as MeshInstance3D).get_aabb()
			if local.size.y < 0.2 and local.size.x > 1.5:
				desk = child
				break
	check(desk != null, "the desk is a flat slab under the terminal")
	if desk != null:
		var span := desk.get_aabb()
		check(desk.position.x + span.position.x <= monitor.position.x
			and desk.position.x + span.end.x >= monitor.position.x,
			"the screen sits over the desk, not beside it")
		check(monitor.position.x >= examiner.position.x,
			"the screen stays on the man's side, never behind him")
		var reaches := absf((desk.position.x + span.position.x) - examiner.position.x)
		check(reaches <= DeskReach, "the desk reaches the man instead of standing beside him (%.2f m)" % reaches)

	print("VAT_STATION_CLEARANCE_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
