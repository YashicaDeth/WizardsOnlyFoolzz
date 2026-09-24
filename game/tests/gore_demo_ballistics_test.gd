extends Node

## "the guns dont have bullets that come out hit the models and destroy there
## bodys bullet by bullet" — Greg, about this scene.
##
## He was right, and the reason was written down in `gore_demo.gd` itself: the
## round that left the barrel was labelled *cosmetic only*, and the damage was a
## separate instant raycast resolved on the frame the trigger went down. Two
## disconnected halves of one shot, and the half you could see was the one that
## did nothing.
##
## What this test proves, in the order the complaint makes:
##
## 1. Pulling the trigger spends a round and puts one in the air, and **does not
##    touch the body** on that frame. This is the check that would have caught
##    the old code, and it is the one `gore_demo_test.gd` had backwards — it
##    asserted damage *immediately*, which is precisely the bug.
## 2. The round travels: it exists between frames, it is somewhere different
##    each frame, and it covers real metres.
## 3. Damage lands when the round arrives, on a real anatomy zone, as a
##    recorded wound rather than a mark stamped on a surface.
## 4. A magazine emptied into one body takes it apart in stages. Each round is
##    resolved on its own frame against the body as it stands at that moment,
##    which is the difference between bullet-by-bullet and one lump.
## 5. A round that belongs to somebody else is not this scene's to resolve.
##
## The test drives the real scene rather than a rig built here, because every
## one of those is a property of how `gore_demo.gd` is wired to `Ballistics`,
## and a stand-in would prove the wiring of the stand-in.

const DEMO := preload("res://gore_demo.tscn")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func total_health(rig: BaselineHuman) -> float:
	var total := 0.0
	for zone: String in BaselineHuman.ZONES:
		total += rig.zone_health(zone)
	return total


