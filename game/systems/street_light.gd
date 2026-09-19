class_name StreetLight
extends StaticBody3D

## AB1.2. `DESIGN/DESTRUCTION.md` step two: one object class, all the way
## through the loop the design doc actually asks for — condition -> break
## state -> shed debris -> recorded -> queryable -> (later) repaired — proved
## on the cheapest, most visible target before anything is asked to hold up a
## building. Condition lives in `WorldHistory` through `world_damage.gd`
## exactly like the handheld's own `condition` field; there is no second,
## scene-local number that could disagree with it.
##
## Four authored break states, the exact ladder the design doc names for this
## object: intact, flickering, sparking with the glass gone, hanging by its
## cable. Nothing here simulates a crack propagating through a mesh — a hit
## moves one number, and that number decides which of four small, authored
## looks is showing.

const WORLD_DAMAGE := preload("res://systems/world_damage.gd")
const WORLD_DEBRIS := preload("res://systems/world_debris.gd")
const WORLD_LOOK := preload("res://systems/world_look.gd")

const DEBRIS_POOL := "streetlight_glass"
const MAX_DEBRIS_ULTRA := 24
const MAX_DEBRIS_HIGH := 16
const MAX_DEBRIS_PERFORMANCE := 8

## The design doc's own words for this object, in order from full condition
## to none. `_shed()` fires the moment condition crosses into "sparking" —
## the glass is gone by the time it would be visible as gone.
const BANDS := [
	{"floor": 0.7, "label": "intact"},
	{"floor": 0.4, "label": "flickering"},
	{"floor": 0.1, "label": "sparking"},
	{"floor": 0.0, "label": "hanging"},
]

const MIN_IMPACT_SPEED := 3.0
const DAMAGE_PER_SPEED := 0.05

var subject_id := ""
var pole_height := 4.2

var _arm: Node3D
var _head: MeshInstance3D
var _glass: MeshInstance3D
var _lamp: OmniLight3D
var _band := ""
var _shed := false


## Places a real, struckable fixture and gives it a `WorldHistory` subject if
## it does not already have one — a second call against the same id (a
## reloaded scene finding a light the world already knows about) reads that
## history back rather than resetting it to full.
func build(id: String, height := 4.2) -> void:
	subject_id = id
	pole_height = maxf(2.4, height)
	if WorldHistory.subject(subject_id).is_empty():
		WorldHistory.register_subject(subject_id, {"kind": "streetlight"})
	_build_geometry()
	_shed = WORLD_DAMAGE.condition(subject_id) <= BANDS[2]["floor"]
	_refresh_visual(true)


func condition() -> float:
	return WORLD_DAMAGE.condition(subject_id)


func band() -> String:
	return WORLD_DAMAGE.band(subject_id, BANDS)


## The struck path a bullet or a fixed amount already knows how to speak.
func strike(amount: float, cause: String, direction := Vector3.FORWARD) -> Dictionary:
	var result := WORLD_DAMAGE.damage(subject_id, amount, cause, BANDS)
	if bool(result.get("ok", false)):
		_refresh_visual(false, direction)
	return result


## The vehicle/derby path — the same closing-speed contract `breakable_prop.gd`
## already exposes, so a car does not need to know this is a different object
## class to hit it.
func impact(closing_speed: float, direction := Vector3.FORWARD, contribution := 1.0) -> Dictionary:
	var speed := maxf(0.0, closing_speed)
	if speed <= MIN_IMPACT_SPEED:
		return {"ok": false, "reason": "TOO SLOW TO DAMAGE"}
	var share := clampf(contribution, 0.2, 1.0)
	var amount := (speed - MIN_IMPACT_SPEED) * DAMAGE_PER_SPEED * share
	return strike(amount, "vehicle_impact", direction)


static func debris_budget() -> int:
	match WORLD_LOOK.quality:
		WORLD_LOOK.Quality.ULTRA:
			return MAX_DEBRIS_ULTRA
		WORLD_LOOK.Quality.PERFORMANCE:
			return MAX_DEBRIS_PERFORMANCE
		_:
			return MAX_DEBRIS_HIGH


