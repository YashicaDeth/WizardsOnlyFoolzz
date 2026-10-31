extends Node

## Greg's 30 September playtest dropped to 7 fps (134 ms frames, GPU 3-5 ms,
## script 16, physics 34) while a fresh sandbox measures 160+. Something
## accumulates in real play. This plays a two-minute third-person fight
## through the pad the way a person does (move, lock, lights, heavies, rolls,
## guard, get hit) and logs every 10 s what the frame costs and how much of
## everything there is, so whatever grows shows itself. Windowed only.

const SECONDS := 120.0
const REPORT_EVERY := 10.0

var lab: Node
var demo
var clock := 0.0
var window_clock := 0.0
var frames := 0
var worst := 0.0
var last_us := 0
var next_action := 0.0
var step := 0
var last_action := ""
var spikes := 0
var last_pipelines := 0
var last_surface := 0
var last_draw := 0
var last_spec := 0


## Every render pipeline Godot has compiled so far (canvas, mesh, surface,
## draw, specialization). A spike with this climbing is shader compilation.
func _pipelines() -> int:
	return int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION))


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("psy_lab soak: skipped headless (needs a real renderer)")
		get_tree().quit(0)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	get_window().size = Vector2i(1600, 900)
	lab = load("res://psy_lab.tscn").instantiate()
	add_child(lab)


func _axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = demo.pad.device
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)


func _tap(button: JoyButton) -> void:
	for down in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = demo.pad.device
		event.button_index = button
		event.pressed = down
		Input.parse_input_event(event)


func _count(type: String) -> int:
	return demo.find_children("*", type, true, false).size()


## One action every ~0.35 s, cycling like a person fighting would.
func _act() -> void:
	step += 1
	var angle := float(step) * 0.7
	_axis(JOY_AXIS_LEFT_X, cos(angle) * 0.8)
	_axis(JOY_AXIS_LEFT_Y, sin(angle) * 0.8)
	_axis(JOY_AXIS_RIGHT_X, 0.3 if step % 6 < 3 else -0.3)
	last_action = ["R1", "O roll", "move", "R1", "R2 down", "R2 up", "R1", "R3 lock", "L1 guard", "move"][step % 10]
	match step % 10:
		0, 3, 6: _tap(JOY_BUTTON_RIGHT_SHOULDER)
		1: _tap(JOY_BUTTON_B)
		4:
			_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
		5:
			_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
		7:
			if demo.avatar.lock_target == null:
				_tap(JOY_BUTTON_RIGHT_STICK)
		8:
			var guard := InputEventJoypadButton.new()
			guard.device = demo.pad.device
			guard.button_index = JOY_BUTTON_LEFT_SHOULDER
			guard.pressed = step % 20 < 10
			Input.parse_input_event(guard)
	# A body that has been knocked over is replaced now and then, like a
	# player pressing R after clearing the room.
	var standing := 0
	for index in demo.bodies.size():
		if demo._can_duel(index):
			standing += 1
	if standing == 0:
		last_action = "R reset"
		demo._reset()


func _process(delta: float) -> void:
	if demo == null:
		demo = lab.get("demo")
		if demo != null:
			demo.arsenal.select_slot(HunterArsenal.SLOT_ORDER.find("cleaver"))
			demo._toggle_view()
			demo._set_enemies_enabled(true)
			demo.spar_level = 1
		return
	var now := Time.get_ticks_usec()
	if last_us > 0:
		var frame_ms := (now - last_us) / 1000.0
		worst = maxf(worst, frame_ms)
		if frame_ms > 100.0 and spikes < 40:
			spikes += 1
			print("SPIKE %6.1f ms at t=%5.1fs after [%s] note [%s] chunks %d | last blow %.1f ms | enemy blow %.1f ms | pipelines +%d (surface +%d, draw +%d, spec +%d)" % [frame_ms, clock, last_action, str(demo.last_note), GoreChunks.live_count(), demo.last_contact_ms, demo.last_enemy_strike_ms, _pipelines() - last_pipelines, int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)) - last_surface, int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)) - last_draw, int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)) - last_spec])
	last_us = now
	last_pipelines = _pipelines()
	last_surface = int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE))
	last_draw = int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW))
	last_spec = int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION))
	clock += delta
	window_clock += delta
	frames += 1
	next_action -= delta
	if next_action <= 0.0:
		next_action = 0.35
		_act()
	if window_clock >= REPORT_EVERY:
		last_us = 0  # the report walks the tree: not a game spike
		var ms := window_clock * 1000.0 / float(frames)
		print("SOAK t=%3.0fs %6.1f fps %6.2f ms worst %6.1f | script %5.2f physics %5.2f | nodes %5d objects %6d | rigid %3d active %3d | meshes %4d decals %3d particles %3d | chunks %3d | draws %4d | health %3d" % [
			clock, 1000.0 / ms, ms, worst,
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_COUNT),
			_count("RigidBody3D"),
			Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
			_count("MeshInstance3D"), _count("Decal"),
			_count("GPUParticles3D") + _count("CPUParticles3D"),
			GoreChunks.live_count(),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			demo.simulation_health])
		window_clock = 0.0
		frames = 0
		worst = 0.0
	if clock >= SECONDS:
		print("PSY_LAB_SOAK_RESULT failures=0")
		get_tree().quit(0)
