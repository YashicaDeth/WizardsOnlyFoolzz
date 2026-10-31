extends Node

## The Mental and Physical Support Unit (Greg, 24 September): sneak past or
## break the cameras, trip the alarm and see what it does (brain chips, block
## tracking, the white X-ray flash, reinforcements who shoot), free a
## bingyanga, and get through Hollis's gate at the end. Everything recorded.

const UNIT := preload("res://support_unit.tscn")
const CARRY := preload("res://systems/carry.gd")
const STEP := 1.0 / 30.0

var failures: Array[String] = []
var unit


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _place(at: Vector3, yaw := 0.0, pitch := 0.0) -> void:
	unit.player.global_position = at
	unit.player.velocity = Vector3.ZERO
	unit.yaw = yaw
	unit.pitch = pitch
	unit.player.rotation.y = yaw
	unit.camera.rotation = Vector3(pitch, 0, 0)


## Yaw that looks from the player toward `at`.
func _yaw_to(at: Vector3) -> float:
	var to: Vector3 = at - unit.player.global_position
	return atan2(-to.x, -to.z)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person", "status": "loose"})
	var carry := CARRY.new()
	carry.items.append({"label": "BREACH TOOL", "kind": "tool", "mass": 4.0, "perishes": false, "age": 0.0, "from": "service_arcade"})
	carry.save_to_history()
	unit = UNIT.instantiate()
	add_child(unit)
	# The test drives the frame itself.
	unit.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame

	check(WorldHistory.event_count("support_unit_entered") == 1, "entering the unit is recorded")
	check(unit.cameras.size() == 3 and unit.cells.size() == 6 and unit.guards.size() == 2, "three cameras, six cells, two guards on their rounds")
	check(unit.holding_ram, "the breach tool carried in is in hand")
	check(unit.guard_post != null and unit.guard_post.position.z == unit.GATE_Z and not unit.guard_post.door_open, "Hollis's gate stands shut at the end of the hallways")
	var held := 0
	for bingyanger in unit.bingyangers:
		held += 1 if bingyanger.state == "held" else 0
	check(held == 6, "every cell holds a bingyanga")

	await _cameras()
	await _alarm()
	_bingyanga()
	_gate()
	_death()

	print("SUPPORT_UNIT_TEST_RESULT failures=", failures.size())
	unit.queue_free()
	get_tree().quit(0 if failures.is_empty() else 1)


func _cameras() -> void:
	var lens: SecurityCamera = unit.cameras[0]
	# Greg, 26 September: the signal is invisible unless a vision mode shows it.
	check(not lens.cone.visible and not lens.lamp.visible, "a camera's signal is invisible by default")
	SecurityCamera.show_signals(true)
	check(lens.cone.visible and lens.lamp.visible, "a vision mode shows its cone, drawn and lit")
	SecurityCamera.show_signals(false)
	check(not lens.cone.visible, "and hides it again")
	# Sweeping: the head's yaw is not the same a few seconds apart.
	lens.step(STEP, Vector3(0, -50, 0), unit.player)
	var before: float = lens.head.rotation.y
	for _frame in 60:
		lens.step(STEP, Vector3(0, -50, 0), unit.player)
	check(absf(lens.head.rotation.y - before) > 0.1, "the cone sweeps")
	# Sneaking: a pillar between you and the lens is cover.
	var open_point := Vector3(0.6, 1.35, -14.5)
	var hidden_point := Vector3(-2.2, 1.35, -11.9)
	lens.head.look_at(open_point)
	check(lens.sees(open_point), "in the open, in the cone, it sees you")
	lens.head.look_at(hidden_point)
	check(not lens.sees(hidden_point), "behind a pillar it does not")
	lens.head.look_at(open_point + Vector3(0, 0, 25))
	check(not lens.sees(open_point + Vector3(0, 0, 25)), "past its range it does not")
	# Sneak up beside it, outside the cone, and break it.
	_place(Vector3(-3.5, 1.0, -22.7))
	await get_tree().physics_frame
	lens.step(STEP, unit.player.global_position + Vector3(0, 0.35, 0), unit.player)
	check(lens.lock == 0.0, "standing beside the lens, outside its cone, is unseen")
	var to_lens: Vector3 = lens.eye() - unit.eye()
	_place(unit.player.global_position, _yaw_to(lens.eye()), atan2(to_lens.y, Vector2(to_lens.x, to_lens.z).length()))
	unit._update_hud()
	check(unit.prompt.text.contains("SMASH THE CAMERA"), "facing it, the prompt offers to smash it (%s)" % unit.prompt.text)
	var guard_level_before: String = unit.director.level
	check(unit.swing() == "camera", "one swing takes the camera")
	check(lens.broken and not lens.cone.visible and not lens.sees(Vector3(-2.2, 1.35, -14.0)), "a broken camera films nothing")
	check(WorldHistory.event_count("support_camera_broken") == 1 and str(WorldHistory.subject("support_camera_1").get("state", "")) == "broken", "breaking it is recorded on the camera")
	check(guard_level_before == "calm" and not unit.director.is_alarm(), "breaking one unseen is loud but is not the alarm")
	check(not bool(lens.hack().get("accepted", true)), "the hack hook is there and refuses until it is earned")


