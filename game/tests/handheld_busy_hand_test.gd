extends Node

## C6.1 `v6`. The screen being visible is not enough: crossing the physical
## raise threshold must make the attack hand unavailable before the arsenal
## spends ammo, starts windup, or enters cooldown.

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
	await get_tree().process_frame

	# Control: with the device pocketed, the ordinary melee path begins a real
	# windup. This proves the later refusal is the handheld gate, not a broken
	# arsenal or an unrelated cooldown.
	hunt.handheld.raised = 0.0
	hunt.attack_cooldown = 0.0
	hunt.strike_windup = -1.0
	hunt.pending_attack = {}
	hunt._attack(false)
	check(not hunt.pending_attack.is_empty(), "a pocketed-device attack enters the arsenal normally")
	check(hunt.strike_windup >= 0.0, "the control attack starts a real windup")

	# Same clean state, now past the held threshold.
	hunt.attack_cooldown = 0.0
	hunt.strike_windup = -1.0
	hunt.pending_attack = {}
	hunt.handheld.raised = 1.0
	hunt._attack(false)
	check(hunt.pending_attack.is_empty(), "a raised handheld leaves no weapon action pending")
	check(hunt.strike_windup < 0.0, "the occupied hand never starts a strike windup")
	check(is_zero_approx(hunt.attack_cooldown), "the refusal happens before combat cooldown is spent")

	print("HANDHELD_BUSY_HAND_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
