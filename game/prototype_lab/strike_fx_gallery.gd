extends Node3D

## A blade swung round the whole body over a locked target: the trail, the
## trailing cable and the lock ring together. `-- --shot=PATH` captures one
## frame mid-sweep and quits.

var pivot: Node3D
var blade: Node3D
var trail: StrikeTrail
var ring: LockRing
var smear: StrikeSmear
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
	var cam := Camera3D.new()
	cam.position = Vector3(2.6, 2.6, 3.2)
	add_child(cam)
	cam.look_at(Vector3(0, 0.9, -0.8))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shot="):
			_shoot(argument.trim_prefix("--shot="))


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


func _shoot(path: String) -> void:
	for _frame in 50:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)
	get_tree().quit(0)
