class_name SmokeVolume
extends Node3D

## drug-70. Smoke as a simulated volume, not sprite puffs.
##
## `ContaminatedAir.emit_exhale()` throws a one-shot GPU burst that turbulence
## breaks up. That reads as breath in passing, but nothing about it knows where
## the wind is, what is standing in front of you, or how hard you breathed out.
## This is the smoke itself: a few hundred parcels of air, each with a
## position, a velocity, a size and a density, stepped every physics frame.
##
## - **Breath gives it momentum.** An exhale is a jet: parcels leave the mouth
##   at the speed of the breath and slow under drag until the air owns them.
## - **The world wind bends it.** Every parcel is dragged toward the local air
##   velocity (`wind` plus a little curl turbulence), so a plume leans downwind
##   and a strong wind lays it flat.
## - **It curls round bodies and walls.** Bodies are capsules handed in by the
##   owner (`set_obstacles`); a parcel heading into one loses the inward part of
##   its velocity and keeps the tangential part, so smoke parts round a person
##   and closes behind them. Walls are found with a few round-robin physics rays
##   a frame and slide the smoke along their face.
## - **It lingers and thins.** A parcel grows as it mixes and its density falls
##   with that growth and with age; buoyancy fades as it cools.
## - **Rings are vortex rings**: a hollow loop of parcels that keeps its speed
##   longer and widens as it travels.
##
## Rendered as one `MultiMeshInstance3D` (a single draw call) of soft camera-
## facing cards, each card a parcel. Every dial is a property, and the parcel
## cap scales with `WorldLook.quality`.

const SHADER := preload("res://shaders/smoke_parcel.gdshader")

## How each device's smoke reads, because a vape cloud and a cigarette wisp are
## different objects. `count` parcels per exhale, `speed` of the breath in m/s,
## `radius` at the mouth, `density` 0-1, `heat` is buoyancy, `life` seconds,
## `grow` m/s of mixing, `thin` per second, `tint` the colour of it.
const DEVICES := {
	"cigarette": {"count": 44, "speed": 1.5, "spread": 0.08, "radius": 0.026, "density": 0.55, "heat": 0.55,
		"life": 7.0, "grow": 0.09, "thin": 0.30, "tint": Color(0.70, 0.72, 0.74)},
	"joint": {"count": 56, "speed": 1.3, "spread": 0.1, "radius": 0.032, "density": 0.65, "heat": 0.45,
		"life": 9.0, "grow": 0.10, "thin": 0.24, "tint": Color(0.70, 0.74, 0.66)},
	"spliff": {"count": 50, "speed": 1.35, "spread": 0.09, "radius": 0.03, "density": 0.6, "heat": 0.5,
		"life": 8.0, "grow": 0.095, "thin": 0.27, "tint": Color(0.70, 0.73, 0.68)},
	# Vapour, not smoke: dense, white, a big soft cloud that sinks a little and
	# is gone far faster than smoke is.
	"vape": {"count": 84, "speed": 1.7, "spread": 0.22, "radius": 0.06, "density": 0.85, "heat": -0.08,
		"life": 4.5, "grow": 0.22, "thin": 0.55, "tint": Color(0.92, 0.93, 0.95)},
	# The bong is the one that empties a whole chest: slow, enormous, long.
	"bong": {"count": 100, "speed": 1.0, "spread": 0.16, "radius": 0.07, "density": 0.8, "heat": 0.35,
		"life": 12.0, "grow": 0.12, "thin": 0.16, "tint": Color(0.72, 0.75, 0.68)},
}
## The thin stream that rises off a lit end you are not drawing on.
## How long one breath takes to leave the mouth.
const EXHALE_SECONDS := 0.8
const SIDESTREAM := {"radius": 0.012, "density": 0.35, "heat": 0.9, "life": 5.0, "grow": 0.05, "thin": 0.35}

