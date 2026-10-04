class_name FluidBody
extends Node3D

## A body of spilled fluid on a floor: the pour through the air, the pool it
## becomes, the ripples, splashes and prints when someone wades it, things
## drifting on it, and the current it carries when it is shocked.
##
## Greg (5 Oct): "it shouldn't instantly dissipate and it should be an actual
## fluid"; the spill "pours out over a few seconds, spreads, pools; the pool
## PERSISTS (stays until drained, slowly toward a floor grate)"; "a thick
## flowing pour (SPH-style particles that collide, gloopy, not loose beads)";
## "wading leaves ripples, splashes and wet footprints, things float"; "the
## liquid conducts electricity: the shock staff on a wet floor shocks whoever
## stands in it".
##
## Two halves, both on the CPU so they run (and test) headless:
## - The pour: up to MAX_BLOBS blobs with SPH-lite neighbour forces (XSPH
##   viscosity, short-range pressure, cohesion) that ray-collide with the
##   world, drawn as one MultiMesh of overlapping stretched spheres.
## - The pool: a depth grid (shallow-water pipe diffusion) over the floor.
##   Fluid above a retained `film` flows downhill; the ground is tilted a
##   hair toward the grate, which drains it. The film never flows, so what
##   does not reach the grate stays, the way blood pools do. A second grid
##   carries ripples. Both upload as one small texture to fluid_sheet.gdshader.
## The connected wet area for a shock is a flood fill over that same grid.
##
## Researched and not used: the GPU SPH addons (Godot Asset Library 5116,
## mdufaud/godot-simulations, thompsop1sou/godot-fluid-sim) run tens of
## thousands of particles in compute shaders. Compute does not run headless
## (no RenderingDevice), so none of it could be tested by the suite, and one
## tank's spill does not need 65k particles. See CREDITS.md.
##
## Reused: BloodPool takes a share of every landing as the stain left under
## the sheet (dial `stain`), which is also what Footprints reads to print.

signal shocked(target: Node, damage: float)

## Dials.
@export var viscosity := 0.7
## Cubic metres a second the grate swallows when fluid reaches it.
@export var drain_rate := 0.0012
## Depth (m) the floor keeps after the flow stops: the stain that stays.
@export var film := 0.003
@export var shock_damage := 14.0
@export var shock_impulse := 5.0
@export var shock_seconds := 0.6
## Feed BloodPool (stain + footprints) with this share of what lands.
@export var stain := 1.0
@export var colour := Color(0.42, 0.04, 0.03)

const MAX_BLOBS := 260
const BLOB_RADIUS := 0.055
const NEIGHBOUR := 0.13
const GRID_HZ := 30.0
## Below this depth a cell is dry for wading and current.
const WET_MIN := 0.0012

var grid := 64
var cell := 0.12
var grate := Vector2(2.6, 0.0)
var root: Node

var depth := PackedFloat32Array()
var ground := PackedFloat32Array()
var ripple := PackedFloat32Array()
var ripple_prev := PackedFloat32Array()
var drained := 0.0
var landed := 0.0
var splashes := 0
var shocks := 0
var shock_left := 0.0
var shock_cells: Dictionary = {}

var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _vol := PackedFloat32Array()
var _age := PackedFloat32Array()
var _blobs: MultiMeshInstance3D
var _sheet: MeshInstance3D
var _sheet_material: ShaderMaterial
var _field: Image
var _field_tex: ImageTexture
var _splash: GPUParticles3D
var _arcs: MeshInstance3D
var _flash: OmniLight3D
var _grid_clock := 0.0
var _dirty := false
var _floaters: Array[RigidBody3D] = []
var _stride: Dictionary = {}
var _victims: Array[Node3D] = []


