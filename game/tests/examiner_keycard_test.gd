extends Node

## Job 6 (v0.1 "Escape"). Greg, 4 Oct: "I literally killed him, where is his
## key." Three worlds by default (each ~40 s of fight, so the gate's 200 s
## ceiling holds; pass --runs=10 for the full sweep), each on a fresh random
## seed (printed; pass --seed=N to replay one): out of the vat, his door down, a fight with a random mix of
## mouse clicks and pad buttons, weapons, angles, parries and step-outs. Every
## time: his head stays on until the fight is over, his card lies on his floor,
## the staff door is physically shut and says what it needs and where, the
## card goes into the inventory, the door takes it and opens, the cupboard
## behind pays out. Plus the parry rule, the desperate phase and the LimboAI
## tree making his choices when the plugin is present.

const VAT := preload("res://vat_chamber.tscn")
const RUNS := 3

var failures: Array[String] = []
var rng := RandomNumberGenerator.new()


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var fixed := -1
	var runs := RUNS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			fixed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--runs="):
			runs = maxi(1, int(arg.trim_prefix("--runs=")))
	_selector_rules()
	var seeder := RandomNumberGenerator.new()
	seeder.randomize()
	for run in (1 if fixed >= 0 else runs):
		var seed_value: int = fixed if fixed >= 0 else seeder.randi() % 1000000
		await _run(run, seed_value)
	print("EXAMINER_KEYCARD_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## The GDScript selector is the same tree as the LimboAI one, branch for branch.
func _selector_rules() -> void:
	check(ExaminerFight.decide({"reeling": true, "winding": true, "in_reach": true, "ready": true}) == "reel", "selector: reeling beats everything")
	check(ExaminerFight.decide({"winding": true, "in_reach": false}) == "windup", "selector: a started wind-up is finished")
	check(ExaminerFight.decide({"in_reach": true, "ready": true}) == "attack", "selector: in reach and rested, he strikes")
	check(ExaminerFight.decide({"in_reach": false, "ready": true}) == "close", "selector: out of reach, he closes")
	check(ExaminerFight.decide({"in_reach": true, "ready": false}) == "circle", "selector: in reach but resting, he circles")
	if ClassDB.class_exists("BehaviorTree"):
		var tree := ExaminerFight.build_tree()
		check(tree != null and tree.call("get_root_task") != null and int(tree.call("get_root_task").call("get_child_count")) == 5, "LimboAI: his tree has the five branches")
	else:
		print("NOTE LimboAI not on disk here: the GDScript selector drives him")


func _stand_up(vat) -> void:
	vat.intake._finish_filing()
	await get_tree().process_frame
	vat.departure_clock = vat.DEPARTURE_SECONDS
	vat._update_departure(0.0)
	vat.clock = vat.DRAINED_AT
	vat.phase = "voiding"
	vat._update_sequence(0.05)
	while not vat.umbilicals.is_empty():
		for _tug in vat.WIRE_TUGS:
			vat._tug_wire(vat.umbilicals[0])
	vat._physics_process(vat.REVENGE_HOLD + 0.1)
	preload("res://systems/clothing.gd").wear("player", "scavenged_coat")
	for _step in 80:
		if vat.can_move:
			break
		vat._physics_process(0.1)
	await get_tree().physics_frame


func _place(vat, at: Vector3, look_at_point: Vector3) -> void:
	vat.player.global_position = Vector3(at.x, vat.BODY_HALF_HEIGHT + 0.02, at.z)
	vat.player.velocity = Vector3.ZERO
	var to := look_at_point - at
	vat.yaw = atan2(-to.x, -to.z)
	vat.pitch = 0.0
	vat.player.rotation.y = vat.yaw
	vat.camera.rotation = Vector3.ZERO


## One press through the real input path: mouse/keyboard or the pad.
func _press(vat, action: String, pad: bool) -> void:
	var event: InputEvent
	if pad:
		var button := InputEventJoypadButton.new()
		button.button_index = {"attack": JOY_BUTTON_RIGHT_SHOULDER, "interact": JOY_BUTTON_X}.get(action, JOY_BUTTON_RIGHT_SHOULDER)
		button.pressed = true
		event = button
		if action == "parry":
			var trigger := InputEventJoypadMotion.new()
			trigger.axis = JOY_AXIS_TRIGGER_LEFT
			trigger.axis_value = 1.0
			event = trigger
	else:
		match action:
			"attack":
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				click.pressed = true
				event = click
			_:
				var key := InputEventKey.new()
				key.keycode = KEY_X if action == "parry" else KEY_E
				key.physical_keycode = key.keycode
				key.pressed = true
				event = key
	vat._unhandled_input(event)


func _head_on(fight) -> bool:
	var body: BaselineHuman = fight.body
	var head := body.parts.get("head") as Node3D
	var torso := body.parts.get("torso") as Node3D
	if body.severed.has("head") or head == null or torso == null or not is_instance_valid(head) or not head.is_visible_in_tree():
		return false
	return head.global_position.distance_to(torso.global_position) < 0.9


## A ray along x at height y and depth z, from the Growing Floor into the artery.
func _blocked_at(vat, z: float, y := 1.0) -> bool:
	var space: PhysicsDirectSpaceState3D = vat.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(6.6, y, z), Vector3(9.0, y, z))
	query.exclude = [vat.player.get_rid()]
	var hit := space.intersect_ray(query)
	return not hit.is_empty() and float((hit.position as Vector3).x) < 8.2


