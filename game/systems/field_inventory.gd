class_name FieldInventory
extends Control

## A direct field view of the same Carry model the Black Mirror exposes. This
## is not a second bag: looting, pockets, improvised limbs and the phone all
## mutate one shared set of identified objects.

signal close_requested
## Still a Carry index, not a grid slot: the Hunt's hand already knows how to
## take up a whole limb, and that path must not be rebuilt in here.
signal activate_requested(index: int)
## A racked weapon went into the hand. The panel reads the same arsenal the
## world fires from; this only tells the owner of the carried-limb model that
## the hand has changed, so an improvised club cannot stay welded to the arm.
signal weapon_equipped(weapon_id: String)

const BRAIN_INDEX := preload("res://systems/brain_index.gd")
const ORGANS := preload("res://systems/organ_system.gd")
const INK := Color("d9c79a")
const BLOOD := Color("a92e32")
const MOSS := Color("8ea85d")
const GLASS := Color("090b0a")

## The board. Cells are a fixed minimum width and a fixed height so a row reads
## as a row, and the column count falls out of the compartment rather than a
## number chosen for one screen. A slot is a *view*: weapons live in
## `arsenal.carried()` and everything else in `Carry.items`, so nothing here is
## a second copy of either and a round fired, an organ fitted or a pocket
## emptied is the same state the phone and the world see.
const GRID_GAP := 8.0
const CELL_MIN_WIDTH := 112.0
const CELL_HEIGHT := 92.0
const GRID_HEADER := 52.0
const GRID_FOOTER := 26.0
const COLUMN_GAP := 24.0
const PAD := 28.0
const BODY_MIN_WIDTH := 190.0
const BODY_MAX_WIDTH := 250.0
const DETAIL_WIDTH := 250.0
## Below this the cabinet cannot hold three columns; the inspect pane is the
## one that gives way, because the body and the grid are both playable.
const DETAIL_MIN_PLATE := 1000.0

var carry: Carry
var body: BaselineHuman
var arsenal: HunterArsenal
var selected := 0
var slot_rects: Array[Dictionary] = []
var grid_scroll_row := 0
## Which bag item is in the hand, when it is not a racked weapon. The board is
## a view of the same state, so it has to be told: the Hunt owns the carried
## limb, and without this every weapon would print IN HAND while the arm was
## holding somebody's leg.
var held_bag_index := -1
## A corpse under inspection, when the bag is showing what is on them rather
## than what is on you. Set by `open_corpse()`, cleared by `open_inventory()` —
## a stale body must never survive into your own bag view.
var inspect_rig: BaselineHuman = null
var inspect_pockets: Array = []
var corpse_rows: Array = []
var brain_rect := Rect2()
var brain_index_open := false
## Greg's checklist: hovering the head glows it and previews what is in the
## chip; clicking zooms into the skull before the index opens.
var head_hover := false
var zoom := -1.0
const ZOOM_SECONDS := 0.35


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	visible = false


func open_inventory(carry_model: Carry, body_rig: BaselineHuman, weapon_model: HunterArsenal, held_index := -1) -> void:
	carry = carry_model
	body = body_rig
	arsenal = weapon_model
	held_bag_index = held_index
	inspect_rig = null
	inspect_pockets = []
	brain_index_open = false
	selected = clampi(selected, 0, maxi(0, slot_count() - 1))
	grid_scroll_row = 0
	visible = true
	queue_redraw()


## Somebody else's pockets, garments and open cavities, listed through
## `CorpseContents` — which owns the gate, so organs behind unopened zones
## show as sealed and stay that way no matter what the panel wants.
func open_corpse(rig: BaselineHuman, pockets: Array = []) -> void:
	inspect_rig = rig
	inspect_pockets = pockets.duplicate()
	selected = 0
	grid_scroll_row = 0
	visible = true
	queue_redraw()


func close_inventory() -> void:
	visible = false


func handle_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
		close_requested.emit()
		return true
	if event.is_action_pressed("ui_left"):
		_move_cursor(-1, 0)
		return true
	if event.is_action_pressed("ui_right"):
		_move_cursor(1, 0)
		return true
	if event.is_action_pressed("ui_up"):
		_move_cursor(0, -1)
		return true
	if event.is_action_pressed("ui_down"):
		_move_cursor(0, 1)
		return true
	if event.is_action_pressed("ui_accept"):
		_activate_selected()
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_O:
				close_requested.emit()
			KEY_LEFT, KEY_A:
				_move_cursor(-1, 0)
			KEY_RIGHT, KEY_D:
				_move_cursor(1, 0)
			KEY_UP, KEY_W:
				_move_cursor(0, -1)
			KEY_DOWN, KEY_S:
				_move_cursor(0, 1)
			KEY_ENTER, KEY_KP_ENTER:
				_activate_selected()
			KEY_P:
				_toggle_pocket()
			KEY_M:
				_mend_cloth()
			KEY_B:
				if inspect_rig == null:
					_toggle_brain_index()
			_:
				return false
		return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if inspect_rig == null and brain_rect.has_point(event.position):
			_toggle_brain_index()
			return true
		# Hit areas are rebuilt from the live layout rather than trusted from the
		# last paint, so a click after a resize or a page scroll lands on the cell
		# actually under the pointer and not on where it used to be.
		for hit in visible_slot_rects(_plates().bag):
			if (hit.rect as Rect2).has_point(event.position):
				if int(hit.slot) == selected and event.double_click:
					_activate_selected()
				else:
					selected = int(hit.slot)
					queue_redraw()
				return true
		return true
	if event is InputEventMouseMotion:
		head_hover = inspect_rig == null and brain_rect.has_point(event.position)
		return true
	return false


