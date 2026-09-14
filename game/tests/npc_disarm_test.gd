extends Node

## O6.1. "You can be disarmed, and so can they." AN2.2 built the player's own
## half off arm.fatigue; an encounter actor has no arm, but footing (O5.10
## v2) is the same shape of number. Barely standing and hit hard enough to
## stagger takes the weapon; footing recovering past the same line gives it
## back.

const HUNT := preload("res://bone_yard_hunt.tscn")

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

	hunt._spawn_encounter_actor({"instance_id": "disarm_probe", "kind": "hostile"}, hunt.player + Vector3(0, -0.5, 2))
	var actor: Dictionary = hunt.encounter_actors.back()

	# Standing solidly: a hit hard enough to stagger does not take the weapon.
	actor["footing"] = 1.0
	hunt._apply_combat_response(actor, {"impulse": 40.0}, {})
	check(str(actor.get("state", "")) == "staggered", "a heavy enough hit still staggers a solid stance")
	check(not bool(actor.get("disarmed", false)), "but a solid stance does not lose the weapon over it")

	# Barely standing this time: the same hard hit takes it.
	actor["state"] = "hostile"
	actor["footing"] = 0.2
	var before_damage: int = hunt._actor_attack_damage(actor)
	var before_cycle: float = hunt._actor_attack_cycle(actor)
	hunt._apply_combat_response(actor, {"impulse": 40.0}, {})
	check(bool(actor.get("disarmed", false)), "hit hard while barely standing and the weapon goes")
	check(WorldHistory.recent_events(5).any(func(event): return str(event.get("type", "")) == "npc_disarmed"), "and it is a real, recorded event")

	var after_damage: int = hunt._actor_attack_damage(actor)
	var after_cycle: float = hunt._actor_attack_cycle(actor)
	check(after_damage < before_damage, "disarmed hits softer (%d -> %d)" % [before_damage, after_damage])
	check(after_cycle < before_cycle, "and swings faster, the way a fist does (%.2f -> %.2f)" % [before_cycle, after_cycle])

	# Footing recovers past the line and the grip comes back with it.
	hunt._update_encounter_actors(5.0)
	var recovered: Dictionary = hunt.encounter_actors.back()
	check(float(recovered.get("footing", 0.0)) >= hunt.STUMBLE_AT, "footing actually recovered past the line (%.2f)" % float(recovered.footing))
	check(not bool(recovered.get("disarmed", false)), "and the grip comes back with it")

	if failures.is_empty():
		print("npc disarm: they can lose it too")
		get_tree().quit(0)
	else:
		print("npc disarm FAILURES: ", failures)
		get_tree().quit(1)
