extends Node
## Greg's checklist: a first run with no dead ends. The guided path, end to
## end, through the real gates: filed and out of the tank, dressed, his door
## down, him beaten, his card, the pit door; the jammed gate and the
## crawlway; the fuse, the sentinel, the heat elevator; up into the Hunt.
## Each step asserts the way on is open, so a dead end fails here first.

const VAT := preload("res://vat_chamber.tscn")
var failures := 0


func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	failures += int(not condition)


func _ready() -> void:
	WorldHistory.clear_history()
	check(not FacilityRoutes.escaped_once(), "a first run")

	# --- Growing Floor: out, dressed, through his door, his card. ---
	var vat = VAT.instantiate()
	add_child(vat)
	await get_tree().process_frame
	vat.intake._finish_filing()
	await get_tree().process_frame
	vat.departure_clock = vat.DEPARTURE_SECONDS
	vat._update_departure(0.0)
	vat.clock = vat.DRAINED_AT
	vat.phase = "voiding"
	vat._update_sequence(0.05)
	while not vat.umbilicals.is_empty():
		for _tug in vat.WIRE_TUGS:
			vat._tug_wire(vat.umbilicals[0])
	vat._physics_process(vat.REVENGE_HOLD + 0.1)
	for _step in 80:
		if vat.can_move:
			break
		vat._physics_process(0.1)
	check(vat.can_move, "out of the tank and standing")
	check(not vat._pit_door_open(), "the pit door waits for his card")
	var route = vat.doctor_route
	check(not route.strike("restraint"), "naked, his door takes no blow")
	Clothing.wear("player", "scavenged_coat")
	var blows := 0
	while not route.door.broken and blows < 200:
		route.cooldown = 0.0
		route.door.hit("axe", route.DOOR_AT + Vector3(0, 1.2, 0), Vector3(0, 0, 1))
		blows += 1
	check(route.door.broken, "dressed, his door comes down (%d blows)" % blows)
	check(vat._first_run_objective().contains("BEAT HIM"), "the objective points at him")
	route.fight._win()
	check(VatRebirth.carries(vat.STAFF_KEYCARD), "beaten, his keycard is yours")
	check(vat._pit_door_open() and vat._first_run_objective().contains("PIT DOOR"), "and it opens the pit door: the way on")
	vat.queue_free()
	await get_tree().process_frame

	# --- Service Arcade: the gate is jammed; the crawlway gets you past. ---
	var arcade = load("res://service_arcade.tscn").instantiate()
	add_child(arcade)
	await get_tree().physics_frame
	arcade.card_taken = true
	arcade.player.global_position = arcade.GATE_AT + Vector3(0, 0.9, 2.0)
	arcade._interact()
	check(not arcade.gate_open, "the pressure gate stays jammed")
	HiddenCache.mark_found(arcade.caches, arcade.CRAWL_ID)
	arcade.player.global_position = arcade.CRAWL_AT + Vector3(0.8, 0.9, 0)
	arcade._interact()
	arcade.player.global_position = arcade.EXIT_AT + Vector3(0, 0.9, 0)
	check(arcade._onward_open(), "through the crawlway, the stairs down are open")
	arcade.queue_free()
	await get_tree().process_frame

	# --- Lower Works: the fuse, past the sentinel, the heat elevator. ---
	var city = load("res://buried_city.tscn").instantiate()
	add_child(city)
	await get_tree().physics_frame
	city.player.global_position = city.FUSE_AT + Vector3(0, 0.9, 0)
	city._interact()
	check(city.fuse_taken, "the lift fuse is there to take")
	city.patrol_alert = false
	city.player.global_position = city.EXIT_AT + Vector3(0, 0.9, 1.0)
	city._interact()
	check(city.lift_requested, "unseen, the heat elevator takes you up")
	check(not FacilityRoutes.pending_surface_handoff().is_empty(), "and the surface is waiting for you")
	city.queue_free()
	await get_tree().process_frame

	check(FacilityRoutes.escaped_once(), "one escape: the side routes open next run")
	print("FIRST_RUN_WALK_TEST_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
