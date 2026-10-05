extends Node3D

## Station 5: the vehicle pad (lab-53). Two cars that crumple, shed parts and
## lose their engines (`VehicleDamage` on the derby's chassis), a ramp, and a
## concrete voxel wall that answers a ram by the toughness table. The plinth
## points at the pad; entry exists only at a door handle (driver or passenger). Driving:
## R2 throttle, L2 brake/reverse, left stick steer, R1 handbrake, Cross horn.

const TITLE := "VEHICLE PAD"
const VERB := "TRY THE CARS"
const PLINTH := Vector3(-5.2, 0, 4.6)
const HINT := "DRIVING  R2/W THROTTLE  L2/S BRAKE  R1/SPACE HANDBRAKE  TRIANGLE/F VIEW  CROSS/H HORN"
## Stretch dial: seat dragging needs combat ownership/reaction work. Kept off
## until that follow-through exists; ordinary passenger-door entry is live in
## VehicleDriver.begin_entry(car, VehicleDriver.DOOR_RIGHT).
const ALLOW_SEAT_DRAG := false
## The run-up lane: the sedan parks at its south end, nose to the crash wall
## under the roof, about 24 m of straight between them (the yard's east side,
## clear of the pillars and the bodies station), so full throttle from parked
## arrives past steel's ram tier (about 14 m/s for the sedan).
const LANE_X := 4.0
const CAR_AT := Vector3(LANE_X, 0.95, 5.2)
const SECOND_AT := Vector3(-3.0, 0.95, -4.0)
const WALL_AT := Vector3(LANE_X, 0, -21.5)
const RAMP_AT := Vector3(-6.5, 0, -8.0)

var lab: Node3D
var cars: Array[RigidBody3D] = []
var driver: VehicleDriver
var wall: VoxelStructure


func build(owner_lab: Node3D) -> void:
	lab = owner_lab
	var paint: StandardMaterial3D = lab._surface(Color("b0552a"), 0.6)
	# Lane edges from the start line to the wall, and the start line.
	var lane_from := CAR_AT.z + 2.6
	var lane_to := WALL_AT.z + 0.4
	for side in [-1.0, 1.0]:
		_stripe(Vector3(LANE_X + side * 1.6, 0.01, (lane_from + lane_to) * 0.5), Vector3(0.18, 0.02, lane_from - lane_to), paint)
	_stripe(Vector3(LANE_X, 0.01, CAR_AT.z - 2.6), Vector3(3.38, 0.02, 0.18), paint)
	_ramp()
	wall = VoxelStructure.make(self, "concrete", Vector3(5.0, 2.1, 0.45), WALL_AT + Vector3(0, 1.05, 0))
	wall.name = "CrashWall"
	cars.append(_park(VehicleDamage.make("sedan", 3, false), CAR_AT, 0.0))
	cars.append(_park(VehicleDamage.make("suv", 7, false), SECOND_AT, PI * 0.5))
	driver = VehicleDriver.new()
	driver.name = "Driver"
	add_child(driver)
	driver.got_out.connect(_on_got_out)


func _park(car: RigidBody3D, at: Vector3, turn: float) -> RigidBody3D:
	add_child(car)
	car.teleport(Transform3D(Basis(Vector3.UP, turn), to_global(at)))
	return car


func _stripe(at: Vector3, size: Vector3, material: Material) -> void:
	var stripe := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	stripe.mesh = box
	stripe.position = at
	add_child(stripe)


## A 1.2 m kicker you take from the pad side and land in the open yard.
func _ramp() -> void:
	var ramp := StaticBody3D.new()
	ramp.name = "Ramp"
	var length := 6.0
	var rise := 1.2
	var angle := atan2(rise, length)
	ramp.position = RAMP_AT + Vector3(0, rise * 0.5 - 0.15, 0)
	ramp.rotation.x = -angle
	add_child(ramp)
	var size := Vector3(3.6, 0.3, length / cos(angle))
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = lab._surface(Color("4a4038"), 0.8)
	mesh.mesh = box
	ramp.add_child(mesh)
	var shape := CollisionShape3D.new()
	var hull := BoxShape3D.new()
	hull.size = size
	shape.shape = hull
	ramp.add_child(shape)


func driving() -> bool:
	return driver != null and driver.driving


func occupied() -> bool:
	return driver != null and driver.occupied()


## The plinth: get out if in, else into the nearest car.
func press() -> String:
	if driver.seated:
		return "OUT" if driver.get_out() else driver.last_message
	return "WALK TO A DRIVER DOOR"


## Out of the car whatever its speed, for the lab menu's teleport.
func leave() -> void:
	if driver != null and driver.phase in ["enter", "jam_pull"]:
		driver.interrupt_entry("STATION TELEPORT")
	elif occupied():
		driver.get_out(true)


## USE at a door handle: the driver's or the passenger's. False when no
## handle is in reach.
func try_enter() -> bool:
	if occupied():
		return false
	_ensure_walker()
	var door := _nearest_door(VehicleDriver.REACH_TO_GET_IN)
	if door.is_empty():
		return false
	return driver.begin_entry(door.car, int(door.side))


func prompt() -> String:
	if driver == null or occupied():
		return ""
	_ensure_walker()
	var door := _nearest_door(VehicleDriver.REACH_TO_GET_IN)
	if door.is_empty():
		return ""
	var side := int(door.side)
	var seat := "DRIVER" if side == VehicleDriver.DOOR_LEFT else "PASSENGER"
	var damage := (door.car as Node).get_node("Damage") as VehicleDamage
	if damage.door_missing(side):
		return "CLIMB INTO %s SEAT" % seat
	if damage.door_jammed(side):
		return "PULL JAMMED %s DOOR" % seat
	return "OPEN %s DOOR" % seat


func interrupt_entry(reason := "HIT") -> bool:
	return driver.interrupt_entry(reason) if driver != null else false


func _ensure_walker() -> void:
	if driver == null or lab == null or lab.player == null:
		return
	driver.bind_walker(lab.player, lab.camera, lab.player_body)


## The closest handle in reach, either side of any car: {car, side} or {}.
func _nearest_door(reach: float) -> Dictionary:
	var best := {}
	var best_distance := reach
	for candidate in cars:
		for side in [VehicleDriver.DOOR_LEFT, VehicleDriver.DOOR_RIGHT]:
			var distance := driver.door_handle(candidate, side).distance_to(lab.player.global_position)
			if distance < best_distance:
				best_distance = distance
				best = {"car": candidate, "side": side}
	return best


func _nearest_car(reach: float) -> RigidBody3D:
	var best: RigidBody3D = null
	var best_distance := reach
	for car in cars:
		var distance := car.global_position.distance_to(lab.player.global_position)
		if distance < best_distance:
			best_distance = distance
			best = car
	return best


func _on_got_out(standing: Vector3, facing_yaw: float) -> void:
	lab.player.global_position = standing
	lab.player.velocity = Vector3.ZERO
	lab.yaw = facing_yaw
	lab.camera.current = true


func status() -> String:
	if driver != null and driver.phase != "idle":
		return "%s  %s" % [driver.phase.to_upper(), driver.last_message]
	if not driver.seated:
		return "%d CARS" % cars.size()
	var report: Dictionary = (driver.car.get_node("Damage") as VehicleDamage).report()
	return "%d KMH  ENGINE %d%%  OFF %d" % [roundi(absf(driver.speed()) * 3.6), roundi(float(report.engine) * 100.0), (report.detached as Array).size()]
