extends Node

## I4. The interface is a thing a bleeding person is holding. This asserts the
## signal comes from the body rather than from a separate UI state, that a
## healthy player gets a clean screen, and that it is bounded — a panel that
## degrades without limit is unreadable rather than atmospheric.

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

	# No body recorded yet: clean, not broken.
	check(is_equal_approx(VitalitySignal.severity(), 0.0), "a player with no recorded body reads a clean screen")

	WorldHistory.update_subject("player", {"anatomy_state": {
		"blood": 5000.0, "blood_capacity": 5000.0, "pain": 0.0, "consciousness": 100.0,
	}})
	check(is_equal_approx(VitalitySignal.severity(), 0.0), "an unhurt player reads a clean screen")

	# A scratch must not break the readout — that is what the floor is for.
	WorldHistory.update_subject("player", {"anatomy_state": {
		"blood": 4850.0, "blood_capacity": 5000.0, "pain": 4.0, "consciousness": 99.0,
	}})
	check(VitalitySignal.severity() <= 0.02, "a scratch does not break the readout")

	var scratched := VitalitySignal.severity()
	WorldHistory.update_subject("player", {"anatomy_state": {
		"blood": 2600.0, "blood_capacity": 5000.0, "pain": 55.0, "consciousness": 52.0,
	}})
	var hurt := VitalitySignal.severity()
	check(hurt > scratched, "bleeding degrades it (%.2f -> %.2f)" % [scratched, hurt])

	WorldHistory.update_subject("player", {"anatomy_state": {
		"blood": 700.0, "blood_capacity": 5000.0, "pain": 96.0, "consciousness": 6.0,
	}})
	var dying := VitalitySignal.severity()
	check(dying > hurt, "and going under degrades it further (%.2f)" % dying)
	check(dying <= 1.0, "but it is bounded, so the panel never vanishes")
	check(VitalitySignal.ink(dying) >= 0.35, "the ink fades but stays legible")

	# Consciousness dominates blood, because a clear head can still read.
	WorldHistory.update_subject("player", {"anatomy_state": {
		"blood": 1200.0, "blood_capacity": 5000.0, "pain": 10.0, "consciousness": 95.0,
	}})
	var clear_headed := VitalitySignal.severity()
	WorldHistory.update_subject("player", {"anatomy_state": {
		"blood": 4200.0, "blood_capacity": 5000.0, "pain": 10.0, "consciousness": 20.0,
	}})
	var fading := VitalitySignal.severity()
	check(fading > clear_headed, "losing consciousness costs more than losing blood (%.2f > %.2f)" % [fading, clear_headed])

	# Wire strain degrades a healthy player's panel too — it is the signal, not
	# only the body.
	WorldHistory.update_subject("player", {"anatomy_state": {
		"blood": 5000.0, "blood_capacity": 5000.0, "pain": 0.0, "consciousness": 100.0,
	}})
	check(VitalitySignal.severity(0.9) > 0.0, "a bad signal degrades a healthy player's panel")

	# Jitter is derived, bounded and still when clean.
	check(VitalitySignal.jitter(0.0, 1, 2.0) == Vector2.ZERO, "a clean panel does not move")
	check(VitalitySignal.jitter(1.0, 1, 2.0).length() < 3.0, "and a failing one wanders rather than swims")

	# --- I1: the rain is material, and it is this world's material ---------
	var columns: Array = CodeRain.build(400.0, 300.0, 26.0, 11)
	check(columns.size() > 10, "the rain builds columns across the width (%d)" % columns.size())
	var vocabulary_ok := true
	for column in columns:
		if not CodeRain.WORDS.has(column.word):
			vocabulary_ok = false
	check(vocabulary_ok, "every column carries a word from the game's own vocabulary")
	check(CodeRain.WORDS.has("CELLOUTZ") and CodeRain.WORDS.has("SPINE") and CodeRain.WORDS.has("GRUDGE"), "the vocabulary is anatomy, factions and the ledger")

	# It falls, and it wraps rather than running off forever.
	var before: float = columns[0].head
	CodeRain.advance(columns, 0.5, 300.0)
	check(columns[0].head > before, "the rain falls")
	for step in 200:
		CodeRain.advance(columns, 0.5, 300.0)
	var in_bounds := true
	for column in columns:
		if column.head > 460.0:
			in_bounds = false
	check(in_bounds, "and wraps rather than leaving the field")

	print("VITALITY_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
