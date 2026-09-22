extends Node

## Talking to somebody who is still on their feet.
##
## The brief carried this as an open item for as long as it existed:
## "`SpokenContact` gives the overworld a transcript, but only for a **downed**
## subject through the resolution window. Nothing on a standing NPC can be
## spoken to yet."
##
## `SpokenContact` was never the restriction. It takes whatever subject id it
## is handed, and `_voice_capture()` only ever handed it `resolution_target`,
## which the downed window sets and nothing else does. So the whole of the
## overworld conversation was reachable the entire time and had one gate in
## front of it.
##
## What is worth testing is the gate, not the plumbing behind it: who counts as
## addressable, who does not, and that the downed path did not change while the
## standing one was added beside it.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


## A stand-in actor record of the shape `encounter_actors` holds.
func _actor(hunt: Node, id: String, at: Vector3, downed: bool, dead := false) -> Dictionary:
	var holder := Node3D.new()
	hunt.add_child(holder)
	holder.global_position = at
	var rig := BaselineHuman.new()
	rig.gore = false
	holder.add_child(rig)
	rig.build(id, {})
	if dead:
		rig.anatomy.dead = true
	elif downed:
		rig.anatomy.downed = true
	return {"node": holder, "rig": rig, "subject_id": id}


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	await get_tree().process_frame
	var hunt: Node = (load("res://bone_yard_hunt.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(hunt)
	# Fail fast rather than hang. When `bone_yard_hunt.gd` will not parse --
	# which happens while another agent is mid-edit in it -- the scene
	# instantiates with no script, every `call()` below returns null, and the
	# test runs off the end without ever reaching `quit()`. Headless Godot then
	# sits in its main loop forever and the run looks like a slow import
	# instead of a broken one. Ten minutes were spent on that once.
	if not hunt.has_method("_nearest_standing"):
		print("FAIL bone_yard_hunt.gd did not load -- it has no script attached")
		print("STANDING_CONTACT_TEST_RESULT failures=1")
		get_tree().quit(1)
		return
	for frame in 20:
		await get_tree().physics_frame

	# Own the actor list outright, so a roamer wandering past cannot decide
	# what this test measured.
	#
	# And never await a physics frame between filling it and reading it. The
	# hunt prunes and rebuilds `encounter_actors` in `_update_encounter_actors`
	# and `_maintain_roamers` every single frame, so a synthetic record does not
	# survive one -- the first version of this test awaited after each append
	# and measured an empty list six times while reporting it as a broken gate.
	var actors: Array = hunt.get("encounter_actors")
	actors.clear()
	var here: Vector3 = hunt.get("player")
	var facing: Vector3 = -(hunt.get("camera") as Camera3D).global_transform.basis.z
	facing.y = 0.0
	facing = facing.normalized()

	print("-- nobody to talk to --")
	check((hunt.call("_nearest_standing") as Dictionary).is_empty(), "an empty road has nobody to address")
	check((hunt.call("_addressable_actor") as Dictionary).is_empty(), "so speaking reaches no one")

	print("-- somebody standing in front of you --")
	var ahead := _actor(hunt, "ahead_subject", here + facing * 2.5, false)
	actors.append(ahead)
	var found: Dictionary = hunt.call("_nearest_standing")
	check(not found.is_empty(), "a person on their feet in front of you can be addressed")
	check(str(found.get("subject_id", "")) == "ahead_subject", "and it is them (%s)" % str(found.get("subject_id", "")))

	print("-- and the ones who cannot be --")
	# Behind you. A fight has people on several sides and shouting at whoever
	# is nearest, including one at your back, is not what speaking meant.
	var behind := _actor(hunt, "behind_subject", here - facing * 2.0, false)
	actors.append(behind)
	check(str((hunt.call("_nearest_standing") as Dictionary).get("subject_id", "")) == "ahead_subject", "somebody behind you is not who you are talking to")
	# Out of range, even dead ahead.
	actors.clear()
	actors.append(_actor(hunt, "far_subject", here + facing * 40.0, false))
	check((hunt.call("_nearest_standing") as Dictionary).is_empty(), "and neither is somebody across the yard")
	# The dead do not answer.
	actors.clear()
	actors.append(_actor(hunt, "dead_subject", here + facing * 2.0, false, true))
	check((hunt.call("_nearest_standing") as Dictionary).is_empty(), "the dead are not addressable")

	print("-- the downed keep their own window --")
	actors.clear()
	var floored := _actor(hunt, "floored_subject", here + facing * 2.0, true)
	actors.append(floored)
	# `_nearest_standing` deliberately skips them: they are the other path.
	check((hunt.call("_nearest_standing") as Dictionary).is_empty(), "a body on the floor is not addressed as somebody standing")
	hunt.set("resolution_target", "floored_subject")
	var addressed: Dictionary = hunt.call("_addressable_actor")
	check(str(addressed.get("subject_id", "")) == "floored_subject", "but the resolution window still reaches them")
	# And the window wins even with somebody upright alongside, because a form
	# open over a body is unambiguously who you are talking to.
	actors.append(_actor(hunt, "bystander", here + facing * 2.4, false))
	check(str((hunt.call("_addressable_actor") as Dictionary).get("subject_id", "")) == "floored_subject", "and it wins over a bystander")
	hunt.set("resolution_target", "")
	check(str((hunt.call("_addressable_actor") as Dictionary).get("subject_id", "")) == "bystander", "with the window closed, the bystander is who you reach")

	print("-- and they are told the truth about themselves --")
	var standing_def: Dictionary = hunt.call("_standing_character", "bystander")
	var downed_def: Dictionary = hunt.call("_downed_character", "floored_subject")
	var standing_rules := ", ".join(PackedStringArray(standing_def.get("rules", [])))
	var downed_rules := ", ".join(PackedStringArray(downed_def.get("rules", [])))
	check(downed_rules.to_lower().contains("cannot get up"), "the downed are told they cannot get up")
	# The load-bearing half: those rules are actively wrong for somebody with a
	# weapon standing in front of you, and handing them over would have a
	# healthy person answer as though they were bleeding on the road.
	check(not standing_rules.to_lower().contains("cannot get up"), "and somebody standing is not")
	check(standing_rules.to_lower().contains("not hurt"), "they are told they are on their feet instead")
	check(str(standing_def.get("identity", "")).contains("on their feet"), "which their identity line says too")
	check(str(standing_def.get("voice", "")) != str(downed_def.get("voice", "")), "and the two do not speak in the same voice")

	print("-- and a machine with no microphone can still talk --")
	# Vosk needs a Python process, a model on disk and a working input device.
	# Without all three the overworld could not be spoken to at all, which is
	# most machines and every demo box.
	var entry := hunt.get("talk_entry") as LineEdit
	check(entry != null and is_instance_valid(entry), "there is a line to type in")
	check(not entry.visible, "and it stays out of the way until it is needed")
	actors.clear()
	var typist := _actor(hunt, "typed_subject", here + facing * 2.0, false)
	actors.append(typist)
	hunt.call("_open_typed_talk", "typed_subject")
	check(entry.visible, "addressing somebody without a microphone raises it")
	check(str(hunt.get("talk_entry_subject")) == "typed_subject", "aimed at the person you are addressing")

	var spoke_before := WorldHistory.event_count("proximity_voice_addressed")
	hunt.call("_typed_said", "  put it down  ")
	check(WorldHistory.event_count("proximity_voice_addressed") == spoke_before + 1, "typing at them reaches the same path speaking does")
	check(not entry.visible, "and the line closes behind it")
	check(str(hunt.get("talk_entry_subject")).is_empty(), "with nobody still addressed")
	check(str(WorldHistory.subject("typed_subject").get("memory", "")).contains("spoke to me"), "they remember being spoken to")

	# Enter on an empty box plainly means "never mind", not "say nothing at
	# somebody".
	hunt.call("_open_typed_talk", "typed_subject")
	var quiet_before := WorldHistory.event_count("proximity_voice_addressed")
	hunt.call("_typed_said", "   ")
	check(WorldHistory.event_count("proximity_voice_addressed") == quiet_before, "submitting nothing says nothing")
	check(not entry.visible, "but still puts the line away")

	print("-- and a panel to say it through --")
	# A demo handed to somebody who has never played this cannot begin with
	# "type a sentence at the armed man".
	var panel := hunt.get("talk_ui") as NPCDialogueUI
	check(panel != null and is_instance_valid(panel), "there is a panel to talk through")
	check(not panel.visible, "and it stays shut until somebody is addressed")
	actors.clear()
	var talked_to := _actor(hunt, "panel_subject", here + facing * 2.0, false)
	actors.append(talked_to)
	hunt.call("_open_talk_panel", "panel_subject")
	check(panel.visible, "addressing somebody opens it")
	check(str(hunt.get("talk_subject")) == "panel_subject", "on them")

	# Chosen lines are said, not applied. The NPC still rules on them, which is
	# what stops the panel being a surrender button.
	var said_before := WorldHistory.event_count("proximity_voice_addressed")
	hunt.call("_talk_option", "Put it down and walk away.")
	check(WorldHistory.event_count("proximity_voice_addressed") == said_before + 1, "choosing a line says it down the same path speech takes")
	check(str(WorldHistory.subject("panel_subject").get("memory", "")).contains("spoke to me"), "and they heard it")

	# Speaking freely takes whichever half this machine can run, and the suite
	# has to pass on both -- the same rule `spoken_contact_test` states, because
	# Vosk needs a Python process, a model on disk and an input device, and the
	# machine that has none of them is exactly the one the fallback is for.
	var talker: SpokenContact = hunt.get("spoken")
	hunt.call("_talk_option", "[SPEAK]")
	if talker != null and talker.transcribes():
		check(panel.listening, "speaking freely opens the microphone where there is one")
		hunt.call("_talk_speak", false)
	else:
		check((hunt.get("talk_entry") as LineEdit).visible, "and the typed line where there is not")
		hunt.call("_close_typed_talk")

	hunt.call("_talk_option", "[LEAVE]")
	check(not panel.visible, "leaving closes the panel")
	check(str(hunt.get("talk_subject")).is_empty(), "and nobody is being addressed afterwards")
	# A chosen line with nobody addressed must not go anywhere.
	var orphan_before := WorldHistory.event_count("proximity_voice_addressed")
	hunt.call("_talk_option", "Put it down and walk away.")
	check(WorldHistory.event_count("proximity_voice_addressed") == orphan_before, "and a line chosen with the panel shut says nothing")

	hunt.queue_free()
	print("STANDING_CONTACT_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
