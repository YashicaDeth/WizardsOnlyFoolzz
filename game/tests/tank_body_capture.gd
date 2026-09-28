extends Node
## In the tank after filing: look down at your grown body and the cords.

func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	var vat: Node = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	await get_tree().process_frame
	vat.intake._finish_filing()
	await get_tree().process_frame
	vat.departure_clock = vat.DEPARTURE_SECONDS
	vat._update_departure(0.0)
	vat.clock = vat.DRAINED_AT
	vat.phase = "voiding"
	vat._update_sequence(0.05)
	for _frame in 20:
		await get_tree().process_frame
	vat.phase = "wired"
	if vat.mission_card != null:
		vat.mission_card.skip()
	for node in vat.get_node("HUD").get_children():
		if node is CanvasItem and node.name != "Objective":
			(node as CanvasItem).visible = false
	vat.pitch = -0.8
	vat.camera.rotation.x = -0.8
	await get_tree().create_timer(1.0).timeout
	print("TANK_BODY marks=%s phase=%s" % [vat.tank_body_marks, vat.phase])
	get_viewport().get_texture().get_image().save_png("P:/GameDev/Temp/lighting/tank_body_down.png")
	get_tree().quit()
