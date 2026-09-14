extends Node

## AS3.3/AS3.4. A layer has to actually cut a real storm's cost, and it has
## to actually show on the body — not just exist as an unread stat.

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

	var hunt: Node = HUNT.instantiate()
	add_child(hunt)
	for _settle in 30:
		await get_tree().process_frame

	# AS3.3: a real storm, forced, costs stamina at two different warmths.
	WorldHistory.chaos_magick_level = 0.95
	WorldHistory.chaos_magick_at_minute = WorldClock.minutes()
	var storm: Node3D = hunt.get("storm_weather")
	storm._process(0.1)

	Clothing.wear("player", "bare")
	hunt.set("stamina", 100.0)
	hunt.call("_update_storm_exposure", 1.0)
	var bare_stamina: float = hunt.get("stamina")

	Clothing.wear("player", "storm_oilskin")
	hunt.set("stamina", 100.0)
	hunt.call("_update_storm_exposure", 1.0)
	var oilskin_stamina: float = hunt.get("stamina")

	check(bare_stamina < 100.0, "a real storm actually costs bare stamina (%.2f)" % bare_stamina)
	check(oilskin_stamina > bare_stamina, "a warm layer cuts the same storm's cost (%.2f vs %.2f)" % [oilskin_stamina, bare_stamina])

	# AS3.4: the coat itself changes colour on the body.
	var hunter_appearance: Node = hunt.get("hunter_appearance")
	var coat: MeshInstance3D = hunter_appearance.details.get("Coat_Front")
	var bare_tint: Color = coat.mesh.material.albedo_color

	Clothing.wear("player", "lead_vest")
	hunter_appearance.sync_from_clothing()
	var vest_tint: Color = coat.mesh.material.albedo_color
	check(bare_tint != vest_tint, "wearing a different layer actually re-tints the coat on the body")

	if failures.is_empty():
		print("clothing integration: strategy you can feel and see")
		get_tree().quit(0)
	else:
		print("clothing integration FAILURES: ", failures)
		get_tree().quit(1)
