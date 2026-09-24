extends Node

var hunt: Node


func _wait(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame


func _shot(file_name: String) -> void:
	await _wait(6)
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://captures/%s" % file_name)
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURED ", path)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	await _wait(55)
	hunt.player = Vector3(58.0, 1.0, 58.0)
	(hunt.player_body as CharacterBody3D).position = hunt.player
	var at: Vector3 = hunt.player + Vector3(0.0, -0.5, 1.55)
	hunt._spawn_encounter_actor({
		"instance_id": "capture_searched_body", "kind": "hostile",
		"display_name": "Toll Runner", "loot": ["field dressing", "rust scrip"],
	}, at)
	var actor: Dictionary = hunt.encounter_actors.back()
	(actor.node as Node3D).position = at
	hunt._kill_encounter_actor(hunt.encounter_actors.size() - 1, "capture")
	hunt._put_the_weapons_down()
	var inspect := InputEventKey.new()
	inspect.keycode = KEY_I
	inspect.pressed = true
	hunt._unhandled_input(inspect)
	await _wait(20)
	hunt._update_held_reliquary()
	await _shot("corpse_whole_body_inspection.png")
	inspect.pressed = false
	hunt._unhandled_input(inspect)
	hunt._interact()
	await _shot("corpse_one_action_loot.png")
	get_tree().quit()
