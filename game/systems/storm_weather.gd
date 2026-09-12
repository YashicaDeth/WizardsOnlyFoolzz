class_name StormWeather
extends Node3D

## AS4. Storms are a readout of how much magick is loose, not ambience.
## Severity tracks `WorldHistory.chaos_magick()` (AS4.2) — nothing here
## invents its own number. Rain and lightning intensity follow that one
## value; the anvil crawler (AS4.3) and red lightning (AS4.4) are what a real
## storm built from it actually looks like, not a separate system laid on top.

const ANVIL_CRAWLER_SHADER := preload("res://shaders/anvil_crawler.gdshader")

## Below this, chaos-magick is background noise — not enough is loose for the
## world to answer with weather at all.
const SEVERITY_FLOOR := 0.08
## AS4.5. Only a real storm costs the player anything; a light drizzle should
## not tax someone for existing outdoors.
const EXPOSURE_SEVERITY_THRESHOLD := 0.45
const EXPOSURE_PER_SECOND := 6.0
## How long a strike's crawl takes to cross the sky.
const CRAWL_DURATION := 0.6

var _rain: GPUParticles3D
var _rain_process_material: ParticleProcessMaterial
var _crawler: MeshInstance3D
var _crawler_material: ShaderMaterial
var _flash_light: OmniLight3D
var _strike_clock := 0.0
var _next_strike := 2.0
var _strike_elapsed := -1.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_build_rain()
	_build_crawler()
	_build_flash_light()
	set_process(true)


## AS4.2. The one number everything else here answers to. Never authored,
## never touched directly — only ever a read of the level WorldHistory is
## already keeping.
func severity() -> float:
	var level := WorldHistory.chaos_magick()
	if level < SEVERITY_FLOOR:
		return 0.0
	return clampf(inverse_lerp(SEVERITY_FLOOR, 1.0, level), 0.0, 1.0)


## Rain and the crawler both have to travel with the player across a world
## this large rather than sitting rooted at the origin. Called by whoever
## owns the world, every frame.
func follow(target_position: Vector3) -> void:
	position = Vector3(target_position.x, position.y, target_position.z)


func _process(delta: float) -> void:
	var storm := severity()
	_rain.emitting = storm > 0.02
	_rain.amount_ratio = clampf(storm * 1.3, 0.0, 1.0)
	if _rain_process_material != null:
		_rain_process_material.initial_velocity_min = 10.0 + storm * 8.0
		_rain_process_material.initial_velocity_max = 14.0 + storm * 10.0

	_strike_clock += delta
	if storm > 0.15 and _strike_clock >= _next_strike:
		_strike(storm)
		_strike_clock = 0.0
		# More severe, more often — a storm chart's own rhythm rather than a
		# fixed metronome.
		_next_strike = _rng.randf_range(2.0, 9.0) / maxf(storm, 0.1)

	if _strike_elapsed >= 0.0:
		_strike_elapsed += delta
		var front := clampf(_strike_elapsed / CRAWL_DURATION, 0.0, 1.0)
		_crawler_material.set_shader_parameter("front", front)
		var fade := clampf(1.0 - _strike_elapsed / (CRAWL_DURATION * 2.2), 0.0, 1.0)
		_crawler_material.set_shader_parameter("intensity", fade)
		if fade <= 0.0:
			_strike_elapsed = -1.0
	# Kept outside the block above and run every frame regardless: gating it
	# on `_strike_elapsed` meant the flash could finish the crawl's own fade
	# and freeze at whatever value it held at that instant, never actually
	# reaching zero until another strike came along to reset it.
	_flash_light.light_energy = move_toward(_flash_light.light_energy, 0.0, delta * (_flash_light.light_energy + 4.0))


func _strike(storm: float) -> void:
	# AS4.4. Red lightning means something: it stays rare, and only becomes
	# less rare once the storm is close to the worst it gets.
	var red := _rng.randf() < clampf((storm - 0.7) * 0.6, 0.0, 0.35)
	_flash_light.light_energy = 8.0 + storm * 6.0
	_flash_light.light_color = Color("d8324a") if red else Color("dce6ff")
	_crawler_material.set_shader_parameter("seed_value", _rng.randf() * 1000.0)
	_crawler_material.set_shader_parameter("red", red)
	_crawler_material.set_shader_parameter("front", 0.0)
	_crawler_material.set_shader_parameter("intensity", 1.0)
	_strike_elapsed = 0.0


## AS4.5. Zero below a real storm; a per-second drain above it. What that
## drain actually costs the player is left to whoever calls this — this file
## only knows how bad the storm is, not what stat should pay for it.
func exposure_cost(delta: float) -> float:
	var storm := severity()
	if storm < EXPOSURE_SEVERITY_THRESHOLD:
		return 0.0
	return EXPOSURE_PER_SECOND * inverse_lerp(EXPOSURE_SEVERITY_THRESHOLD, 1.0, storm) * delta


func _build_rain() -> void:
	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.amount = 800
	_rain.lifetime = 1.6
	_rain.position = Vector3(0, 22, 0)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.02, 0.5)
	var mesh_material := StandardMaterial3D.new()
	mesh_material.albedo_color = Color(0.72, 0.78, 0.82, 0.35)
	mesh_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = mesh_material
	_rain.draw_pass_1 = mesh
	_rain_process_material = ParticleProcessMaterial.new()
	_rain_process_material.direction = Vector3(0, -1, 0)
	_rain_process_material.spread = 4.0
	_rain_process_material.initial_velocity_min = 10.0
	_rain_process_material.initial_velocity_max = 14.0
	_rain_process_material.gravity = Vector3(0, -2.0, 0)
	_rain_process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_rain_process_material.emission_box_extents = Vector3(40, 1, 40)
	_rain.process_material = _rain_process_material
	_rain.emitting = false
	add_child(_rain)


func _build_crawler() -> void:
	_crawler = MeshInstance3D.new()
	_crawler.name = "AnvilCrawler"
	var mesh := QuadMesh.new()
	# Large and far out along the horizon rather than a ceiling directly
	# overhead — "the underside of a storm" only reads if a player looking
	# roughly level with the ground can actually see it, and a quad flat above
	# the camera is only ever in frame if they look straight up.
	mesh.size = Vector2(320, 170)
	_crawler.mesh = mesh
	_crawler.position = Vector3(0, 70, -230)
	_crawler_material = ShaderMaterial.new()
	_crawler_material.shader = ANVIL_CRAWLER_SHADER
	_crawler.material_override = _crawler_material
	_crawler.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_crawler)


func _build_flash_light() -> void:
	_flash_light = OmniLight3D.new()
	_flash_light.name = "LightningFlash"
	_flash_light.position = Vector3(0, 40, 0)
	_flash_light.omni_range = 140.0
	_flash_light.light_energy = 0.0
	add_child(_flash_light)
