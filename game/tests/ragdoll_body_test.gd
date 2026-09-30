extends Node3D

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	_add_floor()
	await _test_physics_corpse()
	_test_opt_out_and_missing_limb()
	print("RAGDOLL_BODY_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _add_floor() -> void:
	var floor := StaticBody3D.new()
	floor.name = "TestFloor"
	add_child(floor)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20.0, 0.10, 20.0)
	collider.shape = shape
	collider.position.y = -0.05
	floor.add_child(collider)


func _body(id: String, ragdoll: bool, travel := 0.25) -> BaselineHuman:
	var body := BaselineHuman.new()
	add_child(body)
	body.build(id, {"gore": false, "ragdoll": ragdoll, "knockdown_travel": travel})
	return body


func _kill(body: BaselineHuman, direction := Vector3.LEFT, impulse := 4.0) -> void:
	body.hit("head", 200.0, impulse, "puncture", "brain", direction)


func _test_physics_corpse() -> void:
	var body := _body("ragdoll_subject", true)
	_kill(body)
	check(body.anatomy.dead and body.ragdoll_body != null, "an opted-in death hands the existing body to a ragdoll")
	check(body.ragdoll_body.bodies.size() == BaselineHuman.ZONES.size(), "every attached zone becomes one physics body")
	await get_tree().create_timer(3.15).timeout
	var corpse := body.ragdoll_body
	var torso := corpse.bodies.get("torso") as RigidBody3D
	check(torso != null and torso.global_position.x < -0.01, "a blow travelling from +X carries the corpse toward -X")
	var in_bounds := true
	for body_value in corpse.bodies.values():
		var zone_body := body_value as RigidBody3D
		if zone_body.global_position.y < -0.05 or zone_body.global_position.distance_to(body.global_position) > 3.0:
			in_bounds = false
	check(in_bounds, "all corpse zones settle on the floor within three metres")
	check(corpse.slept and corpse.settled and corpse.all_frozen(), "the settled corpse sleeps and then freezes instead of simulating forever")

	body.reveal_organs(true)
	check((body.organ_parts.heart as Node3D).visible and body.zone_nearest((body.parts.head as Node3D).global_position) == "head", "ragdolled zones and X-ray anatomy still answer through the original rig")
	var arm_point := (body.parts.left_arm as Node3D).global_position
	body.hit_at(arm_point, 50.0, 12.0, "cut", Vector3.BACK)
	body.hit_at(arm_point, 50.0, 12.0, "cut", Vector3.BACK)
	check(body.severed.has("left_arm"), "a settled corpse can still be cut through hit_at")
	body.queue_free()
	corpse.queue_free()
	await get_tree().process_frame


func _test_opt_out_and_missing_limb() -> void:
	var old := _body("old_fall", false, 0.0)
	_kill(old)
	check(old.ragdoll_body == null and old.rotation.x < -0.5, "ragdoll false keeps the established authored collapse")
	old.queue_free()

	var amputee := _body("amputee", true)
	amputee.hit("right_arm", 44.0, 28.0, "cut", "", Vector3.RIGHT)
	amputee.hit("right_arm", 44.0, 28.0, "cut", "", Vector3.RIGHT)
	check(amputee.severed.has("right_arm"), "test setup removes the arm before death")
	_kill(amputee)
	check(amputee.ragdoll_body != null and not amputee.ragdoll_body.bodies.has("right_arm"), "ragdoll construction never reattaches a pre-severed limb")
	amputee.queue_free()
	amputee.ragdoll_body.queue_free()