## The air, in m/s. The owner writes this from the weather.
var wind := Vector3.ZERO
## Curl turbulence strength, m/s.
@export var turbulence := 0.18
## How quickly a parcel takes on the air's velocity, per second. Low numbers
## let a breath carry; high numbers hand it straight to the wind.
@export var air_coupling := 1.6
## Buoyant lift per unit of heat, m/s^2.
@export var buoyancy := 0.55
## Seconds for buoyancy to halve as the smoke cools.
@export var cooling := 2.5
## Wall probes per physics frame. 0 turns wall collision off.
@export var wall_rays := 12
## The parcel cap. `0` means "from WorldLook.quality".
@export var max_parcels := 0

var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _radius := PackedFloat32Array()
var _density := PackedFloat32Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _heat := PackedFloat32Array()
var _grow := PackedFloat32Array()
var _thin := PackedFloat32Array()
var _ring := PackedFloat32Array() # 0 for a free parcel, the ring's spin speed for a ring parcel
var _tint := PackedColorArray()
## Breaths still leaving the mouth.
var _streams: Array[Dictionary] = []
## Each obstacle: {"a": Vector3, "b": Vector3, "r": float} (a capsule a-b).
var _obstacles: Array[Dictionary] = []
var _ray_cursor := 0
var _time := 0.0
var _multimesh: MultiMesh
var _view: MultiMeshInstance3D
var _exclude: Array[RID] = []


func _ready() -> void:
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_multimesh.mesh = quad
	_multimesh.instance_count = cap()
	_multimesh.visible_instance_count = 0
	_view = MultiMeshInstance3D.new()
	_view.name = "Parcels"
	_view.multimesh = _multimesh
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("noise_texture", _grain())
	_view.material_override = material
	_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_view.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# Parcels are written in world space, so the view sits at the origin.
	_view.top_level = true
	_view.custom_aabb = AABB(Vector3(-200, -50, -200), Vector3(400, 150, 400))
	add_child(_view)


## The grain that frays each card into wisps. Seamless, so it can scroll.
static func _grain() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.035
	noise.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.seamless = true
	texture.width = 128
	texture.height = 128
	texture.generate_mipmaps = true
	return texture


func cap() -> int:
	if max_parcels > 0:
		return max_parcels
	match WorldLook.quality:
		WorldLook.Quality.ULTRA: return 480
		WorldLook.Quality.HIGH: return 360
		_: return 220


func count() -> int:
	return _pos.size()


## Bodies the smoke has to go round. Capsules, refreshed by the owner as often
## as the bodies move (the lab does it every frame for the few it has).
func set_obstacles(capsules: Array[Dictionary]) -> void:
	_obstacles = capsules


## Physics bodies the wall rays should ignore (the smoker's own capsule).
func set_ray_exclusions(rids: Array[RID]) -> void:
	_exclude = rids


## One exhale. `breath` scales the jet (a clean draw is about 1, a big harsh
## one up to 1.6); `volume` scales how much smoke there is (the held draw).
## A breath is a stream, not a burst: the parcels leave the mouth over
## `EXHALE_SECONDS`, fast at first and slower as the breath runs out, so the
## wind bends the stream into a curve instead of pushing one blob sideways.
## Returns how many parcels the breath will carry.
func exhale(device_id: String, mouth: Vector3, direction: Vector3, breath := 1.0, volume := 1.0) -> int:
	var spec: Dictionary = DEVICES.get(device_id, DEVICES["cigarette"])
	var forward := direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD
	var n := roundi(float(spec.count) * clampf(volume, 0.2, 2.0))
	_streams.append({"spec": spec, "mouth": mouth, "forward": forward, "breath": breath,
		"volume": volume, "total": n, "emitted": 0, "elapsed": 0.0})
	return n


