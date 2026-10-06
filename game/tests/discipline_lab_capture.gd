extends Node

## Visual proof harness. It must be launched only through AgentHub's
## render_one.cmd; headless runs validate the harness and explicitly render
## nothing.

var lab: Node3D
var eye: Camera3D
var shots := "P:/GameDev/Temp/lab-52-duelist-shade"


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("DISCIPLINE_LAB_CAPTURE headless, nothing rendered")
		get_tree().quit(0)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shots="):
			shots = argument.trim_prefix("--shots=")
	DirAccess.make_dir_recursive_absolute(shots)
	lab = load("res://lab/mechanics_lab.tscn").instantiate()
	add_child(lab)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Photograph the actual player camera. An external proof camera sees the
	# first-person arms from the side and makes them look disconnected.
	eye = lab.camera
	await get_tree().create_timer(0.6).timeout
	eye.current = true

	lab.disciplines.activate("duelist")
	lab.player.global_position = lab.sparring.holder.global_position + Vector3(0, 1.0, 2.4)
	lab.player.velocity = Vector3.ZERO
	lab.yaw = 0.0
	lab.toggle_lock()
	lab.sparring._enter("windup")
	lab.disciplines.open_riposte(lab.sparring.rig)
	lab.melee.press_parry()
	await get_tree().create_timer(0.06).timeout
	await _shot("duelist")

	lab.disciplines.activate("shade")
	lab.player.global_position = lab.disciplines.to_global(Vector3(0, 1.0, -0.35))
	lab.player.velocity = Vector3.ZERO
	lab.lock_target = null
	lab.yaw = 0.0
	lab.pitch = -0.05
	lab.mover.crouched = true
	lab.disciplines.toggle_darkness()
	await get_tree().create_timer(0.24).timeout
	await _shot("shade_darkness")
	print("DISCIPLINE_LAB_CAPTURE wrote %s" % shots)
	get_tree().quit(0)


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := shots.path_join(label + ".png")
	image.save_png(path)
	print("SHOT ", path)
