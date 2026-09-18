extends CanvasLayer

## Greg: *"gore sandbox is just m,ad laggy"*, *"13 FPS"*. This session measured
## the same sandbox on the same GPU at 81-175 fps in every configuration it could
## construct — idle, six full blasts, 4K, 1.5x supersampling, MSAA 4X — and never
## got below 12 ms/frame. So the gap is not in the scene, it is in the difference
## between how it is being run here and how it is being run there, and no amount
## of benchmarking from this side will find it.
##
## The previous pass asked Greg what resolution he was in and which scene was
## slow. That is the right question and the wrong way to get the answer: it makes
## the person with the problem do the measuring, and he is playing, not
## profiling. This makes the build answer for itself.
##
## F10 toggles it. F11 writes a dump next to the executable that can be sent back
## as a file rather than retyped.
##
## Deliberately cheap: the numbers come from `RenderingServer.get_rendering_info`
## and `Performance`, which the engine is already tracking, and the panel redraws
## on a timer rather than every frame. A profiler that costs frames tells you
## about itself.

const SAMPLE_WINDOW := 90
const REFRESH_SECONDS := 0.25

var showing := false
var _label: RichTextLabel
var _panel: PanelContainer
var _frames: Array[float] = []
var _refresh := 0.0
var _worst := 0.0
var _worst_age := 0.0


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_panel.position = Vector2(12, 12)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.03, 0.82)
	style.border_color = Color(0.55, 0.72, 0.35, 0.7)
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.custom_minimum_size = Vector2(430, 0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match (event as InputEventKey).keycode:
		KEY_F10:
			showing = not showing
			visible = showing
		KEY_F11:
			_dump()


func _process(delta: float) -> void:
	_frames.append(delta)
	if _frames.size() > SAMPLE_WINDOW:
		_frames.remove_at(0)
	# Hold the worst frame for a few seconds. A spike that vanishes before you
	# can read it is the one you most need to see — the sandbox's first blast
	# costs 64 ms here and nothing sustained at all.
	_worst_age += delta
	if delta > _worst or _worst_age > 4.0:
		_worst = delta
		_worst_age = 0.0
	if not showing:
		return
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = REFRESH_SECONDS
	_label.text = _report(true)


func _stats() -> Dictionary:
	var total := 0.0
	for f: float in _frames:
		total += f
	var mean: float = total / maxf(float(_frames.size()), 1.0)
	var view := get_viewport()
	var window := get_window()
	var msaa_names := ["OFF", "2X", "4X", "8X"]
	var scene := get_tree().current_scene
	return {
		"ms": mean * 1000.0,
		"fps": 1.0 / maxf(mean, 0.0001),
		"worst_ms": _worst * 1000.0,
		"window": window.size,
		"render_scale": view.scaling_3d_scale,
		"effective": Vector2i(int(window.size.x * view.scaling_3d_scale), int(window.size.y * view.scaling_3d_scale)),
		"msaa": msaa_names[clampi(int(view.msaa_3d), 0, 3)],
		"vsync": DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED,
		"fullscreen": window.mode == Window.MODE_FULLSCREEN or window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN,
		"draws": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"prims": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"vram": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"scene": scene.scene_file_path if scene != null else "(none)",
	}


func _report(rich: bool) -> String:
	var s := _stats()
	# The split that matters most and is hardest to guess at: how much of the
	# frame is script and how much is the renderer. If `process` is small and the
	# frame is long, no amount of GDScript optimisation will help.
	var gpu_ms: float = maxf(s["ms"] - s["process_ms"] - s["physics_ms"], 0.0)
	var lines := [
		"%-13s %6.2f ms   %5.1f fps    worst %6.2f ms" % ["FRAME", s["ms"], s["fps"], s["worst_ms"]],
		"%-13s script %5.2f   physics %5.2f   rest %5.2f" % ["SPLIT", s["process_ms"], s["physics_ms"], gpu_ms],
		"%-13s %dx%d%s  scale %.2f -> %dx%d" % ["OUTPUT", s["window"].x, s["window"].y,
			"  FULLSCREEN" if s["fullscreen"] else "", s["render_scale"], s["effective"].x, s["effective"].y],
		"%-13s MSAA %s   vsync %s" % ["QUALITY", s["msaa"], "ON" if s["vsync"] else "OFF"],
		"%-13s %d draws   %d objects   %.2fM prims" % ["RENDER", s["draws"], s["objects"], s["prims"] / 1000000.0],
		"%-13s %.0f MB video   %d nodes   %d orphans" % ["MEMORY", s["vram"], s["nodes"], s["orphans"]],
		"%-13s %s" % ["SCENE", s["scene"]],
	]
	var body := "\n".join(lines)
	if rich:
		return "[font_size=13][color=#cfe3a8]%s[/color]\n[color=#7d8a6a]F10 hide   F11 write a dump to send[/color][/font_size]" % body
	return body


## F11. Writes beside the executable rather than into `user://`, because the point
## is that Greg can find the file and send it without being told where Godot
## hides its application data on Windows.
func _dump() -> void:
	var dir := OS.get_executable_path().get_base_dir()
	var path := dir.path_join("perf_dump.txt")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		# Read-only install directory is a real possibility; fall back rather
		# than silently do nothing.
		path = "user://perf_dump.txt"
		file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("perf probe could not write a dump")
		return
	file.store_line("Wizards Only Fools — performance dump")
	file.store_line(Time.get_datetime_string_from_system())
	file.store_line("%s / %s" % [OS.get_name(), RenderingServer.get_video_adapter_name()])
	file.store_line("")
	file.store_line(_report(false))
	file.close()
	print("perf dump written to ", ProjectSettings.globalize_path(path) if path.begins_with("user://") else path)