func _run(run: int, seed_value: int) -> void:
	print("--- run %d seed=%d ---" % [run + 1, seed_value])
	rng.seed = seed_value
	WorldHistory.clear_history()
	var vat = VAT.instantiate()
	add_child(vat)
	await get_tree().process_frame
	await _stand_up(vat)
	var route = vat.doctor_route
	var fight: ExaminerFight = route.fight
	var tag := "[seed %d] " % seed_value
	check(vat.can_move and fight != null and fight.state == "idle", tag + "standing, he is at his bench")

	# The door before: shut, physical, and it names the card and where he is.
	_place(vat, vat.STAFF_DOOR_AT + Vector3(-1.2, 0, 0), vat.STAFF_DOOR_AT)
	await get_tree().physics_frame
	check(_blocked_at(vat, -4.1) and _blocked_at(vat, -3.0) and _blocked_at(vat, -1.9), tag + "the shut staff door seals the whole opening")
	vat._update_hud()
	var sealed_prompt: String = vat.prompt.text
	check(sealed_prompt.contains("NEEDS HIS STAFF KEYCARD") and sealed_prompt.contains("HIS OFFICE"), tag + "the door names the card and where it is (%s)" % sealed_prompt.replace("\n", " / "))
	_press(vat, "interact", rng.randf() < 0.5)
	check(not vat.staff_door_open, tag + "and use does not open it without the card")

	if rng.randf() < 0.7:
		route._take_axe()
	route.door.hit("axe", route.DOOR_AT + Vector3(0, 1.2, 0), Vector3(0, 0, 1))
	var blows := 0
	while not route.door.broken and blows < 80:
		route.door.hit("axe", route.DOOR_AT + Vector3(0, 1.2, 0), Vector3(0, 0, 1))
		blows += 1
	await get_tree().physics_frame

	_place(vat, fight.global_position + Vector3(1.8, 0, 0), fight.global_position)
	for i in 160:
		await get_tree().physics_frame
		if fight.state == "fighting":
			break
	check(fight.state == "fighting", tag + "he turns and comes at you")

	# The fight. The test keeps your blood up: this is about his death and his
	# card. The bot walks at the player's pace (no teleporting onto him), so his
	# backsteps and spacing count, and swings on every weapon cooldown.
	var head_ok := true
	var early_down := false
	var frames := 0
	var side := 1.0
	# Job 6 raised him to ~nine cleaver blows; bare-handed (the 30% of seeds
	# that skip the axe) that is ~29 blows, which never fit in 3000 frames.
	var budget := 3000 if str(route.call("held_weapon")) == "axe" else 9000
	while fight.state == "fighting" and frames < budget:
		frames += 1
		vat.anatomy.blood_remaining = vat.anatomy.blood_capacity
		vat.anatomy.dead = false
		vat.anatomy.downed = false
		var angle := rng.randf_range(-0.6, 0.6) + (PI if side < 0.0 else 0.0)
		var offset := Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(0.9, 1.6)
		var here: Vector3 = vat.player.global_position
		var goal := fight.global_position + offset
		goal.y = here.y
		_place(vat, here.move_toward(goal, 3.5 / 60.0) if here.distance_to(goal) < 6.0 else goal, fight.global_position + Vector3(0, 1.2, 0))
		if frames % 9 == 0:
			side = -side if rng.randf() < 0.2 else side
			if rng.randf() < 0.04:
				# Step out a moment: he goes home, then you come back.
				vat.player.global_position = route.DOOR_AT + Vector3(0, vat.player.global_position.y, -1.4)
			else:
				if fight.winding != "" and rng.randf() < 0.35:
					_press(vat, "parry", rng.randf() < 0.5)
				_press(vat, "attack", rng.randf() < 0.5)
		await get_tree().physics_frame
		if fight.state == "fighting":
			head_ok = head_ok and _head_on(fight)
			early_down = early_down or bool(fight.body.anatomy.get("dead")) or bool(fight.body.anatomy.get("downed"))
	check(fight.state == "won", tag + "he goes down (%d frames, %d blows, %d telegraphs, %d parries, %s, %.0f left)" % [frames, fight.hits_landed, fight.telegraphs, fight.parries, str(route.call("held_weapon")), fight.health])
	check(head_ok, tag + "his head stays on through the fight (no mesh break, no early sever)")
	check(not early_down, tag + "his rig never drops before the fight is won")
	check(fight.phase == 2 and WorldHistory.event_count("examiner_fight_phase") == 1, tag + "he turned desperate under half health")
	check(fight.telegraphs >= 3, tag + "he fought back: %d telegraphed blows" % fight.telegraphs)
	# Greg: "hit him twice... he's dead". Even perfect parries and a bot that
	# never stops swinging need six blows and four seconds; a human, more.
	check(fight.hits_landed >= 6 and frames > 60 * 4, tag + "no quick kill: %d blows over %.1f s" % [fight.hits_landed, frames / 60.0])
	if ClassDB.class_exists("BehaviorTree"):
		check(fight.brain != null and fight.tree_choices > 0, tag + "the LimboAI tree made his choices (%d)" % fight.tree_choices)

	# The card: on the floor, visible, in his room, not yet yours.
	check(fight.keycard_on_floor() and fight.keycard_pickup.is_visible_in_tree(), tag + "his keycard lies on the floor as a pickup")
	var card_at: Vector3 = fight.keycard_pickup.global_position if fight.keycard_on_floor() else Vector3.INF
	check(card_at.y < 0.1 and route.ROOM_X.x < card_at.x and card_at.x < route.ROOM_X.y and route.ROOM_Z.x < card_at.z and card_at.z < route.ROOM_Z.y, tag + "on his office floor (%s)" % str(card_at))
	if not fight.keycard_on_floor():
		vat.queue_free()
		await get_tree().physics_frame
		return
	# Stand back from it: the door now says where the card is.
	_place(vat, vat.STAFF_DOOR_AT + Vector3(-1.2, 0, 0), vat.STAFF_DOOR_AT)
	vat._update_hud()
	check(not ExaminerFight.has_keycard() and str(vat.prompt.text).contains("OFFICE FLOOR"), tag + "until taken, the door points at his office floor")
	# Take it: by use (E or Square), from a step away.
	_place(vat, card_at + Vector3(rng.randf_range(-1.0, 1.0), 0, rng.randf_range(0.8, 1.2)).limit_length(1.3), card_at)
	await get_tree().physics_frame
	vat._update_hud()
	check(str(vat.prompt.text).contains("TAKE HIS STAFF KEYCARD"), tag + "the prompt offers his keycard (%s)" % vat.prompt.text)
	_press(vat, "interact", rng.randf() < 0.5)
	check(ExaminerFight.has_keycard() and VatRebirth.carries(fight.KEYCARD), tag + "his keycard is in your inventory")
	check(not fight.keycard_on_floor(), tag + "and gone from the floor")

	# The door takes it.
	_place(vat, vat.STAFF_DOOR_AT + Vector3(-1.2, 0, 0), vat.STAFF_DOOR_AT)
	vat._update_hud()
	check(str(vat.prompt.text).contains("OPEN THE STAFF DOOR"), tag + "at the door, the card is offered")
	_press(vat, "interact", rng.randf() < 0.5)
	check(vat.staff_door_open and WorldHistory.event_count("staff_door_opened") == 1, tag + "the staff door opens")
	for i in 70:
		await get_tree().physics_frame
	check(not _blocked_at(vat, -3.0) and not _blocked_at(vat, -2.0), tag + "and the way into the artery is clear")
	# The cupboard behind it.
	var meds_before := FieldMeds.count()
	var cupboard: Vector3 = vat._staff_cupboard_at()
	_place(vat, cupboard + Vector3(0, 0, -1.0), cupboard)
	vat._update_hud()
	check(str(vat.prompt.text).contains("HIS CUPBOARD"), tag + "his cupboard is offered past the door")
	_press(vat, "interact", rng.randf() < 0.5)
	check(FieldMeds.count() == meds_before + 2, tag + "his cupboard: two field dressings")
	var rounds := 0
	for entry in WorldHistory.subject("inventory").get("items", []):
		rounds += int((entry as Dictionary).get("rounds", 0)) if entry is Dictionary else 0
	check(rounds >= 8, tag + "and ammunition (%d rounds)" % rounds)

	# The parry rule, on this seed's world: put him back up and wind a cut.
	_parry_rule(vat, fight, tag)
	vat.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame


