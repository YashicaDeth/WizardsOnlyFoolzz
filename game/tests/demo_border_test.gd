extends Node

## P2b. Locked regions must be refused by the world, and only in the demo —
## never by a disabled control, and never touching the mainline at all. Drive
## the real Hunt scene's own `_enforce_demo_territory()` and the real
## `ashbloom_holdings.gd` jurisdiction lookup rather than a stand-in border.

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

	# The Bone Yard itself, and Ossuary Works next door — real holding
	# centres from `ashbloom_holdings.gd`, not invented coordinates.
	var home_ground := Vector3(-155.0, 1.0, 0.0)
	var neighbour_ground := Vector3(135.0, 1.0, 0.0)

	# PLAY. The exact same call must be a no-op outside the demo — P2b.5/P2b.6,
	# one code path rather than a mainline copy that could quietly diverge.
	check(not WorldHistory.is_demo(), "starts in PLAY mode")
	hunt.player = neighbour_ground
	hunt.player_body.position = neighbour_ground - Vector3.UP * 0.6
	hunt._enforce_demo_territory()
	check(hunt.player == neighbour_ground, "PLAY mode never refuses any ground")
	check(hunt._demo_home_holding.is_empty(), "PLAY mode never even learns a home holding")

	# DEMO. Home ground is learned from wherever the player actually is,
	# rather than assumed to be "bone_yard" by name.
	WorldHistory.begin_demo()
	hunt.player = home_ground
	hunt.player_body.position = home_ground - Vector3.UP * 0.6
	hunt._enforce_demo_territory()
	check(hunt._demo_home_holding == "bone_yard", "home ground is learned from the player's real position")
	check(hunt.player == home_ground, "learning home ground does not itself refuse anything")

	# Crossing into a neighbouring holding is refused back onto home ground,
	# with outward momentum killed and the reason named rather than silent.
	hunt.player = neighbour_ground
	hunt.player_body.position = neighbour_ground - Vector3.UP * 0.6
	hunt.player_body.velocity = Vector3(4.0, 0.0, 0.0)
	hunt._enforce_demo_territory()
	check(hunt.player == home_ground, "crossing into another holding is refused back onto your own ground")
	check(hunt.player_body.velocity == Vector3.ZERO, "the refusal kills outward momentum rather than leaving you pressed against the line")
	check(hunt.prompt.text.findn("OSSUARY") != -1 and hunt.prompt.text.findn("CHOIR OF MARROW") != -1,
		"the refusal names the specific holding and who holds it, not a generic no")
	check(WorldHistory.event_count("demo_border_refused") == 1, "the refusal is written into history like the rest of the world")

	# Leaning on the same border again does not spam the ledger.
	hunt.player = neighbour_ground
	hunt.player_body.position = neighbour_ground - Vector3.UP * 0.6
	hunt._enforce_demo_territory()
	check(WorldHistory.event_count("demo_border_refused") == 1, "standing at the same refused border does not write a second event every frame")

	# Leaving and re-approaching is a new instance, not muted forever.
	hunt.player = home_ground
	hunt.player_body.position = home_ground - Vector3.UP * 0.6
	hunt._enforce_demo_territory()
	hunt.player = neighbour_ground
	hunt.player_body.position = neighbour_ground - Vector3.UP * 0.6
	hunt._enforce_demo_territory()
	check(WorldHistory.event_count("demo_border_refused") == 2, "leaving and re-approaching the border names it again")

	print("DEMO_BORDER_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
