class_name BrainIndexHub
extends Control

## The Brain Index hub (Greg, 2026-09-24): one large overlay on Tab. Your real
## body floats in a vat on the right -- drag to turn it, click a part to read
## it -- and the left holds what the tab is about. Tabs in his order: CARRY,
## COMBAT, BRAIN INDEX, TASKS, MAP. It reads what the game already tracks
## (arsenal, carry, anatomy, the Brain Index folders, recorded hits and kills)
## and owns no numbers of its own.
##
## First pass for his feedback: the look is the skeuomorphic chrome frame the
## intake uses; the combat tab shows real stats before any points exist.

signal open_surface(surface: String)

const CellOutzType := preload("res://systems/celloutz_type.gd")
const VAT_BODY_PREVIEW := preload("res://systems/vat_body_preview.gd")
const TABS := ["CARRY", "COMBAT", "BRAIN INDEX", "TASKS", "MAP"]
const INK := Color("e8d6b4")
const DIM := Color("8f7c66")
const HOT := Color("d8402c")
const TEAL := Color("5fc4b4")
const GROUND := Color(0.035, 0.02, 0.022, 0.96)
## One colour per kind of thing carried, so the bag stops being nine identical
## placeholder bottles (Greg's walkthrough).
const KIND_TINT := {
	"skin": Color("d9a38a"), "fat": Color("e8d27a"), "muscle": Color("b43a34"), "bone": Color("e6dfc9"),
	"organ": Color("8e1e2a"), "cybernetic": Color("7fb8c9"), "limb": Color("c46a55"), "substance": Color("8f6ad1"),
}

var tab := 0
## The blood ledger, when the host has one: the COMBAT tab reads it.
var blood_ledger: Object
var carry: Object
var arsenal: Object
var player_rig: Node
var body: Control
var selected_zone := ""
var _tab_rects: Array[Rect2] = []
var _dragging := false
var _clock := 0.0
## Drawn above the 3D body: a parent's own drawing sits underneath its
## children, so the tracker box on a chosen part needs a layer of its own.
var _marks: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body = VAT_BODY_PREVIEW.new()
	body.name = "HubBody"
	add_child(body)
	_marks = Control.new()
	_marks.name = "PartMarks"
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marks.draw.connect(_draw_marks)
	add_child(_marks)
	resized.connect(_layout)
	visible = false


func open(carry_model: Object, weapons: Object, rig: Node) -> void:
	carry = carry_model
	arsenal = weapons
	player_rig = rig
	selected_zone = ""
	visible = true
	_layout()
	# The body as the world has it now: wounds, build, anatomy.
	var record: Dictionary = WorldHistory.subject("player").duplicate(true)
	body.call("present", record)
	# The body in the vat wears what you wear: the jester parts, their skins,
	# and the censor where nothing covers you (Greg, 24 September).
	var preview_rig := body.get("rig") as BaselineHuman
	if preview_rig != null and is_instance_valid(preview_rig):
		Outfit.dress(preview_rig)
	queue_redraw()


func close() -> void:
	visible = false


func _layout() -> void:
	if body == null:
		return
	var vat := _vat_rect()
	body.position = vat.position + Vector2(10, 10)
	body.size = vat.size - Vector2(20, 60)


func _frame() -> Rect2:
	return Rect2(Vector2(size.x * 0.06, size.y * 0.07), Vector2(size.x * 0.88, size.y * 0.86))


func _vat_rect() -> Rect2:
	var frame := _frame()
	return Rect2(Vector2(frame.end.x - frame.size.x * 0.34 - 18, frame.position.y + 70), Vector2(frame.size.x * 0.34, frame.size.y - 88))


func _content_rect() -> Rect2:
	var frame := _frame()
	return Rect2(frame.position + Vector2(24, 76), Vector2(frame.size.x * 0.6, frame.size.y - 100))


# --- input -------------------------------------------------------------------

func handle_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB, KEY_ESCAPE:
				open_surface.emit("close")
			KEY_RIGHT, KEY_E:
				tab = (tab + 1) % TABS.size()
			KEY_LEFT, KEY_Q:
				tab = posmod(tab - 1, TABS.size())
			KEY_ENTER, KEY_KP_ENTER:
				if TABS[tab] == "TASKS":
					open_surface.emit("index")
				elif TABS[tab] == "MAP":
					open_surface.emit("map")
			_:
				return true
		queue_redraw()
		return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			for index in _tab_rects.size():
				if _tab_rects[index].has_point(event.position):
					tab = index
					queue_redraw()
					return true
			if _vat_rect().has_point(event.position):
				_dragging = true
				body.set("held", true)
				_pick(event.position - body.position)
		else:
			_dragging = false
			body.set("held", false)
		return true
	if event is InputEventMouseMotion and _dragging:
		body.set("spin_offset", float(body.get("spin_offset")) + event.relative.x * 0.012)
		return true
	return event is InputEventMouse


