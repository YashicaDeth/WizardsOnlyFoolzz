extends Node

## Runs a CuriosityBot on a real scene, unattended, and writes what held its
## attention (JSON + Markdown). Measures only; changes nothing in the scene.
##
##   ATG_TEST_MODE=1 godot --headless --path game res://tests/curiosity_run.tscn \
##       -- --scene=res://old_drains.tscn --seconds=600 --speed=8 --out=/some/dir
##
## --seconds is SIMULATED time (default 30, so a sweep of every test scene
## only smoke-tests it; real studies pass --seconds=600 or more). --speed runs physics that many times faster
## than real time at the normal 1/60 s step (physics ticks and time scale
## both scale, so each step is still the step the scene was tuned with).
## --seed fixes the bot's dice. --verbs=E,F picks the keys it tries on things.
## If the scene travels somewhere else, the bot follows the new scene.

const DEFAULT_SCENE := "res://bone_yard_hunt.tscn"

var bot: CuriosityBot
var target: Node
var seconds := 30.0
var out_dir := "user://curiosity_runs"
var scene_path := DEFAULT_SCENE
var started_msec := 0
var last_progress := 0.0


func _args() -> Dictionary:
	var parsed := {}
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var key := arg.substr(2, arg.find("=") - 2)
			parsed[key] = arg.substr(arg.find("=") + 1)
	return parsed


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		push_error("curiosity_run needs ATG_TEST_MODE=1 so it cannot touch a real save")
		get_tree().quit(2)
		return
	var args := _args()
	scene_path = str(args.get("scene", DEFAULT_SCENE))
	seconds = float(args.get("seconds", "30"))
	out_dir = str(args.get("out", out_dir))
	var speed := maxf(1.0, float(args.get("speed", "8")))
	Engine.physics_ticks_per_second = int(60.0 * speed)
	Engine.max_physics_steps_per_frame = int(8.0 * speed)
	Engine.time_scale = speed
	await get_tree().process_frame
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("cannot load " + scene_path)
		get_tree().quit(3)
		return
	target = packed.instantiate()
	get_tree().root.add_child(target)
	get_tree().current_scene = target
	bot = CuriosityBot.new()
	bot.rng.seed = int(args.get("seed", "7"))
	if args.has("verbs"):
		bot.verbs.assign(str(args.verbs).split(",", false))
	add_child(bot)
	bot.bind(target)
	started_msec = Time.get_ticks_msec()
	print("CURIOSITY_RUN scene=%s seconds=%s speed=%s" % [scene_path, seconds, speed])


func _physics_process(_delta: float) -> void:
	if bot == null:
		return
	var current := get_tree().current_scene
	if current != null and current != target and current != self:
		target = current
		bot.bind(target)
		print("CURIOSITY_RUN followed into ", target.scene_file_path)
	if bot.sim_time - last_progress >= 30.0:
		last_progress = bot.sim_time
		print("CURIOSITY_RUN t=%ds cells=%d things=%d events=%d real=%ds" % [int(bot.sim_time), bot.visited.size(), bot.things.size(), bot.event_stats.size(), (Time.get_ticks_msec() - started_msec) / 1000])
	if bot.sim_time >= seconds:
		_finish()


func _finish() -> void:
	var data := bot.report()
	bot.enabled = false
	bot.queue_free()
	bot = null
	data["real_seconds"] = snappedf((Time.get_ticks_msec() - started_msec) / 1000.0, 0.1)
	data["target_scene"] = scene_path
	var name := scene_path.get_file().get_basename()
	var dir := out_dir
	if dir.begins_with("user://") or dir.begins_with("res://"):
		dir = ProjectSettings.globalize_path(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	var json_path := dir.path_join("curiosity_%s.json" % name)
	var md_path := dir.path_join("curiosity_%s.md" % name)
	var json := FileAccess.open(json_path, FileAccess.WRITE)
	json.store_string(JSON.stringify(data, "  "))
	json.close()
	var md := FileAccess.open(md_path, FileAccess.WRITE)
	md.store_string(CuriosityBot.markdown(data, "Curiosity run: %s, %d simulated s" % [scene_path, int(data.sim_seconds)]))
	md.close()
	print("CURIOSITY_RUN wrote ", json_path, " and ", md_path)
	print("CURIOSITY_RUN_RESULT failures=0 cells=%d coverage=%s events=%d real_s=%s" % [data.cells_visited, data.coverage_pct, (data.events as Array).size(), data.real_seconds])
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	get_tree().quit(0)
