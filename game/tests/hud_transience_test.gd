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
	# A frame at the design resolution, because both sections below are about
	# geometry: a bare HUD under a plain Node inherits the 64x64 headless
	# viewport and every layout answer would be about the wrong screen.
	var frame := Control.new()
	frame.name = "Frame"
	add_child(frame)
	frame.size = Vector2(1600, 900)
	var hud := GothicFieldHud.new()
	frame.add_child(hud)
	# The scene places this panel with full-rect anchors and a bare `new()` has
	# no size at all; without this every rect below would be measured on a 0x0
	# screen, which is exactly the kind of gate that passes by measuring nothing.
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	frame.size = Vector2(1600, 900)
	check(not hud.location_crest_enabled, "the old centred location banner stays out of field play")

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

	# --- slice 15: the corner is one instrument and one column of words -----
	# Before this the corner hung three near-identical screens and placed its
	# readouts off three different anchors, so at any real injury the lost-run
	# tag printed straight through the bleed tag.
	hud.set_state({"health": 40.0, "blood": 0.31, "stamina": 22.0, "pain": 61.0, "consciousness": 34.0})
	await get_tree().process_frame
	var monitors: Array[Rect2] = hud.nerve_rig.monitor_rects()
	check(monitors.size() == 1, "the top-right hangs one monitor rather than three (%d)" % monitors.size())
	var rows: Array[Rect2] = hud.nerve_rig.readout_rects()
	check(rows.size() >= 3, "a hurt body still says its mood, its pain and its bleed (%d rows)" % rows.size())
	var overlaps := 0
	for a in rows.size():
		for b in range(a + 1, rows.size()):
			if rows[a].intersects(rows[b]):
				overlaps += 1
	check(overlaps == 0, "and no two of its readouts print over each other (%d overlaps)" % overlaps)
	var off_screen := 0
	for rect in rows:
		if not Rect2(Vector2.ZERO, hud.size).encloses(rect):
			off_screen += 1
	check(off_screen == 0, "every readout is inside the frame (%d off screen in %s on %s)" % [off_screen, hud.size, frame.size])

	# --- slice 16: the condition line stays out of the prompt's band --------
	# It sat at size.y - 110, inside the 78px band the scene's prompt label
	# occupies, so a wrapped prompt and any window under the design size put the
	# two in the same pixels. Measured at the design size and at the layout floor.
	for band_size in [Vector2(1600, 900), Vector2(1280, 720), Vector2(640, 400)]:
		frame.size = band_size
		await get_tree().process_frame
		var reserve: Rect2 = hud.prompt_reserve()
		var condition: Rect2 = hud.condition_rect()
		check(not condition.intersects(reserve),
			"the condition line clears the prompt band at %dx%d (%.0f versus %.0f)" % [band_size.x, band_size.y, condition.end.y, reserve.position.y])

	print("HUD_TRANSIENCE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