## Opening zooms into the skull first; closing is immediate.
func _toggle_brain_index() -> void:
	if brain_index_open:
		brain_index_open = false
	elif zoom < 0.0:
		zoom = 0.0
	queue_redraw()


## --- the board ---------------------------------------------------------------
##
## A slot is a view. Weapons come from the live arsenal (the three issued plus
## anything acquired, in the same order the number keys use) and everything
## else from the live Carry. `slot_count()` and `slot_entry()` are the whole
## mapping, so nothing can be equipped in the grid and absent from the world.

func weapon_slots() -> Array[String]:
	var held: Array[String] = []
	if arsenal == null or not is_instance_valid(arsenal):
		return held
	held.assign(arsenal.carried())
	return held


func slot_count() -> int:
	return weapon_slots().size() + (carry.items.size() if carry != null else 0)


func slot_for_bag(bag_index: int) -> int:
	return weapon_slots().size() + bag_index


func slot_for_weapon(weapon_id: String) -> int:
	return weapon_slots().find(weapon_id)


func slot_entry(slot: int) -> Dictionary:
	var held := weapon_slots()
	if slot >= 0 and slot < held.size():
		var weapon_id := str(held[slot])
		var spec: Dictionary = HunterArsenal.WEAPONS.get(weapon_id, {})
		return {
			"source": "weapon", "weapon_id": weapon_id, "slot": slot,
			"label": str(spec.get("label", weapon_id)).to_upper(), "kind": "weapon",
		}
	var bag_index := slot - held.size()
	if carry == null or bag_index < 0 or bag_index >= carry.items.size():
		return {}
	var item: Dictionary = carry.items[bag_index]
	return {
		"source": "bag", "item_index": bag_index, "item": item, "slot": slot,
		"label": str(item.get("label", "OBJECT")), "kind": str(item.get("kind", "goods")),
	}


## The bag plate, as the layout sees it. Public so a test can measure the same
## compartment the panel draws into without waiting for a paint.
func bag_rect() -> Rect2:
	return _plates().bag


func grid_columns(rect: Rect2) -> int:
	var room := rect.size.x - 20.0
	if room <= 0.0:
		return 1
	return clampi(int(floor((room + GRID_GAP) / (CELL_MIN_WIDTH + GRID_GAP))), 1, 6)


func grid_cell(rect: Rect2, columns: int) -> Vector2:
	var room := maxf(rect.size.x - 20.0, 48.0)
	var width := (room - GRID_GAP * float(maxi(0, columns - 1))) / float(maxi(1, columns))
	return Vector2(maxf(44.0, width), CELL_HEIGHT)


func grid_visible_rows(rect: Rect2) -> int:
	var room := rect.size.y - GRID_HEADER - GRID_FOOTER
	return maxi(1, int(floor((room + GRID_GAP) / (CELL_HEIGHT + GRID_GAP))))


## Where the board is scrolled to, and how big one cell is. The chosen slot is
## kept inside the window here rather than by the movement code, so a resize, a
## page of new loot or a click all agree on what is visible.
func grid_layout(rect: Rect2) -> Dictionary:
	var columns := grid_columns(rect)
	var rows := grid_visible_rows(rect)
	var total_rows := int(ceil(float(slot_count()) / float(columns)))
	var selected_row := selected / columns
	if selected_row < grid_scroll_row:
		grid_scroll_row = selected_row
	elif selected_row >= grid_scroll_row + rows:
		grid_scroll_row = selected_row - rows + 1
	grid_scroll_row = clampi(grid_scroll_row, 0, maxi(0, total_rows - rows))
	return {
		"columns": columns, "rows": rows, "cell": grid_cell(rect, columns),
		"first_row": grid_scroll_row, "total_rows": total_rows,
	}


func slot_rect_in(rect: Rect2, slot: int) -> Rect2:
	return _rect_from_layout(grid_layout(rect), rect, slot)


