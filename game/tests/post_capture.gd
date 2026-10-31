extends Node3D

## Stills at Instagram's 4:5 (1080 x 1350), rendered at size rather than
## enlarged: the spine for a cover, the pistol skins in a column, and the gold
## cleaver. `-- --out=DIR --shot=spine|pistols|cleaver`.

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	var shot := "spine"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
		if argument.begins_with("--shot="):
			shot = argument.trim_prefix("--shot=")
	get_window().size = Vector2i(1080, 1350)
	WorldHistory.clear_history()
	match shot:
		"spine":
			_spine()
		_:
			_stage()
			if shot == "pistols":
				_pistols()
			else:
				_cleaver()
	for _frame in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/post_%s.png" % [out_dir, shot]
	print("CAPTURED: " if get_viewport().get_texture().get_image().save_png(path) == OK else "CAPTURE_FAILED: ", path)
	get_tree().quit()


func _spine() -> void:
	var back := ColorRect.new()
	back.color = Color("0e1011")
	back.size = Vector2(1080, 1350)
	add_child(back)
	var holder := Control.new()
	holder.size = Vector2(380, 480)
	holder.scale = Vector2(2.75, 2.75)
	holder.position = Vector2(-120, -60)
	back.add_child(holder)
	var rig := NerveRig.new()
	holder.add_child(rig)
	rig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rig.set_state({"health": 100.0, "blood": 1.0, "stamina": 100.0, "pain": 0.0, "consciousness": 100.0})
	rig.set_state({"health": 100.0, "stamina": 99.0})


func _stage() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("121416")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("8a9098")
	e.ambient_light_energy = 0.55
	env.environment = e
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.6, 0.5, 0)
	key.light_energy = 1.7
	add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.2, 1.0, 1.6)
	rim.omni_range = 6.0
	rim.light_energy = 1.4
	rim.light_color = Color("9fe8ff")
	add_child(rim)
	# Orthographic, so parts at different depths line up as they do on the
	# object instead of splaying apart in perspective.
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.5
	camera.position = Vector3(0, 0, 3.0)
	add_child(camera)


func _pistols() -> void:
	var skins := ["sidearm_dry_falls", "sidearm_ossuary", "facility_sidearm_wetwire", "sidearm_celloutz_fade", "sidearm_midas_nine"]
	for index in skins.size():
		var gear := HeldGear.build_weapon("sidearm")
		add_child(gear)
		WeaponSkins.apply_to(gear, WeaponSkins.mint(str(skins[index]), 0.04, 150 + index * 97))
		gear.scale = Vector3.ONE * 1.55
		gear.rotation = Vector3(0, PI * 0.5, 0)
		gear.position = Vector3(0.3, 0.6 - index * 0.29, 0)


func _cleaver() -> void:
	var gear := HeldGear.build_weapon("sword")
	add_child(gear)
	WeaponSkins.apply_to(gear, WeaponSkins.mint("sword_saints_tooth", 0.05, 333))
	gear.scale = Vector3.ONE * 1.05
	gear.rotation = Vector3(0, PI * 0.5, 0)
	# Tilted about the camera's own axis, so the flat of the blade still faces
	# the lens while it runs corner to corner.
	gear.global_rotate(Vector3.RIGHT, PI * 0.5)
	gear.global_rotate(Vector3.BACK, 0.95)
	gear.position = Vector3(-0.12, -0.28, 0)
