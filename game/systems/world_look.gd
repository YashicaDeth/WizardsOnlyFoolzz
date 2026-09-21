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

const FIRMAMENT_SHADER := preload("res://shaders/firmament.gdshader")

## Greg, playing the build: *"it's lagging a lot in the Gore Sandbox and we put
## it on full screen ... the FPS is about thirteen"*, and separately *"the
## settings look completely different when you enter Gore Sandbox or main
## game"*. Those are one bug, not two.
##
## `country_town_menu._cycle_graphics()` only ever touched the **menu's own**
## Environment, and only its `glow_enabled`. It never touched the two settings
## that actually cost frames, and the moment you left the menu
## `WorldLook.environment()` built a brand new Environment with everything
## switched back on. So GRAPHICS: PERFORMANCE did nothing anywhere except the
## title screen, and the sandbox always ran at maximum.
##
## The three effects below are all fill-rate bound — their cost scales with the
## number of pixels, which is exactly why the build was playable in a window
## and thirteen frames a second fullscreen:
##
##   - **Volumetric fog** ray-marches the view. It is the single most expensive
##     thing in this Environment and the first to go.
##   - **SSAO** samples depth per pixel at a 1.2m radius.
##   - **Glow** blurs the frame through a mip chain.
##
## Quality lives here rather than in the menu because `environment()` is the one
## place every scene passes through. Set it once and the Hunt, the derby, the
## vat and the sandbox all honour it — which is also what makes the settings
## stop disagreeing with each other between scenes.
enum Quality { ULTRA, HIGH, PERFORMANCE }

## X1.2. The region's frame contract. PERFORMANCE is the tier held to this
## budget; HIGH and ULTRA are deliberate exchanges of headroom for image
## quality. Keeping the number beside the preset prevents benchmarks and the
## settings screen from quietly testing different meanings of "performance".
const FRAME_BUDGET_MS := 1000.0 / 60.0
const QUALITY_RENDER_SCALE := {
	Quality.ULTRA: 1.0,
	Quality.HIGH: 0.9,
	Quality.PERFORMANCE: 0.75,
}
const QUALITY_MSAA := {
	Quality.ULTRA: Viewport.MSAA_4X,
	Quality.HIGH: Viewport.MSAA_2X,
	Quality.PERFORMANCE: Viewport.MSAA_DISABLED,
}

## Static so it survives a scene change. Scenes build their Environment fresh on
## load, and an instance field would be rebuilt to the default every time.
# Performance is the safe first-launch contract. The measured sandbox still
# preserves the authored distance fog and colour work at this level, while
# avoiding three fullscreen effects before the player has chosen to pay for
# them. HIGH and ULTRA remain one click away in Settings.
static var quality: Quality = Quality.PERFORMANCE


## Named for the settings panel, which shows the word rather than the enum.
static func quality_name() -> String:
	match quality:
		Quality.ULTRA: return "ULTRA"
		Quality.HIGH: return "HIGH"
		_: return "PERFORMANCE"


static func set_quality_name(value: String) -> void:
	match value.to_upper():
		"ULTRA": quality = Quality.ULTRA
		"PERFORMANCE": quality = Quality.PERFORMANCE
		_: quality = Quality.HIGH


## Applies the part of a graphics tier owned by the viewport rather than its
## Environment. Render benchmarks must call both this and `apply_quality()` or
## they are not measuring the preset a player actually receives.
static func apply_viewport_quality(viewport: Viewport) -> void:
	if viewport == null:
		return
	viewport.scaling_3d_scale = float(QUALITY_RENDER_SCALE[quality])
	viewport.msaa_3d = int(QUALITY_MSAA[quality]) as Viewport.MSAA
	viewport.use_taa = quality != Quality.PERFORMANCE


