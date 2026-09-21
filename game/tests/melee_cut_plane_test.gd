extends Node

## The cut lands at the angle it was swung at. `cut_plane()` reported the swept
## plane with no caller; both melee hit sites now ask `_melee_cut_plane()` for
## it, and a still hand earns nothing — standing with a sword is not a swing.
## Driven through the real hunt like `arm_wired_test.gd`, not through the arm
## in isolation, since the wiring is the thing being tested.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var tree := get_tree()
	await tree.process_frame
	var hunt: Node = load("res://bone_yard_hunt.tscn").instantiate()
	tree.root.add_child(hunt)
	tree.current_scene = hunt
	for _settle in 120:
		await tree.physics_frame

	var arm = hunt.get("arm")
	check(arm != null, "the hunt builds an arm")
	if arm == null:
		_report()
		return

	# --- the player wakes dressed ------------------------------------------------
	# DESIGN.md:245 — the elites dress you. Asserted here rather than in a
	# clothing unit because the build site is the thing being tested.
	var player_rig = hunt.get("player_rig")
	check(player_rig != null and str(player_rig.wardrobe.get("style", "")) == "jester", "the player wakes in the humiliation rig")
	if player_rig != null:
		var p_torso := (player_rig as BaselineHuman).parts.get("torso") as Node3D
		check(p_torso != null and p_torso.get_node_or_null("Garment") != null, "with the motley rendered over the flesh")

	# --- a still hand earns no plane ------------------------------------------
	var rest_speed: float = arm.head_speed()
	print("head speed at rest: %.3f" % rest_speed)
	var cold: Variant = hunt.call("_melee_cut_plane", Vector3.ZERO)
	check(cold == null, "a still hand earns no plane — there was no swing to report")

	# --- a swung hand earns one -------------------------------------------------
	for _frame in 8:
		hunt.call("apply_look", Vector2(90.0 * 0.0026, 0.0))
		await tree.physics_frame
	var swung_speed: float = arm.head_speed()
	print("head speed mid-swing: %.3f" % swung_speed)
	check(swung_speed > 0.9, "sanity: the turn genuinely threw the weapon")
	var plane: Variant = hunt.call("_melee_cut_plane", Vector3(0.0, 1.2, -1.6))
	check(plane is Plane, "a swung hand earns a real plane")
	if plane is Plane:
		check(absf((plane as Plane).normal.length() - 1.0) < 0.01, "with a unit normal, not a degenerate")
		# The plane contains the swing: perpendicular to travel and to the edge.
		# Both in world space — the plane is reported there, so the check meets
		# it there rather than mixing view-space velocity against it.
		var holder: Basis = hunt.get("camera").global_transform.basis
		var travel: Vector3 = (holder * (arm.velocity as Vector3)).normalized()
		var edge: Vector3 = (holder * (arm.at as Vector3)).normalized()
		check(absf((plane as Plane).normal.dot(travel)) < 0.05, "square to the travel, so the blade does not slice across its own motion")
		check(absf((plane as Plane).normal.dot(edge)) < 0.05, "and square to the edge, so the cut is the sweep, not a stamp")

	# --- the wired path still lands ----------------------------------------------
	var forward: Vector3 = hunt.get("HUNTER_MOTOR").wish_direction(Vector2(0, -1), hunt.get("yaw"))
	var probe_at: Vector3 = hunt.get("player") + forward * 1.6 + Vector3(0, -0.5, 0)
	hunt.set("attack_cooldown", 0.0)
	hunt.call("_spawn_encounter_actor", {"instance_id": "cut_plane_probe", "kind": "hostile"}, probe_at)
	var probe: Dictionary = hunt.get("encounter_actors")[-1]
	(probe.node as Node3D).position = probe_at
	hunt.set("lock_target", str(probe.subject_id))
	var arsenal = hunt.get("arsenal")
	arsenal.cooldown = 0.0
	var before := 0.0
	for zone: Dictionary in probe.anatomy.zones.values():
		before += float(zone.get("health", 0.0))
	hunt.call("_attack")
	hunt.call("_resolve_strike")
	var after := 0.0
	for zone: Dictionary in probe.anatomy.zones.values():
		after += float(zone.get("health", 0.0))
	check(before - after > 0.0, "a swung strike through the wired path still connects (%.2f damage)" % (before - after))

	_report()


func _report() -> void:
	print("MELEE_CUT_PLANE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