## The nearest body part under the click, from where the preview drew it.
func _pick(local: Vector2) -> void:
	var best := ""
	var best_distance := 46.0
	var parts: Dictionary = body.call("part_positions")
	for zone in parts:
		var distance := (parts[zone] as Vector2).distance_to(local)
		if distance < best_distance:
			best_distance = distance
			best = str(zone)
	if best != "":
		selected_zone = best
	queue_redraw()


func _process(delta: float) -> void:
	if visible:
		_clock += delta
		queue_redraw()
		_marks.queue_redraw()


# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.72))
	var frame := _frame()
	_chrome(frame)
	CellOutzType.draw_stamped(self, frame.position + Vector2(26, 18), "BRAIN INDEX", 22.0, INK, HOT * Color(1, 1, 1, 0.3), 2.0)
	CellOutzType.draw_condensed(self, frame.position + Vector2(26, 50), "WETWIRE // CUSTODY OF ONE BODY", 8.0, DIM, 0.8)
	_draw_tabs(frame)
	var content := _content_rect()
	draw_rect(content, Color(0, 0, 0, 0.35))
	draw_rect(content, DIM * Color(1, 1, 1, 0.4), false, 1.0)
	match TABS[tab]:
		"CARRY":
			_draw_carry(content)
		"COMBAT":
			_draw_combat(content)
		"BRAIN INDEX":
			_draw_index(content)
		"TASKS":
			_draw_handoff(content, "TASKS", "Contracts, bounties and the world index.", "ENTER OPENS THE WORLD INDEX")
		"MAP":
			_draw_handoff(content, "MAP", "The satellite first; L turns to the facility sheet.", "ENTER OPENS THE MAP")
	_draw_vat()
	CellOutzType.draw_condensed(self, Vector2(frame.position.x + 26, frame.end.y - 16), "TAB CLOSES  //  Q E OR ARROWS: TABS  //  DRAG THE BODY TO TURN IT  //  CLICK A PART TO READ IT", 8.0, DIM, 0.7)


## Brushed chrome: a bright upper bevel, a dark lower one, rivets. The frame
## the intake taught the player to read as "a CellOutz object".
func _chrome(frame: Rect2) -> void:
	draw_rect(frame, GROUND)
	var steps := 6
	for i in steps:
		var t := float(i) / float(steps)
		var edge := frame.grow(-float(i))
		draw_rect(edge, Color(0.78, 0.74, 0.68).lerp(Color(0.18, 0.15, 0.14), t) * Color(1, 1, 1, 0.9 - t * 0.6), false, 1.0)
	var header := Rect2(frame.position + Vector2(8, 8), Vector2(frame.size.x - 16, 50))
	draw_polygon(PackedVector2Array([header.position, Vector2(header.end.x, header.position.y), header.end, Vector2(header.position.x, header.end.y)]),
		PackedColorArray([Color(0.30, 0.26, 0.24), Color(0.20, 0.17, 0.16), Color(0.08, 0.06, 0.06), Color(0.12, 0.09, 0.09)]))
	for corner in [frame.position + Vector2(14, 14), Vector2(frame.end.x - 14, frame.position.y + 14), frame.end - Vector2(14, 14), Vector2(frame.position.x + 14, frame.end.y - 14)]:
		draw_circle(corner, 4.0, Color(0.6, 0.56, 0.5))
		draw_circle(corner + Vector2(-1, -1), 1.6, Color(0.95, 0.92, 0.86))


func _draw_tabs(frame: Rect2) -> void:
	_tab_rects.clear()
	var x := frame.position.x + 480.0
	for index in TABS.size():
		var label: String = TABS[index]
		var width := CellOutzType.width_condensed(label, 11.0, 0.9) + 28.0
		var rect := Rect2(Vector2(x, frame.position.y + 20), Vector2(width, 28))
		_tab_rects.append(rect)
		var active := index == tab
		draw_rect(rect, (HOT if active else Color(0.16, 0.13, 0.12)) * Color(1, 1, 1, 0.9 if active else 0.8))
		draw_rect(rect, INK * Color(1, 1, 1, 0.5 if active else 0.2), false, 1.0)
		CellOutzType.draw_condensed(self, rect.position + Vector2(14, 9), label, 11.0, INK if active else DIM, 0.9)
		x += width + 6.0


