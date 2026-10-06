class_name BlastFx
extends Node3D

## imp-63. What a blast and a break look like (Greg, 5 Oct ~19:00: "Improve and
## refine destruction: smoke, sparks, dust, ground texture, check it on the
## GPU"). `Blast` and `VoxelStructure` decide what breaks; this only shows it.
##
## - **Shock flash**: a white-hot fireball card gone in a fraction of a second,
##   a pale shock ring racing out over the ground, and the light.
## - **Smoke**: a dark column through drug-70's `SmokeVolume` (the same parcels
##   the cigarettes use), so it rises, leans with the wind and slides along walls.
## - **Material dust**: every break (a round as well as a charge) puffs dust of
##   what broke into the same volume. Concrete and drywall throw a heavy pale
##   cloud that hangs low; brick a red-brown one; wood little; steel none.
## - **Sparks**: hot streaks with gravity, from the blast and from steel.
## - **Lasting marks**: a scorch and a dust coat on the floor under a blast
##   (decals, capped). Voxel walls carry their own soot (`VoxelStructure.soot`).
## - **Debris by material** (`DEBRIS`): `VoxelStructure.spawn_cube` reads the
##   shape: brick chunks, concrete grit, wood splinters, steel shards.
##
## One per scene (`of`), made on first use. Every dial is below.

const FLASH_SHADER := preload("res://shaders/blast_flash.gdshader")
const GROUP := "blast_fx"

## How each material breaks. `shape`: the debris piece (`piece_size`). `pieces`
## scales `VoxelStructure.CUBES_PER_HIT`. `dust`: the colour of its dust and
## `dust_n` parcels per removed cell (0 = none). `sparks` per break. `metal`
## pieces are shiny. Materials not in `MaterialToughness` (clay, rock) are
## spoil colours for `DigTerrain`.
const DEBRIS := {
	"brick": {"shape": "chunk", "pieces": 1.0, "dust": Color("8e5a46"), "dust_n": 0.12, "sparks": 0},
	"concrete": {"shape": "grit", "pieces": 0.7, "dust": Color("a9a59c"), "dust_n": 0.3, "sparks": 0},
	"bunker": {"shape": "grit", "pieces": 0.6, "dust": Color("8d8e86"), "dust_n": 0.3, "sparks": 3},
	"sealed": {"shape": "grit", "pieces": 0.5, "dust": Color("5a5860"), "dust_n": 0.2, "sparks": 6},
	"drywall": {"shape": "flake", "pieces": 0.8, "dust": Color("d6d0c2"), "dust_n": 0.4, "sparks": 0},
	"wood": {"shape": "splinter", "pieces": 1.3, "dust": Color("7a5c3e"), "dust_n": 0.04, "sparks": 0},
	"steel_sheet": {"shape": "shard", "pieces": 1.0, "dust": Color(), "dust_n": 0.0, "sparks": 14, "metal": true},
	"vault": {"shape": "shard", "pieces": 0.8, "dust": Color(), "dust_n": 0.0, "sparks": 10, "metal": true},
	"glass": {"shape": "shard", "pieces": 1.2, "dust": Color(), "dust_n": 0.0, "sparks": 0},
	"dirt": {"shape": "clod", "pieces": 1.0, "dust": Color("6e5c48"), "dust_n": 0.06, "sparks": 0},
	"topsoil": {"shape": "clod", "pieces": 1.0, "colour": Color("4a3a2c"), "dust": Color("3e3328"), "dust_n": 0.03, "sparks": 0},
	"clay": {"shape": "clod", "pieces": 1.0, "colour": Color("6e4630"), "dust": Color("4e3a2a"), "dust_n": 0.02, "sparks": 0},
	"rock": {"shape": "grit", "pieces": 1.0, "colour": Color("5e5a54"), "dust": Color("4e4c48"), "dust_n": 0.06, "sparks": 2},
}

