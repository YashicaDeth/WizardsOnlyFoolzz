extends Node

## V1.4. Cars can be repaired, badly. A repair puts hull back on the gauge,
## but `repair()` also drops `max_integrity` a little every time it is called,
## so laundering damage away for free is not on the table: three trips to the
## welder leave a worse car than a car that never needed one, even sitting at
## a full-looking gauge.

const VEHICLE := preload("res://systems/arcade_vehicle.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var car: ArcadeVehicle = VEHICLE.new()
	car.apply_damage(60)
	check(car.integrity == 40, "sanity: the car is actually damaged before repair")

	var after := car.repair(30)
	check(after == 70 and car.integrity == 70, "repair puts hull back on the gauge")
	check(car.max_integrity == 95, "the first repair already costs the ceiling something (max %d)" % car.max_integrity)

	var full: ArcadeVehicle = VEHICLE.new()
	var first_max := full.max_integrity
	for _time in 3:
		full.apply_damage(50)
		full.repair(50)
	check(full.max_integrity < first_max, "three repairs leave a lower ceiling than a fresh chassis (%d vs %d)" % [full.max_integrity, first_max])
	check(full.integrity <= full.max_integrity, "current condition never exceeds the (now lower) ceiling")

	var never_repaired: ArcadeVehicle = VEHICLE.new()
	check(full.max_integrity < never_repaired.max_integrity, "a three-times-welded car is measurably worse than one that was never hit")

	# The ceiling never collapses to nothing under repeated abuse.
	var abused: ArcadeVehicle = VEHICLE.new()
	for _time in 40:
		abused.apply_damage(1000)
		abused.repair(1000)
	check(abused.max_integrity >= 1, "the ceiling degrades but never reaches zero or goes negative")
	check(abused.integrity == abused.max_integrity, "a full repair still tops out exactly at whatever the current ceiling is")

	car.free()
	full.free()
	never_repaired.free()
	abused.free()
	_report()


func _report() -> void:
	if failures.is_empty():
		print("vehicle repair: clean")
		get_tree().quit(0)
	else:
		print("vehicle repair FAILURES: ", failures)
		get_tree().quit(1)
