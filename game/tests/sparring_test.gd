extends Node

## Sparring in the Hunt (Greg, 24 September): E at the post brings out a
## partner of your tier; padded blows count and do not wound; five clean
## hits win and move the next partner up a tier; losing gives the reason.

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
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	hunt.third_person = true
	hunt.lock_target = ""
	hunt.yaw = 0.0
	hunt.pitch = 0.0
	check(hunt.get_node_or_null("SparringPost") != null, "the Hunt has a sparring post")
	check(hunt.spar_tier() == "scavenger", "the first partner is a scavenger")
	hunt._start_spar()
	var partner: Dictionary = hunt.encounter_actors.back()
	check(bool(partner.get("sparring", false)) and str(partner.tier) == "scavenger", "E brings out a sparring partner of your tier")
	partner.node.position = hunt.player + Vector3(0, -1.6, 2.0)
	await get_tree().physics_frame
	hunt._toggle_lock()
	hunt.player_unseen = false
	hunt._equip_weapon(0)
	var wounds: int = partner.anatomy.wounds.size()
	for _hit in 5:
		partner["attack_time"] = hunt._actor_attack_cycle(partner) * 0.95
		hunt._attack_nearest_encounter_actor({"damage": 20.0, "impulse": 10.0, "damage_type": "cut", "range": 6.0, "weapon": "cleaver"})
	check(partner.anatomy.wounds.size() == wounds, "padded blows do not wound the partner")
	check(hunt.spar_bout.is_empty() and hunt.spar_tier() == "hunter", "five clean hits win, and the next partner is a hunter")
	check(hunt.prompt.text.contains("YOU WIN"), "and it says so: %s" % hunt.prompt.text)
	# A lost bout: five touches, no wounds, and the reason.
	hunt._start_spar()
	var second: Dictionary = hunt.encounter_actors.back()
	var health_before: int = hunt.health
	for _touch in 5:
		second["attack_side"] = "low"
		hunt._note_incoming("low", {"damage": 9.0, "blocked": false, "parried": false})
		hunt._spar_struck(second, {"damage": 9.0, "blocked": false, "parried": false})
	check(hunt.spar_bout.is_empty() and hunt.health == health_before, "five touches lose the bout, and nobody bleeds")
	check(hunt.prompt.text.contains("YOU LOSE") and hunt.prompt.text.contains("LOW"), "losing says what beat you: %s" % hunt.prompt.text)
	check(hunt.spar_tier() == "hunter", "losing keeps your tier")
	print("SPARRING_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
