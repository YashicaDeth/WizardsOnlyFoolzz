extends Node3D

## Job 2, BUILD 4: the rigged death ragdoll under whichever 3D physics engine
## the project runs (Godot Physics, or Jolt through a temporary override.cfg).
## Eight corpses, four kinds of blow, six seconds each; prints one line per
## engine that the report compares. Not a pass/fail suite (no `_test` suffix).
##
##   ATG_TEST_MODE=1 godot --headless --path game res://tests/rigged_ragdoll_engine_probe.tscn

const BODIES := 8
const SECONDS := 6.0
const BLOWS := ["", "light_1", "heavy", "charged_heavy"]


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var floor := StaticBody3D.new()
	add_child(floor)
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 0.10, 60.0)
	collider.shape = box
	collider.position.y = -0.05
	floor.add_child(collider)
	var bodies: Array[BaselineHuman] = []
	for index in BODIES:
		var holder := Node3D.new()
		holder.position = Vector3(float(index) * 3.0 - 10.5, 0.9, 0.0)
		holder.rotation.y = float(index) * 0.7
		add_child(holder)
		var body := BaselineHuman.new()
		body.position.y = -0.9
		holder.add_child(body)
		body.build("probe_%d" % index, {"gore": false, "ragdoll": true, "rigged": true})
		bodies.append(body)
	for index in 20:
		await get_tree().process_frame
	var directions := [Vector3.LEFT, Vector3.FORWARD, Vector3.BACK, Vector3.RIGHT]
	for index in BODIES:
		var direction: Vector3 = directions[index % 4]
		bodies[index].hit("head", 400.0, 4.0 + index, "puncture", "brain", direction, 1.0, null, null, BLOWS[index % BLOWS.size()])
	var worst_gap := 0.0
	var worst_speed := 0.0
	var step_ms := 0.0
	var steps := 0
	var settled_at := {}
	var elapsed := 0.0
	while elapsed < SECONDS:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		step_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		steps += 1
		for index in BODIES:
			var rigged := bodies[index].rigged
			if rigged == null:
				continue
			worst_gap = maxf(worst_gap, rigged.max_joint_gap())
			for physical: PhysicalBone3D in rigged.physical_bones.values():
				worst_speed = maxf(worst_speed, physical.linear_velocity.length())
			if rigged.ragdoll_settled and not settled_at.has(index):
				settled_at[index] = elapsed
	var exploded := 0
	var floor_min := INF
	var rest_gap := 0.0
	for body in bodies:
		var torso := body.parts.torso as Node3D
		floor_min = minf(floor_min, torso.global_position.y)
		if absf(torso.global_position.y) > 2.0 or body.rigged.max_joint_gap() > 0.5:
			exploded += 1
		rest_gap = maxf(rest_gap, body.rigged.max_joint_gap())
	var settle_mean := 0.0
	for value: float in settled_at.values():
		settle_mean += value
	settle_mean = settle_mean / maxf(1.0, float(settled_at.size()))
	print("RAGDOLL_ENGINE engine=%s scale=%.3f exploded=%d/%d settled=%d/%d mean_settle=%.2fs worst_gap_falling=%.3fm worst_gap_rest=%.3fm fastest_bone=%.1fm/s lowest_torso=%.2fm physics_step=%.3fms" % [
		ProjectSettings.get_setting("physics/3d/physics_engine"), bodies[0].rigged.model_scale,
		exploded, BODIES, settled_at.size(), BODIES, settle_mean, worst_gap, rest_gap, worst_speed, floor_min, step_ms / maxf(1.0, float(steps))])
	get_tree().quit(0)
