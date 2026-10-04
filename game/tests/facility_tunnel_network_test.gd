extends Node

## art-tunnels-07: the tunnel kit network loads, every piece meets its
## neighbours with no gap (joints match, floor under every edge, walls on every
## closed side), and a body walks its whole length inside facility.tscn, from
## the vat through every side tunnel and the sliding door to the arcade, with
## no scene change and no fall.

const NETWORK := preload("res://facility_tunnel_network.tscn")
const FACILITY := preload("res://facility.tscn")
const KIT := preload("res://systems/facility_tunnel_kit.gd")
const NETWORK_SCRIPT := preload("res://facility_tunnel_network.gd")
const LEG_TIMEOUT := 30.0

var failures: Array[String] = []
var facility: Node3D
var lowest := 99.0
var door_seen_open := false
var watched_door: Node3D


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	get_tree().create_timer(170.0, true, false, true).timeout.connect(func() -> void:
		print("FACILITY_TUNNEL_NETWORK_RESULT failures=timeout")
		get_tree().quit(1))
	await _structure()
	await _walk_it()
	print("FACILITY_TUNNEL_NETWORK_RESULT failures=%d" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)


func _structure() -> void:
	var network: Node3D = NETWORK.instantiate()
	add_child(network)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var errors := NETWORK_SCRIPT.joint_errors()
	check(errors.is_empty(), "every open side meets a matching side or a room port %s" % [errors])
	check(network.pieces.size() == NETWORK_SCRIPT.LAYOUT.size(), "every layout cell built a piece (%d)" % network.pieces.size())
	var kinds := {}
	var lit := 0
	for cell: Vector2i in network.pieces:
		var piece: Node3D = network.pieces[cell]
		kinds[piece.get_meta("kind")] = true
		if piece.get_node_or_null("Lamp") != null:
			lit += 1
	for kind in ["straight", "corner", "t", "cross", "dead_end", "door", "pipe_run", "vent"]:
		check(kinds.has(kind), "the network uses the kit's %s piece" % kind)
	check(lit >= 3 and lit < network.pieces.size(), "lighting pools: %d lit cells with dark cells between" % lit)
	# The generated Higgsfield dressing is placed through its measured FIT.
	var dressed := {}
	for node in network.find_children("*", "Node3D", true, false):
		if node.has_meta("kit_model"):
			var model_name := str(node.get_meta("kit_model"))
			dressed[model_name] = int(dressed.get(model_name, 0)) + 1
	for model in ["tunnel_rib", "tunnel_lamp", "tunnel_pipe_run", "tunnel_vent", "tunnel_bulkhead", "tunnel_door_frame"]:
		check(int(dressed.get(model, 0)) > 0, "the kit dresses its pieces with %s (%d)" % [model, int(dressed.get(model, 0))])
	check(int(dressed.get("tunnel_rib", 0)) == _joints(), "one rib on every joint between cells (%d ribs, %d joints)" % [int(dressed.get("tunnel_rib", 0)), _joints()])
	var space := network.get_world_3d().direct_space_state
	var half := KIT.CELL * 0.5
	var floor_gaps := 0
	var wall_gaps := 0
	var leaks := 0
	for cell: Vector2i in network.pieces:
		var centre := NETWORK_SCRIPT.cell_centre(cell)
		var open: String = NETWORK_SCRIPT.LAYOUT[cell][1]
		# Floor at the centre, the corners and every edge midpoint (just inside
		# the cell, where two pieces meet).
		for offset: Vector3 in [Vector3.ZERO, Vector3(half - 0.05, 0, 0), Vector3(-half + 0.05, 0, 0), Vector3(0, 0, half - 0.05), Vector3(0, 0, -half + 0.05), Vector3(half - 0.05, 0, half - 0.05), Vector3(-half + 0.05, 0, -half + 0.05)]:
			var hit := _ray(space, centre + offset + Vector3(0, 1.0, 0), centre + offset + Vector3(0, -1.0, 0))
			if hit.is_empty() or absf(hit.position.y) > 0.05:
				floor_gaps += 1
				print("  no floor at ", centre + offset)
		# Every closed side stops a body; every open side lets one through.
		for side: String in KIT.SIDES:
			var normal: Vector3 = KIT.SIDES[side]
			var from := centre + Vector3(0, 1.2, 0)
			var hit := _ray(space, from, from + normal * (half + 0.6))
			var is_door: bool = NETWORK_SCRIPT.LAYOUT[cell][0] == "door"
			if not open.contains(side) and hit.is_empty():
				wall_gaps += 1
				print("  no wall on ", cell, " ", side)
			elif open.contains(side) and not hit.is_empty() and not is_door:
				leaks += 1
				print("  open side blocked on ", cell, " ", side)
	check(floor_gaps == 0, "no floor gaps at any centre, edge or corner (%d)" % floor_gaps)
	check(wall_gaps == 0, "every closed side is walled (%d)" % wall_gaps)
	check(leaks == 0, "every open side is clear to the next piece (%d)" % leaks)
	network.queue_free()
	await get_tree().process_frame


func _walk_it() -> void:
	Engine.time_scale = 3.0
	facility = FACILITY.instantiate()
	add_child(facility)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var scene_at_start := get_tree().current_scene
	check(facility.tunnels != null and facility.tunnels.pieces.size() == NETWORK_SCRIPT.LAYOUT.size(), "facility.tscn builds the tunnel network in place of the old artery box")
	for lift: Node3D in facility.lifts.values():
		check(lift.cab.find_child("generated_tunnel_lift_cab", true, false) != null, "lift %s rides with the generated cage in its car" % lift.name)
	var door: Node3D = null
	for piece: Node3D in facility.tunnels.pieces.values():
		if piece.get_node_or_null("Door") != null:
			door = piece.get_node("Door")
	check(door != null and not door.is_open(), "the artery door stands shut before anyone comes")
	check(await _walk(Vector3(4, 0, -2.5)), "walks from the vat to the staff door")
	watched_door = door
	var route := NETWORK_SCRIPT.walk_route()
	var reached := 0
	for point in route:
		if await _walk(point):
			reached += 1
	check(reached == route.size(), "walks every cell of the network, out and back along each spur (%d/%d)" % [reached, route.size()])
	check(await _walk(Vector3(21.5, 0, -2.5)), "through the door into the Service Arcade")
	check(door_seen_open, "the sliding door opened for the body")
	check(await _walk(Vector3(28, 0, -2.5)), "out onto the arcade floor")
	await _seconds(2.0)
	check(door != null and not door.is_open(), "the door shut behind the body")
	check(lowest > -0.5, "the body never dropped through a joint (lowest %.2f)" % lowest)
	check(get_tree().current_scene == scene_at_start and not Interstitial.travelling, "no scene change or loading screen on the way")
	Engine.time_scale = 1.0


func _physics_process(_delta: float) -> void:
	if facility != null and is_instance_valid(facility) and facility.player != null:
		lowest = minf(lowest, facility.player.global_position.y)
	if watched_door != null and is_instance_valid(watched_door) and watched_door.is_open():
		door_seen_open = true


## Joints between two cells, plus the east port (the arcade side).
func _joints() -> int:
	var count := 0
	for cell: Vector2i in NETWORK_SCRIPT.LAYOUT:
		for side in ["e", "s"]:
			if str(NETWORK_SCRIPT.LAYOUT[cell][1]).contains(side):
				count += 1
	return count


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))


func _walk(goal: Vector3) -> bool:
	var player: CharacterBody3D = facility.player
	goal.y = player.global_position.y
	facility.bot_goal = goal
	var ok := await _until(func() -> bool:
		var to := goal - player.global_position
		to.y = 0.0
		return to.length() < 0.5)
	facility.bot_goal = null
	player.velocity = Vector3.ZERO
	if not ok:
		print("  stuck at ", player.global_position, " heading for ", goal)
	return ok


func _until(condition: Callable) -> bool:
	var clock := 0.0
	while clock < LEG_TIMEOUT:
		if condition.call():
			return true
		await get_tree().physics_frame
		clock += get_physics_process_delta_time()
	return false


func _seconds(duration: float) -> void:
	var clock := 0.0
	while clock < duration:
		await get_tree().physics_frame
		clock += get_physics_process_delta_time()
