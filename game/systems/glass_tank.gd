class_name GlassTank
extends Node3D

## A glass tank of fluid that cracks, bursts and empties into a FluidBody.
##
## Greg (5 Oct): "real see-through glass with reflections; cracks spread with
## each hit before it breaks; shards fly, fall and stay on the floor with
## physics; liquid pressure helps burst it outward", and in the tank "a real
## surface ... that sloshes when hit or walked into and drops as it drains",
## "bodies/objects float inside".
##
## Built for the mechanics lab's liquid station and meant for the opening vat
## (Job 4): nothing here knows about the lab. Sits on whatever it stands on
## (this node is the tank's foot); give it a FluidBody to pour into.
##
## Shards: a runtime split, not Blender Cell Fracture. The tube above a jagged
## break line is cut on a jittered grid (12 round x 2 up, each cell halved on
## a diagonal) into 48 thick triangular plates. Cheaper than pre-cut cells
## here because it fits any radius and height with no asset per tank size,
## the break line can be shared with the standing stub exactly (the shader
## discards above the same line), and a thin curved wall gains nothing from
## Voronoi interiors. All tanks share one shard budget; the oldest goes.
##
## imp-61 sound (Greg, 5 Oct ~19:00: "... and add sound"): a crack per stage
## (sharper and longer each blow), the burst with the gush of fluid, and a
## looping pour whose loudness follows the Torricelli flow. Through
## FluidSound; FluidSound.volume = 0 silences all of it.

signal cracked(stage: int)
signal burst(direction: Vector3)

## Dials.
@export var radius := 0.7
@export var height := 2.0
@export var fill := 0.9
## Blows to break: stages 1..blows-1 are cracks, the last one bursts.
@export var blows := 4
## Seconds the burst tank takes to empty to its stub (Torricelli: fast first).
@export var pour_seconds := 6.0
## How hard the fluid throws the wall out: 0 none, 1 a full tank's head.
@export var pressure := 1.0
## Cubic metres that reach the floor sheet from a full tank.
@export var spill_volume := 0.06

const THICK := 0.022
const COLUMNS := 12
const ROWS := 2
static var max_shards := 96
static var _all_shards: Array[RigidBody3D] = []

var fluid: FluidBody
var floater: Node3D
var hits := 0
var broken := false
var level := 1.0
var stub_line := PackedFloat32Array()
var shards: Array[RigidBody3D] = []

var body: StaticBody3D
var _shape: CollisionShape3D
var _glass_material: ShaderMaterial
var _fluid_material: ShaderMaterial
var _fluid: MeshInstance3D
var _impacts: Array[Vector4] = [Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO]
var _tilt := Vector2.ZERO
var _tilt_vel := Vector2.ZERO
var _ripple_age := 99.0
var _head0 := 1.0
var _owed := 0.0
var _hit_dir := Vector3.FORWARD
var _float_rest := Vector3.ZERO
var _pour_sound: AudioStreamPlayer3D
var _flow_peak := 0.0


func _ready() -> void:
	if body == null:
		build()


func build() -> void:
	body = StaticBody3D.new()
	body.name = "Glass"
	body.position = Vector3(0, height * 0.5, 0)
	body.set_meta("glass_tank", self)
	add_child(body)
	_shape = CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	_shape.shape = cylinder
	body.add_child(_shape)

	_glass_material = ShaderMaterial.new()
	_glass_material.shader = preload("res://shaders/glass_tank.gdshader")
	_glass_material.render_priority = 1
	_glass_material.set_shader_parameter("radius", radius)
	_glass_material.set_shader_parameter("half_height", height * 0.5)
	# Outer and inner skins: the wall's thickness shows at every silhouette.
	for skin in [radius, radius - THICK]:
		var tube := CylinderMesh.new()
		tube.top_radius = skin
		tube.bottom_radius = skin
		tube.height = height
		tube.radial_segments = 48
		tube.rings = 6
		tube.cap_top = false
		tube.cap_bottom = false
		tube.material = _glass_material
		var wall := MeshInstance3D.new()
		wall.name = "Wall"
		wall.mesh = tube
		wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(wall)
	for y in [height * 0.5, -height * 0.5]:
		var rim := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = radius - 0.03
		ring.outer_radius = radius + 0.06
		ring.rings = 48
		var metal := StandardMaterial3D.new()
		metal.albedo_color = Color("3a2f27")
		metal.metallic = 0.6
		metal.roughness = 0.45
		ring.material = metal
		rim.mesh = ring
		rim.position = Vector3(0, y, 0)
		body.add_child(rim)

	_fluid_material = ShaderMaterial.new()
	_fluid_material.shader = preload("res://shaders/fluid_volume.gdshader")
	_fluid_material.render_priority = -1
	var column := CylinderMesh.new()
	column.top_radius = radius - THICK - 0.004
	column.bottom_radius = column.top_radius
	column.height = height * fill
	column.radial_segments = 48
	column.rings = 10
	column.material = _fluid_material
	_fluid_material.set_shader_parameter("half_height", column.height * 0.5)
	_fluid = MeshInstance3D.new()
	_fluid.name = "Fluid"
	_fluid.mesh = column
	_fluid.position = Vector3(0, column.height * 0.5, 0)
	add_child(_fluid)
	_apply()


