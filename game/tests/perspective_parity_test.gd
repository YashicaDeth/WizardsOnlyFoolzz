extends Node

## AX5.2's hard constraint: first- and third-person share anatomy, wound depth
## and ballistics, so nothing that decides what a hit *does* is allowed to
## know which one is active. Reads the checked-out source of the four
## functions that resolve a hit rather than trusting the diff that wired the
## camera's clearance blend not to have reached into them — `third_person`,
## `first_person` and `is_first_person` are the words a regression would
## reach for, and proving an identifier was never written is the one thing a
## source scan can do that running the functions never could.

var failures: Array[String] = []

const TARGETS := [
	{"path": "res://bone_yard_hunt.gd", "func": "_resolve_strike"},
	{"path": "res://bone_yard_hunt.gd", "func": "_attack"},
	{"path": "res://bone_yard_hunt.gd", "func": "_resolve_firearm"},
	{"path": "res://systems/anatomy_component.gd", "func": "apply_hit"},
]
const FORBIDDEN := ["third_person", "first_person", "is_first_person"]


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


## The body of one top-level function, by name, out of a whole script's
## source: everything from its own `func name(` line up to, but not
## including, the next line that opens a new top-level function.
func _function_body(source: String, func_name: String) -> String:
	var body := PackedStringArray()
	var inside := false
	var found := false
	for line in source.split("\n"):
		if line.begins_with("func %s(" % func_name):
			inside = true
			found = true
		elif inside and line.begins_with("func "):
			break
		if inside:
			body.append(line)
	return "\n".join(body) if found else ""


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	for target: Dictionary in TARGETS:
		var path := str(target.path)
		var func_name := str(target.func)
		var source := FileAccess.get_file_as_string(path)
		check(not source.is_empty(), "%s is readable" % path)
		var body := _function_body(source, func_name)
		check(not body.is_empty(), "%s() was found in %s" % [func_name, path])
		for word in FORBIDDEN:
			check(not body.contains(word), "%s() in %s never mentions `%s`" % [func_name, path, word])

	print("PERSPECTIVE_PARITY_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
