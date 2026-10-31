extends Node
## Greg's generated models in the hands (Higgsfield, 29 September): each one
## keeps the contract every held weapon keeps (muzzle along +Z before the
## assembly's turn, and the grip / grip_support / muzzle anchors the hands and
## the arsenal read), replaces only the picture, and falls back to the drawn
## model where it cannot load.

var failures := 0


func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	failures += int(not condition)


func _longest(root: Node3D) -> float:
	var longest := 0.0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var size := ((node as MeshInstance3D).mesh.get_aabb().size * (node as MeshInstance3D).global_transform.basis.get_scale())
			longest = maxf(longest, maxf(size.x, maxf(size.y, size.z)))
	return longest


## Tight bounds from the real vertices, in `root`'s space (a mesh's own box
## turned by a rotation is far looser than what is actually there).
func _vertex_bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var to_root := root.global_transform.affine_inverse() * (node as MeshInstance3D).global_transform
			for surface in (node as MeshInstance3D).mesh.get_surface_count():
				for vertex: Vector3 in (node as MeshInstance3D).mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
					var point := to_root * vertex
					box = AABB(point, Vector3.ZERO) if first else box.expand(point)
					first = false
	return box


func _ready() -> void:
	# --- The BREACH NINE, Hollis's gun. ---
	var gear := HeldGear.build_weapon("breach_nine")
	add_child(gear)
	check(gear.find_child("generated_breach_nine", true, false) != null, "the BREACH NINE is the generated model")
	for anchor in ["grip", "grip_support", "muzzle"]:
		check(gear.get_node_or_null("anchor_" + anchor) != null, "it keeps anchor_" + anchor)
	var grip := gear.get_node("anchor_grip") as Node3D
	var muzzle := gear.get_node("anchor_muzzle") as Node3D
	check(muzzle.position.z > grip.position.z + 0.1, "muzzle ahead of the grip on +Z, the convention every weapon keeps")
	var length := _longest(gear)
	check(length > 0.15 and length < 0.35, "pistol-sized in metres (%.3f m longest side)" % length)

	var rig := BaselineHuman.new()
	rig.gore = false
	add_child(rig)
	rig.build("held_models_test")
	var arsenal: Node = HunterArsenal.new()
	add_child(arsenal)
	arsenal.configure(rig)
	check(arsenal.models["sidearm"].find_child("generated_breach_nine", true, false) == null, "the starting sidearm stays the drawn pistol")
	check(arsenal.acquire_facility_sidearm(9), "Hollis's gun can be taken")
	var in_hand: Node3D = arsenal.models["facility_sidearm"]
	check(in_hand.find_child("generated_breach_nine", true, false) != null, "in the first-person hand it is the generated model")
	check(in_hand.find_child("RightGripHand", true, false) != null and in_hand.find_child("LeftGripHand", true, false) != null, "both hands still wrap it")
	arsenal.tick(2.0)
	var loaded_before := int(arsenal.ammo.facility_sidearm.loaded)
	var fired: Dictionary = arsenal.begin_attack()
	check(bool(fired.get("accepted", false)) and int(arsenal.ammo.facility_sidearm.loaded) == loaded_before - 1, "it still fires and spends a round (the model changed a picture, not the gun)")

	# --- The hub body holds it in the fist. ---
	var holder := Control.new()
	add_child(holder)
	var preview := VatBodyPreview.new()
	holder.add_child(preview)
	await get_tree().process_frame
	preview.present({})
	await get_tree().process_frame
	preview.hold("facility_sidearm")
	var hub_weapon: Node = preview.rig.parts["right_arm"].get_node_or_null("HeldWeapon")
	check(hub_weapon != null and hub_weapon.find_child("generated_breach_nine", true, false) != null, "the hub body holds the generated model")

	# --- The shiv: blade forward (+Z), level, a knife's size. ---
	var shiv := HeldGear.build_weapon("shiv")
	add_child(shiv)
	check(shiv.find_child("generated_shiv", true, false) != null, "the shiv is the generated model")
	var shiv_grip := shiv.get_node("anchor_grip") as Node3D
	# `build_weapon` turns the assembly once at the end, so "forward" is -Z here.
	var shiv_box := _vertex_bounds(shiv)
	check(shiv_box.size.z > 0.28 and shiv_box.size.z < 0.42, "knife-length along the blade axis (%.3f m)" % shiv_box.size.z)
	check(shiv_box.size.x < 0.12 and shiv_box.size.y < 0.12, "and knife-thin across it (%.3f x %.3f m): turned to the axis, not diagonal" % [shiv_box.size.x, shiv_box.size.y])
	check(shiv_box.position.z < shiv_grip.global_position.z - 0.15, "the blade reaches well forward of the grip")
	check(shiv_box.end.z > shiv_grip.global_position.z, "and the pommel sits behind it")
	arsenal.acquire_melee("shiv")
	check(arsenal.models["shiv"].find_child("generated_shiv", true, false) != null, "in the first-person hand it is the generated model")

	print("MODEL_HELD_ITEMS_TEST_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
