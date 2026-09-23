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
## A corpse under inspection, when the bag is showing what is on them rather
## than what is on you. Set by `open_corpse()`, cleared by `open_inventory()` —
## a stale body must never survive into your own bag view.
var inspect_rig: BaselineHuman = null
var inspect_pockets: Array = []
var corpse_rows: Array = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	visible = false


func open_inventory(carry_model: Carry, body_rig: BaselineHuman, weapon_model: HunterArsenal) -> void:
	carry = carry_model
	body = body_rig
	arsenal = weapon_model
	inspect_rig = null
	inspect_pockets = []
	selected = clampi(selected, 0, maxi(0, carry.items.size() - 1))
	visible = true
	queue_redraw()


## Somebody else's pockets, garments and open cavities, listed through
## `CorpseContents` — which owns the gate, so organs behind unopened zones
## show as sealed and stay that way no matter what the panel wants.
func open_corpse(rig: BaselineHuman, pockets: Array = []) -> void:
	inspect_rig = rig
	inspect_pockets = pockets.duplicate()
	selected = 0
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
				if inspect_rig != null:
					_take_corpse_row()
				elif carry != null and not carry.items.is_empty():
					activate_requested.emit(selected)
			KEY_P:
				_toggle_pocket()
			KEY_M:
				_mend_cloth()
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
	if inspect_rig != null:
		selected = posmod(selected + by, maxi(1, _corpse_rows().size()))
	elif carry == null or carry.items.is_empty():
		selected = 0
	else:
		selected = posmod(selected + by, carry.items.size())
	queue_redraw()


func _cloth_mean() -> float:
	# Mean garment cover across the six zones. Bare zones count as zero cover,
	# so an undressed rig reads 0% and a half-shredded one reads the middle.
	if body == null:
		return 0.0
	var total := 0.0
	for zone_id in ["head", "torso", "left_arm", "right_arm", "left_leg", "right_leg"]:
		total += clampf(float(body.wardrobe.get(zone_id, 0.0)), 0.0, 1.0)
	return total / 6.0


## One flat takeable list over whatever `CorpseContents` reports. Pockets and
## garments take; organs and implants show with the dig they still need, and
## sealed zones show as sealed — the gate stays in the listing, not here.
func _corpse_rows() -> Array:
	var rows: Array = []
	if inspect_rig == null:
		return rows
	var found: Dictionary = CorpseContents.of(inspect_rig, inspect_pockets)
	for entry: Dictionary in found.get("pockets", []):
		rows.append({"label": str(entry.get("label", "")), "kind": "pocket", "payload": entry})
	for entry: Dictionary in found.get("worn", []):
		rows.append({"label": "%s // %d%%" % [str(entry.get("label", "")), roundi(float(entry.get("condition", 0.0)) * 100.0)], "kind": "garment", "payload": entry})
	for entry: Dictionary in found.get("organs", []):
		rows.append({"label": "%s // NEEDS THE DIG" % str(entry.get("label", "")), "kind": "organ", "payload": entry})
	for entry: Dictionary in found.get("implanted", []):
		rows.append({"label": "%s // NEEDS THE DIG" % str(entry.get("label", "")), "kind": "implant", "payload": entry})
	for zone in found.get("sealed", []):
		rows.append({"label": "%s // SEALED" % str(zone).replace("_", " ").to_upper(), "kind": "sealed", "payload": {}})
	return rows


## Take the selected corpse row. Pockets move to the bag; a garment comes off
## their body (wardrobe erased, shell refreshed) and goes in as goods. Organs,
## implants and sealed zones refuse with the reason — taking those is the
## extraction dig's job, not this panel's.
func _take_corpse_row() -> void:
	var rows := _corpse_rows()
	if selected < 0 or selected >= rows.size():
		return
	var row: Dictionary = rows[selected]
	var kind := str(row.get("kind", ""))
	if kind == "pocket":
		var label := str((row.get("payload", {}) as Dictionary).get("label", "OBJECT"))
		inspect_pockets = inspect_pockets.filter(func(p): return str((p as Dictionary).get("label", p) if p is Dictionary else p).to_upper() != label)
		carry.items.append({"label": label, "kind": "goods", "mass": 0.5, "perishes": false, "age": 0.0, "condition": 1.0})
		carry.save_to_history()
		set_meta("last_result", "%s TAKEN" % label)
	elif kind == "garment":
		var zone := str((row.get("payload", {}) as Dictionary).get("zone", ""))
		var style := str((row.get("payload", {}) as Dictionary).get("style", "plain"))
		inspect_rig.wardrobe.erase(zone)
		inspect_rig.dress(inspect_rig.wardrobe)
		carry.items.append({"label": "%s %s" % [style.to_upper(), zone.replace("_", " ").to_upper()], "kind": "garment", "mass": 1.2, "perishes": false, "age": 0.0, "condition": 1.0})
		carry.save_to_history()
		set_meta("last_result", "%s STRIPPED" % zone.replace("_", " ").to_upper())
	elif kind == "organ" or kind == "implant":
		set_meta("last_result", "NEEDS THE DIG")
	else:
		set_meta("last_result", "SEALED")
	selected = clampi(selected, 0, maxi(0, _corpse_rows().size() - 1))
	queue_redraw()


