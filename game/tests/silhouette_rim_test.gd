extends Node3D

## Greg, 29 September: enemies keep a faint readable silhouette in the dark
## rooms. Every mesh of a hostile's body wears the rim, reinforcements too;
## props beside it, an existing overlay (the undying flame), the dead and your
## own body do not.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _rimmed(root: Node) -> Array[int]:
	var rim := 0
	var all := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		all += 1
		if (node as MeshInstance3D).material_overlay == SilhouetteRim.material():
			rim += 1
	return [rim, all]


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var root := Node3D.new()
	add_child(root)
	var body := BaselineHuman.new()
	root.add_child(body)
	body.build("rim_probe", {"flesh": Color("5a4938"), "variation": 12})
	var prop := MeshInstance3D.new()
	prop.mesh = BoxMesh.new()
	root.add_child(prop)
	var meshes := body.find_children("*", "MeshInstance3D", true, false)
	var flame := ShaderMaterial.new()
	(meshes[0] as MeshInstance3D).material_overlay = flame
	var rimmed := SilhouetteRim.dress(root)
	check(rimmed > 0 and rimmed == meshes.size() - 1, "every mesh of the body wears the rim (%d of %d)" % [rimmed, meshes.size()])
	check(prop.material_overlay == null, "the prop beside it does not")
	check((meshes[0] as MeshInstance3D).material_overlay == flame, "an overlay already there (the undying flame) is left alone")
	check(SilhouetteRim.dress(root) == 0, "dressing twice changes nothing")
	check(SilhouetteRim.material().shader != null and SilhouetteRim.material().shader.get_mode() == Shader.MODE_SPATIAL, "the rim shader loads")
	root.queue_free()

	WorldHistory.clear_history()
	var unit: Node = load("res://support_unit.tscn").instantiate()
	add_child(unit)
	await get_tree().process_frame
	for guard in unit.guards:
		var count := _rimmed(guard)
		check(count[0] > 0 and count[0] == count[1], "%s is rimmed head to foot (%d of %d)" % [guard.name, count[0], count[1]])
	var hollis := _rimmed(unit.guard_post.guard)
	check(hollis[0] > 0 and hollis[0] == hollis[1], "Hollis at the gate is rimmed (%d of %d)" % hollis)
	var reinforcement: Node = unit._spawn_reinforcement(0)
	var late := _rimmed(reinforcement)
	check(late[0] > 0 and late[0] == late[1], "a reinforcement out of a wall door is rimmed too")
	var dead := 0
	for remains_id in unit.remains_nodes:
		dead += _rimmed(unit.remains_nodes[remains_id][0])[0]
	check(dead == 0, "the dead are not rimmed")
	check(_rimmed(unit.player)[0] == 0, "your own body is not rimmed")
	unit.queue_free()
	await get_tree().process_frame

	WorldHistory.clear_history()
	var arcade: Node = load("res://service_arcade.tscn").instantiate()
	add_child(arcade)
	await get_tree().process_frame
	var door := _rimmed(arcade.guard_post.guard)
	check(door[0] > 0 and door[0] == door[1], "the arcade's door guard is rimmed (%d of %d)" % door)
	arcade.queue_free()
	await get_tree().process_frame

	print("SILHOUETTE_RIM_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
