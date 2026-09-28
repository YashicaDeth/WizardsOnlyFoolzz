extends Node
## The Hunt HUD with everything up at once, to find what overlaps.

func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	var timer := preload("res://systems/run_timer.gd")
	timer.start()
	FacilityRoutes.begin(FacilityRoutes.ROUTE_HEAT_ELEVATOR)
	FacilityRoutes.traverse("heat_elevator")
	var hunt: Node = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	await get_tree().create_timer(4.2).timeout
	if hunt.exit_reveal != null:
		hunt.exit_reveal.call("skip") if hunt.exit_reveal.has_method("skip") else null
	await get_tree().create_timer(3.5).timeout
	get_viewport().get_texture().get_image().save_png("P:/GameDev/Temp/lighting/hud_1_arrival.png")
	await get_tree().create_timer(9.0).timeout
	get_viewport().get_texture().get_image().save_png("P:/GameDev/Temp/lighting/hud_2_steady.png")
	get_tree().quit()
