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
	vat.pitch = -1.3
	vat.camera.rotation.x = -1.3
	await get_tree().create_timer(1.0).timeout
	var torso: Node3D = vat.tank_body.parts.get("torso")
	print("TANK_BODY cam=%s torso=%s marks=%s phase=%s" % [vat.camera.global_position, torso.global_position if torso else null, vat.tank_body_marks, vat.phase])
	get_viewport().get_texture().get_image().save_png("P:/GameDev/Temp/lighting/tank_body_down.png")
	# The camera sat inside this torso (0.08 m above its centre), which read
	# as a mirrored "kaleidoscope" of skin texture filling the view.
	var gap: float = vat.camera.global_position.y - torso.global_position.y
	var failures := 0 if gap > 0.3 else 1
	print("TANK_BODY_RESULT failures=%d gap=%.2f" % [failures, gap])
	get_tree().quit(failures)
