extends Node

## AI2.4. "The Board's theories pin onto the pyramid — the two charts are
## one document." `_theories_naming()` is the pure-data half of that (which
## published theories name a given subject); the pin actually landing on
## the right row on screen is the windowed half, same split
## `double_pyramid_test.gd`/`_capture.gd` already draw for the rest of this
## page.

const WORLD_INDEX := preload("res://systems/world_index.gd")
const PIN_BOARD := preload("res://systems/pin_board.gd")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})
	WorldHistory.register_subject("mara_voss", {"name": "Mara Voss", "kind": "person"})
	var index: Control = WORLD_INDEX.new()
	add_child(index)
	await get_tree().process_frame

	print("AI2.4 - nothing published yet reads as nothing pinned, not a crash")
	_check(index._theories_naming("mara_voss").is_empty(), "an unpublished subject has no pins")

	print("AI2.4 - a real publish() on the Board is what lights the pin here")
	var board := PIN_BOARD.new()
	add_child(board)
	await get_tree().process_frame
	# Wire the actual mechanism rather than hand-writing the WorldHistory
	# record: pin a card, string it to a theory, and publish through the
	# real publish() so this test proves the two screens agree because they
	# read the same subject, not because this test assumes the shape of it.
	WorldHistory.record_event("carried_part", {"subject": "mara_voss"})
	board.pin("mara_voss", "person")
	board.pin("theory_ownership", "theory")
	board.lay_string("mara_voss", "theory_ownership")
	var result := board.publish("theory_ownership")
	_check(bool(result.get("ok", false)), "publish() actually went through (%s)" % str(result.get("headline", "")))
	var target := str(result.get("target", ""))
	var claims: Array = index._theories_naming(target)
	_check(not claims.is_empty(), "the subject publish() actually named now carries a real pin")
	if not claims.is_empty():
		_check(str(claims[0].get("title", "")) == "IT IS A DEBT", "...and it is the real theory's title, not a placeholder")
		_check(claims[0].get("sound", null) == bool(result.get("sound", true)), "...and carries the same sound/unsound verdict publish() actually returned")

	print("AI2.4 - a retraction clears the pin for free, off the same record")
	var retracted := board.retract("theory_ownership")
	_check(bool(retracted.get("ok", false)), "retract() actually went through")
	_check(index._theories_naming(target).is_empty(), "the pin is gone the instant the Board record says the theory is off the wall")

	print("PYRAMID_PIN_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
