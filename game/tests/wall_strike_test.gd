extends Node

## AN2.3. The half `_resolve_strike()` used to leave open: it only ever
## recognised "connected with an actor" or "hit nothing," so a swing thrown at
## a wall read as a clean whiff — the weapon carrying through untouched
## instead of stopping on what it hit. `_attack_wall()` closes it. Proves a
## real swing thrown at a real wall answers through the arm the way a connect
## does (damped hard, not carried through), wears the weapon the way armour
## already does (AN2.4), scars the wall, and records the fact — and that a
## swing at open air with nothing in front of it still whiffs exactly as
## before, unaffected by any of it.

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

	hunt.player_body.position = Vector3(175, 0.9, 200)
	hunt.player = hunt.player_body.position + Vector3.UP * 0.6
	hunt.yaw = 0.0
	hunt.pitch = 0.0
	hunt._equip_weapon(0)
	await get_tree().physics_frame

	# Open air first: nothing ahead at all, the case `_resolve_strike()`
	# already handled before this pass.
	WorldHistory.clear_history()
	var condition_clean: float = hunt.arsenal.weapon_condition("sword")
	hunt.arm.velocity = Vector3(0, 0, 4.0)
	hunt.pending_attack = {"damage": 24.0, "impulse": 18.0, "damage_type": "cut", "range": 4.1, "weapon": "sword"}
	hunt._resolve_strike()
	check(hunt.arm.velocity.z > 4.0, "a swing at open air still carries through rather than stopping (%.2f)" % hunt.arm.velocity.z)
	check(is_equal_approx(hunt.arsenal.weapon_condition("sword"), condition_clean), "a whiff does not wear the weapon")
	check(WorldHistory.events.filter(func(e): return e.type == "melee_struck_wall").is_empty(), "no wall event from a swing that met nothing")

	# Now put a real wall dead ahead, in range of the same swing.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.5)
	shape.shape = box
	wall.add_child(shape)
	hunt.add_child(wall)
	wall.global_position = hunt.player + Vector3(0, 0, 2.5)
	await get_tree().physics_frame

	var probe: Dictionary = hunt._attack_wall(4.1)
	check(not probe.is_empty(), "the wall is actually in reach of the swing")
	check(probe.get("normal", Vector3.ZERO).z < 0.0, "the wall's own surface normal faces back at the player, not some default")

	hunt.arm.velocity = Vector3(0, 0, 4.0)
	hunt.pending_attack = {"damage": 24.0, "impulse": 18.0, "damage_type": "cut", "range": 4.1, "weapon": "sword"}
	hunt._resolve_strike()
	check(hunt.arm.velocity.z < 4.0, "a swing that meets a wall is damped, not carried through like a whiff (%.2f)" % hunt.arm.velocity.z)
	check(hunt.arsenal.weapon_condition("sword") < condition_clean, "meeting a wall wears the weapon the way meeting armour already does")
	var wall_events: Array = WorldHistory.events.filter(func(e): return e.type == "melee_struck_wall")
	check(wall_events.size() == 1, "the wall hit is recorded, once")

	if failures.is_empty():
		print("wall strike: a swing that meets stone finally answers, instead of reading as a whiff")
		get_tree().quit(0)
	else:
		print("wall strike FAILURES: ", failures)
		get_tree().quit(1)
