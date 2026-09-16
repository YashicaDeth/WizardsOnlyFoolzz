extends Node

## C1.7 regression: physical drop and deliberate re-decant were both on K,
## allowing one press in captivity to perform two irreversible actions.

const HANDHELD := preload("res://systems/handheld_device.gd")
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
	check(HANDHELD.DROP_KEY == KEY_DELETE, "dropping the device uses the dedicated Delete key")
	check(HANDHELD.DROP_KEY != KEY_K, "drop no longer shares the irreversible re-decant binding")

	var hunt = HUNT.instantiate()
	add_child(hunt)
	await get_tree().process_frame
	var rows: Array = []
	for group: Dictionary in hunt.keys_card.groups:
		rows.append_array(group.get("rows", []))
	check(rows.any(func(row: Array): return row[0] == HANDHELD.DROP_KEY_LABEL and row[1] == "DROP DEVICE"), "the in-world keys card teaches the new drop binding")
	check(rows.any(func(row: Array): return row[0] == "K" and "RE-DECANT" in row[1]), "K remains honestly labelled for its one surviving action")
	check(rows.filter(func(row: Array): return row[0] == "K").size() == 1, "the card contains no second hidden K action")

	print("HANDHELD_CONTROL_BINDING_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
