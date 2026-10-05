class_name VehicleDamage
extends Node

## Lab-53. Crumple, shed parts and lose the engine: the damage half of Greg's
## 5 Oct 02:25 note, "VEHICLE MODELS that use our destruction mechanics, with a
## BeamNG-style driving system (soft-body feel: real crumple, parts that bend
## and come off, engine damage)".
##
## Not a node-beam soft body. BeamNG solves a mass-spring lattice at 2 kHz in
## native code; in GDScript two of those would eat the 144 fps budget alone,
## and no maintained Godot 4 port exists (see DESIGN/REMASTER_LOG.md, lab-53).
## Instead the existing raycast chassis (`arcade_vehicle.gd`: per-wheel
## springs, load-based grip, so weight transfer is already real) drives, and
## this answers each impact where it landed:
##
## - **Crumple**: the body mesh's own vertices near the contact are pushed in,
##   with falloff, capped per vertex, faces re-lit flat. Runs only on impact
##   (one ~1k-vertex pass), never per frame.
## - **Parts**: bumpers, doors, a bolted hood plate, the windscreen and the four
##   wheels each take hits; one comes off as a real `RigidBody3D` only when the
##   blow's source beats its `MaterialToughness` tier, the same table walls and
##   ground use. A ram's tier is its kinetic energy, so a car bends on a slow
##   knock and sheds steel on a fast one. A lost wheel is a lost spring.
## - **Engine**: front hits cost engine health, which `engine_power` turns
##   into a lower top speed and weaker pull; a holed radiator steams.
## - **Occupant**: a `BaselineHuman` in the seat takes the crash in the zone
##   nearest the contact, the derby's rule included: bumper and hood gone, a
##   fast front hit reaches the chest.
##
## Built for the mechanics lab's vehicle pad; nothing here knows about the lab.

const VEHICLE := preload("res://systems/arcade_vehicle.gd")
const MODELS := {
	"sedan": preload("res://art/vehicles/kenney_car_kit/sedan.glb"),
	"suv": preload("res://art/vehicles/kenney_car_kit/suv.glb"),
}
const DOOR := preload("res://art/vehicles/kenney_car_kit/debris-door.glb")
const BUMPER := preload("res://art/vehicles/kenney_car_kit/debris-bumper.glb")
const PLATE := preload("res://art/vehicles/kenney_car_kit/debris-plate-a.glb")
const BIOPUNK_MAP := preload("res://art/vehicles/kenney_car_kit/Textures/colormap_biopunk.png")
const SILHOUETTE := preload("res://systems/silhouette.gd")
## The Kenney kit's toy-scale cars, brought up to a 2.2 m wide car.
const SHELL_SCALE := 1.5
const WHEELS := {"wheel-front-left": 0, "wheel-front-right": 1, "wheel-back-left": 2, "wheel-back-right": 3}
## Shares the derby's pool name so loose doors from both count against one cap.
const PART_POOL := "vehicle_part"
const PART_BUDGET := 16
const SHARD_POOL := "vehicle_glass"
const SHARD_BUDGET := 24

## --- dials (Greg has not set these; defaults noted in REMASTER_LOG) -------
## Closing speed (m/s) below which a contact leaves no mark.
const DENT_THRESHOLD := 3.0
## Metres of crush per m/s past the threshold, and the most any one point of
## the body can travel from where it was built.
const DENT_PER_MS := 0.045
const MAX_CRUSH := 0.6
## Sideways crumple, as a share of how far a point was pushed in.
const WRINKLE := 0.35
## A part within this many metres of the dent's edge shares the blow.
const PART_REACH := 0.9
## Part hp lost per m/s past the threshold at the middle of the blow.
const PART_DAMAGE := 2.5
## Engine health lost per m/s past the threshold on a front-third hit, and
## the floor it settles on: a wreck limps, it does not stop.
const ENGINE_PER_MS := 0.04
const MIN_ENGINE := 0.25
const STEAM_BELOW := 0.75
## Damage handed to the occupant per m/s past the threshold.
const DRIVER_PER_MS := 2.2
const RAM_CRUSH_SPEED := 13.0
## Global crumple multiplier. 1 is the default feel.
static var crumple := 1.0

