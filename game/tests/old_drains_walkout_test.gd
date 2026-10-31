extends Node

## Walk the actual player from the drop channel onto the cistern causeway. The
## route test teleports past this stretch and therefore cannot catch its lip.

const DRAINS := preload("res://old_drains.tscn")

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
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person", "status": "loose"})
	var drains = DRAINS.instantiate()
	add_child(drains)
	for _frame in 3:
		await get_tree().physics_frame
	var stalker = drains.get("stalker")
	if stalker != null and is_instance_valid(stalker):
		stalker.process_mode = Node.PROCESS_MODE_DISABLED
		stalker.visible = false
	drains.set("yaw", 0.0)
	for _frame in 60:
		await get_tree().physics_frame
	var landed: Vector3 = drains.player.global_position
	check(landed.y < 0.6, "the drop lands in the channel, below the walkways")
	Input.action_press("move_forward")
	var cistern_z: float = drains.CISTERN_Z
	var out := false
	for _frame in 900:
		await get_tree().physics_frame
		drains.set("yaw", 0.0)
		var at: Vector3 = drains.player.global_position
		if at.z < cistern_z - 1.5 and at.y > 0.8:
			out = true
			break
	Input.action_release("move_forward")
	if not out:
		print("stuck at ", drains.player.global_position)
	check(out, "holding forward from the drop walks out of the channel onto the causeway")
	print("OLD_DRAINS_WALKOUT_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
