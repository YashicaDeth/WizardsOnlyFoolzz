extends Node

## Same scene, same GPU, wildly different number. The sandbox measures 97-166 fps
## here and Greg sees 13, so the gap is not the content — it is what the viewport
## is being asked to do per pixel.
##
## Two settings compound: `_cycle_resolution` offers 1.25 and 1.5, which are
## SUPERSAMPLING (1.5 renders 2.25x the pixels and throws most away), and ULTRA
## sets MSAA 4X on top. At fullscreen 1440p with both, the fragment work is
## roughly sixteen times a 1080p no-MSAA frame.

const SAMPLE_FRAMES := 100
var demo: Node

func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	demo = load("res://gore_demo.tscn").instantiate()
	add_child(demo)
	for _s in 180:
		await get_tree().process_frame

	for combo in [
		{"res": Vector2i(1920,1080), "scale": 1.0, "msaa": Viewport.MSAA_DISABLED, "tag": "1080p  scale 1.0  no MSAA  (PERFORMANCE-ish)"},
		{"res": Vector2i(2560,1440), "scale": 1.0, "msaa": Viewport.MSAA_DISABLED, "tag": "1440p  scale 1.0  no MSAA"},
		{"res": Vector2i(2560,1440), "scale": 1.0, "msaa": Viewport.MSAA_4X,       "tag": "1440p  scale 1.0  MSAA 4X  (ULTRA)"},
		{"res": Vector2i(2560,1440), "scale": 1.5, "msaa": Viewport.MSAA_DISABLED, "tag": "1440p  scale 1.5  no MSAA"},
		{"res": Vector2i(2560,1440), "scale": 1.5, "msaa": Viewport.MSAA_4X,       "tag": "1440p  scale 1.5  MSAA 4X  <-- worst case"},
	]:
		get_window().size = combo["res"]
		get_viewport().scaling_3d_scale = combo["scale"]
		get_viewport().msaa_3d = combo["msaa"]
		for _w in 40:
			await get_tree().process_frame
		var total := 0.0
		for _f in SAMPLE_FRAMES:
			await get_tree().process_frame
			total += get_process_delta_time()
		var ms := (total / float(SAMPLE_FRAMES)) * 1000.0
		print("%-46s %7.2f ms  %6.1f fps" % [combo["tag"], ms, 1000.0 / maxf(ms, 0.001)])

	print("GORE_SETTINGS_BENCH_RESULT done")
	get_tree().quit(0)