func _emit_streams(delta: float) -> void:
	for index in range(_streams.size() - 1, -1, -1):
		var stream: Dictionary = _streams[index]
		stream.elapsed = float(stream.elapsed) + delta
		var spec: Dictionary = stream.spec
		var total := int(stream.total)
		var due := mini(total, ceili(float(total) * clampf(float(stream.elapsed) / EXHALE_SECONDS, 0.0, 1.0)))
		var forward: Vector3 = stream.forward
		while int(stream.emitted) < due:
			var t := float(stream.emitted) / maxf(float(total - 1), 1.0)
			var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * float(spec.spread)
			var speed := float(spec.speed) * float(stream.breath) * lerpf(1.0, 0.3, t)
			var velocity := (forward + jitter).normalized() * speed
			_spawn(stream.mouth, velocity, float(spec.radius) * lerpf(0.8, 1.3, t),
				float(spec.density) * clampf(float(stream.volume), 0.3, 1.3), float(spec.heat), float(spec.life) * randf_range(0.8, 1.1),
				float(spec.grow), float(spec.thin), spec.tint, 0.0)
			stream.emitted = int(stream.emitted) + 1
		if int(stream.emitted) >= total:
			_streams.remove_at(index)


## A smoke ring: a hollow loop of parcels with a shared forward speed. It keeps
## that speed far longer than a free parcel (`_ring` lowers its drag) and its
## loop widens as it goes.
func ring(device_id: String, mouth: Vector3, direction: Vector3, breath := 1.0) -> int:
	var spec: Dictionary = DEVICES.get(device_id, DEVICES["cigarette"])
	var forward := direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD
	var side := forward.cross(Vector3.UP)
	if side.length_squared() < 0.001:
		side = forward.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(forward).normalized()
	var n := 22
	var made := 0
	for index in n:
		var angle := TAU * float(index) / float(n)
		var offset := (side * cos(angle) + up * sin(angle)) * 0.035
		var velocity := forward * 0.9 * breath + offset.normalized() * 0.05
		made += _spawn(mouth + offset, velocity, 0.018, float(spec.density) * 0.9, 0.15, 4.0,
			0.025, 0.22, spec.tint, 1.0)
	return made


## The thin wisp that rises off a lit end at rest.
func sidestream(at: Vector3, tint := Color(0.62, 0.66, 0.74)) -> void:
	_spawn(at, Vector3.UP * 0.12, float(SIDESTREAM.radius), float(SIDESTREAM.density), float(SIDESTREAM.heat),
		float(SIDESTREAM.life), float(SIDESTREAM.grow), float(SIDESTREAM.thin), tint, 0.0)


## One free parcel with the caller's own numbers (imp-63: a blast's smoke
## column and a break's material dust, which are not breaths).
func billow(at: Vector3, velocity: Vector3, radius: float, density: float, heat: float, life: float,
		grow: float, thin: float, tint: Color) -> int:
	return _spawn(at, velocity, radius, density, heat, life, grow, thin, tint, 0.0)


func _spawn(at: Vector3, velocity: Vector3, radius: float, density: float, heat: float, life: float,
		grow: float, thin: float, tint: Color, ring_flag: float) -> int:
	if _pos.size() >= cap():
		# Full: the oldest, thinnest smoke makes room. It is the least visible.
		_remove(0)
	_pos.append(at)
	_vel.append(velocity)
	_radius.append(radius)
	_density.append(clampf(density, 0.0, 1.0))
	_age.append(0.0)
	_life.append(life)
	_heat.append(heat)
	_grow.append(grow)
	_thin.append(thin)
	_ring.append(ring_flag)
	_tint.append(tint)
	return 1


func _remove(index: int) -> void:
	_pos.remove_at(index)
	_vel.remove_at(index)
	_radius.remove_at(index)
	_density.remove_at(index)
	_age.remove_at(index)
	_life.remove_at(index)
	_heat.remove_at(index)
	_grow.remove_at(index)
	_thin.remove_at(index)
	_ring.remove_at(index)
	_tint.remove_at(index)


