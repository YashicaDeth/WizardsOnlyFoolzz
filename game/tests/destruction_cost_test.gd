extends Node

## AB1.6. Measures the destruction state that exists today before walls and
## buildings are allowed to join it: all six arena barricades broken at the
## PERFORMANCE fragment cap, plus every detachable panel on the player's car.
##
## The intact/broken delta is reported, not asserted. A hardware timing delta
## is noisy and shader warm-up can make the second sample look cheaper. The
## contract is the useful invariant: the fully broken state must still hold the
## region's explicit 16.67 ms budget, and the live physics objects must remain
## inside their production caps.

const DERBY_SCENE := preload("res://rift_derby.tscn")
const WORLD_DEBRIS := preload("res://systems/world_debris.gd")
const BREAKABLE_PROP := preload("res://systems/breakable_prop.gd")
const WORLD_LOOK := preload("res://systems/world_look.gd")
const SAMPLE_FRAMES := 120
const PLAYER_PARTS := ["BumperFront", "DoorLeft", "Hood", "DoorRight", "Wheel0", "BumperRear"]

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	get_window().size = Vector2i(1920, 1080)
	WORLD_LOOK.set_quality_name("PERFORMANCE")
	WORLD_LOOK.apply_viewport_quality(get_viewport())
	OS.set_environment("ATG_HUD_CAPTURE", "1")

	var derby: Node = DERBY_SCENE.instantiate()
	derby.include_breakables_in_test = true
	add_child(derby)
	for _warm in 180:
		await get_tree().process_frame

	var intact := await _sample_frames()
	derby.round_state = "active"
	for prop: Node in derby.breakable_props:
		derby._on_vehicle_impact(prop, 24.0, 1.0)
	for part_name: String in PLAYER_PARTS:
		derby._detach_vehicle_part(derby.boat, part_name, Vector3.FORWARD)

	# Include the allocation/collision spike in the measurement. This is the
	# expensive moment a player can actually create, not only the later state
	# after every fragment has gone to sleep.
	var broken := await _sample_frames()
	var fragment_count := WORLD_DEBRIS.pool_count(BREAKABLE_PROP.FRAGMENT_POOL)
	var vehicle_part_count := WORLD_DEBRIS.pool_count(derby.VEHICLE_PART_POOL)

	print("destruction intact: median %.2f ms  p95 %.2f ms" % [intact.median, intact.p95])
	print("destruction broken: median %.2f ms  p95 %.2f ms  delta %+.2f ms" % [
		broken.median, broken.p95, broken.median - intact.median])
	print("destruction bodies: %d barricade fragments / %d vehicle panels" % [
		fragment_count, vehicle_part_count])
	check(fragment_count == BREAKABLE_PROP.fragment_budget(),
		"six broken barricades fill but do not exceed the PERFORMANCE fragment cap (%d)" % fragment_count)
	check(vehicle_part_count == PLAYER_PARTS.size() and vehicle_part_count <= derby.vehicle_part_budget(),
		"all player panels persist inside the shared PERFORMANCE vehicle-part cap (%d/%d)" % [vehicle_part_count, derby.vehicle_part_budget()])
	check(float(broken.median) <= WORLD_LOOK.FRAME_BUDGET_MS,
		"the isolated fully broken fixture holds the 16.67 ms / 60 FPS median budget (%.2f ms)" % broken.median)
	print("DESTRUCTION_COST_TEST_RESULT failures=%d" % failures.size())
	WORLD_DEBRIS.clear_pool(BREAKABLE_PROP.FRAGMENT_POOL)
	WORLD_DEBRIS.clear_pool(derby.VEHICLE_PART_POOL)
	derby.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	OS.set_environment("ATG_HUD_CAPTURE", "")
	get_tree().quit(0 if failures.is_empty() else 1)


func _sample_frames() -> Dictionary:
	var timings: Array[float] = []
	for _sample in SAMPLE_FRAMES:
		var began := Time.get_ticks_usec()
		await get_tree().process_frame
		timings.append(float(Time.get_ticks_usec() - began) / 1000.0)
	timings.sort()
	var median := timings[timings.size() / 2]
	var p95_index := mini(timings.size() - 1, ceili(float(timings.size()) * 0.95) - 1)
	return {"median": median, "p95": timings[p95_index]}
