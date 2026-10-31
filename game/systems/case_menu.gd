class_name CaseMenu
extends Control

## The Wire exchange: cases, skins and the wardrobe on one screen (Greg, 24
## September: a CS-style case with gun and knife skins, sellable for heaps,
## and the jester outfit as parts you put on).
##
## CASES   the dead cloud's supply caches (scrip, rounds, patches, implants)
##         and the skin cases, bought for scrip, plus any case you looted.
##         A skin case opens on a reel that runs past the ladder and slows
##         onto what you won.
## SKINS   the skins in your bag (apply to the weapon or part, or sell on the
##         Wire) and the skins already applied (take one off).
## WARDROBE what you are wearing and the clothing in your bag. The jester
##         collar holds everything on until you break its lock.
##
## Everything lands through verbs that already exist: `Carry` for scrip and
## items, `SkinCase` / `SkinMarket` / `SkinLoadout` for skins, `Outfit` for
## clothes.

signal close_requested
## A skin went on or came off, or the outfit changed: the host repaints.
signal loadout_changed

const CASE := preload("res://systems/loot_case.gd")

const INK := Color("d9c79a")
const BLOOD := Color("a92e32")
const MOSS := Color("8ea85d")
const GOLD := Color("d8a828")
const GLASS := Color("090b0a")

const TIER_INK := {"scrap": "d9c79a", "useful": "8ea85d", "rare": "6a9ad8", "relic": "9a6ad8", "gold": "d8a828"}
const TABS := ["CASES", "SKINS", "WARDROBE"]
const REEL_SECONDS := 4.2
const REEL_LENGTH := 44
const REEL_WIN_AT := 38

var carry: Carry
var body: BaselineHuman
## What the player has in hand, for breaking the collar's lock.
var weapon_hint := ""
var tab := 0
var selected := 0
var last: Dictionary = {}
var _reel: Array = []
var _reel_clock := -1.0
var _reel_result: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	visible = false
	_rng.randomize()


func open_menu(carry_model: Carry, body_rig: BaselineHuman) -> void:
	carry = carry_model
	body = body_rig
	tab = 0
	selected = 0
	last = {}
	_reel_clock = -1.0
	visible = true
	queue_redraw()


func close_menu() -> void:
	_finish_reel()
	visible = false


## The shop's shelf: the supply caches first (as they always were), then the
## skin cases.
func case_ids() -> Array:
	return CASE.CASES.keys() + SkinCase.CASES.keys()


func reeling() -> bool:
	return _reel_clock >= 0.0


# --- rows -----------------------------------------------------------------------

## What the current tab lists: each row is {label, detail, ink, action, ...}.
func rows() -> Array:
	var found: Array = []
	match tab:
		0:
			for case_id: String in case_ids():
				var spec: Dictionary = CASE.CASES.get(case_id, SkinCase.CASES.get(case_id, {}))
				found.append({"label": str(spec.get("label", "")), "detail": "BUY %d" % int(spec.get("price", 0)), "ink": INK if CASE.CASES.has(case_id) else Color(str(spec.get("ink", "d9c79a"))), "action": "buy", "case": case_id})
			for index in _bag_indices("case"):
				found.append({"label": str(carry.items[index].get("label", "")), "detail": "OPEN (YOURS)", "ink": GOLD, "action": "open", "index": index})
		1:
			for index in _bag_indices("skin"):
				var item: Dictionary = carry.items[index]
				found.append({"label": str(item.get("label", "")), "detail": "%s  %.3f  //  ENTER APPLY  X SELL %d" % [str(WeaponSkins.wear_band(float(item.get("wear", 0.0))).short), float(item.get("wear", 0.0)), SkinMarket.price(item)], "ink": _tier_ink(item), "action": "apply", "index": index})
			var applied := SkinLoadout.all_applied()
			for target: String in applied:
				var item: Dictionary = applied[target]
				found.append({"label": str(item.get("label", "")), "detail": "ON IT  //  ENTER TAKE OFF", "ink": _tier_ink(item), "action": "unapply", "target": target})
		2:
			var worn := Outfit.worn()
			for part_id: String in worn.parts:
				found.append({"label": str(Outfit.PARTS.get(part_id, {}).get("label", part_id)), "detail": "WORN  //  " + ("LOCKED ON" if bool(worn.locked) else "ENTER TAKE OFF"), "ink": INK, "action": "take_off", "part": part_id})
			for index in _bag_indices("garment"):
				found.append({"label": str(carry.items[index].get("label", "")), "detail": "IN THE BAG  //  ENTER PUT ON", "ink": MOSS, "action": "put_on", "index": index})
	return found


