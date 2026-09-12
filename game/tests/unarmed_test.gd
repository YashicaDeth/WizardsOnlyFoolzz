extends Node

## O5.8. "The body is the weapon system" was a claim the build could not
## support: the arsenal hands the player three weapons at spawn and never takes
## them away, so unarmed was not a state this game could be in.

const HUNT := preload("res://bone_yard_hunt.tscn")
const HunterArsenalScript := preload("res://systems/hunter_arsenal.gd")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _ready() -> void:
	print("O5.8 - viable and horrible")
	var hunt: Node = HUNT.instantiate()
	add_child(hunt)
	for _settle in 90:
		await get_tree().process_frame

	_check(not bool(hunt.get("bare_handed")), "you start with something in your hands")
	hunt.call("_put_the_weapons_down")
	_check(bool(hunt.get("bare_handed")), "and you can put it down")

	hunt.set("attack_cooldown", 0.0)
	var light: Dictionary = hunt.call("bare_hand_attack", false)
	hunt.set("attack_cooldown", 0.0)
	var heavy: Dictionary = hunt.call("bare_hand_attack", true)
	var cleaver: Dictionary = HunterArsenalScript.WEAPONS["sword"]

	_check(bool(light.get("accepted", false)), "a punch is a real attack")
	_check(float(light["damage"]) < float(cleaver["damage"]), "worth far less than a cleaver (%.0f vs %.0f)" % [float(light["damage"]), float(cleaver["damage"])])
	_check(float(light["cooldown"]) < float(cleaver["cooldown"]), "but it comes back faster (%.2fs vs %.2fs)" % [float(light["cooldown"]), float(cleaver["cooldown"])])
	_check(float(light["stamina"]) < float(cleaver["stamina"]), "and costs less to throw (%.0f vs %.0f)" % [float(light["stamina"]), float(cleaver["stamina"])])

	# The horrible part: you have to be inside their arms.
	_check(float(light["range"]) < float(cleaver["reach"]) * 0.5, "at under half the reach (%.2fm vs %.2fm)" % [float(light["range"]), float(cleaver["reach"])])
	_check(str(light["damage_type"]) == "blunt", "hands break rather than open — no cuts, no severing")

	# Damage per second is the honest test of "viable".
	var fist_dps: float = float(light["damage"]) / float(light["cooldown"])
	var blade_dps: float = float(cleaver["damage"]) / float(cleaver["cooldown"])
	_check(fist_dps > blade_dps * 0.4, "viable rather than a formality (%.0f dps vs %.0f)" % [fist_dps, blade_dps])
	_check(fist_dps < blade_dps, "and still clearly worse than a weapon")
	_check(float(heavy["damage"]) > float(light["damage"]), "a committed punch is worth more than a jab")

	# O5.9. It is thrown by an arm, and arms can be gone.
	var rig = hunt.get("player_rig")
	rig.severed.append("left_arm")
	rig.severed.append("right_arm")
	hunt.set("attack_cooldown", 0.0)
	var armless: Dictionary = hunt.call("bare_hand_attack", false)
	_check(not bool(armless.get("accepted", true)), "with no arms there is nothing to throw")
	_check(str(armless.get("reason", "")) == "no arms", "and it says why")

	# Picking a weapon back up leaves the bare-handed state.
	hunt.call("_equip_weapon", 0)
	_check(not bool(hunt.get("bare_handed")), "picking a weapon back up ends it")

	print("")
	if failures.is_empty():
		print("O5.8 PASS")
	else:
		print("FAIL: %d" % failures.size())
		for failure in failures:
			print("  - ", failure)
	get_tree().quit(0 if failures.is_empty() else 1)
