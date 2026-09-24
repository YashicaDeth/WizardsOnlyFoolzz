extends Node

## Production first-person checkpoints for the smoking-feel pass. These drive
## the live Hunt update loop and input verbs rather than posing a model viewer.

var out_dir := "P:/GameDev/Temp"
var hunt: Node


func _wait_frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _wait_frames(6)
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [out_dir, name]
	var result := get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURED " if result == OK else "CAPTURE_FAILED ", path)


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
	await _wait_frames(50)
	hunt.third_person = false
	hunt.perspective_blend = 0.0
	hunt.body_motion.set_perspective(true)
	hunt._equip_smokeable("cigarette")
	await _wait_frames(25)
	await _shot("smoking_feel_cigarette_rest")

	hunt._begin_smoking_draw()
	await _wait_frames(54)
	await _shot("smoking_feel_cigarette_draw")
	hunt._finish_smoking_draw()
	await _wait_frames(16)
	await _shot("smoking_feel_cigarette_exhale")

	hunt._toggle_mouth_hold()
	await _wait_frames(32)
	await _shot("smoking_feel_cigarette_lip_hold")
	hunt._equip_weapon(2)
	await _wait_frames(18)
	await _shot("smoking_feel_cigarette_armed")
	hunt._put_the_weapons_down()
	await _wait_frames(8)
	hunt._toggle_mouth_hold()
	await _wait_frames(28)
	hunt.inspect_held = true
	await _wait_frames(30)
	await _shot("smoking_feel_cigarette_inspect")
	hunt.inspect_held = false
	get_tree().quit()
