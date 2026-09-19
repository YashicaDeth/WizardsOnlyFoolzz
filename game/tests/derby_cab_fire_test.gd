extends Node

## AF1.8/AF10.8. `_fire_from_cab()` now fires through the shared `Ballistics`
## system instead of resolving an instant raycast on the frame the trigger
## went down (the same rewrite AF1.1 gave the Hunt). That wiring was landed
## by an unreviewed, unrun rescue commit (`57f9242`) — this is the first time
## it is actually exercised rather than read by eye.
##
## Proves three things a raycast-on-the-spot could not: a round exists in
## `ballistics.rounds` on the physics frame after firing (nothing lands on
## the firing frame itself), it later reaches a real wrecker and reduces its
## `integrity` meta, and that landing is what raises the score — the same
## consequence chain `_damage_target()` already gives a ram.

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
	var derby: Node = load("res://rift_derby.tscn").instantiate()
	tree.root.add_child(derby)
	tree.current_scene = derby
	for _settle in 10:
		await tree.process_frame

	derby.set("round_state", "active")
	var targets: Array = derby.get("targets")
	check(targets.size() > 0, "the derby spawned at least one wrecker to shoot at")
	if targets.is_empty():
		tree.quit(1)
		return

	# A plumbing test, not an aiming test: freeze a wrecker directly in front
	# of the muzzle rather than reproduce the mouse-aim trig, so a miss here
	# can only mean the ballistics wiring is wrong.
	var target: Node3D = targets[0]
	var ai_driver := target.get_node_or_null("AIDriver")
	if ai_driver != null:
		ai_driver.set_physics_process(false)
	var camera: Camera3D = derby.get("camera")
	var forward := -camera.global_transform.basis.z
	target.global_position = camera.global_position + forward * 12.0
	target.set("linear_velocity", Vector3.ZERO)
	target.set("angular_velocity", Vector3.ZERO)
	derby.set("aim_yaw", 0.0)
	derby.set("aim_pitch", 0.0)
	derby.set("fire_cooldown", 0.0)

	var ballistics: Node = derby.get("ballistics")
	var before_integrity: int = int(target.get_meta("integrity", 100))
	var before_score: int = int(derby.get("score"))

	derby.call("_fire_from_cab")

	await tree.process_frame
	var rounds: Array = ballistics.get("rounds")
	check(rounds.size() > 0,
		"a round exists in flight the physics frame after firing, rather than resolving instantly")

	var landed := false
	for _wait in 30:
		await tree.process_frame
		if int(target.get_meta("integrity", before_integrity)) < before_integrity:
			landed = true
			break

	check(landed, "the cab round reached the wrecker and reduced its integrity")
	check(int(derby.get("score")) > before_score, "landing the shot raised the score")

	# AF1.8/AF10.8. The port from `gore_demo.gd` took `_on_round_hit()` but
	# originally dropped `_on_round_expired()` — a cab round fired at open
	# sky ran out of `Ballistics.MAX_RANGE` without ever reaching
	# `_on_cab_round_hit()`, leaking its muzzle position in `_cab_seen`
	# forever. Fired directly through `Ballistics` rather than through the
	# aim-clamped `_fire_from_cab()`, since the player's own pitch clamp
	# cannot point straight up. Real signal round trip: this is
	# `Ballistics.round_expired` actually firing and actually reaching
	# `_on_cab_round_expired()`, not the payload contract read by eye.
	var cab_seen: Dictionary = derby.get("_cab_seen")
	var serial: int = int(derby.get("_cab_shot_serial")) + 1
	derby.set("_cab_shot_serial", serial)
	var sky_muzzle: Vector3 = camera.global_position + Vector3.UP * 5.0
	cab_seen[serial] = sky_muzzle
	ballistics.call("fire", sky_muzzle, Vector3.UP, "pistol", 0.0, 1, "derby_player", {
		"source": "derby_cab",
		"shot": serial,
	})
	var expired := false
	for _wait in 240:
		await tree.process_frame
		if not (derby.get("_cab_seen") as Dictionary).has(serial):
			expired = true
			break
	var rounds_left_in_flight: Array = ballistics.get("rounds")
	print("sky round expired=%s rounds_in_flight=%d" % [str(expired), rounds_left_in_flight.size()])
	check(expired, "a cab round fired at open sky expires and clears its muzzle record rather than leaking it")

	if failures.is_empty():
		print("derby cab fire: fine")
		tree.quit(0)
	else:
		print("derby cab fire FAILURES: ", failures)
		tree.quit(1)
