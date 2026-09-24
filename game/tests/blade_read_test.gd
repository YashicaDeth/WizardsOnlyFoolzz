extends Node

## Two people reading each other, checked as numbers.
##
## The failures a sword fight can have are all the same kind: something that
## looks fine in isolation and quietly removes the reason to play. A guard that
## soaks a blow whatever direction it came from makes reading the swing
## optional. A parry window you can sit in makes timing optional. A swing that
## can be punished during its own active frames means whoever swings second
## always wins.
##
## The one that decides whether this feels like Mordhau or like Dark Souls is
## `committed_side()`, and it is one line: sample the direction at contact and
## the mouse is still steering, so drags work; sample it at release and the
## swing is a commitment you can be punished for wearing.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	print("-- which way a blade is coming --")
	# Named for where it comes from, not where it goes, so meeting one is
	# equality. A blade travelling down arrives from high.
	check(BladeRead.swing_side(Vector3(0, -6, 0)) == BladeRead.HIGH, "a blade coming down arrives from high")
	check(BladeRead.swing_side(Vector3(0, 6, 0)) == BladeRead.LOW, "one coming up arrives from low")
	# Travelling to the defender's right means it started on their left.
	check(BladeRead.swing_side(Vector3(6, 0, 0)) == BladeRead.LEFT, "one crossing to the right came from the left")
	check(BladeRead.swing_side(Vector3(-6, 0, 0)) == BladeRead.RIGHT, "and the mirror of that")
	check(BladeRead.swing_side(Vector3(0.1, 0.1, 0)).is_empty(), "a blade barely moving is not a swing to read")
	# An overhead a few degrees off is still an overhead to everyone watching.
	check(BladeRead.swing_side(Vector3(3.0, -3.2, 0)) == BladeRead.HIGH, "a slightly off-axis overhead still reads as an overhead")

	print("-- where a guard is held --")
	# Raw mouse convention: up is negative y.
	check(BladeRead.guard_side(Vector2(0, -1)) == BladeRead.HIGH, "pushing the mouse up holds a high guard")
	check(BladeRead.guard_side(Vector2(0, 1)) == BladeRead.LOW, "and down holds a low one")
	check(BladeRead.guard_side(Vector2(-1, 0)) == BladeRead.LEFT, "left is left")
	check(BladeRead.guard_side(Vector2(1, 0)) == BladeRead.RIGHT, "and right is right")
	check(BladeRead.guard_side(Vector2.ZERO).is_empty(), "no input is no guard")

	print("-- a guard is only worth what it meets --")
	check(BladeRead.blocks(BladeRead.HIGH, BladeRead.HIGH), "a high guard meets an overhead")
	check(not BladeRead.blocks(BladeRead.HIGH, BladeRead.LOW), "and does nothing about a blow from below")
	check(not BladeRead.blocks(BladeRead.LEFT, BladeRead.RIGHT), "guarding the wrong side is guarding nothing")
	check(not BladeRead.blocks("", BladeRead.HIGH), "and holding no guard at all is worth even less")

	print("-- what happens when they meet --")
	var open: Dictionary = BladeRead.resolve(BladeRead.LEFT, 0.05, BladeRead.HIGH, 8.0)
	check(str(open.outcome) == "open", "the wrong guard leaves you open")
	# The whole game is reading the direction, so a wrong guard must soak
	# nothing whatsoever -- any leak here makes the read optional.
	check(is_equal_approx(float(open.through), 1.0), "and takes the blow in full")
	check(is_equal_approx(float(open.shock), 0.0), "costing the attacker nothing")

	var parried: Dictionary = BladeRead.resolve(BladeRead.HIGH, 0.05, BladeRead.HIGH, 8.0)
	check(str(parried.outcome) == "parry", "the right guard, in time, is a parry")
	check(is_equal_approx(float(parried.through), 0.0), "which takes nothing at all")
	check(float(parried.shock) > 0.0, "and turns the attacker's own commitment back on them (%.2f)" % float(parried.shock))

	var late: Dictionary = BladeRead.resolve(BladeRead.HIGH, 0.9, BladeRead.HIGH, 8.0)
	check(str(late.outcome) == "block", "the right guard held too long is only a block")
	# A guard you can sit in is a guard with no timing in it.
	check(float(late.through) > 0.0, "which lets something through (%.2f)" % float(late.through))
	check(float(late.shock) < float(parried.shock), "and punishes the attacker far less")

	var fast: Dictionary = BladeRead.resolve(BladeRead.HIGH, 0.05, BladeRead.HIGH, 20.0)
	check(float(fast.shock) > float(parried.shock), "committing harder to a swing that gets turned hurts more")
	check(str(BladeRead.resolve(BladeRead.HIGH, 0.05, "", 8.0).outcome) == "none", "and nothing swung is nothing to resolve")

	print("-- Mordhau in first person, Dark Souls in third --")
	# Released high, dragged round to the left by the time it lands.
	var dragged := BladeRead.committed_side(BladeRead.HIGH, BladeRead.LEFT, true)
	check(dragged == BladeRead.LEFT, "in first person the mouse is still steering, so a drag lands where it was dragged to")
	var committed := BladeRead.committed_side(BladeRead.HIGH, BladeRead.LEFT, false)
	check(committed == BladeRead.HIGH, "in third person the swing is what you committed to, whatever the mouse did after")
	# A blade that slowed below anything readable still has to land somewhere.
	check(BladeRead.committed_side(BladeRead.HIGH, "", true) == BladeRead.HIGH, "a first-person swing that slows to nothing keeps the angle it was thrown at")

	print("-- a committed swing has a shape --")
	check(BladeRead.swing_phase(0.05, 0.2, 0.15, 0.4) == "windup", "it winds up")
	check(BladeRead.swing_phase(0.28, 0.2, 0.15, 0.4) == "active", "then it is live")
	check(BladeRead.swing_phase(0.5, 0.2, 0.15, 0.4) == "recovery", "then it has to be recovered from")
	check(BladeRead.swing_phase(0.9, 0.2, 0.15, 0.4) == "done", "and then it is over")
	check(BladeRead.punishable("recovery"), "recovery is the window you get punished in")
	# Both of these are the mistake everybody building this makes once.
	check(not BladeRead.punishable("windup"), "winding up is not, or every trade is a coin flip")
	check(not BladeRead.punishable("active"), "and neither is the active frame, or whoever swings second always wins")

	print("-- a guard is a pose, and the two agree --")
	check(BladeRead.guard_height(BladeRead.HIGH) > BladeRead.guard_height(BladeRead.LOW), "a high guard is held higher than a low one")
	check(BladeRead.guard_height("") == 0.0, "and no guard is no raise")
	# Mirrored, so neither side is the cheap one to guard.
	check(is_equal_approx(BladeRead.guard_lean(BladeRead.LEFT) + BladeRead.guard_lean(BladeRead.RIGHT), 0.0), "left and right lean exactly opposite")
	check(is_equal_approx(BladeRead.guard_lean(BladeRead.HIGH), 0.0), "and a high guard is square on")
	# The two systems have to actually meet, or the read never reaches the body.
	var posed := CombatStance.guard(BladeRead.guard_height(BladeRead.HIGH))
	check(not posed.is_empty(), "a guard side drives an actual CombatStance pose")

	print("BLADE_READ_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
