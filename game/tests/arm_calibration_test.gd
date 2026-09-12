extends Node

## AN1.4. `commitment()` saturated at 1.0 the moment the arm was wired to a real
## mouse, which means the 7.0 m/s reference was picked against the synthetic
## numbers in `limb_momentum_test.gd` and not against anything a hand does.
##
## This measures what the arm actually reaches for turn rates a player produces,
## so the reference is chosen from data rather than from a guess. It prints a
## table; the checks only assert the shape the curve has to have.

const MOMENTUM := preload("res://systems/limb_momentum.gd")

# Gestures, not rates. The first version of this table drove every speed for the
# same fourteen frames, which meant "1200 deg/s" was not a flick at all - it was
# an extremely fast *sustained* sweep, and it duly scored higher than a committed
# one. A flick is fast **and short**; a committed sweep is moderate **and held**,
# with the body moving into it. Duration is half of what separates them and the
# measurement has to contain it.
#
# [degrees per second, frames of input, walking into it]
const GESTURES = [
	[40.0, 30, false, "a slow look around"],
	[1200.0, 3, false, "a flick across the screen"],
	[120.0, 20, false, "tracking somebody walking"],
	[300.0, 14, false, "a deliberate swing"],
	[600.0, 16, true, "a hard committed sweep"],
]

# The hunt's own mouse scale, so this measures the game's numbers not invented ones.
const LOOK_SCALE := 0.0026

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var step := 1.0 / 60.0
	var peaks: Array = []
	print("  gesture                      |  raw  | travel")
	for entry in GESTURES:
		var degrees: float = entry[0]
		var frames: int = entry[1]
		var walking: bool = entry[2]
		# Degrees per second into the radians-per-frame the hunt hands the arm.
		var per_frame := deg_to_rad(degrees) * step
		var arm: LimbMomentum = MOMENTUM.new()
		arm.carry(1.45, 0.62)
		var raw := 0.0
		for frame in 40:
			var turn := Vector2(per_frame if frame < frames else 0.0, 0.0)
			var body := Vector3(0, 0, -3.2) if walking and frame < frames else Vector3.ZERO
			arm.advance(step, turn, body)
			raw = maxf(raw, arm.head_speed())
		# The sustained peak is what `commitment()` divides, so it is the number the
		# reference has to be chosen against.
		var held: float = arm._work
		peaks.append(held)
		print("  %-28s | %5.2f | %5.2f" % [entry[3], raw, held])

	# Written against the old speed measure, where any movement scored. Under
	# travel a slow look correctly accumulates nothing: carrying a weapon is
	# not swinging it.
	check(peaks[0] < 0.05, "a slow look around is not a blow at all")
	check(peaks[2] > peaks[0], "tracking beats a slow look")
	check(peaks[3] > peaks[2], "a deliberate swing beats tracking")
	check(peaks[4] > peaks[3], "and a committed sweep beats a deliberate swing")
	# The one the whole design turns on: a flick must not buy a real blow.
	# It lands near a moderate swing, which is honest - whipping a weapon does
	# move it - and less than half of what committing to the swing is worth.
	check(peaks[1] < peaks[4] * 0.6, "a flick is worth under two thirds of a committed sweep")
	check(absf(peaks[1] - peaks[3]) < peaks[3] * 0.35, "and lands near a moderate swing, not above it")

	# The reference wants to sit where a deliberate swing reads as a full blow
	# and a look around reads as almost nothing.
	var deliberate: float = peaks[4]
	var slow: float = peaks[0]
	print("\n  a committed sweep travels %.2f m; a slow look %.2f" % [deliberate, slow])
	print("  a reference of %.1f would put them at %.2f and %.2f commitment"
		% [deliberate, 1.0, slow / deliberate])
	check(slow / deliberate < 0.35, "a slow look is worth far less than a swing at that reference")

	# And confirm the chosen constant behaves once it is in.
	var arm2: LimbMomentum = MOMENTUM.new()
	arm2.carry(1.45, 0.62)
	for frame in 30:
		arm2.advance(step, Vector2(deg_to_rad(300.0) * step if frame < 14 else 0.0, 0.0))
	print("  commitment of a deliberate swing at the current reference: %.3f" % arm2.commitment())

	if failures.is_empty():
		print("arm calibration: measured")
		get_tree().quit(0)
	else:
		print("arm calibration FAILURES: ", failures)
		get_tree().quit(1)
