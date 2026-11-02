extends Node

## A windowed look at the reload, which Greg called broken. Nothing here is a
## gate; `reload_anim_test` is the gate. This writes frames and the numbers
## behind them so the claim can be checked by looking.
##
##   render_one.cmd reload_anim_capture --shots=P:/GameDev/Temp/reload_anim
##
## For each firearm: rest, then ten frames evenly through the reload, then the
## same again while the gun is shouldered (ADS), because the aim pose is
## applied after the reload pose in `FirstPersonArms.pose()` and that ordering
## is the first thing to suspect when a reload "does nothing".

const SHOTS := 10

var lab: Node3D
var arms: FirstPersonArms
var shots := "P:/GameDev/Temp/reload_anim"


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shots="):
			shots = argument.trim_prefix("--shots=")
	if DisplayServer.get_name() == "headless":
		print("RELOAD_ANIM_CAPTURE headless draws nothing; run windowed")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(shots)
	# The first run captured at 1280x720 and then at 1280x557: the window
	# settles into its own size a moment after launch, and comparing a crop
	# across two heights compares two different pictures. Pin it, and wait for
	# the resize to land before the first shot.
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _seconds(1.0)
	BloodPool.clear()
	lab = load("res://lab/mechanics_lab.tscn").instantiate()
	add_child(lab)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _seconds(0.8)
	arms = lab.held_mount
	lab.player.global_position = Vector3(0, 1.0, 17.0)
	lab.player.velocity = Vector3.ZERO
	lab.yaw = 0.0
	lab.pitch = -0.05
	await _seconds(0.4)

	for weapon_id in ["sidearm", "shotgun"]:
		lab.arsenal.select_weapon(weapon_id)
		await _seconds(0.4)
		await _shot("%s_rest" % weapon_id)
		await _reload(weapon_id, "plain")
		# Shouldered, then reloaded: the case where the aim pose is applied
		# after the reload pose.
		await _aim(true)
		await _seconds(0.4)
		await _shot("%s_ads_rest" % weapon_id)
		await _reload(weapon_id, "ads")
		await _aim(false)
		await _seconds(0.3)

	print("RELOAD_ANIM_CAPTURE wrote %s" % shots)
	get_tree().quit(0)


func _reload(weapon_id: String, label: String) -> void:
	# Fire once so there is a round missing, and let the cooldown clear: the
	# first refusals are silent, which is half of what "broken" means.
	lab.arsenal.begin_attack()
	await _seconds(0.6)
	lab.arsenal.ammo[weapon_id]["loaded"] = 1
	var accepted: bool = lab.arsenal.reload()
	var duration := float(lab.arsenal.current().get("reload", 1.0))
	_log("== %s/%s accepted=%s duration=%.2f loaded=%d reserve=%d" % [
		weapon_id, label, str(accepted), duration,
		int(lab.arsenal.ammo[weapon_id]["loaded"]), int(lab.arsenal.ammo[weapon_id]["reserve"]),
	])
	var rest: Vector3 = arms.held.position
	for frame in SHOTS:
		await _shot("%s_%s_%02d" % [weapon_id, label, frame])
		var magazine := arms.held.find_child("magazine", true, false) as Node3D
		_log("  frame %02d phase=%s reload_left=%.2f magazine_y=%.4f mount_moved=%.3f ammo=%d" % [
			frame, arms.last_phase, lab.arsenal.reload_remaining,
			magazine.position.y if magazine != null else 0.0,
			arms.held.position.distance_to(rest),
			int(lab.arsenal.ammo[weapon_id]["loaded"]),
		])
		await _seconds(duration / float(SHOTS))
	await _seconds(0.4)
	# After it finishes: the pose has to be home again, not parked where the
	# last frame of the swap left it.
	await _shot("%s_%s_done" % [weapon_id, label])
	_log("  done phase=%s reload_left=%.2f mount_moved=%.3f ammo=%d" % [
		arms.last_phase, lab.arsenal.reload_remaining,
		arms.held.position.distance_to(rest),
		int(lab.arsenal.ammo[weapon_id]["loaded"]),
	])


func _log(line: String) -> void:
	print("RELOAD_ANIM_CAPTURE ", line)
	var file := FileAccess.open(shots.path_join("reload.txt"), FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(shots.path_join("reload.txt"), FileAccess.WRITE)
	file.seek_end()
	file.store_line(line)
	file.close()


func _aim(on: bool) -> void:
	var event := InputEventAction.new()
	event.action = "parry"
	event.pressed = on
	Input.parse_input_event(event)
	await _seconds(0.2)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots.path_join(shot_name + ".png"))


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
