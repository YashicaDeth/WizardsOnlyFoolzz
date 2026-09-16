extends Node

## I3.1/I3.2. Every Black Mirror app inherits one chassis-owned page grammar,
## and the page behind the glass may change only while the work surface is
## fully hidden by the physical shutter.

const HANDHELD := preload("res://systems/handheld_device.gd")

var failures: Array[String] = []
var emitted_modes: Array[String] = []


func _check(condition_met: bool, what: String) -> void:
	if condition_met:
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

	var device: Control = HANDHELD.new()
	add_child(device)
	device.set_process(false)
	device.size = Vector2(1280, 720)
	device.open_device()
	for _frame in 20:
		device._process(0.05)

	var aperture: Rect2 = device._page_rect
	var content: Rect2 = device._content_rect
	_check(content.position.x > aperture.position.x and content.position.y > aperture.position.y, "the common work surface begins inside the chassis-owned header and side rails")
	_check(content.end.x < aperture.end.x and content.end.y < aperture.end.y, "the common work surface ends before the chassis-owned footer and side rails")
	for mode in device.MODES:
		var contract: Dictionary = device.page_contract(mode)
		_check(str(contract.role) != "" and str(contract.action) != "", "%s declares its role and primary physical verb" % mode)
		_check(int(contract.index) == device.MODES.find(mode) + 1 and int(contract.count) == device.MODES.size(), "%s occupies one stable numbered place in the seven-page object" % mode)

	device.mode_changed.connect(func(mode: String) -> void: emitted_modes.append(mode))
	device.set_mode("MAP")
	_check(device.current_mode() == "MAP" and device.displayed_mode() == "INDEX", "requesting MAP changes the destination but leaves INDEX physically visible")
	_check(emitted_modes.is_empty(), "requesting a page does not emit a visible page change before movement")

	device._advance_page_transition(device.PAGE_TRANSITION_SECONDS * 0.25)
	_check(device.displayed_mode() == "INDEX", "the old page remains visible while the shutter enters")
	_check(device.page_transition_coverage() > 0.0 and device.page_transition_coverage() < 1.0, "the entering shutter partially covers the common work surface")

	device._advance_page_transition(device.PAGE_TRANSITION_SECONDS * 0.25)
	_check(is_equal_approx(device.page_transition_coverage(), 1.0), "the shutter reaches full occlusion at the midpoint")
	_check(device.displayed_mode() == "MAP", "the destination page is activated only under full occlusion")
	_check(emitted_modes == ["MAP"], "the visible page-change signal fires exactly at the hidden midpoint")

	device._advance_page_transition(device.PAGE_TRANSITION_SECONDS * 0.5)
	_check(device.pending_mode_index == -1 and is_zero_approx(device.page_transition_coverage()), "the shutter leaves the new page fully uncovered")
	_check(device.displayed_mode() == "MAP", "MAP remains physically present after the transition")

	device.set_mode("INDEX")
	_check(device.page_transition_direction < 0.0, "travelling backward through the object reverses the shutter")
	device._advance_page_transition(device.PAGE_TRANSITION_SECONDS)
	_check(device.displayed_mode() == "INDEX", "a reverse transition also changes pages only through the physical mechanism")

	print("HANDHELD_PAGE_GRAMMAR_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
