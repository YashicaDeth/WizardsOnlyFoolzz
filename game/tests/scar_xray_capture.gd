extends Node

## Brief 2, `scar-ledger`, proof frame. Shoot the same forearm twice, once
## shallow and once deep enough to reach the bone, then read the X-ray: two marks
## where the rounds went in, each naming its own exchange.
##
## Render: P:/GameDev/AgentHub/render_one.cmd scar_xray_capture

var failures: Array[String] = []


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp/scar_ledger"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	# A dim room; the X-ray is the instrument, not the lamp.
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.03, 0.028, 0.026)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5, 0.48, 0.44)
	environment.ambient_light_energy = 0.55
	world.environment = environment
	add_child(world)
	var lamp := OmniLight3D.new()
	lamp.light_energy = 2.2
	lamp.light_color = Color(0.86, 0.9, 0.82)
	lamp.omni_range = 6.0
	lamp.global_position = Vector3(1.4, 2.4, 1.6)
	add_child(lamp)

	WorldHistory.world_minute = 13.0 * 60.0 + 20.0
	var body := BaselineHuman.new()
	add_child(body)
	body.build("scar_subject", {})
	var arm := body.parts.get("left_arm") as Node3D
	var point := arm.global_position + Vector3(0.0, 0.1, 0.0)

	# One shallow round into the forearm, then one that crosses it.
	body.hit_at(point + Vector3(0.02, -0.04, 0.0), 9.0, 5.0, "ballistic", Vector3.RIGHT, 0.24)
	WorldHistory.world_minute += 47.0
	body.hit_at(point + Vector3(-0.01, 0.05, 0.0), 11.0, 6.0, "ballistic", Vector3.RIGHT, 1.0)
	WorldHistory.world_minute += 12.0
	# And a blade on the other arm, so the frame shows a cause that is not a round.
	var other := body.parts.get("right_arm") as Node3D
	body.hit_at(other.global_position + Vector3(0.0, 0.16, 0.0), 10.0, 6.0, "cut", Vector3.LEFT)
	print("SCARS ", JSON.stringify(ScarLedger.to_records(body.scars)))
	if body.scars.size() < 3:
		failures.append("three landed blows left %d scars" % body.scars.size())

	var camera := Camera3D.new()
	add_child(camera)
	var chest := (body.parts.get("torso") as Node3D).global_position
	camera.global_position = chest + Vector3(0.0, 0.12, -1.9)
	camera.look_at(chest, Vector3.UP)
	camera.current = true
	camera.fov = 42.0
	body.reveal_organs(true)
	body.see_through(true)

	var overlay := XrayScanOverlay.new()
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.show_scan(body, camera)

	for frame in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/scar_xray.png" % out_dir
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURED ", path, " error=", error)
	get_tree().quit(0 if error == OK and failures.is_empty() else 1)