var car: RigidBody3D
var engine := 1.0
## name -> {node, material, hp, mass, wheel (index or -1)}
var parts: Dictionary = {}
var detached: Array[String] = []
var max_crush := 0.0
var hits := 0
## Slowest crumple pass so far (one impact), for the frame budget.
var dent_usec_max := 0
var driver: BaselineHuman
var _meshes: Array[Dictionary] = []
var _steam: CPUParticles3D
var _spin := 0.0
var _driver_seed := -1


## A drivable car: the Kenney shell regraded biopunk, its own wheels on the
## chassis's springs, bolt-on scrap panels, and this component wired to it.
static func make(model := "sedan", seed_value := 1, with_driver := true) -> RigidBody3D:
	var body: RigidBody3D = VEHICLE.new()
	body.name = "LabCar_%s" % model
	var shell := (MODELS.get(model, MODELS.sedan) as PackedScene).instantiate() as Node3D
	shell.name = "Shell"
	shell.scale = Vector3.ONE * SHELL_SCALE
	# Kenney cars face +Z; the chassis drives toward -Z.
	shell.rotation.y = PI
	shell.position.y = VEHICLE.rest_contact_y()
	body.add_child(shell)
	var anchors: Array = VEHICLE.WHEEL_ANCHORS.duplicate()
	for wheel_name in WHEELS:
		var wheel := shell.find_child(wheel_name, true, false) as Node3D
		if wheel == null:
			continue
		# The tyre's middle, not its inner face (Kenney wheels sit on the hub).
		var tyre := wheel.position + Vector3(0.125 * signf(wheel.position.x), 0, 0)
		var at := shell.transform * tyre
		anchors[WHEELS[wheel_name]] = Vector3(at.x, VEHICLE.WHEEL_ANCHORS[0].y, at.z)
	body.wheel_anchors = anchors
	var box := _shell_box(shell)
	body.hull_size = Vector3(box.size.x - 0.05, 1.5, box.size.z - 0.05)
	_regrade(shell)
	var damage := VehicleDamage.new()
	damage.name = "Damage"
	body.add_child(damage)
	damage.car = body
	damage._bolt_on(shell, box)
	SILHOUETTE.dress_vehicle(body, Vector3(body.hull_size.x * 0.8, 1.0, body.hull_size.z * 0.8), anchors, seed_value, WorldLook.surface, false)
	if with_driver:
		damage._driver_seed = seed_value
	body.impact.connect(damage._on_impact)
	body.set_meta("lab_station", damage)
	return body


## The shell's bounds in chassis space.
static func _shell_box(shell: Node3D) -> AABB:
	var body_mesh := shell.find_child("body", true, false) as MeshInstance3D
	return (shell.transform * body_mesh.transform) * body_mesh.get_aabb()