func _rect_from_layout(layout: Dictionary, rect: Rect2, slot: int) -> Rect2:
	var columns := int(layout.columns)
	var row := slot / columns - int(layout.first_row)
	var column := slot % columns
	if slot < 0 or row < 0 or row >= int(layout.rows):
		return Rect2()
	var cell: Vector2 = layout.cell
	var origin := rect.position + Vector2(10.0, GRID_HEADER)
	return Rect2(origin + Vector2(column * (cell.x + GRID_GAP), row * (cell.y + GRID_GAP)), cell)


## Only the occupied slots are hit areas; an empty cell is furniture, not a
## place something can be clicked or dropped.
func visible_slot_rects(rect: Rect2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var layout := grid_layout(rect)
	var columns := int(layout.columns)
	var first := int(layout.first_row) * columns
	var last := mini(slot_count(), (int(layout.first_row) + int(layout.rows)) * columns)
	for slot in range(first, last):
		var box := _rect_from_layout(layout, rect, slot)
		if box.size.x > 0.0:
			out.append({"rect": box, "slot": slot})
	return out


## --- using a slot ------------------------------------------------------------

func _activate_selected() -> void:
	if inspect_rig != null:
		_take_corpse_row()
		return
	var entry := slot_entry(selected)
	if entry.is_empty():
		return
	if str(entry.get("source", "")) == "weapon":
		_wield_weapon(entry)
		return
	_activate_bag_item(int(entry.get("item_index", -1)))


func _activate_bag_item(bag_index: int) -> void:
	if carry == null or bag_index < 0 or bag_index >= carry.items.size():
		return
	var item: Dictionary = carry.items[bag_index]
	var label := str(item.get("label", "OBJECT"))
	var kind := str(item.get("kind", "goods"))
	# A whole limb is not racked and not bolted on: it goes into the hand, and
	# the world owns that hand. The request leaves rather than this panel
	# growing a second weapon path to compete with `_equip_carried_limb_index`.
	if kind == "limb":
		activate_requested.emit(bag_index)
		return
	if kind in ["organ", "cybernetic"]:
		if body == null or not is_instance_valid(body):
			set_meta("last_result", "NO BODY ON THIS SCREEN TO OPEN")
			queue_redraw()
			return
		var done: Dictionary = ORGANS.install_into_self(carry, bag_index, body)
		if done.is_empty():
			set_meta("last_result", "%s // WILL NOT TAKE" % label)
		else:
			var fitted := str(done.get("organ", done.get("implant", label)))
			set_meta("last_result", "%s // IN THE BODY" % fitted.replace("_", " ").to_upper())
			selected = clampi(selected, 0, maxi(0, slot_count() - 1))
		queue_redraw()
		return
	set_meta("last_result", "%s // CARRIED, NOT WIELDABLE" % label)
	queue_redraw()


func _wield_weapon(entry: Dictionary) -> void:
	var label := str(entry.get("label", "WEAPON"))
	if arsenal == null or not is_instance_valid(arsenal):
		set_meta("last_result", "%s // NO HAND TO HOLD IT" % label)
		queue_redraw()
		return
	var weapon_id := str(entry.get("weapon_id", ""))
	if arsenal.current_id == weapon_id:
		set_meta("last_result", "%s // ALREADY IN HAND" % label)
		queue_redraw()
		return
	if not arsenal.select_weapon(weapon_id):
		set_meta("last_result", "%s // THE HAND IS BUSY" % label)
		queue_redraw()
		return
	# The weapon took the hand, so nothing else is in it. The Hunt drops the
	# carried-limb model on this same signal, and the board stops claiming the
	# old weapon at once rather than on the next reopen.
	held_bag_index = -1
	weapon_equipped.emit(weapon_id)
	set_meta("last_result", "%s // IN HAND" % label)
	queue_redraw()


## The corpse view is still one list; the bag is a board. `_step` survives for
## the dead and for callers that only have a direction.
func _step(by: int) -> void:
	if inspect_rig != null:
		selected = posmod(selected + by, maxi(1, _corpse_rows().size()))
	else:
		_move_cursor(by, 0)
	queue_redraw()


## Reading order, so RIGHT crosses a row into the next one and DOWN moves by a
## whole row. Clamped rather than wrapped: on a board, falling off the last cell
## is easier to understand than teleporting to the first.
func _move_cursor(dx: int, dy: int) -> void:
	if inspect_rig != null:
		_step(dy if dy != 0 else dx)
		return
	var count := slot_count()
	if count <= 0:
		selected = 0
		queue_redraw()
		return
	if dx != 0:
		selected = clampi(selected + dx, 0, count - 1)
	else:
		selected = clampi(selected + dy * grid_columns(bag_rect()), 0, count - 1)
	# The board follows the cursor rather than the other way round.
	grid_layout(bag_rect())
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
	var entry := slot_entry(selected)
	if str(entry.get("source", "")) != "bag":
		set_meta("last_result", "A WEAPON SITS ON ITS OWN PEG")
		queue_redraw()
		return
	var bag_index := int(entry.get("item_index", -1))
	if carry == null or bag_index < 0 or bag_index >= carry.items.size():
		return
	var item: Dictionary = carry.items[bag_index]
	var result: Dictionary = carry.unpocket(bag_index) if bool(item.get("pocketed", false)) else carry.pocket(bag_index)
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


func _process(delta: float) -> void:
	if zoom >= 0.0:
		zoom += delta / ZOOM_SECONDS
		if zoom >= 1.0:
			zoom = -1.0
			brain_index_open = true
	if visible:
		queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var screen := Rect2(Vector2.ZERO, size)
	draw_rect(screen, Color(0.01, 0.012, 0.01, 0.90))
	var plates := _plates()
	var plate: Rect2 = plates.plate
	# The bag is a reliquary cabinet: planked wood, iron corners, a gear train
	# down the side. Layout and hit areas are unchanged underneath.
	GothicFrame.draw_cabinet(self, plate, float(Time.get_ticks_msec()) / 1000.0)
	_t(plate.position + Vector2(PAD, 38), "FIELD INVENTORY // ONE BODY, ONE BAG", 21, INK, plate.size.x - PAD * 2.0)
	var controls := "TOUCHPAD / CIRCLE CLOSE   D-PAD SELECT   CROSS USE OR WIELD" if _using_pad() else "O / ESC CLOSE   ARROWS SELECT   ENTER USE   CLICK TWICE USE   P POCKET   M MEND   B BRAIN"
	_t(plate.position + Vector2(PAD, 62), controls, 12, INK * Color(1, 1, 1, 0.6), plate.size.x - PAD * 2.0)

	for key in ["body", "bag"]:
		GothicFrame.draw_chrome_plate(self, plates[key], Color(0.035, 0.03, 0.025, 0.94))
	_draw_body(plates.body)
	_draw_bag(plates.bag)
	# The third column is the chosen thing, not a second list of the rack: every
	# weapon now has a slot on the board and the old WEAPONS list was the same
	# seven lines printed twice.
	var detail: Rect2 = plates.detail
	if detail.size.x > 0.0:
		GothicFrame.draw_chrome_plate(self, detail, Color(0.035, 0.03, 0.025, 0.94))
		_draw_detail(detail)


## Three compartments measured off one plate, so the grid gets whatever the
## body and the inspect pane do not need. At the width where three columns stop
## making sense the pane is dropped rather than squeezing every column to an
## unreadable sliver.
func _plates() -> Dictionary:
	var plate := Rect2(size * Vector2(0.055, 0.07), size * Vector2(0.89, 0.86))
	var top := plate.position.y + 88.0
	var height := plate.size.y - 116.0
	var body_width := clampf(plate.size.x * 0.19, BODY_MIN_WIDTH, BODY_MAX_WIDTH)
	var detail_width := DETAIL_WIDTH if plate.size.x >= DETAIL_MIN_PLATE else 0.0
	var bag_width := plate.size.x - PAD * 2.0 - body_width - COLUMN_GAP * (2.0 if detail_width > 0.0 else 1.0) - detail_width
	if bag_width < 260.0 and detail_width > 0.0:
		detail_width = 0.0
		bag_width = plate.size.x - PAD * 2.0 - body_width - COLUMN_GAP
	var body := Rect2(Vector2(plate.position.x + PAD, top), Vector2(body_width, height))
	var bag := Rect2(Vector2(body.end.x + COLUMN_GAP, top), Vector2(maxf(140.0, bag_width), height))
	var detail := Rect2(Vector2(bag.end.x + COLUMN_GAP, top), Vector2(detail_width, height)) if detail_width > 0.0 else Rect2()
	return {"plate": plate, "body": body, "bag": bag, "detail": detail}


func _using_pad() -> bool:
	var profile := get_node_or_null("/root/InputProfile")
	return profile != null and bool(profile.using_pad)


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
	# The brain chip is a physical head implant, not an abstract tab.  Put the
	# control above the head/torso rows so it is visibly part of the paper-doll
	# panel and easy to reach with either the mouse or B.
	brain_rect = Rect2(rect.position + Vector2(12, 38), Vector2(rect.size.x - 24, 36))
	var glow := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006) if head_hover and not brain_index_open else 0.0
	draw_rect(brain_rect, Color("210e0d").lerp(Color("3a1512"), glow))
	draw_rect(brain_rect, BLOOD.lightened(0.35 * glow) * Color(1, 1, 1, 0.72 + 0.28 * glow), false, 1.0 + 2.0 * glow)
	_t(brain_rect.position + Vector2(10, 15), "HEAD // WETWIRE BRAIN INDEX", 12, INK, brain_rect.size.x - 20)
	_t(brain_rect.position + Vector2(10, 29), "CLICK HEAD / B TO %s" % ("CLOSE" if brain_index_open else "ACCESS"), 10, BLOOD.lightened(0.18), brain_rect.size.x - 20)
	if brain_index_open:
		_draw_brain_index(rect)
		return
	if zoom >= 0.0:
		_draw_skull_zoom(rect)
		return
	if head_hover:
		_draw_head_preview()
	var y := rect.position.y + 98.0
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


