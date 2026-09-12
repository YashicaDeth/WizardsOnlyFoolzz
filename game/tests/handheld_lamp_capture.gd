extends Node

## AS1.1. The torch, seen: dark with the device pocketed, lit with it raised,
## dimmer and guttering as the battery runs down toward nothing.

func _shot(out_dir: String, name: String) -> void:
	for _settle in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [out_dir, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURED: ", path)


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().process_frame
	for _settle in 20:
		await get_tree().process_frame

	# A wall close in front to actually catch the light rather than losing it
	# into open sky.
	var wall := MeshInstance3D.new()
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(6, 4, 0.3)
	wall.mesh = wall_mesh
	wall.material_override = StandardMaterial3D.new()
	wall.material_override.albedo_color = Color("2a2620")
	wall.position = hunt.player + Vector3(0, 0, -4.0)
	hunt.add_child(wall)

	hunt.yaw = 0.0
	hunt.pitch = 0.0
	await _shot(out_dir, "torch_off")

	# Raising the device to actually read it takes the whole screen (AS1.2 -
	# that hand is busy), which is real and intentional; hiding the panel's
	# own draw here isolates the thing this shot is actually checking - the
	# 3D light in the world - the same way `torch_off`/`_on`/`_low` are about
	# the light, not the UI over it.
	hunt.handheld.open_device()
	hunt.handheld.visible = false
	hunt.handheld.battery = 1.0
	hunt._update_handheld_light(0.016)
	await _shot(out_dir, "torch_on_full")

	hunt.handheld.battery = 0.12
	hunt._update_handheld_light(0.016)
	await _shot(out_dir, "torch_low")

	get_tree().quit()