## Bright toy paint to rust, bone and old blood: the kit's palette texture
## swapped for a regraded copy, the surface made rough and a little metal.
static func _regrade(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for index in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_material(index) as BaseMaterial3D
			if source == null:
				continue
			var grimed := source.duplicate() as BaseMaterial3D
			grimed.albedo_texture = BIOPUNK_MAP
			grimed.roughness = 0.82
			grimed.metallic = 0.3
			mi.set_surface_override_material(index, grimed)


func _bolt_on(shell: Node3D, box: AABB) -> void:
	var ground: float = VEHICLE.rest_contact_y()
	var front := box.position.z
	var back := box.end.z
	var side := box.end.x
	var hood_y := _hood_height(shell, box)
	_part("BumperFront", BUMPER, Vector3(0, ground + 0.3, front - 0.12), Vector3(0, 0, 0), Vector3(1.55, 1.2, 1.0), "steel_sheet", 20.0, 18.0)
	_part("BumperRear", BUMPER, Vector3(0, ground + 0.3, back + 0.12), Vector3(0, PI, 0), Vector3(1.55, 1.2, 1.0), "steel_sheet", 20.0, 18.0)
	_part("DoorLeft", DOOR, Vector3(-side - 0.06, ground + 0.32, 0.05), Vector3.ZERO, Vector3(1.0, 1.0, 1.45), "steel_sheet", 22.0, 24.0)
	_part("DoorRight", DOOR, Vector3(side + 0.06, ground + 0.32, 0.05), Vector3.ZERO, Vector3(1.0, 1.0, 1.45), "steel_sheet", 22.0, 24.0)
	_part("Hood", PLATE, Vector3(0, hood_y + 0.01, front + box.size.z * 0.17), Vector3(0, 0.08, 0), Vector3(1.9, 1.0, 1.15), "steel_sheet", 18.0, 16.0)
	_windscreen(shell, box, hood_y)
	for wheel_name in WHEELS:
		var wheel := shell.find_child(wheel_name, true, false) as Node3D
		if wheel == null:
			continue
		# Physics wheel radius, not the kit's.
		wheel.scale = Vector3.ONE * (VEHICLE.WHEEL_RADIUS / 0.3) / SHELL_SCALE
		parts["Wheel%d" % WHEELS[wheel_name]] = {"node": wheel, "material": "steel_sheet", "hp": 45.0, "mass": 22.0, "wheel": WHEELS[wheel_name]}
	for node in shell.find_children("*", "MeshInstance3D", true, false):
		if not str(node.name).begins_with("wheel"):
			_track_mesh(node as MeshInstance3D, true)


func _part(part_name: String, scene: PackedScene, at: Vector3, turn: Vector3, size: Vector3, material: String, hp: float, kilos: float) -> void:
	var node := scene.instantiate() as Node3D
	node.name = part_name
	node.position = at
	node.rotation = turn
	node.scale = size
	car.add_child(node)
	_regrade(node)
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		_track_mesh(mi as MeshInstance3D)
	parts[part_name] = {"node": node, "material": material, "hp": hp, "mass": kilos, "wheel": -1}


## Highest point of the body over its front fifth: where the hood is.
func _hood_height(shell: Node3D, box: AABB) -> float:
	var body_mesh := shell.find_child("body", true, false) as MeshInstance3D
	var to_car := shell.transform * body_mesh.transform
	var best := box.position.y + box.size.y * 0.4
	for v: Vector3 in body_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var p := to_car * v
		if p.z < box.position.z + box.size.z * 0.2:
			best = maxf(best, p.y)
	return best


## A dark glass pane laid over the kit's painted windscreen, from the hood
## line up to the front of the roof.
func _windscreen(shell: Node3D, box: AABB, hood_y: float) -> void:
	var body_mesh := shell.find_child("body", true, false) as MeshInstance3D
	var to_car := shell.transform * body_mesh.transform
	var roof := box.end.y
	var roof_front := box.end.z
	var low_front := box.end.z
	for v: Vector3 in body_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var p := to_car * v
		if p.y > roof - 0.06:
			roof_front = minf(roof_front, p.z)
		if p.y > hood_y + 0.08 and p.y < hood_y + 0.2:
			low_front = minf(low_front, p.z)
	var bottom := Vector3(0, hood_y + 0.1, low_front + 0.02)
	var top := Vector3(0, roof - 0.04, roof_front + 0.02)
	var pane := MeshInstance3D.new()
	pane.name = "Windscreen"
	var quad := QuadMesh.new()
	quad.size = Vector2(box.size.x * 0.78, bottom.distance_to(top))
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.16, 0.2, 0.18, 0.55)
	glass.metallic = 0.6
	glass.roughness = 0.06
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = glass
	pane.mesh = quad
	var middle := (bottom + top) * 0.5
	var up := (top - bottom).normalized()
	var normal := Vector3.RIGHT.cross(up).normalized()
	pane.transform = Transform3D(Basis(Vector3.RIGHT, up, normal), middle)
	car.add_child(pane)
	parts["Windscreen"] = {"node": pane, "material": "glass", "hp": 4.0, "mass": 6.0, "wheel": -1}


