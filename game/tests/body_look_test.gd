extends Node3D

## imp-60 (Greg, 5 Oct ~19:00: "improve the bodies further (checker skin,
## helmet heads, hunched idle, ankle gaps)"). The rigged people of the route
## wear a real human skin: a face with eyes and brows, flesh (not the world
## grain) on bare zones and cloth on clothed ones, an upright idle, legs that
## run unbroken to the sole, the guard's vest on his body and the examiner's
## loupes on his eyes. A hurt zone still hands back the rig's own body.

const GUARD := preload("res://systems/v01_guard.gd")
const FACE_BOXES := ["Eye_L", "Eye_R", "Pupil_L", "Nose_Bridge", "Mouth_Upper", "Jaw_Line", "Brow_Ridge"]

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	WorldHistory.clear_history()
	if not RiggedBody.HUMAN_SKIN:
		print("BODY_LOOK_TEST: HUMAN_SKIN dial is off; nothing to check")
		print("BODY_LOOK_TEST_RESULT failures=0")
		get_tree().quit(0)
		return
	var subject := _person("look_subject", {})
	var styled := _person("look_styled", {"flesh": Color("6a4a43")})
	HunterAppearance.style_world_rig(styled, "look_styled", false)
	var female := _person("look_female", {"frame": 0.18})
	await _frames(6)
	_test_skin(subject)
	_test_face(styled)
	_test_posture(subject)
	_test_legs_unbroken(subject)
	check(female.rigged.human == "female", "a narrow frame wears the female base (%s)" % female.rigged.human)
	await _test_guard()
	await _test_examiner()
	await _test_hurt_zone_gives_back(styled)
	print("BODY_LOOK_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _person(id: String, extra: Dictionary) -> BaselineHuman:
	var body := BaselineHuman.new()
	add_child(body)
	body.build(id, {"rigged": true, "gore": true}.merged(extra, true))
	body.position = Vector3(get_child_count() * 1.5, 0, 0)
	return body


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame


func _test_skin(body: BaselineHuman) -> void:
	print("BODY LOOK - a human skin with its own face, flesh on bare zones")
	var rigged := body.rigged
	check(rigged != null and rigged.human == "male", "the rig wears the human base (%s)" % (rigged.human if rigged else "no rig"))
	if rigged == null:
		return
	for zone: String in RiggedBody.ZONES:
		check(not (rigged.zone_meshes[zone] as Array).is_empty(), "%s has skin" % zone)
	var head_own := 0
	for instance: MeshInstance3D in rigged.zone_meshes.head:
		if instance.has_meta("own_material"):
			head_own += 1
	check(head_own >= 2, "the head carries its eyes and brows (%d own-material meshes)" % head_own)
	var torso: MeshInstance3D = rigged.zone_meshes.torso[0]
	check(torso.material_override == RiggedBody.flesh_material("male"), "a bare zone wears the flesh shader, not the world grain")
	var mesh := torso.mesh as ArrayMesh
	check(mesh.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0] != null, "the skin carries its rest positions for grime and scars")
	var tone: Color = torso.get_meta("skin_tone", Color.WHITE)
	check(tone.r < 0.7 and tone.r > tone.b, "the flesh tone is the body's flesh, not the grain's white tint (%s)" % tone)


func _test_face(body: BaselineHuman) -> void:
	print("BODY LOOK - the procedural face boxes give way to the skin's face")
	var head := body.parts.head as Node3D
	var shown: Array[String] = []
	for box: String in FACE_BOXES:
		var piece := head.get_node_or_null(box) as Node3D
		if piece != null and piece.visible:
			shown.append(box)
	check(shown.is_empty(), "no box eyes, nose, mouth or brow over the real face (%s)" % ", ".join(shown))
	for child in head.get_children():
		if child.has_meta("mutation"):
			check((child as Node3D).visible, "a mutation (%s) stays on the skinned head" % child.name)
			break


func _test_posture(body: BaselineHuman) -> void:
	print("BODY LOOK - an upright idle, not the hunched crouch")
	var skeleton := body.rigged.skeleton
	for clip: String in ["Idle", "Walk"]:
		body.rigged.player.play(clip)
		body.rigged.player.seek(0.3, true)
		skeleton.force_update_all_bone_transforms()
		# Walking leans in a little more, as people do.
		for pair: Array in [["spine_03", 9.0 if clip == "Idle" else 12.0], ["Head", 6.0]]:
			var bone := skeleton.find_bone(str(pair[0]))
			var up := skeleton.get_bone_global_pose(bone).basis.y.normalized()
			var rest := skeleton.get_bone_global_rest(bone).basis.y.normalized()
			var forward := rad_to_deg(atan2(up.z, up.y)) - rad_to_deg(atan2(rest.z, rest.y))
			check(absf(forward) < float(pair[1]), "%s: %s leans %.1f deg from upright (under %.0f)" % [clip, pair[0], forward, pair[1]])
	body.rigged.player.play("Idle")