func _bag_indices(kind: String) -> Array:
	var found: Array = []
	if carry == null:
		return found
	for index in carry.items.size():
		if str(carry.items[index].get("kind", "")) == kind:
			found.append(index)
	return found


func _tier_ink(item: Dictionary) -> Color:
	return Color(str(WeaponSkins.tier(str(item.get("tier", "issue"))).ink))


# --- input ----------------------------------------------------------------------

func handle_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		if reeling():
			if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
				_finish_reel()
			return true
		var count := rows().size()
		match event.keycode:
			KEY_ESCAPE, KEY_U:
				close_requested.emit()
			KEY_UP, KEY_W:
				selected = posmod(selected - 1, maxi(count, 1))
			KEY_DOWN, KEY_S:
				selected = posmod(selected + 1, maxi(count, 1))
			KEY_LEFT, KEY_A, KEY_Q:
				tab = posmod(tab - 1, TABS.size())
				selected = 0
			KEY_RIGHT, KEY_D, KEY_E, KEY_TAB:
				tab = posmod(tab + 1, TABS.size())
				selected = 0
			KEY_ENTER, KEY_KP_ENTER:
				_act()
			KEY_X:
				_sell()
			KEY_B:
				_break_lock()
		queue_redraw()
		return true
	return event is InputEventMouseMotion


func _act() -> void:
	var listed := rows()
	if carry == null or selected < 0 or selected >= listed.size():
		return
	var row: Dictionary = listed[selected]
	match str(row.action):
		"buy":
			_buy(str(row.case))
		"open":
			_open_skin_case("", int(row.index))
		"apply":
			last = SkinLoadout.apply(carry, int(row.index))
			_changed()
		"unapply":
			last = SkinLoadout.remove(carry, str(row.target))
			_changed()
		"take_off":
			last = Outfit.take_off(body, carry, str(row.part))
			_changed()
		"put_on":
			last = Outfit.put_on(body, carry, int(row.index))
			_changed()
	selected = clampi(selected, 0, maxi(rows().size() - 1, 0))


func _changed() -> void:
	if bool(last.get("ok", false)):
		if body != null:
			Outfit.dress(body)
		loadout_changed.emit()


func _buy(case_id: String) -> void:
	var price := int((CASE.CASES.get(case_id, SkinCase.CASES.get(case_id, {})) as Dictionary).get("price", 0))
	var paid: Dictionary = carry.spend(price, "case bought")
	if not bool(paid.get("ok", false)):
		last = {"ok": false, "reason": str(paid.get("reason", "REFUSED"))}
		return
	if CASE.CASES.has(case_id):
		var receipt: Dictionary = CASE.open(case_id, randf(), true)
		var landed: Dictionary = carry.take_case_winnings(receipt, body)
		last = receipt
		last["note"] = str(landed.get("note", ""))
		last["landed_ok"] = bool(landed.get("ok", false))
		return
	_open_skin_case(case_id, -1)


func _open_skin_case(case_id: String, from_index: int) -> void:
	var receipt := SkinCase.open_into(carry, case_id, _rng, from_index)
	last = receipt
	if not bool(receipt.get("ok", false)):
		return
	_start_reel(str(receipt.case), receipt)


func _sell() -> void:
	var listed := rows()
	if tab != 1 or selected < 0 or selected >= listed.size() or str(listed[selected].action) != "apply":
		return
	last = SkinMarket.sell(carry, int(listed[selected].index))
	selected = clampi(selected, 0, maxi(rows().size() - 1, 0))


func _break_lock() -> void:
	if body == null:
		return
	last = Outfit.break_lock(body, weapon_hint)
	_changed()


# --- the reel -------------------------------------------------------------------

