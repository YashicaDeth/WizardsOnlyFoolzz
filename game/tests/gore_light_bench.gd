extends Node

## Follow-up to `gore_load_bench`, which ruled gore out: the sandbox idles at
## 164 fps and six full blasts only cost ~3 ms. So the cost is in the arena, and
## the arena has 974 meshes and a pile of lights.
##
## In Forward+ every shadow-casting light re-renders the scene's geometry into
## its own shadow map — an omni light does it six times, once per cube face. So
## the cost of a light is not "a light", it is a multiple of the whole scene, and
## it scales with resolution the way Greg's fullscreen number would.
##
## This counts them, then switches shadows off and measures again. Turning a
## thing off and watching the number move is the only way to attribute cost
## honestly; reading the scene and guessing is how you end up shipping a 9% fix
## as a solution.

const SAMPLE_FRAMES := 120

var demo: Node


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_window().size = Vector2i(1920, 1080)

	demo = load("res://gore_demo.tscn").instantiate()
	add_child(demo)
	for _settle in 180:
		await get_tree().process_frame

	var lights := _lights(demo)
	var shadowed: Array[Light3D] = []
	var omni := 0
	var spot := 0
	var directional := 0
	for light: Light3D in lights:
		if light.shadow_enabled:
			shadowed.append(light)
		if light is OmniLight3D:
			omni += 1
		elif light is SpotLight3D:
			spot += 1
		elif light is DirectionalLight3D:
			directional += 1
	print("lights: %d total (%d omni, %d spot, %d directional), %d casting shadows" % [
		lights.size(), omni, spot, directional, shadowed.size()])

	var base := await _sample("SHADOWS ON")

	for light: Light3D in shadowed:
		light.shadow_enabled = false
	var off := await _sample("SHADOWS OFF")
	print("  shadows cost: %.2f ms/frame (%.0f%% of the frame)" % [
		base["ms"] - off["ms"], 100.0 * (base["ms"] - off["ms"]) / maxf(base["ms"], 0.001)])

	# Put them back, then take the lights out entirely — the difference between
	# "shadows are expensive" and "lights are expensive" is a different fix.
	for light: Light3D in shadowed:
		light.shadow_enabled = true
	for light: Light3D in lights:
		light.visible = false
	var dark := await _sample("LIGHTS OFF")
	print("  lights cost: %.2f ms/frame (%.0f%% of the frame)" % [
		base["ms"] - dark["ms"], 100.0 * (base["ms"] - dark["ms"]) / maxf(base["ms"], 0.001)])
	for light: Light3D in lights:
		light.visible = true

	# And what Greg's fullscreen actually costs. Same scene, more pixels.
	get_window().size = Vector2i(2560, 1440)
	await get_tree().process_frame
	var at_1440 := await _sample("1440p")
	get_window().size = Vector2i(3840, 2160)
	await get_tree().process_frame
	var at_2160 := await _sample("2160p")
	print("  1080p -> 1440p: %.2f ms -> %.2f ms | 2160p: %.2f ms" % [base["ms"], at_1440["ms"], at_2160["ms"]])

	print("GORE_LIGHT_BENCH_RESULT done")
	get_tree().quit(0)


func _sample(label: String) -> Dictionary:
	for _warm in 25:
		await get_tree().process_frame
	var total := 0.0
	for _frame in SAMPLE_FRAMES:
		await get_tree().process_frame
		total += get_process_delta_time()
	var ms := (total / float(SAMPLE_FRAMES)) * 1000.0
	var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	print("%-14s %6.2f ms  %6.1f fps | draws %5d" % [label, ms, 1000.0 / maxf(ms, 0.001), draws])
	return {"ms": ms, "draws": draws}


func _lights(root: Node) -> Array[Light3D]:
	var found: Array[Light3D] = []
	if root is Light3D:
		found.append(root)
	for child in root.get_children():
		found.append_array(_lights(child))
	return found
