class_name BloodTreeView
extends Control

## The four style trees side by side: what each style has earned, what it
## still has to spend, which weapons earned it, and the nodes it can open.
## Arrow keys choose, Enter spends, Escape (or the host's key) closes. It only
## reads `BloodLedger` and asks it to `unlock()`; it keeps no record itself.

const CellOutzType := preload("res://systems/celloutz_type.gd")
const BONE := Color("ead4ad")
const DIM := Color(0.42, 0.38, 0.34)
const INK := Color(0.03, 0.02, 0.02)
const NODE_SIZE := Vector2(136.0, 50.0)

var ledger: BloodLedger = null
var style_index := 0
var node_index := 0
var flash := 0.0
var _message := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func toggle() -> void:
	visible = not visible
	_message = ""
	queue_redraw()


func selected_style() -> String:
	return str(BloodTrees.STYLE_ORDER[style_index])


func ordered_nodes(style_id: String) -> Array[String]:
	var out := BloodTrees.style_nodes(style_id)
	out.sort_custom(func(a: String, b: String) -> bool:
		var da := BloodTrees.node_depth(a)
		var db := BloodTrees.node_depth(b)
		return da < db if da != db else BloodTrees.NODES.keys().find(a) < BloodTrees.NODES.keys().find(b))
	return out


func selected_node() -> String:
	var nodes := ordered_nodes(selected_style())
	return nodes[clampi(node_index, 0, nodes.size() - 1)] if not nodes.is_empty() else ""


func move(style_step: int, node_step: int) -> void:
	if style_step != 0:
		style_index = posmod(style_index + style_step, BloodTrees.STYLE_ORDER.size())
		node_index = 0
	if node_step != 0:
		node_index = posmod(node_index + node_step, maxi(1, ordered_nodes(selected_style()).size()))
	_message = ""
	queue_redraw()


func try_unlock() -> bool:
	var node_id := selected_node()
	if ledger == null or node_id.is_empty():
		return false
	if ledger.unlock(node_id):
		flash = 1.0
		_message = "%s OPENED" % str((BloodTrees.NODES[node_id] as Dictionary).label)
		queue_redraw()
		return true
	_message = _blocked_reason(node_id)
	queue_redraw()
	return false


func _blocked_reason(node_id: String) -> String:
	var node := BloodTrees.NODES[node_id] as Dictionary
	if ledger.is_unlocked(node_id):
		return "ALREADY OPEN"
	if not ledger.requirements_met(node_id):
		var needs: Array[String] = []
		for parent in node.get("requires", []):
			if not ledger.is_unlocked(str(parent)):
				needs.append(str((BloodTrees.NODES[str(parent)] as Dictionary).label))
		return "NEEDS %s" % " + ".join(needs)
	return "%d / %d BLOOD" % [ledger.available(str(node.style)), int(node.cost)]


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	var handled := true
	match key.keycode:
		KEY_LEFT: move(-1, 0)
		KEY_RIGHT: move(1, 0)
		KEY_UP: move(0, -1)
		KEY_DOWN: move(0, 1)
		KEY_ENTER, KEY_KP_ENTER: try_unlock()
		KEY_ESCAPE: toggle()
		_: handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	flash = maxf(0.0, flash - delta * 1.8)
	queue_redraw()


## Where a node's box sits: rows by depth, siblings side by side.
func node_rect(style_id: String, node_id: String, column: Rect2) -> Rect2:
	var depth := BloodTrees.node_depth(node_id)
	var siblings: Array[String] = []
	for other in ordered_nodes(style_id):
		if BloodTrees.node_depth(other) == depth:
			siblings.append(other)
	var slot := siblings.find(node_id)
	var gap := 12.0 if siblings.size() < 3 else 6.0
	# A crowded row narrows its boxes to stay inside the style's column.
	var width := minf(NODE_SIZE.x, (column.size.x - 16.0 - (siblings.size() - 1) * gap) / float(maxi(1, siblings.size())))
	var row_width := siblings.size() * width + (siblings.size() - 1) * gap
	var x := column.position.x + (column.size.x - row_width) * 0.5 + slot * (width + gap)
	var y := column.position.y + depth * (NODE_SIZE.y + 34.0)
	return Rect2(Vector2(x, y), Vector2(width, NODE_SIZE.y))


