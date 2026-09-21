extends SceneTree

## The project carries LimboAI as a GDExtension.  This is a deliberately tiny
## compatibility gate before any guard behaviour is moved onto it: an upgrade
## is only an upgrade if it loads on the exact Windows/Godot build the game
## ships with.

func _init() -> void:
	var available := ClassDB.class_exists("BTPlayer") and ClassDB.class_exists("BehaviorTree")
	print("LIMBO_RUNTIME_RESULT available=%s" % str(available))
	quit(0 if available else 1)
