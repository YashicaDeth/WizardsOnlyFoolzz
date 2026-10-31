extends Node3D

## Every skin finish on the real held models, and the jester set on a body:
## a gallery to judge the skins by eye. `-- --out=DIR`.

const ROWS := [
	["sidearm", ["sidearm_dry_falls", "sidearm_ossuary", "facility_sidearm_wetwire", "sidearm_celloutz_fade", "sidearm_midas_nine"]],
	["shotgun", ["shotgun_scrap_primer", "shotgun_blood_rust", "shotgun_case_hardened", "sniper_carrion_tiger", "sniper_frequency_fade"]],
	["sword", ["sword_field_grey", "sword_rib_cage", "sword_abattoir_marble", "sword_slaughter", "sword_saints_tooth"]],
]


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1600, 900)
	WorldHistory.clear_history()
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("15181b")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("8a8f96")
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.6, 0)
	sun.light_energy = 1.6
	add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.5, 1.8, 2.5)
	fill.omni_range = 8.0
	fill.light_energy = 1.2
	add_child(fill)
	var camera := Camera3D.new()
	camera.position = Vector3(0.55, 0.95, 3.1)
	camera.fov = 42.0
	add_child(camera)
	camera.look_at(Vector3(0.55, 0.85, 0), Vector3.UP)
	for row_index in ROWS.size():
		var row: Array = ROWS[row_index]
		var skins: Array = row[1]
		for column in skins.size():
			var skin_id := str(skins[column])
			var target := str(WeaponSkins.SKINS[skin_id].target)
			var visual := "sidearm" if target == "facility_sidearm" else ("shotgun" if target == "sniper" else target)
			var gear := HeldGear.build_weapon(visual)
			add_child(gear)
			var item := WeaponSkins.mint(skin_id, 0.35 if column % 2 == 0 else 0.9, 137 + column * 71)
			WeaponSkins.apply_to(gear, item)
			var scale_ := 1.3 if visual == "sidearm" else (0.34 if visual == "shotgun" else 0.3)
			gear.scale = Vector3.ONE * scale_
			gear.position = Vector3(-0.75 + column * 0.46, 1.55 - row_index * 0.5, 0)
			gear.rotation = Vector3(0, PI * 0.5, PI * 0.12) if visual == "sword" else Vector3(0, PI * 0.5, 0)
	# The jester set on a body at the right, and a skinned doublet beside it.
	var rig := BaselineHuman.new()
	add_child(rig)
	rig.build("gallery_fool", BaselineHuman.config_from_subject({}))
	Outfit.dress(rig)
	rig.position = Vector3(1.85, -0.2, -0.4)
	rig.rotation.y = PI + 0.5
	rig.scale = Vector3.ONE * 0.62
	var rig2 := BaselineHuman.new()
	add_child(rig2)
	rig2.build("gallery_fool_skinned", BaselineHuman.config_from_subject({}))
	var carry := Carry.new()
	Outfit.break_lock(rig2, "sword")
	for skin_id in ["jester_doublet_fade", "jester_cap_wetwire", "jester_hose_oil_slick", "jester_sleeves_bone_blood"]:
		carry.items.append(WeaponSkins.mint(skin_id, 0.1, 400))
		SkinLoadout.apply(carry, carry.items.size() - 1)
	Outfit.dress(rig2)
	rig2.position = Vector3(2.45, -0.2, -0.6)
	rig2.rotation.y = PI - 0.3
	rig2.scale = Vector3.ONE * 0.62
	for _frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/skin_gallery.png" % out_dir
	print("CAPTURED: " if image.save_png(path) == OK else "CAPTURE_FAILED: ", path)
	get_tree().quit()