## A private, editable copy of a mesh: its rest positions kept so a dent is
## always measured from how the car was built.
## `finer` splits every triangle in four first: the kit's body is a few
## hundred faces, too coarse for a crease to show.
func _track_mesh(mi: MeshInstance3D, finer := false) -> void:
	var source := mi.mesh
	var copy := ArrayMesh.new()
	var entry := {"mi": mi, "mesh": copy, "arrays": [], "rest": [], "materials": []}
	for index in source.get_surface_count():
		var arrays := source.surface_get_arrays(index)
		if finer:
			arrays = _split_in_four(arrays)
		copy.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		copy.surface_set_material(index, source.surface_get_material(index))
		entry.arrays.append(arrays)
		entry.rest.append((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate())
	mi.mesh = copy
	_meshes.append(entry)


## One midpoint subdivision, unindexed. Positions, normals and UVs only; a
## shared edge gets the same midpoint from both sides, so no cracks open.
static func _split_in_four(arrays: Array) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		for i in verts.size():
			indices.append(i)
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_uv := PackedVector2Array()
	for t in range(0, indices.size() - 2, 3):
		var corner := [indices[t], indices[t + 1], indices[t + 2]]
		var v := [verts[corner[0]], verts[corner[1]], verts[corner[2]]]
		var n := [normals[corner[0]], normals[corner[1]], normals[corner[2]]]
		var v_mid := [(v[0] + v[1]) * 0.5, (v[1] + v[2]) * 0.5, (v[2] + v[0]) * 0.5]
		var n_mid := [(n[0] + n[1]).normalized(), (n[1] + n[2]).normalized(), (n[2] + n[0]).normalized()]
		var faces := [[0, 3, 5], [3, 1, 4], [5, 4, 2], [3, 4, 5]]
		var all_v: Array = v + v_mid
		var all_n: Array = n + n_mid
		var all_uv: Array = []
		if not uvs.is_empty():
			var u := [uvs[corner[0]], uvs[corner[1]], uvs[corner[2]]]
			all_uv = u + [(u[0] + u[1]) * 0.5, (u[1] + u[2]) * 0.5, (u[2] + u[0]) * 0.5]
		for face in faces:
			for k in face:
				out_v.append(all_v[k])
				out_n.append(all_n[k])
				if not all_uv.is_empty():
					out_uv.append(all_uv[k])
	var result := []
	result.resize(Mesh.ARRAY_MAX)
	result[Mesh.ARRAY_VERTEX] = out_v
	result[Mesh.ARRAY_NORMAL] = out_n
	if not out_uv.is_empty():
		result[Mesh.ARRAY_TEX_UV] = out_uv
	return result


func _seat_driver(seed_value: int) -> void:
	driver = BaselineHuman.new()
	driver.name = "DriverRig"
	driver.position = Vector3(-0.38, -0.2, 0.15)
	car.add_child(driver)
	driver.build("lab_driver_%02d" % seed_value, {"seated": true, "flesh": Color("6b5842"), "variation": seed_value + 2, "blood": 5200.0})


func _ready() -> void:
	_steam = CPUParticles3D.new()
	_steam.name = "RadiatorSteam"
	_steam.emitting = false
	_steam.amount = 16
	_steam.lifetime = 1.4
	_steam.direction = Vector3.UP
	_steam.spread = 25.0
	_steam.initial_velocity_min = 1.0
	_steam.initial_velocity_max = 2.2
	_steam.gravity = Vector3(0, 0.6, 0)
	_steam.scale_amount_min = 0.15
	_steam.scale_amount_max = 0.4
	var puff := SphereMesh.new()
	puff.radius = 0.16
	puff.height = 0.32
	var haze := StandardMaterial3D.new()
	haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	haze.albedo_color = Color(0.72, 0.7, 0.66, 0.08)
	puff.material = haze
	_steam.mesh = puff
	if _driver_seed >= 0:
		_seat_driver.call_deferred(_driver_seed)
	if car != null:
		car.add_child.call_deferred(_steam)
		_steam.position = Vector3(0, 0.1, -car.hull_size.z * 0.4)


## Wheels follow their springs and the rack; spin with the road.
func _physics_process(delta: float) -> void:
	if car == null:
		return
	_spin += float(car.signed_speed) * delta / VEHICLE.WHEEL_RADIUS
	var shell := car.get_node_or_null("Shell") as Node3D
	for index in 4:
		var part: Dictionary = parts.get("Wheel%d" % index, {})
		if part.is_empty():
			continue
		var wheel := part.node as Node3D
		var anchor: Vector3 = car.wheel_anchors[index]
		var centre_y: float = anchor.y - (VEHICLE.SUSPENSION_REST - float(car.wheel_compression[index]))
		if not car.wheel_contacts[index]:
			centre_y = anchor.y - VEHICLE.SUSPENSION_REST
		wheel.position.y = (centre_y - shell.position.y) / SHELL_SCALE
		wheel.rotation = Vector3(-_spin, float(car.steer_angle) if index < 2 else 0.0, 0.0)


func _on_impact(other: Node, closing: float, self_share: float) -> void:
	if car == null:
		return
	var at: Vector3 = car.last_contact
	var push := car.global_position - at
	push.y *= 0.3
	if push.length_squared() < 0.0001:
		push = car.global_basis.z
	# Equal masses crush about equally whoever brought the speed; the car that
	# was moving still wears a little more.
	var speed := closing * (0.7 + 0.3 * self_share)
	if other is VoxelStructure:
		(other as VoxelStructure).damage_sphere(at, 0.8, "vehicle", maxf(0.0, closing - DENT_THRESHOLD) * 10.0, -push.normalized() * closing, {"mass": car.mass, "speed": closing})
	hit(at, push.normalized(), speed, "vehicle", {"mass": car.mass, "speed": speed})


## A blow at `at` (global) travelling `push` (global, into the car) at `speed`
## m/s, from a `MaterialToughness` source. Returns what it did.
func hit(at: Vector3, push: Vector3, speed: float, source := "vehicle", params := {}) -> Dictionary:
	var result := {"dent": 0.0, "detached": [], "engine": engine}
	var over := maxf(0.0, speed - DENT_THRESHOLD)
	if car == null or over <= 0.0:
		return result
	hits += 1
	var local := car.to_local(at)
	var inward := (car.global_basis.inverse() * push).normalized()
	var radius := 0.8 + over * 0.05
	result.dent = _dent(local, inward, minf(over * DENT_PER_MS * crumple, MAX_CRUSH), radius)
	for part_name in parts.keys():
		var part: Dictionary = parts[part_name]
		var node := part.node as Node3D
		var distance := car.to_local(node.global_position).distance_to(local)
		if distance > radius + PART_REACH:
			continue
		part.hp = float(part.hp) - over * (1.0 - distance / (radius + PART_REACH)) * PART_DAMAGE
		if float(part.hp) <= 0.0 and MaterialToughness.can_break(source, str(part.material), params):
			_detach(part_name, push, at)
			result.detached.append(part_name)
	if local.z < -car.hull_size.z / 6.0:
		engine = maxf(MIN_ENGINE, engine - over * ENGINE_PER_MS)
		car.engine_power = engine
		if _steam != null and _steam.is_inside_tree():
			_steam.emitting = engine < STEAM_BELOW
	result.engine = engine
	_hurt_driver(at, push, over, local)
	return result


## The lab's own hit hook (`mechanics_lab._land`): a round or a blow.
## `kind` is the lab's "firearm" or "melee"; a blade dents and breaks glass
## but cannot take steel off.
func strike(at: Vector3, direction: Vector3, kind := "firearm") -> Dictionary:
	var result := hit(at, direction, DENT_THRESHOLD + 4.0, MaterialToughness.source_for(kind))
	result["what"] = "vehicle"
	return result


func _dent(local: Vector3, inward: Vector3, depth: float, radius: float) -> float:
	var started := Time.get_ticks_usec()
	var deepest := 0.0
	var car_inverse := car.global_transform.affine_inverse()
	for entry in _meshes:
		var mi := entry.mi as MeshInstance3D
		if not is_instance_valid(mi) or not mi.is_inside_tree() or not car.is_ancestor_of(mi):
			continue
		var to_mesh := (car_inverse * mi.global_transform).affine_inverse()
		var unit := (to_mesh.basis * Vector3.RIGHT).length()
		var p := to_mesh * local
		var dir := (to_mesh.basis * inward).normalized()
		var reach := radius * unit
		var cap := MAX_CRUSH * unit
		var changed := false
		for surface in entry.arrays.size():
			var arrays: Array = entry.arrays[surface]
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var rest: PackedVector3Array = entry.rest[surface]
			var moved := PackedByteArray()
			moved.resize(verts.size())
			var any := false
			for i in verts.size():
				# A crush plane, not a point push: everything standing out past
				# `depth` behind the contact is folded back to it, the way a
				# wall flattens a nose, fading out sideways across `reach`.
				var rel := verts[i] - p
				var along := rel.dot(-dir)
				var lateral := (rel + dir * along).length()
				if lateral >= reach:
					continue
				var side := lateral / reach
				var push := along + depth * unit * (1.0 - side * side)
				if push <= 0.0:
					continue
				# Wrinkles: a sideways kick keyed on where the vertex was built,
				# so split (flat-shaded) copies of one corner move together.
				var key := rest[i].snapped(Vector3.ONE * 0.001)
				var wrinkle := Vector3(sin(key.x * 91.7 + key.z * 37.1), sin(key.y * 53.3 + key.x * 17.9), sin(key.z * 71.3 + key.y * 29.3))
				var v := verts[i] + dir * push + wrinkle.slide(dir) * push * WRINKLE
				var offset := v - rest[i]
				if offset.length() > cap:
					v = rest[i] + offset.normalized() * cap
				verts[i] = v
				moved[i] = 1
				any = true
				deepest = maxf(deepest, (v - rest[i]).length() / unit)
			if not any:
				continue
			arrays[Mesh.ARRAY_VERTEX] = verts
			_relight(arrays, moved)
			changed = true
		if changed:
			var mesh := entry.mesh as ArrayMesh
			var materials: Array = []
			for surface in mesh.get_surface_count():
				materials.append(mesh.surface_get_material(surface))
			mesh.clear_surfaces()
			for surface in entry.arrays.size():
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, entry.arrays[surface])
				mesh.surface_set_material(surface, materials[surface])
	max_crush = maxf(max_crush, deepest)
	dent_usec_max = maxi(dent_usec_max, Time.get_ticks_usec() - started)
	return deepest