func _heading(at: Vector2, text: String) -> void:
	CellOutzType.draw_condensed(self, at, text, 11.0, HOT, 0.9)
	draw_line(at + Vector2(0, 16), at + Vector2(260, 16), HOT * Color(1, 1, 1, 0.35), 1.0)


func _draw_carry(rect: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var y := rect.position.y + 18.0
	_heading(Vector2(rect.position.x + 16, y), "LOADOUT")
	y += 30.0
	if arsenal != null:
		for weapon_id in arsenal.carried():
			var current := str(weapon_id) == str(arsenal.current_id)
			var label := str(arsenal.weapon_definition(str(weapon_id)).get("label", str(weapon_id).to_upper())) if arsenal.has_method("weapon_definition") else str(weapon_id).to_upper()
			draw_string(font, Vector2(rect.position.x + 24, y + 14), ("> " if current else "  ") + label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x * 0.45, 15, INK if current else DIM)
			# Its skin, in its tier's colour, and how worn it is.
			var skin := SkinLoadout.applied(str(weapon_id))
			if not skin.is_empty():
				var finish := str(skin.get("label", "")).get_slice(" | ", 1)
				var band := str(WeaponSkins.wear_band(float(skin.get("wear", 0.0))).short)
				draw_string(font, Vector2(rect.position.x + rect.size.x * 0.48, y + 14), "%s  %s" % [finish, band], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x * 0.5, 13, Color(str(WeaponSkins.tier(str(skin.get("tier", "issue"))).ink)))
			y += 22.0
	y += 10.0
	var worn := Outfit.worn()
	_heading(Vector2(rect.position.x + 16, y), "WORN  //  " + ("COLLAR LOCKED" if bool(worn.locked) else "YOURS TO TAKE OFF"))
	y += 28.0
	if (worn.parts as Dictionary).is_empty():
		draw_string(font, Vector2(rect.position.x + 24, y + 12), "NOTHING. THE CENSOR COVERS WHAT CLOTH DOES NOT.", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 48, 12, DIM)
		y += 20.0
	else:
		var names: Array = []
		for part_id: String in worn.parts:
			names.append(str(Outfit.PARTS.get(part_id, {}).get("label", part_id)))
		draw_string(font, Vector2(rect.position.x + 24, y + 12), "  //  ".join(names), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 48, 12, INK)
		y += 20.0
	y += 14.0
	var items: Array = carry.items if carry != null else []
	var mass: float = carry.total_mass() if carry != null else 0.0
	_heading(Vector2(rect.position.x + 16, y), "CARRIED / %d   %.1f / %.0f KG" % [items.size(), mass, 28.0])
	y += 30.0
	var bar := Rect2(Vector2(rect.position.x + 24, y), Vector2(rect.size.x - 48, 5))
	draw_rect(bar, DIM * Color(1, 1, 1, 0.2))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(mass / 28.0, 0.0, 1.0), bar.size.y)), TEAL)
	y += 16.0
	var columns := 2
	var cell := Vector2((rect.size.x - 48) / columns, 30)
	for index in items.size():
		var item: Dictionary = items[index]
		var at := Vector2(rect.position.x + 24 + (index % columns) * cell.x, y + (index / columns) * cell.y)
		if at.y > rect.end.y - 44:
			draw_string(font, Vector2(rect.position.x + 24, rect.end.y - 14), "+%d MORE" % (items.size() - index), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DIM)
			break
		var kind := str(item.get("kind", ""))
		var tint: Color = KIND_TINT.get(kind, DIM)
		if kind == "skin":
			tint = Color(str(WeaponSkins.tier(str(item.get("tier", "issue"))).ink))
		_icon(at + Vector2(8, 14), kind, tint)
		draw_string(font, at + Vector2(24, 19), str(item.get("label", "?")), HORIZONTAL_ALIGNMENT_LEFT, cell.x - 30, 13, INK)


