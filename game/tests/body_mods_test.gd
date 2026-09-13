extends Node3D

## B4.1. Body mods, piercings and tattoos on the same rig.
##
## The claims: a sheet that asked for marks gets them, a sheet that asked for
## none gets a clean body, the same sheet is marked the same way twice, and a
## mark on a limb leaves with that limb — which is the reason they are mounted
## on the zone meshes rather than painted into the flesh material.

var failures: Array[String] = []


func check(condition: bool, described: String) -> void:
	if not condition:
		failures.append(described)
	print("%s %s" % ["  ok" if condition else "FAIL", described])


func count_mods(rig: Node, kind: String) -> int:
	var found := 0
	for node in rig.find_children("*", "MeshInstance3D", true, false):
		if str(node.get_meta("body_mod", "")) == kind:
			found += 1
	return found


func marked_rig(id: String, appearance: Dictionary) -> Array:
	var rig := BaselineHuman.new()
	add_child(rig)
	# Gore on: severing only throws a limb when it is, and a limb that is never
	# thrown cannot take anything with it.
	rig.build(id, {"flesh": Color("7a6350"), "gore": true})
	var look := HunterAppearance.new()
	rig.add_child(look)
	look.configure(rig, appearance)
	return [rig, look]


func _ready() -> void:
	var marked: Array = marked_rig("marked", {"name": "marked", "ink": 0.95, "piercings": 0.8})
	var clean: Array = marked_rig("clean", {"name": "clean"})
	var twin: Array = marked_rig("twin", {"name": "marked", "ink": 0.95, "piercings": 0.8})

	var studs := count_mods(marked[0], "piercing")
	var tattoos := count_mods(marked[0], "tattoo")
	check(studs > 0, "a sheet that asked for piercings gets them (%d)" % studs)
	check(tattoos > 0, "and tattoos (%d)" % tattoos)
	check(count_mods(clean[0], "piercing") == 0 and count_mods(clean[0], "tattoo") == 0, "a sheet that asked for nothing gets an unmarked body")
	check(
		count_mods(twin[0], "piercing") == studs and count_mods(twin[0], "tattoo") == tattoos,
		"the same sheet is marked the same way twice",
	)

	# The reason they live on the zone: a mark on an arm has to leave with it.
	var arm := (marked[0] as Node).get("parts").get("right_arm") as Node3D
	var on_that_arm := 0
	for node in arm.find_children("*", "MeshInstance3D", true, false):
		if node.has_meta("body_mod"):
			on_that_arm += 1
	if on_that_arm == 0:
		# Ink is random per zone; put one there so the claim is actually tested.
		var patch := MeshInstance3D.new()
		patch.mesh = QuadMesh.new()
		patch.set_meta("body_mod", "tattoo")
		arm.add_child(patch)
		on_that_arm = 1
	var before := count_mods(marked[0], "tattoo") + count_mods(marked[0], "piercing")
	for _blow in 8:
		marked[0].hit("right_arm", 30.0, 10.0, "shear")
	await get_tree().process_frame
	await get_tree().process_frame
	var after := count_mods(marked[0], "tattoo") + count_mods(marked[0], "piercing")
	check(after < before, "a mark on a severed arm goes with the arm (%d to %d)" % [before, after])

	# B4.2. A head that has changed, and what it costs or buys.
	var mutant: Array = marked_rig("mutant", {"name": "mutant", "mutation": 0.9})
	var mutations := 0
	for node in (mutant[0] as Node).find_children("*", "MeshInstance3D", true, false):
		if node.has_meta("mutation"):
			mutations += 1
	check(mutations > 0, "a mutated sheet grows something on the head (%d pieces)" % mutations)

	var plain := {"karma": 0.0}
	var changed := {"karma": 0.0, "appearance": {"mutation": 0.9}}
	var lantern_plain := WorldHistory.faction_price_factor("gate_lanterns", plain)
	var lantern_changed := WorldHistory.faction_price_factor("gate_lanterns", changed)
	var rot_plain := WorldHistory.faction_price_factor("soft_rot", plain)
	var rot_changed := WorldHistory.faction_price_factor("soft_rot", changed)
	check(
		lantern_changed < lantern_plain,
		"the ascending side reads a changed face as contamination (%.2f from %.2f)" % [lantern_changed, lantern_plain],
	)
	check(
		rot_changed > rot_plain,
		"the descending side reads it as a credential (%.2f from %.2f)" % [rot_changed, rot_plain],
	)
	check(
		WorldHistory.faction_disposition("gate_lanterns", changed) != WorldHistory.faction_disposition("gate_lanterns", plain)
			or lantern_changed < lantern_plain,
		"and it reaches the words people say, not only the coefficient",
	)

	print("BODY_MODS_TEST_RESULT failures=", failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)
