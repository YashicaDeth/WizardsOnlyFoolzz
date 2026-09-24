extends Node

## Vertebra 5, the biometric door: every way through the gate, the way it goes
## wrong, and the gate standing in the real vat chamber between the aisle and
## the pit door.

const CHECKPOINT := preload("res://systems/facility_checkpoint.gd")
const ANATOMY := preload("res://systems/anatomy_component.gd")
const OPENING := preload("res://systems/opening_director.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	_coerce_route()
	_knockout_drag_route()
	_dead_route()
	_hand_route()
	_seen_first()
	await _in_the_vat_chamber()
	print("FACILITY_CHECKPOINT_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)


## A fresh world, a fresh gate, and a decanted player holding the restraint
## the breakout hands them. Local space: the gate is z = 0, the guard stands
## at z = +1.9 looking up the aisle (+z), the reader is at x = +2.3.
func _setup(with_restraint := true) -> Dictionary:
	WorldHistory.clear_history()
	var items: Array = []
	if with_restraint:
		items.append({"label": "BROKEN MEDICAL RESTRAINT", "kind": "tool", "mass": 0.0})
	WorldHistory.register_subject("inventory", {"kind": "inventory", "items": items})
	var gate = CHECKPOINT.new()
	add_child(gate)
	gate.build(7.35, 4.1)
	var player := CharacterBody3D.new()
	add_child(player)
	var anatomy = ANATOMY.new()
	player.add_child(anatomy)
	anatomy.configure("player", 5000.0, {})
	gate.bind_player(player, anatomy)
	gate.active = true
	return {"gate": gate, "player": player, "anatomy": anatomy}


func _teardown(world: Dictionary) -> void:
	(world.gate as Node).queue_free()
	(world.player as Node).queue_free()


func _stand(world: Dictionary, at: Vector3, facing_z := -1.0) -> void:
	var player := world.player as Node3D
	player.global_position = at + Vector3(0, 0.85, 0)
	player.rotation.y = 0.0 if facing_z < 0.0 else PI


func _behind_guard(world: Dictionary) -> void:
	_stand(world, Vector3(0.4, 0, 0.95))


func _at_reader(world: Dictionary) -> void:
	_stand(world, Vector3(2.3, 0, 1.6))


func _away_from_reader(world: Dictionary) -> void:
	_stand(world, Vector3(-1.0, 0, 2.9))


func _carried(label: String) -> Dictionary:
	for entry in WorldHistory.subject("inventory").get("items", []):
		if str((entry as Dictionary).get("label", "")) == label:
			return entry
	return {}


func _coerce_route() -> void:
	var bare := _setup(false)
	_behind_guard(bare)
	var gate = bare.gate
	check(gate.prompt().is_empty() or gate.prompt().contains("READER"), "with nothing in hand there is nothing to do to him")
	check(not gate.interact() or gate.state == "post", "and E does not take a guard hostage bare-handed")
	_teardown(bare)

	var world := _setup()
	gate = world.gate
	_behind_guard(world)
	check(gate.prompt().contains("THROAT"), "behind him with the restraint, the prompt offers his throat")
	check(gate.interact() and gate.state == "coerced", "E behind an unaware guard coerces him")
	check(str(WorldHistory.subject("guard_hollis").get("status", "")) == "coerced", "and the world records it")
	_at_reader(world)
	check(gate.prompt().contains("HIS PALM"), "at the reader the prompt is his palm")
	gate.interact()
	check(gate.is_open, "a coerced living guard opens the gate")
	check(WorldHistory.event_count("facility_biometric_access") == 1, "through the barrier's one shared record")
	check(gate.state == "released" and not bool(gate.guard.anatomy.dead), "and he walks away from it alive")
	check(gate._door_shape.disabled, "the door stops blocking the way")
	_behind_guard(world)
	check(gate.interact() and gate.gun_taken, "a disarmed hostage still gives up his sidearm")
	check(int((_carried("CELL OUTZ BREACH NINE") as Dictionary).get("rounds", 0)) == 3, "with all three rounds, because he never fired")
	_teardown(world)


func _knockout_drag_route() -> void:
	var world := _setup()
	var gate = world.gate
	_behind_guard(world)
	check(gate.strike() and gate.state == "down", "one blow he never saw drops him")
	check(not gate.is_open, "a downed guard opens nothing by lying there")
	_away_from_reader(world)
	_stand(world, gate.guard.global_position + Vector3(-1.2, 0, 0))
	check(gate.prompt().contains("SIDEARM"), "his gun is the first thing offered")
	check(gate.interact() and gate.gun_taken, "taking it")
	check(gate.arsenal.current_id == "facility_sidearm" and int(gate.arsenal.ammo.facility_sidearm.loaded) == 3,
		"lands three rounds in the real arsenal")
	check(gate.interact() and gate.dragging, "then E drags him")
	check(gate.burden() < 1.0, "and a whole man slows you down")
	_at_reader(world)
	gate._drag_behind_player(1.0)
	gate.interact()
	check(gate.is_open and not gate.dragging, "an unconscious guard's hand opens the gate")
	check(not bool(gate.guard.anatomy.dead), "without anybody having to die")
	_teardown(world)


func _dead_route() -> void:
	var world := _setup()
	var gate = world.gate
	_behind_guard(world)
	gate.strike()
	gate._strike_cooldown = 0.0
	check(gate.strike() and gate.state == "dead", "hitting a downed guard again kills him")
	check(str(WorldHistory.subject("guard_hollis").get("status", "")) == "dead", "and the world records a death")
	_stand(world, gate.guard.global_position + Vector3(-1.2, 0, 0))
	gate.interact()
	gate.interact()
	check(gate.dragging, "a corpse drags like anybody else")
	_at_reader(world)
	gate.interact()
	check(gate.is_open, "and the reader takes a dead man's hand exactly as it takes a live one")
	_teardown(world)


func _hand_route() -> void:
	var world := _setup()
	var gate = world.gate
	_behind_guard(world)
	check(not gate.take_arm(), "you cannot saw at a guard who is standing up")
	gate.strike()
	check(gate.take_arm() and gate.carrying_arm, "X on a downed guard takes his hand with the restraint's edge")
	check((gate.guard.severed as Array).has("right_arm"), "through the real dismemberment, not a flag")
	check(not _carried("HOLLIS'S RIGHT ARM").is_empty(), "and the arm is carried")
	_at_reader(world)
	gate.interact()
	check(gate.is_open, "the hand alone opens the gate")
	var methods: Array = []
	for event in WorldHistory.events:
		if str(event.get("type", "")) == "facility_biometric_access":
			methods.append(str((event.get("details", {}) as Dictionary).get("method", "")))
	check(methods == ["removed_anatomy"], "filed once, as removed anatomy (%s)" % str(methods))
	_teardown(world)


func _seen_first() -> void:
	var own := _setup()
	_at_reader(own)
	own.gate.interact()
	check(not own.gate.is_open, "your own grown hand is not cleared")
	_teardown(own)

	var world := _setup()
	var gate = world.gate
	var anatomy = world.anatomy
	_stand(world, Vector3(0.4, 0, 8.0), -1.0)
	var t := 0.0
	var fired := 0
	while t < 40.0 and not bool(anatomy.dead):
		gate._physics_process(0.1)
		t += 0.1
	fired = WorldHistory.event_count("facility_guard_fired")
	check(gate.state == "alert", "walking straight at him up the aisle gets you seen")
	check(fired >= 1 and fired <= 3, "he fires, and never more than the three rounds he has (%d)" % fired)
	check(int(gate.guard.get_meta("facility_rounds")) == 3 - fired, "each shot leaves the gun")
	check(bool(anatomy.dead), "he puts you down and finishes it (%.1fs)" % t)
	_teardown(world)

	# If he emptied the gun at you, there is nothing in it to take.
	var spent := _setup()
	gate = spent.gate
	gate.guard.set_meta("facility_rounds", 0)
	_behind_guard(spent)
	gate.strike()
	_stand(spent, gate.guard.global_position + Vector3(-1.2, 0, 0))
	gate.interact()
	check(gate.gun_taken and _carried("CELL OUTZ BREACH NINE").is_empty(), "an emptied gun is not a gift")
	_teardown(spent)


func _in_the_vat_chamber() -> void:
	WorldHistory.clear_history()
	var scene = load("res://vat_chamber.tscn").instantiate()
	add_child(scene)
	scene.intake.sheet.randomise()
	scene.intake._finish_filing()
	await get_tree().process_frame
	var gate = scene.checkpoint
	check(gate != null and gate.global_position.z < -15.0, "the gate stands at the end of the aisle")
	check(gate.global_position.z > scene.door_marker.global_position.z, "in front of the pit door")
	scene.can_move = true
	scene.phase = "aisle"
	scene.player.global_position = scene.door_marker.global_position + Vector3(0, 0.85, 0.5)
	scene._interact()
	check(not OPENING.reached("entered_pit"), "the pit door does nothing while the gate is shut")
	check(scene.prompt.text.find("UNDERGROUND HEAT") == -1, "and does not offer itself")
	scene.queue_free()
	await get_tree().process_frame