## Applies the current quality to an Environment. Separated from `environment()`
## so a live scene can be re-tuned the instant the player changes the setting,
## without rebuilding the sky or losing the hour of day.
static func apply_quality(env: Environment, preset: Dictionary) -> void:
	if env == null:
		return
	# Distance fog stays on at every level: it is cheap, it is the art
	# direction, and without it the far edge of every region pops.
	env.fog_enabled = true
	match quality:
		Quality.ULTRA:
			env.volumetric_fog_enabled = true
			env.volumetric_fog_density = float(preset.get("volumetric", 0.01))
			env.ssao_enabled = true
			env.glow_enabled = true
		Quality.HIGH:
			# Volumetric fog at roughly half density still reads as depth and
			# costs appreciably less than the full march.
			env.volumetric_fog_enabled = true
			env.volumetric_fog_density = float(preset.get("volumetric", 0.01)) * 0.55
			env.ssao_enabled = true
			env.glow_enabled = true
		_:
			env.volumetric_fog_enabled = false
			env.ssao_enabled = false
			env.glow_enabled = false




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
	# The front door, and only the front door. Greg, on the title shot: *"i dont
	# like the blueish backround and how low poly everything is"*. It was running
	# `ossuary`, which is mauve from zenith to ground and carries the densest fog
	# of any preset here — 0.02, nearly twice `ashbloom`'s. Both halves of the
	# complaint come out of that one entry: the purple is the blue he means, and
	# the fog is why the street reads as untextured blocks. `ashbloom`'s own note
	# above already says it — dense fog "hid every surface the material system
	# produces and is a large part of why the Ashbloom read as a grey-box
	# prototype" — and the title screen was still carrying twice that density.
	#
	# Red and black, because that is what the mark, the sigil and the key light
	# already are; a mauve screen behind a blood-red wordmark is two games. Fog
	# down to a third so the geometry has surfaces again, saturation up because
	# the red is supposed to be the thing you notice.
	# Near-black carrying red, not red. The first cut of this went to a flat
	# arterial field and the wordmark — which is itself red — vanished into it;
	# trading a mauve screen for a monochrome one is not a fix. The mark reads on
	# black, which is what its own PNG is drawn against, so the door is black
	# with the red held in the horizon and the volumetrics and the lights.
	"front_door": {
		"zenith": "0a0406", "horizon": "3a0d0a", "ground": "120607",
		"fog": "1e0908", "fog_density": 0.0060, "volumetric": 0.009,
		"ambient": 0.40, "saturation": 0.92, "contrast": 1.28, "exposure": 1.0,
	},
	# The Lower Works, for exactly the reason `front_door` above exists. It was
	# running `ossuary` too, and Greg's note on it -- *"this map is super
	# scuffed"* -- is the same complaint in the same words as the title shot:
	# mauve from zenith to ground, and 0.02 fog erasing every surface the
	# material system produces. The district is also indoors and underground,
	# where a sky-coloured haze forty metres down a sealed tunnel was never
	# right to begin with.
	#
	# So: near-black warm rock, and fog at a third of ossuary's, which is what
	# lets the rust-orange and sodium-green bay lamps do the colouring instead
	# of a flat violet wash sitting in front of them.
	"lower_works": {
		"zenith": "07090a", "horizon": "1b1512", "ground": "0c0a08",
		"fog": "1d1a16", "fog_density": 0.0065, "volumetric": 0.010,
		"ambient": 0.46, "saturation": 0.96, "contrast": 1.26, "exposure": 1.05,
	},
}

static var _noise_cache: Dictionary = {}


