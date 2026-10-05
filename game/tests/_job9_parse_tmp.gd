extends Node
func _ready() -> void:
	var s = load("res://tests/v01_enemies_capture.gd")
	print("PARSE capture ", s != null and s.can_instantiate())
	get_tree().quit()
