extends Node

var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)

## Spawns a dummy directly in front, swings at the given pitch, and reports which
## zone actually took the damage. Removed afterwards so the next probe is
## unambiguous about which actor it hit.
func _aim_wound(hunt, aim_pitch: float, tag: String) -> String:
	hunt._spawn_encounter_actor({"instance_id": tag, "kind": "hostile", "summary": "aim probe"}, hunt.player + Vector3(0, 0, 2.2))
	var actor: Dictionary = hunt.encounter_actors.back()
	var rig = actor.rig
	hunt.yaw = 0.0
	hunt.pitch = aim_pitch
	hunt._attack_nearest_encounter_actor()
	var worst := ""
	var worst_loss := 0.0
	for zone_id in BaselineHuman.ZONES:
		var loss: float = float(AnatomyComponent.DEFAULT_ZONES[zone_id].health) - rig.zone_health(zone_id)
		if loss > worst_loss:
			worst_loss = loss
			worst = zone_id
	(actor.node as Node3D).queue_free()
	hunt.encounter_actors.erase(actor)
	return worst


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

	# The player finally has a body rather than only a health integer.
	check(hunt.player_rig is BaselineHuman, "the player has a baseline rig")
	Input.action_press("crouch")
	hunt._update_player(0.2)
	Input.action_release("crouch")
	check(hunt.player_capsule.height < 1.8 and hunt.player_collider.position.y < 0.0, "crouch lowers both capsule and centre without lifting the feet")
	for stand_frame in 4:
		hunt._update_player(0.2)
	check(is_equal_approx(hunt.player_capsule.height, 1.8), "released crouch restores standing collision")
	hunt.third_person = false
	hunt._update_camera()
	check(not hunt.player_rig.parts["head"].visible, "first person hides the player's own head")
	check(hunt.player_rig.parts["left_arm"].visible, "...but keeps the body you look down at")
	hunt.third_person = true
	# M3. The switch is a blend now (perspective_blend), not a hard cut, so the
	# head only reappears once it has actually slid past the halfway point —
	# one call left it still mid-transition and reads as a false failure here.
	for _settle in 30:
		hunt._update_camera()
	check(hunt.player_rig.parts["head"].visible, "third person shows the whole body")
	hunt._wound_player(hunt.player + Vector3(0, 0, 2), 20.0, "cut")
	var player_state: Dictionary = WorldHistory.subject("player").get("anatomy_state", {})
	check(player_state.has("zones"), "player wounds are recorded on the player subject")
	var player_hurt := 0
	for zone_id in player_state.get("zones", {}):
		if float(player_state.zones[zone_id].health) < float(AnatomyComponent.DEFAULT_ZONES[zone_id].health):
			player_hurt += 1
	check(player_hurt == 1, "a strike on the player lands on exactly one zone (%d)" % player_hurt)

	# Aim, not a round-robin, decides the wound.
	var high := _aim_wound(hunt, 0.85, "aim_high")
	var low := _aim_wound(hunt, -0.85, "aim_low")
	check(high != low, "where you look changes what you open (up %s, down %s)" % [high, low])
	check(high in ["head", "torso"], "looking up wounds the upper body (%s)" % high)
	check(low in ["left_leg", "right_leg"], "looking down wounds the legs (%s)" % low)
	var derby = load("res://rift_derby.tscn").instantiate()
	add_child(derby)
	derby.set_physics_process(false)
	check(derby.round_state == "countdown", "derby starts at countdown")
	derby._physics_process(3.1)
	check(derby.round_state == "active", "countdown starts active round")
	var wrecker: Node3D = derby.targets[1]
	var rig = wrecker.get_node_or_null("DriverRig")
	check(rig is BaselineHuman, "derby drivers use the shared baseline rig")
	var driver_subject := str(wrecker.get_meta("driver_subject", ""))
	derby._injure_driver(wrecker, 60, Vector3(0, 0, 1), false)
	var state: Dictionary = WorldHistory.subject(driver_subject).get("anatomy_state", {})
	check(state.has("zones"), "a derby injury is recorded on the driver's subject")
	var hurt: Array[String] = []
	for zone_id in state.get("zones", {}):
		if float(state.zones[zone_id].health) < float(AnatomyComponent.DEFAULT_ZONES[zone_id].health):
			hurt.append(str(zone_id))
	# Two-sided: the blow has to land somewhere real, and only there. Smearing
	# across zones or vanishing into the torso are both failures.
	check(hurt.size() == 1 and BaselineHuman.ZONES.has(hurt[0]), "the blow lands on exactly one canonical zone (%s)" % str(hurt))
	# Bodies remember: rebuild that same driver and the wound is still on them.
	derby._create_wrecker(1)
	var rebuilt = (derby.targets.back() as Node3D).get_node_or_null("DriverRig")
	check(rebuilt.zone_health(hurt[0]) < float(AnatomyComponent.DEFAULT_ZONES[hurt[0]].health), "a rebuilt driver still carries the wound on %s" % hurt[0])
	check(rebuilt.zone_health("head") == float(AnatomyComponent.DEFAULT_ZONES.head.health) or hurt[0] == "head", "...and is not wounded anywhere they were not hit")
	derby._finish_round("won")
	derby._finish_round("lost")
	check(derby.round_state == "won" and derby.mode_label.visible, "terminal derby result is stable and visible")
	check(OpeningDirector.reached("won_derby"), "winning the real derby advances the opening route")
	print("OPENING_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
