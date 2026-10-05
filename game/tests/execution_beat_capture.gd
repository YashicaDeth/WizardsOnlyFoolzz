extends Node

## Fix-58 visual proof: three frames of a cleaver execution in the mechanics
## lab (drawn back, the blow, over the corpse). Windowed only, through
## AgentHub/render_one.cmd:
##   render_one.cmd execution_beat_capture --out=P:/GameDev/Temp/fix58
## Optional --weapon=cleaver|staff|sidearm.

var lab: Node3D
var out := "P:/GameDev/Temp/fix58"
var weapon := "cleaver"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--weapon="):
			weapon = arg.trim_prefix("--weapon=")
	DirAccess.make_dir_recursive_absolute(out)
	lab = load("res://lab/mechanics_lab.tscn").instantiate()
	add_child(lab)
	await _frames(20)
	lab.arsenal.select_weapon(weapon)
	lab.sparring._spawn()
	await _frames(4)
	var rig: BaselineHuman = lab.sparring.rig
	rig.hit("left_leg", 30.0, 4.0, "cut")
	rig.anatomy.go_down()
	await _frames(40)
	var holder: Node3D = lab.sparring.holder
	var side := holder.global_basis.x
	side.y = 0.0
	lab.player.global_position = Vector3(holder.global_position.x, lab.player.global_position.y, holder.global_position.z) + side.normalized() * 2.0
	var to: Vector3 = rig.global_position - lab.player.global_position
	lab.yaw = atan2(-to.x, -to.z)
	lab.pitch = -0.4
	await _frames(10)
	print("EXECUTION_CAPTURE begin=", lab.execute_downed())
	var shots := {"wind": false, "blow": false, "after": false}
	var guard := 0
	while lab.execution.active and guard < 600:
		await get_tree().process_frame
		guard += 1
		if not shots.wind and lab.execution.phase == "wind" and lab.execution.wind() > 0.8:
			shots.wind = _shot("1_wind")
		elif not shots.blow and lab.execution.phase == "hold" and lab.execution.clock > 0.05:
			shots.blow = _shot("2_blow")
		elif not shots.after and lab.execution.phase == "hold" and lab.execution.clock > 0.42:
			shots.after = _shot("3_after")
	await _frames(30)
	if not shots.after:
		_shot("3_after")
	print("EXECUTION_CAPTURE dead=", rig.anatomy.dead, " report=", lab.execution.report.get("reason", ""))
	get_tree().quit(0)


func _shot(name: String) -> bool:
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s_%s.png" % [out, weapon, name]
	image.save_png(path)
	print("EXECUTION_CAPTURE shot ", path)
	return true


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame
