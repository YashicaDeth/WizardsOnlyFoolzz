extends Node

## AN2.5. The live first-person check, made permanent.
##
## The choke-up was authored against the cleaver's handle and its heated edge,
## and the one thing that cannot be allowed to drift is a hand passing through
## the blade. `held_gear.gd`'s `GRIPS` table decides where a hand goes; this
## measures the geometry that actually ends up in frame, not the table.
##
## The cleaver is measured on the real Hunt's mount, after the same
## `_cycle_grip()` the B key calls. The sword is not issued to the Hunt any
## more, so its three grips are measured on the production mount
## `HunterArsenal._build_weapon_model()` builds and the same
## `HeldGear.pose_mounted_hand()` calls `HunterArsenal.apply_grip()` makes.
##
## The hand and the blade are both rigid children of that mount, so a swing
## carries them together; the live capture measured the same 1.14 mm at rest
## and on every frame of a light and heavy swing. The thing a grip table can
## author wrong is the seated grip, which is what this measures.
##
## A grip whose anchor is on the blade (`half_sword`'s off hand) is supposed to
## touch the steel, so that hand is checked for contact rather than clearance.
## Every hand on a handle, a choke, or the free-hand rest is checked for real
## clearance from the blade box.

const MIN_CLEARANCE := 0.0005
## How far a hand may sit from a blade its grip names, before it stops being a
## hand on the blade at all.
const BLADE_CONTACT := 0.030

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var melee_weapons := 0
	for weapon_id in hunt.GRIP_CYCLE:
		var definition: Dictionary = HunterArsenal.WEAPONS.get(weapon_id, {})
		if str(definition.get("kind", "")) != "melee":
			continue
		melee_weapons += 1
		var grips: Array = hunt.GRIP_CYCLE[weapon_id]
		check(not grips.is_empty(), "%s offers at least one grip to measure" % weapon_id)
		if weapon_id == "cleaver":
			await _check_cleaver(hunt, grips)
		elif weapon_id == "sword":
			_check_sword(grips)
		else:
			check(false, "melee grip '%s' has a production fixture in this test" % weapon_id)
	check(melee_weapons >= 2, "the melee weapons with a grip cycle are covered (%d)" % melee_weapons)

	print("MELEE_GRIP_CLEARANCE_RESULT failures=%d" % failures.size())
	if failures.is_empty():
		print("melee grip clearance: every offered grip seats its hands; no hand on a handle enters the blade")
		get_tree().quit(0)
	else:
		print("melee grip clearance FAILURES: ", failures)
		get_tree().quit(1)


func _check_cleaver(hunt: Node, grips: Array) -> void:
	hunt._equip_weapon(0)
	await get_tree().physics_frame
	check(str(hunt.arsenal.current_id) == "cleaver", "the live Hunt holds the issued cleaver")
	var mount := hunt.arsenal.models.get("cleaver") as Node3D
	check(mount != null and mount.visible, "the cleaver mount is the one drawn in the hand")
	if mount == null:
		return
	var weapon := mount.get_node_or_null("cleaver_model") as Node3D
	var right := mount.get_node_or_null("RightGripHand") as Node3D
	var blade := weapon.get_node_or_null("blade") as MeshInstance3D if weapon != null else null
	check(weapon != null and right != null and blade != null, "the live cleaver has its blade, mount and working hand")
	check(mount.get_node_or_null("LeftGripHand") == null, "the cleaver's off hand is free, not parked on a grip it does not use")
	if weapon == null or right == null or blade == null:
		return
	_blade_is_measurable(blade, "cleaver")

	var nearest_by_grip: Dictionary = {}
	for grip: String in grips:
		var guard := 0
		while str(hunt.current_grip) != grip and guard <= grips.size():
			hunt._cycle_grip()
			guard += 1
		check(str(hunt.current_grip) == grip, "B reaches the cleaver's %s grip" % grip)
		var spec: Dictionary = HeldGear.GRIPS.get(grip, {})
		check(not spec.is_empty(), "the cleaver's %s grip is in HeldGear.GRIPS" % grip)
		if spec.is_empty():
			continue
		nearest_by_grip[grip] = _check_hand(right, blade, spec.get("right", {}), "cleaver/%s working hand" % grip)
	# A clearance check alone would still pass if B changed the label but not
	# the hand. The choke-up is the grip that brings the hand up against the
	# bolster, so it must measure closer to the blade than the handle grip.
	if nearest_by_grip.has("one_hand") and nearest_by_grip.has("choke_up"):
		var handle_mm: float = float(nearest_by_grip["one_hand"]) * 1000.0
		var choke_mm: float = float(nearest_by_grip["choke_up"]) * 1000.0
		check(choke_mm < handle_mm - 20.0,
			"the choke-up really moves the hand up the handle (%.1f mm vs %.1f mm at the handle)" % [choke_mm, handle_mm])


