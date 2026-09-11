extends Node

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
	hunt.player_body.position = Vector3(175, 0.9, 125)
	hunt.player = hunt.player_body.position + Vector3.UP * 0.6
	hunt.yaw = 0.0
	hunt.pitch = 0.0
	hunt.third_person = false
	hunt._update_camera()
	hunt._spawn_encounter_actor({"instance_id": "armed_target", "kind": "hostile", "summary": "ballistic target"}, hunt.player + Vector3(0, 0, 6))
	var actor: Dictionary = hunt.encounter_actors.back()
	actor.node.position = hunt.player + Vector3(0, -0.5, 6)
	await get_tree().physics_frame
	hunt._equip_weapon(1)
	var shell_before := int(hunt.arsenal.ammo.shotgun.loaded)
	hunt._attack()
	check(int(hunt.arsenal.ammo.shotgun.loaded) == shell_before - 1, "live Hunt input fires a chambered shotgun shell")
	check(actor.anatomy.wounds.size() > 0, "live pellets resolve against the NPC BaselineHuman")
	var wounded_zones: Array[String] = []
	for wound in actor.anatomy.wounds:
		var zone := str(wound.get("zone", ""))
		if not wounded_zones.has(zone):
			wounded_zones.append(zone)
	check(not wounded_zones.is_empty() and wounded_zones.all(func(zone): return BaselineHuman.ZONES.has(zone)), "firearm reports canonical anatomy zones %s" % str(wounded_zones))
	check(WorldHistory.recent_events(12).any(func(event): return str(event.get("type", "")) == "weapon_fired"), "weapon discharge enters world history")

	# Lock-on: the verb that makes third-person combat aimable at all.
	hunt.third_person = true
	hunt.lock_target = ""
	# A fresh body: the shotgun target above may already be down or dead, and a
	# lock is only ever offered on someone still standing.
	var lock_at: Vector3 = hunt.player + Vector3(0, -0.5, 5)
	hunt._spawn_encounter_actor({"instance_id": "lock_subject", "kind": "hostile"}, lock_at)
	var locked_actor: Dictionary = hunt.encounter_actors.back()
	locked_actor.node.position = lock_at
	await get_tree().physics_frame
	hunt._toggle_lock()
	check(hunt.lock_target == str(locked_actor.subject_id), "lock acquires the nearby hostile (%s)" % hunt.lock_target)
	hunt._steer_lock(0.5)
	check(hunt.lock_screen.x >= 0.0, "locked target reports a reticle position")
	# A second body closer to the player must not steal the swing.
	var closer: Vector3 = hunt.player + Vector3(0.4, -0.5, 1.2)
	hunt._spawn_encounter_actor({"instance_id": "lock_decoy", "kind": "hostile"}, closer)
	var decoy: Dictionary = hunt.encounter_actors.back()
	decoy.node.position = closer
	var decoy_wounds: int = decoy.anatomy.wounds.size()
	var locked_wounds: int = locked_actor.anatomy.wounds.size()
	hunt._equip_weapon(0)
	hunt._attack_nearest_encounter_actor({"damage": 20.0, "impulse": 10.0, "damage_type": "cut", "range": 9.0, "weapon": "cleaver"})
	check(decoy.anatomy.wounds.size() == decoy_wounds, "a nearer body does not steal a locked strike")
	check(locked_actor.anatomy.wounds.size() > locked_wounds, "the locked target takes the strike")
	hunt._toggle_lock()
	check(hunt.lock_target.is_empty(), "lock releases")

	print("COMBAT_INTEGRATION_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
