extends Node

## The four opening rooms as pools of light, and the vat room after the glass
## bursts. HUD and overlays hidden; a free camera down each room.
## Run (not headless): ... res://tests/room_lights_capture.tscn -- --out=DIR

## Scene, camera, look-at, and the tension to hold it at.
const SHOTS := [
	["vat_calm", "res://vat_chamber.tscn", Vector3(0.0, 1.7, -1.5), Vector3(0.0, 0.6, -16.0), 0.35],
	["vat_high", "res://vat_chamber.tscn", Vector3(3.0, 3.0, 0.5), Vector3(0.0, 0.0, -9.0), 0.35],
	["arcade", "res://service_arcade.tscn", Vector3(0.0, 1.7, 4.0), Vector3(0.0, 1.2, -30.0), 0.25],
	["support", "res://support_unit.tscn", Vector3(0.0, 1.7, 8.0), Vector3(0.0, 1.2, -40.0), 0.25],
	["bay", "res://doctor_vehicle_bay.tscn", Vector3(0.0, 1.7, 11.0), Vector3(0.0, 1.0, -12.0), 0.25],
]


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	for shot: Array in SHOTS:
		var room := await _stage(str(shot[1]), shot[2], shot[3], float(shot[4]))
		await _capture("%s/%s.png" % [out_dir, shot[0]])
		if str(shot[0]) == "vat_high":
			room.call("_breach")
			_hide_overlays(room)
			room.set("phase", "aisle")
			for sweep in 3:
				await _hold(12)
				await _capture("%s/vat_burst_%d.png" % [out_dir, sweep])
		room.queue_free()
		await _hold(2)
	get_tree().quit()


func _stage(path: String, eye_at: Vector3, look_at: Vector3, tension: float) -> Node:
	WorldHistory.clear_history()
	WorldHistory.world_minute = WorldClock.OPENING_MINUTE
	var room: Node = load(path).instantiate()
	add_child(room)
	room.set_physics_process(false)
	await _hold(3)
	var intake: Variant = room.get("intake")
	if intake is Object and is_instance_valid(intake) and (intake as Object).has_method("_finish_filing"):
		intake.call("_finish_filing")
	await _hold(2)
	# Untyped, so the same capture runs on a build from before RoomLights.
	var lights: Node = room.get_node_or_null("RoomLights")
	if lights != null:
		lights.set("tension", tension)
	_hide_overlays(room)
	var eye := Camera3D.new()
	eye.fov = 70.0
	room.add_child(eye)
	eye.global_position = eye_at
	eye.look_at(look_at, Vector3.UP)
	eye.current = true
	await _hold(6)
	return room


## Every canvas layer and control (HUD, body-cam OSD, load-in, tank tint,
## fades, thoughts) and the player's body.
func _hide_overlays(room: Node) -> void:
	for layer in room.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	for control in room.find_children("*", "Control", true, false):
		(control as Control).visible = false
	var player: Variant = room.get("player")
	if player is Node3D:
		(player as Node3D).visible = false


func _hold(frames: int) -> void:
	for _frame in frames:
		await get_tree().process_frame


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	print("CAPTURED: " if get_viewport().get_texture().get_image().save_png(path) == OK else "CAPTURE_FAILED: ", path)
