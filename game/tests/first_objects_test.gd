extends Node
## AX3.1 and AX3.2 on the Growing Floor: the broken restraint you tore out of
## the vat is the first thing you use (it pries the stuck tank), and the
## clothing you first wear comes off the dead failed subject inside it.

const VAT := preload("res://vat_chamber.tscn")
var failures := 0


func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	failures += int(not condition)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var vat = VAT.instantiate()
	add_child(vat)
	await get_tree().process_frame
	vat.intake._finish_filing()
	await get_tree().process_frame
	vat.departure_clock = vat.DEPARTURE_SECONDS
	vat._update_departure(0.0)
	vat.clock = vat.DRAINED_AT
	vat.phase = "voiding"
	vat._update_sequence(0.05)
	while not vat.umbilicals.is_empty():
		for _tug in vat.WIRE_TUGS:
			vat._tug_wire(vat.umbilicals[0])
	vat._physics_process(vat.REVENGE_HOLD + 0.1)
	for _step in 80:
		if vat.can_move:
			break
		vat._physics_process(0.1)
	check(vat.can_move, "out of the tank and standing")
	check(vat._carries_restraint(), "the broken restraint came out of the vat with you")
	check(Clothing.worn("player") == "bare", "you come out wearing nothing")

	# Away from it, nothing happens.
	vat.player.global_position = vat.stuck_tank_marker.global_position + Vector3(8, 0, 0)
	check(not vat._try_pry_stuck_tank(), "the stuck tank cannot be pried from across the room")
	check(not vat._try_take_garment(), "and nothing can be taken from a tank that is still shut")

	vat.player.global_position = vat.stuck_tank_marker.global_position + Vector3(1.5, 0, 0)
	check(vat._try_pry_stuck_tank(), "the restraint pries the stuck tank open")
	check(WorldHistory.event_count("opening_first_object_used") == 1, "filed as the first object used")
	check(not vat._try_pry_stuck_tank(), "and it only opens once")

	check(vat._try_take_garment(), "the failed subject's clothing can be taken")
	check(Clothing.worn("player") == "humiliation_smock", "you are wearing the humiliation smock (%s)" % Clothing.worn("player"))
	check(Clothing.worn(vat.FAILED_SUBJECT_ID) == "bare", "and the dead subject is left bare")
	check(not vat._try_take_garment(), "dressed, there is nothing more to take")
	vat.queue_free()
	print("FIRST_OBJECTS_TEST_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
