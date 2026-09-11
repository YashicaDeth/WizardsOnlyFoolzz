extends Node

## The clinch is the unarmed route into the downed window. It has to be a
## contest that can be lost, and winning it must leave the loser alive and
## decidable rather than dead.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame

	hunt.yaw = 0.0
	var at: Vector3 = hunt.player + Vector3(0, 0, 1.6)
	hunt._spawn_encounter_actor({"instance_id": "clinch", "kind": "hostile"}, at)
	var actor: Dictionary = hunt.encounter_actors.back()
	actor.node.position = at
	await get_tree().physics_frame

	# Out of reach first: a grapple must need contact range.
	actor.node.position = hunt.player + Vector3(0, 0, 9.0)
	hunt._start_grapple()
	check(hunt.grapple_target.is_empty(), "a grapple cannot be started across the yard")

	actor.node.position = at
	hunt.stamina = 100.0
	hunt._start_grapple()
	check(hunt.grapple_target == str(actor.subject_id), "the clinch takes hold at contact range")

	# Without pressing, the contest does not simply resolve itself.
	var opening: float = hunt.grapple_advantage
	hunt._update_grapple(0.4)
	check(hunt.grapple_advantage < opening + 0.5, "advantage is contested, not automatic")
	check(hunt.stamina < 100.0, "a clinch costs stamina")

	# Drive it to a win the way a held press would.
	# Enough iterations to actually win the contest: the opponent pushes back
	# every tick, so a clinch is deliberately slow to close out.
	for step in 200:
		hunt.grapple_advantage += 0.05
		hunt._update_grapple(0.05)
		if hunt.grapple_target.is_empty():
			break
	check(actor.anatomy.downed and not actor.anatomy.dead, "winning a clinch downs them alive")
	check(actor.rig.zone_health("torso") < AnatomyComponent.DEFAULT_ZONES.torso.health, "the takedown is recorded on the body")
	check(hunt.grapple_target.is_empty(), "the clinch releases once it resolves")
	check(WorldHistory.recent_events(20).any(func(e): return str(e.get("type", "")) == "grapple_takedown"), "the takedown enters world history")

	# And the downed body is now decidable, which is the whole point.
	hunt.player = (actor.node as Node3D).global_position - Vector3(0, 0, 1.2)
	hunt._interact()
	check(hunt.resolution_ui.visible, "a grappled body opens the resolution window")
	hunt.resolution_ui.cancel_menu()

	# Losing throws the player instead.
	var second: Vector3 = hunt.player + Vector3(0, 0, 1.4)
	hunt._spawn_encounter_actor({"instance_id": "clinch_loss", "kind": "hostile"}, second)
	var bully: Dictionary = hunt.encounter_actors.back()
	bully.node.position = second
	await get_tree().physics_frame
	hunt.stamina = 100.0
	hunt._start_grapple()
	var health_before: int = hunt.health
	for step in 200:
		hunt.grapple_advantage -= 0.05
		hunt._update_grapple(0.05)
		if hunt.grapple_target.is_empty():
			break
	check(hunt.health < health_before, "losing a clinch hurts (%d -> %d)" % [health_before, hunt.health])
	check(hunt.grapple_target.is_empty(), "a lost clinch releases")

	# F7. The clinch is a social verb: you can talk to somebody you are holding,
	# and what they agree to reaches the downed window afterwards.
	var third: Vector3 = hunt.player + Vector3(0, 0, 1.3)
	hunt._spawn_encounter_actor({"instance_id": "clinch_talk", "kind": "hostile"}, third)
	var mark: Dictionary = hunt.encounter_actors.back()
	mark.node.position = third
	await get_tree().physics_frame
	var mark_id := str(mark.subject_id)
	check(not hunt._accepts_recruitment(WorldHistory.subject(mark_id)), "a stranger will not be recruited off the street")
	# Held explicitly: which body `_start_grapple` picks out of a crowd is
	# covered above, and what is under test here is the negotiation.
	hunt.stamina = 100.0
	hunt.grapple_target = mark_id
	# A player the world trusts, with a real hold on a hurt body.
	WorldHistory.update_subject("player", {"karma": 0.9}, "test_standing")
	WorldHistory.update_subject(mark_id, {"bond": 40}, "test_bond")
	mark.anatomy.pain = 70.0
	hunt.grapple_advantage = 0.9
	var offer: Dictionary = hunt._clinch_options(mark)
	check(float(offer.persuasion) > float(offer.coercion), "standing makes talking the better verb here")
	hunt._clinch_persuade()
	var persuaded := WorldHistory.subject(mark_id)
	check(float(persuaded.get("debt_to_player", 0.0)) > 0.0, "talking them down leaves them owing you")
	check(hunt._accepts_recruitment(persuaded), "and that debt is what makes recruitment possible in the downed window")
	check(hunt.grapple_target.is_empty(), "a surrender ends the hold")
	check(mark.anatomy.downed and not mark.anatomy.dead, "they go down awake, having decided, rather than knocked out")

	# Leaning on someone instead buys it with a grudge.
	var fourth: Vector3 = hunt.player + Vector3(1.1, 0, 0.6)
	hunt._spawn_encounter_actor({"instance_id": "clinch_lean", "kind": "hostile"}, fourth)
	var leaned: Dictionary = hunt.encounter_actors.back()
	leaned.node.position = fourth
	await get_tree().physics_frame
	var leaned_id := str(leaned.subject_id)
	WorldHistory.update_subject("player", {"karma": -0.9}, "test_dread")
	leaned.anatomy.pain = 70.0
	hunt.stamina = 100.0
	hunt.grapple_target = leaned_id
	hunt.grapple_advantage = 0.9
	var grudge_before := int(WorldHistory.subject(leaned_id).get("grudge", 0))
	hunt._clinch_threaten()
	check(int(WorldHistory.subject(leaned_id).get("grudge", 0)) > grudge_before, "leaning on them is remembered as a grudge")
	check(WorldHistory.recent_events(6).any(func(event): return str(event.get("type", "")) == "clinch_threatened"), "and the act enters the record with whoever saw it")

	print("GRAPPLE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
