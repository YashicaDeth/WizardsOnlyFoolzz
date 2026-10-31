extends Node

## Tidy-80 (Greg, 6 Oct: the mechanics lab is "so cluttered"): one hall of
## separate labelled bays. No two bays overlap, every station's geometry stands
## inside its own bay's lines, nothing visible hangs loose in the walkways, the
## START menu reaches every bay, and the screen keeps to one neutral line with
## the long readout behind SELECT.

var failures: Array[String] = []
var lab: Node3D


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	BloodPool.clear()
	lab = load("res://lab/mechanics_lab.tscn").instantiate()
	add_child(lab)
	await _frames(3)
	var bays: Array = lab.BAYS
	check(bays.size() == lab.stations.size() + 1, "a bay for each of the %d stations and one for the weapons" % lab.stations.size())

	for a in bays.size():
		for b in range(a + 1, bays.size()):
			check(not (bays[a].rect as Rect2).intersects(bays[b].rect), "%s and %s do not overlap" % [bays[a].title, bays[b].title])

	for index in lab.stations.size():
		_inside(lab.stations[index].node, index)
		var plinth: Vector3 = lab.stations[index].plinth
		check(lab.bay_at(plinth) == index, "the %s plinth stands in its own bay" % bays[index].title)
	_inside(lab.sparring, lab.WEAPONS_BAY)

	# Nothing visible hangs off the lab itself: it is all under a station, a
	# bay, a plinth, or the hall's own walls, floor and roof.
	var loose: Array[String] = []
	for child in lab.get_children():
		if child is VisualInstance3D and not (child is Light3D or child is GPUParticlesCollision3D) and (child as Node3D).is_visible_in_tree():
			loose.append(str(child.name))
	check(loose.is_empty(), "no loose meshes or labels in the hall (%s)" % ", ".join(loose))

	for index in bays.size():
		var sign := lab.get_node_or_null("Bay_%s/Sign" % str(bays[index].title).capitalize().replace(" ", "").replace("+", "")) as Label3D
		check(sign != null and sign.text == bays[index].title, "the %s bay has its sign" % bays[index].title)

	# START menu: every row, and each one lands you in its bay.
	await _press("pause")
	check(lab.menu_open, "START opens the bay menu")
	check((lab._menu.text as String).split("\n").size() == bays.size() + 1, "the menu lists every bay")
	await _press("pause")
	for index in bays.size():
		lab.go_to(index)
		await _frames(2)
		check(lab.bay_at(lab.player.global_position) == index, "the menu puts you in the %s bay" % bays[index].title)
		check((lab._hud.text as String).begins_with(str(bays[index].title)), "the top line names the bay (%s)" % lab._hud.text)

	# The screen: one neutral line, nothing red, the dials hidden until SELECT.
	check(not (lab._hud.text as String).contains("\n"), "the top line is one line")
	check(lab._hud.get_theme_color("font_color") == lab.INK, "and neutral, not red")
	check((lab._danger.text as String).is_empty(), "no danger line while nothing hurts")
	check(not lab._readout.visible, "the dials are hidden by default")
	check((lab._hints.text as String).contains("READOUTS"), "the pad hints say where they are (%s)" % lab._hints.text)
	await _press("device")
	check(lab._readout.visible and (lab._readout.text as String).split("\n").size() >= lab.stations.size(), "SELECT shows every station's readout")
	await _press("device")
	check(not lab._readout.visible, "and SELECT again hides it")

	# Red is for danger: acid rain on you in the open, not under the roof.
	lab.weather.apply("acid")
	lab.go_to(lab.WEAPONS_BAY)
	await _frames(2)
	check((lab._danger.text as String).contains("ACID"), "acid rain on you shows red (%s)" % lab._danger.text)
	lab.go_to(0)
	await _frames(2)
	check(not (lab._danger.text as String).contains("ACID"), "and goes under the roof")
	lab.weather.apply("clear")

	print("LAB_LAYOUT_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## Every visible mesh of `node` stands inside bay `index`'s lines. The storm
## (sky-wide by design) and screen-space viewers are not floor objects.
func _inside(node: Node3D, index: int) -> void:
	var rect: Rect2 = (lab.BAYS[index].rect as Rect2).grow(0.05)
	var outside: Array[String] = []
	for child in node.find_children("*", "VisualInstance3D", true, false):
		var visual := child as VisualInstance3D
		if visual is GPUParticles3D or visual is Light3D or not visual.is_visible_in_tree():
			continue
		if node.get_node_or_null("Storm") != null and node.get_node("Storm").is_ancestor_of(visual):
			continue
		if _under_canvas(visual) or visual.get_aabb().size.length() < 0.001:
			continue
		var box: AABB = visual.global_transform * visual.get_aabb()
		if box.end.y < -5.0:
			continue
		if not rect.encloses(Rect2(box.position.x, box.position.z, box.size.x, box.size.z)):
			outside.append("%s %s" % [node.get_path_to(visual), box])
	check(outside.is_empty(), "everything of %s stands inside its bay (%s)" % [lab.BAYS[index].title, "; ".join(outside.slice(0, 3))])


func _under_canvas(node: Node) -> bool:
	var up := node.get_parent()
	while up != null:
		if up is CanvasLayer or up is SubViewport:
			return true
		up = up.get_parent()
	return false


func _press(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	await get_tree().process_frame
	await _frames(1)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame
	await get_tree().process_frame


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().physics_frame
