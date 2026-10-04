extends Node3D

## Station 1: a glass tank of red fluid, on the shared GlassTank + FluidBody
## (the same pair the opening vat adopts in Job 4).
##
## Greg (5 Oct): "it shouldn't instantly dissipate and it should be an actual
## fluid as well as an actual glass." Each blow cracks the glass a stage; the
## last bursts it outward with the fluid's pressure behind it; the tank pours
## for several seconds into a pool that stays and creeps to the grate; wading
## ripples, splashes and prints; the button shocks the spill (a test shock
## until the shock staff lands in Job 3): a dummy standing in it is hit, the
## one on dry floor is not.
##
## USE cycles: smash the tank -> shock the spill -> refill.

const TITLE := "LIQUID"
const VERB := "SMASH / SHOCK / REFILL"
const PLINTH := 0.35
const TANK_AT := Vector3(0, 0, -2.0)
const BODIES := preload("res://lab/stations/bodies_station.gd")

var lab: Node3D
var tank: GlassTank
var fluid: FluidBody
var glass_body: StaticBody3D
var wet_dummy: BaselineHuman
var dry_dummy: BaselineHuman
var player_shock_taken := 0.0
var last_shocked: Array[Node3D] = []
var _bump_clock := 0.0
var _shocked_since_break := false


var broken: bool:
	get: return tank.broken
var hits: int:
	get: return tank.hits
var splashes: int:
	get: return fluid.splashes


func build(owner_lab: Node3D) -> void:
	lab = owner_lab
	var plinth := MeshInstance3D.new()
	var base := CylinderMesh.new()
	base.top_radius = 0.82
	base.bottom_radius = 0.88
	base.height = PLINTH
	base.material = _metal(Color("2a2420"))
	plinth.mesh = base
	plinth.position = TANK_AT + Vector3(0, PLINTH * 0.5, 0)
	add_child(plinth)
	var foot := StaticBody3D.new()
	foot.position = plinth.position
	var foot_shape := CollisionShape3D.new()
	var foot_cylinder := CylinderShape3D.new()
	foot_cylinder.radius = 0.85
	foot_cylinder.height = PLINTH
	foot_shape.shape = foot_cylinder
	foot.add_child(foot_shape)
	add_child(foot)

	fluid = FluidBody.new()
	fluid.name = "Spill"
	fluid.position = TANK_AT
	add_child(fluid)
	fluid.setup(lab, 3.84, Vector2(2.6, 0.6))

	tank = GlassTank.new()
	tank.name = "Tank"
	tank.position = TANK_AT + Vector3(0, PLINTH, 0)
	tank.fluid = fluid
	add_child(tank)
	glass_body = tank.body
	glass_body.set_meta("lab_station", self)
	tank.burst.connect(_on_burst)
	# Something pale hanging in it, so the depth tint has a thing to swallow.
	var specimen := MeshInstance3D.new()
	specimen.name = "Specimen"
	var lump := CapsuleMesh.new()
	lump.radius = 0.16
	lump.height = 0.8
	lump.material = _metal(Color("b39684"))
	specimen.mesh = lump
	tank.hold(specimen, Vector3(0.12, 1.0, -0.05))

	# Two dummies for the current: one where the spill will run, one dry.
	wet_dummy = BODIES.dummy(self, "liquid_wet_dummy", TANK_AT + Vector3(-1.1, 0, 1.0), PI * 0.8)
	dry_dummy = BODIES.dummy(self, "liquid_dry_dummy", TANK_AT + Vector3(-4.6, 0, 0.6), PI * 0.6)


func press() -> String:
	if not tank.broken:
		tank.strike(glass_body.global_position + Vector3(0, 0, tank.radius), Vector3.FORWARD, tank.blows)
		return "GLASS BURST"
	if not _shocked_since_break and fluid.wet_cells() > 0:
		var struck := shock(fluid.global_position + Vector3(0, 0, 1.0))
		return "SPILL SHOCKED  %d STANDING IN IT" % struck.size()
	_refill()
	return "TANK REFILLED"


## The shock staff's hook (Job 3): current into the wet floor at `at`.
func shock(at: Vector3) -> Array[Node3D]:
	_shocked_since_break = true
	var extra: Array = []
	if lab != null and lab.get("player") != null:
		extra.append(lab.player)
	last_shocked = fluid.shock(at, extra)
	if lab != null and last_shocked.has(lab.get("player")):
		player_shock_taken += fluid.shock_damage
	return last_shocked


## A blow or a round on the glass.
func strike(at: Vector3, direction: Vector3, weight := 1) -> Dictionary:
	var result := tank.strike(at, direction, weight)
	if result.broken:
		fluid.splash(at * Vector3(1, 0, 1) + Vector3(0, fluid.global_position.y, 0), 1.0)
	return result


## Feet or a round at `at`: a splash if there is spill under it.
func touch(at: Vector3, strength := 1.0) -> bool:
	return fluid.splash(at, strength)


## Called by the lab every physics frame with the walker, feet and velocity.
func wade(walker: Node3D, feet: Vector3, velocity: Vector3, delta: float) -> void:
	fluid.wade(walker, feet, velocity, delta)
	GlassTank.kick(feet, velocity)
	# Walking into the tank sloshes it.
	_bump_clock -= delta
	var local := tank.to_local(feet)
	var flat := Vector2(local.x, local.z)
	if _bump_clock <= 0.0 and flat.length() < tank.radius + 0.45 and Vector2(velocity.x, velocity.z).length() > 1.0:
		_bump_clock = 0.6
		tank.slosh(Vector3(local.x, 0, local.z), 0.35)


func pouring() -> bool:
	return fluid.blob_count() > 0


func status() -> String:
	if not tank.broken:
		return "TANK FULL   CRACKS %d/%d" % [tank.hits, tank.blows - 1]
	return "LEVEL %d%%  POOL %.0f L  DRAINED %.1f L  SPLASH %d  SHOCKS %d" % [roundi(tank.level * 100.0), fluid.volume() * 1000.0, fluid.drained * 1000.0, fluid.splashes, fluid.shocks]


func _on_burst(direction: Vector3) -> void:
	_shocked_since_break = false
	# Debris carried out with the pour, to float on the spill.
	for index in 3:
		var chunk := RigidBody3D.new()
		chunk.name = "Floater"
		chunk.mass = 0.05
		chunk.collision_layer = 1 << 3
		chunk.collision_mask = 1
		var piece := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.09, 0.03, 0.06) * (1.0 + index * 0.3)
		box.material = _metal(Color("b39684").darkened(0.2 * index))
		piece.mesh = box
		chunk.add_child(piece)
		var hull := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size
		hull.shape = shape
		chunk.add_child(hull)
		add_child(chunk)
		var around := atan2(-direction.z, -direction.x) + randf_range(-0.8, 0.8)
		chunk.global_position = tank.to_global(Vector3(cos(around) * 0.8, 0.6, sin(around) * 0.8))
		chunk.linear_velocity = Vector3(cos(around), 0.5, sin(around)) * 2.0
		fluid.add_floater(chunk)
	WorldHistory.record_event("mechanics_lab_tank_broken", {"blows": tank.hits})


func _refill() -> void:
	tank.refill()
	fluid.clear()
	for child in get_children():
		if child.name.begins_with("Floater"):
			child.queue_free()
	BloodPool.clear()
	Footprints.clear()


func _metal(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.55
	material.metallic = 0.4
	return material
