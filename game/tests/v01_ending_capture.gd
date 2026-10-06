extends Node
## PNG sequence of the v0.1 ending: the gate, the white-out, the eyes
## adjusting onto the world, the title drop, TO BE CONTINUED. Windowed only
## (render_one.cmd v01_ending_capture); quits before the menu.

const OUT := "P:/GameDev/Temp/v01_ending"
const SHOTS := [[0.15, "2_white"], [1.7, "3_adjust"], [3.0, "4_title_burn"], [5.2, "5_title"], [8.6, "6_title_fade"], [11.2, "7_to_be_continued"], [16.5, "8_card_late"]]


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, label])
	print("SHOT ", label, " hour=%.2f" % (WorldHistory.world_minute / 60.0))


func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(OUT)
	WorldHistory.clear_history()
	RunTimer.start()
	RunTimer.enter("growing_floor")
	RunTimer.enter("service_arcade")
	RunTimer.enter("lower_works")
	FacilityRoutes.begin(FacilityRoutes.ROUTE_HEAT_ELEVATOR)
	var facility: Node = load("res://facility.tscn").instantiate()
	facility.set("play_ending_in_tests", true)
	get_tree().root.add_child.call_deferred(facility)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = facility
	facility.player.global_position = Vector3(28, facility.SURFACE_Y + 0.4, -131.0)
	facility.yaw = 0.0
	for _frame in 30:
		await get_tree().physics_frame
	await _snap("1_gate")
	facility.player.global_position = Vector3(28, facility.SURFACE_Y + 0.4, facility.GATE_Z - 0.6)
	while facility.ending == null:
		await get_tree().physics_frame
	var ending: Node = facility.ending
	for shot in SHOTS:
		while is_instance_valid(ending) and ending.clock < float(shot[0]):
			await get_tree().process_frame
		if not is_instance_valid(ending):
			break
		await _snap(str(shot[1]))
	get_tree().quit()
