extends Node

## P1.1/P2.4. `OpeningDirector.advance()` used to have no caller anywhere in
## real gameplay, only in tests that called it directly — so `stage()` never
## left "none" during an actual playthrough and a resumed run always sent the
## player back to the Growing Floor. This drives the three production
## transitions through the same `Interstitial.travel()` chokepoint the real
## scenes use, with no test-only shortcut, and checks the stage the game
## itself recorded.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	# The tree is still assembling this very test node when `_ready` fires;
	# `root.add_child` refuses while that is in progress.
	await get_tree().process_frame
	# Godot loaded this test node itself as `current_scene`. `Interstitial.travel()`
	# frees whatever `current_scene` is at the moment it is called, and this node
	# would be freed out from under its own running coroutine on the first travel
	# call. Hand `current_scene` to a throwaway node so travel frees that instead.
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	WorldHistory.clear_history()
	check(OpeningDirector.stage() == "none", "a fresh run starts at stage none")

	await Interstitial.travel("res://vat_chamber.tscn", "the growing floor // decanting")
	check(OpeningDirector.reached("woke"), "arriving at the Growing Floor records woke")

	await Interstitial.travel("res://rift_derby.tscn", "the bone yard // heat one")
	check(OpeningDirector.reached("entered_pit"), "arriving at the derby records entered_pit")
	check(not OpeningDirector.reached("won_derby"), "the heat is not won just by entering it")
	check(str(OpeningDirector.resume_destination().scene) == "res://rift_derby.tscn",
		"an unfinished heat still resumes at the real derby, wired from actual play")

	await Interstitial.travel("res://bone_yard_hunt.tscn", "walking out into the ashbloom expanse")
	check(OpeningDirector.reached("won_derby"), "arriving at the Hunt Grounds records won_derby")
	check(str(OpeningDirector.resume_destination().scene) == "res://bone_yard_hunt.tscn",
		"resuming now skips straight past the derby, wired from actual play")

	print("OPENING_STAGE_WIRING_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
