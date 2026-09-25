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
## One pool for every kind, so a room full of crates shares the cap with the
## derby's barricades instead of each kind promising its own "only six".
const FRAGMENT_POOL := "prop_fragment"

## 0.2 (`DESIGN/GOAL_LOOP_2.md`): what breaks outside the derby. Hit points
## are set against what reaches a prop through `WorldBreak`: a pistol round
## lands about 14, a breach-tool blow 33. So a crate, jar, monitor or chair
## goes in one round, a barrel in two, and a locker takes two blows. `shard`
## is what each one breaks into; `pieces` how many.
const KINDS := {
	"crate": {"size": Vector3(0.8, 0.8, 0.8), "hp": 12.0, "colour": "5a3f27", "surface": "dirt", "shard": "plank", "pieces": 6, "mass": 0.5},
	"barrel": {"size": Vector3(0.62, 0.92, 0.62), "hp": 24.0, "colour": "3a4636", "surface": "rust", "shard": "stave", "pieces": 6, "mass": 0.7},
	"locker": {"size": Vector3(0.62, 1.85, 0.5), "hp": 40.0, "colour": "46525a", "surface": "paint", "shard": "panel", "pieces": 4, "mass": 1.4},
	"jar": {"size": Vector3(0.3, 0.46, 0.3), "hp": 3.0, "colour": "a9c2ae", "surface": "glass", "shard": "glass", "pieces": 7, "mass": 0.08},
	"monitor": {"size": Vector3(0.52, 0.44, 0.46), "hp": 8.0, "colour": "2b2824", "surface": "paint", "shard": "screen", "pieces": 6, "mass": 0.35},
	"chair": {"size": Vector3(0.48, 0.92, 0.5), "hp": 9.0, "colour": "3b3731", "surface": "rust", "shard": "leg", "pieces": 6, "mass": 0.3},
}

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


## Stands a prop of `prop_kind` on the floor at `at`. Its name is its identity
## in the world's record, so every placed prop needs its own `id`.
static func place(parent: Node, prop_kind: String, id: String, at: Vector3, turn := 0.0) -> BreakableProp:
	var prop := BreakableProp.new()
	prop.name = id
	prop.build(prop_kind)
	# The collider is centred on the origin, so it stands on half its height.
	prop.position = at + Vector3(0, prop.dimensions.y * 0.5, 0)
	prop.rotation.y = turn
	parent.add_child(prop)
	return prop


## A zero size or hit points takes the kind's own from `KINDS`.
func build(prop_kind := "scrap_barricade", size := Vector3.ZERO, hit_points := 0.0) -> void:
	var spec: Dictionary = KINDS.get(prop_kind, {})
	if size == Vector3.ZERO:
		size = spec.get("size", Vector3(2.4, 1.35, 0.42))
	if hit_points <= 0.0:
		hit_points = float(spec.get("hp", 28.0))
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
	if KINDS.has(kind):
		_build_look()
		_build_collision()
		return
	var colour := Color("4b3625") if kind == "timber_barricade" else Color("39352d")
	_add_box(_solid, Vector3.ZERO, dimensions, colour)
	# A few uneven plates give the obstruction a readable salvage silhouette;
	# they are visual only, so collision remains one inexpensive box.
	for index in 3:
		var plate := Vector3(dimensions.x * 0.74, dimensions.y * 0.12, dimensions.z * 1.14)
		_add_box(_solid, Vector3(0.0, lerpf(-dimensions.y * 0.28, dimensions.y * 0.28, float(index) / 2.0), dimensions.z * 0.56), plate, colour.lightened(0.08 * float(index)))
	_build_collision()


func _build_collision() -> void:
	_collision = CollisionShape3D.new()
	_collision.name = "SolidCollision"
	var shape := BoxShape3D.new()
	shape.size = dimensions
	_collision.shape = shape
	add_child(_collision)