## `half_extent` metres each way from this node (which sits on the floor),
## `grate_at` the drain in this node's local XZ.
func setup(owner_root: Node, half_extent := 3.84, grate_at := Vector2(2.6, 0.0), cell_size := 0.12) -> void:
	root = owner_root
	cell = cell_size
	grid = int(ceil(half_extent * 2.0 / cell))
	grate = grate_at
	var count := grid * grid
	depth.resize(count)
	ground.resize(count)
	ripple.resize(count)
	ripple_prev.resize(count)
	depth.fill(0.0)
	ripple.fill(0.0)
	ripple_prev.fill(0.0)
	# The floor creeps a hair down toward the grate (2 mm a metre), enough
	# for standing fluid to find it over a minute and no more.
	for z in grid:
		for x in grid:
			ground[x + z * grid] = _cell_centre(x, z).distance_to(grate) * 0.002
	_build_sheet()
	_build_blobs()
	_build_grate()
	_build_fx()


# --- the pour ----------------------------------------------------------------

## A blob of `volume` m³ leaving `from` (global) at `velocity`. False when the
## pour is at its cap; the caller keeps the volume and tries next frame.
func emit(from: Vector3, velocity: Vector3, volume: float) -> bool:
	if _pos.size() >= MAX_BLOBS:
		return false
	_pos.append(to_local(from))
	_vel.append(global_basis.inverse() * velocity)
	_vol.append(volume)
	_age.append(0.0)
	return true


func blob_count() -> int:
	return _pos.size()


func _step_blobs(delta: float) -> void:
	var count := _pos.size()
	if count == 0:
		_blobs.multimesh.visible_instance_count = 0
		return
	# Spatial hash, then SPH-lite: neighbours share velocity (viscosity, the
	# gloop), push apart when crowded and pull together when near (cohesion,
	# the rope). Cheap at a few hundred blobs and enough to stop beads.
	var buckets: Dictionary = {}
	for index in count:
		var key := Vector3i((_pos[index] / NEIGHBOUR).floor())
		if not buckets.has(key):
			buckets[key] = PackedInt32Array()
		(buckets[key] as PackedInt32Array).append(index)
	var nudge := PackedVector3Array()
	nudge.resize(count)
	for index in count:
		var here := _pos[index]
		var key := Vector3i((here / NEIGHBOUR).floor())
		var mean := Vector3.ZERO
		var push := Vector3.ZERO
		var found := 0
		for dz in range(-1, 2):
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var near: Variant = buckets.get(key + Vector3i(dx, dy, dz))
					if near == null:
						continue
					for other: int in near:
						if other == index:
							continue
						var gap := here - _pos[other]
						var distance := gap.length()
						if distance >= NEIGHBOUR or distance < 0.0001:
							continue
						var weight := 1.0 - distance / NEIGHBOUR
						mean += (_vel[other] - _vel[index]) * weight
						var rest := BLOB_RADIUS * 1.1
						push += gap / distance * ((rest - distance) * 40.0 if distance < rest else (rest - distance) * 6.0) * weight
						found += 1
		if found > 0:
			nudge[index] = mean / float(found) * clampf(viscosity * 12.0 * delta, 0.0, 0.9) + push * delta
	var space := get_world_3d().direct_space_state
	var keep := PackedInt32Array()
	for index in count:
		var velocity := _vel[index] + nudge[index] + Vector3(0, -9.8, 0) * delta
		var from := _pos[index]
		var to := from + velocity * delta
		_age[index] += delta
		var query := PhysicsRayQueryParameters3D.create(to_global(from), to_global(to + velocity.normalized() * BLOB_RADIUS * 0.5), 1)
		var hit := space.intersect_ray(query)
		if to.y <= BLOB_RADIUS * 0.4 or (not hit.is_empty() and (hit.normal as Vector3).y > 0.7 and to_local(hit.position).y < 0.08):
			_land(Vector3(to.x, 0.0, to.z), _vol[index], velocity)
			continue
		if not hit.is_empty():
			var normal: Vector3 = global_basis.inverse() * (hit.normal as Vector3)
			to = to_local(hit.position) + normal * BLOB_RADIUS * 0.5
			# Thick fluid does not bounce: it loses the push into the surface
			# and runs along it (off a ledge, down a wall).
			velocity = (velocity - normal * minf(velocity.dot(normal), 0.0)) * (0.92 if normal.y > 0.7 else 0.6)
		if _age[index] > 4.0:
			_land(Vector3(to.x, 0.0, to.z), _vol[index], Vector3.ZERO)
			continue
		_pos[index] = to
		_vel[index] = velocity
		keep.append(index)
	if keep.size() != count:
		var pos := PackedVector3Array()
		var vel := PackedVector3Array()
		var vol := PackedFloat32Array()
		var age := PackedFloat32Array()
		for index in keep:
			pos.append(_pos[index])
			vel.append(_vel[index])
			vol.append(_vol[index])
			age.append(_age[index])
		_pos = pos
		_vel = vel
		_vol = vol
		_age = age
	_draw_blobs()


