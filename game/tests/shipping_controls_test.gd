extends Node

const DEV_AFFORDANCES := preload("res://systems/dev_affordances.gd")

var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition: failures.append(label)

func source(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""

func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var derby := source("res://rift_derby.gd")
	var lab := source("res://prototype_lab/lab.gd")
	check(not derby.contains("KEY_R"), "the shipping derby has no reset key")
	check(not derby.contains("func _reset_round"), "the shipping derby carries no hidden round reset")
	check(lab.contains("DEV_AFFORDANCES.available()"), "prototype reset and reseed controls share the development gate")
	check(lab.contains("DEV_AFFORDANCES.accepts_command_line"), "automation hooks share the development gate")
	check(DEV_AFFORDANCES.available(), "test runs can explicitly use development affordances")
	print("SHIPPING_CONTROLS_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