## Dials (defaults; REMASTER_LOG.md lists them for Greg).
static var enabled := true
## Smoke parcels a blast throws at damage 520 (a charge); scales with damage.
static var smoke_parcels := 64
## Dust parcels any one break may add.
static var dust_cap := 40
## Sparks a blast throws.
static var blast_sparks := 70
## Scorch/dust decals kept on the floor; the oldest goes.
static var decal_budget := 24
## The scorch's width as a multiple of the blast radius.
static var scorch_scale := 3.2
## Blast smoke's opacity (the cigarette smoke's own is 0.42).
static var smoke_opacity := 0.8
## Seconds the fireball and the shock ring last.
const FLASH_LIFE := 0.16
const RING_LIFE := 0.45
const MAX_SPARKS := 260
const SMOKE_TINT := Color(0.16, 0.145, 0.13)
const SPARK_HOT := Color(1.0, 0.85, 0.5)
const SPARK_EMBER := Color(1.0, 0.32, 0.05)

static var _current: BlastFx
static var _scorch_texture: ImageTexture
static var _dust_texture: ImageTexture
static var _piece_looks: Dictionary = {}
static var _unit_box: BoxMesh

var smoke: SmokeVolume
var blasts := 0
var _sparks: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _decals: Array[Decal] = []
var _spark_mesh := ImmediateMesh.new()
var _spark_view: MeshInstance3D


## The scene's BlastFx, made on first use under the current scene.
static func of(host: Node) -> BlastFx:
	if is_instance_valid(_current) and _current.is_inside_tree() and not _current.is_queued_for_deletion():
		return _current
	if host == null or not host.is_inside_tree():
		return null
	var tree := host.get_tree()
	var found := tree.get_first_node_in_group(GROUP) as BlastFx
	if found == null:
		found = BlastFx.new()
		var scene := tree.current_scene
		(scene if scene != null else tree.root).add_child(found)
	_current = found
	return found


## For a test or scene swap that tears down before quitting.
static func release() -> void:
	_current = null
	_scorch_texture = null
	_dust_texture = null
	_piece_looks.clear()
	_unit_box = null


func _ready() -> void:
	name = "BlastFx"
	add_to_group(GROUP)
	top_level = true
	smoke = SmokeVolume.new()
	smoke.name = "BlastSmoke"
	# Blast smoke is heavier than breath: it holds its own push a little longer.
	smoke.air_coupling = 1.1
	smoke.turbulence = 0.35
	add_child(smoke)
	var parcels := smoke.get_node_or_null("Parcels") as MultiMeshInstance3D
	if parcels != null:
		(parcels.material_override as ShaderMaterial).set_shader_parameter("opacity", smoke_opacity)
	_spark_view = MeshInstance3D.new()
	_spark_view.name = "Sparks"
	_spark_view.mesh = _spark_mesh
	_spark_view.top_level = true
	_spark_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var hot := StandardMaterial3D.new()
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hot.vertex_color_use_as_albedo = true
	hot.cull_mode = BaseMaterial3D.CULL_DISABLED
	hot.no_depth_test = false
	hot.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_spark_view.material_override = hot
	add_child(_spark_view)
	# The decal textures are drawn in script (~30 ms); not on a blast's frame.
	_warm.call_deferred()


## Everything a first blast would build or compile for the first time, done
## once far below the world: the decal textures, a fireball, a ring, a light,
## a decal and every material's piece look.
func _warm() -> void:
	_scorch()
	_dust()
	unit_box()
	for material in DEBRIS:
		piece_look(material)
	var away := Vector3(0, -500, 0)
	var staged: Array[Node3D] = [_flash_card(false), _flash_card(true), _decal("Warm", _scorch(), away, 0.5, Color(1, 1, 1, 0))]
	var light := OmniLight3D.new()
	light.light_energy = 0.0
	add_child(light)
	staged.append(light)
	for node in staged:
		node.global_position = away
	await get_tree().process_frame
	await get_tree().process_frame
	for node in staged:
		node.queue_free()


