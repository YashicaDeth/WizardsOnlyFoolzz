class_name KeyHints
extends CanvasLayer

## Greg, 28 September: friends who know nothing get each new key once,
## bottom centre and big (the key, then the verb), gone once they use it.
## A scene adds one of these and calls `offer(id, key, verb)` when a key first
## matters; hints queue up, each shows until its key is pressed (or 8 s pass),
## and a hint shown once is never shown again in this world.
##
## Keyboard only: the game has no controller bindings yet (DESIGN.md, 28
## September). When it does, `offer` takes the pad button too.

const SUBJECT := "key_hints"
const HOLD_SECONDS := 8.0
const BONE := Color("ead4ad")
const COPPER := Color("dc5827")

var queue: Array = []
var current: Dictionary = {}
var age := 0.0
var _key: Label
var _verb: Label
var _panel: Panel


static func seen(id: String) -> bool:
	return (WorldHistory.subject(SUBJECT).get("seen", []) as Array).has(id)


func _ready() -> void:
	layer = 45
	name = "KeyHints"
	_panel = Panel.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.02, 0.01, 0.01, 0.78)
	box.border_color = Color(COPPER, 0.8)
	box.set_border_width_all(2)
	box.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", box)
	add_child(_panel)
	_key = Label.new()
	_key.add_theme_font_size_override("font_size", 34)
	_key.add_theme_color_override("font_color", COPPER)
	_panel.add_child(_key)
	_verb = Label.new()
	_verb.add_theme_font_size_override("font_size", 22)
	_verb.add_theme_color_override("font_color", BONE)
	_panel.add_child(_verb)
	_panel.visible = false


## `keycode` is what dismisses it; `key` is what is printed ("E", "HOLD 4").
func offer(id: String, keycode: Key, key: String, verb: String) -> void:
	if seen(id) or id == str(current.get("id", "")):
		return
	for waiting: Dictionary in queue:
		if str(waiting.id) == id:
			return
	queue.append({"id": id, "keycode": keycode, "key": key, "verb": verb})


func _process(delta: float) -> void:
	if current.is_empty():
		if queue.is_empty():
			return
		current = queue.pop_front()
		age = 0.0
		_key.text = str(current.key)
		_verb.text = str(current.verb).to_upper()
		_layout()
		_panel.visible = true
	age += delta
	_panel.modulate.a = clampf(age / 0.25, 0.0, 1.0)
	if age >= HOLD_SECONDS:
		_done()


func _input(event: InputEvent) -> void:
	if current.is_empty() or not (event is InputEventKey) or not event.pressed:
		return
	if (event as InputEventKey).keycode == int(current.keycode) or (event as InputEventKey).physical_keycode == int(current.keycode):
		_done()


func _done() -> void:
	var list: Array = (WorldHistory.subject(SUBJECT).get("seen", []) as Array).duplicate()
	list.append(str(current.id))
	WorldHistory.update_subject(SUBJECT, {"kind": "ui", "seen": list}, "key_hint_seen")
	current = {}
	_panel.visible = false


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var key_size := _key.get_minimum_size()
	var verb_size := _verb.get_minimum_size()
	var width := key_size.x + verb_size.x + 44.0
	var height := maxf(key_size.y, verb_size.y) + 20.0
	_panel.size = Vector2(width, height)
	_panel.position = Vector2((view.x - width) * 0.5, view.y - height - 150.0)
	_key.position = Vector2(12, (height - key_size.y) * 0.5)
	_verb.position = Vector2(key_size.x + 30.0, (height - verb_size.y) * 0.5)
