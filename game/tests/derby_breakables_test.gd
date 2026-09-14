extends Node

const DERBY_SCENE := preload("res://rift_derby.tscn")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	# Keep the test focused on the arena props rather than standing up twelve
	# AI drivers and the crowd. The scene's explicit test opt-in still builds
	# the same breakables the live derby creates.
	OS.set_environment("ATG_HUD_CAPTURE", "1")
	var derby: Node = DERBY_SCENE.instantiate()
	derby.include_breakables_in_test = true
	add_child(derby)
	await get_tree().physics_frame
	check(derby.breakable_props.size() == 6, "the live derby builds six breakable edge barricades")
	if derby.breakable_props.size() > 0:
		var barricade: Node = derby.breakable_props[0]
		derby.round_state = "active"
		derby._on_vehicle_impact(barricade, 14.0, 1.0)
		check(bool(barricade.get("broken")), "a player vehicle impact reaches and fractures an arena barricade")
	OS.set_environment("ATG_HUD_CAPTURE", "")
	derby.queue_free()
	print("DERBY_BREAKABLES_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