func _draw_blobs() -> void:
	var multimesh := _blobs.multimesh
	multimesh.visible_instance_count = _pos.size()
	for index in _pos.size():
		var velocity := _vel[index]
		var speed := velocity.length()
		var basis := Basis()
		if speed > 0.3:
			var along := velocity / speed
			var side := along.cross(Vector3.UP if absf(along.y) < 0.95 else Vector3.RIGHT).normalized()
			basis = Basis(side, along, side.cross(along)).orthonormalized()
			basis = basis * Basis.from_scale(Vector3(1.0, 1.0 + minf(speed * 0.35, 1.6), 1.0))
		multimesh.set_instance_transform(index, Transform3D(basis, _pos[index]))


func _land(at: Vector3, volume: float, velocity: Vector3) -> void:
	deposit(at, volume)
	var speed := velocity.length()
	if speed > 1.5:
		disturb(at, minf(speed * 0.0015, 0.006))


# --- the pool ----------------------------------------------------------------

## Pour `volume` m³ onto the floor at `at` (this node's local space).
func deposit(at: Vector3, volume: float) -> void:
	var index := _index_at(at)
	if index < 0 or volume <= 0.0:
		return
	depth[index] += volume / (cell * cell)
	landed += volume
	_dirty = true
	if stain > 0.0 and root != null:
		BloodPool.keep(root, to_global(at) * Vector3(1, 0, 1), volume * stain * 80000.0)


## A ripple at `at` (local), `height` metres.
func disturb(at: Vector3, height: float) -> void:
	var index := _index_at(at)
	if index >= 0:
		ripple[index] += height
		_dirty = true


func depth_at(global_point: Vector3) -> float:
	var index := _index_at(to_local(global_point))
	return depth[index] if index >= 0 else 0.0


func wet_at(global_point: Vector3) -> bool:
	return depth_at(global_point) > WET_MIN


func volume() -> float:
	var total := 0.0
	for value in depth:
		total += value
	return total * cell * cell


func wet_cells() -> int:
	var count := 0
	for value in depth:
		if value > WET_MIN:
			count += 1
	return count


func clear() -> void:
	depth.fill(0.0)
	ripple.fill(0.0)
	ripple_prev.fill(0.0)
	landed = 0.0
	drained = 0.0
	_pos.clear()
	_vel.clear()
	_vol.clear()
	_age.clear()
	_dirty = true
	_upload()


