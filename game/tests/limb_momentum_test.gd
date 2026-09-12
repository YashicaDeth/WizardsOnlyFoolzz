extends Node

## AN1. The claim is that a committed swing and a lazy flick produce different
## numbers without the player pressing anything different. That is testable, and
## if it is not true the whole idea is decoration.

const MOMENTUM := preload("res://systems/limb_momentum.gd")

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

	# A flick: a small, quick turn and back.
	var flick: LimbMomentum = MOMENTUM.new()
	flick.carry(1.4, 0.55)
	for frame in 20:
		var turn := 0.012 if frame < 4 else 0.0
		flick.advance(step, Vector2(turn, 0.0))
	var flick_worth := flick.commitment()

	# A committed sweep: the same weapon, turned hard and followed through.
	var sweep: LimbMomentum = MOMENTUM.new()
	sweep.carry(1.4, 0.55)
	for frame in 20:
		var turn := 0.055 if frame < 8 else 0.0
		sweep.advance(step, Vector2(turn, 0.0), Vector3(0, 0, -3.0))
	var sweep_worth := sweep.commitment()

	print("flick %.3f  vs  sweep %.3f" % [flick_worth, sweep_worth])
	check(sweep_worth > flick_worth * 1.8, "a committed sweep is worth much more than a flick")
	check(flick_worth < 0.45, "a flick cannot land a full-strength blow")

	# Mass: the same input on a heavier weapon lags further behind the hand.
	var light: LimbMomentum = MOMENTUM.new()
	light.carry(0.5, 0.3)
	var heavy: LimbMomentum = MOMENTUM.new()
	heavy.carry(6.0, 0.9)
	for frame in 10:
		light.advance(step, Vector2(0.05, 0.0))
		heavy.advance(step, Vector2(0.05, 0.0))
	var light_lag := (light.at - light.anchor).length()
	var heavy_lag := (heavy.at - heavy.anchor).length()
	print("lag: light %.4f  heavy %.4f" % [light_lag, heavy_lag])
	check(heavy_lag > light_lag, "a heavier weapon trails further behind the hand")

	# And it settles. A spring that does not come to rest is a bug, not a feel.
	var settling: LimbMomentum = MOMENTUM.new()
	settling.carry(1.4, 0.55)
	settling.advance(step, Vector2(0.08, 0.04))
	for _frame in 240:
		settling.advance(step, Vector2.ZERO)
	check(settling.velocity.length() < 0.35, "the weapon comes to rest when you stop moving")
	check(settling.at.distance_to(settling.anchor) < 0.4, "and it comes to rest near the hand")

	# The arm does not detach.
	var wild: LimbMomentum = MOMENTUM.new()
	wild.carry(6.0, 0.9)
	for _frame in 90:
		wild.advance(step, Vector2(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4)))
	check(wild.at.distance_to(wild.anchor) <= 0.4201, "the weapon never leaves the arm's reach")
	check(not is_nan(wild.at.x) and not is_nan(wild.velocity.x), "the integration stays finite under abuse")

	# Fatigue makes the guard genuinely worse rather than printing that it is.
	var fresh: LimbMomentum = MOMENTUM.new()
	fresh.carry(1.4, 0.55)
	var spent: LimbMomentum = MOMENTUM.new()
	spent.carry(1.4, 0.55)
	spent.fatigue = 1.0
	for _frame in 45:
		fresh.advance(step, Vector2(0.02, 0.0))
		spent.advance(step, Vector2(0.02, 0.0))
	print("drift: fresh %.4f  spent %.4f" % [(fresh.at - fresh.anchor).length(), (spent.at - spent.anchor).length()])
	check((spent.at - spent.anchor).length() > (fresh.at - fresh.anchor).length(), "a tired arm cannot hold the weapon where it wants it")

	# A landed blow spends the swing, so you cannot hit twice on one wind-up.
	var landed: LimbMomentum = MOMENTUM.new()
	landed.carry(1.4, 0.55)
	for _frame in 8:
		landed.advance(step, Vector2(0.055, 0.0))
	landed.strike(0.7, Vector3.FORWARD)
	landed.advance(step, Vector2.ZERO)
	check(landed.commitment() < 0.5, "contact spends the blow")

	if failures.is_empty():
		print("limb momentum: sound")
		get_tree().quit(0)
	else:
		print("limb momentum FAILURES: ", failures)
		get_tree().quit(1)