func _toggle_pocket() -> void:
	if carry == null or selected < 0 or selected >= carry.items.size():
		return
	var item: Dictionary = carry.items[selected]
	var result: Dictionary = carry.unpocket(selected) if bool(item.get("pocketed", false)) else carry.pocket(selected)
	set_meta("last_result", str(result.get("reason", "POCKET UPDATED" if bool(result.get("ok", false)) else "REFUSED")))
	queue_redraw()


## Clothes come back by purchase, from this menu. Prices through
## `ClothingShell`, spends through `Carry`, refreshes the body's garments so
## the mended cloth shows immediately rather than on the next hit.
func _mend_cloth() -> void:
	if carry == null or body == null:
		return
	var result: Dictionary = carry.spend_on_mending(body.wardrobe)
	if bool(result.get("ok", false)):
		body.dress(body.wardrobe)
		set_meta("last_result", "CLOTH MENDED // %d SCRIP" % int(result.get("spent", 0)))
	else:
		set_meta("last_result", str(result.get("reason", "REFUSED")))
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var screen := Rect2(Vector2.ZERO, size)
	draw_rect(screen, Color(0.01, 0.012, 0.01, 0.90))
	var plate := Rect2(size * Vector2(0.055, 0.07), size * Vector2(0.89, 0.86))
	# The bag is a reliquary cabinet: planked wood, iron corners, a gear train
	# down the side. Layout and hit areas are unchanged underneath.
	GothicFrame.draw_cabinet(self, plate, float(Time.get_ticks_msec()) / 1000.0)
	_t(plate.position + Vector2(28, 38), "FIELD INVENTORY // ONE BODY, ONE BAG", 21, INK, plate.size.x - 56)
	_t(plate.position + Vector2(28, 62), "O / ESC CLOSE   ↑↓ SELECT   ENTER USE OR WIELD   P POCKET   M MEND CLOTH", 12, INK * Color(1, 1, 1, 0.6), plate.size.x - 56)

	var body_rect := Rect2(plate.position + Vector2(28, 88), Vector2(250, plate.size.y - 116))
	var bag_rect := Rect2(Vector2(body_rect.end.x + 24, body_rect.position.y), Vector2(plate.size.x - body_rect.size.x - 330, body_rect.size.y))
	var gear_rect := Rect2(Vector2(bag_rect.end.x + 24, body_rect.position.y), Vector2(250, body_rect.size.y))
	for panel in [body_rect, bag_rect, gear_rect]:
		GothicFrame.draw_chrome_plate(self, panel, Color(0.035, 0.03, 0.025, 0.94))
	_draw_body(body_rect)
	_draw_bag(bag_rect)
	_draw_gear(gear_rect)


## Every line in the house face. `at.y` is a baseline and `px` the size the
## engine font used, so converted lines sit where they did. Anything wider than
## `room` is set smaller rather than run out of its compartment: the stencil
## face does not wrap.
func _t(at: Vector2, value: String, px: float, color: Color, room := -1.0) -> float:
	var cap := px * 0.72
	var tracking := px * 0.08
	var text := value.to_upper()
	if room > 0.0:
		var natural := CellOutzType.width(text, cap, tracking)
		if natural > room:
			cap *= room / natural
			tracking *= room / natural
	return CellOutzType.draw_text(self, Vector2(at.x, at.y - cap), text, cap, color, tracking)


func _t_right(right: float, baseline: float, value: String, px: float, color: Color) -> void:
	var cap := px * 0.72
	var tracking := px * 0.08
	var width := CellOutzType.width(value.to_upper(), cap, tracking)
	CellOutzType.draw_text(self, Vector2(right - width, baseline - cap), value.to_upper(), cap, color, tracking)