## Something hanging in the fluid (a body, debris): it bobs under the
## surface and settles as the level drops. `rest` is its full-tank position.
func hold(thing: Node3D, rest: Vector3) -> void:
	floater = thing
	_float_rest = rest
	if thing.get_parent() == null:
		add_child(thing)
	thing.position = rest


## A blow or a round at `at` (global) travelling `direction`. `weight` blows.
func strike(at: Vector3, direction: Vector3, weight := 1) -> Dictionary:
	var local := to_local(at)
	slosh(local, 0.3 * weight)
	if broken:
		return {"hit": true, "broken": true, "stage": blows}
	hits = mini(hits + weight, blows)
	var flat := Vector2(local.x, local.z)
	var on_wall := (flat.normalized() if flat.length() > 0.01 else Vector2(0, 1)) * radius
	var impact := Vector4(on_wall.x, clampf(local.y - height * 0.5, -height * 0.45, height * 0.45), on_wall.y, 1.0)
	_impacts[(hits - 1) % 4] = impact
	for index in 4:
		if _impacts[index].w > 0.0:
			_impacts[index].w = 0.7 + 0.3 * float(hits) / float(blows)
	if hits >= blows:
		_burst(direction)
		return {"hit": true, "broken": true, "stage": hits}
	cracked.emit(hits)
	FluidSound.play(self, "glass_crack_%d" % clampi(hits, 1, 3), at, 0.7 + 0.1 * hits)
	_apply()
	return {"hit": true, "broken": false, "stage": hits}


## Walked into, kicked, shoved: the surface tips toward `at` (local).
func slosh(at: Vector3, strength: float) -> void:
	var flat := Vector2(at.x, at.z)
	if flat.length() > 0.01:
		_tilt_vel -= flat.normalized() * strength * 0.25
	_fluid_material.set_shader_parameter("ripple_at", flat.limit_length(radius * 0.8))
	_fluid_material.set_shader_parameter("ripple_amp", clampf(strength * 0.02, 0.0, 0.03))
	_ripple_age = 0.0


func crack_stage() -> int:
	return 0 if broken else hits


func _burst(direction: Vector3) -> void:
	broken = true
	_hit_dir = direction.normalized() if direction.length() > 0.01 else Vector3.FORWARD
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	stub_line.resize(COLUMNS)
	for index in COLUMNS:
		stub_line[index] = -height * 0.5 + height * rng.randf_range(0.14, 0.36)
	# The burst line in tank-foot space, and the head of fluid above it.
	var leak := _leak_floor()
	_head0 = maxf(_top() - leak, 0.001)
	_owed = 0.0
	_tilt_vel += Vector2(_hit_dir.x, _hit_dir.z) * 0.4
	_make_shards(rng)
	(_shape.shape as CylinderShape3D).height = leak
	_shape.position.y = -height * 0.5 + leak * 0.5
	burst.emit(_hit_dir)
	var face := to_global(Vector3(-_hit_dir.x, 0, -_hit_dir.z).normalized() * radius + Vector3(0, leak + 0.3, 0))
	FluidSound.play(self, "glass_burst", face, 1.0)
	FluidSound.play(self, "fluid_gush", face, clampf(_head0 / height, 0.4, 1.0))
	if _pour_sound == null:
		_pour_sound = FluidSound.loop(self, "fluid_pour_loop")
	_pour_sound.position = Vector3(0, leak, 0)
	_flow_peak = 0.0
	if _pour_sound.is_inside_tree() and _pour_sound.stream != null and FluidSound.volume > 0.0:
		_pour_sound.play()
	_apply()


