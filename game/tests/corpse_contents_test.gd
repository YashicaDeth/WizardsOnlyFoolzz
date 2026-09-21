extends Node

## A panel that cannot be used to skip the dig.
##
## The failure worth testing here is not how a corpse panel looks. It is that
## listing the contents of a body is a way to give away what `Extraction` and
## `Cavity` exist to charge for. Read "HEART" off a sealed chest, click it, and
## the nine-second dig has been reduced to a label.
##
## So the checks are all the same shape: what is on the outside is always
## listed, what is under the skin is listed only once the body is actually open
## that far, and a zone that is holding out says that it is holding out without
## saying what.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func labels_of(rows: Array) -> String:
	var names: Array[String] = []
	for row: Dictionary in rows:
		names.append(str(row.get("label", "?")))
	return ", ".join(names) if not names.is_empty() else "nothing"


func has_organ(found: Dictionary, organ_id: String) -> bool:
	for row: Dictionary in found.get("organs", []):
		if str(row.get("organ_id", "")) == organ_id:
			return true
	return false


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var rig := BaselineHuman.new()
	add_child(rig)
	rig.build("loot_subject", {"cybernetics": {"torso": {"name": "ceramic sternum"}, "left_arm": {"name": "ledger thumb"}}})
	rig.dress(ClothingShell.fresh_wardrobe())
	await get_tree().process_frame

	print("-- a body nobody has opened --")
	var shut: Dictionary = CorpseContents.of(rig, ["gate scrip", "brass knuckle"])
	check((shut.pockets as Array).size() == 2, "pockets are on the outside and always list (%s)" % labels_of(shut.pockets))
	check((shut.worn as Array).size() > 0, "so is what they are wearing (%s)" % labels_of(shut.worn))
	# The whole point of the gate.
	check((shut.organs as Array).is_empty(), "a sealed body lists no organs at all")
	check((shut.implanted as Array).is_empty(), "and no hardware, however much of it is in there")
	check((shut.sealed as Array).has("torso"), "but it does say the chest is holding out")
	# Saying a chest is shut is not the same as saying what is behind it.
	check(not CorpseContents.summary(shut).contains("HEART"), "and saying so does not name what is behind it (%s)" % CorpseContents.summary(shut))

	print("-- open the chest --")
	var chest := rig.parts.torso as MeshInstance3D
	Cavity.open_zone(rig, "torso", -chest.global_transform.basis.z)
	var opened: Dictionary = CorpseContents.of(rig, [])
	check(has_organ(opened, "heart"), "now the heart is there to take")
	check(has_organ(opened, "gut") and has_organ(opened, "liver"), "and everything else in the chest with it")
	# Opening one zone is not opening the body.
	check(not has_organ(opened, "brain"), "opening a chest does not put a brain on the list")
	check((opened.sealed as Array).has("head"), "the head is still holding out")

	print("-- hardware costs the dig, not the cut --")
	# The chest is open and the sternum is still under everything in it.
	check((opened.implanted as Array).is_empty(), "an open chest does not hand over the hardware in it")
	check((opened.sealed as Array).has("torso"), "which is still something the chest is holding")
	rig.mark_opened("torso", GoreChunks.Layer.CYBERNETIC)
	var dug: Dictionary = CorpseContents.of(rig, [])
	check((dug.implanted as Array).size() == 1, "digging to the hardware layer turns it up (%s)" % labels_of(dug.implanted))
	check(str((dug.implanted[0] as Dictionary).get("zone", "")) == "torso", "in the zone that was dug")
	# And only that zone.
	check(not (dug.sealed as Array).has("torso"), "a chest with nothing left in it stops reading as sealed")

	print("-- what they are wearing is worth what it is worth --")
	var fresh_rows: Array = dug.worn
	var before := 0.0
	for row: Dictionary in fresh_rows:
		if str(row.get("zone", "")) == "left_leg":
			before = float(row.get("condition", 0.0))
	rig.wardrobe["left_leg"] = 0.3
	var worn: Dictionary = CorpseContents.of(rig, [])
	var after := 0.0
	for row: Dictionary in worn.worn:
		if str(row.get("zone", "")) == "left_leg":
			after = float(row.get("condition", 0.0))
	check(after < before, "a garment that took a beating reads lower than a fresh one (%.2f against %.2f)" % [after, before])
	rig.wardrobe["left_leg"] = 0.0
	var stripped: Dictionary = CorpseContents.of(rig, [])
	var still_there := false
	for row: Dictionary in stripped.worn:
		if str(row.get("zone", "")) == "left_leg":
			still_there = true
	check(not still_there, "and one destroyed outright is not there to take")

	print("-- a stump is not a container --")
	rig.severed.append("right_arm")
	var maimed: Dictionary = CorpseContents.of(rig, [])
	check(not (maimed.sealed as Array).has("right_arm"), "a severed arm does not read as sealed")
	check(not CorpseContents.worth_opening(rig, "right_arm"), "and nobody is invited to dig at a stump")

	print("-- and whether a dig is worth offering --")
	check(CorpseContents.worth_opening(rig, "head"), "a head nobody has opened is worth opening")
	check(not CorpseContents.worth_opening(rig, "torso"), "a chest already open with its hardware out is not")
	check(CorpseContents.worth_opening(rig, "left_arm"), "an arm with hardware still in it is")
	check(not CorpseContents.worth_opening(rig, "right_leg"), "a thigh with nothing in it never was")
	check(not CorpseContents.worth_opening(null, "torso"), "and no body at all is not worth digging into")

	rig.queue_free()
	print("CORPSE_CONTENTS_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
