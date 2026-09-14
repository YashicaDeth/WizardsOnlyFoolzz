extends Node3D

## Three bodies, three rounds, same places on each — so the difference on screen
## is the calibre and nothing else. Greg's sentence, rendered.

const HUMAN := preload("res://systems/baseline_human.gd")

func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	get_window().size = Vector2i(1280, 720)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("0e0d0c")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("9aa2ae")
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-28, 46, 0)
	key.light_energy = 2.0
	add_child(key)

	# buckshot 0.12, pistol 0.25, rifle 0.75
	var rounds := [
		{"pen": 0.12, "damage": 6.0},
		{"pen": 0.25, "damage": 7.0},
		{"pen": 0.75, "damage": 8.0},
	]
	for index in rounds.size():
		var rig: BaselineHuman = HUMAN.new()
		add_child(rig)
		rig.build("pen_%d" % index, {"gore": true, "flesh": Color("8a7361")})
		rig.position = Vector3(-0.95 + 0.95 * float(index), 0, 0)
		await get_tree().process_frame
		var pen: float = rounds[index]["pen"]
		var dmg: float = rounds[index]["damage"]
		# Down the arm, thin end to thick end — the exact comparison he described.
		var arm := rig.parts.get("left_arm") as Node3D
		for step in 5:
			var t := -0.85 + 0.42 * float(step)
			var at := arm.to_global(Vector3(0, t * 0.31, 0.07))
			rig.hit_at(at, dmg, 2.0, "ballistic", Vector3(0, 0, -1), pen)
		# And a burst across the chest.
		var torso := rig.parts.get("torso") as Node3D
		for step in 4:
			var at := torso.to_global(Vector3(-0.05 + 0.035 * float(step), 0.10 - 0.05 * float(step), 0.12))
			rig.hit_at(at, dmg, 2.0, "ballistic", Vector3(0, 0, -1), pen)

	await get_tree().process_frame
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.30, 1.85)
	cam.fov = 40.0
	add_child(cam)
	cam.look_at(Vector3(0, 1.14, 0), Vector3.UP)
	for _s in 8:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://captures/b10_penetration.png"))
	print("PENETRATION_CAPTURE_RESULT saved")
	get_tree().quit(0)
