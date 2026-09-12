extends Node3D

## A5.1 / A5.2. One sphere per material kind, under one lamp, so "flesh, scrap,
## rust and glass answer light differently" is something to look at rather than
## a claim in a commit message.
##
## Three exposures, because the difference between these materials is not
## visible in one. Daylight is where v1 to v4 were judged and where almost none
## of this shows. A single key lamp at night is the condition v4 made normal.
## And a lamp *behind* the row is the only shot that can tell meat from plaster:
## subsurface scattering, backlight and transparency all live on the far side of
## a surface, which is exactly where nothing in this project has ever been lit
## from.

const KINDS := [
	{"kind": "rust", "color": "3d1c11"},
	{"kind": "paint", "color": "24332c"},
	{"kind": "chrome", "color": "555b5e"},
	{"kind": "flesh", "color": "7a3b34"},
	{"kind": "bone", "color": "6b6048"},
	{"kind": "glass", "color": "121b1c"},
	{"kind": "dirt", "color": "24201a"},
]

var environment: Environment
var key_light: OmniLight3D
var back_light: OmniLight3D


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)

	var world_environment := WorldEnvironment.new()
	environment = WorldLook.environment("ashbloom")
	# The chart is about what a surface does with a photon, so the air between
	# the camera and the surface is turned off: the region's fog is dense enough
	# at seven metres to put a grey sheet over the whole row, which is correct
	# out in the Ashbloom and useless here.
	environment.fog_enabled = false
	environment.volumetric_fog_enabled = false
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.32, 0.34, 0.3)
	world_environment.environment = environment
	add_child(world_environment)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 0.35, 7.4)
	camera.fov = 52.0
	add_child(camera)

	# A backdrop, so transparency and the bloom's own glow have something to be
	# seen against. Dirt, because it is the least reflective kind in the set and
	# will not add a second highlight to every sphere in front of it.
	var wall := MeshInstance3D.new()
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(20, 8, 0.4)
	wall_mesh.material = WorldLook.surface(Color("1b1813"), "dirt", 3)
	wall.mesh = wall_mesh
	wall.position = Vector3(0, 1.4, -4.2)
	add_child(wall)

	var span := 1.55
	var start := -span * (float(KINDS.size()) - 1.0) * 0.5
	for index in KINDS.size():
		var entry: Dictionary = KINDS[index]
		var ball := MeshInstance3D.new()
		var ball_mesh := SphereMesh.new()
		ball_mesh.radius = 0.62
		ball_mesh.height = 1.24
		ball_mesh.radial_segments = 48
		ball_mesh.rings = 24
		ball_mesh.material = WorldLook.surface(Color(entry["color"]), entry["kind"], index * 7 + 3)
		ball.mesh = ball_mesh
		ball.position = Vector3(start + span * float(index), 0.35, 0)
		add_child(ball)
		# Printed rather than assumed: the first build of this chart photographed
		# a white row and the materials were not the reason, so the maps say out
		# loud what they bound and how dark it is.
		var probe := ball_mesh.material as StandardMaterial3D
		print("KIND=%s albedo=%s rough=%.2f glow=%.2f" % [
			entry["kind"],
			probe.albedo_texture.get_image().get_pixel(40, 40),
			probe.roughness,
			probe.emission_energy_multiplier,
		])

		var label := Label3D.new()
		label.text = String(entry["kind"]).to_upper()
		label.font_size = 48
		label.pixel_size = 0.0022
		label.position = Vector3(start + span * float(index), -0.55, 0.3)
		label.modulate = Color(0.78, 0.74, 0.66)
		label.no_depth_test = true
		add_child(label)

	key_light = OmniLight3D.new()
	# Tuned down hard from the first attempt. Authored albedo in this kit runs
	# from 0.025 to about 0.3, so a seven-energy lamp three metres off the row
	# drove every sphere to paper white and the chart said nothing at all.
	key_light.position = Vector3(-2.4, 1.9, 2.8)
	key_light.light_color = Color("ec6d2e")
	key_light.light_energy = 3.1
	key_light.omni_range = 9.0
	key_light.shadow_enabled = true
	add_child(key_light)

	# Behind and slightly below the row, close enough to push light through the
	# thin kinds rather than merely rim them.
	back_light = OmniLight3D.new()
	back_light.position = Vector3(0.4, 0.3, -1.5)
	back_light.light_color = Color("cfe6d6")
	back_light.light_energy = 2.6
	back_light.omni_range = 5.0
	# Shadows off, deliberately, and it took two runs to learn why. Godot
	# multiplies the backlight term by the light's attenuation *and* its shadow,
	# and a sphere shadows its own front from a lamp directly behind it — so
	# with shadows on, the one material that is supposed to glow through
	# photographs as a black disc while its neighbours catch bright crescents.
	# Transmittance needs the shadow map and backlight needs it gone; measured
	# on this row, backlight is the term that reads.
	back_light.shadow_enabled = false
	add_child(back_light)

	await get_tree().process_frame
	for _settle in 12:
		await get_tree().physics_frame

	await _shoot(out_dir, "chart_day", 1.0, true, false)
	await _shoot(out_dir, "chart_night", 0.0, true, false)
	await _shoot(out_dir, "chart_backlit", 0.0, false, true)
	# A5.2 on its own terms: every lamp off, so the only thing in the frame is
	# what the contamination itself emits. A tint would photograph as nothing
	# here, which is exactly what this map was up to v4.
	await _shoot(out_dir, "chart_bloom", 0.0, false, false)

	# A8.2. The melt, against the one flat backdrop this project has. In the
	# Hunt Grounds every framing puts the player in front of a lit wreck pile
	# that is soft and warm on its own, and a control frame with the shell
	# hidden proved that smear was the scenery rather than the shader. Here the
	# wall behind is a single dirt material with straight seams in it, so a
	# displacement has something to displace that anybody can see move.
	var burning := Node3D.new()
	burning.position = Vector3(0, 0.35, 0)
	add_child(burning)
	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.62
	body_mesh.height = 1.24
	body_mesh.radial_segments = 48
	body_mesh.rings = 24
	body_mesh.material = WorldLook.surface(Color("7a3b34"), "flesh", 11)
	body.mesh = body_mesh
	burning.add_child(body)
	var spirit := UndyingFlame.new()
	burning.add_child(spirit)
	spirit.ignite(burning)
	# A body with nothing left, which is when the spirit is doing the most.
	spirit.set_condition(0.0)
	for index in KINDS.size():
		get_child(4 + index * 2).visible = false
	var melt_shell := spirit.get_node_or_null("FlameMelt") as MeshInstance3D
	for exposure: Array in [["off", false], ["on", true]]:
		if melt_shell != null:
			melt_shell.visible = bool(exposure[1])
		for _tick in 4:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/flame_melt_%s.png" % [out_dir, exposure[0]])
	print("CHART_DONE")
	get_tree().quit()


func _shoot(out_dir: String, name: String, daylight: float, key: bool, back: bool) -> void:
	WorldLook.apply_hour(environment, daylight, "ashbloom")
	# A10.4. The hour sets these now, off the preset. The chart keeps its own
	# ambient *source* (a flat colour instead of the sky) because it is a chart
	# and the sky is not in it, but the level is the region's.
	environment.ambient_light_color = Color(0.32, 0.34, 0.3)
	key_light.visible = key
	back_light.visible = back
	for _tick in 4:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
