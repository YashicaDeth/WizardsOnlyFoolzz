extends Node

## Job 1: the mechanics lab loads, every station is there, and each one's
## system answers one input through the real InputMap actions (USE on the
## plinth, START menu, FIRE / SWING with the v0.1 weapons).

var failures: Array[String] = []
var lab: Node3D


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	BloodPool.clear()
	lab = load("res://lab/mechanics_lab.tscn").instantiate()
	add_child(lab)
	await _frames(3)
	check(lab.stations.size() == 5, "five stations stand in the yard")

	# START opens the station menu; down once and accept goes to the second.
	await _press("pause")
	check(lab.menu_open, "START opens the station menu")
	await _press("ui_down")
	await _press("ui_accept")
	var second: Vector3 = lab.stations[1].plinth
	check(not lab.menu_open and Vector2(lab.player.global_position.x - second.x, lab.player.global_position.z - second.z).length() < 3.0, "the menu takes you to the chosen plinth")

	await _liquid()
	await _weather()
	await _destruction()
	await _bodies()

	print("MECHANICS_LAB_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _liquid() -> void:
	lab.go_to(0)
	await _frames(2)
	await _press("interact")
	check(lab.liquid.broken, "USE on the liquid plinth breaks the tank")
	await _seconds(1.2)
	check(BloodPool.pool_count(lab) > 0, "the spill pools on the floor (%d pools)" % BloodPool.pool_count(lab))
	check(lab.liquid.pouring(), "and the fluid pours as particles")
	var before: int = lab.liquid.splashes
	var tank: Vector3 = lab.liquid.glass_body.global_position
	check(lab.liquid.touch(Vector3(tank.x, 0, tank.z + 0.9)), "a step in the spill splashes")
	check(lab.liquid.splashes > before, "and the splash is counted")


func _weather() -> void:
	lab.go_to(2)
	await _frames(2)
	var weather = lab.weather
	await _press("interact")
	check(weather.state == "rain", "USE on the weather plinth steps clear to rain")
	check(weather.storm.severity() > 0.0, "and drives the game's own StormWeather")
	await _frames(2)
	check(bool((weather.storm.get_node("Rain") as GPUParticles3D).emitting), "the rain falls")
	weather.apply("acid")
	var open_before: float = weather._hp(weather.open_dummy)
	var covered_before: float = weather._hp(weather.covered_dummy)
	for tick in 4:
		weather._process(1.0)
	check(weather.wetness > 0.0, "open ground gets wet")
	check(weather.etch > 0.0, "acid etches the steel cabinet (%.2f)" % weather.etch)
	check(weather._hp(weather.open_dummy) < open_before, "acid burns the dummy in the open")
	check(is_equal_approx(weather._hp(weather.covered_dummy), covered_before), "and not the dummy under the roof")
	weather.apply("clear")


func _destruction() -> void:
	lab.go_to(3)
	await _frames(2)
	var station = lab.destruction
	var crate: BreakableProp = null
	for prop: BreakableProp in station.props:
		if prop.kind == "crate":
			crate = prop
			break
	lab.arsenal.select_weapon("sidearm")
	await _aim(crate.global_position)
	await _press("attack")
	await _seconds(0.3)
	# Whichever crate the round met first (they stand in a stack).
	var struck: BreakableProp = station.get_node_or_null(str(lab.last_hit.get("id", "")))
	check(struck != null and struck.kind == "crate" and struck.broken, "a pistol round breaks a crate through WorldBreak (%s)" % str(lab.last_hit))
	check(struck != null and struck.get_children().any(func(child: Node) -> bool: return child.name.contains("_Cell_")), "into the Blender cells")
	# The open ground takes a hole.
	await _seconds(0.4)
	await _aim(lab.player.global_position + Vector3(0.6, -0.9, -1.2))
	await _press("attack")
	await _seconds(0.3)
	check(lab.ballistics.marks.any(func(mark: Node) -> bool: return is_instance_valid(mark) and mark.name.begins_with("GroundHole")), "a round into the open ground digs a hole")
	# The cleaver on the wall: since lab-47 the wall is tiered voxels (Greg,
	# 5 Oct, Teardown-like), not four panels, so the blow takes brick cells.
	# Job 3: the HOTLINE CLEAVER, with a windup before it lands.
	lab.arsenal.select_weapon("cleaver")
	var wall: VoxelStructure = station.brick_wall
	var cells_before := wall.solid_count()
	var face := wall.to_global(Vector3(wall.size) * wall.voxel * Vector3(0.5, 0.5, 1.0))
	lab.player.global_position = face + Vector3(0, 0.0, 1.6)
	await _frames(2)
	await _aim(face)
	await _press("attack")
	await _seconds(0.6)
	check(wall.solid_count() < cells_before, "the cleaver knocks brick out of the voxel wall (%d -> %d)" % [cells_before, wall.solid_count()])
	# The plinth stands back from the walls (lab-47: its sign was in the shot).
	lab.go_to(3)
	await _frames(2)
	await _press("interact")
	check(station.broken_count() == 0, "USE on the destruction plinth rebuilds it all")


func _bodies() -> void:
	lab.go_to(1)
	await _frames(2)
	await _press("interact")
	check(lab.bodies.xray, "USE on the bodies plinth turns the X-ray on")
	var rig: BaselineHuman = lab.bodies.rigs()[1]
	var before := rig.zone_health("torso")
	await _seconds(0.7)
	lab.arsenal.select_weapon("cleaver")
	lab.player.global_position = rig.global_position + Vector3(0, 1.0, 1.4)
	await _frames(2)
	await _aim(rig.global_position + Vector3(0, 1.2, 0))
	await _press("attack")
	await _seconds(0.6)
	check(str(lab.last_hit.get("what", "")) == "body", "the cleaver lands on a dummy")
	var zone := str(lab.last_hit.get("zone", "torso"))
	check(rig.zone_health(zone) < (before if zone == "torso" else 1000.0), "and wounds it (%s)" % zone)


func _aim(point: Vector3) -> void:
	await _frames(1)
	var eye: Vector3 = lab.camera.global_position
	var to := point - eye
	lab.yaw = atan2(-to.x, -to.z)
	lab.pitch = atan2(to.y, Vector2(to.x, to.z).length())
	await _frames(2)


func _press(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	# Parsed events are flushed on the next idle frame, not the physics one.
	await get_tree().process_frame
	await get_tree().process_frame
	await _frames(1)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame
	await get_tree().process_frame


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().physics_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