static func environment(preset_name: String = "bone_yard") -> Environment:
	var preset: Dictionary = PRESETS.get(preset_name, PRESETS.bone_yard)
	var env := Environment.new()

	# A6.1. The sky was a `ProceduralSkyMaterial` for five passes: a two-colour
	# gradient, which is the one surface in this game that had never been asked
	# to say anything, and the one thing a broken firmament cannot be.
	var sky_material := ShaderMaterial.new()
	sky_material.shader = FIRMAMENT_SHADER
	sky_material.set_shader_parameter("zenith", Color(preset.zenith))
	sky_material.set_shader_parameter("horizon", Color(preset.horizon))
	sky_material.set_shader_parameter("ground", Color(preset.ground))
	sky_material.set_shader_parameter("energy", 1.15)
	sky_material.set_shader_parameter("firmament", firmament())
	sky_material.set_shader_parameter("breach", float(preset.get("breach", 1.0)))
	sky_material.set_shader_parameter("beyond", Color(preset.get("beyond", "04050a")))
	sky_material.set_shader_parameter("shell_edge", Color(preset.get("shell_edge", "9e6a3c")))
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
	env.volumetric_fog_albedo = Color(preset.fog)
	env.volumetric_fog_emission = Color(preset.fog).darkened(0.7)

	# ACES crushes the toe hard, which turned near-black authored albedo into an
	# unreadable frame. Filmic keeps shadow detail at this exposure.
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = float(preset.get("exposure", 1.25))
	env.tonemap_white = 6.0

	env.ssao_radius = 1.2
	env.ssao_intensity = 1.8
	env.ssao_power = 1.4

	# Threshold keeps bloom on actual light sources instead of smearing every
	# bright surface, which is what made the pastel pass read as plastic.
	env.glow_intensity = 0.55
	env.glow_strength = 0.95
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.0

	# The three fill-rate switches, set from the one global the settings panel
	# drives, so every scene agrees and PERFORMANCE actually performs.
	apply_quality(env, preset)

	env.adjustment_enabled = true
	env.adjustment_saturation = float(preset.saturation)
	env.adjustment_contrast = float(preset.contrast)
	env.adjustment_brightness = 1.02
	return env


## A3.1. The hour, applied to the whole look rather than to the sun alone.
##
## "Every surface A built is judged again after dark, not just dimmed." Judged
## after dark, it turned out the world was not even dimmed — it was half dimmed.
## `_update_day_night` drove the sun, the ambient energy and the exposure, and
## nothing drove the sky. A capture at 01:00 and a capture at noon came back
## with a pixel-identical horizon: at one in the morning the brightest thing in
## frame was the sky, the ground under it was crushed to black, and the one real
## sodium lamp in the shot read the same at both hours because it had a lit sky
## to compete with. That is the whole reason nothing in section A has ever
## looked like night: the surfaces were not failing, they were being asked to
## sit under a midday backdrop with no light on them.
##
## So the sky, the fog and the volumetric fog move with the hour too, from the
## preset's authored day values down to a night the preset derives rather than
## declares — night is the same place with the light taken out of it, not a
## second palette somebody would have to keep in agreement with the first.
##
## Takes `daylight` rather than reading `WorldClock` itself, so a caller
## crossfading for its own reasons (a tunnel, the shadow realms, a capture that
## wants a specific hour) uses the same mapping instead of writing a second one.
static func apply_hour(env: Environment, daylight: float, preset_name: String = "bone_yard") -> void:
	if env == null:
		return
	var preset: Dictionary = PRESETS.get(preset_name, PRESETS.bone_yard)
	var lit := clampf(daylight, 0.0, 1.0)

	var sky := env.sky
	if sky != null and sky.sky_material is ShaderMaterial:
		var sky_material := sky.sky_material as ShaderMaterial
		var zenith := Color(preset.zenith)
		var horizon := Color(preset.horizon)
		# Night is this sky with the sun taken out of it: the zenith goes
		# nearly black and keeps its hue, and the horizon loses the warm dust
		# that only exists because something is lighting it. Derived from the
		# authored colours so retuning a preset cannot leave its night behind.
		var night_zenith := zenith.darkened(0.86)
		var night_horizon := horizon.darkened(0.82).lerp(zenith, 0.45)
		sky_material.set_shader_parameter("zenith", night_zenith.lerp(zenith, lit))
		sky_material.set_shader_parameter("horizon", night_horizon.lerp(horizon, lit))
		sky_material.set_shader_parameter("ground", Color(preset.ground).darkened(lerpf(0.7, 0.0, lit)))
		# A6.2. The stars behind the break are only there when the sky in front
		# of them stops competing, which is the same reason you cannot see them
		# through a lit window.
		sky_material.set_shader_parameter("star_density", lerpf(0.85, 0.02, lit))
		# The multiplier is what stopped the horizon ever going dark, because
		# it held at its daylight value around the clock.
		sky_material.set_shader_parameter("energy", lerpf(0.07, 1.15, lit))

	# Fog is lit by the sky, so it has to move with it or the haze stays warm
	# over a cold ground — which reads as smog at noon and as nothing at all at
	# one in the morning.
	var fog := Color(preset.fog)
	env.fog_light_color = fog.darkened(0.78).lerp(fog, lit)
	env.volumetric_fog_albedo = env.fog_light_color
	env.volumetric_fog_emission = env.fog_light_color.darkened(0.7)
	# Slightly denser after dark. Not for atmosphere: it is what keeps a lamp
	# reading as a light with a throw rather than a bright dot, which is what
	# A4.1 and A4.2 are going to hang off.
	# A6.2. And the fog stops repainting the sky after dark. `fog_sky_affect`
	# held at 0.6 around the clock, which put the haze colour over the whole
	# dome at every hour — so the night sky photographed as a brown wash at
	# roughly 0.15 whatever the sky's own energy was, and nothing behind the
	# break could be seen through it. Fog is lit by the sun; with the sun gone
	# there is nothing in the air to light.
	# A10.4. The ambient and the exposure belong to the hour and to the preset,
	# and they are set here rather than by each scene. `bone_yard_hunt.gd` drove
	# them with `lerpf(0.16, 0.72, ...)` and `lerpf(0.85, 1.18, ...)`: four
	# numbers typed into a scene, two of which happened to match the Ashbloom
	# preset and two of which matched nothing at all — so the Hunt Grounds were
	# lit by a term nobody had chosen for them, and any scene that wanted the
	# same night had to copy the same four numbers to get it.
	env.ambient_light_energy = float(preset.ambient) * lerpf(0.22, 1.0, lit)
	env.tonemap_exposure = float(preset.get("exposure", 1.25)) * lerpf(0.76, 1.0, lit)
	_apply_hour_to_materials(lit)
	env.fog_sky_affect = lerpf(0.12, 0.6, lit)
	env.fog_density = float(preset.fog_density) * lerpf(1.45, 1.0, lit)
	env.volumetric_fog_density = float(preset.volumetric) * lerpf(1.6, 1.0, lit)


