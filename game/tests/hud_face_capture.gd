extends Node

## imp-68. The field HUD's face and pocket rack, in each look the dial offers,
## over the real places it is seen: the Hunt (where it is wired), the gore range
## (`gore_demo`, the lab that wears it) and the facility aisle. The facility
## runs the BodyCamOSD, not this HUD; that shot lays the field HUD over the
## aisle only to judge it against the facility's light. Plus a close sheet of
## each look in four body states.
## Windowed only: AgentHub/render_one.cmd hud_face_capture --shots=DIR

const FIELD_HUD := preload("res://systems/gothic_field_hud.gd")
const STYLES := ["xray", "bodycam", "mask"]
const HURT := {
	"health": 48.0, "blood": 0.62, "stamina": 30.0, "pain": 64.0, "consciousness": 72.0,
	"wound_regions": {"head": 0.35, "torso": 0.0, "arms": 0.0, "legs": 0.0},
}
const STATES := [
	{"tag": "whole", "health": 100.0, "blood": 1.0, "stamina": 100.0, "pain": 0.0, "consciousness": 100.0, "wound_regions": {"head": 0.0}},
	{"tag": "winded", "health": 90.0, "blood": 0.96, "stamina": 12.0, "pain": 8.0, "consciousness": 100.0, "wound_regions": {"head": 0.0}},
	{"tag": "hurt", "health": 48.0, "blood": 0.62, "stamina": 30.0, "pain": 64.0, "consciousness": 72.0, "wound_regions": {"head": 0.35}},
	{"tag": "dying", "health": 14.0, "blood": 0.28, "stamina": 20.0, "pain": 95.0, "consciousness": 24.0, "wound_regions": {"head": 0.8}},
]
const POCKETS := [
	{"label": "KIDNEY", "kind": "organ"},
	{"label": "BENZO — GREY (PILL)", "kind": "substance"},
]

var shots := "P:/GameDev/Temp/imp68"


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("HUD_FACE_CAPTURE headless draws nothing; use AgentHub/render_one.cmd")
		get_tree().quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.trim_prefix("--shots=")
	DirAccess.make_dir_recursive_absolute(shots)
	var tree := get_tree()
	tree.create_timer(200.0, true, false, true).timeout.connect(func() -> void: tree.quit(3))
	get_window().size = Vector2i(1280, 720)
	await _hunt()
	await _gore_range()
	await _facility()
	await _sheet()
	print("HUD_FACE_CAPTURE_RESULT shots=%s" % shots)
	tree.quit()


func _styles(hud: Control) -> Array:
	return STYLES if "face_style" in hud else ["before"]


func _apply(hud: Control, style: String, state: Dictionary) -> void:
	if style != "before":
		hud.set("face_style", style)
	var values := state.duplicate()
	values.erase("tag")
	values["pockets"] = POCKETS
	hud.call("set_state", values)


func _hunt() -> void:
	WorldHistory.clear_history()
	WorldHistory.world_minute = 12 * 60
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	hunt.player_body.position = Vector3(0, 0.9, 19)
	hunt.player = hunt.player_body.position + Vector3.UP * 0.6
	hunt.yaw = 0.0
	hunt.pitch = -0.05
	hunt._equip_weapon(1)
	await _frames(20)
	hunt._update_hud()
	# The Hunt feeds the HUD every frame from the body; hold it on the hurt
	# reading the shot is about.
	hunt.set_process(false)
	var hud: Control = hunt.field_interface
	for style in _styles(hud):
		_apply(hud, style, HURT)
		# The Hunt's own head handling (hide or film) runs in _update_camera;
		# with physics held it would also move the lens, so the shot keeps its own.
		var shot: Transform3D = hunt.camera.global_transform
		for _tick in 30:
			hunt._update_camera()
			hunt.camera.global_transform = shot
			await get_tree().process_frame
		await _shoot("hunt_%s.png" % style)
		if style == "bodycam" and hud.face_monitor._feed != null:
			var monitor: FaceMonitor = hud.face_monitor
			print("FEED head=%s visible=%s at=%s cam=%s rigged=%s" % [monitor.head, monitor.head.is_visible_in_tree() if monitor.head else false, monitor.head.global_position if monitor.head else Vector3.ZERO, monitor._feed_camera.global_position, hunt.player_rig.rigged])
			monitor._feed.get_texture().get_image().save_png(shots.path_join("feed_raw.png"))
	hunt.queue_free()
	await _frames(4)


func _gore_range() -> void:
	WorldHistory.clear_history()
	var demo = load("res://gore_demo.tscn").instantiate()
	add_child(demo)
	await _frames(30)
	demo.set_process(false)
	var hud: Control = demo.field_hud
	for style in _styles(hud):
		_apply(hud, style, HURT)
		await _frames(30)
		await _shoot("lab_%s.png" % style)
	demo.queue_free()
	await _frames(4)


func _facility() -> void:
	WorldHistory.clear_history()
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	await _frames(8)
	vat.phase = "aisle"
	vat.breakout_complete = true
	vat.can_move = true
	vat.fade.color.a = 0.0
	vat.submerge_tint.color.a = 0.0
	if vat.intake != null:
		vat.intake.queue_free()
		vat.intake = null
	vat.subtitle.text = ""
	vat.line_index = vat.active_beats.size()
	if vat.load_in != null:
		vat.load_in.visible = false
	vat._open_staff_door(false)
	vat.camera.current = true
	vat.player.global_position = Vector3(18.0, 0.86, -2.5)
	vat.yaw = -PI * 0.5
	vat.osd.visible = false
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var hud: Control = FIELD_HUD.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)
	await _frames(20)
	for style in _styles(hud):
		_apply(hud, style, HURT)
		await _frames(30)
		await _shoot("facility_%s.png" % style)
	layer.queue_free()
	vat.queue_free()
	await _frames(4)


## Each look in four states, cropped to the right-hand column it lives in.
func _sheet() -> void:
	var back := ColorRect.new()
	back.color = Color("1a1b1c")
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(back)
	var hud: Control = FIELD_HUD.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)
	await _frames(4)
	for style in _styles(hud):
		for state: Dictionary in STATES:
			_apply(hud, style, state)
			await _frames(24)
			await _shoot("state_%s_%s.png" % [style, str(state.tag)])
	layer.queue_free()


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame


func _shoot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := shots.path_join(file)
	if image.save_png(path) == OK:
		print("CAPTURED: ", path)
	else:
		print("CAPTURE_FAILED ", path)
