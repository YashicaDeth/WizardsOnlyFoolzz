extends Node

## Short production gameplay reel for AG5.17. This drives the live Hunt scene,
## its real movement actions and the same input events a player uses; it is not
## a posed model showcase. Intended for Godot's deterministic movie writer at
## 30 fps, yielding roughly 36 seconds including scene settle.

var hunt: Node
var frame := 0
var caption: Label


func _ready() -> void:
	WorldHistory.clear_history()
	WorldClock.set_hour(13.0)
	get_window().size = Vector2i(1280, 720)
	hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	for _settle in 75:
		await get_tree().process_frame
	hunt.third_person = false
	hunt.perspective_blend = 0.0
	hunt.body_motion.set_perspective(true)
	_build_caption()
	hunt._equip_smokeable("cigarette")
	caption.text = "LIVE HUNT INPUT // MOVE + CIGARETTE"
	Input.action_press("move_forward")
	frame = 1


func _build_caption() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 92
	hunt.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(28, 22)
	caption.size = Vector2(1224, 36)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 17)
	caption.add_theme_color_override("font_color", Color("f0d5a8"))
	caption.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.96))
	caption.add_theme_constant_override("shadow_offset_x", 2)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(caption)


func _input_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	hunt._unhandled_input(event)


func _input_mouse(button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	hunt._unhandled_input(event)


func _process(_delta: float) -> void:
	if frame <= 0 or hunt == null:
		return
	frame += 1
	# Slow head movement and actual forward motion establish that this is the
	# live controller, not an animation viewer.
	if frame < 125:
		hunt.apply_look(Vector2(0.0035, sin(frame * 0.045) * 0.0004))
	if frame == 125:
		Input.action_release("move_forward")
		caption.text = "HOLD RMB // ZIPPO, INHALE, EMBER BURN"
		hunt._begin_smoking_draw()
	if frame == 215:
		hunt._finish_smoking_draw()
		caption.text = "AUTOMATIC FORWARD EXHALE // CLICK SHAPES IT"
	if frame == 247:
		hunt._shape_smoke_trick()
	if frame == 275:
		caption.text = "Y // PARK THE SAME BURNING CIGARETTE AT THE LIPS"
		hunt._toggle_mouth_hold()
	if frame == 335:
		caption.text = "3 // DRAW SIDEARM WITHOUT LOSING THE CIGARETTE"
		hunt._equip_weapon(2)
		Input.action_press("move_forward")
		Input.action_press("move_right")
	if frame > 335 and frame < 465:
		hunt.apply_look(Vector2(-0.0026, 0.0))
	if frame == 465:
		Input.action_release("move_forward")
		Input.action_release("move_right")
		caption.text = "HOLD ALT // HANDS-FREE PUFF WHILE ARMED"
		_input_key(KEY_ALT, true)
	if frame == 540:
		_input_key(KEY_ALT, false)
		caption.text = "LMB / RMB REMAIN WEAPON CONTROLS"
	if frame == 575:
		_input_mouse(MOUSE_BUTTON_LEFT, true)
	if frame == 620:
		caption.text = "HOLD I // LIVE HELD-ITEM INSPECTION"
		hunt.inspect_held = true
	if frame == 710:
		hunt.inspect_held = false
		caption.text = "5 // HOLSTER; CIGARETTE STAYS AT THE LIPS"
		hunt._put_the_weapons_down()
	if frame == 770:
		caption.text = "Y // THE FREE HAND TAKES IT BACK"
		hunt._toggle_mouth_hold()
	if frame == 835:
		caption.text = "THE SAME OBJECT KEEPS BURNING BETWEEN DRAWS"
		hunt._begin_smoking_draw()
	if frame == 920:
		hunt._finish_smoking_draw()
	if frame == 970:
		caption.text = "MOVE · SMOKE · MOUTH-HOLD · FIGHT · INSPECT"
		Input.action_press("move_left")
	if frame > 970 and frame < 1040:
		hunt.apply_look(Vector2(0.0025, 0.0))
	if frame == 1040:
		Input.action_release("move_left")
	if frame >= 1080:
		get_tree().quit()
