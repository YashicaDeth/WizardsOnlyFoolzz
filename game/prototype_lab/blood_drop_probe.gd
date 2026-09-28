extends Node3D

## Probe: is the airborne gore reading as pale pink because blood drops are
## built with the "flesh" material?
##
## `WorldLook.surface(BLOOD, "flesh", ...)` gives a blood drop the same material
## a torso gets: subsurface scattering at 0.6 with a light red transmittance,
## plus rim 0.5. That is right for a limb and wrong for a 3 cm sphere, where
## the whole bead is effectively translucent and renders as its transmittance
## colour rather than `BLOOD` (6b0f0c).
##
## This is a probe, not a fix. It stages the same sphere three ways under the
## same light and photographs them, so the cause is looked at rather than
## inferred. --row=flesh|paint|blood to shoot one at a time.

const LOOK := preload("res://systems/world_look.gd")
const BLOOD := Color("6b0f0c")

var shot_path := "P:/GameDev/Temp/blood_drop_probe.png"
var which := "all"


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shot="):
			shot_path = argument.trim_prefix("--shot=")
		if argument.begins_with("--row="):
			which = argument.trim_prefix("--row=")

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("141210")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6a5a4a")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	# One key light, matching the sandbox's warm interior, so the only variable
	# between the three spheres is the material.
	var key := DirectionalLight3D.new()
	key.light_color = Color("ffd9a8")
	key.light_energy = 2.2
	key.rotation_degrees = Vector3(-38.0, 28.0, 0.0)
	add_child(key)

	var kinds := ["flesh", "paint", "blood"]
	if which != "all":
		kinds = [which]
	for index in kinds.size():
		_sphere(kinds[index], -1.1 + float(index) * 1.1)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.16, 1.5)
	cam.fov = 45.0
	add_child(cam)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	cam.current = true

	for _frame in 8:
		await get_tree().process_frame

	# Labels are placed by projecting the sphere, not by guessing screen
	# coordinates. The first pass hard-coded an x-scale and put every label in
	# the wrong place, which made the frame read as a lie: "paint" and "blood"
	# are both correct dark red, and a viewer handed that would conclude the
	# fix did nothing.
	var layer := CanvasLayer.new()
	add_child(layer)
	for index in kinds.size():
		var at := Vector3(-1.1 + float(index) * 1.1, -0.16, 0.0)
		var screen := cam.unproject_position(at)
		var tag := Label.new()
		tag.text = kinds[index]
		tag.position = screen - Vector2(30.0, 0.0)
		tag.size = Vector2(60, 24)
		tag.add_theme_color_override("font_color", Color("cfd8d0"))
		tag.add_theme_font_size_override("font_size", 14)
		layer.add_child(tag)

	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(shot_path)
	print("BLOOD_DROP_PROBE kinds=%s -> %s" % [",".join(kinds), "ok" if error == OK else "FAILED"])
	get_tree().quit(0 if error == OK else 1)


func _sphere(kind: String, at_x: float) -> void:
	var mesh := SphereMesh.new()
	# The same size a blood drop actually is: 0.026-0.072 radius in the rig.
	mesh.radius = 0.05
	mesh.height = 0.1
	if kind == "blood":
		# The candidate: opaque, no subsurface, no rim.
		mesh.material = LOOK.surface(BLOOD, "paint", 3)
	else:
		mesh.material = LOOK.surface(BLOOD, kind, 3)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = Vector3(at_x, 0.0, 0.0)
	add_child(node)
