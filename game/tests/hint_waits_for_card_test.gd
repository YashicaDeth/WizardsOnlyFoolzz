extends Node

## bughunt-79: standing up in the vat offers "E USE / OPEN / TEAR" in the same
## frame GET REVENGE plays, and the hint box sat on the card's letters. A hint
## now waits out any mission card, then shows for its full hold. The tank's
## beats ("CYCLE ABORTED // VOIDING") no longer repaint the aisle subtitle.

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
	var layer := CanvasLayer.new()
	add_child(layer)
	var card := MissionCard.new()
	layer.add_child(card)
	var hints := KeyHints.new()
	add_child(hints)
	card.play("get_revenge", "GET REVENGE", 1.0)
	hints.offer("use", KEY_E, "E", "use / open / tear")
	for _frame in 20:
		await get_tree().process_frame
	check(card.playing, "the card is still playing")
	check(not hints._panel.visible, "the hint is hidden while the card plays")
	card.skip()
	for _frame in 6:
		await get_tree().process_frame
	check(not card.playing, "the card has finished")
	check(hints._panel.visible and str(hints.current.get("id", "")) == "use", "the hint shows once the card clears")
	check(hints.age < 1.0, "the hint's hold starts after the card, not under it")

	WorldHistory.clear_history()
	var vat: Node3D = VAT.instantiate()
	add_child(vat)
	for _frame in 4:
		await get_tree().physics_frame
	vat.phase = "aisle"
	vat.line_index = -1
	vat.clock = 10.0
	vat.subtitle.text = ""
	vat._update_beats()
	check(vat.subtitle.text == "", "tank beats do not repaint the aisle subtitle (was '%s')" % vat.subtitle.text)
	vat.phase = "submerged"
	vat.clock = 1.0
	vat._update_beats()
	check(vat.subtitle.text != "", "tank beats still play while submerged")

	print("HINT_WAITS_FOR_CARD_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
