extends Node

## M4.1. Does a door, a car and a person agree about how big a person is?
##
## Scale error is invisible in code review and obvious in a photograph, so this
## boots the real region, stands a real BaselineHuman next to whatever the
## generator built, and photographs them together from eye height. Anything that
## disagrees about human scale shows up immediately.

const HUNT := preload("res://bone_yard_hunt.tscn")
const RIG := preload("res://systems/baseline_human.gd")


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	var hunt: Node = HUNT.instantiate()
	add_child(hunt)
	# Let the region build and the player settle on the ground.
	for _settle in 150:
		await get_tree().process_frame

	var camera: Camera3D = hunt.get_node_or_null("CameraRig/Camera3D")
	if camera == null:
		print("CAPTURE_FAILED no camera")
		get_tree().quit(1)
		return

	# A measuring rod: a rig of known height standing on the ground in front of
	# the camera, so everything else in frame can be judged against a person.
	var marker: Node3D = RIG.new()
	hunt.add_child(marker)
	marker.build("scale_reference", {"gore": false})

	print("REPORT fov=%.1f (vertical)  eye=%.3f m above feet" % [camera.fov, camera.global_position.y])
	print("REPORT near=%.3f far=%.1f" % [camera.near, camera.far])
	# The first capture came back nearly black. Find out what is actually in the
	# scene before assuming anything about scale.
	var lights := 0
	for child in hunt.get_children():
		if child is DirectionalLight3D:
			lights += 1
			print("REPORT sun energy=%.2f visible=%s" % [(child as DirectionalLight3D).light_energy, str(child.visible)])
		if child is OmniLight3D:
			lights += 1
	print("REPORT lights=%d" % lights)
	var we: WorldEnvironment = hunt.get_node_or_null("WorldEnvironment")
	if we != null and we.environment != null:
		var env: Environment = we.environment
		print("REPORT env bg=%d ambient_energy=%.2f fog=%s fog_density=%.4f" % [env.background_mode, env.ambient_light_energy, str(env.fog_enabled), env.fog_density])
		print("REPORT tonemap=%d exposure=%.2f" % [env.tonemap_mode, env.tonemap_exposure])
	var treatment: Control = hunt.get_node_or_null("HUD/ScreenTreatment")
	if treatment != null:
		print("REPORT treatment visible=%s modulate=%s" % [str(treatment.visible), str(treatment.modulate)])
	print("REPORT interstitial alpha=%.2f" % (Interstitial.alpha if Interstitial != null else -1.0))

	var shots := {
		"scale_forward": Vector3.ZERO,
		"scale_left": Vector3(0, PI * 0.5, 0),
		"scale_back": Vector3(0, PI, 0),
	}
	for name in shots:
		hunt.set("yaw", float((shots[name] as Vector3).y))
		for _settle in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s.png" % [out_dir, name]
		if get_viewport().get_texture().get_image().save_png(path) != OK:
			print("CAPTURE_FAILED ", path)
			get_tree().quit(1)
			return
		print("CAPTURED: ", path)
	get_tree().quit()
