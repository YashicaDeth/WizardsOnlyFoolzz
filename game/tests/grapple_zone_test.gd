extends Node

## O3.3 verification. The clinch used to have no opinion about which limb it
## actually had — combat_ratio() already softened resistance for arm damage
## in general, but grabbing somebody by an arm that is already gone was
## identical to grabbing the one that is fine. This checks the hold picks the
## worst limb, leverages it specifically, and actually damages it while
## pressed.

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

	# --- a fresh body: the hold still has to pick something -----------------
	hunt._spawn_encounter_actor({"instance_id": "fresh_grip", "kind": "hostile"}, at)
	var fresh_actor: Dictionary = hunt.encounter_actors.back()
	fresh_actor.node.position = at
	await get_tree().physics_frame
	hunt.stamina = 100.0
	hunt._start_grapple()
	check(not hunt.grapple_zone.is_empty(), "an untouched body still gets a real grip zone (%s)" % hunt.grapple_zone)
	hunt._break_grapple()
	hunt.encounter_actors.erase(fresh_actor)
	(fresh_actor.node as Node3D).queue_free()

	# --- a body with one arm already wrecked: the hold finds it exactly ----
	hunt._spawn_encounter_actor({"instance_id": "hurt_grip", "kind": "hostile"}, at)
	var hurt_actor: Dictionary = hunt.encounter_actors.back()
	hurt_actor.node.position = at
	await get_tree().physics_frame
	hurt_actor.rig.hit("left_arm", 60.0, 20.0, "blunt")
	hunt.stamina = 100.0
	hunt._start_grapple()
	check(hunt.grapple_zone == "left_arm", "the hold grabs the limb that is actually worst off (%s)" % hunt.grapple_zone)

	# --- that grip is worth more than a grip on an untouched body -----------
	var advantage_before: float = hunt.grapple_advantage
	hunt._update_grapple(0.3)
	var gain_on_hurt_limb: float = hunt.grapple_advantage - advantage_before
	hunt._break_grapple()
	hunt.encounter_actors.erase(hurt_actor)
	(hurt_actor.node as Node3D).queue_free()

	hunt._spawn_encounter_actor({"instance_id": "control_grip", "kind": "hostile"}, at)
	var control_actor: Dictionary = hunt.encounter_actors.back()
	control_actor.node.position = at
	await get_tree().physics_frame
	hunt.stamina = 100.0
	hunt._start_grapple()
	var control_before: float = hunt.grapple_advantage
	hunt._update_grapple(0.3)
	var gain_on_fresh_limb: float = hunt.grapple_advantage - control_before
	check(gain_on_hurt_limb > gain_on_fresh_limb, "leverage through an already-broken limb outpaces the same hold on a whole one (%.4f vs %.4f)" % [gain_on_hurt_limb, gain_on_fresh_limb])
	hunt._break_grapple()
	hunt.encounter_actors.erase(control_actor)
	(control_actor.node as Node3D).queue_free()

	# --- pressing the hold actually damages the limb it is leveraging -------
	hunt._spawn_encounter_actor({"instance_id": "pressure_grip", "kind": "hostile"}, at)
	var pressed_actor: Dictionary = hunt.encounter_actors.back()
	pressed_actor.node.position = at
	await get_tree().physics_frame
	hunt.stamina = 100.0
	hunt._start_grapple()
	var zone_before: float = pressed_actor.rig.zone_health(hunt.grapple_zone)
	hunt.grapple_pushing_override = true
	for _tick in 20:
		hunt._update_grapple(0.05)
	hunt.grapple_pushing_override = null
	var zone_after: float = pressed_actor.rig.zone_health(hunt.grapple_zone)
	check(zone_after < zone_before, "pressing the hold for a full second actually costs the leveraged limb condition (%.1f -> %.1f)" % [zone_before, zone_after])

	print("GRAPPLE_ZONE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