## A small drawn icon per kind of thing, so the bag stops being one
## placeholder shape (Greg's walkthrough: "carry icons are all the same").
func _icon(c: Vector2, kind: String, tint: Color) -> void:
	var line := INK * Color(1, 1, 1, 0.55)
	match kind:
		"weapon":
			draw_rect(Rect2(c + Vector2(-8, -5), Vector2(16, 5)), tint)
			draw_rect(Rect2(c + Vector2(-7, 0), Vector2(5, 8)), tint)
		"tool":
			draw_line(c + Vector2(-7, 7), c + Vector2(5, -5), tint, 3.0)
			draw_circle(c + Vector2(5, -5), 3.5, tint)
		"ammo":
			for i in 3:
				draw_rect(Rect2(c + Vector2(-7 + i * 5, -6), Vector2(3, 12)), tint)
		"skin":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -8), c + Vector2(7, 0), c + Vector2(0, 8), c + Vector2(-7, 0)]), tint)
		"case":
			draw_rect(Rect2(c + Vector2(-8, -5), Vector2(16, 11)), tint)
			draw_rect(Rect2(c + Vector2(-3, -8), Vector2(6, 3)), tint)
			draw_line(c + Vector2(-8, 0), c + Vector2(8, 0), Color(0, 0, 0, 0.5), 1.0)
		"garment":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -6), c + Vector2(-3, -8), c + Vector2(3, -8), c + Vector2(8, -6), c + Vector2(6, -1), c + Vector2(4, -2), c + Vector2(4, 8), c + Vector2(-4, 8), c + Vector2(-4, -2), c + Vector2(-6, -1)]), tint)
		"substance", "drug", "smokeable":
			draw_rect(Rect2(c + Vector2(-3, -8), Vector2(6, 16)), tint)
			draw_rect(Rect2(c + Vector2(-4, -9), Vector2(8, 3)), line)
		"cybernetic":
			draw_rect(Rect2(c + Vector2(-6, -6), Vector2(12, 12)), tint)
			for i in 3:
				draw_line(c + Vector2(-9, -4 + i * 4), c + Vector2(-6, -4 + i * 4), tint, 1.0)
				draw_line(c + Vector2(6, -4 + i * 4), c + Vector2(9, -4 + i * 4), tint, 1.0)
		"organ", "meat", "chunk", "muscle", "fat", "limb":
			draw_circle(c + Vector2(-2, 0), 6.0, tint)
			draw_circle(c + Vector2(3, 2), 5.0, tint)
		"bone":
			draw_line(c + Vector2(-6, 6), c + Vector2(6, -6), tint, 3.0)
			draw_circle(c + Vector2(-6, 6), 2.5, tint)
			draw_circle(c + Vector2(6, -6), 2.5, tint)
		_:
			draw_rect(Rect2(c + Vector2(-5, -8), Vector2(10, 16)), tint * Color(1, 1, 1, 0.85))
	draw_rect(Rect2(c + Vector2(-10, -10), Vector2(20, 20)), line * Color(1, 1, 1, 0.4), false, 1.0)


