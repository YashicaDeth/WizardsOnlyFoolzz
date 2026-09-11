extends Node

## I6. The Wire is hostile by design and the player's own tools are not. The
## contrast is the satire, so it has to be a real difference in behaviour
## rather than a line of copy — this asserts the two actually differ on every
## property they claim to.

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
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})
	var wire = preload("res://systems/wire_net.gd").new()
	wire.rebuild()

	# I6.1 — infinite scroll. Twenty pages deep and it still has more.
	var empty_pages := 0
	for page in 20:
		var pull: Dictionary = wire.pull_feed(page)
		if (pull.posts as Array).is_empty():
			empty_pages += 1
	check(empty_pages == 0, "the feed never runs out (%d empty pages in 20)" % empty_pages)

	# And it costs something. Being in the feed is being seen in it.
	check(wire.exposure > 0, "scrolling costs exposure (%d)" % wire.exposure)
	check(wire.strain > 0.0, "and it wears the connection down")

	# I6.1 — variable reward: some pulls carry a lead, most do not. Both halves
	# matter; a feed that always pays is not a dark pattern and one that never
	# pays is not a trap.
	var rewarded := 0
	for page in 60:
		if not (wire.pull_feed(page).lead as Dictionary).is_empty():
			rewarded += 1
	check(rewarded > 0, "some pulls pay out (%d of 60)" % rewarded)
	check(rewarded < 60, "and most do not")

	# I6.2 / I6.3 — the two contracts differ on every property.
	var tool: Dictionary = wire.tool_contract()
	var feed: Dictionary = wire.feed_contract()
	var differences := 0
	for key in tool:
		if tool[key] != feed[key]:
			differences += 1
	check(differences == tool.size(), "the player's tools differ from the feed on every property (%d/%d)" % [differences, tool.size()])
	check(bool(tool.finite) and not bool(feed.finite), "your tools end; the feed does not")
	check(not bool(tool.costs_exposure) and bool(feed.costs_exposure), "your tools are free to open; the feed is not")
	check(str(tool.reward_schedule) == "none" and str(feed.reward_schedule) == "intermittent", "your tools do not gamble with you")

	print("DARK_PATTERN_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