## The inventory does not own another memory system.  This is a small physical
## reader over the same `BrainIndex` data the handheld uses, so losing a device
## cannot make a chip embedded in the player's skull stop existing.
## What the chip holds, at a glance, under the hovered head.
func _draw_head_preview() -> void:
	var box := Rect2(brain_rect.position + Vector2(0, brain_rect.size.y + 4), Vector2(brain_rect.size.x, 38))
	draw_rect(box, Color("110b0a"))
	draw_rect(box, BLOOD * Color(1, 1, 1, 0.6), false, 1.0)
	var chip: Dictionary = BRAIN_INDEX.chip("player")
	var opened := 0
	var total := 0
	for counts: Dictionary in (BRAIN_INDEX.folder_counts("player") as Dictionary).values():
		opened += int(counts.get("open", 0))
		total += int(counts.get("total", 0))
	_t(box.position + Vector2(10, 15), "CHIP // %s" % str(chip.get("owner_faction", "NO CHIP DETECTED")).to_upper(), 10, INK, box.size.x - 20)
	_t(box.position + Vector2(10, 30), "FILES OPEN %02d / %02d" % [opened, total], 10, MOSS, box.size.x - 20)


## Into the skull: it swells from the head row to fill the panel.
func _draw_skull_zoom(rect: Rect2) -> void:
	var t := ease(clampf(zoom, 0.0, 1.0), 0.4)
	var centre := brain_rect.get_center().lerp(rect.get_center(), t)
	var radius := lerpf(16.0, minf(rect.size.x, rect.size.y) * 0.42, t)
	draw_circle(centre, radius, Color("d8c7a8") * Color(1, 1, 1, 0.9))
	draw_circle(centre, radius * 0.93, Color("110b0a"))
	for side in [-1.0, 1.0]:
		draw_circle(centre + Vector2(side * radius * 0.36, -radius * 0.05), radius * 0.2, Color("d8c7a8") * Color(1, 1, 1, 0.8))
		draw_circle(centre + Vector2(side * radius * 0.36, -radius * 0.05), radius * 0.15, Color("110b0a"))
	draw_arc(centre, radius * 0.6, PI * 0.15, PI * 0.85, 16, BLOOD * Color(1, 1, 1, t), 2.0 + 3.0 * t)