## The mannequin's ankles were separate balls with a dark gap above the foot.
## The human leg has skin at every height from the sole to the knee.
func _test_legs_unbroken(body: BaselineHuman) -> void:
	print("BODY LOOK - no gap at the ankle")
	# Each triangle covers the heights between its lowest and highest corner;
	# the union of those spans must run unbroken from the sole to the knee.
	var spans: Array[Vector2] = []
	for instance: MeshInstance3D in body.rigged.zone_meshes.left_leg:
		var arrays := (instance.mesh as ArrayMesh).surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for triangle in indices.size() / 3:
			var a := vertices[indices[triangle * 3]].y
			var b := vertices[indices[triangle * 3 + 1]].y
			var c := vertices[indices[triangle * 3 + 2]].y
			spans.append(Vector2(minf(a, minf(b, c)), maxf(a, maxf(b, c))))
	spans.sort_custom(func(x: Vector2, y: Vector2) -> bool: return x.x < y.x)
	var reach := spans[0].y if not spans.is_empty() else -1.0
	var hole := 0.0
	for span in spans:
		if span.x > 0.55:
			break
		hole = maxf(hole, span.x - reach)
		reach = maxf(reach, span.y)
	check(not spans.is_empty() and spans[0].x < 0.02, "the leg's skin reaches the sole (%.3f m)" % (spans[0].x if not spans.is_empty() else -1.0))
	check(hole <= 0.0, "no height of the lower leg without skin (largest hole %.3f m)" % maxf(hole, 0.0))


func _test_guard() -> void:
	print("BODY LOOK - the guard's vest is on his body, not a slab in front of it")
	var guard := GUARD.new()
	guard.configure("pistol", "07", 0.0)
	guard.set("foe_id", "look_guard_07")
	add_child(guard)
	guard.call("_build_body")
	await _frames(4)
	var rig := guard.get("body") as BaselineHuman
	check(rig.rigged != null and not rig.rigged.kit.is_empty(), "the vest colours ride the rigged skin")
	var kit := (rig.parts.torso as Node3D).get_node_or_null("SecurityKit")
	var boxes := 0
	var stencils := 0
	for child in kit.get_children() if kit != null else []:
		if child is Label3D:
			stencils += 1
		elif child is MeshInstance3D:
			boxes += 1
	check(boxes == 1, "only the holster is a box (%d boxes)" % boxes)
	check(stencils == 2, "the number is on the plates front and back (%d)" % stencils)
	var torso: MeshInstance3D = rig.rigged.zone_meshes.torso[0]
	check(torso.material_override == RiggedBody.cloth_material(rig.rigged.human), "the uniform is cloth on the body")
	guard.queue_free()


func _test_examiner() -> void:
	print("BODY LOOK - the examiner's loupes sit on his eyes")
	var body := _person("office_examiner_look", BaselineHuman.config_from_subject({"race": "decanted"}))
	ExaminerLook.dress(body, false)
	await _frames(4)
	var loupes := (body.parts.head as Node3D).get_node_or_null("Loupes") as Node3D
	check(loupes != null and loupes.position.is_equal_approx(ExaminerLook.HUMAN_LOUPES), "the loupes are placed for the human face")
	var torso: MeshInstance3D = body.rigged.zone_meshes.torso[0]
	var coat: Color = torso.get_meta("skin_tone", Color.BLACK)
	check(coat.r > 0.7 and coat.a > 0.2, "the coat is off-white with the blood as stains (%s)" % coat)


func _test_hurt_zone_gives_back(body: BaselineHuman) -> void:
	print("BODY LOOK - a hurt head hands back the rig's own head and face")
	var head := body.parts.head as Node3D
	body.hit_at(head.global_position + Vector3(0, 0, -0.08), 14.0, 2.0, "cut", Vector3.BACK)
	await _frames(6)
	check(body.rigged.modes.head == "body", "the cut head shows the rig's own wounded flesh")
	var nose := head.get_node_or_null("Nose_Bridge") as Node3D
	check(nose != null and nose.visible, "its procedural face comes back with it")
