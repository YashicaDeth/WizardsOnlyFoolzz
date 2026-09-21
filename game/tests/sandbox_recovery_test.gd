extends Node

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func key_event(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var previous_quality := WorldLook.quality
	WorldLook.set_quality_name("PERFORMANCE")
	check(WorldLook.quality_name() == "PERFORMANCE", "a fresh safe-quality route disables the costly fullscreen tier")
	check(GoreChunks.chunk_budget() == 24, "performance quality caps persistent rigid gore at 24")
	check(GoreChunks.active_physics_budget() == 18, "performance quality keeps at most 18 loose pieces actively simulating")
	check(GoreChunks.impact_voice_budget() == 8, "performance quality prevents impact sounds from becoming an unbounded wall")
	check(BaselineHuman.live_gore_budget() == 52, "performance quality caps transient body effects at 52")
	check(BaselineHuman.splat_budget() == 96, "performance quality prevents hundreds of permanent blood draw objects")
	check(Ballistics.round_budget() == 32 and Ballistics.casing_budget() == 32 and Ballistics.wound_budget() == 64, "performance quality bounds active rounds, brass and impact scars")

	var loose_limb := RigidBody3D.new()
	add_child(loose_limb)
	GoreChunks.register_whole_limb(loose_limb, "left_arm", "sandbox_budget_probe")
	check(loose_limb.collision_layer == (1 << 5) and loose_limb.collision_mask == 1, "loose gore collides with the room, not every other loose piece")
	GoreChunks.clear()

	var demo = load("res://gore_demo.tscn").instantiate()
	add_child(demo)
	await get_tree().physics_frame
	demo.set_physics_process(false)
	var shadowed_lights: Array[Node] = []
	for light_node: Node in demo.find_children("*", "Light3D", true, false):
		if (light_node as Light3D).shadow_enabled:
			shadowed_lights.append(light_node)
	check(shadowed_lights.is_empty(), "performance sandbox avoids re-rendering seven articulated bodies into shadow maps")
	check(not demo.controls_expanded, "the sandbox opens with only essential controls")
	demo._unhandled_input(key_event(KEY_F1))
	check(demo.controls_expanded, "F1 deliberately reveals the complete reference")

	var chunks_before := GoreChunks.live_count()
	demo._unhandled_input(key_event(KEY_F))
	check(GoreChunks.live_count() == chunks_before, "F no longer detonates an invisible explosion")
	demo._unhandled_input(key_event(KEY_9))
	check(demo.launcher_equipped and str(demo.view_gear.weapon.name) == "launcher_model", "9 equips a visible dedicated breach launcher")
	var impact_subject: Dictionary = demo.bodies[0]
	(impact_subject.holder as Node3D).global_position = Vector3(demo.eye.x, 0.9, demo.eye.z - 4.0)
	var pain_before: float = (impact_subject.rig as BaselineHuman).anatomy.pain
	var rounds_before: int = demo.launcher_rounds
	demo._fire()
	check(demo.launcher_rounds == rounds_before - 1, "the launcher spends finite ammunition through the ordinary trigger")
	check(demo.ballistics.rounds.size() == 1, "the launcher creates one travelling round rather than an instant blast")
	var payload: Dictionary = (demo.ballistics.rounds[0] as Dictionary).get("payload", {})
	check(bool(payload.get("explosive", false)) and str((demo.ballistics.rounds[0] as Dictionary).get("calibre", "")) == "rocket",
		"the visible round carries its explosion to the impact point")
	for _frame in 24:
		await get_tree().physics_frame
	check((impact_subject.rig as BaselineHuman).anatomy.pain > pain_before or demo.severed_total > 0,
		"the warhead detonates against its physical target rather than at the player's feet")

	WorldLook.quality = previous_quality
	print("SANDBOX_RECOVERY_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