## A small stoppered jar, filled by what kind of thing the row is.
func _jar(at: Vector2, kind: String, live := true) -> void:
	var fill := BLOOD if kind in ["organ", "limb", "chunk", "meat", "implant"] else (Color("7a55c9") if kind in ["substance", "smokeable", "drug"] else (MOSS if kind in ["garment", "pocket"] else INK.darkened(0.4)))
	var body_rect := Rect2(at + Vector2(0, 5), Vector2(14, 22))
	draw_rect(body_rect, Color(0.02, 0.03, 0.03, 0.8))
	if live:
		draw_rect(Rect2(body_rect.position + Vector2(2, 7), body_rect.size - Vector2(4, 9)), fill * Color(1, 1, 1, 0.85))
	draw_rect(body_rect, INK * Color(1, 1, 1, 0.45), false, 1.0)
	draw_rect(Rect2(at + Vector2(2, 0), Vector2(10, 5)), GothicFrame.BRASS)


func _draw_body(rect: Rect2) -> void:
	_t(rect.position + Vector2(18, 28), "BODY", 17, BLOOD)
	if body == null or body.anatomy == null:
		return
	var y := rect.position.y + 58.0
	for zone_id in ["head", "torso", "left_arm", "right_arm", "left_leg", "right_leg"]:
		var zone: Dictionary = body.anatomy.zones.get(zone_id, {})
		var ceiling: float = float((AnatomyComponent.DEFAULT_ZONES.get(zone_id, {}) as Dictionary).get("health", 100.0))
		var ratio := clampf(float(zone.get("health", ceiling)) / maxf(ceiling, 1.0), 0.0, 1.0)
		var label: String = str(zone_id).replace("_", " ")
		_t(Vector2(rect.position.x + 18, y), label, 12, INK, 100)
		var track := Rect2(Vector2(rect.position.x + 126, y - 10), Vector2(102, 8))
		draw_rect(track, Color(0.12, 0.10, 0.08))
		draw_rect(Rect2(track.position, Vector2(track.size.x * ratio, track.size.y)), BLOOD.lerp(MOSS, ratio))
		# The cloth over the wound, on the same row: flesh above, garment
		# below, so a glance reads which zones are bare before a fight.
		var cover := clampf(float(body.wardrobe.get(zone_id, 0.0)), 0.0, 1.0)
		var hem := Rect2(Vector2(track.position.x, track.end.y + 2), Vector2(track.size.x, 4))
		draw_rect(hem, Color(0.12, 0.10, 0.08))
		draw_rect(Rect2(hem.position, Vector2(hem.size.x * cover, hem.size.y)), INK.lerp(Color("3d0907"), 1.0 - cover))
		y += 38.0
	_t(Vector2(rect.position.x + 18, rect.end.y - 72), "CLOTH  %d%% // M MEND (%d)" % [roundi(_cloth_mean() * 100.0), ClothingShell.price_to_mend(body.wardrobe)], 13, INK, rect.size.x - 36)
	_t(Vector2(rect.position.x + 18, rect.end.y - 48), "BLOOD  %d ML" % roundi(body.anatomy.blood_remaining), 13, BLOOD)
	_t(Vector2(rect.position.x + 18, rect.end.y - 24), "PAIN   %d" % roundi(body.anatomy.pain), 13, INK)


func _draw_bag(rect: Rect2) -> void:
	row_rects.clear()
	if inspect_rig != null:
		_draw_corpse(rect)
		return
	var total := carry.total_mass() if carry != null else 0.0
	_t(rect.position + Vector2(18, 28), "LOOT / %0.1f OF %0.0f KG" % [total, Carry.CAPACITY], 17, MOSS if total <= Carry.CAPACITY else BLOOD)
	if carry == null or carry.items.is_empty():
		_t(rect.position + Vector2(18, 62), "NOTHING CARRIED.", 14, INK * Color(1, 1, 1, 0.45))
		return
	var y := rect.position.y + 48.0
	var max_rows := maxi(1, floori((rect.size.y - 58.0) / 43.0))
	var first := clampi(selected - floori(float(max_rows) * 0.5), 0, maxi(0, carry.items.size() - max_rows))
	for index in range(first, mini(carry.items.size(), first + max_rows)):
		var item: Dictionary = carry.items[index]
		var row := Rect2(Vector2(rect.position.x + 10, y), Vector2(rect.size.x - 20, 38))
		row_rects.append({"rect": row, "index": index})
		# Each thing sits on its own shelf: a plank under the row, lit when chosen.
		draw_rect(Rect2(row.position + Vector2(0, row.size.y - 3), Vector2(row.size.x, 5)), GothicFrame.WOOD_LIGHT)
		draw_line(row.position + Vector2(0, row.size.y + 2), row.position + Vector2(row.size.x, row.size.y + 2), Color(0, 0, 0, 0.6), 1.0)
		if index == selected:
			draw_rect(row, BLOOD * Color(1, 1, 1, 0.22))
			draw_rect(row, BLOOD, false, 1.0)
		_jar(row.position + Vector2(6, 4), str(item.get("kind", "goods")))
		var pocket := " [POCKET]" if bool(item.get("pocketed", false)) else ""
		_t(row.position + Vector2(28, 16), str(item.get("label", "OBJECT")) + pocket, 12, INK, row.size.x - 110)
		_t_right(row.end.x - 10, row.position.y + 16, "%0.1f KG" % float(item.get("mass", 0.5)), 11, INK * Color(1, 1, 1, 0.6))
		var provenance := str(item.get("from", ""))
		var detail := "%s // %s" % [str(item.get("kind", "goods")), carry.condition_label(item)]
		if not provenance.is_empty():
			detail += " // FROM %s" % provenance.replace("_", " ")
		_t(row.position + Vector2(28, 31), detail, 9, INK * Color(1, 1, 1, 0.48), row.size.x - 40)
		y += 43.0
	var result := str(get_meta("last_result", ""))
	if not result.is_empty():
		_t(Vector2(rect.position.x + 18, rect.end.y - 12), result, 11, BLOOD, rect.size.x - 36)