func _draw_brain_index(rect: Rect2) -> void:
	var panel := Rect2(rect.position + Vector2(10, 82), rect.size - Vector2(20, 94))
	draw_rect(panel, Color("110b0a"))
	draw_rect(panel, BLOOD * Color(1, 1, 1, 0.82), false, 1.0)
	_t(panel.position + Vector2(10, 20), "WETWIRE // BRAIN INDEX", 14, BLOOD.lightened(0.28), panel.size.x - 20)
	var chip: Dictionary = BRAIN_INDEX.chip("player")
	var owner := str(chip.get("owner_faction", "NO CHIP DETECTED")).to_upper()
	_t(panel.position + Vector2(10, 39), "CHIP OWNER // " + owner, 10, INK * Color(1, 1, 1, 0.72), panel.size.x - 20)
	var folders: Dictionary = BRAIN_INDEX.folder_counts("player")
	var y := panel.position.y + 66.0
	for folder_id in ["memory", "combat", "people", "places", "carry", "trauma"]:
		var counts: Dictionary = folders.get(folder_id, {})
		var label := str((BRAIN_INDEX.FOLDERS.get(folder_id, {}) as Dictionary).get("label", folder_id)).to_upper()
		draw_rect(Rect2(Vector2(panel.position.x + 7, y - 12), Vector2(panel.size.x - 14, 17)), Color("2a1512"))
		_t(Vector2(panel.position.x + 12, y), label, 10, INK, panel.size.x - 70)
		_t_right(panel.end.x - 8, y, "%02d/%02d" % [int(counts.get("open", 0)), int(counts.get("total", 0))], 10, MOSS)
		y += 24.0
	_t(Vector2(panel.position.x + 10, panel.end.y - 12), "B / CLICK HEAD TO RETURN TO BODY", 10, INK * Color(1, 1, 1, 0.55), panel.size.x - 20)


