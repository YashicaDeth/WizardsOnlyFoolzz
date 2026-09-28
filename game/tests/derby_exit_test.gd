extends Node

## AG1.6. The first playtester reported the game dying after the derby heat
## ended. Every existing derby test sets `leaving = true` in its first lines to
## stop the scene swap freeing the harness mid-await — which means the exit path
## the player actually takes has never once been run by a test. This runs it.
##
## The node keeps itself out of `current_scene` so the swap does not take it
## with the derby, and then watches what arrives.

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
	# The root is still setting up its own children while `_ready` runs, so the
	# harness waits a frame before parenting anything under it.
	await tree.process_frame
	# Step out of the way of the scene swap. `change_scene_to_packed` frees
	# whatever `current_scene` points at, so this harness hands that title to
	# the derby and sits beside it under the root.
	var derby: Node = load("res://rift_derby.tscn").instantiate()
	tree.root.add_child(derby)
	tree.current_scene = derby
	await tree.physics_frame
	await tree.physics_frame
	check(is_instance_valid(derby), "derby stands up")

	# Leaving an idle arena proves nothing. A player reaches the end of a heat
	# with panels shed off every car, loose debris still settling, bodies on the
	# ground and a pit full of trimesh collision — and it is tearing *that* down
	# that would kill the game if anything does. So run a heat first.
	derby.round_state = "active"
	var heat := 0.0
	var step := 1.0 / float(Engine.physics_ticks_per_second)
	while heat < 35.0 and is_instance_valid(derby) and derby.round_state == "active":
		await tree.physics_frame
		heat += step
		# Drive it the way a player does — through the actions `_update_boat`
		# actually reads, not by writing the body's fields behind its back.
		Input.action_press("move_forward", 1.0)
		if fmod(heat, 6.0) < 3.0:
			Input.action_press("move_right", 1.0)
			Input.action_release("move_left")
		else:
			Input.action_press("move_left", 1.0)
			Input.action_release("move_right")
	Input.action_release("move_forward")
	Input.action_release("move_left")
	Input.action_release("move_right")
	check(is_instance_valid(derby), "the derby survives a heat")
	var shed := 0
	for wrecker in derby.targets:
		if is_instance_valid(wrecker):
			shed += (wrecker.get_meta("detached_parts", []) as Array).size()
	shed += (derby.boat.get_meta("detached_parts", []) as Array).size()
	print("panels shed during the heat: ", shed, " // score ", derby.score, " // disabled ", derby.disabled_count)
	# `_detach_vehicle_part` hangs a 14 second SceneTree timer on a node the swap
	# is about to free, and a SceneTree timer outlives the scene that made it.
	# Make sure at least one is outstanding when we leave.
	derby._detach_vehicle_part(derby.boat, "DoorLeft", Vector3(0, 0, -1))
	derby._detach_vehicle_part(derby.boat, "Hood", Vector3(0, 0, -1))
	await tree.physics_frame

	# Win it the way the game ends a heat: eight wreckers actually disabled,
	# each one spawning debris and viscera and queueing a respawn, with the
	# eighth calling `_finish_round` itself.
	var guard := 0
	while derby.disabled_count < 8 and guard < 400:
		guard += 1
		await tree.physics_frame
		if derby.targets.is_empty():
			continue
		derby._wreck_target(derby.targets[0], 40)
		for _hold in 12:
			await tree.physics_frame
	check(derby.disabled_count >= 8, "eight wreckers go down")
	# Either ending leaves through the same door. Thirty-five seconds of being
	# rammed will often finish the player first, and that is a heat ending too.
	print("the heat ended: ", derby.round_state, " // integrity ", derby.integrity)
	check(derby.round_state in ["won", "lost"], "the heat finishes on its own")

	# Run the five second result countdown out in real frames, exactly as a
	# player waiting at the end of a heat does.
	var waited := 0.0
	while waited < 9.0 and is_instance_valid(derby) and not derby.leaving:
		await tree.physics_frame
		waited += 1.0 / float(Engine.physics_ticks_per_second)
	check(waited < 9.0, "the countdown hands over on its own")

	# The swap itself, plus the interstitial's minimum hold and fades.
	var arrived := false
	var elapsed := 0.0
	while elapsed < 30.0:
		await tree.process_frame
		elapsed += tree.root.get_process_delta_time()
		var current := tree.current_scene
		if current != null and is_instance_valid(current) and current != derby:
			arrived = true
			break
	check(arrived, "the hunt grounds arrive")
	if not arrived:
		_report()
		return

	check(not is_instance_valid(derby) or derby.is_queued_for_deletion(), "the derby is gone")
	var hunt := tree.current_scene
	# Greg, 24 September: the derby comes out through the old tunnels at the
	# dry blood waterfall, not straight into the Hunt. The tunnels come first.
	check(hunt.scene_file_path == "res://derby_tunnels.tscn", "we come out into the old tunnels, not somewhere else")

	# Now keep running. A crash on the far side of a scene swap is usually a
	# stale reference firing a frame or two later, and the 14 second detach
	# timers are still out there.
	var ran := 0.0
	while ran < 16.0:
		await tree.physics_frame
		ran += 1.0 / float(Engine.physics_ticks_per_second)
		if not is_instance_valid(hunt):
			break
	check(is_instance_valid(hunt), "the hunt grounds are still standing sixteen seconds later")
	var out := OS.get_environment("ATG_EXIT_SHOT")
	if out != "" and is_instance_valid(hunt):
		await tree.process_frame
		var shot := tree.root.get_texture().get_image()
		shot.save_png(out)
		print("shot: ", out)
	check(not Interstitial.travelling, "the loading plate let go")
	_report()


func _report() -> void:
	if failures.is_empty():
		print("derby exit: clean")
		get_tree().quit(0)
	else:
		print("derby exit FAILURES: ", failures)
		get_tree().quit(1)
