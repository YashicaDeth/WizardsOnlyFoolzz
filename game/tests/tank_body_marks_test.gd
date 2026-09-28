extends Node
## Greg's checklist: your intake answers grow marks on your body, the same
## answers the same body.

var failures := 0


func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	failures += int(not condition)


func _body(subject: Dictionary) -> Dictionary:
	var rig := BaselineHuman.new()
	add_child(rig)
	rig.build("marks_probe", BaselineHuman.config_from_subject(subject))
	var made: Dictionary = preload("res://systems/tank_body_marks.gd").dress(rig, subject)
	rig.queue_free()
	return made


func _ready() -> void:
	var plain := {"race": "decanted", "traits": [], "pre_owned_organs": [], "appearance": {"mutation": 0.0, "wear": 0.2}}
	var worked := {"race": "decanted", "traits": ["a", "b", "c"], "pre_owned_organs": ["kidney", "eye"], "examination_refusals": 2, "appearance": {"mutation": 0.8, "wear": 0.9}}
	var a := _body(plain)
	var b := _body(worked)
	check(int(a.seams) >= 1 and int(a.growths) >= 1, "every grown body carries at least a seam and a growth")
	check(int(b.seams) > int(a.seams), "second-hand organs and refusals mean more seams (%d > %d)" % [b.seams, a.seams])
	check(int(b.growths) > int(a.growths), "more traits, more growths")
	check(int(b.patches) > int(a.patches), "more wear, more patches")
	check(int(b.wrong) >= 2 and int(a.wrong) == 0, "a high mutation dial grows wrong parts; none at zero")
	check(_body(worked) == b, "the same answers grow the same body")
	print("TANK_BODY_MARKS_TEST_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