## A10.3. Every material the look system has made, weakly held, so the hour can
## change all of them and a freed one can still be collected. Weak on purpose: a
## strong reference here would keep every wrecker's flesh alive for the life of
## the process.
static var _hour_materials: Array = []
## The last daylight the materials were set to, quantised. `apply_hour()` runs
## every physics frame and walking several hundred materials at 60Hz to write
## values that have not moved is the kind of cost A10.14 is about.
static var _material_hour := -1.0


## A10.3. What the hour does to a surface. The contamination is the living part
## of every material in this game — A5.2 made it the only part that emits — and
## living things that glow do it at night. In daylight the bloom is washed out
## by the sun the way real bioluminescence is; after dark it is the only thing
## on a wall giving anything back, which is what makes a lamp worth carrying
## past a wall rather than only into a room.
##
## Quantised to fiftieths, so the walk happens a handful of times across a
## sunset rather than sixty times a second.
static func _apply_hour_to_materials(lit: float) -> void:
	var step := snappedf(clampf(lit, 0.0, 1.0), 0.02)
	if is_equal_approx(step, _material_hour):
		return
	_material_hour = step
	var living: Array = []
	for reference in _hour_materials:
		var material: StandardMaterial3D = (reference as WeakRef).get_ref()
		if material == null:
			continue
		living.append(reference)
		material.emission_energy_multiplier = float(material.get_meta("day_glow", 0.3)) * lerpf(2.4, 0.45, step)
	_hour_materials = living


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

	# A5.1. Up to v4 a kind was two scalars and a pattern, which is why every
	# surface in the game answered a lamp with the same highlight: the world was
	# one material wearing six colours. What separates these in life is *how* they
	# return light — meat passes it through, brushed scrap smears it along the
	# grain, glass lets it past, dirt gives none of it back — so that is what
	# separates them here.
	match kind:
		"rust":
			material.metallic = 0.15
			material.roughness = 0.92
			# Oxide is a mineral crust, not a metal surface: what specular it has is
			# dull and colourless.
			material.metallic_specular = 0.28
			_apply_grain(material, 0.32, 0.55, "rust", variation_seed)
		"paint":
			material.metallic = 0.3
			material.roughness = 0.68
			material.metallic_specular = 0.45
			_apply_grain(material, 0.28, 0.4, "paint", variation_seed)
		"chrome":
			material.metallic = 0.85
			material.roughness = 0.32
			# Scrap chrome was ground flat by somebody with a wheel, so its highlight
			# is drawn out along the grain rather than sitting in a round spot. This is
			# the single cue that separates salvaged plate from painted plate under one
			# lamp.
			material.anisotropy_enabled = true
			material.anisotropy = 0.72
			_apply_grain(material, 0.4, 0.22, "chrome", variation_seed)
		"flesh":
			material.metallic = 0.0
			material.roughness = 0.42
			material.rim_enabled = true
			material.rim = 0.5
			material.rim_tint = 0.6
			# Meat is not opaque. A lamp behind a limb comes through it, which is the
			# whole biopunk register and the one thing rim lighting only imitates.
			material.subsurf_scatter_enabled = true
			material.subsurf_scatter_strength = 0.6
			material.subsurf_scatter_transmittance_enabled = true
			material.subsurf_scatter_transmittance_color = Color(0.75, 0.18, 0.16)
			# Depth and boost both matter: Godot's default transmittance depth
			# lets light a few centimetres into a surface, which is right for a
			# cheek and invisible on anything the size of a limb. A lamp behind
			# a body in this game should show through it.
			material.subsurf_scatter_transmittance_depth = 0.85
			material.subsurf_scatter_transmittance_boost = 0.7
			# And a backlight as well, which is the part that actually reads.
			# Measured, not assumed: with an omni lamp behind it, transmittance
			# alone photographed a black disc at every depth and boost tried —
			# Godot computes it from the shadow map and it stays a near-surface
			# effect. `backlight` is the engine's supported wrap-through and it
			# is what makes a limb with a lamp behind it glow at all.
			material.backlight_enabled = true
			material.backlight = Color(0.46, 0.11, 0.09)
			_apply_grain(material, 2.2, 0.3, "flesh", variation_seed)
		"bone":
			material.metallic = 0.0
			material.roughness = 0.74
			# Thin bone lights up from behind the way a lampshade does.
			material.backlight_enabled = true
			material.backlight = Color(0.32, 0.28, 0.2)
			_apply_grain(material, 1.4, 0.35, "bone", variation_seed)
		"glass":
			# A5.1 names glass and the game had none: `smoked_glass` was remapped onto
			# chrome, so every window in the world was a mirror. It is the only kind
			# here that light goes *through*, and the refraction is deliberately small
			# — this is filthy salvaged glazing, not a lens.
			material.metallic = 0.0
			material.roughness = 0.16
			material.metallic_specular = 0.9
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color.a = 0.42
			material.refraction_enabled = true
			material.refraction_scale = 0.06
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			_apply_grain(material, 0.5, 0.18, "glass", variation_seed)
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
			# Ash and spoil return almost nothing at normal incidence, which the
			# rim above does not touch — without this the ground carries a sheen
			# under every lamp and reads as wet concrete even with the edge fixed.
			material.metallic_specular = 0.08
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
	"smoked_glass": {"color": "121b1c", "kind": "glass"},
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
	var maps := _surface_maps(kind, material.albedo_color, seed_value)
	# Albedo was a flat colour on every surface in the game, with only roughness
	# varying — which is the whole reason the world read as untextured primitives
	# no matter how the geometry was built. Contamination arrives on the albedo
	# now, at low resolution and unfiltered, per ART-DIRECTION.md: colour is
	# contamination, not paint, and the target is PS1-era crunch.
	material.albedo_texture = maps["albedo"]
	# A5.2. And contamination stops being only a colour. Up to v4 the roughness
	# map was `_noise(scale)` — unrelated noise, the same field for every kind —
	# so a rust bloom and the clean steel beside it returned a lamp identically
	# and the contamination was visible only as a stain in daylight. The map that
	# decides where the growth is now also decides how that patch answers light:
	# bloom is wet and takes a sharper highlight, and the bloom is the only part
	# of the surface that emits, because the green in this world is alive.
	material.roughness_texture = maps["response"]
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_ALPHA
	material.roughness = clampf(material.roughness * (1.0 - strength * 0.25), 0.05, 1.0)
	material.emission_enabled = true
	material.emission_texture = maps["response"]
	material.emission = Color(1, 1, 1)
	# MULTIPLY, and not by taste: Godot's default emission operator is ADD,
	# which computes `(emission + texture) * energy`. With a white emission
	# colour that is a flat glow on every texel whether or not anything is
	# growing there — the first build of this lit the entire world to mid grey
	# and read as fog. Multiplied, the map alone decides what emits.
	material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	material.emission_energy_multiplier = float(maps["glow"])
	# A10.3. Registered so the hour can reach it. The sky, the fog and the
	# lamps all moved with the clock from v3 onward and the surfaces underneath
	# them did not — they were lit differently at midnight and were otherwise
	# the same material they had been at noon.
	material.set_meta("day_glow", float(maps["glow"]))
	_hour_materials.append(weakref(material))
	# Born at the current hour rather than at noon. `_apply_hour_to_materials()`
	# only walks the registry when the hour has actually moved, so without this
	# a wrecker spawned at one in the morning burns at its daylight value until
	# something else changes the clock — measured, not guessed: a material made
	# mid-run read 0.280 where every other surface in the scene read 0.672.
	if _material_hour >= 0.0:
		material.emission_energy_multiplier = float(maps["glow"]) * lerpf(2.4, 0.45, _material_hour)
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
	elif kind in ["rust", "dirt", "bone", "paint"]:
		# The architecture half of the same idea. Flesh was the only surface in
		# the game that could carry hand-made art, which was fine while the
		# game was one room and wrong the moment it became a buried city: the
		# walls, floors and pipe of an underground are most of what a player
		# looks at. `chrome` and `glass` are deliberately left out -- a grime
		# sheet over polished steel or pressure glass reads as dirt on the
		# lens, not as a surface.
		var slab_sheet: Texture2D = ArtSet.pick("slab", seed_value)
		if slab_sheet != null:
			material.detail_enabled = true
			material.detail_albedo = slab_sheet
			material.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MIX
			material.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# The tint now lives in the texture, so leave the multiplier neutral or the
	# surface is coloured twice and goes muddy. The alpha is kept: glass carries
	# its transparency there and the texture has none of its own.
	material.albedo_color = Color(1, 1, 1, material.albedo_color.a)


