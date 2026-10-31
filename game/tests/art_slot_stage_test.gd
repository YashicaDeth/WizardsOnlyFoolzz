extends Node

## Cutscene art slots (Greg, 2026-09-24): every slot has a place and a neutral
## placeholder until
## a PNG with its name is dropped into art/cutscene/, then that file is used.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var stage: ArtSlotStage = load("res://cutscenes/art_slot_stage.tscn").instantiate()
	add_child(stage)
	await get_tree().process_frame
	for slot in ArtSlotStage.SLOTS:
		check(stage.slot_rect(str(slot)).size.x > 0.0 and stage.slot_rect(str(slot)).size.y > 0.0, "slot %s has a place on the stage" % slot)
		check(stage.is_authored(str(slot)) == ResourceLoader.exists(ArtSlotStage.ART_DIR + str(slot) + ".png"), "slot %s uses Greg's file exactly when it exists" % slot)
	print("ART_SLOT_STAGE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