func _alarm() -> void:
	var lens: SecurityCamera = unit.cameras[1]
	# Out in the open in front of the second camera.
	_place(Vector3(1.0, 1.0, -44.5), PI)
	await get_tree().physics_frame
	var chest: Vector3 = unit.player.global_position + Vector3(0, 0.35, 0)
	lens.head.look_at(chest)
	var frames := 0
	while not unit.director.is_alarm() and frames < 120:
		lens.head.look_at(chest)
		lens.step(STEP, chest, unit.player, false)
		frames += 1
	check(lens.tracking and WorldHistory.event_count("support_camera_saw_player") >= 1, "held in the cone, the camera films you (%d frames)" % frames)
	check(unit.director.is_alarm() and str(unit.director.alarm_source).begins_with("camera:"), "being filmed is the alarm")
	check(WorldHistory.event_count("support_unit_alarm_raised") == 1, "the alarm is recorded")
	var guard: SupportGuard = unit.guards[0]
	var chip: BrainChipFlash = unit.director.chip_for(guard)
	check(guard.alerted and guard.state == "hunt", "the guards are alerted")
	check(chip != null and chip.active and chip.get_parent() == guard.rig.head_anchor, "a brain chip flashes on each alerted guard's head")
	await get_tree().process_frame
	await get_tree().process_frame
	check(chip != null and chip.intensity() > 0.0, "and it is lit (%.2f)" % (chip.intensity() if chip != null else -1.0))
	check(unit.xray_flash.active() and unit.xray_flash.flashes == 1, "the camera flashes white X-ray")
	check(unit.xray_flash.depth_quad != null and unit.xray_flash.depth_quad.visible, "the depth image is up over the view")
	var entries: Array = unit.director.watch_entries()
	check(entries.size() == 2, "block tracking boxes every alerted guard (%d)" % entries.size())
	unit.block_tracker.watch(entries)
	check(unit.block_tracker.watchers.size() == 2, "and the tracker is drawing them")
	for _frame in 40:
		unit.xray_flash._process(STEP)
	check(not unit.xray_flash.active() and not unit.xray_flash.depth_quad.visible and unit.camera.environment == null, "the flash is over in about a second and the view is put back")
	# Reinforcements pile out of the doors.
	unit.director._process(unit.director.REINFORCE_DELAY + 0.1)
	check(unit.director.reinforcements == 2 and unit.guards.size() == 4, "after the flash, reinforcements come out of the doors (%d)" % unit.director.reinforcements)
	var fresh: SupportGuard = unit.guards[3]
	check(fresh.state == "hunt" and fresh.alerted and unit.director.chip_for(fresh) != null, "they arrive hunting, chipped")
	check(WorldHistory.event_count("support_unit_reinforcements") == 1, "the reinforcements are recorded")
	# And they try to kill you.
	_place(fresh.global_position + Vector3(0, 1.0, 5.0), 0.0)
	await get_tree().physics_frame
	var blood_before: float = unit.blood
	for _frame in 150:
		fresh.step(STEP, unit.player, false)
	check(fresh.shots_fired >= 2 and unit.blood < blood_before, "a reinforcement shoots you (%d shots, blood %d)" % [fresh.shots_fired, roundi(unit.blood)])
	# The player can fight back with the ram.
	_place(fresh.global_position + Vector3(0, 1.0, 1.6), _yaw_to(fresh.global_position))
	unit.player.rotation.y = unit.yaw
	var swings := 0
	while not fresh.is_down() and swings < 8:
		unit.swing_cooldown = 0.0
		unit.swing()
		swings += 1
	check(fresh.is_down() and WorldHistory.event_count("support_guard_downed") >= 1, "the ram puts a guard down, recorded (%d swings)" % swings)


