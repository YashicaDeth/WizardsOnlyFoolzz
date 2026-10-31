extends Node

## C1. The side a fighter raises is the part that opens.
##
## Every enemy wind-up already picks a side and shows it. The wound used to be
## resolved from an aim point at chest height whatever the side said, so a `LOW`
## warning opened a rib and a `LEFT` warning opened nothing in particular — the
## player was told to guard low and punished for believing it.
##
## Two claims, and both are about the same table:
## - the promise maps to a real zone (pure, checked for every side and for a
##   nonsense one);
## - the Hunt's own `_wound_player` puts the wound there when it is told what was
##   promised, and the warning names that part before it lands.

const PROMISES := {
	"high": "head",
	"low": "left_leg",
	"left": "left_arm",
	"right": "right_arm",
	"": "torso",
	"nonsense": "torso",
}

var failures: Array[String] = []
var checks := 0


func check(condition: bool, label: String) -> void:
	checks += 1
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	# --- the table -----------------------------------------------------------
	for side in PROMISES:
		var expected := str(PROMISES[side])
		check(FighterTier.zone_for(str(side)) == expected,
			"\"%s\" is promised on the %s" % [side if str(side) != "" else "nothing", expected.replace("_", " ")])

	# --- the wound the Hunt actually deals ------------------------------------
	var hunt: Node = (load("res://bone_yard_hunt.tscn") as PackedScene).instantiate()
	add_child(hunt)
	# The Hunt builds the player's body during its own boot, the same wait
	# `altered_perception_test` does before it asks for the rig.
	for _settle in 30:
		await get_tree().process_frame
	var rig: Node3D = hunt.get("player_rig") as Node3D
	check(rig != null, "the Hunt has a body to wound")
	if rig == null:
		print("ENEMY_ZONE_RESULT checks=%d failures=%d" % [checks, failures.size() + 1])
		get_tree().quit(1)
		return
	for side in ["high", "low", "left", "right"]:
		var zone := FighterTier.zone_for(side)
		var wounds_before := (rig.anatomy.wounds as Array).size()
		hunt.call("_wound_player", rig.global_position - Vector3(1, 0, 0), 9.0, "cut", zone)
		var wounds: Array = rig.anatomy.wounds
		var landed := ""
		if wounds.size() > wounds_before:
			landed = str((wounds[wounds.size() - 1] as Dictionary).get("zone", ""))
		check(landed == zone, "%s is promised and lands there (%s)" % [side, landed])

	# --- the warning says it before it lands ---------------------------------
	var marker := Node3D.new()
	hunt.add_child(marker)
	marker.global_position = rig.global_position
	var actor := {"attack_side": "low", "display_name": "TEST"}
	hunt.call("_show_telegraph", actor, marker, true)
	var mark: Label = actor.get("telegraph_mark") as Label
	check(mark != null and mark.text.contains("LEG"),
		"the warning names the leg it will take (%s)" % (mark.text if mark != null else "none"))

	hunt.queue_free()
	print("ENEMY_ZONE_RESULT checks=%d failures=%d" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
