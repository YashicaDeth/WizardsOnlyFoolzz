extends Node

const FieldHUD := preload("res://systems/gothic_field_hud.gd")
const Mirror := preload("res://systems/black_mirror.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var hud := FieldHUD.new()
	hud.size = Vector2(1280, 720)
	add_child(hud)
	check(hud.meter_opacity("health") < 0.25, "full idle health recedes")
	hud.set_state({
		"health": 46.0,
		"magic": 73.0,
		"stamina": 88.0,
		"portrait": {"name": "THE HUNTER", "tint": "56352f"},
		"map_context": {"label": "BONE YARD EAST", "player": Vector2(44, 31), "heading": 0.4},
		"weapon": {"id": "sword"},
	})
	check(is_equal_approx(hud.magic, 73.0), "optional magic telemetry is accepted")
	check(hud.meter_opacity("health") > 0.95, "damaged health stays prominent")
	check(hud.portrait.name == "THE HUNTER", "portrait telemetry reaches the top-right cluster")
	check(hud.map_context.label == "BONE YARD EAST", "map context telemetry reaches the top-left chart")
	# Existing callers may continue sending only the original contract.
	hud.set_state({"health": 90.0, "stamina": 50.0, "weapon": {}})
	check(is_equal_approx(hud.magic, 73.0), "legacy state updates preserve omitted magic")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var sensor := Mirror.night_vision_state({"enabled": true, "battery": 0.8})
	for frame in 60:
		sensor = Mirror.step_night_vision(sensor, {
			"enabled": true,
			"ambient_luminance": 0.008,
			"highlight_luminance": 0.8,
			"subject_distance": 8.0,
			"contrast": 0.3,
			"motion": 0.15,
		}, 1.0 / 60.0)
	check(sensor.gain > 1.0 and sensor.exposure > 1.0, "darkness raises optical exposure and electronic gain")
	check(sensor.noise > 0.0, "high gain creates sensor noise")
	check(sensor.bloom > 0.0, "bright sources bloom under night exposure")
	check(sensor.focus_distance > 3.0 and sensor.focus_distance <= 8.0, "autofocus travels toward the observed subject")
	check(sensor.battery < 0.8 and sensor.battery_draw > 0.0, "night vision reports and consumes battery load")
	var dark_source := Color(0.01, 0.008, 0.006, 1.0)
	var visible := Mirror.night_vision_sample(dark_source, sensor, Vector2(0.37, 0.62), 3.0)
	check(visible.get_luminance() > dark_source.get_luminance(), "sensor reveals detail that unaided darkness hides")
	check(visible.g > visible.r and visible.g > visible.b, "phosphor response remains camera-like and legible")

	var dead := Mirror.night_vision_state({"enabled": true, "battery": 0.0})
	dead = Mirror.step_night_vision(dead, {"enabled": true}, 0.1)
	check(not dead.enabled and is_zero_approx(dead.battery_draw), "empty battery disables the sensor cleanly")

	print("HUD_NIGHT_CAMERA_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
