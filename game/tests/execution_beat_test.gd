extends Node

## Fix-58 (Greg, 5 Oct: "when someone is downed the execution is still super
## bugged"). In the mechanics lab, with each v0.1 weapon and on the pad: a
## downed sparring partner, R1 / LMB in reach, and the beat runs to the end:
## the player is placed and facing the body, the body is dead and on its
## ragdoll, time runs at 1 and the controls answer again. The lab-48 rip is the
## finisher only through a wound, and the lab never deletes a body under you.

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
	await _weapon("cleaver", false)
	await _weapon("staff", false)
	await _weapon("sidearm", false)
	await _weapon("cleaver", true)
	await _weapon("sidearm", true)
	await _rip()
	await _held_body()
	await _beat_alone()
	print("EXECUTION_BEAT_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## A fresh partner, put on the floor, the player 1.9 m off its front.
func _downed_partner() -> BaselineHuman:
	lab.sparring._spawn()
	await _frames(2)
	var rig: BaselineHuman = lab.sparring.rig
	rig.hit("left_leg", 30.0, 4.0, "cut")
	rig.anatomy.go_down()
	await _seconds(0.4)
	var holder: Node3D = lab.sparring.holder
	var front := -holder.global_basis.z
	front.y = 0.0
	lab.player.global_position = Vector3(holder.global_position.x, lab.player.global_position.y, holder.global_position.z) + front.normalized() * 1.9
	lab.player.velocity = Vector3.ZERO
	var to: Vector3 = rig.global_position - lab.player.global_position
	lab.yaw = atan2(-to.x, -to.z)
	lab.pitch = -0.3
	await _frames(2)
	return rig


func _weapon(id: String, pad: bool) -> void:
	lab.tool = ""
	lab.arsenal.select_weapon(id)
	await _frames(2)
	var rig := await _downed_partner()
	var tag := "%s%s" % [id, " (pad R1)" if pad else ""]
	check(rig.is_downed() and lab.downed_in_reach() == rig, "%s: the downed partner is in reach" % tag)
	check(lab._prompt.text.contains("EXECUTE"), "%s: the prompt offers EXECUTE (%s)" % [tag, lab._prompt.text])
	if pad:
		await _pad(JOY_BUTTON_RIGHT_SHOULDER)
	else:
		await _press("attack")
	check(lab.execution.active or rig.anatomy.dead, "%s: R1 / LMB starts the finisher" % tag)
	check(lab.execution.style_id == id, "%s: the finisher is the weapon's own (%s)" % [tag, lab.execution.style_id])
	# A second press mid-beat is swallowed, not a swing or a shot.
	var contacts_before: int = lab.melee.contacts
	await _press("attack")
	check(lab.melee.contacts == contacts_before, "%s: input under the beat does not start a swing" % tag)
	var waited := 0.0
	while lab.execution.active and waited < 4.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	check(not lab.execution.active, "%s: the beat ends by itself (%.2fs)" % [tag, waited])
	check(waited <= ExecutionBeat.DEADLINE + 0.2, "%s: inside the deadline" % tag)
	check(is_instance_valid(rig) and rig.anatomy.dead, "%s: the body is dead" % tag)
	check(str(lab.execution.report.get("reason", "")) == "done", "%s: it completed rather than timed out (%s)" % [tag, str(lab.execution.report.get("reason", ""))])
	var stand: float = Vector2(lab.player.global_position.x - lab.execution.stand_at.x, lab.player.global_position.z - lab.execution.stand_at.z).length()
	check(stand < 0.3, "%s: the player is at the finisher's spot (%.2f m off)" % [tag, stand])
	check(absf(wrapf(lab.yaw - lab.execution.view_yaw, -PI, PI)) < 0.35, "%s: the player faces the body" % tag)
	check(rig.rigged == null or rig.rigged.ragdolled or rig.ragdoll_body != null, "%s: the corpse goes to its ragdoll" % tag)
	check(is_equal_approx(Engine.time_scale, 1.0), "%s: time runs at 1 afterwards" % tag)
	if id == "cleaver":
		check(rig.severed.has("head"), "%s: the cleaver takes the head" % tag)
	elif id == "staff":
		check(not rig.anatomy.organ_ok("heart"), "%s: the staff goes through the heart" % tag)
	else:
		check(not rig.anatomy.organ_ok("brain"), "%s: the round goes through the brain" % tag)
	# The controls are yours again.
	var before: Vector3 = lab.player.global_position
	Input.action_press("move_right")
	await _seconds(0.3)
	Input.action_release("move_right")
	check(lab.player.global_position.distance_to(before) > 0.05, "%s: you can walk away afterwards" % tag)
	await _seconds(0.3)


## Lab-48: an open chest is the rip, and the heart comes out into your hand.
## A closed one never is.
func _rip() -> void:
	lab.arsenal.select_weapon("cleaver")
	var closed := await _downed_partner()
	check(ExecutionBeat.style_for(closed, "cleaver") == "cleaver", "rip: no wound, no hand in: the weapon finishes them")
	var rig := await _downed_partner()
	rig.mark_opened("torso", GoreChunks.Layer.ORGAN)
	await _frames(1)
	check(ExecutionBeat.style_for(rig, "cleaver") == "rip", "rip: a wound to the organs makes the heart the finisher")
	check(lab._prompt.text.contains("HEART"), "rip: the prompt says so (%s)" % lab._prompt.text)
	await _press("attack")
	var waited := 0.0
	while lab.execution.active and waited < 4.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	check(rig.anatomy.dead, "rip: the body is dead")
	check(bool((rig.anatomy.organs.get("heart", {}) as Dictionary).get("removed", false)), "rip: the heart is out of the body")
	check(str(lab.hand_item).to_lower().contains("heart"), "rip: and in your hand (%s)" % str(lab.hand_item))
	lab._drop_hand()


## A downed partner is not deleted under you while it waits, nor mid-beat.
func _held_body() -> void:
	lab.arsenal.select_weapon("staff")
	var rig := await _downed_partner()
	lab.sparring.dead_for = lab.sparring.RESPAWN_SECONDS + 1.0
	await _frames(2)
	check(is_instance_valid(rig) and lab.sparring.rig == rig, "the downed body outlasts the corpse timer")
	check(lab.execute_downed(), "and can still be finished")
	lab.sparring.dead_for = lab.sparring.DOWNED_SECONDS + 1.0
	await _frames(2)
	check(is_instance_valid(rig) and lab.sparring.rig == rig, "it is not respawned under the finisher")
	while lab.execution.active:
		await get_tree().physics_frame
	await _frames(2)
	check(is_instance_valid(rig) and lab.sparring.rig == rig, "the fresh corpse stays for its own timer")


## The beat on its own: a body freed mid-beat ends it; a standing body is refused.
func _beat_alone() -> void:
	var rig := await _downed_partner()
	var beat := ExecutionBeat.new()
	add_child(beat)
	var stand := Node3D.new()
	add_child(stand)
	stand.global_position = rig.global_position + Vector3(0, 0, 2)
	check(beat.begin(stand, rig, "cleaver"), "the beat starts on a downed body")
	check(not beat.begin(stand, rig, "cleaver"), "a second begin is refused while one runs")
	lab.sparring._spawn()
	await _frames(2)
	beat.step(0.016)
	check(not beat.active and str(beat.report.get("reason", "")) == "victim_gone", "a body freed mid-beat ends it at once")
	var standing: BaselineHuman = lab.sparring.rig
	check(not beat.begin(stand, standing, "cleaver"), "a standing body cannot be executed")
	beat.queue_free()
	stand.queue_free()


func _press(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	await get_tree().process_frame
	await _frames(1)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame
	await _frames(1)


func _pad(button: JoyButton) -> void:
	for down in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = 0
		event.button_index = button
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame
		await get_tree().process_frame
		await _frames(1)


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().physics_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
