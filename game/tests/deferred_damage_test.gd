extends Node

## AF1.1. "A round is a thing that travels, not a raycast resolved on the
## frame it is fired." AF1's own projectile (`ballistics.gd`) already existed;
## what did not was the other half — anatomy damage still landed instantly,
## the frame the trigger went down, regardless of how far the visible round
## still had to travel. This proves the actual claim directly: a shot at a
## real distance wounds nobody on the frame it is fired, and wounds exactly
## the body it was aimed at only once the round has had real time to arrive.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _tick(hunt, times: int) -> void:
	for _index in times:
		await get_tree().physics_frame


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	hunt.player_body.position = Vector3(175, 0.9, 125)
	hunt.player = hunt.player_body.position + Vector3.UP * 0.6
	hunt.yaw = 0.0
	hunt.pitch = 0.0
	hunt.third_person = false
	hunt._update_camera()
	# A real distance, not point-blank — far enough that a 340 m/s pistol
	# round genuinely spends more than zero frames crossing it.
	hunt._spawn_encounter_actor({"instance_id": "deferred_target", "kind": "hostile"}, hunt.player + Vector3(0, -0.5, 20))
	var actor: Dictionary = hunt.encounter_actors.back()
	actor.node.position = hunt.player + Vector3(0, -0.5, 20)
	await get_tree().physics_frame
	await get_tree().physics_frame

	hunt._equip_weapon(2) # sidearm: one pellet, close to a laser
	hunt._attack()

	print("AF1.1 - the frame the trigger goes down wounds nobody yet")
	check(actor.anatomy.wounds.is_empty(), "no wound exists the instant _attack() returns, before the round has travelled anywhere")
	check(not WorldHistory.recent_events(4).any(func(e): return str(e.get("type", "")) == "firearm_anatomy_hit"), "and no firearm_anatomy_hit has been recorded yet either")
	check(WorldHistory.recent_events(4).any(func(e): return str(e.get("type", "")) == "weapon_fired"), "weapon_fired itself is not deferred — the trigger going down is not an anatomy question")

	print("AF1.1 - the round arrives, a few real frames later, and wounds exactly where it was aimed")
	var landed := false
	for _tick_index in 30:
		await get_tree().physics_frame
		if not actor.anatomy.wounds.is_empty():
			landed = true
			break
	check(landed, "the wound exists once the round has had real time to cross a real distance")
	check(actor.anatomy.wounds.all(func(w): return BaselineHuman.ZONES.has(str(w.get("zone", "")))), "and it landed on a real canonical zone, same as an instant hit would have")
	check(WorldHistory.recent_events(4).any(func(e): return str(e.get("type", "")) == "firearm_anatomy_hit"), "the deferred hit is what actually wrote firearm_anatomy_hit, not the frame it was fired on")

	print("AF1.1 - a shotgun's own pellets land as real, separate hits rather than one pre-batched summary")
	# The first shot's own attack_cooldown is a real cooldown and not this
	# claim's business to exercise — `_update_player()` is what counts it
	# down and this test never drives movement, so it is cleared directly
	# rather than waited out with nothing actually ticking it.
	hunt.attack_cooldown = 0.0
	hunt.arsenal.cooldown = 0.0
	WorldHistory.clear_history()
	hunt._spawn_encounter_actor({"instance_id": "deferred_target_2", "kind": "hostile"}, hunt.player + Vector3(0, -0.5, 3))
	var close_actor: Dictionary = hunt.encounter_actors.back()
	close_actor.node.position = hunt.player + Vector3(0, -0.5, 3)
	await get_tree().physics_frame
	await get_tree().physics_frame
	hunt._equip_weapon(1) # shotgun: nine pellets
	hunt._attack()
	# Point-blank on purpose: every pellet should land within the first
	# handful of frames, so the count is read the moment it stops climbing
	# rather than after 20 ticks of an unrelated engine tick diluting the log.
	var pellet_count := 0
	for _tick_index in 15:
		await get_tree().physics_frame
		var now: int = WorldHistory.recent_events(40).filter(func(e): return str(e.get("type", "")) == "firearm_anatomy_hit").size()
		if now == pellet_count and now > 0:
			break
		pellet_count = now
	check(pellet_count > 1, "more than one firearm_anatomy_hit landed from a single shotgun trigger pull (%d)" % pellet_count)

	if failures.is_empty():
		print("deferred damage: the round decides, not the trigger")
		get_tree().quit(0)
	else:
		print("deferred damage FAILURES: ", failures)
		get_tree().quit(1)
