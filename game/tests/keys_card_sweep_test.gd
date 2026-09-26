extends Node

## Greg, 26 September: "all the F1 keys being looked at and checked". Starts
## the Hunt directly (as Play-Overworld.bat does), presses every key the F1
## card lists, and reports what each one changed. A key that changes nothing
## observable, or throws, is a failure.

var failures: Array[String] = []
var hunt
var _current := ""


func snapshot() -> Dictionary:
	return {
		"panel": str(hunt.panel_mode),
		"phone": bool(hunt.handheld.is_open) if hunt.handheld != null else false,
		"weapon": str(hunt.arsenal.current_id) if hunt.arsenal != null else "",
		"bare": bool(hunt.bare_handed),
		"sight": str(hunt.sight.mode) if hunt.sight != null else "",
		"mirror": bool(hunt.black_mirror_active),
		"third": bool(hunt.third_person),
		"keys": bool(hunt.keys_card.is_open),
		"prompt": str(hunt.prompt.text),
		"lock": str(hunt.get("lock_target")) if hunt.get("lock_target") != null else "",
		"photo": bool(hunt.photo_mode.active) if hunt.get("photo_mode") != null and "active" in hunt.photo_mode else false,
		"velocity_y": snappedf(hunt.player_body.velocity.y, 0.1),
		"guard": bool(hunt.guarding),
		"lungs": bool(hunt.pulmonary_held),
		"xray": bool(hunt.xray_active) or float(hunt.xray_held) > 0.2,
		"grip": str(hunt.current_grip),
		"reloading": bool(hunt.arsenal.state().get("reloading", false)) if hunt.arsenal != null else false,
		"tree": bool(hunt.blood_ledger.tree_view.visible) if hunt.blood_ledger != null and hunt.blood_ledger.tree_view != null else false,
		"k_hold": snappedf(float(hunt._k_held_for), 0.5),
		"paused": get_tree().paused,
		"events": WorldHistory.events.size() if "events" in WorldHistory else 0,
	}


func press(code: Key, shift := false, hold := false) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.pressed = true
	down.shift_pressed = shift
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	if hold:
		for _i in 90:
			await get_tree().physics_frame
	var up := InputEventKey.new()
	up.keycode = code
	up.pressed = false
	up.shift_pressed = shift
	Input.parse_input_event(up)
	Input.flush_buffered_events()


func reset() -> void:
	if get_tree().paused:
		get_tree().paused = false
		var gate := get_node_or_null("/root/PauseGate")
		if gate != null and gate.get("open"):
			gate.call("toggle")
	for _i in 3:
		if not str(hunt.panel_mode).is_empty() or hunt.keys_card.is_open or hunt.handheld.is_open:
			await press(KEY_ESCAPE)
			await get_tree().process_frame
	if hunt.handheld.is_open:
		await press(KEY_G)
	if hunt.sight != null and hunt.sight.mode == "wizard":
		hunt.sight.toggle_wizard()
	if hunt.black_mirror_active:
		await press(KEY_L)
	if hunt.third_person:
		await press(KEY_F)
	for _i in 4:
		await get_tree().physics_frame
	# Each key is judged on its own message, not one still held from before.
	hunt.sleep_prompt_hold = 0.0
	hunt.prompt.text = ""


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	for _i in 30:
		await get_tree().physics_frame
	var rows: Array = []
	for group in hunt.keys_card.groups:
		rows.append_array(group.get("rows", []))
	print("KEYS_CARD rows=%d" % rows.size())
	# [label on the card, key, shift, hold]
	var sweep := [
		["F1", KEY_F1, false, false], ["1", KEY_1, false, false], ["2", KEY_2, false, false], ["3", KEY_3, false, false],
		["4", KEY_4, false, false], ["5", KEY_5, false, false], ["6", KEY_6, false, false], ["7", KEY_7, false, false],
		["B", KEY_B, false, false], ["R", KEY_R, false, false], ["Z", KEY_Z, false, false], ["Y", KEY_Y, false, false],
		["F", KEY_F, false, false], ["SPACE", KEY_SPACE, false, false], ["E", KEY_E, false, false], ["C", KEY_C, false, false],
		["H", KEY_H, false, false], ["N", KEY_N, false, false], ["G", KEY_G, false, false], ["TAB", KEY_TAB, false, false],
		["SHIFT+TAB", KEY_TAB, true, false], ["M", KEY_M, false, false], ["T", KEY_T, false, false], ["P", KEY_P, false, false],
		["O", KEY_O, false, false], ["U", KEY_U, false, false], ["F8", KEY_F8, false, false], ["F9", KEY_F9, false, false],
		["L", KEY_L, false, false], ["K", KEY_K, false, false], ["HOLD J", KEY_J, false, true], ["HOLD I", KEY_I, false, true],
		["HOLD K", KEY_K, false, true], ["HOLD Q", KEY_Q, false, true], ["HOLD X", KEY_X, false, true], ["HOLD V", KEY_V, false, true],
		["F10", KEY_F10, false, false],
	]
	for entry in sweep:
		await reset()
		var label: String = entry[0]
		_current = label
		if label in ["1", "R", "B"]:
			# 1 from another weapon; R and B with the pistol, which reloads and changes grip.
			hunt._equip_weapon(2)
			if label == "R":
				hunt.arsenal.state()
				var ammo = hunt.arsenal.get("ammo")
				if ammo is Dictionary and ammo.has(hunt.arsenal.current_id):
					ammo[hunt.arsenal.current_id]["loaded"] = 0
			for _i in 4:
				await get_tree().physics_frame
		var before := snapshot()

		if str(label).begins_with("HOLD"):
			# Read the state while it is held.
			var code: Key = entry[1]
			var down := InputEventKey.new()
			down.keycode = code
			down.pressed = true
			Input.parse_input_event(down)
			Input.flush_buffered_events()
			for _i in 40:
				await get_tree().physics_frame
			var during := snapshot()
			var up := InputEventKey.new()
			up.keycode = code
			up.pressed = false
			Input.parse_input_event(up)
			Input.flush_buffered_events()
			await get_tree().physics_frame
			var changed := _diff(before, during)
			print("KEY %-10s -> %s" % [label, changed if not changed.is_empty() else "NOTHING"])
			if changed.is_empty():
				failures.append(label)
			continue
		await press(entry[1], entry[2], false)
		for _i in 6:
			await get_tree().physics_frame
		var after := snapshot()
		var changed := _diff(before, after)
		print("KEY %-10s -> %s" % [label, changed if not changed.is_empty() else "NOTHING"])
		if changed.is_empty():
			failures.append(label)
	print("KEYS_CARD_SWEEP silent keys: %s" % str(failures))
	print("KEYS_CARD_SWEEP_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _diff(a: Dictionary, b: Dictionary) -> String:
	var out: Array[String] = []
	for key in a:
		if key == "events":
			continue
		# The place's own hint coming back is not the key answering.
		if key == "velocity_y" and _current != "SPACE":
			continue
		if key == "prompt" and (str(b[key]).begins_with("[E]") or str(b[key]).is_empty()):
			continue
		if a[key] != b[key]:
			out.append("%s: %s -> %s" % [key, str(a[key]).left(40), str(b[key]).left(40)])
	if out.is_empty() and int(b.events) > int(a.events):
		out.append("recorded %d event(s)" % (int(b.events) - int(a.events)))
	return ", ".join(out)