func _draw() -> void:
	if not visible or ledger == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.008, 0.008, 0.985))
	var margin := 40.0
	CellOutzType.draw_text(self, Vector2(margin, 34.0), "BLOOD", 34.0, Color("c81f16"), 3.0)
	CellOutzType.draw_text(self, Vector2(margin + CellOutzType.width("BLOOD", 34.0, 3.0) + 18.0, 52.0), "WHAT THE FIGHTING TAUGHT EACH HAND", 12.0, BONE, 1.4)
	CellOutzType.draw_text(self, Vector2(margin, 84.0), "PLACEHOLDER NAMES AND NUMBERS // FOR GREG", 9.0, DIM, 1.0)
	var columns := BloodTrees.STYLE_ORDER.size()
	var column_width := (size.x - margin * 2.0) / float(columns)
	for column_index in columns:
		var style_id := str(BloodTrees.STYLE_ORDER[column_index])
		var style := BloodTrees.STYLES[style_id] as Dictionary
		var tone := style.tone as Color
		var x := margin + column_index * column_width
		var chosen := column_index == style_index
		if chosen:
			draw_rect(Rect2(Vector2(x + 4.0, 108.0), Vector2(column_width - 8.0, size.y - 108.0 - 96.0)), tone * Color(1, 1, 1, 0.07))
		draw_rect(Rect2(Vector2(x + 4.0, 108.0), Vector2(column_width - 8.0, 3.0)), tone * Color(1, 1, 1, 1.0 if chosen else 0.45))
		CellOutzType.draw_text(self, Vector2(x + 16.0, 124.0), str(style.label), 14.0, tone, 1.6)
		var spare := ledger.available(style_id)
		CellOutzType.draw_text(self, Vector2(x + 16.0, 150.0), str(spare), 30.0, BONE, 2.0)
		CellOutzType.draw_text(self, Vector2(x + 16.0, 188.0), "TO SPEND // %d EARNED" % ledger.style_earned(style_id), 9.0, DIM, 1.0)
		# Which weapons fed this pool.
		var line_y := 210.0
		for weapon_id in ledger.state.weapons:
			if BloodTrees.weapon_style(str(weapon_id)) != style_id:
				continue
			var record := ledger.weapon_record(str(weapon_id))
			var text := "%s  %d" % [BloodTrees.weapon_label(str(weapon_id)), int(record.get("blood", 0))]
			CellOutzType.draw_text(self, Vector2(x + 16.0, line_y), CellOutzType.fit_condensed(text, column_width - 32.0, 9.0, 0.9), 9.0, BONE * Color(1, 1, 1, 0.8), 0.9)
			line_y += 15.0
		if line_y == 210.0:
			CellOutzType.draw_text(self, Vector2(x + 16.0, line_y), "NOTHING YET", 9.0, DIM, 0.9)
		var tree_area := Rect2(Vector2(x, 262.0), Vector2(column_width, size.y - 262.0))
		var nodes := ordered_nodes(style_id)
		for node_id in nodes:
			var rect := node_rect(style_id, node_id, tree_area)
			for parent in (BloodTrees.NODES[node_id] as Dictionary).get("requires", []):
				var from := node_rect(style_id, str(parent), tree_area)
				var lit := ledger.is_unlocked(str(parent))
				draw_line(Vector2(from.get_center().x, from.end.y), Vector2(rect.get_center().x, rect.position.y), tone * Color(1, 1, 1, 0.8) if lit else DIM * Color(1, 1, 1, 0.6), 2.0 if lit else 1.0)
		for index in nodes.size():
			var node_id := nodes[index]
			_draw_node(node_rect(style_id, node_id, tree_area), node_id, tone, chosen and index == clampi(node_index, 0, nodes.size() - 1))
	_draw_footer(margin)


func _draw_node(rect: Rect2, node_id: String, tone: Color, selected: bool) -> void:
	var node := BloodTrees.NODES[node_id] as Dictionary
	var open := ledger.is_unlocked(node_id)
	var ready := ledger.can_unlock(node_id)
	var reachable := ledger.requirements_met(node_id)
	if open:
		draw_rect(rect, tone * Color(1, 1, 1, 0.85))
	else:
		draw_rect(rect, INK * Color(1, 1, 1, 0.9))
	var edge := tone if (open or ready) else (DIM if reachable else DIM * Color(1, 1, 1, 0.5))
	draw_rect(rect, edge, false, 2.0 if ready else 1.0)
	if selected:
		var grow := 4.0 + 3.0 * flash
		draw_rect(rect.grow(grow), BONE, false, 1.5)
	var text_tone := INK if open else (BONE if reachable else DIM)
	# A narrow box sets its name smaller before it ever cuts it short.
	var cap := 11.0
	while cap > 7.0 and CellOutzType.width(str(node.label), cap, 1.1) > rect.size.x - 20.0:
		cap -= 0.5
	CellOutzType.draw_text(self, rect.position + Vector2(10.0, 10.0 + (11.0 - cap) * 0.5), CellOutzType.fit_condensed(str(node.label), rect.size.x - 20.0, cap, 1.1), cap, text_tone, 1.1)
	var status := "OPEN" if open else "%d BLOOD" % int(node.cost)
	CellOutzType.draw_text(self, rect.position + Vector2(10.0, 30.0), status, 8.0, text_tone * Color(1, 1, 1, 0.85), 0.9)
	if str(node.effect).contains("NOT WIRED") and not open:
		CellOutzType.draw_text(self, rect.position + Vector2(rect.size.x - 14.0, 10.0), "*", 8.0, DIM, 0.9)


func _draw_footer(margin: float) -> void:
	var node_id := selected_node()
	var top := size.y - 86.0
	draw_rect(Rect2(Vector2(margin, top - 10.0), Vector2(size.x - margin * 2.0, 1.0)), DIM)
	if not node_id.is_empty():
		var node := BloodTrees.NODES[node_id] as Dictionary
		CellOutzType.draw_text(self, Vector2(margin, top), str(node.label), 16.0, BONE, 1.6)
		CellOutzType.draw_text(self, Vector2(margin, top + 26.0), str(node.effect), 10.0, BONE * Color(1, 1, 1, 0.8), 1.0)
		var action := _message
		if action.is_empty():
			action = "[ENTER] SPEND %d BLOOD" % int(node.cost) if ledger.can_unlock(node_id) else _blocked_reason(node_id)
		var action_width := CellOutzType.width(action, 12.0, 1.2)
		CellOutzType.draw_text(self, Vector2(size.x - margin - action_width, top + 2.0), action, 12.0, Color("c81f16") if ledger.can_unlock(node_id) else DIM, 1.2)
	var keys := "[LEFT RIGHT] STYLE   [UP DOWN] NODE   [ENTER] SPEND   [ESC] CLOSE   * NOT WIRED YET"
	CellOutzType.draw_text(self, Vector2(margin, top + 50.0), keys, 8.0, DIM, 0.9)
