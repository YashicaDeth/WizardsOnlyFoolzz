extends Node

## AF10.12. "Jams, wear and condition are real." AN2.4 already gave melee a
## real condition that dulls an edge; nothing before this ever wore a
## firearm or let one fail to cycle. This proves both halves: a firearm
## wears on every shot the same way a blade wears on every connecting hit,
## and once it is worn down far enough the action can actually jam — which
## refuses the next trigger pull until `reload()` (the same input, a
## different real action) clears it.

const ARSENAL := preload("res://systems/hunter_arsenal.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var rig := BaselineHuman.new()
	rig.gore = false
	add_child(rig)
	rig.build("weapon_jam_test")
	var arsenal: Node = ARSENAL.new()
	add_child(arsenal)
	arsenal.configure(rig)
	arsenal.select_slot(2) # sidearm: magazine 10, reserve 50

	# ---- a pristine weapon wears, but never jams: the chance is a pure
	# function of condition and reads exactly zero at 1.0.
	var condition_before: float = arsenal.weapon_condition("sidearm")
	check(is_equal_approx(condition_before, 1.0), "a fresh sidearm starts at full condition")
	for _shot in 6:
		var shot: Dictionary = arsenal.begin_attack()
		check(bool(shot.get("accepted", false)) and not bool(shot.get("caused_jam", false)), "a fresh sidearm cycles cleanly")
		arsenal.tick(1.0)
	var condition_after: float = arsenal.weapon_condition("sidearm")
	check(condition_after < condition_before, "firing a gun wears it too, not only a blade in a fight (%.4f -> %.4f)" % [condition_before, condition_after])
	check(is_equal_approx(condition_after, 1.0 - 6.0 * arsenal.FIREARM_WEAR_PER_SHOT), "the wear is exactly six shots' worth, no more")

	# ---- run it all the way down, and the action actually fails to cycle.
	arsenal.condition["sidearm"] = 0.0
	arsenal._rng.seed = 7
	var jam_report := {}
	var shots_fired := 0
	# The sidearm carries 60 rounds total (10 + 50 reserve); a 35% jam
	# chance every shot at zero condition makes going that far without one
	# astronomically unlikely, so this loop always finds its jam.
	while shots_fired < 60:
		var shot: Dictionary = arsenal.begin_attack()
		if not bool(shot.get("accepted", false)):
			if str(shot.get("reason", "")) == "empty":
				check(arsenal.reload(), "reserve is still there to reload from at zero condition")
				arsenal.tick(float(arsenal.current().reload) + 0.1)
				continue
			jam_report = shot
			break
		shots_fired += 1
		arsenal.tick(float(arsenal.current().cooldown) + 0.1)
		if bool(shot.get("caused_jam", false)):
			jam_report = shot
			break
	check(not jam_report.is_empty(), "a badly worn sidearm eventually jams (%d shots fired first)" % shots_fired)
	check(bool(arsenal.jammed.get("sidearm", false)), "the arsenal's own state agrees the sidearm is jammed")

	# ---- a jammed action refuses to fire again until cleared.
	var after_jam: Dictionary = arsenal.begin_attack()
	check(not bool(after_jam.get("accepted", true)) and str(after_jam.get("reason", "")) == "jammed", "a jammed gun will not fire again on its own")

	# ---- switching away from a jammed gun is still allowed; it is a stuck
	# action, not a frozen arsenal.
	check(arsenal.select_slot(1), "a jammed sidearm can still be holstered for the shotgun")
	check(arsenal.select_slot(2), "and drawn again, still jammed")
	check(bool(arsenal.state().jammed), "state() agrees on the way back out")

	# ---- clearing it is a real, timed action distinct from a reload: no
	# round is lost and no magazine moves.
	var loaded_before_clear: int = arsenal.ammo.sidearm.loaded
	check(arsenal.reload(), "reload() clears a jam instead of swapping the magazine")
	check(arsenal.jam_clear_remaining > 0.0, "a real timer is running, not an instant fix")
	check(not arsenal.select_slot(0), "the arsenal cannot be swapped mid-clear any more than it can mid-reload")
	arsenal.tick(arsenal.JAM_CLEAR_TIME * 0.5)
	check(bool(arsenal.jammed.get("sidearm", false)), "still jammed halfway through the clear")
	arsenal.tick(arsenal.JAM_CLEAR_TIME * 0.6)
	check(not bool(arsenal.jammed.get("sidearm", false)), "clear once the timer actually elapses")
	check(int(arsenal.ammo.sidearm.loaded) == loaded_before_clear, "clearing a jam never touches the chambered round")
	var cleared_shot: Dictionary = arsenal.begin_attack()
	check(bool(cleared_shot.get("accepted", false)), "the action fires again once cleared")

	if failures.is_empty():
		print("weapon jams: a worn gun actually fails, and clearing it is its own real action")
		get_tree().quit(0)
	else:
		print("weapon jam FAILURES: ", failures)
		get_tree().quit(1)
