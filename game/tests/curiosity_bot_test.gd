extends Node

## CuriosityBot on a tiny synthetic arena (`curiosity_arena.gd`):
##   1. it covers more of the grid than a random walk in the same time;
##   2. a stimulus that answers the same way every time bores it, and one that
##      says something new each time holds it longer;
##   3. a spot it cannot move out of is logged as a stuck spot.

const ARENA := preload("res://tests/curiosity_arena.gd")
const SPEED := 16.0

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	Engine.physics_ticks_per_second = int(60.0 * SPEED)
	Engine.max_physics_steps_per_frame = int(8.0 * SPEED)
	Engine.time_scale = SPEED
	await get_tree().process_frame

	# 1. Exploration beats a random walk.
	var curious := await _run({}, false, 3, 150.0)
	var random_a := await _run({}, true, 3, 150.0)
	var random_b := await _run({}, true, 11, 150.0)
	print("cells: curious=%d random=%d,%d coverage=%s%%" % [curious.cells_visited, random_a.cells_visited, random_b.cells_visited, curious.coverage_pct])
	check(curious.cells_visited > random_a.cells_visited and curious.cells_visited > random_b.cells_visited, "the curious bot stands in more grid cells than a random walk in the same 150 s")
	check(curious.cells_visited >= 50, "the curious bot reaches at least half of the 144-cell arena")

	# 2. Boredom.
	var bored := await _run({"with_beacons": true}, false, 5, 150.0)
	var bell := _kind_row(bored, "interactable:[E] RING THE BELL")
	var stranger := _kind_row(bored, "interactable:[E] ASK THE STRANGER")
	var rung := _event_count(bored, "arena_bell_rung")
	print("bell=", bell, "\nstranger=", stranger, "\nrung=", rung)
	check(rung >= 2, "the bot rang the repeating bell more than once")
	check(not bell.is_empty() and int((bell.get("left", {}) as Dictionary).get("bored", 0)) >= 1, "it walked away from the bell because it was bored")
	check(float(bell.get("boredom", 0.0)) > 0.0, "the bell's kind carries boredom afterwards")
	check(not stranger.is_empty() and float(stranger.attend_s) > float(bell.get("attend_s", 0.0)), "a stranger who says something new each time held it longer than the bell")
	var hold_bell := _event_hold(bored, "arena_bell_rung")
	var hold_story := 0.0
	for row: Dictionary in bored.events:
		if str(row.type).begins_with("arena_stranger_says"):
			hold_story += float(row.hold_s)
	check(hold_story > 0.0 and not (bored.walked_away as Array).is_empty(), "events are credited with the attention that followed them")
	var md := CuriosityBot.markdown(bored)
	check(md.contains("What it walked away from") and md.contains("RING THE BELL"), "the Markdown report names what it walked away from")
	print("hold: bell=%s stranger=%s" % [hold_bell, hold_story])

	# 3. Stuck.
	var glued := await _run({"glue_at": Vector3(-18, 1, -18)}, false, 3, 20.0)
	var blocked := 0
	for row: Dictionary in glued.stuck_spots:
		blocked += int(row.blocked)
	check(blocked >= 1, "a spot it cannot leave is logged as blocked")
	check(glued.cells_visited == 1, "the glued bot never left its cell")

	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	print("CURIOSITY_BOT_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _run(settings: Dictionary, random_walk: bool, seed_value: int, seconds: float) -> Dictionary:
	var arena := Node3D.new()
	arena.set_script(ARENA)
	for key: String in settings:
		arena.set(key, settings[key])
	add_child(arena)
	var bot := CuriosityBot.new()
	bot.random_walk = random_walk
	bot.rng.seed = seed_value
	add_child(bot)
	bot.bind(arena)
	var frames := 0
	while bot.sim_time < seconds and frames < 200000:
		await get_tree().physics_frame
		frames += 1
	var data := bot.report()
	bot.enabled = false
	bot.queue_free()
	arena.queue_free()
	await get_tree().physics_frame
	return data


func _kind_row(data: Dictionary, kind: String) -> Dictionary:
	for row: Dictionary in data.thing_kinds:
		if row.kind == kind:
			return row
	return {}


func _event_count(data: Dictionary, type: String) -> int:
	for row: Dictionary in data.events:
		if row.type == type:
			return int(row.count)
	return 0


func _event_hold(data: Dictionary, type: String) -> float:
	for row: Dictionary in data.events:
		if row.type == type:
			return float(row.hold_s)
	return 0.0
