extends Node

## Every firearm reachable by the sandbox must put its own physical calibre in
## flight. This catches the subtle sniper regression where the UI said rifle
## while Ballistics simulated a pistol round.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _round_calibres(demo: Node) -> Array[String]:
	var out: Array[String] = []
	for round_data: Dictionary in demo.ballistics.rounds:
		out.append(str((round_data.get("spec", {}) as Dictionary).get("label", "")))
	return out


func _fire_weapon(demo: Node, weapon_id: String, expected_label: String, expected_rounds: int) -> void:
	demo.ballistics.clear()
	demo.arsenal.tick(10.0)
	if weapon_id == "sniper":
		demo.arsenal.acquire_sniper()
	elif weapon_id == "facility_sidearm":
		demo.arsenal.acquire_facility_sidearm(3)
	else:
		demo.arsenal.select_slot(HunterArsenal.SLOT_ORDER.find(weapon_id))
	var before := int((demo.arsenal.ammo[weapon_id] as Dictionary).loaded)
	demo._fire()
	var labels := _round_calibres(demo)
	check(int((demo.arsenal.ammo[weapon_id] as Dictionary).loaded) == before - 1,
		"%s spends exactly one loaded round" % weapon_id)
	check(labels.size() == expected_rounds,
		"%s puts %d physical projectile(s) in flight" % [weapon_id, expected_rounds])
	check(labels.all(func(label: String) -> bool: return label == expected_label),
		"%s uses the %s ballistic profile (%s)" % [weapon_id, expected_label, labels])


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var demo = load("res://gore_demo.tscn").instantiate()
	add_child(demo)
	await get_tree().physics_frame
	demo.set_physics_process(false)

	_fire_weapon(demo, "sidearm", "9 SHORT", 1)
	_fire_weapon(demo, "shotgun", "12 BORE", 10)
	_fire_weapon(demo, "sniper", "LONG", 1)
	_fire_weapon(demo, "facility_sidearm", "9 SHORT", 1)

	demo.ballistics.clear()
	demo._equip_launcher()
	var warheads_before: int = demo.launcher_rounds
	demo._fire()
	var launcher_labels := _round_calibres(demo)
	check(demo.launcher_rounds == warheads_before - 1, "the breach launcher spends one warhead")
	check(launcher_labels == ["WARHEAD"], "and launches the visible rocket profile")

	print("GORE_ALL_FIREARMS_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