## The air's own velocity at a point: the wind plus a divergence-free swirl
## (the curl of a few sines), so it stirs without piling smoke up anywhere.
func air_at(at: Vector3) -> Vector3:
	var t := _time * 0.6
	var curl := Vector3(
		sin(at.y * 2.1 + t) - cos(at.z * 1.7 - t * 0.8),
		sin(at.z * 1.9 + t * 1.1) - cos(at.x * 2.3 + t * 0.7),
		sin(at.x * 1.6 - t * 0.9) - cos(at.y * 2.2 + t),
	)
	return wind + curl * turbulence * 0.5


## Smoke is slow: stepping it thirty times a second looks the same as sixty
## and costs half. The cards are still drawn every frame.
const STEP_SECONDS := 1.0 / 30.0
var _step_accumulator := 0.0


func _physics_process(delta: float) -> void:
	_step_accumulator += delta
	if _step_accumulator >= STEP_SECONDS:
		step(_step_accumulator)
		_step_accumulator = 0.0
	# Drawn every physics frame, carried along its velocity since the last
	# step, so a fast jet does not hop.
	_draw_parcels(_step_accumulator)


## One simulation step. Public so a test can run the smoke without a frame.
func step(delta: float) -> void:
	if delta <= 0.0:
		return
	_time += delta
	_emit_streams(delta)
	var index := _pos.size() - 1
	while index >= 0:
		_age[index] += delta
		if _age[index] >= _life[index] or _density[index] < 0.01:
			_remove(index)
			index -= 1
			continue
		var p := _pos[index]
		var v := _vel[index]
		var ring_flag := _ring[index]
		# Momentum against the air: a fresh jet holds its own, then the air wins.
		var coupling := air_coupling * (0.25 if ring_flag > 0.0 else 1.0)
		var air := air_at(p)
		v += (air - v) * (1.0 - exp(-coupling * delta))
		# Warm smoke rises and cools.
		v.y += buoyancy * _heat[index] * pow(0.5, _age[index] / cooling) * delta
		v = _round_obstacles(p, v, _radius[index])
		p += v * delta
		_pos[index] = p
		_vel[index] = v
		# Mixing: it grows, and the same smoke over a bigger volume is thinner.
		var before := _radius[index]
		var grow := _grow[index] / (1.0 + _age[index] * 0.6)
		_radius[index] = before + grow * delta
		_density[index] *= exp(-_thin[index] * delta) * pow(before / _radius[index], 1.2)
		index -= 1
	_probe_walls(delta)


## A parcel heading into a body loses the part of its velocity that points in
## and keeps the part that slides round; one already inside is pushed to the
## surface. Starting the turn a body-width early is what makes it curl rather
## than bounce.
func _round_obstacles(p: Vector3, v: Vector3, radius: float) -> Vector3:
	for obstacle in _obstacles:
		var a: Vector3 = obstacle.a
		var b: Vector3 = obstacle.b
		var r := float(obstacle.r)
		var axis := b - a
		var along := clampf((p - a).dot(axis) / maxf(axis.length_squared(), 0.0001), 0.0, 1.0)
		var nearest := a + axis * along
		var away := p - nearest
		var distance := away.length()
		var reach := r + radius * 0.5
		if distance > reach * 2.2 or distance < 0.0001:
			continue
		var normal := away / distance
		var inward := v.dot(normal)
		if inward < 0.0:
			var influence := 1.0 - smoothstep(reach, reach * 2.2, distance)
			v -= normal * inward * influence
			# A little of what was lost goes round, so it wraps instead of stopping.
			var tangent := (v - normal * v.dot(normal))
			if tangent.length_squared() > 0.0001:
				v += tangent.normalized() * (-inward) * influence * 0.35
		if distance < reach:
			v += normal * (reach - distance) * 8.0
	return v