func _build_geometry() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var pole := MeshInstance3D.new()
	pole.name = "Pole"
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.07
	pole_mesh.bottom_radius = 0.1
	pole_mesh.height = pole_height
	pole_mesh.material = _material(Color("2c2822"))
	pole.mesh = pole_mesh
	pole.position = Vector3(0, pole_height * 0.5, 0)
	add_child(pole)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.11
	shape.height = pole_height
	collision.shape = shape
	collision.position = Vector3(0, pole_height * 0.5, 0)
	add_child(collision)

	_arm = Node3D.new()
	_arm.name = "Arm"
	_arm.position = Vector3(0, pole_height, 0)
	add_child(_arm)
	var crossbar := MeshInstance3D.new()
	crossbar.name = "Crossbar"
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(0.7, 0.07, 0.07)
	bar_mesh.material = _material(Color("2c2822"))
	crossbar.mesh = bar_mesh
	crossbar.position = Vector3(0.35, 0.0, 0.0)
	_arm.add_child(crossbar)

	_head = MeshInstance3D.new()
	_head.name = "Head"
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.34, 0.16, 0.24)
	head_mesh.material = _material(Color("39352d"))
	_head.mesh = head_mesh
	_head.position = Vector3(0.68, -0.03, 0.0)
	_arm.add_child(_head)

	_glass = MeshInstance3D.new()
	_glass.name = "Glass"
	var glass_mesh := BoxMesh.new()
	glass_mesh.size = Vector3(0.26, 0.05, 0.16)
	var glass_material := _material(Color("e8dfa8"))
	glass_material.emission_enabled = true
	glass_material.emission = Color("e8dfa8")
	glass_material.emission_energy_multiplier = 1.4
	glass_mesh.material = glass_material
	_glass.mesh = glass_mesh
	_glass.position = Vector3(0.68, -0.11, 0.0)
	_arm.add_child(_glass)

	_lamp = OmniLight3D.new()
	_lamp.name = "Lamp"
	_lamp.light_color = Color("e8dfa8")
	_lamp.light_energy = 1.1
	_lamp.omni_range = 9.0
	_lamp.shadow_enabled = false
	_lamp.position = Vector3(0.68, -0.16, 0.0)
	_arm.add_child(_lamp)


## Re-reads the recorded condition and moves the visible state to match it.
## Idempotent on an unchanged band so a caller can ask for a refresh after
## every hit without the fixture re-shedding glass it already dropped.
func _refresh_visual(initial: bool, direction := Vector3.FORWARD) -> void:
	var new_band := band()
	if new_band == _band and not initial:
		return
	_band = new_band
	match _band:
		"intact":
			_lamp.visible = true
			_lamp.light_energy = 1.1
			_glass.visible = true
			_arm.rotation = Vector3.ZERO
		"flickering":
			_lamp.visible = true
			_lamp.light_energy = 0.45
			_glass.visible = true
			_arm.rotation = Vector3.ZERO
		"sparking":
			_lamp.visible = false
			_glass.visible = false
			_arm.rotation = Vector3.ZERO
			_head.mesh.material.albedo_color = Color("1c1a17")
		"hanging":
			_lamp.visible = false
			_glass.visible = false
			# The whole fixture droops on its cable rather than sitting level —
			# the fourth authored look, not a fifth mesh.
			_arm.rotation = Vector3(0, 0, deg_to_rad(52.0))
			_head.mesh.material.albedo_color = Color("1c1a17")
	if _band in ["sparking", "hanging"] and not _shed:
		_shed_glass(direction)


func _shed_glass(direction: Vector3) -> void:
	_shed = true
	var shard := RigidBody3D.new()
	shard.name = "%s_Glass" % subject_id
	shard.mass = 0.4
	shard.collision_layer = 1 << 3
	shard.collision_mask = 1
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.14, 0.04, 0.1)
	mesh.material = _material(Color("bcd0c9"))
	visual.mesh = mesh
	shard.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	shard.add_child(collision)
	if get_parent() != null:
		get_parent().add_child(shard)
	else:
		add_child(shard)
	shard.global_position = _glass.global_position
	var spray := (direction.normalized() + Vector3(randf_range(-0.4, 0.4), 0.6, randf_range(-0.4, 0.4))).normalized()
	shard.apply_central_impulse(spray * 1.6)
	shard.apply_torque_impulse(Vector3(randf_range(-1.2, 1.2), randf_range(-1.2, 1.2), randf_range(-1.2, 1.2)))
	WORLD_DEBRIS.register(shard, {"kind": "streetlight", "part": "glass", "subject_id": subject_id}, DEBRIS_POOL, debris_budget())


func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.82
	return material
