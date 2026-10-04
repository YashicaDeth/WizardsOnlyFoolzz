extends Node3D

## Station 1: a glass tank of red fluid. Hit it (any weapon, or the button)
## and the glass goes: GPU particles with collision pour out across the
## floor, the spill spreads as `BloodPool` stains (the pooling the gore stack
## already uses), and walking through or shooting into the spill splashes.
## The button refills a broken tank so it can be broken again.

const LIQUID := preload("res://lab/stations/lab_liquid.gdshader")
const TITLE := "LIQUID"
const VERB := "BREAK / REFILL THE TANK"
const RADIUS := 0.7
const HEIGHT := 2.0
const PLINTH := 0.35
const BLOWS := 2
## How long the tank takes to empty, how far the spill reaches and how much
## blood-pool volume it lays down in that time (900 drops is about a full
## `BloodPool.MAX_RADIUS` stain; this is several of those meeting).
const SPILL_SECONDS := 3.6
const SPILL_REACH := 2.8
const SPILL_VOLUME := 5200.0
const FLUID := Color(0.42, 0.04, 0.03)

var lab: Node3D
var glass: MeshInstance3D
var glass_body: StaticBody3D
var fluid: MeshInstance3D
var fluid_material: ShaderMaterial
var pour: GPUParticles3D
var splash: GPUParticles3D
var hits := 0
var broken := false
var since := 0.0
var poured := 0.0
var splashes := 0
var _slosh := 0.0
var _splash_clock := 0.0
var _shards: Array[Node] = []


func build(owner_lab: Node3D) -> void:
	lab = owner_lab
	var plinth := MeshInstance3D.new()
	var base := CylinderMesh.new()
	base.top_radius = RADIUS + 0.12
	base.bottom_radius = RADIUS + 0.18
	base.height = PLINTH
	base.material = _metal(Color("2a2420"))
	plinth.mesh = base
	plinth.position = Vector3(0, PLINTH * 0.5, -2.0)
	add_child(plinth)

	fluid = MeshInstance3D.new()
	fluid.name = "Fluid"
	var column := CylinderMesh.new()
	column.top_radius = RADIUS - 0.04
	column.bottom_radius = RADIUS - 0.04
	column.height = HEIGHT * 0.9
	column.radial_segments = 32
	column.rings = 8
	fluid_material = ShaderMaterial.new()
	fluid_material.shader = LIQUID
	fluid_material.set_shader_parameter("half_height", column.height * 0.5)
	column.material = fluid_material
	fluid.mesh = column
	fluid.position = Vector3(0, PLINTH + column.height * 0.5, -2.0)
	add_child(fluid)
	# Something pale hanging in it, so the depth tint has a thing to swallow.
	var specimen := MeshInstance3D.new()
	var lump := CapsuleMesh.new()
	lump.radius = 0.16
	lump.height = 0.8
	lump.material = _metal(Color("b39684"))
	specimen.mesh = lump
	specimen.position = Vector3(0.12, PLINTH + 1.0, -2.05)
	specimen.rotation = Vector3(0.4, 0, 0.5)
	specimen.name = "Specimen"
	add_child(specimen)

	glass_body = StaticBody3D.new()
	glass_body.name = "Glass"
	glass_body.position = Vector3(0, PLINTH + HEIGHT * 0.5, -2.0)
	glass_body.set_meta("lab_station", self)
	add_child(glass_body)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = RADIUS
	cylinder.height = HEIGHT
	shape.shape = cylinder
	glass_body.add_child(shape)
	glass = MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = RADIUS
	tube.bottom_radius = RADIUS
	tube.height = HEIGHT
	tube.radial_segments = 32
	tube.cap_top = false
	tube.cap_bottom = false
	var pane := StandardMaterial3D.new()
	pane.albedo_color = Color(0.7, 0.78, 0.76, 0.12)
	pane.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pane.roughness = 0.04
	pane.metallic_specular = 0.9
	pane.cull_mode = BaseMaterial3D.CULL_DISABLED
	tube.material = pane
	glass.mesh = tube
	glass_body.add_child(glass)
	var rim := MeshInstance3D.new()
	var cap := TorusMesh.new()
	cap.inner_radius = RADIUS - 0.02
	cap.outer_radius = RADIUS + 0.07
	cap.material = _metal(Color("3a2f27"))
	rim.mesh = cap
	rim.position = Vector3(0, HEIGHT * 0.5, 0)
	glass_body.add_child(rim)

	pour = _particles("Pour", 900, 2.4, false)
	pour.position = Vector3(0, PLINTH + 0.5, -2.0)
	var flow := pour.process_material as ParticleProcessMaterial
	flow.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	flow.emission_ring_axis = Vector3.UP
	flow.emission_ring_radius = RADIUS
	flow.emission_ring_inner_radius = RADIUS * 0.6
	flow.emission_ring_height = 0.8
	flow.direction = Vector3(0, 0.3, 0)
	flow.spread = 180.0
	flow.initial_velocity_min = 1.2
	flow.initial_velocity_max = 3.4
	flow.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
	flow.collision_bounce = 0.05
	flow.collision_friction = 0.6
	add_child(pour)
	splash = _particles("Splash", 60, 0.7, true)
	var spray := splash.process_material as ParticleProcessMaterial
	spray.direction = Vector3.UP
	spray.spread = 55.0
	spray.initial_velocity_min = 1.5
	spray.initial_velocity_max = 3.2
	spray.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	add_child(splash)


func press() -> String:
	if broken:
		_refill()
		return "TANK REFILLED"
	strike(glass_body.global_position + Vector3(0, 0, RADIUS), Vector3.FORWARD, BLOWS)
	return "GLASS BROKEN"


