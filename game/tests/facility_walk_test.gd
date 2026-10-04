extends Node

## DESIGN/FACILITY.md: walk a body from the vat to the Surface Gate through the
## transit lift and the heat elevator, in one scene, with zero Interstitial
## travel. The body is driven by the facility's own movement code (bot_goal),
## and the lifts carry it physically: no teleport anywhere.

const FACILITY := preload("res://facility.tscn")
const LEG_TIMEOUT := 40.0

var failures: Array[String] = []
var facility: Node3D
var travelled := false
var lowest := 99.0


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	Engine.time_scale = 3.0
	# A compile error or a stuck leg must fail, not hang the runner.
	get_tree().create_timer(150.0, true, false, true).timeout.connect(func() -> void:
		print("FACILITY_WALK_RESULT failures=timeout")
		get_tree().quit(1))
	facility = FACILITY.instantiate()
	add_child(facility)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var scene_at_start := get_tree().current_scene
	var player: CharacterBody3D = facility.player
	check(player.global_position.distance_to(facility.START) < 0.6, "the body wakes in front of its vat on 0C")
	var transit: FacilityElevator = facility.lifts["transit"]
	var heat: FacilityElevator = facility.lifts["heat"]

	# 0C: vat, staff door, service artery, the arcade's length.
	for goal in [Vector3(4, 0, -2.5), Vector3(21.5, 0, -2.5), Vector3(28, 0, -2.5), Vector3(28, 0, -57.5)]:
		check(await _walk(goal), "walks to %s" % goal)
	check(await _walk(Vector3(28, 0, -59.6)), "reaches the transit lift landing")
	check(transit.state == "open" and transit.stop == 1, "the transit lift waits open at 0C")
	check(await _walk(Vector3(28, 0, -62.0)), "steps into the transit car")
	check(transit.rider_inside(player.global_position), "the body is inside the car")
	check(facility.interact(), "the car panel answers")
	var shut := await _until(func() -> bool: return transit.state == "moving")
	check(shut and transit.doors <= 0.0, "the doors shut before the car moves")
	await _seconds(2.0)
	check(transit.rider_inside(player.global_position) and player.global_position.y < -1.0, "mid-ride the body is carried down inside the car")
	check(transit.indicator.text.begins_with("DOWN"), "the floor indicator shows the way it is going")
	check(await _until(func() -> bool: return transit.state == "open"), "the car arrives and opens")
	check(absf(player.global_position.y - (-12.0 + 0.85)) < 0.4, "the car set the body down on 0D")
	check(transit.indicator.text == "0D LOWER WORKS", "the indicator names the level")

	# 0D: the Lower Works floor to the heat elevator.
	check(await _walk(Vector3(28, 0, -70.0)), "walks out north into the Lower Works")
	check(await _walk(Vector3(28, 0, -119.6)), "crosses the Lower Works to the heat elevator")
	check(await _walk(Vector3(28, 0, -122.0)), "steps into the heat elevator")
	check(facility.interact(), "the heat elevator panel answers")
	check(await _until(func() -> bool: return heat.state == "moving"), "the heat elevator closes and climbs")
	await _seconds(5.0)
	check(heat.rider_inside(player.global_position) and player.global_position.y > -5.0, "the body rides up the shaft in the car")
	check(await _until(func() -> bool: return heat.state == "open"), "the heat elevator opens at the surface")
	check(player.global_position.y > facility.SURFACE_Y, "the body stands on the surface level")
	check(await _walk(Vector3(28, 0, -138.0)), "walks out through the Surface Gate")
	check(facility.exit_reached, "the first zone exit is reached")
	check(not travelled, "zero Interstitial.travel from vat to the zone exit")
	check(get_tree().current_scene == scene_at_start, "no scene change on the way")
	check(lowest > -12.5, "the body never fell through a floor (lowest %.2f)" % lowest)
	Engine.time_scale = 1.0
	print("FACILITY_WALK_RESULT failures=%d" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)


func _physics_process(_delta: float) -> void:
	if Interstitial.travelling:
		travelled = true
	if facility != null and facility.player != null:
		lowest = minf(lowest, facility.player.global_position.y)


func _walk(goal: Vector3) -> bool:
	var player: CharacterBody3D = facility.player
	goal.y = player.global_position.y
	facility.bot_goal = goal
	var ok := await _until(func() -> bool:
		var to := goal - player.global_position
		to.y = 0.0
		return to.length() < 0.5)
	facility.bot_goal = null
	player.velocity = Vector3.ZERO
	if not ok:
		print("  stuck at ", player.global_position, " heading for ", goal)
	return ok


func _until(condition: Callable) -> bool:
	var clock := 0.0
	while clock < LEG_TIMEOUT:
		if condition.call():
			return true
		await get_tree().physics_frame
		clock += get_physics_process_delta_time()
	return false


func _seconds(duration: float) -> void:
	var clock := 0.0
	while clock < duration:
		await get_tree().physics_frame
		clock += get_physics_process_delta_time()