## The whole blast. `normal` is the face the charge sat on (UP for one on the
## ground or thrown). `material` is what it mostly broke ("" when nothing).
func blast(at: Vector3, radius: float, damage: float, normal := Vector3.UP, material := "") -> void:
	if not enabled:
		return
	blasts += 1
	var strength := clampf(damage / 520.0, 0.3, 1.5)
	var out := normal.normalized() if normal.length_squared() > 0.001 else Vector3.UP
	_fireball(at + out * 0.15, radius * (1.4 + strength))
	# Probe a little out of the face, so a charge on a wall marks the floor at
	# its foot and not the sill of the hole it just made.
	var floor_hit := _floor_below(at + Vector3(out.x, 0.0, out.z) * radius * 0.6, radius * 2.5)
	if not floor_hit.is_empty():
		_ring(floor_hit.position + Vector3.UP * 0.03, radius * 4.0)
		_marks(floor_hit.position, radius, material)
	# The column: dark smoke thrown out of the face and up, then rising.
	var n := roundi(smoke_parcels * strength)
	for i in n:
		var spray := (out * 1.4 + _jitter() * 1.2 + Vector3.UP * randf_range(0.2, 1.4)).normalized()
		var speed := randf_range(1.0, 4.5) * strength
		var shade := SMOKE_TINT.lerp(Color(0.32, 0.29, 0.26), randf() * 0.5)
		smoke.billow(at + out * 0.3 + _jitter() * radius * 0.4, spray * speed, radius * randf_range(0.24, 0.44),
			randf_range(0.7, 1.0), randf_range(0.8, 1.6), randf_range(6.0, 10.0), 0.35, 0.09, shade)
	var spark_count := roundi(blast_sparks * strength)
	for i in spark_count:
		var dir := (out + _jitter() * 1.3 + Vector3.UP * 0.4).normalized()
		_spark(at, dir * randf_range(4.0, 14.0), randf_range(0.35, 1.1))


## A break's dust and sparks: `removed` cells of `material` came out at `at`.
func break_dust(at: Vector3, material: String, removed: int, push := Vector3.ZERO) -> void:
	if not enabled or removed <= 0:
		return
	var spec: Dictionary = DEBRIS.get(material, {})
	var dust_n := float(spec.get("dust_n", 0.0))
	if dust_n > 0.0:
		var tint: Color = spec.dust
		var count := mini(maxi(1, roundi(float(removed) * dust_n)), dust_cap)
		var heavy := removed > 30
		for i in count:
			var v := push.normalized() * randf_range(0.3, 1.6) + _jitter() * randf_range(0.4, 1.8) + Vector3.UP * randf_range(0.0, 0.6)
			var shade := tint * randf_range(0.85, 1.1)
			shade.a = 1.0
			# Dust is heavy: no heat, so it hangs and settles instead of rising.
			smoke.billow(at + _jitter() * (0.35 if heavy else 0.08), v, randf_range(0.07, 0.14) * (2.2 if heavy else 1.0),
				randf_range(0.55, 0.9), randf_range(-0.25, 0.05), randf_range(3.5, 7.0), 0.22 if heavy else 0.12, 0.16, shade)
	var sparks := int(spec.get("sparks", 0))
	for i in mini(sparks * maxi(1, removed / 6), 40):
		_spark(at, (push.normalized() * 2.0 + _jitter() * 1.6 + Vector3.UP * 0.6).normalized() * randf_range(2.5, 8.0), randf_range(0.2, 0.6))


## The piece a break throws for `material`, in units of the voxel edge.
static func piece_size(material: String, edge: float) -> Vector3:
	match str((DEBRIS.get(material, {}) as Dictionary).get("shape", "chunk")):
		"chunk":
			# Half-bricks: long, flat, squarish ends.
			return Vector3(randf_range(0.8, 1.1), randf_range(0.42, 0.6), randf_range(0.5, 0.7)) * edge
		"grit":
			return Vector3(randf_range(0.35, 0.7), randf_range(0.3, 0.6), randf_range(0.35, 0.7)) * edge
		"splinter":
			return Vector3(randf_range(0.12, 0.2), randf_range(0.12, 0.2), randf_range(1.0, 2.0)) * edge
		"shard":
			return Vector3(randf_range(0.7, 1.2), 0.07, randf_range(0.4, 0.9)) * edge
		"flake":
			return Vector3(randf_range(0.6, 1.0), 0.12, randf_range(0.6, 1.0)) * edge
		"clod":
			return Vector3.ONE * randf_range(0.45, 0.85) * edge
	return Vector3.ONE * edge


## How many of a hit's removed cells of `material` fly as pieces.
static func pieces_of(material: String, per_hit: int) -> int:
	return roundi(float(per_hit) * float((DEBRIS.get(material, {}) as Dictionary).get("pieces", 1.0)))