## Round-robin wall probes: a few parcels a frame cast along their motion; a
## hit takes the into-wall velocity away and moves the parcel to the face.
func _probe_walls(delta: float) -> void:
	if wall_rays <= 0 or _pos.is_empty() or not is_inside_tree():
		return
	var world := get_world_3d()
	if world == null:
		return
	var space := world.direct_space_state
	var n := mini(wall_rays, _pos.size())
	for i in n:
		_ray_cursor = (_ray_cursor + 1) % _pos.size()
		var k := _ray_cursor
		var p := _pos[k]
		var v := _vel[k]
		var reach := v * maxf(delta * 4.0, 0.06) + v.normalized() * _radius[k] * 0.5
		if reach.length_squared() < 0.000001:
			continue
		var query := PhysicsRayQueryParameters3D.create(p, p + reach)
		query.exclude = _exclude
		query.collide_with_areas = false
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var normal: Vector3 = hit.normal
		var into := v.dot(normal)
		if into < 0.0:
			v -= normal * into * 1.05
		_vel[k] = v
		_pos[k] = (hit.position as Vector3) + normal * _radius[k] * 0.4


## One buffer upload rather than three server calls a parcel: 12 floats of
## transform, 4 of colour, 4 of custom data, per instance.
var _buffer := PackedFloat32Array()


func _draw_parcels(ahead := 0.0) -> void:
	var n := _pos.size()
	var total := cap()
	if _multimesh.instance_count != total:
		_multimesh.instance_count = total
	if _buffer.size() != total * 20:
		_buffer.resize(total * 20)
	for index in n:
		var size := _radius[index] * 2.6
		var p := _pos[index] + _vel[index] * ahead
		var tint := _tint[index]
		var k := index * 20
		_buffer[k] = size
		_buffer[k + 1] = 0.0
		_buffer[k + 2] = 0.0
		_buffer[k + 3] = p.x
		_buffer[k + 4] = 0.0
		_buffer[k + 5] = size
		_buffer[k + 6] = 0.0
		_buffer[k + 7] = p.y
		_buffer[k + 8] = 0.0
		_buffer[k + 9] = 0.0
		_buffer[k + 10] = size
		_buffer[k + 11] = p.z
		_buffer[k + 12] = tint.r
		_buffer[k + 13] = tint.g
		_buffer[k + 14] = tint.b
		_buffer[k + 15] = _density[index]
		_buffer[k + 16] = fmod(float(index) * 0.618, 1.0)
		_buffer[k + 17] = _age[index] / maxf(_life[index], 0.01)
		_buffer[k + 18] = 0.0
		_buffer[k + 19] = 0.0
	_multimesh.buffer = _buffer
	_multimesh.visible_instance_count = n


## --- readouts for tests and the HUD -----------------------------------------

func centroid() -> Vector3:
	if _pos.is_empty():
		return Vector3.ZERO
	var sum := Vector3.ZERO
	for p in _pos:
		sum += p
	return sum / float(_pos.size())


func total_density() -> float:
	var sum := 0.0
	for d in _density:
		sum += d
	return sum


func mean_radius() -> float:
	if _radius.is_empty():
		return 0.0
	var sum := 0.0
	for r in _radius:
		sum += r
	return sum / float(_radius.size())


## The deepest any parcel sits inside an obstacle, in metres (0 = none inside).
func deepest_inside() -> float:
	var worst := 0.0
	for p in _pos:
		for obstacle in _obstacles:
			var a: Vector3 = obstacle.a
			var axis: Vector3 = (obstacle.b as Vector3) - a
			var along := clampf((p - a).dot(axis) / maxf(axis.length_squared(), 0.0001), 0.0, 1.0)
			worst = maxf(worst, float(obstacle.r) - p.distance_to(a + axis * along))
	return worst


func positions() -> PackedVector3Array:
	return _pos


func clear() -> void:
	_streams.clear()
	# Packed arrays are values: each one is cleared by name, not through a list.
	_pos.clear()
	_vel.clear()
	_radius.clear()
	_density.clear()
	_age.clear()
	_life.clear()
	_heat.clear()
	_grow.clear()
	_thin.clear()
	_ring.clear()
	_tint.clear()