## Point the sandbox's eye at a body from a stated distance, dead level with
## whichever of its own parts is named. Aim is computed out of the rig's real
## world positions so a change to the proportions cannot leave this quietly
## shooting past.
func aim_at(demo, rig: BaselineHuman, zone: String, distance: float) -> void:
	var target: Vector3 = (rig.parts.get(zone) as Node3D).global_position
	# Stand off along +Z from the target and look back down the line.
	demo.eye = target + Vector3(0.0, 0.0, distance)
	demo.eye.y = target.y
	var to_target := target - demo.eye
	demo.yaw = atan2(-to_target.x, -to_target.z)
	demo.pitch = atan2(to_target.y, Vector2(to_target.x, to_target.z).length())
	demo.camera.global_position = demo.eye
	demo.camera.global_transform.basis = Basis(Vector3.UP, demo.yaw) * Basis(Vector3.RIGHT, demo.pitch)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var tree := get_tree()
	# Ignores the scene clock, because the scene under test bends it on purpose.
	tree.create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		print("gore demo ballistics: TIMED OUT")
		tree.quit(3))
	await tree.process_frame

	var demo = DEMO.instantiate()
	tree.root.add_child(demo)
	tree.current_scene = demo
	# The sandbox grabs the mouse on the way in, which is rude when a script
	# opened it.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await tree.physics_frame
	await tree.physics_frame

	var rig := (demo.bodies[0] as Dictionary)["rig"] as BaselineHuman
	check(rig != null and is_instance_valid(rig), "there is a body to shoot")

	# ---------------------------------------------------------------- 1. the trigger
	# Far enough that the round cannot possibly arrive on the frame it is fired:
	# a pistol round covers about 5.6m in one physics step, so twenty metres is
	# three or four frames of genuine flight.
	aim_at(demo, rig, "torso", 20.0)
	await tree.physics_frame

	var health_before := total_health(rig)
	var wounds_before: int = rig.anatomy.wounds.size()
	var spent_before: int = demo.spent
	var brass_before: int = demo.ballistics.casings.size()
	demo._fire()

	check(demo.spent == spent_before + 1, "pulling the trigger spends a round")
	check(demo.ballistics.casings.size() == brass_before + 1, "and throws one case — the brass Greg likes is still there")
	check(demo._rounds_in_flight() == 1, "and puts exactly one real round in the air")
	check(is_equal_approx(total_health(rig), health_before),
		"the body is untouched on the frame the trigger goes down")
	check(rig.anatomy.wounds.size() == wounds_before,
		"and has taken no wound yet — nothing is resolved at the muzzle")

	# ---------------------------------------------------------------- 2. it travels
	var track: Array[Vector3] = []
	var travelled := 0.0
	for _step in 10:
		await tree.physics_frame
		if demo._rounds_in_flight() == 0:
			break
		for round_data: Dictionary in demo.ballistics.rounds:
			var payload: Dictionary = round_data.get("payload", {})
			if str(payload.get("source", "")) == demo.SHOT_SOURCE:
				track.append(round_data["at"])
				travelled = float(round_data["travelled"])
	print("round seen at %d positions, %.2f m of flight" % [track.size(), travelled])
	check(track.size() >= 2, "the round exists across several frames rather than one")
	if track.size() >= 2:
		check(track[0].distance_to(track[track.size() - 1]) > 4.0,
			"and is somewhere different each time it is looked at")
	check(travelled > 4.0, "it covers real metres before it gets anywhere")
	check(is_equal_approx(total_health(rig), health_before),
		"and the body is still untouched while the round is in the air")

	# ---------------------------------------------------------------- 3. it arrives
	var waited := 0
	while is_equal_approx(total_health(rig), health_before) and waited < 60:
		await tree.physics_frame
		waited += 1
	check(total_health(rig) < health_before, "damage lands when the round arrives")
	check(rig.anatomy.wounds.size() > wounds_before,
		"and lands as a wound on the anatomy, not a mark on a surface")
	var wound: Dictionary = rig.anatomy.wounds.back()
	check(BaselineHuman.ZONES.has(str(wound.get("zone", ""))),
		"on a real zone (%s)" % str(wound.get("zone", "")))
	check(str(wound.get("type", "")) == "ballistic",
		"recorded as ballistic (%s)" % str(wound.get("type", "")))
	check(demo._rounds_in_flight() == 0, "and the round is gone once it has arrived")

	# ---------------------------------------------------------------- 4. bullet by bullet
	# A second body, a magazine into one zone, one round at a time. The zone has
	# to come apart in stages: each round is resolved against the body as it
	# stands on the frame that round lands.
	var victim := (demo.bodies[2] as Dictionary)["rig"] as BaselineHuman
	aim_at(demo, victim, "left_arm", 14.0)
	await tree.physics_frame
	var ladder: Array[float] = [victim.zone_health("left_arm")]
	var severed_at := -1
	for shot in 9:
		demo._fire()
		var settled := 0
		while demo._rounds_in_flight() > 0 and settled < 30:
			await tree.physics_frame
			settled += 1
		ladder.append(victim.zone_health("left_arm"))
		if severed_at < 0 and victim.severed.has("left_arm"):
			severed_at = shot + 1
	print("left arm health after each round: ", ladder)
	print("arm came off on round: ", severed_at)

	var steps_down := 0
	for index in range(1, ladder.size()):
		if ladder[index] < ladder[index - 1]:
			steps_down += 1
	check(steps_down >= 3, "the same zone is cut down in separate steps, not one (%d steps)" % steps_down)
	check(ladder[ladder.size() - 1] < ladder[0], "and ends lower than it started")
	check(severed_at > 1, "the arm comes off to an accumulated ladder of rounds, not the first one")
	check(victim.severed.has("left_arm"), "and it does come off")
	check(demo.severed_total > 0, "the room counts what it took off")

	# ---------------------------------------------------------------- 5. not ours
	# `Ballistics` is shared and the Hunt fires through one too. A round with
	# somebody else's payload — or none — must not be resolved here.
	var bystander := (demo.bodies[4] as Dictionary)["rig"] as BaselineHuman
	var bystander_before := total_health(bystander)
	var chest: Vector3 = (bystander.parts.get("torso") as Node3D).global_position
	var from := chest + Vector3(0.0, 0.0, 9.0)
	demo.ballistics.fire(from, (chest - from).normalized(), "pistol", 0.0, 1, "somebody_else", {"source": "bone_yard_hunt", "shot_id": 1})
	for _step in 20:
		await tree.physics_frame
	check(is_equal_approx(total_health(bystander), bystander_before),
		"a round that is not this scene's is not this scene's to resolve")

	# ---------------------------------------------------------------- presentation
	# The visible half. A round that travels and cannot be seen reads to a
	# player as no bullet at all.
	check(demo.view_gear != null and is_instance_valid(demo.view_gear),
		"there is a gun in your hands")
	check(demo.view_gear.weapon != null and demo.view_gear.get_child_count() > 0,
		"and it is a built weapon with hands on it")
	demo._update_view_forearms()
	var right_forearm := demo.view_gear.right_hand.get_node_or_null("FirstPersonForearm") as Node3D
	var left_forearm := demo.view_gear.left_hand.get_node_or_null("FirstPersonForearm") as Node3D
	check(right_forearm != null and left_forearm != null and right_forearm.top_level and left_forearm.top_level,
		"both viewmodel hands continue into first-person forearms")
	var right_sleeve := right_forearm.get_node_or_null("TaperedSleeve") as MeshInstance3D
	check(right_sleeve != null and (right_sleeve.mesh as CylinderMesh).height > 0.08,
		"the visible sleeve stretches from the screen edge to the live wrist")
	check(demo.muzzle_point != null and demo.view_gear.is_ancestor_of(demo.view_gear.weapon),
		"with a muzzle to flash from")
	aim_at(demo, (demo.bodies[5] as Dictionary)["rig"] as BaselineHuman, "torso", 20.0)
	await tree.physics_frame
	for index in range(demo._tracers.size() - 1, -1, -1):
		demo._retire_tracer(index)
	demo._fire()
	check(demo._flash_life > 0.0, "the barrel flashes on the frame the trigger goes down")
	check(demo._gear_recoil > 0.0, "and the gun goes back into the frame")
	await tree.physics_frame
	await tree.physics_frame
	var streaks: int = demo._tracers.size()
	print("tracer segments after two frames of flight: ", streaks)
	check(streaks > 0, "the round draws a visible streak along the path it actually took")
	var longest := 0.0
	for streak: Dictionary in demo._tracers:
		var node := streak["node"] as MeshInstance3D
		longest = maxf(longest, (node.mesh as BoxMesh).size.z)
	print("longest streak: %.2f m" % longest)
	check(longest > 1.0, "and the streak is metres long, not a 16cm box nobody will ever see")

	# ---- and it does not grow without bound while somebody empties a magazine.
	for _volley in 30:
		demo._fire()
		await tree.physics_frame
	check(demo._tracers.size() <= demo.MAX_TRACERS, "tracers are capped")
	check(demo._seen.size() <= demo.MAX_TRACERS, "and nothing is left holding dead rounds")

	tree.current_scene = null
	demo.free()
	Engine.time_scale = 1.0

	if failures.is_empty():
		print("gore demo ballistics: the bullet is the thing that does the damage")
		tree.quit(0)
	else:
		print("gore demo ballistics FAILURES: ", failures)
		tree.quit(1)
