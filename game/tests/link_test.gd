extends Node

## I5. Everything printed on the index is pointable, and following a link moves
## the panel to the page that already shows the thing rather than opening a
## window over it — rule 3, no hard cuts, no modals.

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
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})
	WorldHistory.register_subject("mara_voss", {
		"name": "MARA VOSS", "kind": "person", "faction_id": "ashline_wreckers",
		"injury": "crushed left arm", "wounds": ["cut right leg"],
		"anatomy_state": {"cybernetics": {"left_arm": {"name": "ashline industrial arm", "condition": 140.0}}},
	})

	var index = preload("res://systems/world_index.gd").new()
	add_child(index)
	index.size = Vector2(1280, 720)
	index.open()
	index.page = 0
	# The plate is drawn behind an open blend; without it _draw returns early
	# and nothing is printed, so nothing is clickable.
	index.open_blend = 1.0
	index.rail_index = 1
	for _settle in 4:
		await get_tree().process_frame
	index.queue_redraw()
	for _paint in 3:
		await get_tree().process_frame

	# The dossier collected links while it drew.
	var kinds: Array = []
	for link in index._link_rects:
		if not kinds.has(str(link.kind)):
			kinds.append(str(link.kind))
	check(not index._link_rects.is_empty(), "the dossier prints links (%d)" % index._link_rects.size())
	check(kinds.has("wound") or kinds.has("implant"), "wounds and implants among them (%s)" % str(kinds))

	# Every link has a real rect, or it is unclickable.
	var sized := true
	for link in index._link_rects:
		var rect: Rect2 = link.rect
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			sized = false
	check(sized, "every link has a clickable rect")

	# Following a body link lands on the BODY page, not a window.
	index._follow_link({"kind": "wound", "id": "crushed left arm"})
	check(index.page == 3, "following a wound goes to the body page")
	check(index._inspector.zone == "left_arm", "and points the inspector at the named zone (%s)" % index._inspector.zone)

	index._follow_link({"kind": "implant", "id": "ashline industrial arm", "zone": "left_arm"})
	check(index.page == 3 and index._inspector.zone == "left_arm", "an implant lands on its own zone")

	# Prose is read for a zone, never for meaning.
	check(index._zone_from_text("cut right leg") == "right_leg", "a wound's zone is read out of its text")
	check(index._zone_from_text("something unrecorded") == "torso", "and falls back rather than failing")

	# An account link goes to the Wire.
	index._follow_link({"kind": "account", "id": "mara_voss"})
	check(index.page == 2, "following an account goes to the Wire")

	# Links are rebuilt per frame, not accumulated forever.
	var before: int = index._link_rects.size()
	index.page = 0
	index.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	check(index._link_rects.size() <= maxi(before, 1) * 2, "links are rebuilt each frame rather than piling up")

	print("LINK_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
