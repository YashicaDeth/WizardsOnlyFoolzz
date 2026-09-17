extends Node

## B10.1 / B10.2. T1.1 says the universe restarts and you do not.
##
## Nine passes went into this body and none of them had anywhere to go, because
## the restart erased the person along with the world: `begin_new()` called
## `clear_history()`, `clear_history()` empties `subjects`, and `subjects` is
## where bodies live. You were not surviving the branch, you were being
## re-decanted into it.
##
## So this asks the two questions the items ask, of the rig rather than of a
## dictionary:
##
##   B10.1 — is the thing standing in the new world the same body? Built from
##           the same papers, the same authored shape, down to the geometry.
##   B10.2 — and what did it bring? Scars: the holes, where they are, how deep
##           the limb was opened, the arm that is not there. Not statistics:
##           not the health it had left, not the blood it had lost, not the
##           pain it was in. A body that arrives in a new universe still
##           bleeding from a wound that is not in this world — and with no hole
##           where the wound was — has carried over exactly the wrong half.
##
## The geometry checks are the point. `wound_marks` being a dictionary with the
## right number of entries proves a dictionary round-tripped; asking the limb
## for its `Wounds` node proves the body has holes in it.

const HUMAN := preload("res://systems/baseline_human.gd")
const MARKS := preload("res://systems/wound_marks.gd")
const Quantum := preload("res://systems/quantum_saves.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _rig_from(record: Dictionary, node_name: String) -> BaselineHuman:
	var rig: BaselineHuman = HUMAN.new()
	rig.name = node_name
	add_child(rig)
	var config: Dictionary = HUMAN.config_from_subject(record)
	# Explicit rather than inherited from the world's gore setting: these checks
	# count wound geometry, and a suite that silently ran with gore off would
	# report no holes and call it a finding.
	config["gore"] = true
	rig.build("player", config)
	return rig


## The same person's papers with nothing that ever happened to them attached —
## a body as it was made. Everything B10.1 claims is "recognisably itself" has
## to be true of this one too, or it was never about the body.
func _authored_only(record: Dictionary) -> Dictionary:
	var clean := record.duplicate(true)
	clean.erase("anatomy_state")
	return clean


func _holes_on(rig: BaselineHuman, zone: String) -> int:
	var part := rig.parts.get(zone) as Node3D
	if part == null or not is_instance_valid(part):
		return -1
	var holder := part.get_node_or_null("Wounds")
	if holder == null:
		return 0
	return holder.get_child_count()


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()

	# --- a person, filed the way the intake files one ------------------------
	var sheet := CharacterSheet.new()
	sheet.display_name = "THE HUNTER"
	sheet.race = "marrow_cut"
	sheet.appearance = {"face": 0.82, "wear": 0.31}
	sheet.under_skin = {"skeleton": "standard", "organs": "standard", "blood": "NULL", "grown_with": []}
	sheet.apply_to_world()
	var papers: Dictionary = WorldHistory.subject("player")
	check(not papers.is_empty(), "sanity: the intake filed a body to restart")

	var before := _rig_from(papers, "BeforeBody")
	await get_tree().process_frame

	# --- mark it -------------------------------------------------------------
	# Two points near the torso centre, confirmed to resolve to one zone rather
	# than assumed to: a point a hand's width off centre can legitimately land
	# on an arm, and this is about position *within* a limb.
	var torso := before.parts.get("torso") as Node3D
	check(torso != null, "sanity: the rig has a torso to be shot in")
	var high := torso.global_position + Vector3(-0.05, 0.12, 0.16)
	var low := torso.global_position + Vector3(0.05, -0.10, 0.16)
	var zone := before.zone_nearest(high)
	check(zone == before.zone_nearest(low), "sanity: both shots land on the same limb (%s / %s)" % [zone, before.zone_nearest(low)])
	before.hit_at(high, 30.0, 6.0, "ballistic", Vector3(0, 0, -1))
	before.hit_at(low, 30.0, 6.0, "ballistic", Vector3(0, 0, -1))
	var marked: Array = before.wound_marks.get(zone, [])
	check(marked.size() >= 2, "sanity: the body took %d marks before the restart" % marked.size())
	var marked_at: Array[Vector3] = []
	for wound: Dictionary in marked:
		marked_at.append(wound["at"] as Vector3)
	check(_holes_on(before, zone) == marked.size(), "sanity: and they are holes in it, not entries in a list (%d)" % _holes_on(before, zone))

	# --- and take an arm off, which is the loudest scar there is -------------
	var arm := "left_arm"
	var arm_part := before.parts.get(arm) as Node3D
	for swing in 8:
		if before.severed.has(arm):
			break
		before.hit_at(arm_part.global_position, 22.0, 5.0, "shear", Vector3(1, 0, 0))
	check(before.severed.has(arm), "sanity: an arm came off before the restart")

	var hurt_health := before.zone_health(zone)
	before.anatomy.pain = 44.0
	before.anatomy.blood_remaining = before.anatomy.blood_capacity * 0.5
	before.anatomy.downed = true
	WorldHistory.update_subject("player", {"anatomy_state": before.snapshot()}, "anatomy_changed")

	# --- an ordinary save is not a restart ----------------------------------
	# Guarded here because the fix for B10.2 is a *reduction*, and a reduction
	# applied in the wrong place would quietly heal every body that crosses an
	# ordinary load. Loading a save has to still bring everything back.
	var reloaded := _rig_from(WorldHistory.subject("player"), "ReloadedBody")
	await get_tree().process_frame
	check(is_equal_approx(reloaded.zone_health(zone), hurt_health), "an ordinary load still restores the statistics (%.1f vs %.1f)" % [reloaded.zone_health(zone), hurt_health])
	check((reloaded.wound_marks.get(zone, []) as Array).size() == marked.size(), "and the scars, which is what a save never carried at all")
	check(_holes_on(reloaded, zone) == marked.size(), "as holes on the limb (%d)" % _holes_on(reloaded, zone))

	# --- cross the restart --------------------------------------------------
	var born := Quantum.begin_new(1, "SECOND WORLD")
	check(not born.is_empty(), "sanity: the restart births a new world")
	var born_event: Dictionary = WorldHistory.events[-1]
	check(str(born_event.get("type", "")) == "quantum_branch_born" and str((born_event.get("details", {}) as Dictionary).get("action_id", "")).begins_with("action_") and int(WorldHistory.get("_ledger_batch_depth")) == 0,
		"the blank world, carried body and branch-birth receipt persist as one crossing")
	# Round-trip it through the file the branch was written to, rather than
	# reading the live dictionary the restart left behind. JSON has no Vector3:
	# a scar written straight out comes back as the *string* "(0.1, 0.2, 0.3)",
	# and a body whose wounds are strings has no holes in it.
	WorldHistory.clear_history()
	check(Quantum.enter(1), "sanity: and the new world can be re-entered from disk")

	var after_papers: Dictionary = WorldHistory.subject("player")
	check(not after_papers.is_empty(), "B10.1: there is still a body in the world after the restart")
	var after := _rig_from(after_papers, "AfterBody")
	var virgin := _rig_from(_authored_only(after_papers), "VirginBody")
	await get_tree().process_frame

	# --- B10.1: recognisably itself -----------------------------------------
	check(after.subject_id == before.subject_id, "B10.1: the same body, under the same name")
	check(str(after_papers.get("name", "")) == str(papers.get("name", "")), "and the same person answering to it (%s)" % str(after_papers.get("name", "")))
	check(is_equal_approx(after.build_factor, before.build_factor), "built to the same size (%.3f vs %.3f) — the race is a silhouette, not a stat block" % [after.build_factor, before.build_factor])
	var before_head := (before.parts["head"] as MeshInstance3D).mesh.get_aabb().size
	var after_head := (after.parts["head"] as MeshInstance3D).mesh.get_aabb().size
	check(after_head.is_equal_approx(before_head), "with the same head, generated from the same face (%.3v vs %.3v)" % [after_head, before_head])
	var virgin_head := (virgin.parts["head"] as MeshInstance3D).mesh.get_aabb().size
	check(after_head.is_equal_approx(virgin_head), "and the same head the papers alone describe — the shape is the person, not the damage")
	check(after.parts.keys() == before.parts.keys(), "with the same zones it was authored with")

	# --- B10.2: what it carried is scars ------------------------------------
	var after_marks: Array = after.wound_marks.get(zone, [])
	check(after_marks.size() == marked.size(), "B10.2: the scars crossed the restart (%d of %d)" % [after_marks.size(), marked.size()])
	check(after_marks.size() > 0 and after_marks[0].get("at") is Vector3, "each one still a place on the limb, not the string JSON makes of a position")
	var located := 0
	for wound: Dictionary in after_marks:
		for was: Vector3 in marked_at:
			if (wound.get("at", Vector3.ZERO) as Vector3).distance_to(was) < 0.001:
				located += 1
				break
	check(located == marked_at.size(), "in the same places they were made (%d of %d)" % [located, marked_at.size()])
	check(_holes_on(after, zone) == after_marks.size(), "B10.2: and the rig has holes in it, not a record of holes (%d meshes)" % _holes_on(after, zone))
	var holder := (after.parts[zone] as Node3D).get_node_or_null("Wounds")
	check(holder != null and holder.get_parent() == after.parts[zone], "on the limb itself, in the limb's own space, so they ride it and leave with it")
	check(_holes_on(virgin, zone) == 0, "and the same body without the history has none of them — the marks are the history, not the build")
	check(int(after.zone_depth.get(zone, 0)) == int(before.zone_depth.get(zone, 0)), "how deep the limb was opened crossed too (%d)" % int(after.zone_depth.get(zone, 0)))
	check(after.severed.has(arm), "B10.2: the arm is still gone")
	check(not (after.parts[arm] as Node3D).visible, "and gone on the rig, not just in a list")

	# --- B10.2: and not statistics ------------------------------------------
	check(is_equal_approx(after.zone_health(zone), virgin.zone_health(zone)), "B10.2: the health it lost did not cross — the numbers come back as the body was made (%.1f vs %.1f)" % [after.zone_health(zone), virgin.zone_health(zone)])
	check(after.zone_health(zone) > hurt_health, "which is more than it had left in the old world (%.1f)" % hurt_health)
	check(is_equal_approx(after.anatomy.blood_remaining, virgin.anatomy.blood_remaining), "the blood it lost did not cross (%.0f vs %.0f)" % [after.anatomy.blood_remaining, virgin.anatomy.blood_remaining])
	check(after.anatomy.pain <= 0.01, "nor the pain it was in (%.1f)" % after.anatomy.pain)
	check(not after.anatomy.downed and not after.anatomy.dead, "and a body that was on the floor of the old world stands up in this one")
	check(float(after.sever_stress.get(arm, 0.0)) <= 0.0, "the running tally toward losing the arm did not cross either — that is a counter, the missing arm is the scar")

	print("BODY_RESTART_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
