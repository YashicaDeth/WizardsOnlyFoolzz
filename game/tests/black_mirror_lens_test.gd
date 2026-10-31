extends Node

## Agent 1 brief. "Do not solve darkness by merely increasing ambient
## brightness. Night should remain dark. The Black Mirror camera should
## become the meaningful navigation tool in extreme darkness." Verifies the
## real seam: the camera's own `environment` is what changes, the scene's
## `WorldEnvironment` (what the naked eye sees) is untouched either way, and
## the amplification is stronger at night than at noon rather than one fixed
## value regardless of the hour.

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
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Night vision is the phone's camera (Greg, 2026-09-24): the suite holds
	# the phone, so raising it is a lens test and not a possession test.
	hunt.handheld.possessed = true

	var world_env: Environment = hunt.get_node("WorldEnvironment").environment

	print("Black Mirror lens - off by default, the naked-eye view untouched")
	check(not hunt.black_mirror_active, "starts lowered")
	check(hunt.camera.environment == null, "the camera reads the scene's own WorldEnvironment by default")

	print("Black Mirror lens - raising it changes only the camera's own view")
	WorldClock.set_hour(2.0)
	hunt._toggle_black_mirror()
	check(hunt.black_mirror_active, "raised")
	check(hunt.camera.environment != null, "the camera now has its own environment")
	check(hunt.camera.environment != world_env, "a distinct resource, not the scene's own WorldEnvironment reassigned")
	check(hunt.get_node("WorldEnvironment").environment == world_env, "the scene's WorldEnvironment - what the naked eye sees - was never touched")
	check(bool(hunt.camera.environment.adjustment_enabled), "the lens actually applies a real grade, not an inert copy")
	var night_brightness: float = hunt.camera.environment.adjustment_brightness

	print("Black Mirror lens - it earns its keep at night, and stays honest at noon")
	WorldClock.set_hour(12.0)
	hunt._toggle_black_mirror()
	check(not hunt.black_mirror_active, "a second press lowers it")
	check(hunt.camera.environment == null, "and hands the naked-eye view straight back")
	hunt._toggle_black_mirror()
	var noon_brightness: float = hunt.camera.environment.adjustment_brightness
	check(noon_brightness < night_brightness, "noon amplifies far less than the middle of the night (%.2f vs %.2f)" % [noon_brightness, night_brightness])
	check(noon_brightness > 1.0, "but is not a pure no-op even then - the lens is always at least a real lens")

	print("Black Mirror lens - the phone's sensor is live, and needs the phone")
	var sensor = hunt._mirror
	check(sensor != null and sensor.active and sensor.visible, "raising it runs the BlackMirrorCamera sensor feed, not only a grade")
	hunt._toggle_black_mirror()
	check(not sensor.active, "lowering it stops the feed")
	hunt.dropped_handheld = RigidBody3D.new()
	hunt.add_child(hunt.dropped_handheld)
	hunt._toggle_black_mirror()
	check(not hunt.black_mirror_active and hunt.camera.environment == null, "with the phone on the ground there is nothing to raise")

	print("BLACK_MIRROR_LENS_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
