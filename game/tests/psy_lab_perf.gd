extends Node

## Greg, 30 September: "the performance of the schizophrenia sandbox is
## terrible". Real-GPU frame time of psy_lab at 1920x1080, vsync off. Each
## switch is measured ON ITS OWN against the same scene and then put back, and
## the baseline is measured again at the end so drift and noise are visible.
## Windowed only; headless draws nothing.

var lab: Node
var demo: Node
var stage := -1
var t0 := 0
var frames := 0
var worst := 0.0
var last := 0
var warm := 0
const WARM_FRAMES := 30
const SAMPLE_MS := 4000

## [label, turn it on/off (true = the change), undo]
var stages: Array = []


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("psy_lab perf: skipped headless (needs a real renderer)")
		get_tree().quit(0)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	get_window().size = Vector2i(1920, 1080)
	lab = load("res://psy_lab.tscn").instantiate()
	add_child(lab)


func _build_stages() -> void:
	stages = [
		["baseline: idle, first person", func() -> void: pass, func() -> void: pass],
		["third person", func() -> void: _tp(true), func() -> void: _tp(false)],
		["enemies attacking (third person)", func() -> void: _tp(true); demo._set_enemies_enabled(true), func() -> void: demo._set_enemies_enabled(false); _tp(false)],
		["- psychedelic rig hidden", func() -> void: lab.rig.visible = false, func() -> void: lab.rig.visible = true],
		["- readout hidden", func() -> void: lab.readout.visible = false, func() -> void: lab.readout.visible = true],
		["- field HUD hidden", func() -> void: demo.field_hud.visible = false, func() -> void: demo.field_hud.visible = true],
		["- sandbox HUD hidden", func() -> void: demo.hud.visible = false, func() -> void: demo.hud.visible = true],
		["- bodies hidden", func() -> void: _bodies(false), func() -> void: _bodies(true)],
		["baseline again", func() -> void: pass, func() -> void: pass],
		["after 40 cuts (gore on the floor)", func() -> void: _cuts(), func() -> void: pass],
	]


func _tp(on: bool) -> void:
	demo.third_person = on
	demo.avatar.third_person = on


func _bodies(on: bool) -> void:
	for entry: Dictionary in demo.bodies:
		var holder := entry.get("holder") as Node3D
		if holder != null and is_instance_valid(holder):
			holder.visible = on
			holder.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func _cuts() -> void:
	for i in 40:
		var entry: Dictionary = demo.bodies[i % demo.bodies.size()]
		var rig: BaselineHuman = entry.rig
		if is_instance_valid(rig):
			rig.hit_at(rig.global_position + Vector3(randf_range(-0.3, 0.3), randf_range(0.2, 1.7), 0.0), 30.0, 20.0, "cut", Vector3.FORWARD)


func _process(_delta: float) -> void:
	if demo == null:
		demo = lab.get("demo")
		if demo != null:
			_build_stages()
		return
	var now := Time.get_ticks_usec()
	if stage >= 0:
		warm += 1
		if warm > WARM_FRAMES:
			frames += 1
			if frames == 1:
				t0 = now
			elif last > 0:
				worst = maxf(worst, (now - last) / 1000.0)
	last = now
	if stage < 0 or (frames > 1 and (now - t0) / 1000.0 >= SAMPLE_MS):
		if stage >= 0:
			var ms := (now - t0) / 1000.0 / float(frames - 1)
			print("PERF %-36s %6.1f fps  %6.2f ms/frame  worst %6.1f ms" % [stages[stage][0], 1000.0 / ms, ms, worst])
			(stages[stage][2] as Callable).call()
		stage += 1
		if stage >= stages.size():
			print("PSY_LAB_PERF_RESULT failures=0")
			get_tree().quit(0)
			return
		(stages[stage][1] as Callable).call()
		warm = 0
		frames = 0
		worst = 0.0
