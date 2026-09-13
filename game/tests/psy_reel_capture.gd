extends Node

## AU/AT. The drug experience as a run rather than four stills: every named
## state the rig can reach, held long enough for feedback to actually build,
## photographed on the way through.
##
## `reset_dials()` between states on purpose. The earlier capture only ever
## sent the dials it was changing, so feedback_strength 0.72 was still live
## underneath the "everything" shot, and forty frames of a 0.72 accumulator at
## zoom 1.03 converge on the average of the frame - a flat grey. That is the
## real failure mode of an unclamped feedback loop, and it is worth knowing
## about, but it is not what the state was meant to look like.

const LAB := preload("res://psy_lab.tscn")

## Named states, not named drugs. AU decides which substance reaches for which
## of these; the rig has no opinion about that and should not gain one.
const STATES := [
	{"name": "00_sober", "hold": 20, "dials": {}},
	{"name": "01_come_up", "hold": 24, "dials": {
		"chromatic_offset": 0.006, "displacement_strength": 0.02, "lut_strength": 0.2,
	}},
	{"name": "02_rising", "hold": 24, "dials": {
		"chromatic_offset": 0.012, "displacement_strength": 0.04,
		"lut_strength": 0.35, "kaleidoscope_segments": 3.0, "kaleidoscope_spin": 0.15,
	}},
	{"name": "03_peak", "hold": 30, "dials": {
		"kaleidoscope_segments": 6.0, "kaleidoscope_spin": 0.35,
		"chromatic_offset": 0.018, "displacement_strength": 0.05, "lut_strength": 0.5,
	}},
	{"name": "04_peak_spun", "hold": 30, "dials": {
		"kaleidoscope_segments": 8.0, "kaleidoscope_spin": -0.6,
		"chromatic_offset": 0.022, "displacement_strength": 0.07, "lut_strength": 0.55,
	}},
	{"name": "05_trails", "hold": 60, "dials": {
		"feedback_strength": 0.55, "feedback_zoom": 1.02,
		"feedback_spin": 0.06, "chromatic_offset": 0.01,
	}},
	{"name": "06_trails_deep", "hold": 60, "dials": {
		"feedback_strength": 0.68, "feedback_zoom": 1.015,
		"feedback_spin": 0.12, "chromatic_offset": 0.014, "lut_strength": 0.3,
	}},
	{"name": "07_bad_trip", "hold": 34, "dials": {
		"kaleidoscope_segments": 3.0, "kaleidoscope_spin": -0.8,
		"displacement_strength": 0.12, "chromatic_offset": 0.03,
		"cut_intensity": 0.45, "cut_rate": 6.0, "lut_strength": 0.7,
	}},
	{"name": "08_cutting", "hold": 26, "dials": {
		"cut_intensity": 0.8, "cut_rate": 11.0, "cut_seed": 3.0,
		"chromatic_offset": 0.02, "lut_strength": 0.45,
	}},
	{"name": "09_come_down", "hold": 24, "dials": {
		"chromatic_offset": 0.008, "lut_strength": 0.25,
		"feedback_strength": 0.3, "feedback_zoom": 1.01,
	}},
	{"name": "10_sober_again", "hold": 20, "dials": {}},
]

var lab


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	var tree := get_tree()
	tree.create_timer(300.0, true, false, true).timeout.connect(func() -> void: tree.quit(3))
	await tree.process_frame

	lab = LAB.instantiate()
	tree.root.add_child(lab)
	tree.current_scene = lab
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await tree.physics_frame
	await tree.physics_frame

	# Something with edges in shot, or the effect has nothing to work on.
	lab.demo.eye = Vector3(0.0, 1.68, 7.0)
	lab.demo.yaw = 0.0
	lab.demo.pitch = -0.06
	await _settle(tree, 6)
	var centre: Vector3 = (lab.demo.bodies[0] as Dictionary)["rig"].global_position
	lab.demo._explode(centre + Vector3(0, 1.0, 0), 92.0)
	await _settle(tree, 24)

	for raw_state in STATES:
		var state: Dictionary = raw_state
		lab.rig.reset_dials()
		for dial_name: String in (state["dials"] as Dictionary):
			lab.rig.set_dial(dial_name, float((state["dials"] as Dictionary)[dial_name]))
		await _settle(tree, int(state["hold"]))
		await _shoot(tree, "%s/psy_%s.png" % [out_dir, str(state["name"])])

	print("REEL DONE: %d states" % STATES.size())
	tree.quit(0)


func _settle(tree: SceneTree, frames: int) -> void:
	for _frame in frames:
		await tree.physics_frame


func _shoot(tree: SceneTree, path: String) -> void:
	for _frame in 3:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("CAPTURED: " if image.save_png(path) == OK else "FAILED: ", path)
