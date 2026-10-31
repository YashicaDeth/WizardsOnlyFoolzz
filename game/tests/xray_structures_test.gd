extends Node3D

## The reticle names three structures, the way the reference does
## (`RIGHT LUNG / RIGHT RIB 3 / T5 VERTEBRA`), instead of the one organ the aim
## happened to be on.
##
## Resolution lives in `XrayCursor.structures()`: the tissue is whatever the
## lab's own rip prompt would take hold of (`OrganSystem.aimed_part`), and the
## bone and landmark are the skeleton the X-ray draws, met by the actual aim
## line. So these checks are about what the body can prove: a named rib and a
## numbered vertebra where the ray crosses them, fewer lines where the body has
## nothing more to say, and nothing at all where there is no body.
##
## Headless it asserts. Windowed it also writes
## `P:/GameDev/Temp/xray_structures.png` from the real scan overlay, so the
## three lines can be looked at rather than only measured.

const OUT := "P:/GameDev/Temp/xray_structures.png"
const XrayCursor := preload("res://systems/xray_cursor.gd")

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
	RenderingServer.set_default_clear_color(Color("11100e"))
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.9, 0.6, 0.0)
	light.light_energy = 1.6
	add_child(light)
	var body := BaselineHuman.new()
	add_child(body)
	body.build("aimed", {"gore": true})
	await get_tree().physics_frame

	# --- the chest, low and medial: heart, the rib behind it, the vertebra ---
	# A line that reaches all three because the body puts them there: the heart
	# sits under the fourth rib's hoop, and the spine column is behind both.
	var heart := body.organ_parts.get("heart") as Node3D
	var chest_from := Vector3(0.0, heart.global_position.y - 0.06, heart.global_position.z - 1.2)
	var chest := XrayCursor.structures(body, chest_from, Vector3(0, 0, 1))
	var chest_labels := labels_of(chest)
	print("CHEST ", chest_labels)
	check(chest.size() == 3, "the reticle names three structures at once (%d)" % chest.size())
	check(chest_labels.size() == 3 and not chest_labels[0].is_empty() and not chest_labels[1].is_empty() and not chest_labels[2].is_empty(),
		"and every one of them has a name")
	var unique := {}
	for label: String in chest_labels:
		unique[label] = true
	check(unique.size() == chest_labels.size(), "no structure is named twice (%s)" % str(chest_labels))
	check(chest_labels.size() > 0 and chest_labels[0] == "HEART", "the tissue under the reticle is named")
	check(chest.size() > 0 and str((chest[0] as Dictionary).get("kind", "")) == "tissue", "and it is the tissue line")
	check(chest_labels.size() > 1 and chest_labels[1].begins_with("RIB"), "the bone immediately behind it is a named rib (%s)" % (chest_labels[1] if chest_labels.size() > 1 else "none"))
	check(chest_labels.size() > 2 and chest_labels[2].begins_with("VERTEBRA"), "and the landmark the ray reaches is a numbered vertebra (%s)" % (chest_labels[2] if chest_labels.size() > 2 else "none"))
	check(chest.size() > 2 and str((chest[2] as Dictionary).get("kind", "")) == "landmark", "the third line is the landmark")

	# The order on screen is the order along the ray: tissue, then bone, then
	# landmark, which is what makes the lines read as depth rather than a list.
	if chest.size() == 3:
		check(float((chest[0] as Dictionary).depth) < float((chest[1] as Dictionary).depth)
			and float((chest[1] as Dictionary).depth) < float((chest[2] as Dictionary).depth),
			"the three lines are ordered the way the aim line meets them")
	# Same aim, same answer: a reticle that flickers between names is worse than
	# one that says nothing.
	check(labels_of(XrayCursor.structures(body, chest_from, Vector3(0, 0, 1))) == chest_labels, "the same aim resolves to the same three names")

	# --- which half of the chest the aim crosses ---------------------------
	# A rib is one hoop across both halves of the cage, so the side has to come
	# from where the aim line meets it. Two aims a few centimetres either side of
	# the midline are the same shot on two ribs, and the body says which.
	var right_labels := labels_of(XrayCursor.structures(body, chest_from + Vector3(0.06, 0, 0), Vector3(0, 0, 1)))
	var left_labels := labels_of(XrayCursor.structures(body, chest_from + Vector3(-0.06, 0, 0), Vector3(0, 0, 1)))
	print("CHEST RIGHT ", right_labels, " LEFT ", left_labels)
	check(right_labels.size() > 1 and str(right_labels[1]).begins_with("RIGHT RIB"),
		"a rib crossed on the body's right says so (%s)" % (right_labels[1] if right_labels.size() > 1 else "none"))
	check(left_labels.size() > 1 and str(left_labels[1]).begins_with("LEFT RIB"),
		"and the mirror aim says left (%s)" % (left_labels[1] if left_labels.size() > 1 else "none"))
	# A crossing on the midline is the sternum. Naming a side there would be the
	# reticle guessing at something the body does not distinguish.
	check(chest_labels.size() > 1 and not str(chest_labels[1]).begins_with("RIGHT") and not str(chest_labels[1]).begins_with("LEFT"),
		"a crossing on the midline is given no side it does not have (%s)" % (chest_labels[1] if chest_labels.size() > 1 else "none"))

	# --- a lateral shot: fewer lines rather than an invented bone -----------
	# Through the left lung the rib cage is in front and the spine is beside the
	# line, so the body can only name the lung. It must not reach for the rib it
	# did not cross behind.
	var lung := body.organ_parts.get("left_lung") as Node3D
	var lung_lines := XrayCursor.structures(body, lung.global_position + Vector3(0, 0, -1.2), Vector3(0, 0, 1))
	var lung_labels := labels_of(lung_lines)
	print("LUNG ", lung_labels)
	check(lung_labels.size() < 3 and lung_labels.has("LEFT LUNG"), "a shot with nothing behind the tissue names only the tissue (%s)" % str(lung_labels))

	# --- a limb: its own bone, and no tissue it does not have ---------------
	var arm := body.parts.get("left_arm") as Node3D
	var arm_lines := XrayCursor.structures(body, arm.global_position + Vector3(0, 0, -0.9), Vector3(0, 0, 1))
	var arm_labels := labels_of(arm_lines)
	print("ARM ", arm_labels)
	check(not arm_labels.is_empty(), "a limb still names what is there")
	check(not arm_labels.has("LEFT LUNG") and not arm_labels.has("HEART"), "and not something from the chest (%s)" % str(arm_labels))
	for label: String in arm_labels:
		check(label == "LEFT ARM BONE", "the arm's skeleton is named as the arm's own bone (%s)" % label)

	# --- the skull: the far wall counts as the bone behind the brain ---------
	var brain := body.organ_parts.get("brain") as Node3D
	var head_labels := labels_of(XrayCursor.structures(body, brain.global_position + Vector3(0, 0, -0.8), Vector3(0, 0, 1)))
	print("HEAD ", head_labels)
	check(head_labels.has("BRAIN") and head_labels.has("SKULL"), "the head names the brain and the skull it sits in (%s)" % str(head_labels))
	check(head_labels.size() == 2, "and nothing it did not cross (%s)" % str(head_labels))

	# --- the guards: no body, no names --------------------------------------
	check(XrayCursor.structures(body, Vector3(4, 1.2, -1.0), Vector3(0, 0, 1)).is_empty(), "an aim that misses the body names nothing")
	check(XrayCursor.structures(body, lung.global_position + Vector3(0, 0, -1.2), Vector3(0, 0, -1)).is_empty(), "an aim pointing away from the body names nothing")
	check(XrayCursor.structures(null, lung.global_position, Vector3(0, 0, 1)).is_empty(), "no body at all names nothing")

	# --- the sweep's own rule gates the names ------------------------------
	# The sweep still draws a skeleton through the shed on purpose (B3.4); naming
	# is the part that must not claim to have looked through it.
	var sight := get_world_3d()
	var heart_at := heart.global_position
	var clear_labels := labels_of(XrayCursor.structures(body, chest_from, Vector3(0, 0, 1), XrayCursor.READOUT_REACH, sight))
	check(clear_labels.size() == 3, "a body in line of sight names three through the world query (%s)" % str(clear_labels))
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(0.7, 0.7, 0.08)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	add_child(wall)
	wall.global_position = Vector3(heart_at.x, heart_at.y - 0.03, heart_at.z - 0.62)
	for frame in 2:
		await get_tree().physics_frame
	check(XrayCursor.structures(body, chest_from, Vector3(0, 0, 1), XrayCursor.READOUT_REACH, sight).is_empty(),
		"the same body behind a wall names nothing")
	wall.queue_free()
	for frame in 2:
		await get_tree().physics_frame
	check(labels_of(XrayCursor.structures(body, chest_from, Vector3(0, 0, 1), XrayCursor.READOUT_REACH, sight)) == clear_labels,
		"and names the same three again once the wall is gone")
	# The range half of the same rule, asked directly so it is wired rather than
	# decorative: past `WorldXray.RANGE` nothing is read at any distance.
	check(not WorldXray.reads(chest_from, chest_from + Vector3(0, 0, WorldXray.RANGE + 3.0), null),
		"past the sweep's reach nothing is read")
	check(WorldXray.reads(chest_from, heart_at, null), "and at arm's length it is")

	# --- look at it, when there is a screen to look with --------------------
	if DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		add_child(camera)
		camera.global_position = chest_from + Vector3(0, 0.0, -0.2)
		camera.look_at(chest_from + Vector3(0, 0, 1.4), Vector3.UP)
		camera.current = true
		body.reveal_organs(true)
		body.see_through(true)
		var overlay := XrayScanOverlay.new()
		add_child(overlay)
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.show_scan(body, camera)
		for frame in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var error := image.save_png(OUT)
		print("CAPTURE ", OUT, " error=", error)

	print("XRAY_STRUCTURES_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
