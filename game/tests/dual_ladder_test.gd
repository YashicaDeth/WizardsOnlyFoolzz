extends Node

## K3.2 v2. Real standing on both ladders at once must cost something —
## reach specifically, not the Tree axis K3.1 deliberately leaves alone.
## Every comparison below holds *total* influence constant and only varies
## how it is split, so the penalty is isolated rather than confounded with
## "more relations means more reach" doing the work instead.

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

	# Same total influence (60), all of it on one side.
	WorldHistory.register_subject("committed", {
		"name": "Committed", "kind": "person",
		"relations": {"ashline_wreckers": {"kind": "command", "strength": 60}},
	})
	# Same total influence (60), split evenly across both — past the
	# threshold on each side.
	WorldHistory.register_subject("split_evenly", {
		"name": "Split Evenly", "kind": "person",
		"relations": {
			"ashline_wreckers": {"kind": "command", "strength": 30},
			"wizardsonlyfoolz": {"kind": "command", "strength": 30},
		},
	})
	# Same total influence (35) as the dabbler below, but all on one side —
	# the control for proving a small toe in the other ladder is not enough.
	WorldHistory.register_subject("committed_35", {
		"name": "Committed 35", "kind": "person",
		"relations": {"ashline_wreckers": {"kind": "command", "strength": 35}},
	})
	WorldHistory.register_subject("dabbling", {
		"name": "Dabbling", "kind": "person",
		"relations": {
			"ashline_wreckers": {"kind": "command", "strength": 30},
			"wizardsonlyfoolz": {"kind": "command", "strength": 5},
		},
	})

	var wire := WireNet.new()
	var committed_reach := int(wire.account("committed").reach)
	var split_reach := int(wire.account("split_evenly").reach)
	var committed_35_reach := int(wire.account("committed_35").reach)
	var dabbling_reach := int(wire.account("dabbling").reach)

	check(split_reach < committed_reach, "the same total influence, split across both ladders past the threshold, reaches less (%d < %d)" % [split_reach, committed_reach])
	check(is_equal_approx(float(split_reach), float(committed_reach) * WireNet.DUAL_LADDER_PENALTY), "by exactly the stated penalty factor, not an arbitrary number (%d vs committed*%.1f)" % [split_reach, WireNet.DUAL_LADDER_PENALTY])
	check(dabbling_reach == committed_35_reach, "the same total influence, mostly on one side with only a small toe in the other, is not penalised at all (%d == %d)" % [dabbling_reach, committed_35_reach])

	print("DUAL_LADDER_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
