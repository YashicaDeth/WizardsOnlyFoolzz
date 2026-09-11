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
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(hunt.player_body is CharacterBody3D, "hunter uses collision body")
	var building: Node3D = hunt.generated_world.generated_buildings[0]
	var floor_shape: BoxShape3D = building.get_child(5).get_child(0).shape
	var depth := floor_shape.size.z
	hunt.player_body.position = building.position + Vector3(0, 0.92, depth * 0.5 + 2)
	await get_tree().physics_frame
	check(not hunt.player_body.test_move(hunt.player_body.global_transform, Vector3(0, 0, -3)), "doorway admits hunter")
	hunt.player_body.position.x += 3.0
	check(hunt.player_body.test_move(hunt.player_body.global_transform, Vector3(0, 0, -3)), "front wall blocks hunter")
	var lots: Array = hunt.generated_world.lots
	var overlaps := 0
	for i in lots.size():
		for j in range(i + 1, lots.size()):
			if lots[i].intersects(lots[j]):
				overlaps += 1
	check(overlaps == 0, "town lots do not overlap")
	var old_health: int = hunt.enemy_health
	hunt.player = hunt.enemy.position
	hunt._resolve_strike()
	check(hunt.enemy_health == old_health, "hidden Mara cannot be hit")
	hunt._spawn_loot_cache(hunt.player, ["test salvage"])
	hunt._interact()
	hunt._interact()
	check(WorldHistory.subject("inventory").items.count("test salvage") == 1, "loot collected exactly once")
	hunt._toggle_panel("tree")
	var energy: float = hunt.stamina
	hunt._attack()
	check(hunt.stamina == energy, "menu blocks strikes")
	hunt._toggle_panel("tree")
	WorldHistory.register_subject("migration_test", {"grudge": 91})
	WorldHistory.register_subject("migration_test", {"grudge": 0, "new_field": true})
	check(WorldHistory.subject("migration_test").grudge == 91 and WorldHistory.subject("migration_test").new_field, "migration preserves earned state")
	var anatomy = load("res://systems/anatomy_component.gd").new()
	add_child(anatomy)
	anatomy.configure("test")
	anatomy.apply_hit("left_leg", 90, 20, "cut")
	var before: float = anatomy.blood_remaining
	anatomy._process(1.0)
	check(anatomy.blood_remaining < before and anatomy.mobility_ratio() < 1.0, "injury bleeds and impairs movement")
	var rate: float = anatomy.bleed_rate
	anatomy.treat_wound("left_leg", 1.0)
	check(anatomy.bleed_rate < rate, "treatment reduces bleeding")
	anatomy.blood_remaining = 0.01
	anatomy._process(2.0)
	check(anatomy.dead, "blood loss reaches death")
	var first_lot: Rect2 = lots[0]
	var from := Vector3(first_lot.position.x - 5, 1, first_lot.get_center().y)
	var to := Vector3(first_lot.end.x + 5, 1, first_lot.get_center().y)
	var route: PackedVector2Array = hunt.pathfinder.route(from, to)
	var clear_route := not route.is_empty()
	for point in route:
		if first_lot.has_point(point):
			clear_route = false
	check(clear_route, "escape route avoids building footprint")
	hunt.player = Vector3(0, 1, 45)
	hunt.health = 50
	hunt._spawn_misfire_marker("Test", "Tea", Vector3(0, 0, 45), "friendly", "test_tea")
	hunt._interact()
	check(hunt.health == 75 and WorldHistory.subject("misfire:test_tea").status == "resolved", "friendly event heals and resolves")
	WorldHistory.update_subject("inventory", {"items": ["rust scrip"]})
	hunt._spawn_misfire_marker("Test", "Trade", Vector3(0, 0, 45), "trade", "test_trade")
	hunt._interact()
	check(WorldHistory.subject("inventory").items == ["field dressing"], "trade consumes currency and grants item")
	var event := {"instance_id": "test_enemy", "kind": "hostile", "summary": "test"}
	WorldHistory.register_subject("test_enemy_actor", {"status": "escaped"})
	var actor_count: int = hunt.encounter_actors.size()
	hunt._spawn_encounter_actor(event, Vector3(0, 0, 50))
	check(hunt.encounter_actors.size() == actor_count, "escaped actor cannot respawn")
	var derby = load("res://rift_derby.tscn").instantiate()
	add_child(derby)
	derby.set_process(false)
	check(derby.round_state == "countdown", "derby starts at countdown")
	derby._process(3.1)
	check(derby.round_state == "active", "countdown starts active round")
	derby._finish_round("won")
	derby._finish_round("lost")
	check(derby.round_state == "won" and derby.mode_label.visible, "terminal derby result is stable and visible")
	print("OPENING_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
