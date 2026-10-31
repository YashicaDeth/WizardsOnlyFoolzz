extends Node

## imp-68. The HUD FACE dial: one default, each look swaps the face and the
## pockets together, the pocket tags read what a pocket holds, and the body-cam
## keeps the head off the eye's layers without hiding it from the feed.

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
	var hud := preload("res://systems/gothic_field_hud.gd").new()
	add_child(hud)
	check(hud.face_style == FaceMonitor.DEFAULT_STYLE and FaceMonitor.DEFAULT_STYLE == "bodycam", "the default face is the body-cam (Greg, 6 Oct night)")
	check(hud.face_monitor.visible and hud.nerve_rig.pocket_style == "spine", "default: the CRT face and pockets as tags off the spine")
	hud.face_style = "mask"
	check(not hud.face_monitor.visible and hud.nerve_rig.pocket_style == "rack", "mask: the old face and the bottle rack come back together")
	hud.face_style = "nonsense"
	check(hud.face_style == FaceMonitor.DEFAULT_STYLE, "an unknown style falls back to the default")
	WorldHistory.update_subject("settings", {"hud_face": "bodycam"}, "hud_setting_changed")
	hud._poll_face_setting()
	check(hud.face_style == "bodycam", "the pause menu's HUD FACE row reaches the HUD")
	check(not hud.face_monitor.feeding(), "no head to film: the body-cam shows the skull plate")

	check(NerveRig.pocket_glyph({"kind": "organ"}) == "meat" and NerveRig.pocket_glyph({"kind": "substance"}) == "pill" and NerveRig.pocket_glyph({"kind": "bone"}) == "bone", "a tag's mark says what the pocket holds")
	check(NerveRig.pocket_name({"label": "Benzo — grey (pill)"}) == "BENZO", "a tag's name is the item's first word")

	# A body with a head, as the Hunt has.
	var body := Node3D.new()
	body.set_script(preload("res://tests/hud_face_test_body.gd"))
	add_child(body)
	var head := MeshInstance3D.new()
	var hat := MeshInstance3D.new()
	head.add_child(hat)
	body.add_child(head)
	body.parts = {"head": head}
	var eye := Camera3D.new()
	add_child(eye)
	hud.attach_head(body)
	check(hud.face_monitor.feeding(), "with a head attached the body-cam films it")
	var face: FaceMonitor = hud.face_monitor
	face.film_head(eye, body, true)
	var bit := 1 << (FaceMonitor.HEAD_LAYER - 1)
	check(head.layers == bit and hat.layers == bit and not eye.get_cull_mask_value(FaceMonitor.HEAD_LAYER), "eye inside the skull: the head and what it wears leave the eye's layers")
	face.film_head(eye, body, false)
	check(head.layers == 1 and hat.layers == 1 and eye.get_cull_mask_value(FaceMonitor.HEAD_LAYER), "eye out of the skull: the head is back where every camera sees it")

	print("HUD_FACE_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
