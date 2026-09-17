extends Node

const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")

## C3. A photograph is not a screenshot. It is a record of what was in shot and
## what state those bodies were really in, taken off the same rig the fight
## happened to — which is the only version E3 can hold a ritual to, because a
## ritual that can be satisfied by standing in the right place is a confirm
## button with extra steps.

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
	WorldHistory.register_subject("settings", {"gore": "FULL"})
	WorldHistory.register_subject("player", {"name": "THE HUNTER"})
	BaselineHuman.apply_gore_setting()

	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3.ZERO
	camera.look_at_from_position(Vector3.ZERO, Vector3(0, 0, -10), Vector3.UP)
	camera.current = true

	var subject := BaselineHuman.new()
	add_child(subject)
	subject.build("in_shot", {})
	subject.position = Vector3(0, 0, -6)
	var behind := BaselineHuman.new()
	add_child(behind)
	behind.build("behind_you", {})
	behind.position = Vector3(0, 0, 9)
	var miles := BaselineHuman.new()
	add_child(miles)
	miles.build("too_far", {})
	miles.position = Vector3(0, 0, -(FieldCamera.LEGIBLE_RANGE + 12.0))
	await get_tree().physics_frame

	# --- C3.1: what is in shot is what the engine says is in shot ------------
	check(FieldCamera.in_frame(camera, subject), "a body in front of the lens is in frame")
	check(not FieldCamera.in_frame(camera, behind), "one behind you is not")
	check(not FieldCamera.in_frame(camera, miles), "and one too far to read is not evidence")

	var empty := FieldCamera.capture(camera, [behind], "nowhere")
	check((empty.contents as Array).is_empty() and str(empty.caption) == "NOTHING IN FRAME", "photographing an empty room gets you an empty photograph")

	# --- C3.2/C3.3: the contents are the real state of a real body -----------
	subject.hit("right_arm", 60.0, 30.0, "cut", "", Vector3.RIGHT)
	if not subject.severed.has("right_arm"):
		subject.hit("right_arm", 60.0, 30.0, "cut", "", Vector3.RIGHT)
	subject.hit("torso", 90.0, 20.0, "cut", "heart")
	await get_tree().physics_frame

	var photo := FieldCamera.capture(camera, [subject, behind, miles], "ashbloom_bone_yard")
	check((photo.contents as Array).size() == 1, "only what was in shot is in the photograph")
	var record: Dictionary = (photo.contents as Array)[0]
	check(str(record.subject_id) == "in_shot", "and it knows whose body it is")
	check((record.severed as Array).has("right_arm"), "the photograph records the arm that is actually gone")
	check((record.ruptured as Array).has("heart"), "and the organ that is actually ruptured")
	check(str(photo.caption).contains("RIGHT ARM OFF"), "the caption cannot claim anything the body was not doing")

	check(FieldCamera.verify(photo, {"zone": "right_arm", "state": "severed"}).ok, "a ritual asking for a severed arm is satisfied")
	check(not FieldCamera.verify(photo, {"zone": "left_leg", "state": "severed"}).ok, "one asking for a leg is not")
	check(FieldCamera.verify(photo, {"organ": "heart"}).ok, "and one asking for a ruptured heart is")
	var five := FieldCamera.verify(photo, {"zone": "right_arm", "state": "severed", "count": 5})
	check(not five.ok and str(five.reason).contains("1 of 5"), "photographing one body five times is not five bodies")
	check(not FieldCamera.verify(photo, {"subject": "somebody_else", "zone": "right_arm", "state": "severed"}).ok, "and evidence about the wrong person does not count")

	# --- the album persists --------------------------------------------------
	FieldCamera.store(photo)
	check(FieldCamera.album().size() > 0, "photographs are kept, so one taken before a ritual existed still counts")

	# --- C3.4: posting it -----------------------------------------------------
	var wire := WireNet.new(WireNet.SIGNAL_SURFACE)
	var quiet := wire.publish_photograph(empty)
	check(not bool(quiet.ok), "an empty frame is not publishable")
	var grudge_before := 0
	WorldHistory.register_subject("in_shot", {"name": "In Shot", "grudge": 0})
	grudge_before = int(WorldHistory.subject("in_shot").get("grudge", 0))
	var posted := wire.publish_photograph(photo)
	check(bool(posted.ok) and int(posted.reach) > 0, "a real photograph travels")
	check(int(posted.exposure) > 0, "and it is evidence you were close enough to take it")
	check(int(WorldHistory.subject("in_shot").get("grudge", 0)) > grudge_before, "whoever is in it has a new reason to know your name")
	var published_events := WorldHistory.events.filter(func(event: Dictionary) -> bool: return str(event.get("type", "")) == "photograph_published")
	check(published_events.size() == 1 and PLAYER_ACTION_LEDGER.count("photograph_published") == 1 and str((published_events[0].get("details", {}) as Dictionary).get("action_id", "")).begins_with("action_"), "and publishing it is one identified recorded act")
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0, "the publication and every depicted subject reaction close one transaction")

	print("CAMERA_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
