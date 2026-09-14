extends Node

## Greg, describing what he wants, almost as a spec:
##
##   "say you shot them in the middle of their hand, you could shoot a hole into
##    their hand because there's not enough there ... you move down on their arm,
##    you shoot, a hole, it only goes halfway through ... certain bullets will
##    only make so much of a penetration wound and a flesh wound."
##
## So the test is his sentence: the same round, two places on the same limb, two
## different outcomes — and nothing in the model knowing what a hand is.

const HUMAN := preload("res://systems/baseline_human.gd")
const PEN := preload("res://systems/penetration.gd")
const BALLISTICS := preload("res://systems/ballistics.gd")

var failures: Array[String] = []

func check(c: bool, label: String) -> void:
	print("PASS " if c else "FAIL ", label)
	if not c:
		failures.append(label)

func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()

	var pistol: float = float((BALLISTICS.CALIBRES["pistol"] as Dictionary)["penetration"])

	# --- the sentence ------------------------------------------------------
	# -1.0 is the bottom of the arm: the wrist/hand end, thin.
	var hand: Dictionary = PEN.resolve("left_arm", -1.0, false, pistol, 0.0, 0.62)
	# +0.7 is the deltoid, the thickest part of the same limb.
	var upper: Dictionary = PEN.resolve("left_arm", 0.7, false, pistol, 0.0, 0.62)
	check(bool(hand["through"]), "the same round goes through the thin end of an arm")
	check(not bool(upper["through"]), "and does not go through the thick end of it")
	check(float(upper["fraction"]) > 0.0 and float(upper["fraction"]) < 1.0, "it stops part-way in — %.0f%% of the way through" % (float(upper["fraction"]) * 100.0))
	check(float(hand["thickness"]) < float(upper["thickness"]), "because there is less arm there, which is the only reason (%.3f m vs %.3f m)" % [hand["thickness"], upper["thickness"]])

	# --- bigger rounds go further -----------------------------------------
	var buck: float = float((BALLISTICS.CALIBRES["buck"] as Dictionary)["penetration"])
	var rifle: float = float((BALLISTICS.CALIBRES["rifle"] as Dictionary)["penetration"])
	check(rifle > buck, "sanity: the calibre table already ranks these")
	var chest_buck: Dictionary = PEN.resolve("torso", 0.3, false, buck, 0.0, 0.66)
	var chest_rifle: Dictionary = PEN.resolve("torso", 0.3, false, rifle, 0.0, 0.66)
	check(not bool(chest_buck["through"]), "buckshot stops inside a chest")
	check(bool(chest_rifle["through"]), "a rifle round leaves through the back of it")

	# --- which way through the body matters --------------------------------
	var front: Dictionary = PEN.resolve("torso", 0.5, false, rifle, 0.0, 0.66)
	var side: Dictionary = PEN.resolve("torso", 0.5, true, rifle, 0.0, 0.66)
	check(float(side["thickness"]) > float(front["thickness"]), "a chest is wider than it is deep, so a side-on shot crosses more of it (%.3f vs %.3f)" % [side["thickness"], front["thickness"]])

	# --- armour is a thickness, not a discount -----------------------------
	var bare: Dictionary = PEN.resolve("torso", 0.3, false, pistol, 0.0, 0.66)
	var plated: Dictionary = PEN.resolve("torso", 0.3, false, pistol, 0.45, 0.66)
	check(float(plated["fraction"]) < float(bare["fraction"]), "armour means the same round gets less far in")
	var heavy: Dictionary = PEN.resolve("torso", 0.3, false, pistol, 1.0, 0.66)
	check(int(heavy["result"]) == PEN.Result.STOPPED_BY_ARMOUR, "and enough of it stops a light round outright")
	var rifle_plated: Dictionary = PEN.resolve("torso", 0.3, false, rifle, 1.0, 0.66)
	check(int(rifle_plated["result"]) != PEN.Result.STOPPED_BY_ARMOUR, "while the same plate barely inconveniences a rifle — which is why armour is a thickness and not a percentage")

	# --- and it lands on a real body --------------------------------------
	var rig: BaselineHuman = HUMAN.new()
	add_child(rig)
	rig.build("penetrated", {})
	await get_tree().process_frame
	# The same worn plate that reduces `apply_hit()` must reduce a round's
	# remaining depth. This is deliberately a real rig read, not a second
	# hand-maintained list of what clothes mean to ballistics.
	var bare_torso_armour := rig.anatomy.zone_armor("torso")
	rig.anatomy.worn = ["scrap plate"]
	var worn_torso_armour := rig.anatomy.zone_armor("torso")
	check(worn_torso_armour > bare_torso_armour, "worn scrap plate is included in the torso's penetration armour")
	var bare_torso: Dictionary = PEN.resolve("torso", 0.3, false, pistol, bare_torso_armour, 0.66)
	var worn_torso: Dictionary = PEN.resolve("torso", 0.3, false, pistol, worn_torso_armour, 0.66)
	check(float(worn_torso["fraction"]) < float(bare_torso["fraction"]), "the same worn plate leaves the round less depth to make a wound")
	rig.anatomy.worn = []
	var arm := rig.parts.get("left_arm") as Node3D
	# Low on the arm, where it is thin: expect an entry and an exit.
	var low := arm.to_global(Vector3(0, -0.28, 0.06))
	var zone := rig.zone_nearest(low)
	rig.hit_at(low, 26.0, 5.0, "ballistic", Vector3(0, 0, -1), 0.75)
	var marks: Array = rig.wound_marks.get(zone, [])
	check(marks.size() == 2, "a round that goes through leaves two wounds, not one (%d)" % marks.size())
	if marks.size() == 2:
		check(bool(marks[1].get("exit", false)), "the second one is the exit")
		check(float(marks[1]["radius"]) > float(marks[0]["radius"]), "and the exit is the bigger of the two")

	# High on the arm with a weak round: one wound, no exit.
	var rig2: BaselineHuman = HUMAN.new()
	add_child(rig2)
	rig2.build("stopped", {})
	await get_tree().process_frame
	var arm2 := rig2.parts.get("left_arm") as Node3D
	var high := arm2.to_global(Vector3(0, 0.22, 0.08))
	var zone2 := rig2.zone_nearest(high)
	rig2.hit_at(high, 26.0, 5.0, "ballistic", Vector3(0, 0, -1), 0.12)
	var marks2: Array = rig2.wound_marks.get(zone2, [])
	check(marks2.size() == 1, "a round that stops inside leaves one wound (%d)" % marks2.size())
	if marks2.size() >= 1:
		check(not bool(marks2[0].get("through", false)), "and it is not marked as having gone through")
		check(float(marks2[0].get("depth", 1.0)) < 1.0, "its recorded depth is partial — %.0f%%" % (float(marks2[0].get("depth", 1.0)) * 100.0))

	print("PENETRATION_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
