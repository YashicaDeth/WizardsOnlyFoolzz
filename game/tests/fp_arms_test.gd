extends Node

## imp-64: the first-person arms carry the held weapon in the mechanics lab.
## A light swing moves the hand through wind-up, strike and recovery and
## brings it home; the hand stays on the grip throughout; block, parry, a
## blow taken, reload and inspect each change the pose; bare hands punch;
## the swing whooshes and the hit is voiced by what it met.

var failures: Array[String] = []
var lab: Node3D


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	BloodPool.clear()
	lab = load("res://lab/mechanics_lab.tscn").instantiate()
	add_child(lab)
	await _frames(3)
	var arms := lab.held_mount as FirstPersonArms
	check(arms != null and arms.get_parent() == lab.camera, "the arms hang off the eye")
	check(arms.held.get_node_or_null("RightGripHand") != null and arms.left_hand != null, "the cleaver is in a gloved right hand, the left hand free")
	check(arms.find_child("heat_edge", true, false) != null, "the heated edge is on the held cleaver")

	# A light swing into open air.
	lab.player.global_position = Vector3(0, 1.0, 17.0)
	lab.yaw = PI
	await _frames(4)
	# Sample the rest only once the arms have posed a frame.
	await get_tree().process_frame
	await get_tree().process_frame
	var rest := arms.held.position
	var phases := {}
	var furthest := 0.0
	var off_grip := 0.0
	var whooshes: int = lab.melee.audio.whooshes
	lab.melee.press_light()
	for _frame in 50:
		await get_tree().process_frame
		phases[arms.last_phase] = true
		furthest = maxf(furthest, arms.held.position.distance_to(rest))
		off_grip = maxf(off_grip, _grip_gap(arms))
	check(phases.has("windup") and phases.has("active") and phases.has("recovery"), "the arm passes wind-up, strike and recovery (%s)" % str(phases.keys()))
	check(furthest > 0.12, "the hand really travels (%.2f m)" % furthest)
	check(off_grip < 0.02, "the hand stays seated on the grip (%.3f m)" % off_grip)
	await _seconds(0.5)
	check(arms.held.position.distance_to(rest) < 0.06, "and comes home after (%.3f m, %s)" % [arms.held.position.distance_to(rest), arms.last_phase])
	check(lab.melee.audio.whooshes == whooshes + 1, "one whoosh for the swing")

	lab.melee.set_guard(true)
	await _seconds(0.3)
	check(arms.last_phase == "block", "L1 raises the block")
	lab.melee.set_guard(false)
	await _seconds(0.3)
	lab.melee.press_parry()
	await _frames(2)
	check(arms.last_phase == "parry", "L2 flicks a parry")
	await _seconds(0.4)
	var before_blow := arms.held.position
	lab.melee.receive_blow(10.0)
	await _frames(2)
	check(arms.held.position.distance_to(before_blow) > 0.01, "a blow taken knocks the arms")
	arms.inspect()
	await _seconds(1.0)
	check(arms.last_phase == "inspect", "inspect turns the weapon over")
	await _seconds(1.6)

	# The hit is voiced by what it met.
	var rig: BaselineHuman = lab.bodies.rigs()[0]
	lab.player.global_position = rig.global_position + Vector3(0, 1.0, 1.4)
	await _frames(2)
	var to: Vector3 = rig.global_position + Vector3(0, 1.2, 0) - lab.camera.global_position
	lab.yaw = atan2(-to.x, -to.z)
	lab.pitch = atan2(to.y, Vector2(to.x, to.z).length())
	await _frames(3)
	lab.melee.press_light()
	await _seconds(0.8)
	check(int(lab.melee.audio.impacts.get("flesh", 0)) >= 1, "a cleaver into a body sounds as flesh (%s)" % str(lab.melee.audio.impacts))
	var pane := StaticBody3D.new()
	pane.name = "GlassPane"
	var plate := StaticBody3D.new()
	plate.set_meta("surface", "metal")
	add_child(pane)
	add_child(plate)
	check(FpCombatAudio.surface_of(pane) == "glass" and FpCombatAudio.surface_of(plate) == "metal" and FpCombatAudio.surface_of(self) == "concrete", "glass, metal and concrete are told apart")
	check(FpCombatAudio.surface_of(rig, {"heavy": true, "damage_type": "blunt"}) == "bone", "a heavy blunt blow to a body is bone")

	# Pistol: reload drops the magazine.
	lab.arsenal.select_weapon("sidearm")
	await _frames(3)
	check(arms.weapon_id == "sidearm" and arms.held.get_node_or_null("LeftGripHand") != null, "the pistol is held in both hands")
	var magazine := arms.held.find_child("magazine", true, false) as Node3D
	lab.arsenal.ammo["sidearm"]["loaded"] = 2
	check(lab.arsenal.reload(), "a reload starts")
	await _seconds(0.4)
	check(arms.last_phase == "reload" and magazine != null and magazine.position.y < -0.05, "the arms tip the pistol and the magazine drops")

	# Bare hands throw their own punches.
	arms.arsenal = null
	arms.driver = null
	arms.take("")
	await _frames(2)
	var fist_rest := arms.held.position
	check(arms.strike(), "a bare-handed jab starts")
	var reach := 0.0
	for _frame in 20:
		await get_tree().process_frame
		reach = maxf(reach, arms.held.position.distance_to(fist_rest))
	check(reach > 0.1, "the fist goes out (%.2f m)" % reach)
	check(arms._audio != null and arms._audio.whooshes == 1, "and whooshes without a driver behind it")

	# The Hunt issues the HOTLINE CLEAVER, not the old sword.
	var issued := HunterArsenal.new()
	check(issued.current_id == "cleaver" and HunterArsenal.SLOT_ORDER[0] == "cleaver" and not HunterArsenal.SLOT_ORDER.has("sword"), "the Hunt's issued blade is the cleaver")
	check(BloodTrees.starting_weapon("blade") == "cleaver", "a blade style walks into the Hunt holding it")
	issued.free()

	print("FP_ARMS_TEST_RESULT failures=%d" % failures.size())
	Engine.time_scale = 1.0
	get_tree().quit(1 if failures.size() > 0 else 0)


## How far the right hand has drifted off the weapon's grip anchor.
func _grip_gap(arms: FirstPersonArms) -> float:
	var hand := arms.held.get_node_or_null("RightGripHand") as Node3D
	var grip := arms.held.find_child("anchor_grip", true, false) as Node3D
	if hand == null or grip == null:
		return 1.0
	var seated: Vector3 = hand.get_meta("grip_rest_position", hand.position)
	return absf(hand.global_position.distance_to(grip.global_position) - (arms.held.global_transform * seated).distance_to(grip.global_position))


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().physics_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
