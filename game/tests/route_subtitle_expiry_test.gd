extends Node

## bughunt-79: once on your feet, a one-off subtitle (the fight teacher's
## "RED GLINT" line, a pickup, a door) clears itself instead of riding the
## lifts to the surface gate. A new line restarts the hold.

const VAT := preload("res://vat_chamber.tscn")

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
	var vat: Node3D = VAT.instantiate()
	add_child(vat)
	for _frame in 4:
		await get_tree().physics_frame
	vat.phase = "aisle"
	vat.breakout_complete = true
	vat.can_move = true
	if vat.intake != null:
		vat.intake.visible = false
	vat.line_index = vat.active_beats.size()
	var subtitle: Label = vat.subtitle
	subtitle.text = "RED GLINT  //  STEP OUT OR DODGE (B / SPACE)"
	await _seconds(vat.SUBTITLE_HOLD * 0.5)
	check(subtitle.text.begins_with("RED GLINT"), "a fresh line stays up long enough to read")
	subtitle.text = "THE PIT DOOR  //  A CARD READER, RED"
	await _seconds(vat.SUBTITLE_HOLD * 0.7)
	check(subtitle.text.begins_with("THE PIT DOOR"), "a new line restarts the hold")
	await _seconds(vat.SUBTITLE_HOLD * 0.6)
	check(subtitle.text.is_empty(), "then it clears instead of sticking for the rest of the run")
	print("ROUTE_SUBTITLE_EXPIRY_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _seconds(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()