func refill() -> void:
	broken = false
	hits = 0
	level = 1.0
	_impacts = [Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO]
	if _pour_sound != null:
		_pour_sound.stop()
	(_shape.shape as CylinderShape3D).height = height
	_shape.position.y = 0.0
	for shard in shards:
		if is_instance_valid(shard):
			_all_shards.erase(shard)
			shard.queue_free()
	shards.clear()
	_apply()


func _top() -> float:
	return height * fill * level


func _leak_floor() -> float:
	var lowest := INF
	for value in stub_line:
		lowest = minf(lowest, value)
	return lowest + height * 0.5


func _physics_process(delta: float) -> void:
	# The slosh: a damped spring on the surface's tilt.
	_tilt_vel += (-_tilt * 38.0 - _tilt_vel * 2.2) * delta
	_tilt += _tilt_vel * delta
	_tilt = _tilt.limit_length(0.35)
	_ripple_age += delta
	if broken:
		_drain(delta)
	if floater != null and is_instance_valid(floater):
		var bob := sin(Time.get_ticks_msec() * 0.0011) * 0.03
		var surface := _top() - 0.12
		var y := minf(_float_rest.y + bob, surface)
		floater.position = Vector3(_float_rest.x + _tilt.x * 0.3, maxf(y, 0.18), _float_rest.z + _tilt.y * 0.3)
		floater.rotation.z = 0.5 + sin(Time.get_ticks_msec() * 0.0007) * 0.08 + _tilt.x
	_fluid_material.set_shader_parameter("tilt", _tilt)
	_fluid_material.set_shader_parameter("ripple_age", _ripple_age)
	_fluid_material.set_shader_parameter("level", level)


## Torricelli: the head above the break falls at k*sqrt(head), so the pour
## comes out hard and tails off, and the stub keeps what is below the break.
func _drain(delta: float) -> void:
	var leak := _leak_floor()
	var head := _top() - leak
	if head <= 0.002:
		if _pour_sound != null and _pour_sound.playing:
			_pour_sound.stop()
		return
	var k := 2.0 * sqrt(_head0) / maxf(pour_seconds, 0.1)
	var drop := minf(k * sqrt(head) * delta, head)
	if _pour_sound != null:
		# Loud while it gushes, a trickle as the head falls.
		var flow := k * sqrt(head)
		_flow_peak = maxf(_flow_peak, flow)
		var share := flow / maxf(_flow_peak, 0.0001)
		_pour_sound.volume_db = linear_to_db(clampf(share * share * FluidSound.volume, 0.001, 1.0))
		_pour_sound.pitch_scale = lerpf(0.8, 1.05, share)
	level = maxf((_top() - drop) / (height * fill), 0.0)
	if fluid == null:
		return
	_owed += spill_volume * drop / _head0
	var share := spill_volume / 700.0
	var budget := 12
	while _owed >= share and budget > 0:
		budget -= 1
		var around: float
		if randf() < 0.75:
			# Mostly out of the struck face, which faces whoever struck it
			# (imp-61: narrowed so the pour reads as one stream, not a ring).
			around = atan2(-_hit_dir.z, -_hit_dir.x) + randf_range(-0.7, 0.7)
		else:
			around = randf() * TAU
		var out := Vector3(cos(around), 0, sin(around))
		var y := lerpf(leak, _top(), pow(randf(), 1.6))
		var speed := sqrt(2.0 * 9.8 * maxf(_top() - y, 0.02)) * clampf(0.35 + pressure * 0.65, 0.2, 1.5) * (1.0 - fluid.viscosity * 0.45)
		if randf() < 0.3:
			# Gloop rolling over the broken lip and down the outside.
			y = leak
			speed = randf_range(0.2, 0.9)
		var from := to_global(out * (radius + 0.05) + Vector3(0, y, 0))
		var velocity := global_basis * (out * speed + Vector3(randf_range(-0.2, 0.2), randf_range(-0.1, 0.3), randf_range(-0.2, 0.2)))
		if not fluid.emit(from, velocity, share):
			break
		_owed -= share


func _apply() -> void:
	_glass_material.set_shader_parameter("crack", 0.0 if hits == 0 else float(hits) / float(maxi(blows - 1, 1)))
	_glass_material.set_shader_parameter("impacts", PackedVector4Array(_impacts))
	_glass_material.set_shader_parameter("stub", 1.0 if broken else 0.0)
	if stub_line.size() == COLUMNS:
		_glass_material.set_shader_parameter("stub_line", stub_line)
	_fluid_material.set_shader_parameter("level", level)


# --- shards ------------------------------------------------------------------

