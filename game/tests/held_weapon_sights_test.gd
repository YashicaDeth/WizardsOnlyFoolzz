extends Node

## models-03. The remade guns carry the three points an aim-down-sights camera
## lines up on (`sight_rear`, `sight_front`, `muzzle`, all Marker3D), the line
## between the sights is level, centred, above the bore and not blocked by the
## gun itself, the trigger guards hang as vertical loops, and the same markers
## reach the hunter's real hand through HunterArsenal.

var failures := 0


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures += 1


## Every mesh vertex of `root`, in `root`'s own frame.
func _vertices(root: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var to_root := root.global_transform.affine_inverse() * (node as MeshInstance3D).global_transform
			for surface in (node as MeshInstance3D).mesh.get_surface_count():
				for vertex: Vector3 in (node as MeshInstance3D).mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
					out.append(to_root * vertex)
	return out


func _ready() -> void:
	for weapon_id in ["sidearm", "shotgun", "breach_nine"]:
		var gun := HeldGear.build_weapon(weapon_id)
		add_child(gun)
		var rear := gun.get_node_or_null("sight_rear") as Marker3D
		var front := gun.get_node_or_null("sight_front") as Marker3D
		var muzzle := gun.get_node_or_null("muzzle") as Marker3D
		check(rear != null and front != null and muzzle != null, "%s has Marker3D sight_rear, sight_front and muzzle" % weapon_id)
		if rear == null or front == null or muzzle == null:
			continue
		# Marker positions are in the builder's muzzle-forward (+Z) frame.
		check(front.position.z - rear.position.z > 0.15, "%s: front sight well ahead of the rear" % weapon_id)
		check(absf(front.position.y - rear.position.y) < 0.002 and absf(rear.position.x) < 0.001 and absf(front.position.x) < 0.001,
			"%s: the sight line is level and centred, parallel to the bore" % weapon_id)
		check(rear.position.y > muzzle.position.y + 0.015, "%s: the sight line sits above the bore" % weapon_id)
		check(muzzle.position.z >= front.position.z, "%s: the muzzle is at or ahead of the front sight" % weapon_id)
		var muzzle_anchor := gun.get_node_or_null("anchor_muzzle") as Node3D
		check(muzzle_anchor != null and muzzle_anchor.position.distance_to(muzzle.position) < 0.002, "%s: muzzle marker and muzzle anchor agree" % weapon_id)
		# Nothing of the gun pokes up into the line between the two sights.
		# `_vertices` is relative to the gun's root, which is the builder's
		# frame: the half turn `build_weapon` adds is on the root itself.
		var blocked := 0
		for p in _vertices(gun):
			if p.z > rear.position.z + 0.012 and p.z < front.position.z - 0.012 and absf(p.x) < 0.003 and p.y > rear.position.y - 0.0008:
				blocked += 1
		check(blocked == 0, "%s: the sight line is clear between the sights (%d vertices in it)" % [weapon_id, blocked])
		if weapon_id != "breach_nine":
			check(gun.find_child("magazine", false, false) != null, "%s still has the magazine the reload rides" % weapon_id)
			var guard := gun.get_node_or_null("trigger_guard") as MeshInstance3D
			var box := guard.transform * guard.mesh.get_aabb() if guard != null else AABB()
			check(guard != null and box.size.y > box.size.x * 2.0, "%s: the trigger guard hangs as a vertical loop (%.3f tall, %.3f wide)" % [weapon_id, box.size.y, box.size.x])
			check(gun.get_node_or_null("trigger") != null, "%s has a trigger inside it" % weapon_id)

	var sword := HeldGear.build_weapon("sword")
	add_child(sword)
	for part in ["blade", "fuller-1", "fuller1", "guard", "langet", "quillon-1", "quillon1", "grip", "pommel"]:
		check(sword.get_node_or_null(part) != null, "the sword has its %s" % part)
	for anchor in ["grip", "grip_low", "blade_grip", "blade_high", "muzzle"]:
		check(sword.get_node_or_null("anchor_" + anchor) != null, "the sword keeps anchor_" + anchor)
	var blade_box := (sword.get_node("blade") as MeshInstance3D).mesh.get_aabb()
	check(blade_box.size.z > 0.8 and blade_box.size.z < 0.9 and blade_box.size.y < 0.015, "the blade is a long, thin plate (%.3f long, %.4f thick)" % [blade_box.size.z, blade_box.size.y])

	# The route: the hunter's real hand gets the same markers.
	var rig := BaselineHuman.new()
	rig.gore = false
	add_child(rig)
	rig.build("held_weapon_sights_test")
	var arsenal: Node = HunterArsenal.new()
	add_child(arsenal)
	arsenal.configure(rig)
	for weapon_id in ["sidearm", "shotgun"]:
		var mount: Node3D = arsenal.models[weapon_id]
		check(mount.find_child("sight_rear", true, false) is Marker3D and mount.find_child("sight_front", true, false) is Marker3D,
			"the %s in the hunter's hand carries both sight markers" % weapon_id)
	check(arsenal.acquire_facility_sidearm(3), "the BREACH NINE can be taken")
	check(arsenal.models["facility_sidearm"].find_child("sight_front", true, false) is Marker3D, "and it carries sight markers in the hand too")

	print("HELD_WEAPON_SIGHTS_TEST_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
