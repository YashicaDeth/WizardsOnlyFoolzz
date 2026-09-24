class_name CaseMenu
extends Control

## The dead cloud's shopfront: two cases, a wallet, and a reveal. ENTER buys
## the selected box for its price and opens it on a fresh draw; the receipt
## lands through `Carry` so scrip, items and patches all arrive by verbs the
## game already has. Gold is the top row in gold because it should feel like
## it from across the room.

signal close_requested

const CASE := preload("res://systems/loot_case.gd")

const INK := Color("d9c79a")
const BLOOD := Color("a92e32")
const MOSS := Color("8ea85d")
const GOLD := Color("d8a828")
const GLASS := Color("090b0a")

const TIER_INK := {"scrap": "d9c79a", "useful": "8ea85d", "rare": "6a9ad8", "relic": "9a6ad8", "gold": "d8a828"}

var carry: Carry
var body: BaselineHuman
var selected := 0
var last: Dictionary = {}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	visible = false


func open_menu(carry_model: Carry, body_rig: BaselineHuman) -> void:
	carry = carry_model
	body = body_rig
	selected = 0
	last = {}
	visible = true
	queue_redraw()


func close_menu() -> void:
	visible = false


func case_ids() -> Array:
	return CASE.CASES.keys()


func handle_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_U:
				close_requested.emit()
			KEY_UP, KEY_W:
				selected = posmod(selected - 1, case_ids().size())
				queue_redraw()
			KEY_DOWN, KEY_S:
				selected = posmod(selected + 1, case_ids().size())
				queue_redraw()
			KEY_ENTER, KEY_KP_ENTER:
				_buy_and_open()
		return true
	return event is InputEventMouseMotion


func _buy_and_open() -> void:
	if carry == null:
		return
	var ids := case_ids()
	if selected < 0 or selected >= ids.size():
		return
	var case_id := str(ids[selected])
	var price := int((CASE.CASES.get(case_id, {}) as Dictionary).get("price", 0))
	var paid: Dictionary = carry.spend(price, "case bought")
	if not bool(paid.get("ok", false)):
		last = {"ok": false, "reason": str(paid.get("reason", "REFUSED"))}
		queue_redraw()
		return
	var receipt: Dictionary = CASE.open(case_id, randf(), true)
	var landed: Dictionary = carry.take_case_winnings(receipt, body)
	last = receipt
	last["note"] = str(landed.get("note", ""))
	last["landed_ok"] = bool(landed.get("ok", false))
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
	var plate := Rect2(size * Vector2(0.2, 0.18), size * Vector2(0.6, 0.64))
	draw_rect(plate, GLASS)
	draw_rect(plate, GOLD * Color(1, 1, 1, 0.5), false, 2.0)
	draw_string(font, plate.position + Vector2(28, 38), "DEAD CLOUD EXCHANGE // CASH IN, SORTED OUT", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, GOLD)
	draw_string(font, plate.position + Vector2(28, 62), "UP/DOWN SELECT   ENTER BUY AND OPEN   U / ESC CLOSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK * Color(1, 1, 1, 0.65))
	var wallet := 0
	if carry != null:
		wallet = int(WorldHistory.subject("inventory").get("rust_scrip", 0))
	draw_string(font, Vector2(plate.end.x - 28, 38), "%d SCRIP" % wallet, HORIZONTAL_ALIGNMENT_RIGHT, 200, 17, MOSS)
	var y := plate.position.y + 100.0
	var ids := case_ids()
	for index in ids.size():
		var spec: Dictionary = CASE.CASES.get(str(ids[index]), {})
		var row := Rect2(Vector2(plate.position.x + 28, y), Vector2(plate.size.x - 56, 44))
		if index == selected:
			draw_rect(row, GOLD * Color(1, 1, 1, 0.18))
			draw_rect(row, GOLD, false, 1.0)
		draw_string(font, row.position + Vector2(12, 20), str(spec.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK)
		draw_string(font, Vector2(row.end.x - 12, row.position.y + 20), "%d" % int(spec.get("price", 0)), HORIZONTAL_ALIGNMENT_RIGHT, 100, 15, MOSS)
		y += 52.0
	y += 12.0
	if not last.is_empty():
		if bool(last.get("ok", false)):
			var ink := Color(str(TIER_INK.get(str(last.get("tier", "scrap")), "d9c79a")))
			draw_string(font, Vector2(plate.position.x + 28, y), str(last.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
			draw_string(font, Vector2(plate.position.x + 28, y + 24), "%s // %s %d" % [str(last.get("tier", "")).to_upper(), str(last.get("kind", "")).to_upper(), int(last.get("amount", 0))], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
			draw_string(font, Vector2(plate.position.x + 28, y + 44), str(last.get("note", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK * Color(1, 1, 1, 0.7))
		else:
			draw_string(font, Vector2(plate.position.x + 28, y), str(last.get("reason", "REFUSED")), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, BLOOD)
