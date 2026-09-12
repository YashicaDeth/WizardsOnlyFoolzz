extends Node

## Greg's report was "heaps of gore and combat don't work at all". The rig did
## carry gore, but it evaporated: every drop had a life of about two seconds and
## nothing was left behind, so a fight never marked the ground. And the GORE
## setting was applied only in the derby, so OFF did nothing in the Hunt Grounds.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	WorldHistory.register_subject("settings", {"gore": "FULL"})
	WorldHistory.update_subject("settings", {"gore": "FULL"})
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	check(hunt.viscera_fx, "the Hunt Grounds applies the gore setting at all")

	hunt._spawn_encounter_actor({"instance_id": "gore_probe", "kind": "hostile"}, hunt.player + Vector3(0, 0, 2))
	var actor: Dictionary = hunt.encounter_actors.back()
	var rig = actor.rig
	check(rig.gore, "a spawned hostile inherits the setting")

	var before: int = BaselineHuman.live_gore
	rig.hit("torso", 26.0, 12.0, "cut")
	var sprayed: int = BaselineHuman.live_gore - before
	check(sprayed >= 8, "a sword hit throws a real spray, not a few specks (%d)" % sprayed)

	# Run the airborne blood out of life so it lands.
	for step in 40:
		rig._process(0.1)
	check(BaselineHuman.splats.size() > 0, "blood that lands stays on the ground (%d marks)" % BaselineHuman.splats.size())
	var remembered: Array = BaselineHuman.blood_records.get(BaselineHuman._blood_scene_key(get_tree().current_scene), [])
	check(not remembered.is_empty(), "landed blood is retained as scene evidence, not only as a live mesh")
	check(BaselineHuman.live_gore < sprayed, "airborne blood is still cleaned up")

	# The floor fills and then stays full rather than growing without bound.
	for burst in 60:
		rig.hit("torso", 30.0, 12.0, "cut")
		for step in 40:
			rig._process(0.1)
	check(BaselineHuman.splats.size() <= BaselineHuman.MAX_SPLATS, "landed blood is capped (%d)" % BaselineHuman.splats.size())
	check(BaselineHuman.live_gore <= BaselineHuman.MAX_LIVE_GORE, "airborne blood is capped (%d)" % BaselineHuman.live_gore)

	# A drop of blood leaves a mark a few times its own size. It used to leave
	# one over three metres wide - _splat_mesh accepted a radius and ignored it,
	# so the mesh was already about two units across before the caller scaled it
	# up by another 6-12.5x, and any real fight buried its own floor in red.
	var widest := 0.0
	var measured := 0
	for splat in BaselineHuman.splats:
		var mark := splat as MeshInstance3D
		if mark == null or not is_instance_valid(mark) or mark.mesh == null:
			continue
		measured += 1
		widest = maxf(widest, (mark.get_aabb().size * mark.global_transform.basis.get_scale()).length())
	check(measured > 0, "there is landed blood to measure (%d marks)" % measured)
	check(widest < 1.2, "a landed drop is spatter, not a puddle you could lie in (widest %.2fm)" % widest)
	check(BaselineHuman._splat_mesh(1.0).get_aabb().size.x <= 2.01, "the splat mesh honours the radius it is given")

	# OFF must actually mean off, in the Hunt Grounds and not only in the derby.
	WorldHistory.update_subject("settings", {"gore": "OFF"})
	check(not BaselineHuman.apply_gore_setting(), "OFF is reported as off")
	WorldHistory.update_subject("settings", {"gore": "REDUCED"})
	check(BaselineHuman.apply_gore_setting() and is_equal_approx(BaselineHuman.detail, 0.4), "REDUCED thins the effect without disabling it")
	WorldHistory.update_subject("settings", {"gore": "FULL"})
	check(BaselineHuman.apply_gore_setting() and is_equal_approx(BaselineHuman.detail, 1.0), "FULL restores the effect")

	print("GORE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
