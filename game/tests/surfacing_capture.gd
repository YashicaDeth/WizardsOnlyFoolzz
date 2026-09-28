extends Node
## Up the heat elevator into the Hunt: white-out, the title, the keys.

func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	FacilityRoutes.begin(FacilityRoutes.ROUTE_HEAT_ELEVATOR)
	FacilityRoutes.traverse("heat_elevator")
	var hunt: Node = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	var shots := [[0.5, "surface_1_white"], [1.9, "surface_2_title"], [4.6, "surface_3_keys"]]
	var at := 0.0
	for shot in shots:
		await get_tree().create_timer(float(shot[0]) - at).timeout
		at = float(shot[0])
		get_viewport().get_texture().get_image().save_png("P:/GameDev/Temp/lighting/%s.png" % shot[1])
	print("HOUR ", WorldHistory.world_minute / 60.0)
	get_tree().quit()
