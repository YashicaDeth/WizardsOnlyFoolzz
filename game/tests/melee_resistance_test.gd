extends Node

## AN2.3. `arm.strike()` took a hardcoded 0.65 on every connecting blow —
## armour, bone and a bare torso all felt identical through the weapon. This
## proves `_melee_resistance()` actually varies with what was hit, and that a
## real swing through `_attack_nearest_encounter_actor()` feeds it real data
## rather than the old constant.

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

	# Pure function first: bone density alone, no armour either side.
	var head_bare: float = hunt._melee_resistance("head", {"absorbed": 0.0})
	var torso_bare: float = hunt._melee_resistance("torso", {"absorbed": 0.0})
	var arm_bare: float = hunt._melee_resistance("left_arm", {"absorbed": 0.0})
	check(head_bare > torso_bare and torso_bare > arm_bare, "a skull, a ribcage and a limb do not stop a blade equally (%.2f / %.2f / %.2f)" % [head_bare, torso_bare, arm_bare])

	# Armour on top of the same zone raises it further — the two causes stack
	# rather than one silently standing in for the other.
	var torso_armoured: float = hunt._melee_resistance("torso", {"absorbed": 0.7})
	check(torso_armoured > torso_bare, "plate under the same ribs answers harder than skin alone (%.2f -> %.2f)" % [torso_bare, torso_armoured])
	check(hunt._melee_resistance("torso", {"absorbed": 1.0}) <= 0.95, "resistance never reaches a dead stop")

	# A real swing: an unarmoured target versus one with real hardware
	# installed in the zone the blow actually lands in.
	hunt.player_body.position = Vector3(175, 0.9, 125)
	hunt.player = hunt.player_body.position + Vector3.UP * 0.6
	hunt.yaw = 0.0
	hunt.pitch = 0.0
	hunt._spawn_encounter_actor({"instance_id": "resistance_bare", "kind": "hostile"}, hunt.player + Vector3(0, -0.5, 4))
	var bare: Dictionary = hunt.encounter_actors.back()
	bare.node.position = hunt.player + Vector3(0, -0.5, 4)
	await get_tree().physics_frame
	hunt._attack_nearest_encounter_actor({"damage": 20.0, "impulse": 10.0, "damage_type": "cut", "range": 9.0, "weapon": "cleaver"})
	var bare_zone: String = str((bare.anatomy.wounds.back() as Dictionary).get("zone", "torso"))
	var bare_resistance: float = hunt._last_melee_resistance
	check(is_equal_approx(bare_resistance, hunt._melee_resistance(bare_zone, bare.anatomy.wounds.back())), "a real swing records the same resistance the pure function would compute for that same wound")

	# Strictly closer than `bare`, so the same attack call unambiguously
	# targets this one instead — ties go to whichever was spawned first.
	hunt._spawn_encounter_actor({"instance_id": "resistance_armoured", "kind": "hostile"}, hunt.player + Vector3(0, -0.5, 2))
	var armoured: Dictionary = hunt.encounter_actors.back()
	armoured.node.position = hunt.player + Vector3(0, -0.5, 2)
	# A synthetic part with an explicit zone and armour rather than a named
	# catalog entry, since a named entry's own authored zone (e.g. "ceramic
	# sternum" is always torso) would not necessarily match wherever this
	# aim actually landed.
	armoured.anatomy.install_part(bare_zone, {"id": "test plate", "zone": bare_zone, "armor": 0.4, "max_condition": 100.0, "condition": 100.0})
	await get_tree().physics_frame
	hunt._attack_nearest_encounter_actor({"damage": 20.0, "impulse": 10.0, "damage_type": "cut", "range": 9.0, "weapon": "cleaver"})
	check(hunt._last_melee_resistance > bare_resistance, "the same blow through real plate answers harder than the same blow through nothing (%.2f -> %.2f)" % [bare_resistance, hunt._last_melee_resistance])

	if failures.is_empty():
		print("melee resistance: armour and bone finally answer differently")
		get_tree().quit(0)
	else:
		print("melee resistance FAILURES: ", failures)
		get_tree().quit(1)
