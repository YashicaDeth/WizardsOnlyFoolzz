extends Node

## AN2.2. A weapon you are barely holding is a weapon somebody can take.
## `arm.fatigue` (AN1.6) already measures grip looseness; this proves a hard
## hit while exhausted actually knocks the weapon free, a fresh grip does not
## give it up to the same hit, a light tap does not shake loose an exhausted
## grip either, and a carried severed limb (its own drop-on-wear mechanic)
## is not double-dipped into this one.

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

	hunt._equip_weapon(0)
	check(not hunt.bare_handed, "starts armed")

	# A fresh grip does not give a weapon up to a hard hit.
	hunt.arm.fatigue = 0.0
	hunt._wound_player(hunt.player + Vector3(0, 0, 3), 20.0, "cut")
	check(not hunt.bare_handed, "a fresh grip survives a hard blow (fatigue 0.0)")

	# Exhausted and hit hard: the weapon goes.
	hunt.arm.fatigue = 0.9
	hunt._wound_player(hunt.player + Vector3(0, 0, 3), 20.0, "cut")
	check(hunt.bare_handed, "an exhausted grip actually gives the weapon up")
	check(WorldHistory.recent_events(5).any(func(event): return str(event.get("type", "")) == "player_disarmed"), "and it is a real, recorded event")

	# Drawing again recovers it — this is a mid-fight setback, not a loss.
	hunt._equip_weapon(0)
	check(not hunt.bare_handed, "drawing again re-arms the same player")

	# Exhausted but the hit itself was light: not enough to shake it loose.
	hunt.arm.fatigue = 0.9
	hunt._wound_player(hunt.player + Vector3(0, 0, 3), 5.0, "cut")
	check(not hunt.bare_handed, "an exhausted grip still holds through a light tap")

	# A carried severed limb has its own condition/break mechanic (AN2.4-
	# shaped, already built for that one weapon) and must not also trigger
	# this check.
	hunt.carried_limb_index = 0
	check(not hunt._should_disarm(20.0), "a carried limb is not disarmed by this path even at full fatigue")

	if failures.is_empty():
		print("disarm: a weapon barely held is a weapon that can be taken")
		get_tree().quit(0)
	else:
		print("disarm FAILURES: ", failures)
		get_tree().quit(1)