## Each kind's silhouette: a few primitives over the one box collider.
func _build_look() -> void:
	var d := dimensions
	var base := Color(str((KINDS[kind] as Dictionary).colour))
	var body := _surface(base)
	match kind:
		"crate":
			_part(_box(d), Vector3.ZERO, body)
			# Boards stand proud of both faces, so it reads as slatted wood.
			for side in [-1.0, 1.0]:
				for row in 3:
					_part(_box(Vector3(d.x * 0.96, d.y * 0.27, 0.03)), Vector3(0, (float(row) - 1.0) * d.y * 0.33, side * (d.z * 0.5 + 0.012)), _surface(base.lightened(0.07 * float(row + 1))))
		"barrel":
			_part(_cylinder(d.x * 0.5, d.y), Vector3.ZERO, body)
			for y in [-0.3, 0.3]:
				_part(_cylinder(d.x * 0.5 + 0.012, 0.05), Vector3(0, y * d.y, 0), _surface(base.darkened(0.45)))
		"locker":
			_part(_box(d), Vector3.ZERO, body)
			_part(_box(Vector3(d.x * 0.9, d.y * 0.94, 0.02)), Vector3(0, 0, d.z * 0.5 + 0.01), _surface(base.lightened(0.07)))
			for slit in 3:
				_part(_box(Vector3(d.x * 0.5, 0.022, 0.012)), Vector3(0, d.y * (0.36 - 0.04 * float(slit)), d.z * 0.5 + 0.024), _surface(Color("0d0c0b")))
			_part(_box(Vector3(0.03, 0.14, 0.03)), Vector3(d.x * 0.32, 0, d.z * 0.5 + 0.03), _surface(Color("8a8478"), "chrome"))
		"jar":
			# A specimen jar: filthy glass, murky fluid, something pale in it.
			_part(_cylinder(d.x * 0.5, d.y * 0.86), Vector3(0, -d.y * 0.07, 0), body)
			_part(_cylinder(d.x * 0.42, d.y * 0.6), Vector3(0, -d.y * 0.19, 0), _surface(Color("5c6a3e"), "glass"))
			_part(_sphere(d.x * 0.2), Vector3(0, -d.y * 0.17, 0), _surface(Color("b39684"), "flesh"))
			_part(_cylinder(d.x * 0.53, d.y * 0.1), Vector3(0, d.y * 0.42, 0), _surface(Color("2a2521"), "rust"))
		"monitor":
			_part(_box(d), Vector3.ZERO, body)
			_part(_box(Vector3(d.x * 0.78, d.y * 0.7, 0.02)), Vector3(0, d.y * 0.04, d.z * 0.5 + 0.006), _screen())
		"chair":
			_part(_box(Vector3(d.x, 0.06, d.z * 0.92)), Vector3(0, -d.y * 0.02, 0), body)
			_part(_box(Vector3(d.x, d.y * 0.44, 0.05)), Vector3(0, d.y * 0.27, -d.z * 0.44), body)
			for x in [-1.0, 1.0]:
				for z in [-1.0, 1.0]:
					_part(_box(Vector3(0.04, d.y * 0.48, 0.04)), Vector3(x * d.x * 0.42, -d.y * 0.26, z * d.z * 0.4), _surface(base.darkened(0.3)))


## What piece `index` of this kind is: planks off a crate, staves and a hoop
## off a barrel, a locker's door and sides, glass off a jar (and what was in
## it), glass and casing off a monitor, a chair's seat, back and legs.
func _shard(index: int) -> PrimitiveMesh:
	var d := dimensions
	var base := Color(str((KINDS[kind] as Dictionary).colour))
	var mesh: PrimitiveMesh
	match str((KINDS[kind] as Dictionary).shard):
		"plank":
			mesh = _box(Vector3(d.x * randf_range(0.45, 0.95), 0.035, d.y * 0.26))
			mesh.material = _surface(base.lightened(randf_range(0.0, 0.2)))
		"stave":
			if index == 0:
				var hoop := TorusMesh.new()
				hoop.inner_radius = d.x * 0.47
				hoop.outer_radius = d.x * 0.52
				hoop.material = _surface(base.darkened(0.45))
				return hoop
			mesh = _box(Vector3(d.x * 0.34, d.y * randf_range(0.5, 0.9), 0.03))
			mesh.material = _surface(base)
		"panel":
			mesh = _box(Vector3(d.x * 0.88, d.y * (0.9 if index == 0 else randf_range(0.3, 0.5)), 0.025))
			mesh.material = _surface(base.lightened(0.07 if index == 0 else 0.0))
		"glass":
			if index == 0:
				mesh = _sphere(d.x * 0.2)
				mesh.material = _surface(Color("b39684"), "flesh")
				return mesh
			mesh = _glass_shard(d.x)
			mesh.material = _surface(base)
		"screen":
			if index % 2 == 0:
				mesh = _glass_shard(d.x * 0.6)
				mesh.material = _screen()
			else:
				mesh = _box(Vector3(d.x * randf_range(0.3, 0.6), d.y * randf_range(0.2, 0.4), d.z * 0.3))
				mesh.material = _surface(base)
		"leg":
			if index == 0:
				mesh = _box(Vector3(d.x, 0.06, d.z * 0.92))
			elif index == 1:
				mesh = _box(Vector3(d.x, d.y * 0.44, 0.05))
			else:
				mesh = _box(Vector3(0.04, d.y * 0.48, 0.04))
			mesh.material = _surface(base if index < 2 else base.darkened(0.3))
	return mesh