## Flat normals on every face a dent touched, so creases catch the light.
func _relight(arrays: Array, moved: PackedByteArray) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	if normals.size() != verts.size():
		return
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var count := indices.size() if not indices.is_empty() else verts.size()
	for t in range(0, count - 2, 3):
		var a := indices[t] if not indices.is_empty() else t
		var b := indices[t + 1] if not indices.is_empty() else t + 1
		var c := indices[t + 2] if not indices.is_empty() else t + 2
		if moved[a] == 0 and moved[b] == 0 and moved[c] == 0:
			continue
		var normal := Plane(verts[a], verts[b], verts[c]).normal
		normals[a] = normal
		normals[b] = normal
		normals[c] = normal
	arrays[Mesh.ARRAY_NORMAL] = normals


func _detach(part_name: String, push: Vector3, at: Vector3) -> void:
	var part: Dictionary = parts[part_name]
	parts.erase(part_name)
	detached.append(part_name)
	var node := part.node as Node3D
	var world := car.get_parent()
	MaterialToughness.play_break(car, at, str(part.material))
	if int(part.wheel) >= 0:
		car.wheel_lost[int(part.wheel)] = true
	if part.material == "glass":
		_shatter(node, push)
		node.queue_free()
	else:
		var loose := RigidBody3D.new()
		loose.name = "%s_Detached" % part_name
		loose.mass = float(part.mass)
		world.add_child(loose)
		loose.global_transform = Transform3D(node.global_basis.orthonormalized(), node.global_position)
		node.reparent(loose, true)
		var mi := (node if node is MeshInstance3D else node.find_children("*", "MeshInstance3D", true, false)[0]) as MeshInstance3D
		var bounds := (loose.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = bounds.size.max(Vector3.ONE * 0.05)
		shape.shape = box
		shape.position = bounds.get_center()
		loose.add_child(shape)
		loose.linear_velocity = car.linear_velocity
		loose.apply_central_impulse((push.normalized() * 3.0 + Vector3.UP * 2.0) * loose.mass)
		loose.apply_torque_impulse(Vector3(1.2, 2.0, 0.8) * loose.mass * 0.3)
		WorldDebris.register(loose, {"kind": "vehicle_part", "part": part_name, "vehicle": car.name}, PART_POOL, PART_BUDGET)
	WorldHistory.record_event("vehicle_part_detached", {"vehicle": car.name, "part": part_name})


## The windscreen goes as a spray of thick shards that stay on the floor.
func _shatter(pane: Node3D, push: Vector3) -> void:
	var quad := (pane as MeshInstance3D).mesh as QuadMesh
	var rng := RandomNumberGenerator.new()
	rng.seed = car.get_instance_id()
	for index in 10:
		var shard := RigidBody3D.new()
		shard.mass = 0.3
		var visual := MeshInstance3D.new()
		var plate := BoxMesh.new()
		plate.size = Vector3(rng.randf_range(0.08, 0.22), 0.012, rng.randf_range(0.06, 0.18))
		plate.material = quad.material
		visual.mesh = plate
		shard.add_child(visual)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = plate.size
		shape.shape = box
		shard.add_child(shape)
		car.get_parent().add_child(shard)
		var spot := Vector3(rng.randf_range(-0.45, 0.45) * quad.size.x, rng.randf_range(-0.45, 0.45) * quad.size.y, 0.0)
		shard.global_position = pane.to_global(spot)
		shard.linear_velocity = car.linear_velocity + push.normalized() * rng.randf_range(1.0, 3.0) + Vector3.UP * rng.randf_range(0.5, 2.0)
		WorldDebris.register(shard, {"kind": "glass_shard", "vehicle": car.name}, SHARD_POOL, SHARD_BUDGET)


func _hurt_driver(at: Vector3, push: Vector3, over: float, local: Vector3) -> void:
	if driver == null or not is_instance_valid(driver) or driver.anatomy.dead:
		return
	# The derby's rule: once the bumper and the hood are gone nothing stands
	# between a fast front hit and the cab, and it lands on the chest.
	var crush := detached.has("BumperFront") and detached.has("Hood") and local.z < 0.0 and over + DENT_THRESHOLD > RAM_CRUSH_SPEED
	var zone := "torso" if crush else driver.zone_nearest(at)
	driver.hit(zone, over * DRIVER_PER_MS * (1.45 if crush else 1.0), over * 4.0, "shear" if crush else "blunt", "", push)


## Everything a test or a HUD wants in one place.
func report() -> Dictionary:
	return {"engine": engine, "max_crush": max_crush, "detached": detached.duplicate(), "hits": hits, "dent_usec_max": dent_usec_max,
		"wheels_lost": (car.wheel_lost as Array).count(true) if car != null else 0}
