extends Node

## The image/mesh-to-particle-cloud technique. Headless coverage is
## necessarily structural — no headless run can look at a rendered cloud —
## but wiring, dial contracts and the follow-node framing all have to be
## right before spending a capture on the visual half.

const PORTRAIT := preload("res://systems/particle_portrait.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var portrait: GPUParticles3D = PORTRAIT.new()
	add_child(portrait)

	portrait.set_source_from_art("body", 22, 16, 20)
	check(portrait.amount == 16 * 20, "amount matches the requested grid (%d)" % portrait.amount)
	check(portrait.process_material is ShaderMaterial, "a custom particle shader drives it, not the built-in ParticlesMaterial")
	check(portrait.draw_pass_1 is QuadMesh, "particles draw as real geometry, not the default point sprite")

	portrait.set_dial("glitch", 0.6)
	check(absf(float(portrait.process_material.get_shader_parameter("glitch")) - 0.6) < 0.001, "a known dial actually reaches the shader")
	portrait.set_dial("not_a_real_dial", 9.0)
	check(portrait.process_material.get_shader_parameter("not_a_real_dial") == null, "an unknown dial is ignored rather than adopted")

	# A live source: a plain Node3D with one mesh, framed by its own AABB.
	var target := Node3D.new()
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 2.0, 0.5)
	mesh_instance.mesh = box
	target.add_child(mesh_instance)
	add_child(target)

	portrait.follow_node(target, 12, 12, Vector2i(64, 64))
	await get_tree().process_frame
	var viewport: SubViewport = portrait.get_node("PortraitSource")
	check(viewport != null, "following a node builds its own capture viewport")
	check(viewport.size == Vector2i(64, 64), "at the requested frame size")
	var camera := viewport.get_node("Camera3D") if viewport.has_node("Camera3D") else null
	if camera == null:
		for child in viewport.get_children():
			if child is Camera3D:
				camera = child
	check(camera != null, "and a camera framing whatever was handed to it")
	check(camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "orthographic, so scale reads consistently regardless of distance")
	check(portrait.amount == 12 * 12, "amount updates for the new grid")

	if failures.is_empty():
		print("particle portrait: wired correctly, ready for a capture")
		get_tree().quit(0)
	else:
		print("particle portrait FAILURES: ", failures)
		get_tree().quit(1)
