extends Node

## A short deterministic gameplay take: inspect and raise a cigarette, draw to
## its clean window, release into the automatic exhale, shape the fresh breath,
## sink a bong cone, then inspect a weapon. This drives the same Hunt methods as
## live input; it is not a separate animation demo.

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
	# Cigarette: the fingers and remaining paper are readable before the compact
	# clean pull, continuous paper burn and neutral breath.
	if frame == 12:
		hunt.set("inspect_held", true)
	if frame == 38:
		hunt.set("inspect_held", false)
	if frame == 54:
		hunt.call("_begin_smoking_draw")
	if frame == 102:
		hunt.call("_finish_smoking_draw")
	if frame == 124:
		hunt.call("_shape_smoke_trick")
	# Spliff: relaxed roll into the mouth and the first green-grey breath.
	if frame == 168:
		hunt.call("_equip_smokeable", "spliff")
	if frame == 184:
		hunt.call("_begin_smoking_draw")
	if frame == 244:
		hunt.call("_finish_smoking_draw")
	if frame == 266:
		hunt.call("_shape_smoke_trick")
	# Bong: weighted two-hand lift, live bowl, water bubbles and chamber fill.
	if frame == 308:
		hunt.call("_equip_smokeable", "bong")
	if frame == 326:
		hunt.call("_begin_smoking_draw")
	if frame == 428:
		hunt.call("_finish_smoking_draw")
	if frame == 450:
		hunt.call("_shape_smoke_trick")
	# End on a real two-hand weapon inspection to show the verb is universal.
	if frame == 478:
		hunt.call("_equip_weapon", 1)
	if frame == 492:
		hunt.set("inspect_held", true)
	if frame == 550:
		hunt.set("inspect_held", false)
	if frame >= 574:
		get_tree().quit()
