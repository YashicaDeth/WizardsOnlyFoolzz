extends Node

const BODY := preload("res://systems/baseline_human.gd")
const ARSENAL := preload("res://systems/hunter_arsenal.gd")
const LOADOUT := preload("res://systems/facility_guard_loadout.gd")

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
	var guard := BODY.new()
	guard.build("guard_hollis")
	add_child(guard)
	var loadout := LOADOUT.new("guard_hollis")
	loadout.attach_to(guard)
	var arsenal := ARSENAL.new()
	add_child(arsenal)

	check(not bool(loadout.take_sidearm(guard, arsenal).accepted),
		"the player cannot take a gun an active guard still physically holds")
	guard.anatomy.downed = true
	var taken := loadout.take_sidearm(guard, arsenal)
	check(bool(taken.accepted) and arsenal.current_id == "facility_sidearm",
		"downing the barrier guard transfers that guard's gun into the real arsenal")
	check(str(guard.get_meta("facility_weapon")) == "" and not loadout.gun_available,
		"the same physical gun no longer exists on the guard")
	var definition := arsenal.current()
	check(float(definition.damage) >= 50.0 and float(definition.impulse) >= 30.0,
		"the first firearm is genuinely decisive rather than a weak tutorial prop")
	check(int(arsenal.ammo.facility_sidearm.loaded) == 3 and int(arsenal.ammo.facility_sidearm.reserve) == 0,
		"it arrives with only three chambered rounds and no reserve ammunition")
	for shot in 3:
		var report := arsenal.begin_attack()
		check(bool(report.accepted), "scarce round %d can still be fired" % (shot + 1))
		arsenal.cooldown = 0.0
	check(not bool(arsenal.begin_attack().accepted) and not arsenal.reload(),
		"after three powerful shots the gun is empty and melee matters again")
	check(not bool(loadout.take_sidearm(guard, arsenal).accepted),
		"the guard cannot be farmed for another gun or another three rounds")
	check(WorldHistory.event_count("facility_guard_weapon_taken") == 1,
		"the one transfer is recorded once as an escape consequence")

	print("FACILITY_FIRST_FIREARM_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
