extends Node

## Item 4: the blob tracker takes hits and watchers, caps both, and lets hit
## markers expire on their own.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var tracker := BlockTracker.new()
	add_child(tracker)
	tracker.report_hit(Vector3(0, 1, -3), "left_arm", 26.0, "cut")
	check(tracker.hits.size() == 1 and str(tracker.hits[0].zone) == "left_arm", "a hit becomes a tracked marker on its zone")
	for index in 20:
		tracker.report_hit(Vector3.ZERO, "torso", 5.0, "blunt")
	check(tracker.hits.size() == BlockTracker.MAX_HITS, "markers are capped so a flurry never floods the screen")
	tracker._process(BlockTracker.HIT_LIFE + 0.1)
	check(tracker.hits.is_empty(), "markers expire on their own")
	var many: Array = []
	for index in 12:
		many.append({"at": Vector3(index, 0, -5), "certainty": 1.0})
	tracker.watch(many)
	check(tracker.watchers.size() == BlockTracker.MAX_WATCHERS, "awareness boxes are capped too")
	print("BLOCK_TRACKER_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
