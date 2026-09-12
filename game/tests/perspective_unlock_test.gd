extends Node

## M1.5 verification. `third_person_unlocked()` is a pure read of history and
## could always flip true with nobody pressing anything — the failure mode is
## a permission granted silently in the background. This asserts the flip
## itself fires a beat exactly once, rather than trusting it looks right.

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

	check(not hunt.third_person_unlock_announced, "starts unannounced")
	var prompt_before: String = hunt.prompt.text
	hunt._update_hud()
	check(not hunt.third_person_unlock_announced, "a tick with no qualifying kill announces nothing")
	check(hunt.prompt.text == prompt_before, "and leaves the prompt alone")
	check(WorldHistory.event_count("third_person_unlocked") == 0, "and writes nothing to history")

	# Craft exactly what third_person_unlocked() reads: one melee hit landed,
	# and a resolution against someone the world already rated dangerous.
	WorldHistory.record_event("melee_body_hit", {"target": "test_boss", "location": hunt.HUNT_LOCATION})
	WorldHistory.register_subject("test_boss", {"name": "Test Boss", "kind": "person", "elo": 1200, "grudge": 0, "rival": true})
	WorldHistory.record_event("execution", {"subject_id": "test_boss"})
	check(hunt.third_person_unlocked(), "the read itself is true once a rated kill lands")

	var kick_before: Vector2 = hunt.impact_feel.kick
	hunt._update_hud()
	check(hunt.third_person_unlock_announced, "the edge trigger fires on the first qualifying tick")
	check(hunt.prompt.text != prompt_before and not hunt.prompt.text.is_empty(), "the prompt carries the beat, not silence")
	check(WorldHistory.event_count("third_person_unlocked") == 1, "the moment itself becomes a fact in history")
	check(hunt.impact_feel.kick != kick_before or hunt.impact_feel.shake > 0.0, "the camera actually moves for it")

	# The permission was never a quiet one — F itself must already work.
	hunt.third_person = false
	check(hunt.third_person_unlocked(), "and pressing F would now be honoured, not refused")

	var announced_prompt: String = hunt.prompt.text
	hunt._update_hud()
	check(WorldHistory.event_count("third_person_unlocked") == 1, "a second tick does not announce it twice")
	check(hunt.prompt.text == announced_prompt, "and does not keep stomping the prompt line")

	print("PERSPECTIVE_UNLOCK_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
