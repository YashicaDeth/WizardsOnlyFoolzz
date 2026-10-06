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
	# drug-70 added the materia station (sixth, after the vehicle pad, so the
	# indices below are unchanged).
	check(lab.stations.size() == 6, "six stations stand in the yard")

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
	await _vehicles()

	print("MECHANICS_LAB_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## Car-71: the plinth points at the cars; USE at a door handle starts the
## continuous entry. R2 drives it, a round dents it, USE gets out.
func _vehicles() -> void:
	lab.go_to(4)
	await _frames(2)
	await _press("interact")
	check(not lab.vehicles.driving() and lab.last_note == "WALK TO A DRIVER DOOR", "the vehicle plinth sends you to a real door")
	var car: RigidBody3D = lab.vehicles.cars[0]
	lab.player.global_position = lab.vehicles.driver.standing_point(car, VehicleDriver.DOOR_LEFT)
	await _frames(2)
	await _press("interact")
	await _seconds(0.3)
	check(lab.player_body.rigged != null and lab.player_body.rigged._clip == "Interact", "the free rig animation reaches for the door during entry")
	await _seconds(1.1)
	check(lab.vehicles.driving(), "USE at the driver handle opens the door and seats you")
	Input.action_press("pad_combat_r2")
	var first_peak := 0.0
	for _frame in 120:
		await get_tree().physics_frame
		first_peak = maxf(first_peak, float(car.signed_speed))
	Input.action_release("pad_combat_r2")
	check(first_peak > 2.0, "R2 drives it (%.1f m/s)" % first_peak)
	var other: RigidBody3D = lab.vehicles.cars[1]
	lab._land(other, other.to_global(Vector3(0, 0.2, -other.hull_size.z * 0.5)), other.global_basis.z, {"damage": 30.0}, "firearm", null)
	check((other.get_node("Damage") as VehicleDamage).max_crush > 0.0, "a round dents the other car")
	car.linear_velocity = Vector3.ZERO
	await _seconds(0.6)
	await _press("interact")
	await _seconds(1.2)
	check(not lab.vehicles.driving() and lab.camera.current, "USE gets you out and back to your own eyes")
	await _vehicle_melee(other)
	await _vehicle_teleport(car)
	await _vehicle_run(car)


## A blade dents a car but cannot take a steel door off; a round can.
func _vehicle_melee(other: RigidBody3D) -> void:
	var damage := other.get_node("Damage") as VehicleDamage
	var door_part := damage.door_part(VehicleDriver.DOOR_LEFT)
	check(not door_part.is_empty(), "the parked SUV keeps its driver door before the melee test (%s)" % [damage.detached])
	if door_part.is_empty():
		return
	var door: Node3D = door_part.impact_node
	var into := (other.global_position - door.global_position).normalized()
	# Repeated blows on one spot reach the crush cap, so the last blow alone
	# may dent nothing; the deepest of the six is the one that counts.
	var deepest := 0.0
	for i in 6:
		lab._land(other, door.global_position, into, {"damage": 44.0, "weapon": "cleaver"}, "melee", null)
		deepest = maxf(deepest, float(lab.last_hit.get("dent", 0.0)))
	check(not damage.detached.has("DoorLeft") and deepest > 0.0, "a cleaver dents the door but cannot take steel off")
	for i in 3:
		lab._land(other, door.global_position, into, {"damage": 30.0}, "firearm", null)
	check(damage.detached.has("DoorLeft"), "rounds take the same door off")


## The lab menu's teleport gets you out of the car first, even at speed.
func _vehicle_teleport(car: RigidBody3D) -> void:
	lab.vehicles.driver.car = car
	lab.vehicles.driver._enter_immediately(VehicleDriver.DOOR_LEFT)
	car.linear_velocity = -car.global_basis.z * 10.0
	await _frames(2)
	lab.go_to(0)
	await _frames(2)
	var plinth: Vector3 = lab.stations[0].plinth
	check(not lab.vehicles.driving() and lab.camera.current and Vector2(lab.player.global_position.x - plinth.x, lab.player.global_position.z - plinth.z).length() < 3.0, "the menu teleport gets you out of a moving car")


## Parked at the start line, full throttle down the lane reaches the wall past
## steel's ram tier, and steel comes off.
func _vehicle_run(car: RigidBody3D) -> void:
	var pad = lab.vehicles
	car.teleport(Transform3D(Basis(), pad.to_global(pad.CAR_AT)))
	await _seconds(0.6)
	var damage := car.get_node("Damage") as VehicleDamage
	var hits_before := damage.hits
	var detached_before := damage.detached.size()
	pad.driver.car = car
	pad.driver._enter_immediately(VehicleDriver.DOOR_LEFT)
	await _frames(2)
	hits_before = damage.hits
	Input.action_press("pad_combat_r2")
	var top := 0.0
	var waited := 0.0
	while damage.hits == hits_before and waited < 8.0:
		await get_tree().physics_frame
		waited += 1.0 / Engine.physics_ticks_per_second
		top = maxf(top, float(car.signed_speed))
	Input.action_release("pad_combat_r2")
	var tier_speed := sqrt(2.0 * MaterialToughness.ram_joules_per_tier * MaterialToughness.tier_of("steel_sheet") / car.mass)
	await _seconds(0.3)
	check(top >= tier_speed and damage.detached.size() > detached_before, "full throttle down the lane hits the wall at %.1f m/s (steel needs %.1f) and sheds %s" % [top, tier_speed, str(damage.detached.slice(detached_before))])
	car.linear_velocity = Vector3.ZERO
	await _frames(2)
	pad.driver.get_out(true)


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