static func colour_of(material: String) -> Color:
	var spec: Dictionary = DEBRIS.get(material, {})
	if spec.has("colour"):
		return spec.colour
	return (MaterialToughness.MATERIALS.get(material, MaterialToughness.MATERIALS.dirt) as Dictionary).colour


## One shared look per material, so a hundred pieces are a handful of materials.
static func piece_look(material: String) -> StandardMaterial3D:
	if not _piece_looks.has(material):
		var look := StandardMaterial3D.new()
		look.albedo_color = colour_of(material)
		look.roughness = 0.9
		var spec: Dictionary = DEBRIS.get(material, {})
		if bool(spec.get("metal", false)):
			look.metallic = 0.85
			look.roughness = 0.38
		elif material == "glass":
			look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			look.albedo_color.a = 0.45
			look.roughness = 0.1
		_piece_looks[material] = look
	return _piece_looks[material]


static func unit_box() -> BoxMesh:
	if _unit_box == null:
		_unit_box = BoxMesh.new()
	return _unit_box


func spark_count() -> int:
	return _sparks.size()


func decal_count() -> int:
	return _decals.size()


func _jitter() -> Vector3:
	return Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))


func _spark(at: Vector3, velocity: Vector3, life: float) -> void:
	if _sparks.size() >= MAX_SPARKS:
		_sparks.pop_front()
	_sparks.append({"p": at, "v": velocity, "age": 0.0, "life": life})


func _fireball(at: Vector3, size: float) -> void:
	var card := _flash_card(false)
	card.global_position = at
	var light := OmniLight3D.new()
	light.light_color = Color("ffb36a")
	light.light_energy = 14.0
	light.omni_range = size * 4.0
	light.shadow_enabled = false
	add_child(light)
	light.global_position = at
	_flashes.append({"node": card, "age": 0.0, "life": FLASH_LIFE, "from": size * 0.35, "to": size, "light": light})


func _ring(at: Vector3, size: float) -> void:
	var card := _flash_card(true)
	card.global_position = at
	_flashes.append({"node": card, "age": 0.0, "life": RING_LIFE, "from": size * 0.2, "to": size})


func _flash_card(ring: bool) -> MeshInstance3D:
	var card := MeshInstance3D.new()
	var quad := QuadMesh.new()
	if ring:
		quad.orientation = PlaneMesh.FACE_Y
	card.mesh = quad
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var look := ShaderMaterial.new()
	look.shader = FLASH_SHADER
	look.set_shader_parameter("ring", 1.0 if ring else 0.0)
	look.set_shader_parameter("seed", randf() * 50.0)
	card.material_override = look
	card.top_level = true
	add_child(card)
	return card


func _floor_below(at: Vector3, reach: float) -> Dictionary:
	if not is_inside_tree():
		return {}
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.2, at + Vector3.DOWN * reach, 1)
	return get_world_3d().direct_space_state.intersect_ray(query)


## A scorch and a coat of the material's dust on the floor. They stay.
func _marks(at: Vector3, radius: float, material: String) -> void:
	var width := radius * scorch_scale
	# The dust coat first and wide, the scorch over it.
	var tint: Color = (DEBRIS.get(material, {}) as Dictionary).get("dust", Color())
	if tint != Color():
		_keep(_decal("DustCoat", _dust(), at, width * 2.2, Color(tint.r, tint.g, tint.b, 0.5)))
	_keep(_decal("Scorch", _scorch(), at, width, Color(1, 1, 1, 1)))


func _decal(id: String, texture: Texture2D, at: Vector3, width: float, tint: Color) -> Decal:
	var decal := Decal.new()
	decal.name = id
	decal.texture_albedo = texture
	decal.size = Vector3(width, 1.2, width)
	decal.modulate = tint
	decal.upper_fade = 0.2
	decal.lower_fade = 0.2
	# Only what stands still takes it: debris and bodies are on other layers.
	decal.cull_mask = 1
	add_child(decal)
	decal.global_position = at
	decal.rotate_y(randf() * TAU)
	return decal


func _keep(decal: Decal) -> void:
	_decals.append(decal)
	while _decals.size() > decal_budget:
		var old: Decal = _decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()


