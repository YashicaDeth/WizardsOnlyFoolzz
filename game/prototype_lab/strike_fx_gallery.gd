extends Node3D

## A blade swung round the whole body over a locked target: the trail, the
## trailing cable and the lock ring together. `-- --shot=PATH` captures one
## frame mid-sweep and quits.

var pivot: Node3D
var blade: Node3D
var trail: StrikeTrail
var ring: LockRing
var smear: StrikeSmear
var dust: DustPuff
var flash: HitFlash
var _dust_clock := 0.3
var target: Node3D
var clock := 0.0


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.05, 0.045, 0.05)
	env.environment.glow_enabled = true
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.15, 0.14)
	ground.material_override = mat
	add_child(ground)
	target = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.height = 1.8
	(target as MeshInstance3D).mesh = capsule
	target.position = Vector3(0, 0.9, -2.2)
	add_child(target)
	pivot = Node3D.new()
	pivot.position = Vector3(0, 1.2, 0)
	add_child(pivot)
	blade = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.02, 1.1)
	(blade as MeshInstance3D).mesh = box
	var holder := Node3D.new()
	pivot.add_child(holder)
	holder.position = Vector3(0, 0, -0.35)
	holder.add_child(blade)
	blade.position = Vector3(0, 0, -0.55)
	trail = StrikeTrail.new()
	add_child(trail)
	ring = LockRing.new()
	add_child(ring)
	smear = StrikeSmear.new()
	add_child(smear)
	dust = DustPuff.new()
	add_child(dust)
	flash = HitFlash.new()
	add_child(flash)
	var cam := Camera3D.new()
	cam.position = Vector3(2.6, 2.6, 3.2)
	add_child(cam)
	cam.look_at(Vector3(0, 0.9, -0.8))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shot="):
			_shoot(argument.trim_prefix("--shot="))
		elif argument == "--perf":
			_perf()


func _process(delta: float) -> void:
	clock += delta
	# A full round-the-body sweep, tilting as it goes, the way a spinning whip
	# cut comes over and around rather than only forward.
	pivot.rotation = Vector3(sin(clock * 3.0) * 0.5, clock * 7.5, 0.35)
	var commit := clampf(0.5 + 0.5 * sin(clock * 2.0), 0.0, 1.0)
	var holder := blade.get_parent() as Node3D
	trail.feed_weapon(holder, delta, commit)
	smear.feed(holder, holder.global_transform * trail.tip_local(holder), delta, commit)
	ring.follow(Vector3(target.position.x, 0.0, target.position.z))
	# A dodge beside the target every 0.7 s, travelling to the right.
	_dust_clock -= delta
	if _dust_clock <= 0.0:
		_dust_clock = 0.7
		dust.burst(Vector3(-1.4, 0.0, -0.4), Vector3(1, 0, 0))
		# And a landed blow on the target between dodges, for the recorded reel.
		flash.burst(target.position + Vector3(0.2, 0.2, 0.3), Vector3(0.3, 0, -1), 1.0)


func _shoot(path: String) -> void:
	for frame in 50:
		if frame == 42:
			dust.burst(Vector3(-1.4, 0.0, -0.4), Vector3(1, 0, 0))
		if frame == 47:
			flash.burst(target.position + Vector3(0.2, 0.2, 0.3), Vector3(0.3, 0, -1), 1.0)
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)
	get_tree().quit(0)


## `-- --perf`: five fighters swinging with trail, cable and smear, dodging
## (dust) and landing blows (flash), against the same five with the effects
## off. Prints mean frame time.
var _fx_rigs: Array[Dictionary] = []


func _perf() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for i in 5:
		var p := Node3D.new()
		p.position = Vector3(-3.0 + i * 1.5, 1.2, -1.0)
		add_child(p)
		var h := Node3D.new()
		p.add_child(h)
		var b := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.05, 0.02, 1.1)
		b.mesh = box
		b.position = Vector3(0, 0, -0.55)
		h.add_child(b)
		var t := StrikeTrail.new()
		add_child(t)
		var s := StrikeSmear.new()
		add_child(s)
		_fx_rigs.append({"pivot": p, "holder": h, "trail": t, "smear": s})
	var results := {}
	for mode in ["off", "on"]:
		for _warm in 60:
			await get_tree().process_frame
		var frames := 300
		var start := Time.get_ticks_usec()
		for _f in frames:
			await get_tree().process_frame
		results[mode] = float(Time.get_ticks_usec() - start) / 1000.0 / frames
		_fx_on = true
	print("PERF combat fx x5 (trail, cable, smear, dust, flash): off %.2f ms/frame, on %.2f ms/frame, cost %.2f ms" % [results.off, results.on, results.on - results.off])
	get_tree().quit(0)


var _fx_on := false
var _perf_tick := 0


func _physics_process(delta: float) -> void:
	for i in _fx_rigs.size():
		var rig: Dictionary = _fx_rigs[i]
		(rig.pivot as Node3D).rotation = Vector3(0.3, clock * (7.0 + i), 0.35)
		if _fx_on:
			(rig.trail as StrikeTrail).feed_weapon(rig.holder, delta, 0.9)
			(rig.smear as StrikeSmear).feed(rig.holder, (rig.holder as Node3D).global_transform * (rig.trail as StrikeTrail).tip_local(rig.holder), delta, 0.9)
			# A heavy fight: each fighter dodges about every 0.5 s and lands a
			# blow about every 0.33 s, through the shared dust and flash pools.
			_perf_tick += 1
			if _perf_tick % 30 == i * 6:
				dust.burst((rig.pivot as Node3D).global_position - Vector3(0, 1.2, 0), Vector3(1, 0, 0))
			if _perf_tick % 20 == i * 4:
				flash.burst((rig.pivot as Node3D).global_position, Vector3(0, 0, -1), 1.0)
