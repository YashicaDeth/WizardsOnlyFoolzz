extends Node

## The sandbox's own X-ray names three structures.
##
## `gore_demo` toggles the X-ray directly and carries no scan overlay, so the
## readout added to `XrayCursor` was invisible in the one room where the gore
## is actually played with. This drives the sandbox itself: `_set_xray(true)` is
## the same key the player presses (X), and `xray_structures()` is the exact
## call the sandbox HUD paints from, so the check is on the surface the player
## sees rather than on a parallel harness.
##
## Headless it asserts. Windowed it writes `P:/GameDev/Temp/xray_sandbox.png`
## from the live range, so the three lines can be looked at.

const DEMO := preload("res://gore_demo.tscn")
const XrayCursor := preload("res://systems/xray_cursor.gd")
const OUT := "P:/GameDev/Temp/xray_sandbox.png"
const MONITOR_OUT := "P:/GameDev/Temp/medical_monitor.png"
const MedicalMonitor := preload("res://systems/medical_monitor.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func labels_of(lines: Array) -> Array:
	var out := []
	for line: Dictionary in lines:
		out.append(str(line.get("label", "")))
	return out


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var demo: Node = DEMO.instantiate()
	add_child(demo)
	get_tree().current_scene = demo
	for frame in 3:
		await get_tree().process_frame

	var bodies: Array = demo.get("bodies")
	check(bodies.size() > 0, "the sandbox stood its dummies up")
	if bodies.is_empty():
		print("XRAY_SANDBOX_READOUT_TEST_RESULT failures=1")
		get_tree().quit(1)
		return

	# --- off means quiet -----------------------------------------------------
	check(not bool(demo.get("xray")), "the sandbox starts with the X-ray off")
	check((demo.xray_structures() as Array).is_empty(), "and names nothing with it off")

	# --- aim at a dummy's chest and read the sandbox's own answer ------------
	var rig: BaselineHuman = (bodies[0] as Dictionary)["rig"]
	var heart := rig.organ_parts.get("heart") as Node3D
	var along := rig.global_transform.basis.z
	# Under the heart, which is where the fourth rib's hoop crosses the shot:
	# the same body-relative line the lab test uses, so the sandbox and the lab
	# are being read at the same point rather than at two different aims.
	# Medial, so the spine column is behind the tissue and the third line exists no
	# matter how the dummy is standing. The side check gets its own lateral aim
	# below, because 6 cm off the midline misses the vertebrae.
	var aim := heart.global_position - rig.global_transform.basis.y * 0.06
	var from := aim - along * 1.2
	var camera := demo.get("camera") as Camera3D
	camera.global_position = from
	camera.look_at(aim, Vector3.UP)
	demo.call("_set_xray", true)
	check(bool(demo.get("xray")), "X turns the sandbox's X-ray on")
	var lines: Array = demo.xray_structures()
	var labels := labels_of(lines)
	print("SANDBOX ", labels)
	check(lines.size() == 3, "the sandbox reticle names three structures at once (%d)" % lines.size())
	var unique := {}
	for label: String in labels:
		unique[label] = true
	check(unique.size() == labels.size(), "none of them is named twice (%s)" % str(labels))
	# These dummies carry real lab hardware, so the first thing the line meets can
	# be an installed plate rather than an organ. Both are the tissue line; what
	# matters is that it is named and that the lines behind it are the bones the
	# ray actually crosses.
	var first_kind := str((lines[0] as Dictionary).get("kind", "")) if not lines.is_empty() else ""
	check(labels.size() > 0 and not labels[0].is_empty() and first_kind in ["tissue", "hardware"],
		"what the reticle lands in is named (%s / %s)" % [first_kind, labels[0] if not labels.is_empty() else "none"])
	# The heart sits in the left chest, so the hoop behind this aim is a left rib;
	# the lab test is where both sides and the sternum are asserted.
	check(labels.size() > 1 and labels[1].contains("RIB"),
		"the bone behind it is a named rib (%s)" % (labels[1] if labels.size() > 1 else "none"))
	check(labels.size() > 2 and labels[2].begins_with("VERTEBRA"),
		"and the landmark is the column the shot reaches (%s)" % (labels[2] if labels.size() > 2 else "none"))

	# No fourth path: the sandbox must be answering with the same resolution the
	# lab's overlay draws, not with its own idea of a body.
	check(labels == labels_of(XrayCursor.structures(rig, from, along, XrayCursor.READOUT_REACH, camera.get_world_3d())),
		"the sandbox and the lab resolve the same three names")

	# --- and which half of the chest it names -------------------------------
	# The same shot a few centimetres to the body's right: the rib is the same
	# hoop, but the body says which side the line went through.
	var side_aim := aim + rig.global_transform.basis.x * 0.06
	camera.global_position = side_aim - along * 1.2
	camera.look_at(side_aim, Vector3.UP)
	var side_labels := labels_of(demo.xray_structures())
	print("SANDBOX SIDE ", side_labels)
	check(side_labels.size() > 1 and str(side_labels[1]).begins_with("RIGHT RIB"),
		"a shot on the dummy's right names the rib on that side (%s)" % (side_labels[1] if side_labels.size() > 1 else "none"))

	# --- off again -----------------------------------------------------------
	demo.call("_set_xray", false)
	check((demo.xray_structures() as Array).is_empty(), "turning the X-ray off silences the names again")

	# --- the medical monitor on a wounded dummy ------------------------------
	check((demo.monitor_lines() as Array).is_empty(), "M is closed until it is asked")
	rig.hit("left_arm", 26.0, 6.0, "cut")
	rig.hit("torso", 44.0, 10.0, "ballistic")
	await get_tree().create_timer(0.2).timeout
	# Re-aimed on where the heart actually is now: the dummy has been hit twice
	# since the last aim and may have moved.
	var vitals_aim := (rig.organ_parts.get("heart") as Node3D).global_position
	var vitals_from := vitals_aim - rig.global_transform.basis.z * 1.2
	camera.global_position = vitals_from
	camera.look_at(vitals_aim, Vector3.UP)
	demo.call("_toggle_monitor")
	check(bool(demo.get("monitor")), "M opens the sandbox's monitor")
	var vitals: Array = demo.monitor_lines()
	print("MONITOR ", vitals)
	check(vitals.size() >= 10, "it prints the body it is on (%d lines)" % vitals.size())
	check(str(vitals[0]).begins_with("BODY //"), "naming the subject (%s)" % (vitals[0] if not vitals.is_empty() else "none"))
	var printed_bleed := ""
	for line in vitals:
		if str(line).begins_with("BLEED "):
			printed_bleed = str(line)
	check(printed_bleed == "BLEED %.1f mL/s" % float(rig.anatomy.bleed_rate), "with the body's own rate (%s)" % printed_bleed)
	check(rig.anatomy.bleed_rate > 0.0, "and these hits are bleeding")
	# No second copy: the sandbox's answer is the monitor's answer for this rig.
	check(vitals == MedicalMonitor.lines(rig), "the sandbox does not keep its own numbers")

	# --- look at it, when there is a screen to look with --------------------
	if DisplayServer.get_name() != "headless":
		demo.set_process(false)
		demo.set_physics_process(false)
		camera.global_position = from
		camera.look_at(aim, Vector3.UP)
		demo.call("_set_xray", true)
		var hud := demo.get("hud") as Control
		hud.queue_redraw()
		for frame in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var error := image.save_png(OUT)
		print("CAPTURE ", OUT, " error=", error)
		# The monitor on the wounded body, with the skeleton off: this is the
		# screen as it is read, not as the X-ray happens to light it.
		demo.call("_set_xray", false)
		camera.global_position = vitals_from
		camera.look_at(vitals_aim, Vector3.UP)
		hud.queue_redraw()
		for frame in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var vitals_image := get_viewport().get_texture().get_image()
		var vitals_error := vitals_image.save_png(MONITOR_OUT)
		print("CAPTURE ", MONITOR_OUT, " error=", vitals_error)

	print("XRAY_SANDBOX_READOUT_TEST_RESULT failures=", failures.size())
	demo.queue_free()
	get_tree().quit(0 if failures.is_empty() else 1)
