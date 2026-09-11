class_name WorldLook
extends RefCounted

## One look system for every scene. Each scene previously built its own
## Environment with ad-hoc numbers, which is why the derby sat at 1.45 ambient
## with fog disabled while the Hunt Grounds sat at 0.7 with fog on: the same
## world rendered as two unrelated games. Scenes now take a tuned base and
## express their mood as a named preset, so a change to the house look reaches
## all of them.
##
## Art direction per ART-DIRECTION.md: sun-bleached copper and teal salvage,
## low saturation, heavy value separation, fog for depth, and deliberately
## authored technical limitations rather than clean photorealism.

const PRESETS := {
	"bone_yard": {
		"zenith": "241612", "horizon": "8a5230", "ground": "3a2317",
		"fog": "6b4429", "fog_density": 0.019, "volumetric": 0.018,
		"ambient": 0.38, "saturation": 0.82, "contrast": 1.14,
	},
	"ashbloom": {
		"zenith": "1b1d16", "horizon": "6d6b3e", "ground": "2b2a1d",
		"fog": "586042", "fog_density": 0.024, "volumetric": 0.026,
		"ambient": 0.34, "saturation": 0.78, "contrast": 1.16,
	},
	"ossuary": {
		"zenith": "120d14", "horizon": "44304a", "ground": "1d151f",
		"fog": "4a3550", "fog_density": 0.032, "volumetric": 0.038,
		"ambient": 0.3, "saturation": 0.74, "contrast": 1.2,
	},
}

static var _noise_cache: Dictionary = {}


static func environment(preset_name: String = "bone_yard") -> Environment:
	var preset: Dictionary = PRESETS.get(preset_name, PRESETS.bone_yard)
	var env := Environment.new()

	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(preset.zenith)
	sky_material.sky_horizon_color = Color(preset.horizon)
	sky_material.ground_bottom_color = Color(preset.ground)
	sky_material.ground_horizon_color = Color(preset.horizon).darkened(0.25)
	sky_material.sky_energy_multiplier = 0.85
	sky_material.sun_angle_max = 48.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky

	# Sky-sourced ambient at low energy keeps shadows readable. A flat colour
	# wash at 1.45 was erasing every form in the scene.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = float(preset.ambient)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	env.fog_enabled = true
	env.fog_light_color = Color(preset.fog)
	env.fog_density = float(preset.fog_density)
	env.fog_aerial_perspective = 0.45
	env.fog_sky_affect = 0.6
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = float(preset.volumetric)
	env.volumetric_fog_albedo = Color(preset.fog)
	env.volumetric_fog_emission = Color(preset.fog).darkened(0.7)

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0

	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.6
	env.ssao_power = 1.7

	# Threshold keeps bloom on actual light sources instead of smearing every
	# bright surface, which is what made the pastel pass read as plastic.
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.95
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.15

	env.adjustment_enabled = true
	env.adjustment_saturation = float(preset.saturation)
	env.adjustment_contrast = float(preset.contrast)
	env.adjustment_brightness = 0.97
	return env


static func surface(color: Color, kind: String = "paint", variation_seed: int = 0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var tint := color
	if variation_seed != 0:
		# Nothing in a scrapyard is the same colour twice. Without this every
		# wrecker and spectator is a clone of the last one.
		var drift := float(absi(variation_seed) % 11) / 11.0 - 0.5
		tint = tint.lightened(maxf(0.0, drift * 0.16)).darkened(maxf(0.0, -drift * 0.2))
		tint.h = fposmod(tint.h + drift * 0.015, 1.0)
	material.albedo_color = tint

	match kind:
		"rust":
			material.metallic = 0.15
			material.roughness = 0.92
			_apply_grain(material, 2.4, 0.55)
		"paint":
			material.metallic = 0.3
			material.roughness = 0.68
			_apply_grain(material, 1.6, 0.4)
		"chrome":
			material.metallic = 0.85
			material.roughness = 0.32
			_apply_grain(material, 0.9, 0.22)
		"flesh":
			material.metallic = 0.0
			material.roughness = 0.42
			material.rim_enabled = true
			material.rim = 0.5
			material.rim_tint = 0.6
			_apply_grain(material, 5.5, 0.3)
		"bone":
			material.metallic = 0.0
			material.roughness = 0.74
			_apply_grain(material, 3.2, 0.35)
		"dirt":
			material.metallic = 0.0
			material.roughness = 0.97
			_apply_grain(material, 1.1, 0.6)
		_:
			material.metallic = 0.35
			material.roughness = 0.6
	return material


static func emissive(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.metallic = 0.1
	material.roughness = 0.5
	return material


## Triplanar noise on roughness. Every mesh in the project is an untextured
## primitive with no UVs, so triplanar is the only way to break up a surface
## without authoring UV maps for procedurally generated geometry.
static func _apply_grain(material: StandardMaterial3D, scale: float, strength: float) -> void:
	material.uv1_triplanar = true
	material.uv1_scale = Vector3(scale, scale, scale)
	material.roughness_texture = _noise(scale)
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.roughness = clampf(material.roughness * (1.0 - strength * 0.25), 0.05, 1.0)


static func _noise(scale: float) -> NoiseTexture2D:
	var key := str(snappedf(scale, 0.1))
	if _noise_cache.has(key):
		return _noise_cache[key]
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.018 * scale
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.55
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.seamless = true
	texture.width = 256
	texture.height = 256
	_noise_cache[key] = texture
	return texture