func _check_sword(grips: Array) -> void:
	var mount := HunterArsenal._build_weapon_model("sword")
	add_child(mount)
	var weapon := mount.get_node_or_null("sword_model") as Node3D
	var right := mount.get_node_or_null("RightGripHand") as Node3D
	var left := mount.get_node_or_null("LeftGripHand") as Node3D
	var blade := weapon.get_node_or_null("blade") as MeshInstance3D if weapon != null else null
	check(weapon != null and right != null and left != null and blade != null,
		"the production sword mount carries its blade and both hands")
	if weapon == null or right == null or left == null or blade == null:
		mount.free()
		return
	_blade_is_measurable(blade, "sword")

	for grip: String in grips:
		var spec: Dictionary = HeldGear.GRIPS.get(grip, {})
		check(not spec.is_empty(), "the sword's %s grip is in HeldGear.GRIPS" % grip)
		if spec.is_empty():
			continue
		# The two calls `HunterArsenal.apply_grip()` makes for this grip.
		HeldGear.pose_mounted_hand(right, weapon, spec.get("right", {}), 1)
		HeldGear.pose_mounted_hand(left, weapon, spec.get("left", {}), -1)
		_check_hand(right, blade, spec.get("right", {}), "sword/%s right hand" % grip)
		_check_hand(left, blade, spec.get("left", {}), "sword/%s left hand" % grip)

	mount.free()


func _blade_is_measurable(blade: MeshInstance3D, label: String) -> void:
	var box: AABB = blade.get_aabb()
	check(box.size.length() > 0.05 and box.size.length() < 1.2,
		"the %s blade has real, blade-sized bounds (%.3f m across)" % [label, box.size.length()])


func _check_hand(hand: Node3D, blade: MeshInstance3D, spec: Dictionary, label: String) -> float:
	var metrics := _hand_metrics(hand, blade)
	check(int(metrics["vertices"]) > 0, "%s: there is hand geometry to measure" % label)
	if int(metrics["vertices"]) <= 0:
		return INF
	var anchor := str(spec.get("anchor", ""))
	var nearest: float = float(metrics["nearest"])
	var inside: int = int(metrics["inside"])
	print("  %s: %d vertices, nearest %.2f mm, %d inside%s" % [
		label, int(metrics["vertices"]), nearest * 1000.0, inside,
		" (on %s)" % anchor if anchor.begins_with("blade") else "",
	])
	if anchor.begins_with("blade"):
		check(nearest <= BLADE_CONTACT,
			"%s: the hand is actually on the blade at %s (%.1f mm from the steel)" % [label, anchor, nearest * 1000.0])
	else:
		check(inside == 0 and nearest >= MIN_CLEARANCE,
			"%s: the hand is clear of the blade (%.2f mm, %d vertices inside)" % [label, nearest * 1000.0, inside])
	return nearest


## Every vertex of every glove mesh under `hand`, in the blade mesh's frame.
## The wrist and fingers are separate MeshInstance3Ds at several transforms, so
## a hand origin alone would miss the part that actually reaches the steel.
## The first-person forearm lives under the hand too; it is sleeve, not grip,
## and is deliberately not part of the contact surface.
func _hand_metrics(hand: Node3D, blade: MeshInstance3D) -> Dictionary:
	var box: AABB = blade.get_aabb()
	var forearm := hand.get_node_or_null("FirstPersonForearm") as Node3D
	var to_blade := blade.global_transform.affine_inverse()
	var nearest := INF
	var inside := 0
	var deepest := 0.0
	var vertices := 0
	var stack: Array[Node] = [hand]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if forearm != null and (node == forearm or forearm.is_ancestor_of(node)):
			continue
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var to_blade_from_mesh := to_blade * mesh_instance.global_transform
		for surface in mesh_instance.mesh.get_surface_count():
			var arrays := mesh_instance.mesh.surface_get_arrays(surface)
			if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
				continue
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				var point: Vector3 = to_blade_from_mesh * vertex
				vertices += 1
				var closest := Vector3(
					clampf(point.x, box.position.x, box.end.x),
					clampf(point.y, box.position.y, box.end.y),
					clampf(point.z, box.position.z, box.end.z))
				nearest = minf(nearest, point.distance_to(closest))
				if box.has_point(point):
					var depth := minf(
						minf(point.x - box.position.x, box.end.x - point.x),
						minf(minf(point.y - box.position.y, box.end.y - point.y),
							minf(point.z - box.position.z, box.end.z - point.z)))
					deepest = maxf(deepest, depth)
					if depth > MIN_CLEARANCE:
						inside += 1
	return {
		"nearest": nearest if vertices > 0 else INF,
		"inside": inside,
		"deepest": deepest,
		"vertices": vertices,
	}
