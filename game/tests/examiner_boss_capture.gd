extends Node

## Job 6 visual proof: the examiner's telegraphs (scalpel glint, syringe
## glint, desperate phase), his keycard on his office floor, the staff door
## shut with its red reader, then open onto the artery with his cupboard.
## Run windowed: render_one.cmd examiner_boss_capture --out=DIR

var out_dir := "P:/GameDev/Temp"
var vat_ref: Node


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	var vat = load("res://vat_chamber.tscn").instantiate()
	vat_ref = vat
	add_child(vat)
	await get_tree().process_frame
	vat.intake._finish_filing()
	await get_tree().process_frame
	vat.departure_clock = vat.DEPARTURE_SECONDS
	vat._update_departure(0.0)
	vat.clock = vat.DRAINED_AT
	vat.phase = "voiding"
	vat._update_sequence(0.05)
	while not vat.umbilicals.is_empty():
		for _tug in vat.WIRE_TUGS:
			vat._tug_wire(vat.umbilicals[0])
	vat._physics_process(vat.REVENGE_HOLD + 0.1)
	preload("res://systems/clothing.gd").wear("player", "scavenged_coat")
	for _step in 80:
		if vat.can_move:
			break
		vat._physics_process(0.1)
	var route = vat.doctor_route
	var fight: ExaminerFight = route.fight
	route._take_axe()
	while not route.door.broken:
		route.door.hit("axe", route.DOOR_AT + Vector3(0, 1.2, 0), Vector3(0, 0, 1))
	# The player's own view, in his room, a step from him.
	var him: Vector3 = fight.global_position
	_stand(vat, him + Vector3(1.6, 0, -0.6), him + Vector3(0, 1.3, 0))
	fight._notice()
	fight.state = "fighting"
	for _frame in 30:
		_stand(vat, him + Vector3(1.6, 0, -0.6), fight.global_position + Vector3(0, 1.3, 0))
		await get_tree().process_frame

	# A scalpel wind-up, two thirds through: the bone-white glint.
	await _hold_windup(vat, fight, "scalpel", 0.66)
	await _capture("examiner_boss_1_scalpel_telegraph")
	await _hold_windup(vat, fight, "syringe", 0.7)
	await _capture("examiner_boss_2_syringe_telegraph")
	# Desperate: his bar says so, quicker cuts.
	fight.health = ExaminerFight.HEALTH * 0.4
	fight._desperate()
	fight._update_bar()
	await _hold_windup(vat, fight, "follow", 0.6)
	await _capture("examiner_boss_3_desperate")

	# Down. His card on the floor, the player looking at it from a few steps.
	fight._cancel_windup()
	fight.health = 0.0
	fight._win()
	for _frame in 90:
		await get_tree().process_frame
	var card: Vector3 = fight.keycard_pickup.global_position
	_stand(vat, card + Vector3(1.2, 0, 1.4), card)
	vat.pitch = -0.55
	for _frame in 20:
		vat.camera.rotation.x = 0.0
		await get_tree().process_frame
	await _capture("examiner_boss_4_keycard_on_floor")

	# The staff door, shut, before the card is taken.
	_stand(vat, vat.STAFF_DOOR_AT + Vector3(-2.6, 0, -0.5), vat.STAFF_DOOR_AT + Vector3(0.6, 1.3, -0.5))
	for _frame in 20:
		await get_tree().process_frame
	await _capture("examiner_boss_5_staff_door_shut")
	fight.keycard_pickup.global_position = vat.player.global_position
	fight.take_keycard()
	_stand(vat, vat.STAFF_DOOR_AT + Vector3(-1.2, 0, -0.5), vat.STAFF_DOOR_AT)
	vat._interact()
	for _frame in 75:
		_stand(vat, vat.STAFF_DOOR_AT + Vector3(-2.6, 0, -0.5), vat.STAFF_DOOR_AT + Vector3(2.0, 1.3, -0.5))
		await get_tree().process_frame
	await _capture("examiner_boss_6_staff_door_open")
	var cupboard: Vector3 = vat._staff_cupboard_at()
	_stand(vat, cupboard + Vector3(0.3, 0, -2.1), cupboard + Vector3(0, 1.1, 0))
	for _frame in 20:
		await get_tree().process_frame
	await _capture("examiner_boss_7_cupboard")
	get_tree().quit()


func _stand(vat, at: Vector3, look_at_point: Vector3) -> void:
	vat.player.global_position = Vector3(at.x, vat.BODY_HALF_HEIGHT + 0.02, at.z)
	vat.player.velocity = Vector3.ZERO
	var to := look_at_point - (at + Vector3(0, 1.6, 0))
	vat.yaw = atan2(-to.x, -to.z)
	vat.pitch = atan2(to.y, Vector2(to.x, to.z).length())


## Starts a wind-up and lets it run to `amount` of its length, then freezes it.
func _hold_windup(vat, fight: ExaminerFight, kind: String, amount: float) -> void:
	fight._cancel_windup()
	fight.stagger_left = 0.0
	fight.parried_left = 0.0
	fight.winding = kind
	fight.windup = 0.0
	fight.telegraphs += 1
	fight._set_glint(ExaminerFight.GLINT_SYRINGE if kind == "syringe" else ExaminerFight.GLINT_SCALPEL)
	if fight.body.rigged != null:
		var clip := "spell_cast" if kind == "syringe" else "sword_attack"
		var length: float = fight.body.rigged.player.get_animation(str(RiggedBody.CLIPS[clip])).length
		fight.body.rigged.play_action(clip, length / fight._windup_for(kind))
	var frames := int(fight._windup_for(kind) * amount * 60.0)
	fight.set_physics_process(false)
	for _frame in frames:
		fight.windup += 1.0 / 60.0
		fight._glow(clampf(fight.windup / fight._windup_for(kind), 0.0, 1.0))
		await get_tree().process_frame
	if fight.body.rigged != null:
		fight.body.rigged.player.speed_scale = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	if fight.body.rigged != null:
		fight.body.rigged.player.speed_scale = 1.0
	fight.set_physics_process(true)


func _capture(shot: String) -> void:
	_quiet()
	await get_tree().process_frame
	_quiet()
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [out_dir, shot]
	print("CAPTURED: " if get_viewport().get_texture().get_image().save_png(path) == OK else "CAPTURE_FAILED: ", path)


## The GET REVENGE card and the one-time key teaching sit over the middle of
## the screen; these shots are of him.
func _quiet() -> void:
	for overlay in [vat_ref.get("title"), vat_ref.get("mission_card"), vat_ref.get("key_hints")]:
		if overlay is Object and is_instance_valid(overlay) and overlay.get("visible") != null:
			overlay.set("visible", false)
