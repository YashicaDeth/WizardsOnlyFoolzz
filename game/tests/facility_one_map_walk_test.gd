extends Node

## Job 5 proof on the production route: the opening's own player, moved by its
## own controller through real InputMap actions, walks from the Growing Floor
## through the east staff door, the service artery, the Service Arcade, rides
## the transit lift down, crosses the Lower Works, rides the heat elevator up
## and leaves through the Surface Gate. Zero Interstitial.travel, no scene
## change, never through a floor.

const VAT := preload("res://vat_chamber.tscn")
const LEG_TIMEOUT := 40.0

var failures: Array[String] = []
var vat: Node3D
var travelled := false
var lowest := 0.0


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	Engine.time_scale = 3.0
	get_tree().create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("FACILITY_ONE_MAP_WALK_RESULT failures=timeout")
		get_tree().quit(1))
	WorldHistory.clear_history()
	vat = VAT.instantiate()
	add_child(vat)
	for _frame in 4:
		await get_tree().physics_frame
	var scene_at_start := get_tree().current_scene
	var facility: Node3D = vat.facility_map
	check(facility != null and facility.player == vat.player, "the production vat owns the one facility player")
	# Skip the scripted opening beats (other suites own them): stand free in
	# the aisle with the staff door open, as after the breakout.
	vat.phase = "aisle"
	vat.breakout_complete = true
	vat.can_move = true
	if vat.intake != null:
		vat.intake.visible = false
	if vat.load_in != null:
		vat.load_in.visible = false
	vat._open_staff_door(false)
	vat.player.global_position = Vector3(4.0, 0.9, -2.5)
	vat.player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	lowest = vat.player.global_position.y
	var objective: Label = vat.get_node("HUD/Objective")

	check(await _walk(Vector3(9.5, 0, -2.5)), "walks through the east staff door into the artery")
	check(objective.text.contains("SERVICE ARCADE"), "past the staff door the objective names the arcade (%s)" % objective.text.replace("\n", " "))
	check(await _walk(Vector3(21.0, 0, -2.5)), "walks the service artery east")
	check(await _walk(Vector3(28.0, 0, -2.5)), "enters the Service Arcade")
	check(await _walk(Vector3(28.0, 0, -59.6)), "crosses the Service Arcade to the transit landing")
	check(objective.text.contains("TRANSIT LIFT"), "at the landing the objective names the transit lift")
	var transit: FacilityElevator = facility.lifts["transit"]
	check(await _walk(Vector3(28.0, 0, -62.0)), "steps into the transit car")
	vat._interact()
	check(await _until(func() -> bool: return transit.state == "moving"), "the transit car shuts and moves")
	check(await _until(func() -> bool: return transit.state == "open" and transit.stop == 0), "the transit car opens on 0D")
	check(absf(vat.player.global_position.y - (-12.0 + 0.85)) < 0.5, "the car set the body down on 0D (y %.2f)" % vat.player.global_position.y)
	check(await _walk(Vector3(28.0, 0, -70.0)), "walks out into the Lower Works")
	check(objective.text.contains("HEAT ELEVATOR"), "in the Lower Works the objective names the heat elevator")
	check(await _walk(Vector3(28.0, 0, -119.6)), "crosses the Lower Works to the heat elevator")
	var heat: FacilityElevator = facility.lifts["heat"]
	check(await _walk(Vector3(28.0, 0, -122.0)), "steps into the heat elevator")
	vat._interact()
	check(await _until(func() -> bool: return heat.state == "moving"), "the heat elevator shuts and climbs")
	check(await _until(func() -> bool: return heat.state == "open" and heat.stop == 1), "the heat elevator opens at the surface")
	check(vat.player.global_position.y > facility.SURFACE_Y, "the body stands on the surface level")
	check(objective.text.contains("SURFACE GATE"), "on the surface the objective names the gate")
	check(await _walk(Vector3(28.0, 0, -138.0)), "walks out through the Surface Gate")
	check(facility.exit_reached, "the surface gate exit is reached")
	check(not travelled, "zero Interstitial.travel from the vat to the surface gate")
	check(get_tree().current_scene == scene_at_start, "no scene change on the way")
	check(lowest > -12.5, "the body never fell through a floor (lowest %.2f)" % lowest)
	Input.action_release("move_forward")
	Engine.time_scale = 1.0
	print("FACILITY_ONE_MAP_WALK_RESULT failures=%d" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)


func _physics_process(_delta: float) -> void:
	if Interstitial.travelling:
		travelled = true
	if vat != null and vat.player != null and vat.can_move:
		lowest = minf(lowest, vat.player.global_position.y)


## Holds the real forward action and turns the opening's yaw toward the goal,
## exactly as a pad's stick and look would.
func _walk(goal: Vector3) -> bool:
	var player: CharacterBody3D = vat.player
	var ok := await _until(func() -> bool:
		var to := goal - player.global_position
		to.y = 0.0
		if to.length() < 0.5:
			return true
		vat.yaw = atan2(-to.x, -to.z)
		Input.action_press("move_forward")
		return false)
	Input.action_release("move_forward")
	player.velocity.x = 0.0
	player.velocity.z = 0.0
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