func _step_grid(delta: float) -> void:
	if landed <= 0.0:
		return
	var rate := clampf(0.22 * (1.0 - viscosity * 0.85), 0.01, 0.24)
	var flow := PackedFloat32Array()
	flow.resize(depth.size())
	var moving := false
	for z in grid:
		for x in grid:
			var index := x + z * grid
			var spare := depth[index] - film
			if spare <= 0.0:
				continue
			var level := ground[index] + depth[index]
			var out := [0.0, 0.0, 0.0, 0.0]
			var total := 0.0
			var neighbours := [index - 1 if x > 0 else -1, index + 1 if x < grid - 1 else -1, index - grid if z > 0 else -1, index + grid if z < grid - 1 else -1]
			for side in 4:
				var other: int = neighbours[side]
				if other < 0:
					continue
				var drop := level - (ground[other] + depth[other])
				if drop > 0.0:
					out[side] = drop * rate
					total += drop * rate
			if total <= 0.0:
				continue
			var scale := minf(1.0, spare / total)
			for side in 4:
				var other: int = neighbours[side]
				if other >= 0 and out[side] > 0.0:
					flow[other] += out[side] * scale
					flow[index] -= out[side] * scale
					moving = true
	if moving:
		for index in depth.size():
			depth[index] += flow[index]
	# The grate swallows what reaches it, film and all.
	var mouth := _index_at(Vector3(grate.x, 0, grate.y))
	if mouth >= 0:
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var index := mouth + dx + dz * grid
				var take := minf(depth[index], drain_rate * delta / 9.0 / (cell * cell))
				depth[index] -= take
				drained += take * cell * cell
	# Ripples: the two-buffer wave, damped, only where there is fluid.
	var damping := 0.94 - viscosity * 0.06
	var settled := true
	for z in range(1, grid - 1):
		for x in range(1, grid - 1):
			var index := x + z * grid
			var next := 0.0
			if depth[index] > WET_MIN:
				next = ((ripple[index - 1] + ripple[index + 1] + ripple[index - grid] + ripple[index + grid]) * 0.5 - ripple_prev[index]) * damping
			ripple_prev[index] = next
			if absf(next) > 0.00002:
				settled = false
	var swap := ripple
	ripple = ripple_prev
	ripple_prev = swap
	if moving or not settled or _dirty:
		_upload()


func _upload() -> void:
	_dirty = false
	var pairs := PackedFloat32Array()
	pairs.resize(depth.size() * 2)
	for index in depth.size():
		pairs[index * 2] = depth[index]
		pairs[index * 2 + 1] = ripple[index]
	_field.set_data(grid, grid, false, Image.FORMAT_RGF, pairs.to_byte_array())
	_field_tex.update(_field)


# --- wading ------------------------------------------------------------------

## Called each physics frame by whoever walks: feet (global), their velocity,
## and who they are (prints and stride are per walker).
func wade(walker: Object, feet: Vector3, velocity: Vector3, delta: float) -> bool:
	var speed := Vector2(velocity.x, velocity.z).length()
	if not wet_at(feet):
		_stride.erase(walker.get_instance_id() if walker else 0)
		return false
	var id := walker.get_instance_id() if walker else 0
	var stride: Dictionary = _stride.get(id, {"clock": 0.0, "left": true})
	var local := to_local(feet)
	if speed > 0.4:
		disturb(local, 0.0012 * minf(speed, 6.0) * delta * 30.0)
	stride.clock -= delta * maxf(speed, 0.0)
	if speed > 0.6 and stride.clock <= 0.0:
		stride.clock = 0.75
		stride.left = not stride.left
		splash(feet, clampf(speed / 6.0, 0.2, 1.0))
		Footprints.step(root, walker, feet * Vector3(1, 0, 1) + Vector3(0, 0, 0), "left" if stride.left else "right")
	_stride[id] = stride
	return true


## Spray at `at` (global). Counted; the station asks for it on shots too.
func splash(at: Vector3, strength := 1.0) -> bool:
	if not wet_at(at):
		return false
	_splash.global_position = Vector3(at.x, global_position.y + 0.05, at.z)
	_splash.amount_ratio = clampf(strength, 0.2, 1.0)
	_splash.restart()
	disturb(to_local(at), 0.004 * strength)
	splashes += 1
	return true


## A RigidBody3D that drifts on the pool: carried downhill by the flow,
## bobbing, damped while wet.
func add_floater(body: RigidBody3D) -> void:
	_floaters.append(body)


