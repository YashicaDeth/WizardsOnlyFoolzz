extends Node

## A short deterministic gameplay take: raise a cigarette, draw to its clean
## window, release into the automatic exhale, then click the fresh breath into
## an O. This drives the same Hunt methods as live input; it is not a separate
## animation demo.

var hunt: Node
var frame := 0


func _ready() -> void:
	await get_tree().process_frame
	# Captures must not inherit a dose from a previous developer take.
	WorldHistory.clear_history()
	hunt = load("res://bone_yard_hunt.tscn").instantiate()
	get_tree().root.add_child(hunt)
	get_tree().current_scene = hunt
	for _settle in 75:
		await get_tree().process_frame
	# Record from the real first-person play view: the held ember, timed pull,
	# automatic breath and shaped ring are the things the player actually sees.
	hunt.set("third_person", false)
	hunt.set("perspective_blend", 0.0)
	hunt.get("body_motion").set_perspective(true)
	hunt.call("_equip_smokeable", "cigarette")
	frame = 1


func _process(_delta: float) -> void:
	if frame <= 0 or hunt == null:
		return
	frame += 1
	if frame == 28:
		hunt.call("_begin_smoking_draw")
	if frame == 126:
		hunt.call("_finish_smoking_draw")
	if frame == 164:
		hunt.call("_shape_smoke_trick")
	if frame >= 245:
		get_tree().quit()
