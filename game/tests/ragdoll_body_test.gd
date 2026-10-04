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
	await _test_impulse_regression()
	await _test_weight_classes()
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
	# The production sandbox owns every rig through a holder at +0.9 m, with
	# the rig offset back down by -0.9 m. Keeping that hierarchy in the proof
	# catches physics bodies that accidentally inherit their old holder twice.
	var holder := Node3D.new()
	holder.name = "%s_holder" % id
	holder.position.y = 0.9
	add_child(holder)
	var body := BaselineHuman.new()
	body.position.y = -0.9
	holder.add_child(body)
	body.build(id, {"gore": false, "ragdoll": ragdoll, "knockdown_travel": travel})
	return body


func _kill(body: BaselineHuman, direction := Vector3.LEFT, impulse := 4.0, attack_id := "") -> void:
	body.hit("head", 200.0, impulse, "puncture", "brain", direction, 1.0, null, null, attack_id)


func _translated_body(id: String) -> Dictionary:
	var holder := Node3D.new()
	holder.position = Vector3(0.0, 0.9, 0.0)
	add_child(holder)
	var body := BaselineHuman.new()
	holder.add_child(body)
	body.position = Vector3(0.0, -0.9, 0.0)
	body.build(id, {"gore": false, "ragdoll": true})
	await get_tree().physics_frame
	return {"holder": holder, "body": body}


func _test_impulse_regression() -> void:
	print("RAGDOLL BODY - translated holders never inject first-frame velocity")
	for impulse in [4.0, 10.0, 16.0, 30.0]:
		var fixture := await _translated_body("kick_regression_%d" % int(impulse))
		var body := fixture.body as BaselineHuman
		_kill(body, Vector3.RIGHT, impulse)
		var peak := 0.0
		for _step in 24:
			await get_tree().physics_frame
			var torso := body.ragdoll_body.bodies.get("torso") as RigidBody3D
			peak = maxf(peak, torso.linear_velocity.length())
		var expected_peak := minf(impulse, RagdollBody.MAX_KILLING_IMPULSE) * RagdollBody.BASE_IMPULSE_SPEED
		check(peak <= expected_peak + 0.4, "impulse %d stays near its capped authored speed (peak %.2f)" % [int(impulse), peak])
		(fixture.holder as Node).queue_free()
		body.ragdoll_body.queue_free()
		await get_tree().process_frame


func _test_weight_classes() -> void:
	print("RAGDOLL BODY - blow classes carry authored weight without skating")
	var cases := [
		{"attack": "light_1", "minimum": 0.0, "maximum": 0.5, "lift": false},
		{"attack": "heavy", "minimum": 0.8, "maximum": 1.5, "lift": false},
		{"attack": "charged_heavy", "minimum": 1.5, "maximum": 2.5, "lift": true},
	]
	for case in cases:
		var fixture := await _translated_body("weight_%s" % case.attack)
		var body := fixture.body as BaselineHuman
		var torso_part := body.parts.torso as Node3D
		var start := torso_part.global_position
		_kill(body, Vector3.RIGHT, 28.0, str(case.attack))
		check(body.ragdoll_body.attack_id == str(case.attack), "%s id reaches the corpse through BaselineHuman's last-hit record" % case.attack)
		var peak := 0.0
		var lifted := false
		var launched_torso := body.ragdoll_body.bodies.get("torso") as RigidBody3D
		var max_rise := maxf(0.0, launched_torso.global_position.y - start.y)
		lifted = max_rise > 0.04
		for _step in 190:
			await get_tree().physics_frame
			var torso := body.ragdoll_body.bodies.get("torso") as RigidBody3D
			for body_value in body.ragdoll_body.bodies.values():
				peak = maxf(peak, (body_value as RigidBody3D).linear_velocity.length())
			max_rise = maxf(max_rise, torso.global_position.y - start.y)
			lifted = lifted or max_rise > 0.04
		var travel := maxf(0.0, torso_part.global_position.x - start.x)
		check(travel >= float(case.minimum) and travel <= float(case.maximum), "%s kill travels %.2f m along the blow (%+.2f z fall offset) inside %.1f-%.1f m" % [case.attack, travel, torso_part.global_position.z - start.z, case.minimum, case.maximum])
		check(peak <= RagdollBody.MAX_BODY_SPEED + 0.01, "%s kill stays at or below %.1f m/s (peak %.2f)" % [case.attack, RagdollBody.MAX_BODY_SPEED, peak])
		if bool(case.lift):
			check(lifted, "poise-breaking heavy briefly lifts the corpse (rise %.2f m)" % max_rise)
		check(body.ragdoll_body.settled and body.ragdoll_body.all_frozen(), "%s corpse is at rest and frozen within three seconds" % case.attack)
		(fixture.holder as Node).queue_free()
		body.ragdoll_body.queue_free()
		await get_tree().process_frame


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
