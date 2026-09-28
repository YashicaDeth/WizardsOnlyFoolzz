class_name FieldMeds
extends RefCounted

## Greg, 26 September (question boxes): meds go on hold-4, and a dressing heals
## 20. Tapping 4 keeps what it already did (the carried limb in the Hunt); only
## a held 4 opens a FIELD DRESSING from the carry list. One shared piece so the
## vat room, every opening area and the Hunt all answer the same key the same
## way.
##
## Each scene owns one instance and calls `tick()` every frame with whether 4
## is down. It returns "" while nothing happens, "holding" while the bar fills,
## "used" on the frame a dressing is spent (the scene heals then), "none" once
## when 4 is held with nothing to open, and "tap" when 4 is released early.

## "A few seconds ... no fighting while you do it" (DESIGN.md, 26 September).
const HOLD_SECONDS := 2.5
const HEALS := 20.0
const LABEL := "FIELD DRESSING"

var held := 0.0
var _spent_this_hold := false


## A carry entry is a stash dressing (a dictionary) or the Hunt broker's
## plain "field dressing" string; both count.
static func _is_dressing(entry: Variant) -> bool:
	if entry is Dictionary:
		return str((entry as Dictionary).get("label", "")).to_upper() == LABEL
	return entry is String and (entry as String).to_upper() == LABEL


static func count() -> int:
	var total := 0
	for entry in WorldHistory.subject("inventory").get("items", []):
		if _is_dressing(entry):
			total += 1
	return total


## Takes one dressing off the carry list. False when there is none.
static func take_one() -> bool:
	var items: Array = (WorldHistory.subject("inventory").get("items", []) as Array).duplicate(true)
	for index in items.size():
		if _is_dressing(items[index]):
			items.remove_at(index)
			WorldHistory.update_subject("inventory", {"items": items}, "carry_changed")
			WorldHistory.record_event("field_dressing_used", {"heals": HEALS})
			return true
	return false


## Heals an anatomy-driven body (the vat room, the Hunt): 20 in the same units
## the 100-blood scenes use, so 20% of its blood, the worst zone patched by
## 20, and its bleeding mostly stopped.
static func heal_anatomy(anatomy: Node) -> void:
	if anatomy == null or bool(anatomy.get("dead")):
		return
	var capacity := float(anatomy.get("blood_capacity"))
	anatomy.set("blood_remaining", minf(capacity, float(anatomy.get("blood_remaining")) + capacity * HEALS / 100.0))
	var zones: Dictionary = anatomy.get("zones")
	var full: Dictionary = anatomy.get("DEFAULT_ZONES")
	var worst := ""
	var worst_ratio := INF
	for zone_id: String in zones:
		var top := float((full.get(zone_id, {}) as Dictionary).get("health", 100.0))
		var ratio := float((zones[zone_id] as Dictionary).get("health", top)) / maxf(top, 1.0)
		if ratio < worst_ratio:
			worst_ratio = ratio
			worst = zone_id
	if not worst.is_empty() and worst_ratio < 1.0:
		var zone: Dictionary = zones[worst]
		var top := float((full.get(worst, {}) as Dictionary).get("health", 100.0))
		zone["health"] = minf(top, float(zone.get("health", top)) + HEALS)
		zones[worst] = zone
		anatomy.call("treat_wound", worst, 0.7)


## True while a dressing is being put on: the scene holds its attacks.
func busy() -> bool:
	return held > 0.0 and not _spent_this_hold


## 0..1 of the hold, for the prompt bar.
func progress() -> float:
	return clampf(held / HOLD_SECONDS, 0.0, 1.0)


func tick(delta: float, key_down: bool) -> String:
	if not key_down:
		var was := held
		held = 0.0
		var spent := _spent_this_hold
		_spent_this_hold = false
		return "tap" if was > 0.0 and was < HOLD_SECONDS and not spent else ""
	if _spent_this_hold:
		return ""
	if held == 0.0 and count() == 0:
		held = HOLD_SECONDS
		_spent_this_hold = true
		return "none"
	held += delta
	if held < HOLD_SECONDS:
		return "holding"
	_spent_this_hold = true
	return "used" if take_one() else "none"


## The prompt line while holding: a bar of ten.
func bar_text() -> String:
	var filled := int(round(progress() * 10.0))
	return "[HOLD 4] FIELD DRESSING  %s%s  x%d" % ["|".repeat(filled), ".".repeat(10 - filled), count()]


## The whole key in one call for a scene: reads 4, draws its own line (so a
## scene's HUD refresh cannot overwrite it) and calls `heal` when a dressing
## is spent. Returns what `tick()` returned.
func step(host: Node, delta: float, heal: Callable, key_down: Variant = null) -> String:
	var down: bool = key_down if key_down != null else Input.is_physical_key_pressed(KEY_4)
	var result := tick(delta, down)
	match result:
		"holding":
			line(host, bar_text(), 0.3)
		"used":
			heal.call()
			line(host, "FIELD DRESSING // +%d BLOOD  (%d LEFT)" % [int(HEALS), count()], 2.2)
		"none":
			line(host, "NO FIELD DRESSING // STASHES HIDE THEM (K, J)", 2.2)
	return result


## One bottom-centre line of its own, above the scene's HUD.
static func line(host: Node, text: String, seconds: float) -> void:
	var layer := host.get_node_or_null("FieldMedsLine") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "FieldMedsLine"
		layer.layer = 40
		host.add_child(layer)
		var label := Label.new()
		label.name = "Line"
		label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		label.offset_top = -132.0
		label.offset_bottom = -104.0
		label.offset_left = -360.0
		label.offset_right = 360.0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color("ead4ad"))
		label.add_theme_color_override("font_outline_color", Color(0.05, 0.01, 0.01))
		label.add_theme_constant_override("outline_size", 6)
		label.add_theme_font_size_override("font_size", 17)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(label)
	var shown := layer.get_node("Line") as Label
	shown.text = text
	shown.visible = true
	layer.set_meta("until", Time.get_ticks_msec() + int(seconds * 1000.0))
	if not layer.has_meta("timer"):
		layer.set_meta("timer", true)
		_hide_later(layer)


static func _hide_later(layer: CanvasLayer) -> void:
	while is_instance_valid(layer) and Time.get_ticks_msec() < int(layer.get_meta("until", 0)):
		await layer.get_tree().process_frame
	if is_instance_valid(layer):
		(layer.get_node("Line") as Label).visible = false
		layer.remove_meta("timer")
