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
	print("COMBAT_INTEGRATION_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
