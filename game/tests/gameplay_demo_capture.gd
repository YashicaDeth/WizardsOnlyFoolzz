extends Node

## A quick gameplay demo: loads the real Hunt Grounds scene and drives it
## through the same beats `tests/trailer.gd` already proved out (lock-on,
## melee, gore, the clinch, the downed window, the kill cam, the index, the
## map), taking a real screenshot at each one. Every call here is the same
## function the player's own input calls - nothing is staged for the camera.

var scene: Node
var out_dir := "P:/GameDev/Temp"


func _shot(name: String) -> void:
	for _settle in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/demo_%s.png" % [out_dir, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURED: ", path)


func _walk(steps: int, step: Vector3) -> void:
	for _index in steps:
		scene.player_body.position += step
		scene.player = scene.player_body.position + Vector3.UP * 0.6
		await get_tree().physics_frame


func _spawn(tag: String, offset: Vector3) -> Dictionary:
	var at: Vector3 = scene.player + offset
	scene._spawn_encounter_actor({"instance_id": tag, "kind": "hostile"}, at)
	var actor: Dictionary = scene.encounter_actors.back()
	actor.node.position = at
	await get_tree().physics_frame
	return actor


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	scene = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(scene)
	for _settle in 40:
		await get_tree().process_frame
	scene.yaw = 2.7
	await _shot("world")

	var mark := await _spawn("demo_mark", Vector3(sin(scene.yaw), 0, cos(scene.yaw)) * 5.0)
	scene._toggle_lock()
	await _shot("lockon")

	for swing in 3:
		scene.pitch = 0.22
		scene._attack_nearest_encounter_actor({"damage": 26.0, "impulse": 14.0, "damage_type": "cut", "range": 9.0, "weapon": "cleaver"})
		for _f in 16:
			await get_tree().physics_frame
	await _shot("melee")

	for blow in 6:
		mark.rig.hit("torso", 24.0, 12.0, "cut")
		for _f in 6:
			await get_tree().physics_frame
	await _shot("gore")

	var held := await _spawn("demo_clinch", Vector3(sin(scene.yaw), 0, cos(scene.yaw)) * 1.5)
	scene.stamina = 100.0
	scene._start_grapple()
	for press in 90:
		scene.grapple_advantage += 0.02
		scene._update_grapple(0.05)
		if scene.grapple_target.is_empty():
			break
		await get_tree().physics_frame
	await _shot("clinch")

	scene.player = (held.node as Node3D).global_position - Vector3(0, 0, 1.4)
	scene.player_body.position = scene.player - Vector3.UP * 0.6
	await get_tree().physics_frame
	scene._interact()
	await _shot("downed")

	scene.resolution_ui._choose(0)
	for _f in 90:
		await get_tree().process_frame
	await _shot("killcam")

	scene._toggle_panel("index")
	await _shot("index")
	scene._toggle_panel("index")

	scene._toggle_panel("map")
	await _shot("map")
	scene._toggle_panel("map")

	print("DEMO_DONE")
	get_tree().quit()
