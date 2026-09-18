class_name FieldInventory
extends Control

## A direct field view of the same Carry model the Black Mirror exposes. This
## is not a second bag: looting, pockets, improvised limbs and the phone all
## mutate one shared set of identified objects.

signal close_requested
signal activate_requested(index: int)

const INK := Color("d9c79a")
const BLOOD := Color("a92e32")
const MOSS := Color("8ea85d")
const GLASS := Color("090b0a")

var carry: Carry
var body: BaselineHuman
var arsenal: HunterArsenal
var selected := 0
var row_rects: Array[Dictionary] = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	visible = false


func open_inventory(carry_model: Carry, body_rig: BaselineHuman, weapon_model: HunterArsenal) -> void:
	carry = carry_model
	body = body_rig
	arsenal = weapon_model
	selected = clampi(selected, 0, maxi(0, carry.items.size() - 1))
	visible = true
	queue_redraw()


func close_inventory() -> void:
	visible = false


func handle_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_O:
				close_requested.emit()
			KEY_UP, KEY_W:
				_step(-1)
			KEY_DOWN, KEY_S:
				_step(1)
			KEY_ENTER, KEY_KP_ENTER:
				if carry != null and not carry.items.is_empty():
					activate_requested.emit(selected)
			KEY_P:
				_toggle_pocket()
			_:
				return false
		return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for row in row_rects:
			if (row.rect as Rect2).has_point(event.position):
				selected = int(row.index)
				activate_requested.emit(selected)
				queue_redraw()
				return true
		return true
	return event is InputEventMouseMotion


func _step(by: int) -> void:
	if carry == null or carry.items.is_empty():
		selected = 0
	else:
		selected = posmod(selected + by, carry.items.size())
	queue_redraw()


func _toggle_pocket() -> void:
	if carry == null or selected < 0 or selected >= carry.items.size():
		return
	var item: Dictionary = carry.items[selected]
	var result: Dictionary = carry.unpocket(selected) if bool(item.get("pocketed", false)) else carry.pocket(selected)
	set_meta("last_result", str(result.get("reason", "POCKET UPDATED" if bool(result.get("ok", false)) else "REFUSED")))
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var font := ThemeDB.fallback_font
	var screen := Rect2(Vector2.ZERO, size)
	draw_rect(screen, Color(0.01, 0.012, 0.01, 0.90))
	var plate := Rect2(size * Vector2(0.055, 0.07), size * Vector2(0.89, 0.86))
	draw_rect(plate, GLASS)
	draw_rect(plate, INK * Color(1, 1, 1, 0.56), false, 2.0)
	draw_string(font, plate.position + Vector2(28, 38), "FIELD INVENTORY // ONE BODY, ONE BAG", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, INK)
	draw_string(font, plate.position + Vector2(28, 62), "O / ESC CLOSE   UP/DOWN SELECT   ENTER USE OR WIELD   P POCKET", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK * Color(1, 1, 1, 0.65))

	var body_rect := Rect2(plate.position + Vector2(28, 88), Vector2(250, plate.size.y - 116))
	var bag_rect := Rect2(Vector2(body_rect.end.x + 24, body_rect.position.y), Vector2(plate.size.x - body_rect.size.x - 330, body_rect.size.y))
	var gear_rect := Rect2(Vector2(bag_rect.end.x + 24, body_rect.position.y), Vector2(250, body_rect.size.y))
	for panel in [body_rect, bag_rect, gear_rect]:
		draw_rect(panel, Color(0.04, 0.045, 0.035, 0.92))
		draw_rect(panel, INK * Color(1, 1, 1, 0.22), false, 1.0)
	_draw_body(font, body_rect)
	_draw_bag(font, bag_rect)
	_draw_gear(font, gear_rect)


func _draw_body(font: Font, rect: Rect2) -> void:
	draw_string(font, rect.position + Vector2(18, 28), "BODY", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, BLOOD)
	if body == null or body.anatomy == null:
		return
	var y := rect.position.y + 58.0
	for zone_id in ["head", "torso", "left_arm", "right_arm", "left_leg", "right_leg"]:
		var zone: Dictionary = body.anatomy.zones.get(zone_id, {})
		var ceiling: float = float((AnatomyComponent.DEFAULT_ZONES.get(zone_id, {}) as Dictionary).get("health", 100.0))
		var ratio := clampf(float(zone.get("health", ceiling)) / maxf(ceiling, 1.0), 0.0, 1.0)
		var label: String = str(zone_id).replace("_", " ").to_upper()
		draw_string(font, Vector2(rect.position.x + 18, y), label, HORIZONTAL_ALIGNMENT_LEFT, 105, 12, INK)
		var track := Rect2(Vector2(rect.position.x + 126, y - 10), Vector2(102, 8))
		draw_rect(track, Color(0.12, 0.10, 0.08))
		draw_rect(Rect2(track.position, Vector2(track.size.x * ratio, track.size.y)), BLOOD.lerp(MOSS, ratio))
		y += 38.0
	draw_string(font, Vector2(rect.position.x + 18, rect.end.y - 48), "BLOOD  %d ML" % roundi(body.anatomy.blood_remaining), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, BLOOD)
	draw_string(font, Vector2(rect.position.x + 18, rect.end.y - 24), "PAIN   %d" % roundi(body.anatomy.pain), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)