func _make_shards(rng: RandomNumberGenerator) -> void:
	# Grid points on the tube: row 0 is the break line (shared with the stub
	# in the shader: column i sits at angle (i/12 - 0.5) * TAU), the top row
	# is the rim, the rows between are jittered.
	var points: Array = []
	for row in ROWS + 1:
		var line: Array[Vector3] = []
		for column in COLUMNS:
			var turn := (float(column) / COLUMNS - 0.5) * TAU
			var y: float
			if row == 0:
				y = stub_line[column]
			elif row == ROWS:
				y = height * 0.5
			else:
				turn += rng.randf_range(-0.3, 0.3) * TAU / COLUMNS
				y = lerpf(stub_line[column], height * 0.5, float(row) / ROWS) + rng.randf_range(-0.12, 0.12)
			line.append(Vector3(cos(turn) * radius, y, sin(turn) * radius))
		points.append(line)
	var material := ShaderMaterial.new()
	material.shader = _glass_material.shader
	material.render_priority = 1
	material.set_shader_parameter("radius", radius)
	var head := _top()
	for row in ROWS:
		for column in COLUMNS:
			var next := (column + 1) % COLUMNS
			var a: Vector3 = points[row][column]
			var b: Vector3 = points[row][next]
			var c: Vector3 = points[row + 1][next]
			var d: Vector3 = points[row + 1][column]
			var pair := [[a, b, c], [a, c, d]] if rng.randf() < 0.5 else [[a, b, d], [b, c, d]]
			for tri in pair:
				_shard(tri, material, head)


func _shard(tri: Array, material: Material, head: float) -> void:
	var centre: Vector3 = (tri[0] + tri[1] + tri[2]) / 3.0
	var outward := Vector3(centre.x, 0, centre.z).normalized()
	var outer := PackedVector3Array()
	var inner := PackedVector3Array()
	for point: Vector3 in tri:
		outer.append(point - centre)
		inner.append(point - centre - outward * THICK)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [[outer[0], outer[1], outer[2]], [inner[2], inner[1], inner[0]]]:
		for vertex: Vector3 in face:
			surface.add_vertex(vertex)
	for edge in 3:
		var n := (edge + 1) % 3
		for vertex in [outer[edge], inner[edge], inner[n], outer[edge], inner[n], outer[n]]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, material)

	var shard := RigidBody3D.new()
	shard.name = "Shard"
	shard.mass = 0.08
	shard.collision_layer = 1 << 3
	shard.collision_mask = 1 | (1 << 3)
	shard.linear_damp = 0.1
	shard.angular_damp = 0.6
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	shard.add_child(piece)
	var hull := CollisionShape3D.new()
	var convex := ConvexPolygonShape3D.new()
	var all := outer.duplicate()
	all.append_array(inner)
	convex.points = all
	hull.shape = convex
	shard.add_child(hull)
	get_parent().add_child(shard)
	shard.global_transform = Transform3D(global_basis, to_global(centre + Vector3(0, height * 0.5, 0)))
	# Pressure: the deeper under the surface, the harder the wall goes out.
	var below := clampf((head - (centre.y + height * 0.5)) / height, 0.0, 1.0)
	var throw := outward * (0.8 + pressure * level * 4.5 * (0.3 + below)) + Vector3(0, randf_range(0.2, 1.4), 0)
	if outward.dot(_hit_dir) < -0.6:
		throw += _hit_dir * 1.2
	shard.linear_velocity = global_basis * throw
	shard.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	shards.append(shard)
	_prune_shards()
	_all_shards.append(shard)
	while _all_shards.size() > max_shards:
		# Untyped: a shard swept with its scene is already freed here.
		var oldest: Variant = _all_shards.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()


## Feet through the shards on the floor: they skitter.
static func kick(feet: Vector3, velocity: Vector3) -> int:
	var flat := Vector3(velocity.x, 0, velocity.z)
	if flat.length() < 0.5:
		return 0
	var moved := 0
	_prune_shards()
	for shard in _all_shards:
		if not is_instance_valid(shard):
			continue
		var gap := shard.global_position - feet
		if Vector2(gap.x, gap.z).length() < 0.32 and absf(gap.y) < 0.4:
			shard.apply_central_impulse((flat * 0.5 + Vector3(0, 0.6, 0)) * shard.mass)
			moved += 1
	return moved


static func shard_count() -> int:
	_prune_shards()
	return _all_shards.size()


## The list is static and outlives the scene that owned the shards, so drop the
## freed ones before anything reads it through a typed variable.
static func _prune_shards() -> void:
	_all_shards = _all_shards.filter(func(shard: Variant) -> bool: return is_instance_valid(shard))