## A low-resolution, posterised, contaminated surface for one material kind,
## and the map of how that contamination answers light. Generated rather than
## authored so nothing here is an imported asset, and cached hard: without the
## cache a pit of twelve wreckers would build a thousand of these.
static var _surface_cache: Dictionary = {}


## A5.2. Returns `albedo` (the colour), `response` (RGB is what the bloom
## emits, alpha is how rough that texel is) and `glow` (how hard this kind's
## growth burns). One field decides all of it, which is the point: up to v4 the
## contamination was painted into the albedo and the roughness came from
## unrelated noise, so a bloom and the clean plate beside it returned a lamp
## exactly alike and the contamination existed only in daylight, as a stain.
static func _surface_maps(kind: String, tint: Color, seed_value: int) -> Dictionary:
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

	# What grows on, weeps down or stains this kind of surface, and how hard the
	# growth burns once it is the only thing in the frame emitting.
	var growth := Color("6d8a2a")
	var stain := Color("2a1a12")
	var bloom := 0.42
	var glow := 0.5
	match kind:
		"rust":
			growth = Color("8a4a1c")
			stain = Color("241109")
			bloom = 0.62
			glow = 0.28
		"chrome":
			growth = Color("4a5a5e")
			stain = Color("13181a")
			bloom = 0.3
			glow = 0.12
		"flesh":
			growth = Color("7d3a3a")
			stain = Color("2a0b10")
			bloom = 0.34
			glow = 0.22
		"bone":
			growth = Color("b8a870")
			stain = Color("3a3018")
			bloom = 0.3
			glow = 0.1
		"glass":
			growth = Color("3e5a46")
			stain = Color("101614")
			bloom = 0.34
			glow = 0.18
		"dirt":
			growth = Color("5c5340")
			stain = Color("1b1710")
			bloom = 0.55
			glow = 0.2

	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var response := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var patch := absf(blotch.get_noise_2d(float(x), float(y)))
			var cell := clampf(absf(grime.get_noise_2d(float(x), float(y))), 0.0, 1.0)
			# Vertical weeping: whatever is on this surface has been running
			# down it for years.
			var weep := clampf(absf(blotch.get_noise_2d(float(x) * 3.4, float(y) * 0.32)), 0.0, 1.0)

			var living := clampf(patch * bloom * 2.6, 0.0, 0.95)
			var weeping := clampf(weep * 0.9 - 0.1, 0.0, 0.8)
			var value := tint
			value = value.lerp(growth, living)
			value = value.lerp(stain, weeping)
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

			# The same field, read as a light response. Growth is wet, so it takes a
			# tighter highlight than the dry plate around it; the multiplier can only
			# reduce roughness, which is correct — nothing here is rougher than the
			# material's own worst state. Only the living part emits, and it emits its
			# own colour rather than a house green.
			var slick := clampf(1.0 - living * 0.55, 0.3, 1.0)
			var burn := living * living
			response.set_pixel(x, y, Color(growth.r * burn, growth.g * burn, growth.b * burn, slick))

	var maps := {
		"albedo": ImageTexture.create_from_image(image),
		"response": ImageTexture.create_from_image(response),
		"glow": glow,
	}
	_surface_cache[key] = maps
	return maps