func _process(delta: float) -> void:
	# The blast itself costs a long frame (the remesh); aging the flash by it
	# would skip the flash. It plays over at least a few drawn frames.
	var flash_step := minf(delta, 1.0 / 30.0)
	for index in range(_flashes.size() - 1, -1, -1):
		var flash: Dictionary = _flashes[index]
		flash.age = float(flash.age) + flash_step
		var light := flash.get("light") as OmniLight3D
		if is_instance_valid(light):
			# The light outlives the card a little and dies fast.
			var lit := clampf(float(flash.age) / 0.4, 0.0, 1.0)
			light.light_energy = 14.0 * pow(1.0 - lit, 3.0)
			if lit >= 1.0:
				light.queue_free()
		var node := flash.node as MeshInstance3D
		var t := clampf(float(flash.age) / float(flash.life), 0.0, 1.0)
		if t >= 1.0 or not is_instance_valid(node):
			if is_instance_valid(node):
				node.visible = false
			if not is_instance_valid(light) or light.is_queued_for_deletion():
				if is_instance_valid(node):
					node.queue_free()
				_flashes.remove_at(index)
			continue
		var grow := 1.0 - pow(1.0 - t, 3.0)
		node.scale = Vector3.ONE * lerpf(float(flash.from), float(flash.to), grow)
		(node.material_override as ShaderMaterial).set_shader_parameter("age", t)
	for index in range(_sparks.size() - 1, -1, -1):
		var spark: Dictionary = _sparks[index]
		spark.age = float(spark.age) + delta
		if float(spark.age) >= float(spark.life):
			_sparks.remove_at(index)
			continue
		var v: Vector3 = spark.v
		v += Vector3.DOWN * 9.8 * delta
		v *= exp(-1.2 * delta)
		spark.v = v
		spark.p = (spark.p as Vector3) + v * delta
	_draw_sparks()


func _draw_sparks() -> void:
	_spark_mesh.clear_surfaces()
	if _sparks.is_empty():
		return
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye := camera.global_position if camera != null else Vector3(0, 2, 5)
	_spark_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for spark in _sparks:
		var p: Vector3 = spark.p
		var v: Vector3 = spark.v
		var t := float(spark.age) / float(spark.life)
		var tail := p - v * 0.028
		var across := (p - tail).cross(eye - p).normalized() * 0.012
		var colour := SPARK_HOT.lerp(SPARK_EMBER, t) * (1.0 - t * t) * 3.0
		colour.a = 1.0
		_spark_mesh.surface_set_color(colour)
		_spark_mesh.surface_add_vertex(p + across)
		_spark_mesh.surface_add_vertex(p - across)
		_spark_mesh.surface_add_vertex(tail)
	_spark_mesh.surface_end()


## A soot splash: dense in the middle, ragged rays out, transparent edge.
static func _scorch() -> ImageTexture:
	if _scorch_texture == null:
		_scorch_texture = ImageTexture.create_from_image(_splat(Color(0.035, 0.03, 0.026), 0.95, 7.0, 0.55))
	return _scorch_texture


static func _dust() -> ImageTexture:
	if _dust_texture == null:
		_dust_texture = ImageTexture.create_from_image(_splat(Color(1, 1, 1), 0.55, 2.5, 0.25))
	return _dust_texture


static func _splat(colour: Color, density: float, rays: float, ray_weight: float) -> Image:
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = int(rays * 13.0)
	noise.frequency = 0.06
	noise.fractal_octaves = 4
	for y in size:
		for x in size:
			var c := (Vector2(x, y) / float(size - 1)) * 2.0 - Vector2.ONE
			var r := c.length()
			var spokes := 0.5 + 0.5 * sin(atan2(c.y, c.x) * rays + noise.get_noise_2d(x * 0.3, y * 0.3) * 4.0)
			var grain := 0.5 + 0.5 * noise.get_noise_2d(x, y)
			var reach := 0.55 + ray_weight * spokes * 0.45 + (grain - 0.5) * 0.25
			var alpha := (1.0 - smoothstep(reach * 0.35, reach, r)) * density * (0.65 + 0.35 * grain)
			image.set_pixel(x, y, Color(colour.r, colour.g, colour.b, clampf(alpha, 0.0, 1.0)))
	image.generate_mipmaps()
	return image