func _part(mesh: PrimitiveMesh, at: Vector3, material: Material) -> void:
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	_solid.add_child(instance)


func _surface(colour: Color, look := "") -> StandardMaterial3D:
	var surface_kind := look if not look.is_empty() else str((KINDS[kind] as Dictionary).surface)
	# Seeded by name, so the same crate is the same crate every time it loads.
	return WORLD_LOOK.surface(colour, surface_kind, absi(hash(str(name))) % 97 + 1)


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	return mesh


static func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	return mesh


static func _glass_shard(scale: float) -> PrismMesh:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(scale * randf_range(0.18, 0.4), scale * randf_range(0.25, 0.55), 0.008)
	mesh.left_to_right = randf()
	return mesh


## A dead CRT: dark glass with a little green still in it.
static func _screen() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("0b1410")
	material.roughness = 0.12
	material.emission_enabled = true
	material.emission = Color("1f5a33")
	material.emission_energy_multiplier = 0.5
	return material


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
	# Every break sheds its own pieces. A full pool gives up its oldest ones
	# (`WORLD_DEBRIS.register`) rather than this one breaking into nothing,
	# which is what the shared pool did once a handful of props had gone.
	var pieces := int((KINDS.get(kind, {}) as Dictionary).get("pieces", 6))
	for index in mini(pieces, fragment_budget()):
		_spawn_fragment(index, direction, speed)


func _spawn_fragment(index: int, direction: Vector3, speed: float) -> void:
	var fragment := RigidBody3D.new()
	fragment.name = "%s_Fragment_%02d" % [kind, index]
	var spec: Dictionary = KINDS.get(kind, {})
	fragment.mass = float(spec.get("mass", 1.2 + float(index) * 0.18))
	# Fragments collide with the arena floor but not cars. They look physical
	# without adding a new moving-obstacle cost to every vehicle contact scan.
	fragment.collision_layer = 1 << 3
	fragment.collision_mask = 1
	var visual := MeshInstance3D.new()
	var mesh: PrimitiveMesh
	if spec.is_empty():
		mesh = _box(Vector3(dimensions.x * 0.20, dimensions.y * 0.15, dimensions.z * 0.38).max(Vector3(0.09, 0.07, 0.08)))
		mesh.material = _material(Color("4d3626") if index % 2 == 0 else Color("2d3932"))
	else:
		mesh = _shard(index)
	visual.mesh = mesh
	fragment.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.get_aabb().size.max(Vector3(0.02, 0.02, 0.02))
	collision.shape = shape
	fragment.add_child(collision)
	add_child(fragment)
	fragment.global_position = global_position + Vector3(randf_range(-dimensions.x * 0.35, dimensions.x * 0.35), dimensions.y * 0.35 + randf() * 0.28, randf_range(-dimensions.z * 0.35, dimensions.z * 0.35))
	var spray := (direction.normalized() + Vector3(randf_range(-0.48, 0.48), randf_range(0.32, 0.88), randf_range(-0.48, 0.48))).normalized()
	if spec.is_empty():
		# Barricades keep the derby's numbers, tuned for a car going through.
		fragment.apply_central_impulse(spray * (2.4 + speed * 0.28))
		fragment.apply_torque_impulse(Vector3(randf_range(-1.6, 1.6), randf_range(-1.6, 1.6), randf_range(-1.6, 1.6)))
	else:
		# A prop is mostly broken by hand, and a blow drops its pieces a step
		# or two rather than throwing them: the first render at the derby's
		# push sent a locker door 3.5 m. A velocity and a spin rather than
		# impulses, because a glass shard's inertia is so small the barricade's
		# torque would turn it at hundreds of radians a second.
		fragment.linear_velocity = spray * (0.8 + speed * 0.08)
		fragment.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
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