func _bingyanga() -> void:
	var cell: BingyangCell = unit.cells[0]
	var occupant: Bingyanger = cell.occupant
	check(occupant.state == "held" and not occupant.mutations.is_empty(), "a bingyanga is strapped in its cell, mutated (%s)" % ",".join(occupant.mutations))
	# Stand in the hall in front of its door and break it open.
	var door_face: Vector3 = cell.global_position + Vector3(1.6, 1.0, 0)
	_place(door_face, PI * 0.5, -0.1)
	unit.post_message_timer = 0.0
	unit._update_hud()
	check(unit.prompt.text.contains("BREAK THE CELL OPEN"), "facing a cell door, the prompt offers to break it (%s)" % unit.prompt.text)
	var swings := 0
	while not cell.door.broken and swings < 20:
		unit.swing_cooldown = 0.0
		unit.swing()
		swings += 1
	check(cell.door.broken, "the ram breaks the cell door (%d swings)" % swings)
	check(occupant.state == "loose" and occupant.meetings == 1 and occupant.attitude in ["friendly", "hostile"], "the bingyanga is out, a bingyanger, its attitude rolled (%s, %s)" % [occupant.attitude, occupant.act])
	check(WorldHistory.event_count("bingyanga_freed") == 1 and str(WorldHistory.subject(occupant.subject_id).get("status", "")) == "loose", "freeing it is recorded")
	# A new meeting re-rolls it.
	occupant.global_position = unit.player.global_position + Vector3(20, 0, 0)
	occupant.step(occupant.APART_SECONDS + 0.5)
	check(not occupant.met, "far apart for long enough, the meeting is over")
	occupant.global_position = unit.player.global_position + Vector3(2.0, -1.0, 0)
	occupant.step(STEP)
	check(occupant.meetings == 2 and WorldHistory.event_count("bingyanger_met") == 2, "meeting it again rolls it again")
	# Friendly: gives you something.
	var carried: int = CARRY.new().items.size()
	occupant.meet("friendly", "give")
	occupant.global_position = unit.player.global_position + Vector3(1.2, -1.0, 0)
	occupant.step(STEP)
	check(CARRY.new().items.size() == carried + 1 and WorldHistory.event_count("bingyanger_gave") == 1, "a friendly one hands you something")
	# Friendly: tells you something.
	occupant.meet("friendly", "tell")
	occupant.step(STEP)
	check(WorldHistory.event_count("bingyanger_told") == 1, "a friendly one tells you something")
	# Hostile: steals and runs.
	occupant.meet("hostile", "steal")
	occupant.step(STEP)
	check(not occupant.holding.is_empty() and CARRY.new().items.size() == carried and WorldHistory.event_count("bingyanger_stole") == 1, "a hostile one steals what you carry (%s)" % occupant.holding)
	# Hostile: attacks.
	var blood_before: float = unit.blood
	occupant.meet("hostile", "attack")
	occupant._cooldown = 0.0
	occupant.step(STEP)
	check(unit.blood < blood_before, "a hostile one tears at you")
	# It dies like anyone; what it took is on its body.
	var hits := 0
	while not occupant.is_down() and hits < 12:
		occupant.take_hit(60.0, Vector3.FORWARD, "blunt", "player")
		hits += 1
	check(occupant.state == "dead" and WorldHistory.event_count("bingyanger_died") == 1, "it dies like anyone, recorded")
	var stolen: String = occupant.holding
	_place(occupant.global_position + Vector3(0, 1.0, 1.0))
	check(not stolen.is_empty() and unit.interact() == "take_back" and CARRY.new().items.size() == carried + 1, "and you can take back what it stole off its body")
	check(unit.holding_ram, "the breach tool is back in hand")
	# A second one, freed and forced hostile-scream, raises the alarm on its own.
	var second: Bingyanger = unit.cells[1].occupant
	second.release("test")
	check(WorldHistory.event_count("bingyanga_freed") == 2, "each one freed is recorded")


func _gate() -> void:
	var post: FacilityGuardPost = unit.guard_post
	var hollis_at: Vector3 = post.guard.global_position
	_place(hollis_at + Vector3(0, 1.0, 1.6), _yaw_to(hollis_at))
	var said: String = unit.interact()
	check(said == "hollis" and post.door_open, "the ram at Hollis's chest makes him palm the reader: the gate opens")
	check(WorldHistory.event_count("facility_biometric_access") == 1, "his tissue opened it, recorded by the barrier")
	_place(Vector3(0, 1.0, unit.GATE_Z - 2.0))
	unit._check_gate()
	check(unit.gate_passed and WorldHistory.event_count("support_unit_gate_passed") == 1, "walking through the last checkpoint is recorded")
	_place(unit.EXIT_AT + Vector3(0, 1.0, 1.0))
	check(unit.interact() == "exit" and unit.exit_requested, "at the far end the way down is taken")
	if ResourceLoader.exists(unit.NEXT_SCENE):
		check(unit.exit_message.is_empty(), "with the vehicle bay built, it travels there")
	else:
		check(unit.exit_message.contains("NOT BUILT YET"), "without the vehicle bay yet, it says so")


func _death() -> void:
	unit._hurt(500.0, "shot by Support Unit security", "support_guard_a")
	check(unit.died and str(unit.rebirth_request.get("scene", "")) == "res://vat_chamber.tscn", "dying here hands off to rebirth in the vat")
	var found := false
	for event in WorldHistory.events:
		if str(event.type) == "player_died" and str((event.details as Dictionary).get("location", "")) == "support_unit":
			found = true
	check(found, "the death is recorded where it happened")
