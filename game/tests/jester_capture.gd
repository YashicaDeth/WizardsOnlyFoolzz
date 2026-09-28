extends Node3D

## The jester set up close: forced on with the collar locked; lock broken
## with the cap and sleeves off; and the set in case skins. `-- --out=DIR`.

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1400, 900)
	WorldHistory.clear_history()
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("1a1c1f")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("9098a0")
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.4, 0)
	sun.light_energy = 1.5
	add_child(sun)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.05, -3.3)
	camera.fov = 38.0
	add_child(camera)
	camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	var carry := Carry.new()
	var locked := _rig("locked", Vector3(1.0, 0, 0))
	Outfit.dress(locked)
	var loose := _rig("loose", Vector3(0, 0, 0))
	Outfit.dress(loose)
	Outfit.break_lock(loose, "sword")
	Outfit.take_off(loose, carry, "jester_cap")
	Outfit.take_off(loose, carry, "jester_sleeves")
	# Put the parts back on for the skinned body, then skin every part.
	Outfit.put_on(loose, carry, 0)
	Outfit.put_on(loose, carry, 0)
	var skinned := _rig("skinned", Vector3(-1.0, 0, 0))
	for skin_id in ["jester_cap_wetwire", "jester_doublet_wine", "jester_sleeves_bone_blood", "jester_hose_oil_slick"]:
		carry.items.append(WeaponSkins.mint(skin_id, 0.1, 400))
		SkinLoadout.apply(carry, carry.items.size() - 1)
	Outfit.dress(skinned)
	# The middle body shows the lock broken and the cap and sleeves off.
	WorldHistory.update_subject(Outfit.SUBJECT, {"parts": {"jester_doublet": 1.0, "jester_hose": 1.0}, "locked": false})
	var saved := SkinLoadout.all_applied()
	WorldHistory.update_subject(SkinLoadout.SUBJECT, {"applied": {}})
	Outfit.dress(loose)
	WorldHistory.update_subject(SkinLoadout.SUBJECT, {"applied": saved})
	for _frame in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/jester_parts.png" % out_dir
	print("CAPTURED: " if get_viewport().get_texture().get_image().save_png(path) == OK else "CAPTURE_FAILED: ", path)
	get_tree().quit()


func _rig(label: String, at: Vector3) -> BaselineHuman:
	var rig := BaselineHuman.new()
	add_child(rig)
	rig.build("jester_" + label, BaselineHuman.config_from_subject({}))
	rig.position = at
	return rig
