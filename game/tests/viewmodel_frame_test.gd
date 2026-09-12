extends Node

## M4.4 regression guard. The weapon models in `hunter_arsenal.gd` were built
## and positioned before M4.1-M4.3 corrected the FOV and eye height they are
## seen through, and the old placement sat entirely outside the frustum at the
## corrected numbers — invisible, and nothing ever asserted it was in frame.
## This measures where each weapon actually lands on screen so that cannot
## regress silently again.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.third_person = false
	for _settle in 90:
		await get_tree().physics_frame

	var cam: Camera3D = hunt.camera
	var viewport_size: Vector2 = get_viewport().size

	for entry in [{"slot": 0, "id": "sword"}, {"slot": 1, "id": "shotgun"}, {"slot": 2, "id": "sidearm"}]:
		hunt._equip_weapon(entry.slot)
		for _frame in 10:
			await get_tree().physics_frame
		var model: Node3D = hunt.arsenal.models[entry.id]
		check(model.visible, "%s model is the one shown when equipped" % entry.id)
		var in_front: bool = not cam.is_position_behind(model.global_position)
		check(in_front, "%s sits in front of the camera, not behind it" % entry.id)
		var screen_pos: Vector2 = cam.unproject_position(model.global_position)
		var margin := 0.35
		var inside: bool = (
			screen_pos.x > -viewport_size.x * margin and screen_pos.x < viewport_size.x * (1.0 + margin)
			and screen_pos.y > -viewport_size.y * margin and screen_pos.y < viewport_size.y * (1.0 + margin)
		)
		check(inside, "%s falls inside the frame at the corrected FOV/eye height (%s in a %s viewport)" % [entry.id, screen_pos, viewport_size])
		var distance: float = cam.global_position.distance_to(model.global_position)
		check(distance > 0.3 and distance < 1.6, "%s sits at a plausible held distance (%.2fm)" % [entry.id, distance])

	print("VIEWMODEL_FRAME_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
