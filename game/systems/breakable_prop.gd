class_name BreakableProp
extends StaticBody3D

## A piece of the world that can take a hit without turning every wall into a
## permanent physics simulation. It owns one solid collider while intact, then
## a deliberately small number of rigid fragments after it breaks — real,
## identified debris (`world_debris.gd`) that persists rather than despawning
## on a clock, capped globally because ten individual props each promising
## "only six" is still sixty active bodies during a derby.

const WORLD_LOOK := preload("res://systems/world_look.gd")
const WORLD_DEBRIS := preload("res://systems/world_debris.gd")

## AB1.3. Fragments used to force-despawn on this timer regardless of how far
## under budget the pool was — the exact "not persistent" gap AB1.1 named.
## `WORLD_DEBRIS` now owns that call: a fragment stays until the pool it is
## in actually needs the room.
const FRAGMENT_POOL := "barricade_fragment"

const MIN_DAMAGE_SPEED := 4.0
const DAMAGE_PER_METRE := 2.8
const MAX_FRAGMENTS_ULTRA := 48
const MAX_FRAGMENTS_HIGH := 28
const MAX_FRAGMENTS_PERFORMANCE := 14

var kind := "scrap_barricade"
var dimensions := Vector3(2.4, 1.35, 0.42)
var integrity := 28.0
var max_integrity := 28.0
var broken := false
var _solid: Node3D
var _collision: CollisionShape3D
var _fragments: Array[RigidBody3D] = []


static func fragment_budget() -> int:
	match WORLD_LOOK.quality:
		WORLD_LOOK.Quality.ULTRA:
			return MAX_FRAGMENTS_ULTRA
		WORLD_LOOK.Quality.PERFORMANCE:
			return MAX_FRAGMENTS_PERFORMANCE
		_:
			return MAX_FRAGMENTS_HIGH


func build(prop_kind := "scrap_barricade", size := Vector3(2.4, 1.35, 0.42), hit_points := 28.0) -> void:
	kind = prop_kind
	dimensions = size.max(Vector3(0.15, 0.15, 0.15))
	max_integrity = maxf(1.0, hit_points)
	integrity = max_integrity
	broken = false
	_build_solid()


func impact(closing_speed: float, direction := Vector3.FORWARD, contribution := 1.0) -> Dictionary:
	if broken:
		return {"accepted": false, "broken": true, "damage": 0.0, "integrity": integrity}
	var speed := maxf(0.0, closing_speed)
	var share := clampf(contribution, 0.2, 1.0)
	var damage := maxf(0.0, speed - MIN_DAMAGE_SPEED) * DAMAGE_PER_METRE * share
	if damage <= 0.0:
		return {"accepted": false, "broken": false, "damage": 0.0, "integrity": integrity}
	integrity = maxf(0.0, integrity - damage)
	if integrity > 0.0:
		_dent(direction, damage / max_integrity)
		return {"accepted": true, "broken": false, "damage": damage, "integrity": integrity}
	_fracture(direction, speed)
	return {"accepted": true, "broken": true, "damage": damage, "integrity": integrity, "fragments": _fragments.size()}


## A blow or a round rather than a car: the damage is already known, so it
## goes straight onto integrity (`WorldBreak` scales it per weapon).
func strike(damage: float, direction := Vector3.FORWARD) -> Dictionary:
	if broken:
		return {"accepted": false, "broken": true, "damage": 0.0, "integrity": integrity}
	if damage <= 0.0:
		return {"accepted": false, "broken": false, "damage": 0.0, "integrity": integrity}
	integrity = maxf(0.0, integrity - damage)
	if integrity > 0.0:
		_dent(direction, damage / max_integrity)
		return {"accepted": true, "broken": false, "damage": damage, "integrity": integrity}
	# A blow scatters the pieces a step or two, not across the yard.
	_fracture(direction, MIN_DAMAGE_SPEED + damage * 0.2)
	return {"accepted": true, "broken": true, "damage": damage, "integrity": integrity, "fragments": _fragments.size()}


