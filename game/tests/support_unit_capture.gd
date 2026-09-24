extends Node

## Visual proof for the Support Unit: the hallway with a camera's sweeping
## cone, the alarm moment (the white depth / X-ray flash, then the brain chips
## and block tracking, then reinforcements), and a freed bingyanger.
## Run windowed: ... res://tests/support_unit_capture.tscn -- --out=DIR

const CARRY := preload("res://systems/carry.gd")

var unit
var out_dir := "P:/GameDev/Temp"


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person", "status": "loose"})
	var carry := CARRY.new()
	carry.items.append({"label": "BREACH TOOL", "kind": "tool", "mass": 4.0, "perishes": false, "age": 0.0})
	carry.save_to_history()
	unit = load("res://support_unit.tscn").instantiate()
	add_child(unit)
	unit.set_physics_process(false)
	await _hold(4)

	# 1. The hallway, calm, the first camera's cone sweeping across it.
	var lens: SecurityCamera = unit.cameras[0]
	lens.clock = 1.2
	lens.step(0.0, Vector3(0, -50, 0), unit.player)
	# From behind and beside it, so the cone reads side-on down the hall.
	_place(Vector3(5.6, 1.0, -27.0), 0.0, -0.12)
	_place(unit.player.global_position, _yaw_to(Vector3(-1.0, 0, -16.0)), -0.12)
	await _frame_hud(10)
	await _capture("support_hallway_cone")
	_place(Vector3(0.4, 1.0, -4.0), 0.0, -0.05)
	lens.clock = 3.4
	lens.step(0.0, Vector3(0, -50, 0), unit.player)
	await _frame_hud(6)
	await _capture("support_hallway_long")

	# 2. The alarm: a guard in front of you, the camera films you.
	var guard: SupportGuard = unit.guards[0]
	guard.global_position = Vector3(-0.6, 0, -35.0)
	guard.rotation.y = 0.0
	_place(Vector3(0.6, 1.0, -30.5), 0.0, -0.08)
	guard.rotation.y = PI
	await _frame_hud(4)
	unit.director.trip("camera:support_camera_1", unit.player.global_position)
	await _wait(0.2)
	await _capture("support_alarm_flash")
	# Wait out the flash itself, not a wall-clock guess: frames are slow here.
	var frames := 0
	while unit.xray_flash.active() and frames < 600:
		frames += 1
		await get_tree().process_frame
	await _wait(0.4)
	unit._update_alarm_lamps()
	unit.block_tracker.watch(unit.director.watch_entries())
	await _frame_hud(2)
	await _capture("support_alarm_chip")
	# The chip up close, from behind him.
	_place(guard.global_position + Vector3(0.25, 0.7, -1.3), PI + 0.15, -0.12)
	unit.block_tracker.watch(unit.director.watch_entries())
	await _frame_hud(3)
	await _capture("support_alarm_chip_close")
	# Reinforcements pile out of the doors.
	unit.director.send_wave()
	_place(Vector3(3.5, 1.0, -36.0), 0.75, -0.06)
	unit._update_alarm_lamps()
	unit.block_tracker.watch(unit.director.watch_entries())
	await _frame_hud(4)
	await _capture("support_reinforcements")

	# 3. A freed bingyanger in front of its broken cell.
	var cell: BingyangCell = unit.cells[0]
	var occupant: Bingyanger = cell.occupant
	for _hit in 12:
		if cell.door.broken:
			break
		cell.door.hit("axe", cell.door.global_position + Vector3(0.1, 1.2, 0.2), Vector3(-1, 0, 0))
	occupant.meet("friendly", "tell")
	occupant.global_position = cell.global_position + Vector3(1.7, 0, 0.2)
	_place(occupant.global_position + Vector3(2.0, 1.0, -1.2), 0.0, -0.1)
	occupant._face(unit.player.global_position)
	occupant.global_rotation.y = atan2(-(unit.player.global_position.x - occupant.global_position.x), -(unit.player.global_position.z - occupant.global_position.z))
	_place(unit.player.global_position, _yaw_to(occupant.global_position + Vector3(-0.4, 0, 0)), -0.12)
	occupant._speak("THE MAN AT THE LAST DOOR IS HOLLIS. THE DOOR WANTS HIS HAND, NOT HIS PERMISSION.")
	unit.director.alertness = 0.0
	await _frame_hud(6)
	await _capture("support_bingyanger")
	print("MUTATIONS: ", occupant.mutations, " attitude=", occupant.attitude)
	get_tree().quit()


func _place(at: Vector3, yaw: float, pitch: float) -> void:
	unit.player.global_position = at
	unit.yaw = yaw
	unit.pitch = pitch
	unit.player.rotation.y = yaw
	unit.camera.rotation = Vector3(pitch, 0, 0)


func _yaw_to(at: Vector3) -> float:
	var to: Vector3 = at - unit.player.global_position
	return atan2(-to.x, -to.z)


func _frame_hud(frames: int) -> void:
	for _frame in frames:
		unit._update_hud()
		await get_tree().process_frame


func _hold(frames: int) -> void:
	for _frame in frames:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [out_dir, name]
	var image := get_viewport().get_texture().get_image()
	print("CAPTURED: " if image.save_png(path) == OK else "CAPTURE_FAILED: ", path)
