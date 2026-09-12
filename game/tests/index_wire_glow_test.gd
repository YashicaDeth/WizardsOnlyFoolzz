extends Node

## I1.5 v2. The code rain behind the World Index used to run full time behind
## every page - FILE, PYRAMID and BODY included, not only WIRE - which made it
## decoration this screen paid for on every page rather than the Wire's own
## substrate. `_wire_glow` should ease toward 1 only while PAGES[page] ==
## "WIRE" and back toward 0 on every other page.

const WORLD_INDEX := preload("res://systems/world_index.gd")

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
	var index: Control = WORLD_INDEX.new()
	add_child(index)
	await get_tree().process_frame
	index.open()

	_check(is_equal_approx(index._wire_glow, 0.0), "starts on FILE with no wire glow")
	index.page = index.PAGES.find("WIRE")
	for frame in 40:
		index._process(0.05)
	_check(index._wire_glow > 0.9, "the wire page eases the glow up (%.2f)" % index._wire_glow)

	index.page = index.PAGES.find("BODY")
	for frame in 40:
		index._process(0.05)
	_check(index._wire_glow < 0.1, "leaving the wire page eases the glow back down (%.2f)" % index._wire_glow)

	print("INDEX_WIRE_GLOW_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