## The strip that runs past: skins drawn from the case at the ladder's own
## odds, with what you actually won at `REEL_WIN_AT`.
func _start_reel(case_id: String, receipt: Dictionary) -> void:
	_reel.clear()
	for index in REEL_LENGTH:
		if index == REEL_WIN_AT:
			_reel.append(receipt.item)
			continue
		var filler := SkinCase.open(case_id, _rng.randf(), _rng.randf(), _rng.randf(), 0)
		_reel.append(filler.get("item", {}))
	_reel_result = receipt
	_reel_clock = 0.0


func _finish_reel() -> void:
	if _reel_clock >= 0.0:
		_reel_clock = -1.0
		last = _reel_result
		last["note"] = "%s  //  %s  //  WORTH %d ON THE WIRE" % [str(WeaponSkins.tier(str(_reel_result.tier)).label), str(WeaponSkins.wear_band(float(_reel_result.item.wear)).label), SkinMarket.price(_reel_result.item)]


func _process(delta: float) -> void:
	if not visible:
		return
	if _reel_clock >= 0.0:
		_reel_clock += delta
		if _reel_clock >= REEL_SECONDS + 0.8:
			_finish_reel()
	queue_redraw()


## Where the strip is, in cells: fast at first, easing out onto the win.
func reel_position() -> float:
	var t := clampf(_reel_clock / REEL_SECONDS, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 3.2)
	return eased * float(REEL_WIN_AT)


# --- drawing --------------------------------------------------------------------

func _draw() -> void:
	if not visible:
		return
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.012, 0.01, 0.92))
	var plate := Rect2(size * Vector2(0.14, 0.12), size * Vector2(0.72, 0.76))
	draw_rect(plate, GLASS)
	draw_rect(plate, GOLD * Color(1, 1, 1, 0.5), false, 2.0)
	draw_string(font, plate.position + Vector2(28, 38), "THE WIRE EXCHANGE // CASES, SKINS, WARDROBE", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, GOLD)
	var wallet := int(WorldHistory.subject("inventory").get("rust_scrip", 0))
	draw_string(font, Vector2(plate.end.x - 228, plate.position.y + 38), "%d SCRIP" % wallet, HORIZONTAL_ALIGNMENT_RIGHT, 200, 17, MOSS)
	# Tabs.
	var tx := plate.position.x + 28
	for index in TABS.size():
		var label := str(TABS[index])
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 24
		var r := Rect2(Vector2(tx, plate.position.y + 54), Vector2(w, 26))
		if index == tab:
			draw_rect(r, GOLD * Color(1, 1, 1, 0.22))
			draw_rect(r, GOLD, false, 1.0)
		draw_string(font, r.position + Vector2(12, 18), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, GOLD if index == tab else INK * Color(1, 1, 1, 0.6))
		tx += w + 8
	var help: String = "A/D TAB   W/S SELECT   ENTER " + ["BUY / OPEN", "APPLY / TAKE OFF   X SELL", "TAKE OFF / PUT ON   B BREAK THE COLLAR LOCK"][tab] + "   U CLOSE"
	draw_string(font, plate.position + Vector2(28, 102), help, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK * Color(1, 1, 1, 0.6))
	if reeling():
		_draw_reel(font, plate)
		return
	var listed := rows()
	var y := plate.position.y + 120.0
	var visible_rows := int((plate.size.y - 220.0) / 40.0)
	var first := clampi(selected - visible_rows + 1, 0, maxi(listed.size() - visible_rows, 0))
	if listed.is_empty():
		draw_string(font, Vector2(plate.position.x + 40, y + 24), ["", "NO SKINS YET. OPEN A CASE.", "NOTHING WORN, NOTHING IN THE BAG."][tab], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK * Color(1, 1, 1, 0.5))
	for index in range(first, mini(listed.size(), first + visible_rows)):
		var row: Dictionary = listed[index]
		var box := Rect2(Vector2(plate.position.x + 28, y), Vector2(plate.size.x - 56, 34))
		var ink: Color = row.ink
		if index == selected:
			draw_rect(box, GOLD * Color(1, 1, 1, 0.16))
			draw_rect(box, GOLD, false, 1.0)
		draw_rect(Rect2(box.position, Vector2(4, box.size.y)), ink)
		draw_string(font, box.position + Vector2(14, 22), str(row.label), HORIZONTAL_ALIGNMENT_LEFT, box.size.x * 0.55, 15, ink)
		draw_string(font, Vector2(box.end.x - 12 - box.size.x * 0.44, box.position.y + 22), str(row.detail), HORIZONTAL_ALIGNMENT_RIGHT, box.size.x * 0.44, 12, INK * Color(1, 1, 1, 0.75))
		y += 40.0
	_draw_last(font, plate)


