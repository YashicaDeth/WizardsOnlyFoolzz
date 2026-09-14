extends Node

## C10.2. The night-reading treatment belongs to the device aperture, not to
## any individual app. Prove the colour floor and prove all six modes retain
## the same surface while switching between hosted and device-native content.

const HANDHELD := preload("res://systems/handheld_device.gd")
const MIRROR := preload("res://systems/black_mirror.gd")

var failures: Array[String] = []


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

	_check(MIRROR.reading_contrast(HANDHELD.INK) >= 10.0, "primary bone ink clears the phosphor bed")
	_check(MIRROR.reading_contrast(HANDHELD.MOSS, 0.90) >= 4.5, "moss instruments clear it at their working opacity")
	_check(MIRROR.reading_contrast(HANDHELD.AMBER, 0.90) >= 3.0, "copper registration remains distinct without becoming white")

	var device: Control = HANDHELD.new()
	add_child(device)
	device.set_process(false)
	device.size = Vector2(1280, 720)
	device.open_device()
	for _frame in 20:
		device._process(0.05)
	var shared_surface: Rect2 = device._page_rect
	for mode in device.MODES:
		device.set_mode(mode)
		device._process(0.05)
		_check(device._page_rect.is_equal_approx(shared_surface), "%s uses the shared night-reading surface" % mode)

	_check(shared_surface.position.x > device._screen_rect.position.x, "reflective black glass remains visible beside the reading surface")
	print("HANDHELD_DARK_LEGIBILITY_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
