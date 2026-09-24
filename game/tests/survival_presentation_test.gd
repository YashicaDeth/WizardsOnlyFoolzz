extends Node

const HUNT := preload("res://bone_yard_hunt.tscn")

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
	var hunt = HUNT.instantiate()
	add_child(hunt)
	for _settle in 24:
		await get_tree().process_frame

	var anatomy = hunt.player_rig.anatomy
	anatomy.blood_remaining = anatomy.blood_capacity * 0.30
	anatomy.consciousness = 18.0
	anatomy.pain = 76.0
	anatomy.critical = true
	anatomy.zones["torso"]["health"] = 34.0
	hunt._update_altered_perception()
	hunt._update_hud()
	check(hunt.psychedelic.dial("displacement_strength") <= 0.0061,
		"critical blood loss keeps fullscreen displacement playable")
	check(hunt.psychedelic.dial("kaleidoscope_segments") < 2.0,
		"critical blood loss never masquerades as a kaleidoscope trip")
	check(hunt.field_interface.mood_name() == "FADING",
		"the field instrument names the actual failing-consciousness state")

	hunt.pulmonary_held = true
	hunt._update_hud()
	var diagnostic: Dictionary = hunt.field_interface.pulmonary_state()
	check(is_equal_approx(float(diagnostic.get("blood", 1.0)), 0.30)
		and is_equal_approx(float(diagnostic.get("consciousness", 100.0)), 18.0)
		and is_equal_approx(float(diagnostic.get("pain", 0.0)), 76.0),
		"holding V reads the live body's blood, consciousness and pain")
	check(float((diagnostic.get("wound_regions", {}) as Dictionary).get("torso", 0.0)) > 0.60,
		"the same self-condition view reads regional anatomy damage")

	for _dose in 12:
		hunt.blood_veil.splash(1.0, Vector2.LEFT)
	check(hunt.blood_veil.marks.size() <= hunt.blood_veil.MAX_MARKS,
		"repeated close blood events cannot cover the lens beyond its new cap")
	hunt.blood_veil._process(hunt.blood_veil.DRYING + hunt.blood_veil.FADING + 0.1)
	check(hunt.blood_veil.marks.is_empty(),
		"lens blood clears within the shortened readable encounter window")

	print("SURVIVAL_PRESENTATION_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