func _draw_bag(font: Font, rect: Rect2) -> void:
	row_rects.clear()
	var total := carry.total_mass() if carry != null else 0.0
	draw_string(font, rect.position + Vector2(18, 28), "LOOT / %0.1f OF %0.0f KG" % [total, Carry.CAPACITY], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, MOSS if total <= Carry.CAPACITY else BLOOD)
	if carry == null or carry.items.is_empty():
		draw_string(font, rect.position + Vector2(18, 62), "NOTHING CARRIED.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK * Color(1, 1, 1, 0.45))
		return
	var y := rect.position.y + 48.0
	var max_rows := maxi(1, floori((rect.size.y - 58.0) / 43.0))
	var first := clampi(selected - floori(float(max_rows) * 0.5), 0, maxi(0, carry.items.size() - max_rows))
	for index in range(first, mini(carry.items.size(), first + max_rows)):
		var item: Dictionary = carry.items[index]
		var row := Rect2(Vector2(rect.position.x + 10, y), Vector2(rect.size.x - 20, 38))
		row_rects.append({"rect": row, "index": index})
		if index == selected:
			draw_rect(row, BLOOD * Color(1, 1, 1, 0.25))
			draw_rect(row, BLOOD, false, 1.0)
		var pocket := " [POCKET]" if bool(item.get("pocketed", false)) else ""
		draw_string(font, row.position + Vector2(10, 16), str(item.get("label", "OBJECT")) + pocket, HORIZONTAL_ALIGNMENT_LEFT, row.size.x - 90, 12, INK)
		draw_string(font, row.position + Vector2(row.size.x - 72, 16), "%0.1f KG" % float(item.get("mass", 0.5)), HORIZONTAL_ALIGNMENT_RIGHT, 62, 11, INK * Color(1, 1, 1, 0.6))
		var provenance := str(item.get("from", ""))
		var detail := "%s // %s" % [str(item.get("kind", "goods")).to_upper(), carry.condition_label(item)]
		if not provenance.is_empty():
			detail += " // FROM %s" % provenance.to_upper().replace("_", " ")
		draw_string(font, row.position + Vector2(10, 32), detail, HORIZONTAL_ALIGNMENT_LEFT, row.size.x - 20, 9, INK * Color(1, 1, 1, 0.48))
		y += 43.0
	var result := str(get_meta("last_result", ""))
	if not result.is_empty():
		draw_string(font, Vector2(rect.position.x + 18, rect.end.y - 12), result, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, BLOOD)


func _draw_gear(font: Font, rect: Rect2) -> void:
	draw_string(font, rect.position + Vector2(18, 28), "WEAPONS", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, INK)
	if arsenal == null:
		return
	var y := rect.position.y + 62.0
	for weapon_id in HunterArsenal.SLOT_ORDER:
		var spec: Dictionary = HunterArsenal.WEAPONS[weapon_id]
		var active: bool = arsenal.current_id == str(weapon_id)
		draw_string(font, Vector2(rect.position.x + 18, y), ("> " if active else "  ") + str(spec.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, BLOOD if active else INK)
		var state: Dictionary = arsenal.ammo.get(weapon_id, {})
		var detail := "%d / %d" % [int(state.get("loaded", -1)), int(state.get("reserve", -1))] if str(spec.kind) == "firearm" else "%d%% EDGE" % roundi(arsenal.weapon_condition(weapon_id) * 100.0)
		draw_string(font, Vector2(rect.position.x + 32, y + 18), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK * Color(1, 1, 1, 0.55))
		y += 58.0
	draw_string(font, Vector2(rect.position.x + 18, rect.end.y - 44), "ENTER WIELDS A", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK * Color(1, 1, 1, 0.55))
	draw_string(font, Vector2(rect.position.x + 18, rect.end.y - 26), "SELECTED WHOLE LIMB", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK * Color(1, 1, 1, 0.55))
