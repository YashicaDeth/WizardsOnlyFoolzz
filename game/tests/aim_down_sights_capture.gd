extends Node

## ads-01 evidence. Windowed only (through AgentHub's render_one.cmd): hip,
## stage-1 sight, stage-2 sight with the MERCY NINE, then the 12G shouldered,
## with a standing target downrange so the sight picture has something on it.
##   render_one.cmd res://tests/aim_down_sights_capture.tscn -- --out=P:/GameDev/Temp/ads01

var out_dir := "P:/GameDev/Temp/ads01"
var hunt: Node


func _shot(shot_name: String) -> void:
	for _frame in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [out_dir, shot_name]
	var image := get_viewport().get_texture().get_image()
	var result := image.save_png(path) if image != null else FAILED
	print("CAPTURED " if result == OK else "CAPTURE_FAILED ", path, " fov=", hunt.camera.fov, " stage=", hunt.ads.stage)


func _frames(count: int) -> void:
	for _frame in count:
		hunt.body_motion.update(1.0 / 60.0, Vector3.ZERO, true, false, false, false)
		hunt._advance_arm(1.0 / 60.0)
		hunt._update_camera()
		hunt._update_hud()
		await get_tree().process_frame


func _rmb(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = pressed
	hunt._unhandled_input(event)


func _shift() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_SHIFT
		event.pressed = pressed
		hunt._unhandled_input(event)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	WorldClock.set_hour(13.0)
	hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	await get_tree().physics_frame
	hunt.set_physics_process(false)
	hunt.player_body.position = Vector3(0, 0.9, 19)
	hunt.player = hunt.player_body.position + Vector3.UP * 0.6
	hunt.yaw = PI
	hunt.pitch = -0.02
	var target: Dictionary = hunt._spawn_encounter_actor({
		"instance_id": "ads_target", "kind": "hostile", "display_name": "SIGHT PROBE",
	}, hunt.player + Vector3(0, -0.5, -9.0))
	(target.node as Node3D).position = hunt.player + Vector3(0, -0.5, -9.0)
	target.attack_time = 0.0

	hunt._equip_weapon(2)
	await _frames(30)
	await _shot("ads_sidearm_hip")
	_rmb(true)
	await _frames(40)
	await _shot("ads_sidearm_stage1")
	_shift()
	await _frames(40)
	await _shot("ads_sidearm_stage2")
	_rmb(false)
	await _frames(30)
	await _shot("ads_sidearm_released")

	hunt._equip_weapon(1)
	await _frames(20)
	_rmb(true)
	await _frames(40)
	await _shot("ads_shotgun_stage1")
	_rmb(false)

	# Aimed from the third-person shoulder: the camera comes in to the eye.
	hunt._equip_weapon(2)
	hunt.third_person = true
	hunt.perspective_blend = 1.0
	await _frames(30)
	await _shot("ads_third_person_hip")
	_rmb(true)
	await _frames(40)
	await _shot("ads_third_person_aimed")
	print("AIM_DOWN_SIGHTS_CAPTURE_DONE")
	get_tree().quit()