func _draw_last(font: Font, plate: Rect2) -> void:
	if last.is_empty():
		return
	var y := plate.end.y - 66.0
	if bool(last.get("ok", false)):
		var tier_id := str(last.get("tier", ""))
		var ink := GOLD
		if last.has("item"):
			ink = _tier_ink(last.item)
		elif TIER_INK.has(tier_id):
			ink = Color(str(TIER_INK[tier_id]))
		var headline := str(last.get("label", ""))
		var note := str(last.get("note", ""))
		if last.has("paid") and not last.has("case"):
			note = "SOLD ON THE WIRE // +%d SCRIP" % int(last.paid)
		elif note.is_empty() and last.has("kind"):
			note = "%s // %s %d" % [tier_id.to_upper(), str(last.get("kind", "")).to_upper(), int(last.get("amount", 0))]
		if headline.is_empty():
			headline = "DONE"
		draw_string(font, Vector2(plate.position.x + 28, y), headline, HORIZONTAL_ALIGNMENT_LEFT, plate.size.x - 56, 16, ink)
		draw_string(font, Vector2(plate.position.x + 28, y + 24), note, HORIZONTAL_ALIGNMENT_LEFT, plate.size.x - 56, 13, INK * Color(1, 1, 1, 0.75))
	else:
		draw_string(font, Vector2(plate.position.x + 28, y), str(last.get("reason", "REFUSED")), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, BLOOD)


func _draw_reel(font: Font, plate: Rect2) -> void:
	var lane := Rect2(Vector2(plate.position.x + 28, plate.position.y + 170), Vector2(plate.size.x - 56, 150))
	draw_rect(lane, Color(0.02, 0.025, 0.022))
	var cell := 170.0
	var centre := lane.position.x + lane.size.x * 0.5
	var offset := reel_position()
	for index in _reel.size():
		var item: Dictionary = _reel[index]
		var x := centre + (float(index) - offset) * cell - cell * 0.5
		if x + cell < lane.position.x or x > lane.end.x:
			continue
		# Clipped to the lane on both sides, so a card sliding in or out never
		# spills over the plate or its neighbour.
		var left := maxf(x + 4, lane.position.x)
		var right := minf(x + cell - 4, lane.end.x)
		if right - left <= 4:
			continue
		var card := Rect2(Vector2(left, lane.position.y + 10), Vector2(right - left, lane.size.y - 20))
		if card.size.x < cell - 8:
			draw_rect(card, Color(0.06, 0.065, 0.06))
			draw_rect(Rect2(Vector2(card.position.x, card.end.y - 8), Vector2(card.size.x, 8)), _tier_ink(item))
			continue
		var ink := _tier_ink(item)
		draw_rect(card, Color(0.06, 0.065, 0.06))
		draw_rect(Rect2(Vector2(card.position.x, card.end.y - 8), Vector2(card.size.x, 8)), ink)
		var parts := str(item.get("label", "")).split(" | ")
		draw_string(font, card.position + Vector2(8, 30), parts[0] if parts.size() > 0 else "", HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 12, 11, INK * Color(1, 1, 1, 0.7))
		draw_string(font, card.position + Vector2(8, 58), parts[1] if parts.size() > 1 else "", HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 12, 14, ink)
		draw_string(font, card.position + Vector2(8, 84), str(WeaponSkins.tier(str(item.get("tier", "issue"))).label), HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 12, 10, ink * Color(1, 1, 1, 0.8))
	# The marker every case is decided under.
	draw_line(Vector2(centre, lane.position.y - 8), Vector2(centre, lane.end.y + 8), GOLD, 3.0)
	draw_rect(lane, GOLD * Color(1, 1, 1, 0.4), false, 1.0)
	draw_string(font, Vector2(lane.position.x, lane.end.y + 40), "OPENING... ENTER TO SKIP", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK * Color(1, 1, 1, 0.6))
