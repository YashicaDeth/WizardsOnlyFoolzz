extends Node
## The heat elevator's doors, fuse in, from six metres out.

func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	var city: Node = load("res://buried_city.tscn").instantiate()
	add_child(city)
	for _frame in 30:
		await get_tree().process_frame
	city.player.global_position = city.LIFT_AT + Vector3(0, 1.0, 11.0)
	get_viewport().get_texture().get_image().save_png("P:/GameDev/Temp/lighting/lift_1_shut.png")
	city.fuse_taken = true
	city.lift_lamp.light_color = Color("5fbf6a")
	city.player.global_position = city.LIFT_AT + Vector3(0, 1.0, 6.5)
	await get_tree().create_timer(1.6).timeout
	get_viewport().get_texture().get_image().save_png("P:/GameDev/Temp/lighting/lift_2_open.png")
	get_tree().quit()
