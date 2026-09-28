extends Node
## Greg's playtest: the first run is one guided breakout, one lesson a room,
## and each room's way on waits for its lesson. A returning run is free.

var failures := 0


func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	failures += int(not condition)


func _ready() -> void:
	WorldHistory.clear_history()
	check(not FacilityRoutes.escaped_once(), "a fresh world is a first run")

	# Growing Floor: the fight. His keycard is what opens the pit door.
	var vat = load("res://vat_chamber.gd").new()
	check(not vat._pit_door_open(), "first run: the pit door is sealed without his keycard")
	check(vat._first_run_objective().contains("BREAK IT DOWN"), "the objective sends you through his door")
	var carry := Carry.new()
	carry.items.append({"label": vat.STAFF_KEYCARD, "kind": "key", "mass": 0.05, "perishes": false, "age": 0.0})
	carry.save_to_history()
	check(vat._pit_door_open() and vat._first_run_objective().contains("PIT DOOR"), "his keycard opens it, and the objective says so")
	vat.free()

	# Service Arcade: sight. The gate is jammed; the crawlway gets you past.
	var arcade = load("res://service_arcade.tscn").instantiate()
	add_child(arcade)
	await get_tree().physics_frame
	arcade.card_taken = true
	arcade.player.global_position = arcade.GATE_AT + Vector3(0, 0, 2.0)
	arcade._interact()
	check(not arcade.gate_open and arcade.post_message.contains("HOLD J"), "first run: the card will not open the jammed gate, and J is named")
	HiddenCache.mark_found(arcade.caches, arcade.CRAWL_ID)
	arcade.player.global_position = arcade.CRAWL_AT + Vector3(0.8, 0.9, 0)
	arcade._interact()
	check(arcade.player.global_position.z < arcade.GATE_AT.z and WorldHistory.event_count("service_arcade_crawlway_taken") == 1, "the scanned crawlway takes you out past the gate")
	check(arcade._onward_open() or arcade._flat_distance(arcade.EXIT_AT) > 3.0, "and the way on is not blocked behind you")
	arcade.queue_free()

	# Lower Works: stealth. Creeping is quieter; hunted, the lift will not go.
	var city = load("res://buried_city.tscn").instantiate()
	add_child(city)
	await get_tree().physics_frame
	check(city.HEAR_CREEPING < city.HEAR_WALKING, "creeping lets you get closer than walking")
	city.fuse_taken = true
	city.patrol_alert = true
	city.player.global_position = city.EXIT_AT + Vector3(0, 0.9, 0)
	city._interact()
	check(not city.lift_requested and city.objective.text.contains("LOSE IT"), "hunted, the heat elevator waits until you lose it or put it down")
	city.patrol_alert = false
	city._interact()
	check(city.lift_requested, "unseen, it takes you up")
	city.queue_free()

	WorldHistory.amend_subject(FacilityRoutes.SUBJECT, {"completed_routes": [FacilityRoutes.ROUTE_HEAT_ELEVATOR]})
	var again = load("res://vat_chamber.gd").new()
	WorldHistory.clear_history()
	WorldHistory.amend_subject(FacilityRoutes.SUBJECT, {"completed_routes": [FacilityRoutes.ROUTE_HEAT_ELEVATOR]})
	check(again._pit_door_open(), "a returning run: the pit door opens without him")
	again.free()
	print("FIRST_RUN_LESSONS_TEST_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
