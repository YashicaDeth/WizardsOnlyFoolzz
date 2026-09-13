extends Node

## E2.4 cutscene gap. `begin_burn`/`begin_bind` took one seed and ran one
## animation; "each and every" named a sequence that did not exist. This
## drives `begin_full_sequence()` end to end without waiting on real frame
## timing — `_process()` is called directly with a delta bigger than each
## seal's own duration, the same fast-forward `handheld_lean_test.gd` already
## uses on `HandheldDevice`, so 72 real bakes run in a handful of test frames
## rather than the genuine seconds the cutscene will actually take.

const MOTHERBOARD := preload("res://systems/motherboard.gd")
const GOETIC_SEALS := preload("res://systems/goetic_seals.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var board := MOTHERBOARD.new()
	board._ready()

	var started: Array[Dictionary] = []
	# A boxed int rather than a bare local — a lambda closes over a plain
	# `int` by value in GDScript, so `finished_count += 1` inside one would
	# silently mutate a copy nobody outside the lambda ever sees.
	var finished_count := [0]
	board.sequence_seal_started.connect(func(index: int, total: int, entry: Dictionary) -> void:
		started.append({"index": index, "total": total, "name": str(entry.get("name", ""))}))
	board.sequence_finished.connect(func() -> void: finished_count[0] += 1)

	# `begin_burn`/`begin_bind` floor `anim_duration` at 0.2s regardless of
	# what is asked for, so the fast-forward step below has to clear that
	# floor, not just `per_seal` itself.
	var per_seal := 0.2
	board.begin_full_sequence("burn", per_seal)
	check(board.is_running_sequence(), "starting the sequence actually leaves it running")
	check(started.size() == 1, "the first demon's own start fires synchronously, before any process tick (%d)" % started.size())

	# One step per seal, each big enough to clear that seal's own duration and
	# trigger its bake — which is what chains straight into the next one.
	var total_goetia := GOETIC_SEALS.GOETIA.size()
	for _tick in total_goetia + 4: # margin; the loop below stops itself once finished
		if not board.is_running_sequence():
			break
		board._process(per_seal + 0.05)

	check(total_goetia == 72, "the roster this is walking is genuinely all 72 (%d)" % total_goetia)
	check(started.size() == total_goetia, "every single one of them actually started, not just the first (%d of %d)" % [started.size(), total_goetia])
	check(finished_count[0] == 1, "sequence_finished fires exactly once, not once per seal (%d)" % finished_count[0])
	check(not board.is_running_sequence(), "and the sequence genuinely stops rather than idling at the end")
	check(board.burnt_seals.size() == total_goetia, "every one of them left a real permanent bake behind (%d)" % board.burnt_seals.size())

	var order_matches := true
	for index in started.size():
		if str(started[index].get("name", "")) != str(GOETIC_SEALS.GOETIA[index].get("name", "")):
			order_matches = false
			break
	check(order_matches, "the walk is in Mathers' own listed order, not shuffled")

	var seeds := {}
	for record: Dictionary in board.burnt_seals:
		seeds[int(record.get("seed", 0))] = true
	check(seeds.size() == total_goetia, "72 distinct names burnt 72 distinct shapes, not one seal repeated 72 times (%d unique seeds)" % seeds.size())

	# A second run has to be a second run, not additional noise piled onto an
	# already-finished one.
	started.clear()
	finished_count[0] = 0
	board.begin_full_sequence("burn", per_seal)
	check(started.size() == 1 and str(started[0].get("name", "")) == str(GOETIC_SEALS.GOETIA[0].get("name", "")), "calling it again restarts cleanly from Bael")

	board.free()

	if failures.is_empty():
		print("motherboard sequence: each and every one of them, in order, for real")
		get_tree().quit(0)
	else:
		print("motherboard sequence FAILURES: ", failures)
		get_tree().quit(1)