## A blow or a round on the glass. `weight` blows at once (the button is two).
func strike(at: Vector3, direction: Vector3, weight := 1) -> Dictionary:
	if broken:
		touch(at, 1.0)
		return {"hit": true, "broken": true}
	hits += weight
	_slosh = 0.06
	if hits < BLOWS:
		(glass.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color.a = 0.3
		return {"hit": true, "broken": false}
	_break(direction)
	return {"hit": true, "broken": true}


## Feet or a round at `at`: a splash if there is spill under it.
func touch(at: Vector3, strength := 1.0) -> bool:
	if lab == null or BloodPool.volume_at(lab, at) <= 0.0:
		return false
	splash.global_position = Vector3(at.x, 0.05, at.z)
	splash.amount_ratio = clampf(strength, 0.2, 1.0)
	splash.restart()
	splashes += 1
	return true


## Called by the lab every physics frame with the player's feet and speed.
func wade(feet: Vector3, speed: float, delta: float) -> void:
	_splash_clock -= delta
	if speed > 1.0 and _splash_clock <= 0.0 and touch(feet, speed / 6.0):
		_splash_clock = 0.32


func status() -> String:
	if not broken:
		return "TANK FULL   %d/%d BLOWS" % [hits, BLOWS]
	return "SPILLED %d%%   POOLS %d   SPLASHES %d" % [roundi(poured / SPILL_VOLUME * 100.0), BloodPool.pool_count(lab), splashes]


func _process(delta: float) -> void:
	_slosh = move_toward(_slosh, 0.0, delta * 0.05)
	fluid_material.set_shader_parameter("slosh", _slosh)
	if not broken:
		return
	since += delta
	var drained := clampf(since / SPILL_SECONDS, 0.0, 1.0)
	var level := maxf(0.0, 1.0 - drained)
	fluid.scale.y = maxf(level, 0.001)
	fluid.position.y = PLINTH + HEIGHT * 0.9 * 0.5 * level
	fluid.visible = level > 0.01
	pour.emitting = drained < 1.0
	if drained < 1.0 and poured < SPILL_VOLUME:
		# The stain spreads from the tank's foot outward as the tank empties.
		var share := SPILL_VOLUME * delta / SPILL_SECONDS
		var reach := lerpf(RADIUS + 0.3, SPILL_REACH, ease(drained, 0.6))
		var angle := randf() * TAU
		var from := global_position + Vector3(0, 0.0, -2.0)
		var at := from + Vector3(cos(angle), 0, sin(angle)) * randf_range(RADIUS, reach)
		BloodPool.keep(lab, Vector3(at.x, 0.0, at.z), share)
		poured += share


func _break(direction: Vector3) -> void:
	broken = true
	since = 0.0
	poured = 0.0
	glass.visible = false
	(glass_body.get_child(0) as CollisionShape3D).set_deferred("disabled", true)
	_slosh = 0.12
	pour.restart()
	pour.emitting = true
	var shard_material := StandardMaterial3D.new()
	shard_material.albedo_color = Color(0.7, 0.78, 0.76, 0.35)
	shard_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shard_material.roughness = 0.05
	shard_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for index in 18:
		var shard := RigidBody3D.new()
		shard.mass = 0.05
		shard.collision_layer = 1 << 3
		shard.collision_mask = 1
		var piece := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(randf_range(0.08, 0.3), randf_range(0.12, 0.4), 0.01)
		prism.material = shard_material
		piece.mesh = prism
		shard.add_child(piece)
		var hull := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = prism.size
		hull.shape = box
		shard.add_child(hull)
		add_child(shard)
		var around := TAU * randf()
		var out := Vector3(cos(around), 0, sin(around))
		shard.global_position = glass_body.global_position + out * RADIUS + Vector3(0, randf_range(-0.8, 0.9), 0)
		shard.linear_velocity = (out + direction * 0.4 + Vector3(0, randf_range(0.1, 0.6), 0)).normalized() * randf_range(1.5, 4.5)
		shard.angular_velocity = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
		_shards.append(shard)
	WorldHistory.record_event("mechanics_lab_tank_broken", {"blows": hits})


func _refill() -> void:
	broken = false
	hits = 0
	since = 0.0
	glass.visible = true
	(glass.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color.a = 0.12
	(glass_body.get_child(0) as CollisionShape3D).set_deferred("disabled", false)
	fluid.scale.y = 1.0
	fluid.position.y = PLINTH + HEIGHT * 0.9 * 0.5
	fluid.visible = true
	pour.emitting = false
	for shard in _shards:
		if is_instance_valid(shard):
			shard.queue_free()
	_shards.clear()
	BloodPool.clear()


func _particles(label: String, amount: int, life: float, one_shot: bool) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = label
	particles.amount = amount
	particles.lifetime = life
	particles.one_shot = one_shot
	particles.explosiveness = 1.0 if one_shot else 0.0
	particles.emitting = false
	particles.visibility_aabb = AABB(Vector3(-6, -2, -6), Vector3(12, 6, 12))
	var process := ParticleProcessMaterial.new()
	process.gravity = Vector3(0, -9.8, 0)
	process.scale_min = 0.6
	process.scale_max = 1.4
	particles.process_material = process
	var drop := SphereMesh.new()
	drop.radius = 0.025
	drop.height = 0.05
	drop.radial_segments = 6
	drop.rings = 3
	var wet := StandardMaterial3D.new()
	wet.albedo_color = FLUID
	wet.roughness = 0.08
	wet.metallic_specular = 0.8
	drop.material = wet
	particles.draw_pass_1 = drop
	return particles


func _metal(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.55
	material.metallic = 0.4
	return material