func _draw_bag(rect: Rect2) -> void:
	slot_rects.clear()
	if inspect_rig != null:
		_draw_corpse(rect)
		return
	var total := carry.total_mass() if carry != null else 0.0
	var header_color := MOSS if total <= Carry.CAPACITY else BLOOD
	_t(rect.position + Vector2(18, 28), "CARRIED / %0.1f OF %0.0f KG" % [total, Carry.CAPACITY], 17, header_color)
	var count := slot_count()
	if count == 0:
		_t(rect.position + Vector2(18, 62), "NOTHING CARRIED.", 14, INK * Color(1, 1, 1, 0.45), rect.size.x - 36)
		return
	var layout := grid_layout(rect)
	var columns := int(layout.columns)
	var rows := int(layout.rows)
	var first_row := int(layout.first_row)
	var pages := int(ceil(float(layout.total_rows) / float(maxi(1, rows))))
	if pages > 1:
		_t_right(rect.end.x - 18, rect.position.y + 28, "PAGE %d/%d" % [mini(pages, first_row / rows + 1), pages], 11, INK * Color(1, 1, 1, 0.55))
	var cell: Vector2 = layout.cell
	var origin := rect.position + Vector2(10.0, GRID_HEADER)
	slot_rects = visible_slot_rects(rect)
	for row in rows:
		for column in columns:
			var slot := (first_row + row) * columns + column
			var box := Rect2(origin + Vector2(column * (cell.x + GRID_GAP), row * (cell.y + GRID_GAP)), cell)
			_draw_slot(box, slot, slot < count)
	var result := str(get_meta("last_result", ""))
	if not result.is_empty():
		_t(Vector2(rect.position.x + 18, rect.end.y - 12), result, 11, BLOOD, rect.size.x - 36)


## One drawer. Empty cells are furniture with a dead centre mark; an occupied
## one carries a drawn kind glyph, its name, and the one number that matters
## for that kind — weight, condition, edge, or rounds. The chosen cell keeps the
## old row's blood wash and gains brass corner ticks.
func _draw_slot(box: Rect2, slot: int, occupied: bool) -> void:
	var chosen := occupied and slot == selected
	draw_rect(box, Color("1b0e0c") if chosen else Color(0.035, 0.04, 0.034, 0.92))
	draw_rect(box, Color(0.13, 0.11, 0.08), false, 1.0)
	draw_line(box.position + Vector2(1, 1), Vector2(box.end.x - 1, box.position.y + 1), Color(0, 0, 0, 0.6), 1.0)
	draw_line(box.position + Vector2(1, 1), Vector2(box.position.x + 1, box.end.y - 1), Color(0, 0, 0, 0.45), 1.0)
	draw_line(Vector2(box.position.x + 1, box.end.y - 1), box.end - Vector2(1, 1), GothicFrame.WOOD_LIGHT * Color(1, 1, 1, 0.45), 1.0)
	if not occupied:
		draw_rect(Rect2(box.get_center() - Vector2(2, 2), Vector2(4, 4)), Color(1, 1, 1, 0.05))
		return
	var entry := slot_entry(slot)
	var kind := str(entry.get("kind", "goods"))
	if chosen:
		draw_rect(box.grow(-1.0), BLOOD * Color(1, 1, 1, 0.16))
		draw_rect(box, BLOOD, false, 1.5)
		for corner in [box.position, Vector2(box.end.x, box.position.y), Vector2(box.position.x, box.end.y), box.end]:
			var sx := 1.0 if corner.x == box.position.x else -1.0
			var sy := 1.0 if corner.y == box.position.y else -1.0
			draw_line(corner, corner + Vector2(7 * sx, 0), GothicFrame.BRASS, 1.5)
			draw_line(corner, corner + Vector2(0, 7 * sy), GothicFrame.BRASS, 1.5)
	_carry_glyph(box.position + Vector2(9, 12), kind, entry)
	var cap := 7.5
	var room := box.size.x - 50.0
	var lines: Array = CellOutzType.wrap_condensed(str(entry.get("label", "OBJECT")), room, cap, 0.0)
	for index in mini(2, lines.size()):
		CellOutzType.draw_condensed(self, Vector2(box.position.x + 40, box.position.y + 16 + index * 11.0), str(lines[index]), cap, INK)
	var foot := CellOutzType.fit_condensed(slot_foot(entry), box.size.x - 30, 6.6)
	CellOutzType.draw_condensed(self, Vector2(box.position.x + 10, box.end.y - 12), foot, 6.6, INK * Color(1, 1, 1, 0.66))
	if bool((entry.get("item", {}) as Dictionary).get("pocketed", false)):
		draw_rect(Rect2(box.end - Vector2(13, 13), Vector2(7, 7)), GothicFrame.BRASS)
	if _in_hand(entry):
		draw_colored_polygon(PackedVector2Array([box.position, box.position + Vector2(12, 0), box.position + Vector2(0, 12)]), GothicFrame.BRASS)


