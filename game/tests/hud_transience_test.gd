extends Node

## M1.6 verification. The location crest and hunt thread were permanent
## fixtures regardless of whether they had anything current to say — this
## checks both now clear themselves the same way I0.6 already made the
## derby's own HUNT SIGNAL plate behave.

const GothicFieldHud := preload("res://systems/gothic_field_hud.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	var hud := GothicFieldHud.new()
	add_child(hud)

	# --- the location crest announces once, then clears on its own ---------
	check(hud.location_announce == 0.0, "the crest starts with nothing to announce")
	hud.set_state({"location": "LIMBO // ASHBLOOM EXPANSE"})
	check(hud.location_announce > 0.0, "a first location sets a real arrival to announce")
	hud._process(GothicFieldHud.LOCATION_ANNOUNCE_TIME + 1.0)
	check(hud.location_announce == 0.0, "and it clears on its own rather than sitting there permanently")

	# Re-stating the same location is not a fresh arrival.
	hud.set_state({"location": "LIMBO // ASHBLOOM EXPANSE"})
	check(hud.location_announce == 0.0, "reporting the same location again does not re-trigger the announcement")

	# A genuinely new one does.
	hud.set_state({"location": "THE OSSUARY WORKS"})
	check(hud.location_announce > 0.0, "but an actual change to a new place announces again")

	# --- the hunt thread only exists while there is a hunt to report -------
	hud.set_state({"rival_status": "dormant"})
	check(hud.rival_status == "DORMANT", "dormant is read and normalised")
	hud.set_state({"rival_status": "hunting"})
	check(hud.rival_status == "HUNTING", "and a real status is read the same way")

	print("HUD_TRANSIENCE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
