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

## Authored albedo in the Bone Yard kit runs from 0.025 (oil_asphalt, dead_forest)
## to about 0.3 (rusted_steel). Surfaces that dark need real light to read at all:
## too little and the pit goes black, too much and the palette cooks to pastel.
## These values are tuned against captures from tests/capture_scene.tscn.
const PRESETS := {
	# Cool zenith over a warm dust horizon. A single-hue sky drives a single-hue
	# ambient, which flattens the whole frame into one amber wash; the cool fill
	# is what lets the warm floodlights read as light rather than as tint.
	"bone_yard": {
		"zenith": "2b2c34", "horizon": "9a6238", "ground": "3e2a1d",
		"fog": "6f5340", "fog_density": 0.012, "volumetric": 0.012,
		"ambient": 0.62, "saturation": 0.8, "contrast": 1.1, "exposure": 1.18,
	},
	# Fog was dense enough (0.014 with 0.88 ambient) to wash the region into one
	# flat brown haze at any distance, which hid every surface the material
	# system produces and is a large part of why the Ashbloom read as a
	# grey-box prototype. The far edge still hazes out; the near field no
	# longer does. Saturation up, because contamination colour is supposed to
	# be the thing you notice.
	"ashbloom": {
		"zenith": "2c3026", "horizon": "94906a", "ground": "3a3828",
		"fog": "6d7152", "fog_density": 0.005, "volumetric": 0.006,
		"ambient": 0.72, "saturation": 1.02, "contrast": 1.16, "exposure": 1.12,
	},
	"ossuary": {
		"zenith": "1d1722", "horizon": "6a5074", "ground": "2a2030",
		"fog": "5e466a", "fog_density": 0.02, "volumetric": 0.022,
		"ambient": 0.72, "saturation": 0.78, "contrast": 1.1, "exposure": 1.2,
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
	sky_material.sky_energy_multiplier = 1.15
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

	# ACES crushes the toe hard, which turned near-black authored albedo into an
	# unreadable frame. Filmic keeps shadow detail at this exposure.
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = float(preset.get("exposure", 1.25))
	env.tonemap_white = 6.0

	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.8
	env.ssao_power = 1.4

	# Threshold keeps bloom on actual light sources instead of smearing every
	# bright surface, which is what made the pastel pass read as plastic.
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.95
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.0

	env.adjustment_enabled = true
	env.adjustment_saturation = float(preset.saturation)
	env.adjustment_contrast = float(preset.contrast)
	env.adjustment_brightness = 1.02
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
			_apply_grain(material, 0.32, 0.55, "rust", variation_seed)
		"paint":
			material.metallic = 0.3
			material.roughness = 0.68
			_apply_grain(material, 0.28, 0.4, "paint", variation_seed)
		"chrome":
			material.metallic = 0.85
			material.roughness = 0.32
			_apply_grain(material, 0.4, 0.22, "chrome", variation_seed)
		"flesh":
			material.metallic = 0.0
			material.roughness = 0.42
			material.rim_enabled = true
			material.rim = 0.5
			material.rim_tint = 0.6
			_apply_grain(material, 2.2, 0.3, "flesh", variation_seed)
		"bone":
			material.metallic = 0.0
			material.roughness = 0.74
			_apply_grain(material, 1.4, 0.35, "bone", variation_seed)
		"dirt":
			material.metallic = 0.0
			material.roughness = 0.97
			# G7.2. Near-black albedo (oil_asphalt, dead_forest run 0.03-0.06) plus
			# 0.97 roughness means flat ground has no grazing-angle response at
			# all — it just goes solid black under anything but direct overhead
			# light, which is most of what a first-person camera sees of the
			# ground. The same rim trick "flesh" already uses picks up the sky's
			# horizon glow at grazing angles instead, so the near field reads as
			# a lit surface with an edge rather than a black hole — contrast from
			# the existing light, not a global exposure or ambient raise.
			material.rim_enabled = true
			material.rim = 0.3
			material.rim_tint = 0.75
			_apply_grain(material, 0.22, 0.6, "dirt", variation_seed)
		_:
			material.metallic = 0.35
			material.roughness = 0.6
	return material


## The authored kits were built to the superseded toybox brief, so their baked
## materials read as bright salvage paint. Rather than block on re-exporting
## every .blend, remap the known material names onto the biopunk palette at
## load. Re-authored assets can simply stop matching these names.
const REGRIME := {
	"salvage_teal": {"color": "24332c", "kind": "rust"},
	"celloutz_salvage_teal": {"color": "1f2b26", "kind": "rust"},
	"bone_enamel": {"color": "6b6048", "kind": "bone"},
	"tar_rubber": {"color": "14100f", "kind": "dirt"},
	"smoked_glass": {"color": "121b1c", "kind": "chrome"},
	"worn_copper": {"color": "50291a", "kind": "rust"},
	"warning_orange": {"color": "7d3a16", "kind": "rust"},
	"rusted_steel": {"color": "3d1c11", "kind": "rust"},
	"burnt_steel": {"color": "17100c", "kind": "rust"},
	"dirty_cream": {"color": "5c5137", "kind": "dirt"},
	"quarry_concrete": {"color": "24201a", "kind": "dirt"},
	"oil_asphalt": {"color": "100e0d", "kind": "dirt"},
	"dead_forest": {"color": "1b241a", "kind": "dirt"},
}


static func regrime(root: Node, variation_seed: int = 0) -> int:
	var changed := 0
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		for child in current.get_children():
			pending.append(child)
		var mesh_instance := current as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source: Material = mesh_instance.mesh.surface_get_material(surface)
			if source == null:
				continue
			var key := source.resource_name.to_lower()
			if not REGRIME.has(key):
				continue
			var entry: Dictionary = REGRIME[key]
			mesh_instance.set_surface_override_material(surface, surface(Color(entry.color), str(entry.kind), variation_seed + surface))
			changed += 1
	return changed


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
static func _apply_grain(material: StandardMaterial3D, scale: float, strength: float, kind := "paint", seed_value := 0) -> void:
	material.uv1_triplanar = true
	material.uv1_scale = Vector3(scale, scale, scale)
	material.roughness_texture = _noise(scale)
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.roughness = clampf(material.roughness * (1.0 - strength * 0.25), 0.05, 1.0)
	# Albedo was a flat colour on every surface in the game, with only roughness
	# varying — which is the whole reason the world read as untextured
	# primitives no matter how the geometry was built. Contamination arrives on
	# the albedo now, at low resolution and unfiltered, per ART-DIRECTION.md:
	# colour is contamination, not paint, and the target is PS1-era crunch.
	material.albedo_texture = _contamination(kind, material.albedo_color, seed_value)
	# G1.3. Greg's own artwork, as a detail layer over the procedural
	# contamination rather than instead of it. Flesh only: the body is where a
	# hand-made surface reads, and putting the same sheets on every wall would
	# turn a texture set into wallpaper. Absent art changes nothing.
	if kind == "flesh":
		var sheet: Texture2D = ArtSet.pick("body", seed_value)
		if sheet != null:
			material.detail_enabled = true
			material.detail_albedo = sheet
			material.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MIX
			material.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# The tint now lives in the texture, so leave the multiplier neutral or the
	# surface is coloured twice and goes muddy.
	material.albedo_color = Color(1, 1, 1, material.albedo_color.a)


## A low-resolution, posterised, contaminated surface for one material kind.
## Generated rather than authored so nothing here is an imported asset, and
## cached hard: without the cache a pit of twelve wreckers would build a
## thousand of these.
static var _surface_cache: Dictionary = {}

static func _contamination(kind: String, tint: Color, seed_value: int) -> ImageTexture:
	var bucket := absi(seed_value) % 6
	var key := "%s|%d|%d|%d|%d" % [kind, roundi(tint.r * 12), roundi(tint.g * 12), roundi(tint.b * 12), bucket]
	if _surface_cache.has(key):
		return _surface_cache[key]

	var size := 96
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var blotch := FastNoiseLite.new()
	blotch.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	blotch.frequency = 0.035
	blotch.fractal_octaves = 3
	blotch.seed = rng.randi()
	var grime := FastNoiseLite.new()
	grime.noise_type = FastNoiseLite.TYPE_CELLULAR
	grime.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_DIV
	grime.frequency = 0.11
	grime.seed = rng.randi()

	# What grows on, weeps down or stains this kind of surface.
	var growth := Color("6d8a2a")
	var stain := Color("2a1a12")
	var bloom := 0.42
	match kind:
		"rust":
			growth = Color("8a4a1c")
			stain = Color("241109")
			bloom = 0.62
		"chrome":
			growth = Color("4a5a5e")
			stain = Color("13181a")
			bloom = 0.3
		"flesh":
			growth = Color("7d3a3a")
			stain = Color("2a0b10")
			bloom = 0.34
		"bone":
			growth = Color("b8a870")
			stain = Color("3a3018")
			bloom = 0.3
		"dirt":
			growth = Color("5c5340")
			stain = Color("1b1710")
			bloom = 0.55

	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var patch := absf(blotch.get_noise_2d(float(x), float(y)))
			var cell := clampf(absf(grime.get_noise_2d(float(x), float(y))), 0.0, 1.0)
			# Vertical weeping: whatever is on this surface has been running
			# down it for years.
			var weep := clampf(absf(blotch.get_noise_2d(float(x) * 3.4, float(y) * 0.32)), 0.0, 1.0)

			var value := tint
			value = value.lerp(growth, clampf(patch * bloom * 2.6, 0.0, 0.95))
			value = value.lerp(stain, clampf(weep * 0.9 - 0.1, 0.0, 0.8))
			value = value.darkened(cell * 0.52)
			# Panel seams and patch plates: straight edges, because a wall that
			# has been repaired has lines on it and pure noise never does.
			if (x % 21 == 0 and patch > 0.18) or (y % 17 == 0 and patch > 0.3):
				value = value.darkened(0.45)
			# Posterise. Banding is the point: smooth gradients read as modern,
			# and the brief asks for deliberately authored technical limits.
			var steps := 7.0
			value = Color(
				roundf(value.r * steps) / steps,
				roundf(value.g * steps) / steps,
				roundf(value.b * steps) / steps,
				1.0
			)
			image.set_pixel(x, y, value)

	var texture := ImageTexture.create_from_image(image)
	_surface_cache[key] = texture
	return texture


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