## Which drawing a kind gets is the same question the brain index already asks
## of its rows. Organs are wet sacs, hardware is a bolted plate, a whole limb is
## a bone, weapons are a blade or a barrel, and everything else keeps the jar.
func _carry_glyph(at: Vector2, kind: String, entry: Dictionary) -> void:
	match kind:
		"weapon":
			var spec: Dictionary = HunterArsenal.WEAPONS.get(str(entry.get("weapon_id", "")), {})
			_weapon_glyph(at, str(spec.get("kind", "melee")) == "firearm")
		"organ":
			_organ_glyph(at, entry)
		"cybernetic":
			_hardware_glyph(at)
		"limb":
			_bone_glyph(at)
		_:
			_jar(at, kind)


func _weapon_glyph(at: Vector2, firearm: bool) -> void:
	if firearm:
		draw_rect(Rect2(at + Vector2(1, 7), Vector2(20, 6)), Color("54504c"))
		draw_rect(Rect2(at + Vector2(1, 7), Vector2(20, 6)), GothicFrame.CHROME * Color(1, 1, 1, 0.35), false, 1.0)
		draw_line(at + Vector2(18, 8), at + Vector2(23, 8), GothicFrame.BRASS, 2.0)
		draw_rect(Rect2(at + Vector2(5, 13), Vector2(4, 8)), GothicFrame.IRON)
		draw_line(at + Vector2(9, 14), at + Vector2(13, 14), GothicFrame.IRON, 2.0)
		return
	draw_line(at + Vector2(3, 17), at + Vector2(21, 4), GothicFrame.CHROME * Color(1, 1, 1, 0.85), 3.0)
	draw_line(at + Vector2(4, 18), at + Vector2(20, 6), Color("4c4844"), 1.0)
	draw_rect(Rect2(at + Vector2(1, 15), Vector2(6, 3)), GothicFrame.IRON)
	draw_line(at + Vector2(2, 20), at + Vector2(7, 15), GothicFrame.BRASS, 2.0)


func _organ_glyph(at: Vector2, entry: Dictionary) -> void:
	var condition := clampf(float((entry.get("item", {}) as Dictionary).get("condition", 1.0)), 0.0, 1.0)
	var meat := BLOOD.darkened(0.15).lerp(Color("3a211c"), 1.0 - condition)
	draw_circle(at + Vector2(9, 13), 8.0, meat)
	draw_circle(at + Vector2(16, 10), 6.0, meat.lightened(0.08))
	draw_line(at + Vector2(9, 5), at + Vector2(10, 1), meat.lightened(0.25), 2.0)
	draw_line(at + Vector2(16, 4), at + Vector2(15, 0), meat.lightened(0.25), 2.0)
	draw_arc(at + Vector2(13, 11), 9.0, PI * 1.15, PI * 1.75, 8, BLOOD.lightened(0.35), 1.2)


func _hardware_glyph(at: Vector2) -> void:
	draw_rect(Rect2(at + Vector2(2, 5), Vector2(18, 15)), GothicFrame.IRON)
	draw_rect(Rect2(at + Vector2(2, 5), Vector2(18, 15)), GothicFrame.CHROME * Color(1, 1, 1, 0.45), false, 1.0)
	draw_rect(Rect2(at + Vector2(6, 9), Vector2(10, 7)), Color("0d0f0e"))
	draw_circle(at + Vector2(5, 8), 1.8, GothicFrame.BRASS)
	draw_circle(at + Vector2(17, 8), 1.8, GothicFrame.BRASS)
	draw_line(at + Vector2(11, 1), at + Vector2(11, 5), GothicFrame.CHROME * Color(1, 1, 1, 0.6), 1.5)


func _bone_glyph(at: Vector2) -> void:
	var bone := Color("cfc2a4")
	draw_line(at + Vector2(5, 6), at + Vector2(17, 18), bone, 3.0)
	draw_circle(at + Vector2(4, 5), 3.2, bone)
	draw_circle(at + Vector2(7, 3), 2.4, bone)
	draw_circle(at + Vector2(18, 19), 3.2, bone)
	draw_circle(at + Vector2(21, 17), 2.4, bone)


## Is this slot the thing physically in the hand right now? A racked weapon is
## only in hand when nothing else is; a carried limb is in hand when it is the
## one the Hunt is wielding.
func _in_hand(entry: Dictionary) -> bool:
	if str(entry.get("source", "")) == "weapon":
		return held_bag_index < 0 and arsenal != null and arsenal.current_id == str(entry.get("weapon_id", ""))
	return held_bag_index >= 0 and int(entry.get("item_index", -1)) == held_bag_index


