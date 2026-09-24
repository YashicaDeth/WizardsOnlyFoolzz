extends Node

## The old drains' bingyanger (Greg, 24 September): it hunts by sound, costs
## blood the way the sentinel does, can be slipped by going quiet or stunned
## with the breach tool, and everything it does is on the record.

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
	var drains = load("res://old_drains.tscn").instantiate()
	add_child(drains)
	var stalker: DrainStalker = drains.stalker
	var player: CharacterBody3D = drains.player
	check(stalker != null and stalker.rig != null, "the old drains have their bingyanger")
	check(str(WorldHistory.subject("drain_bingyanger").get("attitude", "")) == "hostile", "filed as a freed-long-ago escapee, always hostile")

	stalker.global_position = Vector3(0, 0, -20)
	# Still, five metres off: nothing to hear.
	player.global_position = Vector3(0, 0.85, -15)
	player.velocity = Vector3.ZERO
	_tick(stalker, 1.0)
	check(stalker.state == "prowl", "a player standing still is not heard at five metres")

	# Creeping past, four metres off.
	Input.action_press("crouch")
	player.velocity = Vector3(0, 0, -1.4)
	_tick(stalker, 0.5)
	check(stalker.state == "prowl", "creeping is not heard at four metres")
	Input.action_release("crouch")

	# Running, twelve metres off.
	stalker.global_position = Vector3(0, 0, -27)
	Input.action_press("sprint")
	player.velocity = Vector3(0, 0, -5.4)
	_tick(stalker, 0.1)
	Input.action_release("sprint")
	check(stalker.state == "hunt", "running is heard from twelve metres")
	check(WorldHistory.event_count("drain_bingyanger_heard_you") >= 1, "and it is recorded that it heard you")

	# It closes and tears at you.
	player.velocity = Vector3.ZERO
	var start := stalker.blood
	_tick(stalker, 8.0)
	check(stalker.blood < start, "reaching you costs blood (%d%%)" % roundi(stalker.blood))
	check(WorldHistory.event_count("drain_bingyanger_strike") >= 1, "every strike is recorded")
	for _second in 60:
		stalker.global_position = player.global_position
		_tick(stalker, 1.0)
	check(is_equal_approx(stalker.blood, DrainStalker.BLOOD_FLOOR), "it can bleed you to the floor and no further, like the sentinel")

	# Walk away quietly and it loses the trail.
	player.global_position = Vector3(0, 0.85, -40)
	stalker.global_position = Vector3(0, 0, -10)
	_tick(stalker, DrainStalker.LOSES_TRAIL_AFTER + 1.0)
	check(stalker.state == "prowl", "going quiet loses it")

	# The breach tool stuns it, at close range only.
	stalker.global_position = player.global_position + Vector3(12, 0, 0)
	check(not stalker.discharge(player.global_position), "the breach tool does nothing at twelve metres")
	stalker.global_position = player.global_position + Vector3(4, 0, 0)
	check(stalker.discharge(player.global_position) and stalker.state == "stunned", "at four metres it stuns it")
	var blood_before := stalker.blood
	stalker.global_position = player.global_position
	_tick(stalker, 2.0)
	check(is_equal_approx(stalker.blood, blood_before), "and a stunned bingyanger cannot hurt you")

	print("DRAIN_STALKER_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)


func _tick(stalker: DrainStalker, seconds: float) -> void:
	var step := 0.05
	var t := 0.0
	while t < seconds:
		stalker._physics_process(step)
		t += step
