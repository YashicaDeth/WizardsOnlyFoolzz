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
	eye = Camera3D.new()
	eye.fov = 68.0
	add_child(eye)
	await get_tree().create_timer(0.6).timeout
	eye.current = true

	lab.disciplines.activate("duelist")
	lab.disciplines.open_riposte(lab.sparring.rig)
	await _shot("duelist", lab.sparring.holder.global_position + Vector3(4.8, 2.2, 4.8), lab.sparring.rig.global_position + Vector3.UP)

	lab.disciplines.activate("shade")
	lab.disciplines.toggle_darkness()
	await _shot("shade_darkness", lab.disciplines.to_global(Vector3(4.8, 2.0, 2.0)), lab.disciplines.target.global_position + Vector3.UP)
	print("DISCIPLINE_LAB_CAPTURE wrote %s" % shots)
	get_tree().quit(0)


func _shot(label: String, from: Vector3, at: Vector3) -> void:
	eye.global_position = from
	eye.look_at(at)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := shots.path_join(label + ".png")
	image.save_png(path)
	print("SHOT ", path)
