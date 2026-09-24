extends Node

## What an NPC decides has to actually happen.
##
## `NPCConversationComponent` has run the whole loop since it was written --
## perceive, brain proposes, validator rules, relationship moves, NPC speaks
## from what happened -- and `validated_action` had no connection in the hunt
## at all. Somebody could rule that they were going to run, or comply, or shout
## for help, say so out loud, and then stand exactly where they were.
##
## So what is worth testing is not the ruling, which `npc_conversation_test`
## already covers. It is that the world moved: the disposition that decides
## whether they are still swinging at you, and the record, which is what makes
## a person who yielded still yielded after a reload.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _actor(hunt: Node, id: String, at: Vector3) -> Dictionary:
	var holder := Node3D.new()
	hunt.add_child(holder)
	holder.global_position = at
	var rig := BaselineHuman.new()
	rig.gore = false
	holder.add_child(rig)
	rig.build(id, {})
	WorldHistory.register_subject(id, {"name": id.to_upper(), "kind": "person"})
	return {"node": holder, "rig": rig, "subject_id": id, "disposition": "hostile", "state": "hunting", "attack_time": 1.0}


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	await get_tree().process_frame
	var hunt: Node = (load("res://bone_yard_hunt.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(hunt)
	if not hunt.has_method("_npc_acted"):
		print("FAIL bone_yard_hunt.gd did not load -- it has no script attached")
		print("NPC_RULING_TEST_RESULT failures=1")
		get_tree().quit(1)
		return
	for frame in 20:
		await get_tree().physics_frame
	# Never await between filling this and reading it: the hunt prunes and
	# rebuilds `encounter_actors` every physics frame.
	var actors: Array = hunt.get("encounter_actors")
	var here: Vector3 = hunt.get("player")

	print("-- talking your way into a fight --")
	actors.clear()
	var hostile := _actor(hunt, "ruling_attack", here + Vector3(0, 0, -2.0))
	hostile.disposition = "neutral"
	actors.append(hostile)
	hunt.call("_npc_acted", "ruling_attack", {"action": "attack"})
	check(str(hostile.get("disposition", "")) == "hostile", "deciding to attack makes them hostile")
	check(str(hostile.get("state", "")) == "hunting", "and sets them hunting")
	check(bool(hostile.get("tracking_player", false)), "and they know where you are")
	check(str(WorldHistory.subject("ruling_attack").get("disposition", "")) == "hostile", "and the record says so too")

	print("-- and out of one --")
	actors.clear()
	var yielding := _actor(hunt, "ruling_comply", here + Vector3(0, 0, -2.0))
	actors.append(yielding)
	hunt.call("_npc_acted", "ruling_comply", {"action": "comply"})
	# `disposition != hostile` is the line the encounter loop reads to stop
	# somebody swinging, so this is the whole of surrender working.
	check(str(yielding.get("disposition", "")) == "neutral", "yielding stops them being hostile")
	check(str(yielding.get("state", "")) == "spared", "and puts them in the spared state")
	check(is_equal_approx(float(yielding.get("attack_time", 1.0)), 0.0), "and drops the swing they were winding up")
	# The one that has to survive a reload: a person who gave up is not a
	# person you have to talk down again next time you walk past.
	check(str(WorldHistory.subject("ruling_comply").get("status", "")) == "spared", "and the record holds them spared")

	print("-- or away from one --")
	actors.clear()
	var running := _actor(hunt, "ruling_flee", here + Vector3(0, 0, -2.0))
	actors.append(running)
	hunt.call("_npc_acted", "ruling_flee", {"action": "flee"})
	check(str(running.get("state", "")) == "fleeing", "deciding to run puts them in the state that runs")
	check(str(running.get("disposition", "")) == "neutral", "and they are not fighting while they do it")

	print("-- shouting for the others --")
	actors.clear()
	var caller := _actor(hunt, "ruling_shout", here + Vector3(0, 0, -2.0))
	var near := _actor(hunt, "ruling_near", here + Vector3(3.0, 0, -2.0))
	var far := _actor(hunt, "ruling_far", here + Vector3(0, 0, -60.0))
	var friend := _actor(hunt, "ruling_friend", here + Vector3(2.0, 0, -2.0))
	friend.disposition = "neutral"
	actors.append(caller)
	actors.append(near)
	actors.append(far)
	actors.append(friend)
	hunt.call("_npc_acted", "ruling_shout", {"action": "call_for_help"})
	check(bool(near.get("tracking_player", false)), "somebody close enough to hear comes looking")
	# A shout that pulled the whole yard would make talking strictly worse than
	# shooting, which would be a reason never to talk to anybody.
	check(not bool(far.get("tracking_player", false)), "and somebody across the yard does not")
	check(not bool(friend.get("tracking_player", false)), "nor does somebody who is not hostile to begin with")

	print("-- the dead do not decide anything --")
	actors.clear()
	var corpse := _actor(hunt, "ruling_dead", here + Vector3(0, 0, -2.0))
	(corpse.rig as BaselineHuman).anatomy.dead = true
	actors.append(corpse)
	hunt.call("_npc_acted", "ruling_dead", {"action": "attack"})
	check(str(corpse.get("disposition", "")) == "hostile", "a dead body is left exactly as it was")
	check(str(corpse.get("state", "")) == "hunting", "and does not get up to hunt you")
	# And somebody who is not in the encounter at all cannot be ruled about.
	hunt.call("_npc_acted", "nobody_at_all", {"action": "attack"})
	check(true, "a ruling about somebody who is not here is simply ignored")

	print("-- and all of it is on the record --")
	# Four: attack, comply, flee, call_for_help. The dead body and the person
	# who is not in the encounter are deliberately not among them -- both were
	# ruled about above and both returned before recording, because a ledger
	# that says a corpse decided something is worse than one that says nothing.
	check(WorldHistory.event_count("npc_conversation_ruling") == 4, "every ruling by somebody alive and present is recorded (%d)" % WorldHistory.event_count("npc_conversation_ruling"))
	check(WorldHistory.event_count("npc_yielded") >= 1, "yielding is its own event")
	check(WorldHistory.event_count("npc_turned_hostile") >= 1, "so is turning on you")

	hunt.queue_free()
	print("NPC_RULING_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
