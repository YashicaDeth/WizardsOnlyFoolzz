extends Node

## AE1.1. Unseen has to be a real, continuous state driven by all four named
## inputs — not a single input deciding the answer on its own, and not a
## boolean invented without a formula behind it.

const PERCEPTION := preload("res://systems/perception.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	# Far away, dark, silent, and covered: as unseen as it gets.
	var hidden := PERCEPTION.visibility(0.0, 0.0, 1.0, 40.0, 40.0)
	check(hidden < 0.05, "far, dark, silent and covered is barely visible at all (%.3f)" % hidden)
	check(PERCEPTION.is_unseen(0.0, 0.0, 1.0, 40.0, 40.0), "and reads as genuinely unseen")

	# Point-blank, even with nothing else going for you, is not unseen.
	var close := PERCEPTION.visibility(0.0, 0.0, 0.0, 0.0, 40.0)
	check(close > PERCEPTION.UNSEEN_THRESHOLD, "standing at someone's feet is not unseen no matter how dark (%.3f)" % close)
	check(not PERCEPTION.is_unseen(0.0, 0.0, 0.0, 0.0, 40.0), "distance alone can make you seen")

	# Each input actually moves the number, independent of the others.
	var base := PERCEPTION.visibility(0.0, 0.0, 0.0, 30.0, 40.0)
	var lit := PERCEPTION.visibility(1.0, 0.0, 0.0, 30.0, 40.0)
	var loud := PERCEPTION.visibility(0.0, 1.0, 0.0, 30.0, 40.0)
	var covered := PERCEPTION.visibility(0.0, 0.0, 1.0, 30.0, 40.0)
	check(lit > base, "more light makes you more visible (%.3f vs %.3f)" % [lit, base])
	check(loud > base, "more noise makes you more visible (%.3f vs %.3f)" % [loud, base])
	check(covered < base, "cover makes you less visible (%.3f vs %.3f)" % [covered, base])

	# No single term is allowed to fully override another.
	var lit_and_loud_but_covered := PERCEPTION.visibility(1.0, 1.0, 1.0, 5.0, 40.0)
	check(lit_and_loud_but_covered > 0.0, "full cover dims a lit, loud, close target rather than erasing it (%.3f)" % lit_and_loud_but_covered)
	var dark_silent_same_cover := PERCEPTION.visibility(0.0, 0.0, 1.0, 5.0, 40.0)
	check(lit_and_loud_but_covered > dark_silent_same_cover, "but being lit and loud still costs you through the same cover (%.3f vs %.3f)" % [lit_and_loud_but_covered, dark_silent_same_cover])

	# Degenerate input: no range to measure against at all.
	check(is_equal_approx(PERCEPTION.visibility(0.0, 0.0, 0.0, 10.0, 0.0), 1.0), "a zero max_range reads as fully visible rather than dividing by zero")

	# Always bounded, whatever is thrown at it.
	var extreme := PERCEPTION.visibility(50.0, -30.0, 12.0, -900.0, 40.0)
	check(extreme >= 0.0 and extreme <= 1.0, "out-of-range inputs still land inside 0..1 (%.3f)" % extreme)

	if failures.is_empty():
		print("perception: unseen is a real, continuous state")
		get_tree().quit(0)
	else:
		print("perception FAILURES: ", failures)
		get_tree().quit(1)
