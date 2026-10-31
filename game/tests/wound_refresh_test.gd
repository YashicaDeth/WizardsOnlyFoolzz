extends Node

## Greg's 30 September playtest dropped to 7 fps: every blow rebuilt every
## wound on the struck zone (up to 14 meshes and materials; 340 ms a blow on a
## busy arm with the real renderer). Now a blow builds only the new wound, a
## deeper opening re-tints the old ones, and a dropped wound goes.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _wounds(rig: BaselineHuman, zone: String) -> Array:
	var holder := (rig.parts[zone] as Node3D).get_node_or_null("Wounds")
	return holder.get_children() if holder != null else []


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var holder := Node3D.new()
	add_child(holder)
	holder.position = Vector3(0, 0.9, 0)
	var rig := BaselineHuman.new()
	holder.add_child(rig)
	rig.position = Vector3(0, -0.9, 0)
	rig.build("wound_refresh_subject", {"gore": true, "blood": 9000.0, "undying": true})
	await get_tree().process_frame
	var torso := rig.parts["torso"] as Node3D
	var at := torso.global_position + Vector3(0.0, 0.05, -0.15)

	rig.hit_at(at, 8.0, 2.0, "cut", Vector3(0, 0, 1))
	var first: Array = _wounds(rig, "torso")
	check(first.size() >= 1, "a cut leaves a wound (%d)" % first.size())
	rig.hit_at(at + Vector3(0.05, 0.08, 0), 8.0, 2.0, "cut", Vector3(0, 0, 1))
	var second: Array = _wounds(rig, "torso")
	var kept := 0
	for node in first:
		if is_instance_valid(node) and second.has(node):
			kept += 1
	check(second.size() > first.size(), "a second cut adds a wound (%d -> %d)" % [first.size(), second.size()])
	check(kept == first.size(), "and the first wound is the same node, not rebuilt (%d of %d kept)" % [kept, first.size()])

	# A wound shows min(its own layer, the zone's depth): when the zone's depth
	# falls below it (healed, a prosthetic), its look changes and it is rebuilt.
	for wound: Dictionary in rig.wound_marks["torso"]:
		wound["layer"] = 3
	rig.zone_depth["torso"] = 3
	rig._refresh_wounds("torso")
	var opened: Array = _wounds(rig, "torso")
	rig.zone_depth["torso"] = 0
	rig._refresh_wounds("torso")
	var closed: Array = _wounds(rig, "torso")
	var rebuilt := 0
	for node in closed:
		if not opened.has(node):
			rebuilt += 1
	check(rebuilt == closed.size() and closed.size() == opened.size(), "a change in the layer a wound shows rebuilds it (%d of %d)" % [rebuilt, closed.size()])

	# Past MAX_PER_ZONE the oldest wound's mesh goes with its record.
	for index in WoundMarks.MAX_PER_ZONE + 3:
		rig.hit_at(at + Vector3(0.01 * index, 0.0, 0.0), 8.0, 2.0, "cut", Vector3(0, 0, 1))
	await get_tree().process_frame
	var marks: Array = rig.wound_marks.get("torso", [])
	check(marks.size() == WoundMarks.MAX_PER_ZONE and _wounds(rig, "torso").size() == marks.size(), "one mesh per wound on record, capped (%d meshes, %d records)" % [_wounds(rig, "torso").size(), marks.size()])
	var unmatched := 0
	for node in _wounds(rig, "torso"):
		var record: Variant = node.get_meta("wound", null)
		var found := false
		for wound in marks:
			if is_same(record, wound):
				found = true
		if not found:
			unmatched += 1
	check(unmatched == 0, "every wound mesh belongs to a wound still on record (%d strays)" % unmatched)

	print("WOUND_REFRESH_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
