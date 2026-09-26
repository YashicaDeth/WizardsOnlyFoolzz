extends Node

## Lane C: gore has to work the same in all four places bodies get hit.
##
##   - the Gore Sandbox (`gore_demo.tscn`)
##   - the vat room (`vat_chamber.tscn`)
##   - the Support Unit (`support_unit.tscn`)
##   - the Hunt (`bone_yard_hunt.tscn`)
##
## Every one of those scenes builds its people with `BaselineHuman`, and every
## wound, chunk, drip, streak and pool in this game is reached through the rig
## rather than through the scene. So the question is not "does gore work here"
## but "does a hit in this scene reach the rig at all", and the only honest way
## to ask that is to hit something in each scene and look at the body.
##
## This suite drives the real scenes, finds a real person in each, hits them,
## and then checks the three things Greg named: a wound mark, a body that is
## bleeding, and blood in the world. It prints what it found either way, so a
## scene that is wired but slow to bleed says so instead of reading as broken.

const POOL := preload("res://systems/blood_pool.gd")
const FLOW := preload("res://systems/blood_flow.gd")

const SCENES := {
	"sandbox": "res://gore_demo.tscn",
	"vat room": "res://vat_chamber.tscn",
	"support unit": "res://support_unit.tscn",
	"hunt": "res://bone_yard_hunt.tscn",
}

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


## First built person in the tree, whoever owns them. Scene-specific reach-in
## (`bodies[0]`, `guard_post.rig`, `encounter_actors[0]`) would make this suite
## break every time a scene restructures its own cast.
func _find_rig(node: Node) -> BaselineHuman:
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_front()
		if current is BaselineHuman and current.has_method("hit_at"):
			return current
		for child in current.get_children():
			stack.append(child)
	return null


func _wound_total(rig: BaselineHuman) -> int:
	var total := 0
	for marks: Array in rig.wound_marks.values():
		total += (marks as Array).size()
	return total


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()

	for label: String in SCENES:
		print("-- %s --" % label)
		var scene: Node = load(SCENES[label]).instantiate()
		add_child(scene)
		for _frame in 4:
			await get_tree().process_frame

		var rig := _find_rig(scene)
		check(rig != null, "%s: the scene stands a person who can be hurt" % label)
		if rig == null:
			scene.queue_free()
			continue

		var torso := rig.parts.get("torso") as Node3D
		if torso == null:
			# A downed or partial rig still has to be hittable, so fall back to
			# the rig's own origin rather than skipping the scene.
			torso = rig
		var at: Vector3 = torso.global_position + Vector3(0.0, 0.10, 0.18)
		var zone := rig.zone_nearest(at)
		var before := _wound_total(rig)

		# Hard enough to open a wound and start a bleed. The point is the path,
		# not the damage tuning.
		rig.hit_at(at, 34.0, 8.0, "ballistic", Vector3(0, 0, -1))
		var after := _wound_total(rig)
		check(after > before, "%s: a hit leaves a wound mark (%s, %d -> %d)" % [label, zone, before, after])

		var bleeding: float = float(rig.anatomy.bleed_rate) + float(rig.anatomy.internal_bleed_rate) * 0.12
		check(bleeding >= FLOW.MIN_BLEED, "%s: the body is bleeding after the hit (%.3f, floor %.3f)" % [label, bleeding, FLOW.MIN_BLEED])

		# Blood needs somewhere to land, and it arrives on a clock: `drip_one`
		# drops unnamed spheres the rig tracks in `_loose`, and the visible run
		# down the skin is a `BloodStreak` node on the part. Counting "nodes
		# called drip" finds nothing, which is how this check first reported four
		# broken scenes when three of them were bleeding.
		for _frame in 150:
			await get_tree().process_frame
		var pooled := POOL.pool_count(scene)
		var falling: int = (rig.get("_loose") as Array).size()
		var streaking := _count_streaks(rig)
		print("     rig '%s' gore=%s sites=%d bleed_s=%.2f streak=%d falling=%d pools=%d" % [
			rig.name, str(rig.gore), (rig._bleeding_sites() as Array).size(),
			rig.get("_bleed_seconds"), streaking, falling, pooled])
		check(streaking > 0 or falling > 0 or pooled > 0,
			"%s: blood reached the body and the world (streak %d, falling %d, pools %d)" % [label, streaking, falling, pooled])

		scene.queue_free()
		for _frame in 2:
			await get_tree().process_frame

	print("GORE_SCENE_PARITY_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## The wet run down the skin: `baseline_human._refresh_streaks` hangs one
## `BloodStreak` per bleeding limb. This is the blood you can actually see on
## the body, as opposed to a drop in the air or a mark on the floor.
func _count_streaks(rig: BaselineHuman) -> int:
	var found := 0
	for child in rig.get_children():
		if child.name == "BloodStreak" and is_instance_valid(child):
			found += 1
	for zone: String in rig.wound_marks.keys():
		var part := rig.parts.get(zone) as Node3D
		if part == null or not is_instance_valid(part):
			continue
		# A dressed wound bleeds *through* the cloth, so the run hangs on the
		# Garment node one thickness out rather than on the skin. Hollis wears a
		# clinical coat and the cradled subjects do not, which is why looking
		# only at the part reported the Support Unit as dry when it was not.
		if part.get_node_or_null("BloodStreak") != null:
			found += 1
		elif (part.get_node_or_null("Garment") as Node3D) != null \
				and (part.get_node("Garment") as Node3D).get_node_or_null("BloodStreak") != null:
			found += 1
	return found
