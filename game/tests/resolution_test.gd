extends Node
var failures: Array[String] = []
var checks := 0
var hunt

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures.append(label)

func downed(tag: String) -> Dictionary:
	hunt._spawn_encounter_actor({"instance_id": tag, "kind": "hostile"}, hunt.player + Vector3(0, 0, 2))
	var actor: Dictionary = hunt.encounter_actors.back()
	actor.node.position = hunt.player + Vector3(0, 0, 2)
	actor.rig.gore = false
	for i in 7:
		actor.rig.hit("torso", 30, 10, "blunt")
	return actor

func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	var actor := downed("mercy")
	var before: int = hunt.health
	var position: Vector3 = actor.node.position
	hunt._update_encounter_actors(2.0)
	check(actor.rig.is_downed() and not actor.anatomy.dead, "downed remains alive")
	check(hunt.health == before and actor.node.position == position, "downed actor cannot attack or flee")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var prior_mouse_mode := Input.mouse_mode
	hunt._interact()
	check(hunt.resolution_ui.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "E opens menu and releases pointer")
	check(hunt.resolution_ui.buttons.size() == 3, "three real resolution buttons")
	check(hunt.resolution_ui.buttons[2].disabled, "unearned recruitment is refused")
	check(hunt.resolution_ui.voice_button is Button, "voice is a visible hold action beside the choices")
	var voice_before := WorldHistory.event_count("proximity_voice_addressed")
	hunt.resolution_ui._voice_hold(true)
	hunt.voice_channel._process_capture()
	check(hunt.voice_channel.active, "hold V opens a transient local microphone session")
	hunt.resolution_ui._voice_hold(false)
	check(not hunt.voice_channel.active and hunt.resolution_ui.visible, "release sends voice without closing the encounter")
	check(WorldHistory.event_count("proximity_voice_addressed") == voice_before + 1, "voice contact enters world history without saving raw audio")
	check(not hunt.resolution_ui.voice_reply.is_empty(), "downed subject returns an in-world reply")
	check(actor.rig.head_anchor.get_node_or_null("VoiceReply") is AudioStreamPlayer3D, "reply sound originates at the subject's head")
	hunt._spawn_encounter_actor({"instance_id": "world_keeps_moving", "kind": "hostile"}, hunt.player + Vector3(0, 0, 10))
	var moving: Dictionary = hunt.encounter_actors.back()
	var moving_before: Vector3 = moving.node.position
	hunt._update_encounter_actors(0.5)
	check(moving.node.position != moving_before, "other enemies keep moving while the decision is open")
	moving.node.queue_free()
	hunt.encounter_actors.erase(moving)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	hunt.resolution_ui._input(escape)
	check(not hunt.resolution_ui.visible and actor.rig.is_downed(), "Escape cancels without choosing")
	check(Input.mouse_mode == prior_mouse_mode, "cancel restores prior pointer mode")
	hunt._open_resolution(actor)
	hunt.resolution_ui.buttons[1].pressed.emit()
	check(not actor.anatomy.dead and not actor.anatomy.downed, "spare leaves survivor stabilised")
	check(actor.rig.zone_health("torso") == 0, "spare preserves destroyed chest")
	check(WorldHistory.subject(actor.subject_id).status == "spared", "mercy persists")
	hunt._update_encounter_actors(2.0)
	check(hunt.health == before, "spared witness does not immediately attack")
	var recruited := downed("crew")
	WorldHistory.update_subject(recruited.subject_id, {"bond": 25})
	hunt._open_resolution(recruited)
	check(not hunt.resolution_ui.buttons[2].disabled, "earned bond enables recruitment")
	hunt.resolution_ui.buttons[2].pressed.emit()
	hunt._update_encounter_actors(2.0)
	check(not recruited.anatomy.dead and recruited.disposition == "ally" and hunt.health == before, "recruit is alive and non-hostile")
	check(WorldHistory.subject(recruited.subject_id).relations.player.consensual, "consent persists in relationship")
	var doomed := downed("execution")
	var loot_before: int = hunt.loose_loot.size()
	hunt._open_resolution(doomed)
	hunt.resolution_ui.buttons[0].pressed.emit()
	check(doomed.anatomy.dead and WorldHistory.subject(doomed.subject_id).status == "dead", "execution persists death")
	check(hunt.loose_loot.size() == loot_before + 1, "execution drops loot once")
	check(hunt.kill_cam.active and hunt.kill_cam.anatomy_state.organs.heart.ruptured, "execution camera carries actual ruptured heart")
	check(hunt.kill_cam.ruptures.size() == 7, "camera represents all seven internal structures")
	var intact := 0
	for organ in hunt.kill_cam.ruptures:
		if not organ.ruptured:
			intact += 1
	check(intact == 6, "camera leaves untouched organs intact")
	hunt.kill_cam.cancel()
	check(is_equal_approx(Engine.time_scale, 1), "cancel restores time")
	hunt.kill_cam.trigger("LEGACY", "torso", Vector3.LEFT, "DERBY")
	check(hunt.kill_cam.active, "four-argument derby trigger works")
	hunt.kill_cam._process(1)
	check(not hunt.kill_cam.active and is_equal_approx(Engine.time_scale, 1), "completion restores time")
	hunt.kill_cam.trigger("EXIT", "head", Vector3.LEFT)
	hunt.kill_cam.free()
	check(is_equal_approx(Engine.time_scale, 1), "tree exit restores time")
	print("RESOLUTION_TEST_RESULT checks=", checks, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