## A6.1. Where the sky is broken, as an equirectangular map: red is the
## fracture itself, green the shell's broken edge around it.
##
## Sampled in three dimensions off the direction vector rather than in two off
## the texel grid, which costs the same and removes both of the artefacts that
## come free with an equirect map: the seam behind the player at yaw 0, and the
## pinch at the poles where a two-dimensional field gets wrung out to a point.
##
## Generated, cached and never regenerated: the break is a fact about the world
## and every scene that looks up is looking at the same one.
static var _firmament_map: ImageTexture = null


static func firmament() -> ImageTexture:
	if _firmament_map != null:
		return _firmament_map
	var width := 384
	var height := 192
	# Cellular distance2-minus-distance1 is ~0 exactly along the boundary between
	# two cells and rises inward, so the zero set of it is a web of joins — which
	# is what a shattered shell is, and what no amount of ridged noise gives you.
	var cells := FastNoiseLite.new()
	cells.noise_type = FastNoiseLite.TYPE_CELLULAR
	cells.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	cells.frequency = 0.9
	cells.seed = 7741
	# Where it is broken at all. Without this the whole dome crazes evenly, which
	# reads as a texture on the sky rather than as damage to it.
	var region := FastNoiseLite.new()
	region.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	region.frequency = 0.55
	region.fractal_octaves = 2
	region.seed = 4013
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		var phi := float(y) / float(height) * PI
		for x in width:
			var theta := (float(x) / float(width) - 0.5) * TAU
			var dir := Vector3(sin(phi) * sin(theta), cos(phi), sin(phi) * cos(theta))
			var joint := absf(cells.get_noise_3d(dir.x * 8.0, dir.y * 8.0, dir.z * 8.0))
			var open := smoothstep(0.12, 0.46, region.get_noise_3d(dir.x * 2.2, dir.y * 2.2, dir.z * 2.2))
			# Kept off the ground and off the zenith: a tear you have to look up for,
			# rather than one that meets the horizon all the way round.
			var band := smoothstep(0.0, 0.25, dir.y) * (1.0 - smoothstep(0.65, 1.0, dir.y))
			# Thresholds measured, not assumed. Godot's cellular
			# distance2-minus-distance1 does not come down to zero on a cell
			# boundary: over this sphere it runs 0.33 to 0.99, with half a
			# percent of it below 0.50 and four percent below 0.60. The obvious
			# `smoothstep(0.0, 0.05)` for "near the join" can therefore never
			# fire, and the first build of this generated an empty map.
			var crack := (1.0 - smoothstep(0.58, 0.645, joint)) * open * band
			var edge := (1.0 - smoothstep(0.58, 0.76, joint)) * open * band
			image.set_pixel(x, y, Color(crack, clampf(edge - crack, 0.0, 1.0), 0.0, 1.0))
	_firmament_map = ImageTexture.create_from_image(image)
	return _firmament_map


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
