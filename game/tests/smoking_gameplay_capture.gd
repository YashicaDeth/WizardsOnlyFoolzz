extends Node

## A deterministic full smoking showcase. It drives the same Hunt methods as
## live input; it is not a separate animation demo. Every held device appears,
## all three smoke tricks cycle in their normal order, and the take ends on the
## universal weapon inspection pose.

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
	# Cigarette: inspect, Zippo, continuous burn, automatic breath and an O.
	if frame == 12:
		hunt.set("inspect_held", true)
	if frame == 42:
		hunt.set("inspect_held", false)
	if frame == 55:
		hunt.call("_begin_smoking_draw")
	if frame == 110:
		hunt.call("_finish_smoking_draw")
	if frame == 128:
		hunt.call("_shape_smoke_trick")
	# Vape: distinct hand rhythm, no lighter, then DOUBLE O.
	if frame == 170:
		hunt.call("_equip_smokeable", "vape")
	if frame == 185:
		hunt.call("_begin_smoking_draw")
	if frame == 235:
		hunt.call("_finish_smoking_draw")
	if frame == 253:
		hunt.call("_shape_smoke_trick")
	# Joint: herb tint and the GHOST inhale.
	if frame == 295:
		hunt.call("_equip_smokeable", "joint")
	if frame == 310:
		hunt.call("_begin_smoking_draw")
	if frame == 365:
		hunt.call("_finish_smoking_draw")
	if frame == 383:
		hunt.call("_shape_smoke_trick")
	# Spliff: inspect the rolled object, then its slower mouth gesture.
	if frame == 425:
		hunt.call("_equip_smokeable", "spliff")
	if frame == 438:
		hunt.set("inspect_held", true)
	if frame == 468:
		hunt.set("inspect_held", false)
	if frame == 480:
		hunt.call("_begin_smoking_draw")
	if frame == 540:
		hunt.call("_finish_smoking_draw")
	# Bong: inspect, weighted two-hand lift, Zippo, live bowl, water bubbles,
	# chamber fill and a long cone sink while the camera looks down it.
	if frame == 590:
		hunt.call("_equip_smokeable", "bong")
	if frame == 605:
		hunt.set("inspect_held", true)
	if frame == 640:
		hunt.set("inspect_held", false)
	if frame == 650:
		hunt.call("_begin_smoking_draw")
	if frame == 770:
		hunt.call("_finish_smoking_draw")
	if frame == 788:
		hunt.call("_shape_smoke_trick")
	# End on a real two-hand weapon inspection to show the verb is universal.
	if frame == 830:
		hunt.call("_equip_weapon", 1)
	if frame == 850:
		hunt.set("inspect_held", true)
	if frame == 920:
		hunt.set("inspect_held", false)
	if frame >= 950:
		get_tree().quit()
