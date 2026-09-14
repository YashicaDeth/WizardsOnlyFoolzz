extends Node3D

## The shot that makes B9.2 the point rather than a footnote: the camera stands
## behind a wounded body, so the frame holds its back — and the glass in front of
## it holds its face. Neither view is available to the player in first person,
## and they are the same body at the same instant.

const HUMAN := preload("res://systems/baseline_human.gd")
const MIRROR := preload("res://systems/body_mirror.gd")

func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	get_window().size = Vector2i(1280, 720)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("0d0c0b")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("9aa0ad")
	e.ambient_light_energy = 0.55
	env.environment = e
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 150, 0)
	key.light_energy = 2.0
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-18, -20, 0)
	rim.light_energy = 1.1
	rim.light_color = Color("b9c6d8")
	add_child(rim)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("241f1c")
	ground.material_override = gm
	add_child(ground)

	var rig: BaselineHuman = HUMAN.new()
	add_child(rig)
	rig.build("in_the_glass", {"gore": true, "flesh": Color("8a7361")})
	rig.rotation.y = PI
	await get_tree().process_frame

	# Shot in the chest and the face — the two places you can never inspect on
	# yourself, which is the whole argument for the mirror existing.
	var torso := rig.parts.get("torso") as Node3D
	for i in 5:
		rig.hit_at(torso.global_position + Vector3(-0.05 + 0.03 * float(i), 0.12 - 0.04 * float(i), 0.15), 9.0, 1.2, "ballistic", Vector3(0, 0, -1))
	var head := rig.parts.get("head") as Node3D
	rig.hit_at(head.global_position + Vector3(0.03, 0.02, 0.11), 8.0, 1.0, "ballistic", Vector3(0, 0, -1))

	var mirror: BodyMirror = MIRROR.new()
	add_child(mirror)
	mirror.watch(rig)
	# Beside the body and turned toward the camera, so one frame holds the body's
	# back and the glass holding its face.
	mirror.position = Vector3(-1.02, 1.05, 0.15)
	for _s in 40:
		await get_tree().process_frame

	# Behind and above: the body's back in frame, its face in the glass.
	var cam := Camera3D.new()
	cam.position = Vector3(0.10, 1.52, 2.35)
	cam.fov = 46.0
	add_child(cam)
	cam.look_at(Vector3(-0.34, 1.05, 0.0), Vector3.UP)
	for _s in 10:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://captures/b9_mirror.png"))
	print("BODY_MIRROR_CAPTURE_RESULT saved")
	get_tree().quit(0)
