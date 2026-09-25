extends Node

## The animated intake pages (Greg: "ink, blood, metal, and parts swinging out
## on gears"): a page swings in and is exactly still once printed, each page
## change runs blood from the clip, and the runs are capped.

const MOTION := preload("res://systems/intake_page_motion.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	check(is_equal_approx(MOTION.swing_angle(0.0), MOTION.SWING_FROM), "a new page starts swung out")
	check(MOTION.swing_angle(1.0) == 0.0, "a printed page hangs exactly still")
	var crossed := false
	for step in 30:
		if MOTION.swing_angle(float(step) / 30.0) > 0.0:
			crossed = true
	check(crossed, "it overshoots on the way in, like a part on a spring")
	check(absf(MOTION.swing_angle(0.9)) < 0.01, "and has settled by the end of the print")
	var hinge := Vector2(6, 118)
	check(MOTION.swing_transform(0.4, hinge) * hinge == hinge, "the page turns about its hinge")

	WorldHistory.clear_history()
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	for _frame in 3:
		await get_tree().process_frame
	var intake = vat.intake
	intake.set_process(false)
	intake._process(0.1)
	var runs_before: int = intake.blood_runs.size()
	intake.page = (intake.page + 1) % intake.PAGES.size()
	intake._process(0.1)
	check(intake.blood_runs.size() == runs_before + 1 and intake.page_print < 0.5, "turning a page starts it printing and runs blood from the clip")
	for turn in 10:
		intake.page = (intake.page + 1) % intake.PAGES.size()
		intake._process(0.1)
	check(intake.blood_runs.size() <= MOTION.MAX_RUNS, "old runs give way to new ones (%d)" % intake.blood_runs.size())
	for _second in 30:
		intake._process(1.0)
	check(float(intake.blood_runs.back().age) > MOTION.DRY_SECONDS and intake.page_print >= 1.0, "the blood dries and the page settles")
	print("INTAKE_PAGES_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
