extends Node

const HUNT := preload("res://bone_yard_hunt.tscn")
const ARSENAL := preload("res://systems/hunter_arsenal.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var hunt := HUNT.instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	hunt.encounter_actors.clear()
	hunt.player = Vector3(0, 1.5, 0)
	hunt.player_body.position = Vector3(0, 0.9, 0)
	WorldClock.set_hour(13.0)

	# Mere proximity is not consent to an attack. Before perception resolves,
	# even a body inside melee range cannot run the attack clock.
	hunt._spawn_encounter_actor({"instance_id": "pacing_probe", "kind": "hostile"}, Vector3(0, 0, 2.2))
	var actor: Dictionary = hunt.encounter_actors.back()
	var health_before: int = hunt.health
	hunt._update_encounter_actors(5.0)
	check(hunt.health == health_before and is_zero_approx(float(actor.get("attack_time", 0.0))),
		"an undetected close actor cannot attack by proximity alone")

	# Detection begins a visible reaction window. It cannot be skipped by one
	# large update, and the same actor pursues after that window ends.
	hunt._update_perception(0.1)
	check(float(actor.get("notice_remaining", 0.0)) == hunt.ENCOUNTER_NOTICE_SECONDS and str(actor.state) == "noticing",
		"detection begins the authored reaction window")
	hunt._update_encounter_actors(1.0)
	check(hunt.health == health_before and str(actor.state) == "noticing",
		"the player can orient or leave while the hostile reacts")
	actor.node.global_position = Vector3(0, 0, 8.0)
	hunt._update_encounter_actors(2.0)
	hunt._update_encounter_actors(0.5)
	check((actor.node as CharacterBody3D).velocity.length() > 0.0,
		"pursuit starts normally after the reaction window")

	# Mercy Nine now expresses the anatomy model instead of bypassing it: the
	# first precise hit leaves a severe wound; the follow-up destroys the brain.
	var rig := BaselineHuman.new()
	rig.gore = false
	add_child(rig)
	rig.build("durability_probe")
	var pistol_damage := float(ARSENAL.WEAPONS.sidearm.damage)
	rig.hit("head", pistol_damage, float(ARSENAL.WEAPONS.sidearm.impulse), "ballistic", "brain")
	check(not rig.anatomy.dead and not rig.anatomy.downed and float(rig.anatomy.organs.brain.health) > 0.0,
		"one Mercy Nine head hit wounds but does not erase a fresh body")
	check(rig.anatomy.wounds.size() == 1 and float(rig.anatomy.zones.head.health) < float(AnatomyComponent.DEFAULT_ZONES.head.health),
		"that first hit remains a located wound on the shared anatomy")
	rig.hit("head", pistol_damage, float(ARSENAL.WEAPONS.sidearm.impulse), "ballistic", "brain")
	check(rig.anatomy.dead and bool(rig.anatomy.organs.brain.ruptured),
		"a deliberate follow-up remains lethal rather than making a sponge")

	print("ENCOUNTER_PACING_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
