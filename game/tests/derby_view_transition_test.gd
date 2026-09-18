extends Node

## M2.7. Cab/chase changes must occupy time, move the camera through space,
## and keep both shells rendered until the eye reaches its destination.

const DERBY := preload("res://rift_derby.tscn")
const INTERIOR := preload("res://systems/vehicle_interior.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var derby = DERBY.instantiate()
	add_child(derby)
	await get_tree().process_frame
	derby.set_physics_process(false)

	var cab_at: Vector3 = derby.camera.global_position
	var authored_cab_at: Vector3 = (derby._cab_camera_target().transform as Transform3D).origin
	check(cab_at.distance_to(authored_cab_at) < 0.05, "the first rendered frame is already seated in the physical cab")
	WorldHistory.update_subject(derby.CAST.id_for(derby.CAPTAIN_SLOT), {"grudge": 40}, "test_unlock")
	derby._toggle_derby_view()
	check(not derby.in_cab and is_zero_approx(derby.view_transition), "toggle sets a chase destination without teleporting there")
	var bodywork_bit: int = 1 << (derby.BODYWORK_LAYER - 1)
	var cab_bit: int = 1 << (INTERIOR.CAB_LAYER - 1)
	check((derby.camera.cull_mask & bodywork_bit) != 0 and (derby.camera.cull_mask & cab_bit) != 0, "both shells remain visible while the camera crosses them")

	derby._update_camera(derby.VIEW_TRANSITION_SECONDS * 0.5)
	var midway: Vector3 = derby.camera.global_position
	var chase_at: Vector3 = (derby._chase_camera_target().transform as Transform3D).origin
	check(midway.distance_to(cab_at) > 0.1 and midway.distance_to(chase_at) > 0.1, "halfway is a real position between seat and chase")
	check(derby.view_transition > 0.0 and derby.view_transition < 1.0, "the transition occupies more than one frame")

	derby._update_camera(derby.VIEW_TRANSITION_SECONDS)
	check(derby.camera.global_position.distance_to(chase_at) < 0.05, "the move finishes at the live chase position")
	check((derby.camera.cull_mask & cab_bit) == 0 and (derby.camera.cull_mask & bodywork_bit) != 0, "the chase mask changes only after arrival")

	derby._toggle_derby_view()
	derby._update_camera(derby.VIEW_TRANSITION_SECONDS * 0.5)
	check(derby.camera.global_position.distance_to(chase_at) > 0.1, "the return journey also moves out of chase instead of cutting")
	derby._update_camera(derby.VIEW_TRANSITION_SECONDS)
	check(derby.camera.global_position.distance_to(cab_at) < 0.05, "the return finishes at the physical cab seat")
	check((derby.camera.cull_mask & bodywork_bit) == 0 and (derby.camera.cull_mask & cab_bit) != 0, "the cab mask changes only after the return arrives")

	derby.is_colosseum = true
	derby.round_state = "active"
	check(not derby._begin_climbing_out() and not derby.leaving_on_foot,
		"the facility cab cannot skip an active escape contract")
	check(derby.exit_refusal > 0.0, "the locked door gives immediate visible refusal")
	derby.round_state = "won"
	check(derby._begin_climbing_out() and derby.leaving_on_foot,
		"a cleared facility heat releases the same physical climb-out")

	print("DERBY_VIEW_TRANSITION_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
