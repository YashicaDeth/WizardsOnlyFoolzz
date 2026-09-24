extends Node

## Bullets and blades break things (DESIGN/GOAL_LOOP_2.md 0.1): through the
## Hunt's own round and melee paths, a streetlight and a barricade take
## damage, break, and the world records it.

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
	check(hunt.breakables.size() == 4, "the Hunt has things that break (%d)" % hunt.breakables.size())
	var light: StreetLight = hunt.breakables[0]
	var barricade: BreakableProp = hunt.breakables[2]

	# Rounds: the Hunt's own world-hit branch, as Ballistics reports it.
	for shot in 3:
		hunt._on_round_hit({"collider": light, "position": light.global_position + Vector3(0, 4.0, 0), "direction": Vector3.FORWARD, "calibre": "pistol", "energy": 1.0, "shooter": "player", "payload": {"damage": 24.0, "weapon": "sidearm"}})
	check(light.condition() < 0.4, "three pistol rounds knock a streetlight down to %s (%.2f)" % [light.band(), light.condition()])
	check(str(hunt.last_world_break.get("what", "")) == "object", "the round reached it through WorldBreak")
	for shot in 2:
		hunt._on_round_hit({"collider": light, "position": light.global_position + Vector3(0, 4.0, 0), "direction": Vector3.FORWARD, "calibre": "pistol", "energy": 1.0, "shooter": "player", "payload": {"damage": 24.0, "weapon": "sidearm"}})
	check(light.band() == "hanging", "keep shooting and it hangs by its cable (%s)" % light.band())

	# Blades: the melee wall branch, pointed at the barricade.
	hunt.player = barricade.global_position + Vector3(0, 0.8, 1.6)
	hunt.yaw = PI
	hunt.pitch = -0.25
	await get_tree().physics_frame
	var wall: Dictionary = hunt._attack_wall(4.0)
	check(wall.get("collider") == barricade, "a swing at the barricade meets the barricade")
	for blow in 3:
		hunt.pending_attack = {"damage": 24.0, "impulse": 10.0, "damage_type": "cut", "range": 4.0, "weapon": "sword", "kind": "melee"}
		hunt._resolve_strike()
	check(barricade.broken, "blows break the barricade apart (integrity %.1f)" % barricade.integrity)
	check(barricade.fragment_count() > 0, "into real fragments (%d)" % barricade.fragment_count())
	check(WorldHistory.event_count("world_object_struck") >= 6, "every hit on the world is filed (%d)" % WorldHistory.event_count("world_object_struck"))
	check(WORLD_BREAK_DOOR_OK(), "a door hit by a gun hears a gun")
	print("WORLD_BREAK_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func WORLD_BREAK_DOOR_OK() -> bool:
	var WB = load("res://systems/world_break.gd")
	return WB.door_weapon("sidearm", "firearm") == "gun" and WB.door_weapon("sword", "melee") == "axe" and WB.door_weapon("", "melee") == "body"
