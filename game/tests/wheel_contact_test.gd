extends Node

## Greg: "fix the car models so the wheels are on the ground not touching the
## body or dragging". Three separate faults produced that one sentence, and all
## three were arithmetic that nothing checked.

const VEHICLE := preload("res://systems/arcade_vehicle.gd")

var failures: Array[String] = []

func check(c: bool, label: String) -> void:
	print("PASS " if c else "FAIL ", label)
	if not c:
		failures.append(label)

func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	# --- 1. the spring can actually hold the car up ------------------------
	# It could not. 9.8 / 26 = 0.377 against 0.35 of travel, so compression
	# clamped every frame and the car stood on its bump stops.
	check(not VEHICLE.bottomed_out(), "the spring holds the car up instead of standing on its bump stops")
	var rest: float = VEHICLE.rest_compression()
	check(rest > 0.0 and rest < VEHICLE.SUSPENSION_REST, "rest compression is inside the available travel")
	check(rest < VEHICLE.SUSPENSION_REST * 0.55, "and leaves over half the travel for bumps and landings rather than spending it standing still")

	# --- 2. the chassis is off the floor -----------------------------------
	# The real symptom. Chassis half-height is 0.65 and the ground used to sit
	# at exactly -0.65 in body space: the hull resting on the ground.
	var ground: float = VEHICLE.rest_contact_y()
	var chassis_bottom := -1.3 * 0.5
	check(ground < chassis_bottom, "the ground is below the bottom of the hull, so the body is not dragging")
	check(chassis_bottom - ground > 0.12, "and there is real clearance under it, not a rounding error (%.3f m)" % (chassis_bottom - ground))

	# --- 3. the physics agrees with the model ------------------------------
	# scrap_skiff.glb's wheels are 0.70 tall. WHEEL_RADIUS was 0.30, measured
	# against nothing, so the visible tyre could never touch what the ray hit.
	check(is_equal_approx(VEHICLE.WHEEL_RADIUS, 0.35), "wheel radius matches the wheels in the model that is actually drawn")

	# --- 4. the shell is seated on the contact patch, at any scale ---------
	# The failure was a shell whose origin is its own ground plane parented onto
	# a chassis whose origin is its centre. Scale-dependent, so check both the
	# player's and the AI's.
	var derby := load("res://rift_derby.gd")
	var wheel_bottom: float = derby.SKIFF_WHEEL_BOTTOM
	for shell_scale: float in [1.15, 1.05, 1.05 * 1.12]:
		var seat: float = ground - wheel_bottom * shell_scale
		var tyre_bottom: float = seat + wheel_bottom * shell_scale
		check(is_equal_approx(tyre_bottom, ground), "at scale %.2f the tyre meets the ground exactly" % shell_scale)
		check(seat < 0.0, "and the shell is seated below the chassis centre, not on top of it (%.3f)" % seat)

	# The derived height has to move when the model it is derived from moves, or
	# it is a hardcoded number wearing a function's clothes.
	check(VEHICLE.rest_contact_y() < (VEHICLE.WHEEL_ANCHORS[0] as Vector3).y, "the contact patch is below the wheel anchor, as a wheel hanging down implies")

	print("WHEEL_CONTACT_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
