extends Node

const DERBY := preload("res://rift_derby.gd")
const WORLD_LOOK := preload("res://systems/world_look.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WORLD_LOOK.set_quality_name("ULTRA")
	var ultra_debris := DERBY.debris_budget()
	var ultra_lights := DERBY.arena_light_budget()
	WORLD_LOOK.set_quality_name("PERFORMANCE")
	var performance_debris := DERBY.debris_budget()
	var performance_lights := DERBY.arena_light_budget()
	check(performance_debris < ultra_debris and performance_debris == 64, "performance mode caps derby debris at 64 instead of %d" % ultra_debris)
	check(performance_lights < ultra_lights and performance_lights == 4, "performance mode uses four arena lights instead of %d" % ultra_lights)
	var derby: Node = DERBY.new()
	for index in performance_debris + 3:
		var shard := Node3D.new()
		derby.add_child(shard)
		derby._track_debris(shard, Vector3.ZERO, 1.0)
	check(derby.debris.size() == performance_debris, "every derby debris path holds the configured cap (%d)" % derby.debris.size())
	derby.free()
	WORLD_LOOK.set_quality_name("HIGH")
	print("DERBY_BUDGET_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
