extends Node

## Greg, 25 September: the doctor walks up to the screen and taps it, goes to
## his computer, says his lines ("Hello. Hey. ..." / birthday / "Hurry up now.
## I'm being watched too."), the cameras all around zoom in, and the first
## time you think out loud he tells you he can read your thoughts.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	await get_tree().process_frame
	vat.arrival_clock = 0.0
	var faced_tank := false
	var t := 0.0
	while t < 5.4:
		vat._update_arrival(0.05)
		t += 0.05
		if vat.arrival_clock > 2.2 and vat.arrival_clock < 3.4:
			var to_tank: Vector3 = vat.VAT_POSITION - vat.examiner_node.global_position
			var facing: Vector3 = vat.examiner_node.global_transform.basis.z
			faced_tank = faced_tank or Vector2(facing.x, facing.z).normalized().dot(Vector2(to_tank.x, to_tank.z).normalized()) > 0.9
	check(vat.examiner_taps == 3, "he taps the glass three times (%d)" % vat.examiner_taps)
	check(faced_tank, "facing you while he does it")
	check(vat.opening_audio.played_cues.count("tap") == 3, "each knock is heard")
	check(WorldHistory.event_count("examiner_tapped_glass") == 1, "the taps are recorded")
	var at_glass: float = vat.examiner_node.global_position.distance_to(vat.examiner_post)
	check(at_glass < 0.3, "and then he is at his terminal (%.2f m off)" % at_glass)

	var intake = vat.intake
	var said: Array[String] = []
	var watched_at := -1.0
	var clock := 0.0
	while clock < 60.0 and watched_at < 0.0:
		intake._process(0.05)
		clock += 0.05
		var line := str(intake.doctor_says)
		if intake.doctor_life > 0.0 and not said.has(line):
			said.append(line)
		if vat.watchers.closed_in and watched_at < 0.0:
			watched_at = clock
	for beat in DoctorExamination.OPENING:
		check(said.has(str(beat.line)), "he says: %s" % str(beat.line).left(40))
	check(said.find(str(DoctorExamination.OPENING[0].line)) < said.find(str(DoctorExamination.OPENING[2].line)), "in order")
	check(watched_at > 0.0, "\"I'm being watched too\" turns the cameras on you")
	var scan: Control = vat.watchers.scan
	check(scan != null and scan.size.x > 100.0 and scan.size.y > 100.0, "the depth scan covers the screen, not 0x0 (%s)" % (str(scan.size) if scan != null else "none"))
	for i in 60:
		vat.watchers._process(0.05)
	check(vat.watchers.zoom_amount() > 0.95, "every lens barrel runs out (%.2f)" % vat.watchers.zoom_amount())
	var aimed := true
	for lens in vat.watchers.cameras:
		var forward: Vector3 = -lens.head.global_transform.basis.z
		aimed = aimed and forward.dot((vat.watchers.target - lens.head.global_position).normalized()) > 0.95
	check(aimed, "and every camera is pointed at your tank")
	check(WorldHistory.event_count("intake_cameras_closed_in") == 1, "the cameras closing in are recorded")
	check(WorldHistory.event_count("examiner_greeting") == 1, "so is his greeting")

	intake._think("let me out")
	check(str(intake.doctor_says) == str(DoctorExamination.READS_THOUGHTS.line), "your first thought, he answers: he can read it")
	check(WorldHistory.event_count("examiner_read_thought") == 1, "and it goes on the record")
	intake.doctor_life = 0.0
	intake._think("i hate you")
	check(WorldHistory.event_count("examiner_read_thought") == 1, "he only says it once")
	print("OPENING_GREETING_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