## Somebody else's effects, drawn where the bag goes. Takeable rows take;
## everything the dig still owns says so on its own row.
func _draw_corpse(rect: Rect2) -> void:
	corpse_rows = _corpse_rows()
	_t(rect.position + Vector2(18, 28), "DEAD // CONTENTS", 17, BLOOD)
	if corpse_rows.is_empty():
		_t(rect.position + Vector2(18, 62), "NOTHING ON THEM.", 14, INK * Color(1, 1, 1, 0.45))
		return
	var y := rect.position.y + 48.0
	var max_rows := maxi(1, floori((rect.size.y - 58.0) / 30.0))
	var first := clampi(selected - floori(float(max_rows) * 0.5), 0, maxi(0, corpse_rows.size() - max_rows))
	for index in range(first, mini(corpse_rows.size(), first + max_rows)):
		var row: Dictionary = corpse_rows[index]
		var line := Rect2(Vector2(rect.position.x + 10, y), Vector2(rect.size.x - 20, 26))
		if index == selected:
			draw_rect(line, BLOOD * Color(1, 1, 1, 0.25))
			draw_rect(line, BLOOD, false, 1.0)
		var ink := INK
		var kind := str(row.get("kind", ""))
		if kind == "sealed":
			ink = INK * Color(1, 1, 1, 0.45)
		elif kind in ["organ", "implant"]:
			ink = BLOOD.lightened(0.2)
		_t(line.position + Vector2(10, 17), str(row.get("label", "")), 12, ink, line.size.x - 20)
		y += 30.0
	var outcome := str(get_meta("last_result", ""))
	if not outcome.is_empty():
		_t(Vector2(rect.position.x + 18, rect.end.y - 12), outcome, 11, BLOOD, rect.size.x - 36)


func _draw_gear(rect: Rect2) -> void:
	_t(rect.position + Vector2(18, 28), "WEAPONS", 17, INK)
	if arsenal == null:
		return
	var y := rect.position.y + 62.0
	for weapon_id in HunterArsenal.SLOT_ORDER:
		var spec: Dictionary = HunterArsenal.WEAPONS[weapon_id]
		var active: bool = arsenal.current_id == str(weapon_id)
		# A rack peg per slot; the wielded one hangs lit.
		draw_circle(Vector2(rect.position.x + 12, y - 5), 3.0, GothicFrame.BRASS if active else GothicFrame.IRON)
		_t(Vector2(rect.position.x + 22, y), str(spec.label), 13, BLOOD if active else INK, rect.size.x - 40)
		var state: Dictionary = arsenal.ammo.get(weapon_id, {})
		var detail := "%d / %d" % [int(state.get("loaded", -1)), int(state.get("reserve", -1))] if str(spec.kind) == "firearm" else "%d%% EDGE" % roundi(arsenal.weapon_condition(weapon_id) * 100.0)
		_t(Vector2(rect.position.x + 32, y + 18), detail, 10, INK * Color(1, 1, 1, 0.55))
		y += 58.0
	_t(Vector2(rect.position.x + 18, rect.end.y - 44), "ENTER WIELDS A", 11, INK * Color(1, 1, 1, 0.55))
	_t(Vector2(rect.position.x + 18, rect.end.y - 26), "SELECTED WHOLE LIMB", 11, INK * Color(1, 1, 1, 0.55))
