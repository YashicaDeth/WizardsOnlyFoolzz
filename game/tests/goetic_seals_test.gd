extends Node

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var seals := GoeticSeals.all()
	check(seals.size() == 72, "the catalogue has all seventy-two entries")
	check(str(seals[0].name) == "BAEL" and str(seals[71].name) == "ANDROMALIUS", "the roster keeps its historical endpoints")
	check(str(GoeticSeals.find(50).rank) == "KNIGHT", "rank data survives as data rather than display copy")
	var marks: Dictionary = {}
	for seal in seals:
		var id := int(seal.id)
		var strokes: Array = seal.strokes
		check(not strokes.is_empty(), "seal %02d has a drawable mark" % id)
		var same_again: Array = GoeticSeals.strokes_for(id)
		check(str(strokes) == str(same_again), "seal %02d remains stable" % id)
		marks[str(strokes)] = true
	check(marks.size() == 72, "every roster entry has a distinct project-native mark")
	check(GoeticSeals.find(0).is_empty() and GoeticSeals.find(73).is_empty(), "out-of-range seals do not invent data")
	print("GOETIC_SEALS_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