func fragment_count() -> int:
	var live := 0
	for fragment in _fragments:
		if is_instance_valid(fragment) and not fragment.is_queued_for_deletion():
			live += 1
	return live


func _build_solid() -> void:
	if _solid != null:
		_solid.queue_free()
	_solid = Node3D.new()
	_solid.name = "Intact"
	add_child(_solid)
	var colour := Color("4b3625") if kind == "timber_barricade" else Color("39352d")
	_add_box(_solid, Vector3.ZERO, dimensions, colour)
	# A few uneven plates give the obstruction a readable salvage silhouette;
	# they are visual only, so collision remains one inexpensive box.
	for index in 3:
		var plate := Vector3(dimensions.x * 0.74, dimensions.y * 0.12, dimensions.z * 1.14)
		_add_box(_solid, Vector3(0.0, lerpf(-dimensions.y * 0.28, dimensions.y * 0.28, float(index) / 2.0), dimensions.z * 0.56), plate, colour.lightened(0.08 * float(index)))
	_collision = CollisionShape3D.new()
	_collision.name = "SolidCollision"
	var shape := BoxShape3D.new()
	shape.size = dimensions
	_collision.shape = shape
	add_child(_collision)


func _dent(direction: Vector3, fraction: float) -> void:
	if _solid == null:
		return
	var push := direction.normalized() if direction.length_squared() > 0.001 else Vector3.FORWARD
	_solid.position += push * minf(0.035, fraction * 0.09)
	_solid.rotation.y += clampf(push.x, -1.0, 1.0) * minf(0.035, fraction * 0.06)


func _fracture(direction: Vector3, speed: float) -> void:
	broken = true
	if _solid != null:
		_solid.visible = false
	if _collision != null:
		_collision.set_deferred("disabled", true)
	collision_layer = 0
	collision_mask = 0
	var available := maxi(0, fragment_budget() - WORLD_DEBRIS.pool_count(FRAGMENT_POOL))
	var wanted := mini(6, available)
	for index in wanted:
		_spawn_fragment(index, direction, speed)


func _spawn_fragment(index: int, direction: Vector3, speed: float) -> void:
	var fragment := RigidBody3D.new()
	fragment.name = "%s_Fragment_%02d" % [kind, index]
	fragment.mass = 1.2 + float(index) * 0.18
	# Fragments collide with the arena floor but not cars. They look physical
	# without adding a new moving-obstacle cost to every vehicle contact scan.
	fragment.collision_layer = 1 << 3
	fragment.collision_mask = 1
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(dimensions.x * 0.20, dimensions.y * 0.15, dimensions.z * 0.38).max(Vector3(0.09, 0.07, 0.08))
	mesh.material = _material(Color("4d3626") if index % 2 == 0 else Color("2d3932"))
	visual.mesh = mesh
	fragment.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	fragment.add_child(collision)
	add_child(fragment)
	fragment.global_position = global_position + Vector3(randf_range(-dimensions.x * 0.35, dimensions.x * 0.35), dimensions.y * 0.35 + randf() * 0.28, randf_range(-dimensions.z * 0.35, dimensions.z * 0.35))
	var spray := (direction.normalized() + Vector3(randf_range(-0.48, 0.48), randf_range(0.32, 0.88), randf_range(-0.48, 0.48))).normalized()
	fragment.apply_central_impulse(spray * (2.4 + speed * 0.28))
	fragment.apply_torque_impulse(Vector3(randf_range(-1.6, 1.6), randf_range(-1.6, 1.6), randf_range(-1.6, 1.6)))
	_fragments.append(fragment)
	WORLD_DEBRIS.register(fragment, {"kind": kind, "part": "fragment"}, FRAGMENT_POOL, fragment_budget())


func _add_box(parent: Node3D, at: Vector3, size: Vector3, colour: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(colour)
	mesh_instance.mesh = mesh
	mesh_instance.position = at
	parent.add_child(mesh_instance)


func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.metallic = 0.55 if kind == "scrap_barricade" else 0.12
	material.roughness = 0.84
	return material
