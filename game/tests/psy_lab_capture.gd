extends Node

## The whole of Path C, photographed: a UDP packet goes in one end and the
## screen is different at the other. Headless cannot render, so a passing OSC
## test proves the number arrived and proves nothing about whether the shader
## did anything with it. This stands the lab up for real, sends it the packets
## TouchDesigner would send, and takes the picture.

const LAB := preload("res://psy_lab.tscn")

var lab


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	var tree := get_tree()
	tree.create_timer(120.0, true, false, true).timeout.connect(func() -> void: tree.quit(3))
	await tree.process_frame

	lab = LAB.instantiate()
	tree.root.add_child(lab)
	tree.current_scene = lab
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await tree.physics_frame
	await tree.physics_frame

	if not lab.bridge.listening:
		print("FAILED: the lab did not open its port — is another copy running?")
		tree.quit(1)
		return

	# Stand somewhere with bodies in shot, and wreck one, so the effect has
	# something with edges to work on rather than an empty floor.
	lab.demo.eye = Vector3(0.0, 1.68, 7.0)
	lab.demo.yaw = 0.0
	lab.demo.pitch = -0.06
	await _settle(tree, 6)
	var centre: Vector3 = (lab.demo.bodies[0] as Dictionary)["rig"].global_position
	lab.demo._explode(centre + Vector3(0, 1.0, 0), 92.0)
	await _settle(tree, 30)
	await _shoot(tree, out_dir + "/psy_lab_neutral.png")

	# Now be TouchDesigner.
	var td := PacketPeerUDP.new()
	td.set_dest_address("127.0.0.1", lab.port)
	var sent := {
		"/psy/kaleidoscope_segments": 6.0,
		"/psy/kaleidoscope_spin": 0.35,
		"/psy/chromatic_offset": 0.018,
	}
	for address: String in sent:
		td.put_packet(OSCBridge.encode(address, [float(sent[address])]))
	await _settle(tree, 14)
	print("kaleidoscope now %.2f" % lab.rig.dial("kaleidoscope_segments"))
	await _shoot(tree, out_dir + "/psy_lab_kaleidoscope.png")

	# Feedback is the one that needs frames to build, because it is the only
	# dial whose input is its own previous output.
	td.put_packet(OSCBridge.encode("/psy/kaleidoscope_segments", [0.0]))
	td.put_packet(OSCBridge.encode("/psy/feedback_strength", [0.72]))
	td.put_packet(OSCBridge.encode("/psy/feedback_zoom", [1.03]))
	td.put_packet(OSCBridge.encode("/psy/feedback_spin", [0.06]))
	await _settle(tree, 10)
	for _step in 40:
		await tree.process_frame
	await _shoot(tree, out_dir + "/psy_lab_feedback.png")

	# And everything at once, which is what the drugs and the shadow realms are
	# going to be: one shader, different dials.
	td.put_packet(OSCBridge.encode("/psy/kaleidoscope_segments", [8.0]))
	td.put_packet(OSCBridge.encode("/psy/displacement_strength", [0.09]))
	td.put_packet(OSCBridge.encode("/psy/lut_strength", [0.65]))
	td.put_packet(OSCBridge.encode("/psy/cut_intensity", [0.3]))
	await _settle(tree, 20)
	await _shoot(tree, out_dir + "/psy_lab_everything.png")

	print("packets received: %d" % lab.packets)
	tree.quit(0)


func _settle(tree: SceneTree, frames: int) -> void:
	for _frame in frames:
		await tree.physics_frame


func _shoot(tree: SceneTree, path: String) -> void:
	for _frame in 3:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("CAPTURED: " if image.save_png(path) == OK else "FAILED: ", path)