func _draw_combat(rect: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var y := rect.position.y + 18.0
	_heading(Vector2(rect.position.x + 16, y), "BLOOD  //  WHAT FIGHTING HAS EARNED")
	y += 34.0
	# Blood per style (the four trees), as bars: earned in total, and what is
	# left to spend. The ledger owns the numbers.
	var width := rect.size.x - 280.0
	for style_id in BloodTrees.STYLE_ORDER:
		var spec: Dictionary = BloodTrees.STYLES[style_id]
		var earned := int(blood_ledger.style_earned(style_id)) if blood_ledger != null else 0
		var left := int(blood_ledger.available(style_id)) if blood_ledger != null else 0
		draw_string(font, Vector2(rect.position.x + 24, y + 12), str(spec.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)
		var track := Rect2(Vector2(rect.position.x + 170, y + 3), Vector2(width, 10))
		draw_rect(track, DIM * Color(1, 1, 1, 0.2))
		var scale_ := maxf(200.0, float(earned))
		draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(float(earned) / scale_, 0.0, 1.0), track.size.y)), (spec.tone as Color) * Color(1, 1, 1, 0.5))
		draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(float(left) / scale_, 0.0, 1.0), track.size.y)), spec.tone)
		draw_string(font, Vector2(track.end.x + 12, y + 12), "%d / %d" % [left, earned], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DIM)
		y += 26.0
	y += 14.0
	_heading(Vector2(rect.position.x + 16, y), "BY WEAPON")
	y += 30.0
	if arsenal != null:
		for weapon_id in arsenal.carried():
			var blood := int(blood_ledger.weapon_blood(str(weapon_id))) if blood_ledger != null else 0
			var skin := SkinLoadout.applied(str(weapon_id))
			var kills := int(skin.get("kills", 0))
			var label := str(arsenal.weapon_definition(str(weapon_id)).get("label", str(weapon_id).to_upper()))
			draw_string(font, Vector2(rect.position.x + 24, y), label, HORIZONTAL_ALIGNMENT_LEFT, 190, 14, INK if str(weapon_id) == str(arsenal.current_id) else DIM)
			var tally := ("   //   %d KILL%s ON ITS SKIN" % [kills, "" if kills == 1 else "S"]) if kills > 0 else ""
			draw_string(font, Vector2(rect.position.x + 220, y), "%d BLOOD%s" % [blood, tally], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
			y += 22.0
	y += 16.0
	var rows := [["BODIES OPENED", WorldHistory.event_count("npc_anatomy_hit")], ["KILLED", WorldHistory.event_count("npc_killed")]]
	if player_rig != null and player_rig.get("anatomy") != null:
		rows.append(["PAIN", "%d" % roundi(float(player_rig.anatomy.pain))])
	for row in rows:
		draw_string(font, Vector2(rect.position.x + 24, y), str(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DIM)
		draw_string(font, Vector2(rect.position.x + 220, y), str(row[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)
		y += 22.0
	CellOutzType.draw_condensed(self, Vector2(rect.position.x + 24, rect.end.y - 22), "7 OPENS THE BLOOD TREES  //  U OPENS THE WIRE EXCHANGE: SKINS, CASES, WARDROBE", 9.0, TEAL, 0.8)


func _draw_index(rect: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var y := rect.position.y + 18.0
	_heading(Vector2(rect.position.x + 16, y), "FOLDERS  //  PEOPLE AND KINSHIP LIVE HERE")
	y += 42.0
	var counts: Dictionary = BrainIndex.folder_counts("player")
	var column := 0
	for folder_id in BrainIndex.FOLDERS:
		var spec: Dictionary = BrainIndex.FOLDERS[folder_id]
		var count = counts.get(folder_id, {})
		var open := int(count.get("open", 0)) if count is Dictionary else int(count)
		var total := int(count.get("total", open)) if count is Dictionary else open
		var at := Vector2(rect.position.x + 24 + column * (rect.size.x * 0.5), y)
		draw_string(font, at, str(spec.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK if open > 0 else DIM)
		draw_string(font, at + Vector2(rect.size.x * 0.5 - 90, 0), "%02d / %02d" % [open, total], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TEAL if open > 0 else DIM)
		column = 1 - column
		if column == 0:
			y += 24.0


func _draw_handoff(rect: Rect2, title: String, note: String, action: String) -> void:
	var font := ThemeDB.fallback_font
	_heading(rect.position + Vector2(16, 18), title)
	draw_string(font, rect.position + Vector2(24, 70), note, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 48, 15, INK)
	var button := Rect2(rect.position + Vector2(24, 100), Vector2(300, 36))
	draw_rect(button, HOT * Color(1, 1, 1, 0.25 + 0.1 * sin(_clock * 3.0)))
	draw_rect(button, HOT, false, 1.0)
	CellOutzType.draw_condensed(self, button.position + Vector2(14, 13), action, 11.0, INK, 0.9)


func _draw_vat() -> void:
	var vat := _vat_rect()
	draw_rect(vat, Color(0.2, 0.18, 0.16), false, 2.0)
	CellOutzType.draw_condensed(self, Vector2(vat.position.x + 10, vat.end.y - 40), "SUBJECT // LIVE", 9.0, DIM, 0.7)
	if selected_zone.is_empty() or player_rig == null or player_rig.get("anatomy") == null:
		CellOutzType.draw_condensed(self, Vector2(vat.position.x + 10, vat.end.y - 24), "CLICK A PART", 9.0, DIM, 0.7)
		return
	var zones: Dictionary = player_rig.anatomy.zones
	var zone: Dictionary = zones.get(selected_zone, {})
	var max_health := float((AnatomyComponent.DEFAULT_ZONES.get(selected_zone, {}) as Dictionary).get("health", 100.0))
	var health := float(zone.get("health", max_health))
	var line := "%s  //  %d / %d%s" % [selected_zone.replace("_", " ").to_upper(), roundi(health), roundi(max_health), "  //  GONE" if bool(zone.get("severed", false)) else ""]
	CellOutzType.draw_condensed(self, Vector2(vat.position.x + 10, vat.end.y - 24), line, 10.0, HOT if health < max_health * 0.5 else TEAL, 0.8)


func _draw_marks() -> void:
	if not visible or selected_zone.is_empty():
		return
	var parts: Dictionary = body.call("part_positions")
	if not parts.has(selected_zone):
		return
	# The tracker box on the chosen part, in the same register as the fight.
	var centre: Vector2 = body.position + (parts[selected_zone] as Vector2)
	var box := Rect2(centre - Vector2(28, 28), Vector2(56, 56))
	_marks.draw_rect(box, TEAL, false, 1.0)
	_marks.draw_line(centre - Vector2(6, 0), centre + Vector2(6, 0), TEAL, 1.0)
	_marks.draw_line(centre - Vector2(0, 6), centre + Vector2(0, 6), TEAL, 1.0)
