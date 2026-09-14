extends Node

## Greg: bodies should "have detailled gruesome body wounds" from the guns.
## The fault was never that damage was not tracked — it was that `hit_at()`
## received the exact impact point and discarded it, so every wound on a limb
## was drawn in the same hardcoded spot.

const HUMAN := preload("res://systems/baseline_human.gd")
const MARKS := preload("res://systems/wound_marks.gd")

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

	var rig: BaselineHuman = HUMAN.new()
	add_child(rig)
	rig.build("wound_test", {})
	await get_tree().process_frame

	var torso := rig.parts.get("torso") as Node3D
	check(torso != null, "sanity: the rig has a torso to be shot in")

	# --- a hit is recorded where it landed -----------------------------------
	# Points chosen close to the torso centre and then confirmed, rather than
	# assumed: `zone_nearest` is what decides which limb a world point belongs
	# to, and a point a hand's width off centre can legitimately resolve to an
	# arm. The bug under test is about position within a zone, so the test has
	# to be sure both shots landed in the same one.
	var left_of_centre := torso.global_position + Vector3(-0.05, 0.12, 0.16)
	var right_of_centre := torso.global_position + Vector3(0.05, -0.10, 0.16)
	var zone_a := rig.zone_nearest(left_of_centre)
	var zone_b := rig.zone_nearest(right_of_centre)
	check(zone_a == zone_b, "sanity: both test points resolve to the same limb (%s / %s)" % [zone_a, zone_b])

	rig.hit_at(left_of_centre, 30.0, 6.0, "ballistic", Vector3(0, 0, -1))
	var marks: Array = rig.wound_marks.get(zone_a, [])
	check(marks.size() == 1, "a round leaves exactly one wound, not none and not a shower")

	# --- a second hit elsewhere is a second, different wound -----------------
	rig.hit_at(right_of_centre, 30.0, 6.0, "ballistic", Vector3(0, 0, -1))
	marks = rig.wound_marks.get(zone_a, [])
	check(marks.size() == 2, "shooting a different spot leaves a second wound")
	var a: Vector3 = marks[0]["at"]
	var b: Vector3 = marks[1]["at"]
	check(a.distance_to(b) > 0.1, "and the two are in genuinely different places (%.3f m apart) — this is the whole bug" % a.distance_to(b))

	# --- they are drawn, and drawn on the limb ------------------------------
	var struck := rig.parts.get(zone_a) as Node3D
	var holder := struck.get_node_or_null("Wounds")
	check(holder != null, "the wounds are actually built as geometry, not just recorded")
	check(holder != null and holder.get_child_count() == 2, "one mesh per wound")
	# Riding the limb is the reason they are stored in local space: a thrown arm
	# takes its holes with it.
	check(holder != null and holder.get_parent() == struck, "and they are children of the limb, so they move with it and leave with it")

	# --- size responds to the hit ------------------------------------------
	var small: Dictionary = MARKS.make(Vector3.ZERO, Vector3.UP, 8.0, "ballistic", 0)
	var heavy: Dictionary = MARKS.make(Vector3.ZERO, Vector3.UP, 90.0, "ballistic", 0)
	check(float(heavy["radius"]) > float(small["radius"]), "a heavier round opens a wider hole")
	var punch: Dictionary = MARKS.make(Vector3.ZERO, Vector3.UP, 40.0, "ballistic", 0)
	var tear: Dictionary = MARKS.make(Vector3.ZERO, Vector3.UP, 40.0, "shear", 0)
	check(float(tear["radius"]) > float(punch["radius"]), "and something that tears opens a wider one than something that punches, at the same damage")
	var skin: Dictionary = MARKS.make(Vector3.ZERO, Vector3.UP, 40.0, "ballistic", 0)
	var organ: Dictionary = MARKS.make(Vector3.ZERO, Vector3.UP, 40.0, "ballistic", 4)
	check(float(organ["radius"]) > float(skin["radius"]), "a wound into the organ layer reads bigger than one that only broke skin")

	# --- a graze is not a hole ---------------------------------------------
	var before: int = (rig.wound_marks.get(zone_a, []) as Array).size()
	rig.hit_at(left_of_centre, 1.0, 0.5, "blunt", Vector3(0, 0, -1))
	check((rig.wound_marks.get(zone_a, []) as Array).size() == before, "a hit under the threshold leaves no mark — marking everything makes the marks mean nothing")

	# --- emptying a magazine into one limb degrades the limb, not the frame --
	for shot in 40:
		rig.hit_at(left_of_centre + Vector3(randf_range(-0.04, 0.04), randf_range(-0.06, 0.06), 0.0), 20.0, 4.0, "ballistic", Vector3(0, 0, -1))
	marks = rig.wound_marks.get(zone_a, [])
	check(marks.size() <= MARKS.MAX_PER_ZONE, "wounds are capped per limb (%d) rather than accumulating without limit" % marks.size())
	var live := struck.get_node_or_null("Wounds")
	check(live != null and live.get_child_count() <= MARKS.MAX_PER_ZONE, "and so is the geometry — forty rounds is not forty meshes")

	print("WOUND_MARKS_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
