extends Node

func _ready() -> void:
	for klass in ["BTPlayer", "BehaviorTree", "BTAction", "Blackboard", "LimboHSM", "Terrain3D", "Terrain3DMaterial"]:
		print("CLASS ", klass, " = ", ClassDB.class_exists(klass))
	print("DialogueManager autoload = ", Engine.has_singleton("DialogueManager") or get_node_or_null("/root/DialogueManager") != null)
	var scatter := load("res://addons/proton_scatter/src/scatter.gd")
	print("ProtonScatter script = ", scatter != null)
	var fmod_ok := ClassDB.class_exists("FmodServer") or ClassDB.class_exists("FMODStudioModule")
	print("FMOD classes = ", fmod_ok)
	get_tree().quit()