func _parry_rule(vat, fight: ExaminerFight, tag: String) -> void:
	fight.state = "fighting"
	fight.health = ExaminerFight.HEALTH
	fight.phase = 1
	fight.parried_left = 0.0
	fight.stagger_left = 0.0
	fight.attacks_made = 0
	fight.attack_clock = 0.0
	var taken := fight.hits_taken
	fight._begin_attack()
	check(fight.winding == "scalpel" and fight._glint != null and fight._glint.visible, tag + "a scalpel wind-up glints")
	fight.player_parry()
	fight._land("scalpel", 1.0)
	fight._cancel_windup()
	check(fight.parried_left > 0.0 and fight.hits_taken == taken, tag + "a parried scalpel does no harm and leaves him open")
	var before := fight.health
	_place(vat, fight.global_position + Vector3(1.0, 0, 0), fight.global_position + Vector3(0, 1.2, 0))
	vat.doctor_route.cooldown = 0.0
	fight.player_strike("axe")
	check(is_equal_approx(before - fight.health, ExaminerFight.DAMAGE["axe"] * ExaminerFight.RIPOSTE), tag + "the riposte bites double (%.0f)" % (before - fight.health))
	fight.parried_left = 0.0
	fight.player_parry()
	fight._land("syringe", 1.0)
	check(fight.hits_taken == taken + 1 and fight.parried_left == 0.0, tag + "the syringe cannot be parried")
	fight.state = "won"