func _step_floaters(delta: float) -> void:
	for body in _floaters:
		if not is_instance_valid(body):
			continue
		var local := to_local(body.global_position)
		var index := _index_at(local)
		if index < 0 or depth[index] <= WET_MIN or local.y > 0.25:
			continue
		var x := index % grid
		var z := index / grid
		var slope := Vector3.ZERO
		if x > 0 and x < grid - 1 and z > 0 and z < grid - 1:
			var level := func(i: int) -> float: return ground[i] + depth[i]
			slope = Vector3(level.call(index - 1) - level.call(index + 1), 0.0, level.call(index - grid) - level.call(index + grid)) / (2.0 * cell)
		var bob := sin(Time.get_ticks_msec() * 0.004 + float(body.get_instance_id() % 97)) * 0.4
		body.apply_central_force(global_basis * (slope * 60.0 * body.mass) + Vector3(0, (9.8 * 0.95 + bob) * body.mass * clampf(depth[index] / 0.01, 0.0, 1.0), 0))
		body.linear_velocity *= 1.0 - minf(delta * 2.0, 0.5)
		if body.linear_velocity.length() > 0.2:
			disturb(local, 0.0008)


# --- current -----------------------------------------------------------------

## Electrify the wet area connected to `at` (global). Everyone standing in
## it takes `shock_damage`, a stagger and visible arcs; anyone on dry floor
## does not. `extra` are walkers the caller knows of (the player); bodies are
## found by walking `root`. Returns who was hit.
func shock(at: Vector3, extra: Array = []) -> Array[Node3D]:
	shock_cells = connected_wet(at)
	_victims.clear()
	if shock_cells.is_empty():
		return _victims
	shocks += 1
	shock_left = shock_seconds
	for target in _standing(extra):
		_victims.append(target)
		if target is BaselineHuman:
			var rig := target as BaselineHuman
			for zone in ["left_leg", "right_leg", "torso"]:
				rig.hit(zone, shock_damage / 3.0, shock_impulse, "blunt", "", Vector3(randf_range(-1, 1), 0.3, randf_range(-1, 1)).normalized())
		shocked.emit(target, shock_damage)
	_flash.global_position = to_global(_cell_centre_v3(_index_at(to_local(at)))) + Vector3(0, 0.4, 0)
	_flash.light_energy = 6.0
	return _victims


## The cells wet and touching `at`'s (4-connected), as a set of indices.
## A dry `at` snaps to the nearest wet cell within half a metre.
func connected_wet(at: Vector3) -> Dictionary:
	var start := _index_at(to_local(at))
	if start < 0:
		return {}
	if depth[start] <= WET_MIN:
		start = _nearest_wet(start, int(ceil(0.5 / cell)))
		if start < 0:
			return {}
	var seen := {start: true}
	var open := [start]
	while not open.is_empty():
		var index: int = open.pop_back()
		var x := index % grid
		for other in [index - 1 if x > 0 else -1, index + 1 if x < grid - 1 else -1, index - grid, index + grid]:
			if other >= 0 and other < depth.size() and not seen.has(other) and depth[other] > WET_MIN:
				seen[other] = true
				open.append(other)
	return seen


func _standing(extra: Array) -> Array[Node3D]:
	var found: Array[Node3D] = []
	var walk := [root if root != null else self]
	while not walk.is_empty():
		var node: Node = walk.pop_back()
		if node is BaselineHuman:
			found.append(node)
			continue
		walk.append_array(node.get_children())
	for node in extra:
		if node is Node3D and not found.has(node):
			found.append(node)
	var out: Array[Node3D] = []
	for node in found:
		if node is BaselineHuman and ((node as BaselineHuman).anatomy == null or (node as BaselineHuman).anatomy.dead):
			continue
		var feet := node.global_position
		if feet.y - global_position.y > 0.6:
			continue
		var index := _index_at(to_local(feet))
		if index >= 0 and shock_cells.has(index):
			out.append(node)
	return out


