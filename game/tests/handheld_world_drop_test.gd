extends Node

## C1.7 live seam: dropping the HUD object creates the same serial as a
## colliding world body, E repossesses it, and an unresolved drop survives a
## Hunt reload at its last recorded position.

const HUNT := preload("res://bone_yard_hunt.tscn")

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

	var hunt = HUNT.instantiate()
	add_child(hunt)
	await get_tree().process_frame
	var serial: int = hunt.handheld.serial
	var charge: float = hunt.handheld.battery
	var before_drop: float = hunt.handheld.condition

	var result: Dictionary = hunt.handheld.drop()
	await get_tree().physics_frame
	check(bool(result.get("ok", false)), "the live Hunt accepts the deliberate drop")
	check(hunt.dropped_handheld is RigidBody3D, "the drop becomes a real physics body in world space")
	check(hunt.dropped_handheld.get_node_or_null("Case") is MeshInstance3D, "the world body has a rendered case")
	check(hunt.dropped_handheld.get_node_or_null("MirrorGlass") is MeshInstance3D, "and recognisable live mirror glass")
	check(int(hunt.dropped_handheld.payload.get("serial", -1)) == serial, "the world object carries the exact device serial")
	check(float(hunt.dropped_handheld.payload.get("condition", 0.0)) < before_drop, "its payload includes the wear caused by this drop")
	check(is_equal_approx(float(hunt.dropped_handheld.payload.get("battery", -1.0)), charge), "its remaining charge travels with the same object")

	hunt.dropped_handheld.freeze = true
	hunt.dropped_handheld.global_position = hunt.player + Vector3(1.0, -0.4, 0.0)
	hunt._persist_dropped_handheld()
	hunt.player = hunt.dropped_handheld.global_position
	hunt.player_body.global_position = hunt.player - Vector3.UP * 0.6
	hunt._update_dropped_handheld_prompt()
	check("RECOVER BLACK MIRROR" in hunt.prompt.text, "standing over it exposes a serialised recovery prompt")
	var dropped_condition: float = hunt.handheld.condition
	hunt._interact()
	check(hunt.handheld.possessed, "E repossesses the dropped device")
	check(hunt.dropped_handheld == null, "the world body leaves only after repossession succeeds")
	check(hunt.handheld.serial == serial and is_equal_approx(hunt.handheld.condition, dropped_condition), "pickup preserves serial and accumulated condition")

	# Drop it once more and leave it there: the next Hunt instance must rebuild
	# the physical object rather than trapping the save in `possessed = false`.
	hunt.handheld.drop()
	hunt.dropped_handheld.freeze = true
	var saved_at := Vector3(7.25, 0.15, 12.5)
	hunt.dropped_handheld.global_position = saved_at
	hunt._persist_dropped_handheld()
	remove_child(hunt)
	hunt.queue_free()
	await get_tree().process_frame

	var reloaded = HUNT.instantiate()
	add_child(reloaded)
	await get_tree().process_frame
	check(not reloaded.handheld.possessed, "a reload remembers the device is still out of the player's hands")
	check(reloaded.dropped_handheld is RigidBody3D, "and reconstructs its pickable world body")
	var restored_at: Vector3 = reloaded.dropped_handheld.global_position
	check(Vector2(restored_at.x, restored_at.z).distance_to(Vector2(saved_at.x, saved_at.z)) < 0.05, "at the last persisted world position (with gravity free to settle it vertically)")
	check(int(reloaded.dropped_handheld.payload.get("serial", -1)) == serial, "with the original serial after the reload")

	print("HANDHELD_WORLD_DROP_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
