extends Node

## Greg, 25 September: "if you shoot downwards with a gun ... there will be an
## impact hole" (DESIGN/GOAL_LOOP_2.md 0.2b). Real rounds through the Hunt's own
## Ballistics: into the ground they dig a hole sized by the calibre and the
## world records it; into anything that is not the ground they keep the scar.

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
	WorldDebris.clear_pool(GroundHole.CLOD_POOL)
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var guns = hunt.ballistics

	var pistol: Node3D = await _shoot(guns, Vector3(3.0, 2.0, 24.0), Vector3.DOWN, "pistol")
	check(_is_hole(pistol), "a pistol round fired into the ground leaves a hole, not a scar")
	if pistol != null:
		var ground_y := _ground_under(Vector3(3.0, 2.0, 24.0))
		check(absf(pistol.global_position.y - ground_y) < 0.02 and Vector2(pistol.global_position.x, pistol.global_position.z).distance_to(Vector2(3.0, 24.0)) < 0.1,
			"on the ground where the round hit it (%s, ground at %.3f)" % [pistol.global_position, ground_y])
		check(pistol.get_node_or_null("Bowl") != null and pistol.get_node_or_null("Lip") != null, "with a pit drawn into it and a lip of dirt round it")
	var rifle: Node3D = await _shoot(guns, Vector3(4.5, 2.0, 24.0), Vector3.DOWN, "rifle")
	var pistol_r := float(pistol.get_meta("radius", 0.0)) if pistol else 0.0
	var rifle_r := float(rifle.get_meta("radius", 0.0)) if rifle else 0.0
	check(rifle != null and rifle_r > pistol_r * 1.8, "a rifle round digs a wider hole than a pistol round (%.3f m vs %.3f m)" % [rifle_r, pistol_r])
	check(WorldDebris.pool_count(GroundHole.CLOD_POOL) > 0, "and throws out clods that stay as debris (%d)" % WorldDebris.pool_count(GroundHole.CLOD_POOL))

	var filed: Dictionary = {}
	for index in range(WorldHistory.events.size() - 1, -1, -1):
		var event: Dictionary = WorldHistory.events[index]
		if str(event.get("type", "")) == "round_struck_world":
			filed = event.get("details", {})
			break
	var hole: Dictionary = filed.get("ground_hole", {})
	check(not hole.is_empty() and is_equal_approx(float(hole.get("radius", 0.0)), snappedf(rifle_r, 0.001)),
		"the world records where the hole is and how big (%s)" % [hole])

	# Not the ground: a wall, and the top of a block, both keep the flat scar.
	var block := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(1, 1, 1)
	block.add_child(shape)
	add_child(block)
	block.global_position = Vector3(6.0, 0.5, 24.0)
	await get_tree().physics_frame
	var wall: Node3D = await _shoot(guns, Vector3(6.0, 0.5, 26.0), Vector3.FORWARD, "rifle")
	check(_is_scar(wall), "a round into a wall leaves the scar it always did")
	var lid: Node3D = await _shoot(guns, Vector3(6.0, 2.0, 24.0), Vector3.DOWN, "rifle")
	check(_is_scar(lid), "and so does a surface that faces up but is not the ground")

	print("GROUND_HOLE_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## By what a mark is made of, not its name: Godot renames a second sibling.
func _is_hole(mark: Node3D) -> bool:
	return mark != null and mark.has_node("Bowl") and mark.has_node("Lip")


func _is_scar(mark: Node3D) -> bool:
	return mark != null and mark.has_node("ImpactCore") and not mark.has_node("Bowl")


func _ground_under(from: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 10.0)
	var met := get_viewport().world_3d.direct_space_state.intersect_ray(query)
	return (met.position as Vector3).y if not met.is_empty() else INF


## Fires one round and waits for it to land, handing back what it left.
func _shoot(guns: Node, from: Vector3, along: Vector3, calibre: String) -> Node3D:
	var before: int = guns.marks.size()
	guns.fire(from, along, calibre, 0.0, 1, "test", {})
	for _frame in 120:
		await get_tree().physics_frame
		if guns.marks.size() > before:
			return guns.marks.back()
	return null
