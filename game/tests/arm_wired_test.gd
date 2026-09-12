extends Node

## AN1.2-AN1.6. `limb_momentum.gd` passed ten checks this morning and was
## attached to nothing, which is the exact failure this project keeps repeating.
## So this test does not re-check the physics — `limb_momentum_test.gd` owns
## that. It checks that the Hunt Grounds is actually driving it.

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
	for _settle in 60:
		await tree.process_frame

	var arm = hunt.get("arm")
	check(arm != null, "the hunt builds an arm")
	if arm == null:
		_report()
		return

	# ---- AN1.5: it is carrying whatever the player is holding.
	print("carrying %.2f kg at %.2f m reach" % [arm.mass, arm.reach])
	check(arm.mass > 0.0 and arm.reach > 0.0, "the arm is carrying a real weapon")

	# ---- AN1.2: turning throws it. Feed the hunt the same motion a mouse makes.
	# Through `apply_look`, not through a synthetic InputEventMouseMotion: the
	# hunt gates its mouse branch on MOUSE_MODE_CAPTURED, which a headless run
	# can never be, so feeding it events measured gravity sag and passed.
	var rest: Vector3 = arm.at
	for _frame in 8:
		hunt.call("apply_look", Vector2(90.0 * 0.0026, 0.0))
		await tree.physics_frame
	var thrown: float = (arm.at - arm.anchor).length()
	print("thrown %.4f m off the anchor" % thrown)
	check(thrown > 0.12, "turning the camera genuinely throws the weapon")
	check(arm.at != rest, "and the arm is genuinely being advanced")

	# ---- AN1.4: that swing is worth something, and it is recorded.
	var worth: float = arm.commitment()
	print("commitment after a hard turn: %.3f" % worth)
	check(worth > 0.15, "a hard turn is worth a real blow, not a rounding error")

	# ---- and a still hand is worth much less than a swung one.
	for _frame in 120:
		await tree.physics_frame
	var still: float = arm.commitment()
	print("commitment at rest: %.3f" % still)
	check(still < worth, "a still hand is worth less than a swung one")
	check((arm.at - arm.anchor).length() < 0.12, "and the weapon settles back to the hand")

	# ---- AN1.6: fatigue tracks stamina rather than being set by hand.
	hunt.set("stamina", 100.0)
	await tree.physics_frame
	var fresh: float = arm.fatigue
	hunt.set("stamina", 0.0)
	await tree.physics_frame
	var spent: float = arm.fatigue
	print("fatigue: fresh %.2f  spent %.2f" % [fresh, spent])
	check(fresh < 0.05, "a full player has a fresh arm")
	check(spent > 0.9, "an empty player has a spent one")

	# ---- AN1.3: the weapon model is posed off the arm, not off an animation.
	var arsenal = hunt.get("arsenal")
	if arsenal != null and arsenal.models.has(str(arsenal.current_id)):
		var model: Node3D = arsenal.models[str(arsenal.current_id)]
		check(model.has_meta("rest_position"), "the weapon model remembers where it rests")
		hunt.set("stamina", 100.0)
		var before: Vector3 = model.position
		for _frame in 6:
			hunt.call("apply_look", Vector2(-140.0 * 0.0026, 40.0 * 0.0024))
			await tree.physics_frame
		print("model moved %.4f m" % model.position.distance_to(before))
		check(model.position.distance_to(before) > 0.02, "the weapon is drawn where the arm put it")

	# ---- AN1.8: the old swing still owns damage until somebody says otherwise.
	check(hunt.get("momentum_damage") == false, "commitment does not reach damage yet, by design")

	_report()


func _report() -> void:
	if failures.is_empty():
		print("arm wiring: connected")
		get_tree().quit(0)
	else:
		print("arm wiring FAILURES: ", failures)
		get_tree().quit(1)