func slot_foot(entry: Dictionary) -> String:
	if str(entry.get("source", "")) == "weapon":
		var weapon_id := str(entry.get("weapon_id", ""))
		if _in_hand(entry):
			return "IN HAND"
		var spec: Dictionary = HunterArsenal.WEAPONS.get(weapon_id, {})
		if str(spec.get("kind", "")) == "firearm":
			var state: Dictionary = arsenal.ammo.get(weapon_id, {}) if arsenal != null else {}
			return "%d / %d" % [int(state.get("loaded", -1)), int(state.get("reserve", -1))]
		return "%d%% EDGE" % roundi((arsenal.weapon_condition(weapon_id) if arsenal != null else 1.0) * 100.0)
	var item: Dictionary = entry.get("item", {})
	if _in_hand(entry):
		return "IN HAND"
	var bits: Array = [str(item.get("kind", "goods")).to_upper(), "%0.1fKG" % float(item.get("mass", 0.5))]
	var condition := clampf(float(item.get("condition", 1.0)), 0.0, 1.0)
	if condition < 0.99:
		bits.append("%d%%" % roundi(condition * 100.0))
	if bool(item.get("pocketed", false)):
		bits.append("POCKET")
	return " ".join(bits)


## The third column used to repeat the weapon rack. It is the chosen slot now:
## what it is, what it weighs, whose it was, and the one verb it answers to.
func _draw_detail(rect: Rect2) -> void:
	_t(rect.position + Vector2(18, 28), "CHOSEN", 17, INK)
	var entry := slot_entry(selected)
	if entry.is_empty():
		_t(rect.position + Vector2(18, 62), "NOTHING IN THE GRID.", 13, INK * Color(1, 1, 1, 0.45), rect.size.x - 36)
		return
	var badge := Rect2(rect.position + Vector2(18, 44), Vector2(70, 70))
	draw_rect(badge, Color("0b0d0a"))
	draw_rect(badge, Color(0.16, 0.13, 0.09), false, 1.0)
	_carry_glyph(badge.position + Vector2(22, 22), str(entry.get("kind", "goods")), entry)
	var room := rect.size.x - 36.0
	var name_room := room - 84.0
	var cap := 8.2
	var lines: Array = CellOutzType.wrap_condensed(str(entry.get("label", "")), name_room, cap, 0.0)
	for index in mini(3, lines.size()):
		CellOutzType.draw_condensed(self, Vector2(badge.end.x + 14, badge.position.y + 26 + index * 12.0), str(lines[index]), cap, INK)
	var y := badge.end.y + 24.0
	for line in _detail_lines(entry):
		_t(Vector2(rect.position.x + 18, y), CellOutzType.fit_condensed(str(line), room, 8.2), 11, INK * Color(1, 1, 1, 0.72), room)
		y += 19.0
	_t(Vector2(rect.position.x + 18, rect.end.y - 46), _action_line(entry), 11, MOSS, room)
	_t(Vector2(rect.position.x + 18, rect.end.y - 26), "P POCKET  //  CLICK TWICE OR ENTER", 10, INK * Color(1, 1, 1, 0.5), room)


func _detail_lines(entry: Dictionary) -> Array:
	var out: Array = []
	if str(entry.get("source", "")) == "weapon":
		var weapon_id := str(entry.get("weapon_id", ""))
		var spec: Dictionary = HunterArsenal.WEAPONS.get(weapon_id, {})
		out.append("KIND // %s" % str(spec.get("kind", "weapon")).to_upper())
		var wear := roundi((arsenal.weapon_condition(weapon_id) if arsenal != null else 1.0) * 100.0)
		if str(spec.get("kind", "")) == "firearm":
			var state: Dictionary = arsenal.ammo.get(weapon_id, {}) if arsenal != null else {}
			out.append("LOADED // %d / %d" % [int(state.get("loaded", -1)), int(state.get("reserve", -1))])
			out.append("WEAR // %d%%" % wear)
		else:
			out.append("EDGE // %d%%" % wear)
		return out
	var item: Dictionary = entry.get("item", {})
	out.append("KIND // %s" % str(item.get("kind", "goods")).to_upper())
	out.append("MASS // %0.1f KG" % float(item.get("mass", 0.0)))
	out.append("CONDITION // %d%%" % roundi(clampf(float(item.get("condition", 1.0)), 0.0, 1.0) * 100.0))
	var provenance := str(item.get("from", ""))
	if not provenance.is_empty():
		out.append("FROM // %s" % provenance.replace("_", " ").to_upper())
	if bool(item.get("pocketed", false)):
		out.append("POCKETED // YES")
	return out


func _action_line(entry: Dictionary) -> String:
	if _in_hand(entry):
		return "IN HAND // ENTER KEEPS IT THERE"
	if str(entry.get("source", "")) == "weapon":
		return "ENTER // TAKE IT UP"
	var kind := str(entry.get("kind", "goods"))
	match kind:
		"limb":
			return "ENTER // WIELD THE WHOLE LIMB"
		"organ":
			return "ENTER // FIT IT TO YOUR BODY" if body != null else "NO BODY HERE TO OPEN"
		"cybernetic":
			return "ENTER // BOLT IT INTO YOUR BODY" if body != null else "NO BODY HERE TO OPEN"
	return "ENTER // CARRIED, NOT WIELDABLE"


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

