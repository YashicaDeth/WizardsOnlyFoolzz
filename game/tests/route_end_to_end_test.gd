extends Node
## The escape route as one run, not as a set of beats.
##
## first_run_walk_test drives the route to "the surface is waiting for you"
## and stops there. exit_reveal_test proves the arrival reveal, but from a
## synthetic handoff it builds itself. Neither one shows that the staff door
## you opened is the same route that lands you on the surface and plays the
## ending -- so a break between the last two beats could pass both suites.
##
## This fixture is the joint. It walks the real scenes in order and never
## injects a handoff: the one the lift leaves is the one the Hunt consumes.
##
##   vat -> examiner -> his keycard -> staff door -> arcade crawlway
##       -> lower works fuse -> heat elevator -> pending handoff
##       -> the Hunt plays the reveal -> the world is handed back
##
## Exit code is the authority (ORCA/RULES.md 2).

const VAT := preload("res://vat_chamber.tscn")

var failures := 0


func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	failures += int(not condition)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	# The reveal holds the tree while it plays; this node has to keep running
	# to watch it, the same way exit_reveal_test does.
	process_mode = Node.PROCESS_MODE_ALWAYS
	WorldHistory.clear_history()
	check(not FacilityRoutes.escaped_once(), "this is a first run")

	# --- Growing Floor: out of the tank, dressed, his door, him, his card. ---
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
	check(vat.can_move, "out of the tank and on your feet")

	Clothing.wear("player", "scavenged_coat")
	var route = vat.doctor_route
	var blows := 0
	while not route.door.broken and blows < 200:
		route.cooldown = 0.0
		route.door.hit("axe", route.DOOR_AT + Vector3(0, 1.2, 0), Vector3(0, 0, 1))
		blows += 1
	check(route.door.broken, "his office door comes down (%d blows)" % blows)
	route.fight._win()
	check(route.fight.keycard_on_floor(), "beaten, his keycard is on his floor")
	var card_at: Vector3 = route.fight.keycard_pickup.global_position if route.fight.keycard_on_floor() else vat.player.global_position
	vat.player.global_position = Vector3(card_at.x, vat.BODY_HALF_HEIGHT + 0.02, card_at.z + 0.6)
	check(route.fight.take_keycard() and VatRebirth.carries(vat.STAFF_KEYCARD), "his keycard is yours")

	# The one-map build: the staff door is the way on, and this is the door
	# whose route must be the one that reaches the surface.
	vat.player.global_position = Vector3(vat.STAFF_DOOR_AT.x - 1.2, vat.BODY_HALF_HEIGHT + 0.02, vat.STAFF_DOOR_AT.z)
	check(vat._try_staff_door() and vat.staff_door_open, "the staff door opens onto the artery")
	check(vat._first_run_objective().contains("STAFF DOOR"), "and the objective reads through it")
	vat.queue_free()
	await get_tree().process_frame

	# --- Service Arcade: the jammed gate, the crawlway past it. ---
	var arcade = load("res://service_arcade.tscn").instantiate()
	add_child(arcade)
	await get_tree().physics_frame
	arcade.card_taken = true
	arcade.player.global_position = arcade.GATE_AT + Vector3(0, 0.9, 2.0)
	arcade._interact()
	check(not arcade.gate_open, "the pressure gate will not take the card")
	HiddenCache.mark_found(arcade.caches, arcade.CRAWL_ID)
	arcade.player.global_position = arcade.CRAWL_AT + Vector3(0.8, 0.9, 0)
	arcade._interact()
	arcade.player.global_position = arcade.EXIT_AT + Vector3(0, 0.9, 0)
	check(arcade._onward_open(), "through the crawlway, the stairs down are open")
	arcade.queue_free()
	await get_tree().process_frame

	# --- Lower Works: the fuse, unseen, the heat elevator. ---
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
	check(FacilityRoutes.escaped_once(), "the escape is filed")
	# This is the handoff the lift leaves. Nothing below replaces it.
	var handoff: Dictionary = FacilityRoutes.pending_surface_handoff()
	check(not handoff.is_empty(), "and the surface handoff is the live one, not a stand-in")
	city.queue_free()
	await get_tree().process_frame

	# --- The surface: the Hunt consumes that handoff and plays the arrival. ---
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	await get_tree().process_frame
	check(hunt.exit_reveal == null, "the white-out and the title drop come first")
	var waited := 0.0
	while hunt.exit_reveal == null and waited < 10.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	var reveal: ExitReveal = hunt.exit_reveal
	check(reveal != null, "then the arrival reveal starts (%.1fs)" % waited)
	if reveal == null:
		hunt.queue_free()
		print("ROUTE_END_TO_END_TEST_RESULT failures=%d" % failures)
		get_tree().quit(1)
		return
	# The reveal exists as soon as the route surfaces, but it does not begin
	# until the white-out behind it has finished -- before that its clock is
	# zero, advance() has nothing planned to fly, and the world is not held
	# yet. Waiting on the pause itself is the only honest signal that it has
	# taken over; asserting straight after it appears races the transition and
	# passes or fails on timing.
	var began := 0.0
	while not get_tree().paused and began < 10.0:
		await get_tree().create_timer(0.1).timeout
		began += 0.1
	check(reveal.active and get_tree().paused, "and it holds the world while it plays (%.1fs after it appeared)" % began)
	check(reveal.exit_at.distance_to(Vector3(float(handoff.surface_position[0]), 0.0, float(handoff.surface_position[2]))) < 0.5,
		"from the point the heat elevator actually left you")
	var steps := 0
	var clock_before := reveal.clock
	while reveal.active and steps < 400:
		reveal.advance(0.1)
		steps += 1
	# A no-op advance would otherwise spin the whole budget and report a
	# mystifying 40 seconds instead of naming the real fault.
	check(reveal.clock > clock_before, "its clock runs once it has the world (%.1fs)" % reveal.clock)
	check(not reveal.active, "the reveal runs to its end (%.1fs)" % (float(steps) * 0.1))
	check(not get_tree().paused and get_viewport().get_camera_3d() == hunt.camera,
		"and the Hunt has its camera and its world back")
	var recorded: Array[Dictionary] = []
	for event: Dictionary in WorldHistory.events:
		if str(event.get("type", "")) == "exit_reveal_seen":
			recorded.append(event)
	check(recorded.size() == 1, "the arrival is written into the world record once")
	check(FacilityRoutes.pending_surface_handoff().is_empty(), "and the handoff is spent, not left to replay")
	hunt.queue_free()
	await get_tree().process_frame

	print("ROUTE_END_TO_END_TEST_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
