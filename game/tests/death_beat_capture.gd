extends Node
## The death beat in the Lower Works: one frame mid-fall, one with the lines up.

func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	var city: Node = load("res://buried_city.tscn").instantiate()
	add_child(city)
	for _frame in 60:
		await get_tree().process_frame
	city.rebirth_site.die("cut down by the Lower Works sentinel", "lower_works_sentinel")
	await get_tree().create_timer(0.35).timeout
	get_viewport().get_texture().get_image().save_png("P:/GameDev/Temp/lighting/death_1_falling.png")
	await get_tree().create_timer(2.3).timeout
	get_viewport().get_texture().get_image().save_png("P:/GameDev/Temp/lighting/death_2_lines.png")
	get_tree().quit()