func _nearest_wet(start: int, reach: int) -> int:
	var sx := start % grid
	var sz := start / grid
	var best := -1
	var best_d := INF
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var x := sx + dx
			var z := sz + dz
			if x < 0 or z < 0 or x >= grid or z >= grid:
				continue
			var index := x + z * grid
			if depth[index] > WET_MIN and dx * dx + dz * dz < best_d:
				best_d = dx * dx + dz * dz
				best = index
	return best


func _draw_arcs() -> void:
	var lines := _arcs.mesh as ImmediateMesh
	lines.clear_surfaces()
	if shock_left <= 0.0 or shock_cells.is_empty():
		_arcs.visible = false
		return
	_arcs.visible = true
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	var cells := shock_cells.keys()
	# Crawling arcs over the wet floor, re-rolled every frame (it flickers).
	for chain in mini(14, cells.size()):
		var point := _cell_centre_v3(cells[randi() % cells.size()]) + Vector3(0, 0.03, 0)
		for link in 5:
			var next := point + Vector3(randf_range(-0.25, 0.25), randf_range(0.0, 0.05), randf_range(-0.25, 0.25))
			next.y = clampf(next.y, 0.02, 0.1)
			lines.surface_add_vertex(point)
			lines.surface_add_vertex(next)
			point = next
	# And up each victim from the feet.
	for target in _victims:
		if not is_instance_valid(target):
			continue
		var point := to_local(target.global_position) * Vector3(1, 0, 1) + Vector3(0, 0.03, 0)
		for link in 7:
			var next := point + Vector3(randf_range(-0.12, 0.12), 0.22, randf_range(-0.12, 0.12))
			lines.surface_add_vertex(point)
			lines.surface_add_vertex(next)
			point = next
	lines.surface_end()


# --- frame -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_step_blobs(delta)
	_step_floaters(delta)
	_grid_clock += delta
	if _grid_clock >= 1.0 / GRID_HZ:
		_step_grid(_grid_clock)
		_grid_clock = 0.0


func _process(delta: float) -> void:
	if shock_left > 0.0:
		shock_left -= delta
	_sheet_material.set_shader_parameter("shock", clampf(shock_left / maxf(shock_seconds, 0.01), 0.0, 1.0))
	_flash.light_energy = move_toward(_flash.light_energy, 0.0, delta * 14.0)
	_draw_arcs()


## Advance the whole body `seconds` at `step` without rendering: for tests
## and for pre-settling a level that starts already spilled.
func simulate(seconds: float, step := 1.0 / 60.0) -> void:
	var left := seconds
	while left > 0.0:
		_physics_process(step)
		left -= step


# --- build -------------------------------------------------------------------

func _build_sheet() -> void:
	_field = Image.create(grid, grid, false, Image.FORMAT_RGF)
	_field_tex = ImageTexture.create_from_image(_field)
	_sheet_material = ShaderMaterial.new()
	_sheet_material.shader = preload("res://shaders/fluid_sheet.gdshader")
	_sheet_material.set_shader_parameter("field", _field_tex)
	_sheet_material.set_shader_parameter("cell", cell)
	_sheet_material.set_shader_parameter("texel", 1.0 / float(grid))
	_sheet_material.set_shader_parameter("film", film)
	_sheet_material.set_shader_parameter("shallow", Color(colour.r * 1.3, colour.g * 1.2, colour.b * 1.2, 0.78))
	var plane := PlaneMesh.new()
	plane.size = Vector2(grid * cell, grid * cell)
	plane.subdivide_width = grid - 1
	plane.subdivide_depth = grid - 1
	plane.material = _sheet_material
	_sheet = MeshInstance3D.new()
	_sheet.name = "Sheet"
	_sheet.mesh = plane
	_sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sheet.extra_cull_margin = 0.5
	add_child(_sheet)


