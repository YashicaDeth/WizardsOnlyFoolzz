extends Node

## dec-89 (Greg, 6 Oct night): a death on the route is a short regrowth beat
## in the vat, then you go on from the checkpoint you last filed, not the whole
## route again. The bloodstain stays where you died. With no checkpoint on file
## the old rebirth (the full tank escape) is unchanged.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	await _with_checkpoint()
	await _without_checkpoint()
	print("REGROW_TO_CHECKPOINT_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _with_checkpoint() -> void:
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"kind": "person", "name": "THE HUNTER", "status": "broke free"})
	var filer := FacilityCheckpoints.new()
	add_child(filer)
	var mark := Vector3(14.0, 0.95, -30.0)
	filer.file("service_arcade_west_door", mark)
	filer.queue_free()
	var died_at := Vector3(18.0, 0.0, -34.0)
	VatRebirth.die("service_arcade", "beaten down by CellOutz test", "v01_guard_test", died_at)
	check(VatRebirth.is_pending(), "a death on the route grows the next body")
	var chamber = load("res://vat_chamber.tscn").instantiate()
	add_child(chamber)
	await _frames(3)
	check(chamber.rebirth and chamber.regrow_to_checkpoint, "the regrowth knows a checkpoint is on file")
	check(chamber.phase == "submerged", "the beat starts in the tank (%s)" % chamber.phase)
	var stain := chamber.rebirth_site.get_node_or_null("Bloodstain_remains_1") as Node3D
	check(stain != null, "the bloodstain lies where you died")
	if stain != null:
		check(Vector2(stain.global_position.x - died_at.x, stain.global_position.z - died_at.z).length() < 0.5, "at the spot (%s)" % str(stain.global_position))
	var waited := 0.0
	while chamber.phase == "submerged" and waited < 8.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	check(waited >= 2.5 and waited <= vat_seconds(chamber) + 1.0, "the beat is short (%.1fs)" % waited)
	check(chamber.phase == "aisle" and chamber.can_move, "then you are out and moving (%s)" % chamber.phase)
	check(chamber.player.global_position.distance_to(mark) < 0.6, "at the arcade west door checkpoint (%.2f m off)" % chamber.player.global_position.distance_to(mark))
	check(not VatRebirth.is_pending() and WorldHistory.event_count("regrown_to_checkpoint") == 1, "the regrowth is complete and recorded once")
	await _frames(3)
	check(str(WorldHistory.subject(FacilityCheckpoints.SUBJECT).get("id", "")) == "service_arcade_west_door", "the checkpoint keeps its name after resuming")
	check(chamber.rebirth_site.get_node_or_null("Bloodstain_remains_1") != null, "and the stain is still there")
	chamber.queue_free()
	await _frames(3)


func _without_checkpoint() -> void:
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"kind": "person", "name": "THE HUNTER", "status": "broke free"})
	VatRebirth.die("growing_floor", "torn apart by a freed vat subject", "v01_subject", Vector3(2.0, 0.0, -6.0))
	var chamber = load("res://vat_chamber.tscn").instantiate()
	add_child(chamber)
	await _frames(3)
	check(not chamber.regrow_to_checkpoint, "no checkpoint: the old rebirth")
	var waited := 0.0
	while waited < chamber.REGROW_SECONDS + 0.6:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	check(chamber.phase != "aisle" and WorldHistory.event_count("regrown_to_checkpoint") == 0, "and you climb out of the tank yourself (%s)" % chamber.phase)
	chamber.queue_free()
	await _frames(3)


func vat_seconds(chamber: Node) -> float:
	return float(chamber.REGROW_SECONDS)


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().physics_frame
