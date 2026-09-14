extends Node

const PROP := preload("res://systems/breakable_prop.gd")
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
	var prop: BreakableProp = PROP.new()
	add_child(prop)
	prop.build("scrap_barricade", Vector3(2.6, 1.3, 0.46), 24.0)
	await get_tree().physics_frame
	check(prop.get_node_or_null("SolidCollision") != null, "an intact barricade owns one physical collision shape")
	var brush: Dictionary = prop.impact(4.0, Vector3.FORWARD)
	check(not bool(brush["accepted"]) and not prop.broken, "a low-speed scrape does not explode a barricade")
	var ram: Dictionary = prop.impact(14.0, Vector3.FORWARD)
	check(bool(ram["accepted"]) and prop.broken, "a committed ram fractures the barricade")
	await get_tree().physics_frame
	check(prop.fragment_count() > 0, "a fractured barricade produces physical fragments")
	check(prop.fragment_count() <= 6, "one barricade stays inside its six-fragment local cap (%d)" % prop.fragment_count())
	check(prop.collision_layer == 0, "the intact collision is removed after the break")
	WORLD_LOOK.set_quality_name("ULTRA")
	var ultra := PROP.fragment_budget()
	WORLD_LOOK.set_quality_name("PERFORMANCE")
	var performance := PROP.fragment_budget()
	check(performance < ultra and performance == 14, "performance mode has a real global fragment budget (%d vs %d)" % [performance, ultra])
	WORLD_LOOK.set_quality_name("HIGH")
	prop.queue_free()
	print("BREAKABLE_PROP_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
