extends Node

## Greg, 5 Oct: the examiner on the intake feed is the rigged base, not the
## generated skin, and his lip sync still moves his mouth.

const FEED := preload("res://systems/examiner_feed.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	var feed: Control = FEED.new()
	feed.size = Vector2(320, 240)
	add_child(feed)
	for _frame in 5:
		await get_tree().process_frame
	check(feed.rig != null and feed.rig.rigged != null, "the feed's examiner is the rigged base")
	check(feed.rig.get_node_or_null("ModelSkin") == null, "and wears no generated skin")
	var lower: Node3D = feed._lip_lower
	check(lower != null, "he has a lower lip to sync")
	var rest: Vector3 = feed._rest.get(lower, Vector3.ZERO)
	var opened := 0.0
	for _frame in 20:
		feed.say("Blink. Aaa", true)
		await get_tree().process_frame
		opened = maxf(opened, rest.y - lower.position.y)
	check(opened > 0.003, "saying a line opens his mouth (%.4f)" % opened)
	print("EXAMINER_FEED_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