func _build_blobs() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = BLOB_RADIUS
	sphere.height = BLOB_RADIUS * 2.0
	sphere.radial_segments = 10
	sphere.rings = 6
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/fluid_blob.gdshader")
	material.set_shader_parameter("colour", colour.darkened(0.15))
	sphere.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = sphere
	multimesh.instance_count = MAX_BLOBS
	multimesh.visible_instance_count = 0
	_blobs = MultiMeshInstance3D.new()
	_blobs.name = "Pour"
	_blobs.multimesh = multimesh
	_blobs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blobs.custom_aabb = AABB(Vector3(-grid * cell * 0.5, -0.5, -grid * cell * 0.5), Vector3(grid * cell, 4.0, grid * cell))
	add_child(_blobs)


func _build_grate() -> void:
	var grate_node := MeshInstance3D.new()
	grate_node.name = "Grate"
	var slab := BoxMesh.new()
	slab.size = Vector3(0.42, 0.012, 0.42)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("16120f")
	iron.metallic = 0.7
	iron.roughness = 0.5
	slab.material = iron
	grate_node.mesh = slab
	grate_node.position = Vector3(grate.x, 0.006, grate.y)
	add_child(grate_node)
	for bar in 5:
		var slot := MeshInstance3D.new()
		var gap := BoxMesh.new()
		gap.size = Vector3(0.05, 0.004, 0.34)
		var black := StandardMaterial3D.new()
		black.albedo_color = Color.BLACK
		black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gap.material = black
		slot.mesh = gap
		slot.position = Vector3(-0.16 + bar * 0.08, 0.007, 0)
		grate_node.add_child(slot)


func _build_fx() -> void:
	_splash = GPUParticles3D.new()
	_splash.name = "Splash"
	_splash.amount = 48
	_splash.lifetime = 0.7
	_splash.one_shot = true
	_splash.explosiveness = 1.0
	_splash.emitting = false
	var spray := ParticleProcessMaterial.new()
	spray.direction = Vector3.UP
	spray.spread = 50.0
	spray.initial_velocity_min = 1.2
	spray.initial_velocity_max = 2.8
	spray.gravity = Vector3(0, -9.8, 0)
	spray.scale_min = 0.5
	spray.scale_max = 1.3
	spray.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	_splash.process_material = spray
	var drop := SphereMesh.new()
	drop.radius = 0.018
	drop.height = 0.036
	drop.radial_segments = 6
	drop.rings = 3
	var wet := StandardMaterial3D.new()
	wet.albedo_color = colour
	wet.roughness = 0.08
	wet.metallic_specular = 0.8
	drop.material = wet
	_splash.draw_pass_1 = drop
	add_child(_splash)
	_arcs = MeshInstance3D.new()
	_arcs.name = "Arcs"
	_arcs.mesh = ImmediateMesh.new()
	var arc := StandardMaterial3D.new()
	arc.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arc.albedo_color = Color(0.75, 0.88, 1.0)
	arc.emission_enabled = true
	arc.emission = Color(0.6, 0.8, 1.0)
	arc.emission_energy_multiplier = 4.0
	arc.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_arcs.material_override = arc
	_arcs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arcs.visible = false
	add_child(_arcs)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(0.6, 0.8, 1.0)
	_flash.omni_range = 5.0
	_flash.light_energy = 0.0
	add_child(_flash)


func _index_at(local: Vector3) -> int:
	var half := grid * cell * 0.5
	var x := int(floor((local.x + half) / cell))
	var z := int(floor((local.z + half) / cell))
	if x < 0 or z < 0 or x >= grid or z >= grid:
		return -1
	return x + z * grid


func _cell_centre(x: int, z: int) -> Vector2:
	var half := grid * cell * 0.5
	return Vector2(-half + (x + 0.5) * cell, -half + (z + 0.5) * cell)


func _cell_centre_v3(index: int) -> Vector3:
	var centre := _cell_centre(index % grid, index / grid)
	return Vector3(centre.x, 0.0, centre.y)
