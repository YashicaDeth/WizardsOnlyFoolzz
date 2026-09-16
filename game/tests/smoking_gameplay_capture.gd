extends Node

## A deterministic full use-and-inspect reel. It drives the same Hunt methods as
## live input; it is not a separate animation viewer. Each smokeable is used and
## then read in the hand, followed by the sword, shotgun, sidearm and a physical
## carried limb performing their own inspection choreography.

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
	# Begin two draws into the same cigarette so the first demonstrated release
	# is its deterministic ash-flick beat rather than hiding that polish outside
	# the reel. This is still the live object and the live draw path.
	var primed_spent := Smokeables.spend_per_hit("cigarette") * 2.0
	var stored_spent: Dictionary = hunt.get("smoke_spent")
	stored_spent["cigarette"] = primed_spent
	hunt.set("smoke_spent", stored_spent)
	Smokeables.set_spent(hunt.get("smoke_model") as Node3D, primed_spent)
	frame = 1


func _process(_delta: float) -> void:
	if frame <= 0 or hunt == null:
		return
	frame += 1
	# Cigarette: use first, automatic breath and O, then inspect paper and ember.
	if frame == 20:
		hunt.call("_begin_smoking_draw")
	if frame == 82:
		hunt.call("_finish_smoking_draw")
	if frame == 102:
		hunt.call("_shape_smoke_trick")
	# Transfer it to the mouth, take a short hands-free puff, return it to the
	# fingers, then expose the paper/ember inspection before changing object.
	if frame == 112:
		hunt.call("_toggle_mouth_hold")
	if frame == 132:
		hunt.call("_begin_smoking_draw")
	if frame == 178:
		hunt.call("_finish_smoking_draw")
	if frame == 184:
		hunt.call("_toggle_mouth_hold")
	if frame == 190:
		hunt.set("inspect_held", true)
	if frame == 207:
		hunt.set("inspect_held", false)
	# Vape: use, DOUBLE O, then show its cell/window face.
	if frame == 210:
		hunt.call("_equip_smokeable", "vape")
	if frame == 225:
		hunt.call("_begin_smoking_draw")
	if frame == 282:
		hunt.call("_finish_smoking_draw")
	if frame == 302:
		hunt.call("_shape_smoke_trick")
	if frame == 316:
		hunt.set("inspect_held", true)
	if frame == 380:
		hunt.set("inspect_held", false)
	# Joint: use, GHOST, then inspect its thicker roll and green-biased ember.
	if frame == 410:
		hunt.call("_equip_smokeable", "joint")
	if frame == 425:
		hunt.call("_begin_smoking_draw")
	if frame == 485:
		hunt.call("_finish_smoking_draw")
	if frame == 505:
		hunt.call("_shape_smoke_trick")
	if frame == 520:
		hunt.set("inspect_held", true)
	if frame == 584:
		hunt.set("inspect_held", false)
	# Spliff: slower mouth gesture, use, then seam inspection.
	if frame == 614:
		hunt.call("_equip_smokeable", "spliff")
	if frame == 630:
		hunt.call("_begin_smoking_draw")
	if frame == 696:
		hunt.call("_finish_smoking_draw")
	if frame == 730:
		hunt.set("inspect_held", true)
	if frame == 796:
		hunt.set("inspect_held", false)
	# Bong: inspect, weighted two-hand lift, Zippo, live bowl, water bubbles,
	# chamber fill and a long cone sink; inspect bowl and chamber after the rip.
	if frame == 826:
		hunt.call("_equip_smokeable", "bong")
	if frame == 842:
		hunt.call("_begin_smoking_draw")
	if frame == 962:
		hunt.call("_finish_smoking_draw")
	if frame == 982:
		hunt.call("_shape_smoke_trick")
	if frame == 997:
		hunt.set("inspect_held", true)
	if frame == 1075:
		hunt.set("inspect_held", false)
	# Use and inspect every weapon class: edge read, receiver check, press-check.
	if frame == 1105:
		hunt.call("_equip_weapon", 0)
	if frame == 1118:
		hunt.call("_attack")
	if frame == 1140:
		hunt.set("inspect_held", true)
	if frame == 1215:
		hunt.set("inspect_held", false)
	if frame == 1245:
		hunt.call("_equip_weapon", 1)
	if frame == 1258:
		hunt.call("_attack")
	if frame == 1280:
		hunt.set("inspect_held", true)
	if frame == 1360:
		hunt.set("inspect_held", false)
	if frame == 1390:
		hunt.call("_equip_weapon", 2)
	if frame == 1403:
		hunt.call("_attack")
	if frame == 1425:
		hunt.set("inspect_held", true)
	if frame == 1505:
		hunt.set("inspect_held", false)
	# Finally use and inspect the gruesome improvised class that used to float
	# without any hand at all.
	if frame == 1535:
		hunt.get("handheld").carry.take_chunk({
			"layer_name": "limb", "whole_limb": true, "zone": "left_arm",
			"subject_id": "inspection_reel", "condition": 1.0,
		})
		hunt.call("_equip_carried_limb")
	if frame == 1548:
		hunt.call("_attack")
	if frame == 1570:
		hunt.set("inspect_held", true)
	if frame == 1665:
		hunt.set("inspect_held", false)
	if frame >= 1700:
		get_tree().quit()
