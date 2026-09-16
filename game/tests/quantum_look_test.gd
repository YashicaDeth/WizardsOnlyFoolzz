extends Node

## A10.12. The look survives the quantum restart looking like itself.
##
## Not a build — a comparison, which is what the v10 note said this segment
## would be once the restart existed. It exists: `systems/quantum_saves.gd`.
## `begin_new()` is the restart proper (history cleared, a fresh `run_salt`, the
## clock back to 16:30) and `enter()` crosses back into a branch that has been
## through a file on disk. So this suite takes the look either side of both
## moves and compares it, in both directions:
##
##   (a) the same salt across a restart — the look comes back identical;
##   (b) a new salt — the look genuinely differs, in the places the salt is
##       wired to, and is identical everywhere else, which is the half of
##       "looking like itself" that a different world could break.
##
## ## What a capture is here
##
## `--headless` has no framebuffer. Probed rather than assumed: a viewport in a
## headless run returns a texture whose `get_image()` is null, so a PNG diff is
## not available to a suite that has to run from the ordinary test command. The
## capture is therefore taken one level up, off the things the renderer would
## have drawn from — the generated contamination maps pixel by pixel, the
## material scalars, the sky and fog the hour produces, the region's geometry,
## the seeds every grime mark is placed from, and the cast. That is a stronger
## regression than a screenshot for everything except shader output, and it is
## honest about being a data capture rather than a frame.
##
## ## What is wired to the salt, and what is not
##
## Measured rather than repeated from the checklist, whose A10.12 note claimed
## "every surface, every field and every map in A is generated from a seed and a
## `run_salt`". Half true. The salt reaches:
##
##   - every interface grime mark, through `CellOutzGrunge._mix()` (A5.6);
##   - every generated person, through `CastNames._seed_for()`.
##
## It does not reach the world's materials, the palette or the region: those
## take an explicit seed from their caller and a constant one from the scene
## (`ashbloom_world_generator.gd:18` defaults to 774013). So a new branch wears
## differently and is populated by different people, and the walls, the light
## and the streets are the same world. Both halves are checked: the salt-fed
## layers must move, and the salt-blind ones must not — the second is what would
## fail if someone later wired the salt into the region generator and quietly
## made every branch a different city.

const Quantum := preload("res://systems/quantum_saves.gd")
const GENERATOR := preload("res://systems/ashbloom_world_generator.gd")
const ANATOMY := preload("res://systems/anatomy_component.gd")

## Real call-site seeds, not invented ones — the HUD's stains and scratches
## (`celloutz_hud.gd:122-126`), the index plate's grain, stains and stamp
## (`world_index.gd:817-861, 1838-1851`), the handheld's (`handheld_device.gd:826`)
## and the decanting cards' (`decanting_prologue.gd:172`).
const GRIME_SEEDS := [2207, 2211, 2213, 2217, 2219, 907, 11, 27, 43, 61, 5, 12, 19, 31, 77, 300, 4409, 4411, 5501, 4400]

## Slots the game actually resolves people through.
const CAST_SLOTS := ["derby_captain", "boneyard_worker_0", "boneyard_worker_3", "roamer_1_0", "gate_nix"]

## One of every material kind the look system makes, with the tints the world
## uses them at.
const SURFACE_SAMPLES := [
	{"kind": "rust", "color": "b0552a", "seed": 3},
	{"kind": "paint", "color": "392a20", "seed": 17},
	{"kind": "chrome", "color": "6d7278", "seed": 41},
	{"kind": "flesh", "color": "8a7361", "seed": 58},
	{"kind": "bone", "color": "cbbf9a", "seed": 96},
	{"kind": "glass", "color": "3e5a46", "seed": 121},
	{"kind": "dirt", "color": "27221c", "seed": 140},
]

## The branch is aged to 18:45 on the second day. Dusk on purpose rather than
## midnight: `daylight()` is 0.81 there, so every clock-fed dial in the look —
## fog density, sky energy, star density, ambient, exposure — is caught
## mid-lerp, where a restore that rounded, defaulted or lost the clock shows up.
## At 01:00 the curve is flat at zero and a sky restored to the wrong small hour
## would compare equal.
const BRANCH_MINUTE := 42.75 * 60.0

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	print("layers: grime and cast are the two the run salt reaches; sky follows")
	print("        the clock; surface, palette_night, hour_response and region")
	print("        are salt-blind and must not move when the salt does.")

	# ---- build a branch and age it.
	WorldHistory.clear_history()
	Quantum.begin_new(0, "FIRST WORLD")
	var salt_first := int(WorldHistory.run_salt)
	WorldHistory.world_minute = BRANCH_MINUTE
	_register_a_wounded_player()
	Quantum.save_current(0, "FIRST WORLD")
	var before := _fingerprint()
	print("--- branch 0 salt=%d hour=%.2f daylight=%.3f" % [salt_first, WorldClock.hour(), WorldClock.daylight()])
	_print_fingerprint("before", before)

	# ---- (b) the restart proper: a new salt, a blank world, a reset clock.
	Quantum.begin_new(1, "SECOND WORLD")
	var salt_second := int(WorldHistory.run_salt)
	var elsewhere := _fingerprint()
	print("--- branch 1 salt=%d hour=%.2f daylight=%.3f" % [salt_second, WorldClock.hour(), WorldClock.daylight()])
	_print_fingerprint("elsewhere", elsewhere)

	check(salt_second != salt_first, "the restart mints a new run salt")
	check(CellOutzGrunge.run_salt == salt_second, "and the grime layer is told about it")
	check(elsewhere["grime"] != before["grime"], "(b) a new salt wears the interfaces differently")
	check(elsewhere["cast"] != before["cast"], "(b) a new salt is populated by different people")
	check(elsewhere["surface"] == before["surface"], "(b) and the materials are the same materials")
	check(elsewhere["palette_night"] == before["palette_night"], "(b) and the palette after dark is unchanged")
	check(elsewhere["hour_response"] == before["hour_response"], "(b) and the hour still drives the surfaces the same way")
	check(elsewhere["region"] == before["region"], "(b) and the region is the same region, not a second city")
	check(elsewhere["body"] != before["body"], "(b) and the restart left the first world's body behind")
	check(absf(WorldClock.hour() - 16.5) < 0.01, "(b) and the new world opens at 16:30 rather than at the old hour")

	# ---- (a) cross back. `enter()` parses the branch off disk; nothing below
	# this line is reading the copy that was in memory a moment ago.
	check(Quantum.enter(0), "the saved branch can be re-entered")
	var after := _fingerprint()
	print("--- re-entered branch 0 salt=%d hour=%.2f daylight=%.3f" % [int(WorldHistory.run_salt), WorldClock.hour(), WorldClock.daylight()])
	_print_fingerprint("after", after)

	check(int(WorldHistory.run_salt) == salt_first, "(a) the run salt survives the round trip through the file")
	check(CellOutzGrunge.run_salt == salt_first, "(a) and the grime layer is put back on it")
	check(absf(WorldClock.hour() - 18.75) < 0.01, "(a) and the branch comes back at the hour it was saved at")
	check(before["sky"] != elsewhere["sky"], "(a) the sky is a real fingerprint of the hour, not a constant")
	for layer in before:
		check(after[layer] == before[layer], "(a) the %s comes back identical" % layer)

	# ---- and the branch left behind was not overwritten by the one that
	# replaced it: crossing back the other way returns the second world's wear.
	check(Quantum.enter(1), "the second branch can be re-entered in turn")
	var elsewhere_again := _fingerprint()
	for layer in elsewhere:
		check(elsewhere_again[layer] == elsewhere[layer], "the second world's %s survived the crossing too" % layer)

	print("QUANTUM_LOOK_TEST_RESULT failures=", failures.size())
	if not failures.is_empty():
		print("QUANTUM_LOOK_TEST FAILURES: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)


## A body with damage on it, written where the game writes it
## (`bone_yard_hunt.gd:4995` amends `subjects.player.anatomy_state` from the
## rig's snapshot). The rig itself needs a scene and a physics frame; the
## anatomy under it does not, and it is the anatomy that is saved.
##
## The limit, stated rather than hidden: what is compared is the record the body
## is rebuilt from, not a rebuilt body. `BaselineHuman.build(id, {"restore":
## state})` is deterministic in what it restores — which limbs are gone, which
## organs are hidden, how deep each zone is opened — but the gore it hangs off
## them draws from the global RNG (`baseline_human.gd:587, 1026-1074`), so a rig
## fingerprint would differ between two identical restores and invent failures.
## Comparing the record is the part that can be compared honestly.
func _register_a_wounded_player() -> void:
	var anatomy: AnatomyComponent = ANATOMY.new()
	anatomy.configure("player")
	anatomy.apply_hit("head", 18.0, 1.0, "ballistic", "eye")
	anatomy.apply_hit("torso", 34.0, 1.4, "ballistic", "liver")
	anatomy.apply_hit("left_arm", 26.0, 1.1, "cut")
	WorldHistory.register_subject("player", {
		"name": "THE PLAYER",
		"kind": "person",
		"anatomy_state": anatomy.snapshot(),
	})
	anatomy.free()


## Every layer of the look that can be read without a framebuffer, as strings
## that compare exactly. Caches are dropped first, on purpose: the surface maps
## are cached hard by kind and tint, and a comparison of two cache hits would
## prove only that a dictionary lookup is stable. Everything below is generated
## again from scratch on every call.
func _fingerprint() -> Dictionary:
	WorldLook._surface_cache = {}
	WorldLook._hour_materials = []
	WorldLook._material_hour = -1.0

	var surfaces: Array[StandardMaterial3D] = []
	var surface_text := PackedStringArray()
	for sample in SURFACE_SAMPLES:
		var material := WorldLook.surface(Color(str(sample["color"])), str(sample["kind"]), int(sample["seed"]))
		surfaces.append(material)
		surface_text.append("%s %s" % [str(sample["kind"]), _material_text(material)])

	return {
		"surface": "\n".join(surface_text),
		"hour_response": _hour_response_text(surfaces),
		"sky": _sky_text(WorldClock.daylight()),
		# Clock-independent, so it can be compared across a restart that resets
		# the clock. This is the palette A10.7 measured.
		"palette_night": _sky_text(0.0),
		"region": _region_text(),
		"grime": _grime_text(),
		"cast": _cast_text(),
		"body": _canonical(WorldHistory.subject("player")),
	}


## Colour, roughness, metal, and the contamination map itself — sampled pixel by
## pixel on a grid rather than hashed, so a failure says which texel moved.
## `response` is the A5.2 map: RGB is what the growth emits, alpha is how rough
## that texel is.
func _material_text(material: StandardMaterial3D) -> String:
	var parts := PackedStringArray()
	parts.append("albedo=%s rough=%.6f metal=%.6f glow=%.6f filter=%d triplanar=%s uv=%.4f" % [
		_canonical(material.albedo_color), material.roughness, material.metallic,
		float(material.get_meta("day_glow", -1.0)), material.texture_filter,
		material.uv1_triplanar, material.uv1_scale.x,
	])
	for label in ["albedo_texture", "emission_texture"]:
		var texture: Texture2D = material.get(label)
		parts.append("%s=%s" % [label, _texture_text(texture)])
	return " ".join(parts)


func _texture_text(texture: Texture2D) -> String:
	if texture == null:
		return "none"
	var image := texture.get_image()
	if image == null:
		return "no-image"
	var samples := PackedStringArray()
	samples.append("%dx%d f%d" % [image.get_width(), image.get_height(), image.get_format()])
	var step := maxi(1, image.get_width() / 8)
	for y in range(0, image.get_height(), step):
		for x in range(0, image.get_width(), step):
			samples.append(_canonical(image.get_pixel(x, y)))
	return ",".join(samples)


## A10.3: the hour is the one live part of a material. Driven explicitly at both
## ends rather than off the clock, so this layer says whether the mechanism
## survived the restart without also saying what time it is.
func _hour_response_text(materials: Array[StandardMaterial3D]) -> String:
	var env := WorldLook.environment("ashbloom")
	var parts := PackedStringArray()
	for daylight in [0.0, 1.0]:
		WorldLook._material_hour = -1.0
		WorldLook.apply_hour(env, daylight, "ashbloom")
		var row := PackedStringArray()
		for material in materials:
			row.append("%.6f" % material.emission_energy_multiplier)
		parts.append("lit=%.2f %s" % [daylight, " ".join(row)])
	return "\n".join(parts)


## The sky, the fog and the exposure the hour produces — the whole of what
## A3.1/A10.4 put on the clock.
func _sky_text(daylight: float) -> String:
	var env := WorldLook.environment("ashbloom")
	WorldLook.apply_hour(env, daylight, "ashbloom")
	var material := (env.sky.sky_material as ShaderMaterial)
	var parts := PackedStringArray()
	for parameter in ["zenith", "horizon", "ground", "energy", "star_density", "breach", "beyond", "shell_edge"]:
		parts.append("%s=%s" % [parameter, _canonical(material.get_shader_parameter(parameter))])
	parts.append("fog=%s density=%.6f sky_affect=%.6f" % [_canonical(env.fog_light_color), env.fog_density, env.fog_sky_affect])
	parts.append("vol=%s vol_density=%.6f emission=%s" % [_canonical(env.volumetric_fog_albedo), env.volumetric_fog_density, _canonical(env.volumetric_fog_emission)])
	parts.append("ambient=%.6f exposure=%.6f sat=%.6f contrast=%.6f" % [
		env.ambient_light_energy, env.tonemap_exposure, env.adjustment_saturation, env.adjustment_contrast,
	])
	return " ".join(parts)


## The region, rebuilt. Where every building stands, how big it is, which way it
## leans and what colour its walls are — the silhouette of the place.
func _region_text() -> String:
	var generator: Node3D = GENERATOR.new()
	add_child(generator)
	generator.generate()
	var parts := PackedStringArray()
	parts.append("buildings=%d lots=%d" % [generator.generated_buildings.size(), generator.lots.size()])
	for building in generator.generated_buildings:
		parts.append("%s %s" % [_canonical(building.position.snapped(Vector3.ONE * 0.0001)), _canonical(building.rotation.snapped(Vector3.ONE * 0.0001))])
	for lot in generator.lots:
		parts.append(_canonical(lot))
	remove_child(generator)
	generator.free()
	return "\n".join(parts)


## Every grime mark in the interface layer is placed by an RNG whose seed is
## `CellOutzGrunge._mix(call_site_seed)` — the first line of `stain`, `spatter`,
## `stamp`, `grain`, `scratches`, `hatch`, `run_down` and `scrawl` alike. The
## run salt is the only input to `_mix` that is not a constant in the source, so
## this stream is the marks: same stream, same panel; different stream, a panel
## worn somewhere else entirely.
func _grime_text() -> String:
	var parts := PackedStringArray()
	for seed_value in GRIME_SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = CellOutzGrunge._mix(seed_value)
		var draws := PackedStringArray()
		for index in 8:
			draws.append("%.6f" % rng.randf())
		parts.append("%d -> %d [%s]" % [seed_value, rng.seed, " ".join(draws)])
	return "\n".join(parts)


func _cast_text() -> String:
	var parts := PackedStringArray()
	for slot in CAST_SLOTS:
		var who := CastNames.person(slot)
		parts.append("%s -> %s / %s / %s" % [slot, who["name"], who["role"], who["faction"]])
	return "\n".join(parts)


## A stable text form. Written rather than leaning on `==` between dictionaries
## because the branch has been through JSON: an integer comes back as a float,
## key order is not promised, and nested containers compare by reference in some
## engine versions. Keys are sorted and every number is formatted the same way,
## so 4700 and 4700.0 are the same body and 4700 and 4701 are not.
func _canonical(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_INT, TYPE_FLOAT:
			return "%.6f" % float(value)
		TYPE_COLOR:
			var color: Color = value
			return "(%.6f,%.6f,%.6f,%.6f)" % [color.r, color.g, color.b, color.a]
		TYPE_VECTOR2:
			return "(%.6f,%.6f)" % [(value as Vector2).x, (value as Vector2).y]
		TYPE_VECTOR3:
			return "(%.6f,%.6f,%.6f)" % [(value as Vector3).x, (value as Vector3).y, (value as Vector3).z]
		TYPE_RECT2:
			return "[%s %s]" % [_canonical((value as Rect2).position), _canonical((value as Rect2).size)]
		TYPE_DICTIONARY:
			var keys: Array = (value as Dictionary).keys()
			keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
			var pairs := PackedStringArray()
			for key in keys:
				pairs.append("%s:%s" % [str(key), _canonical((value as Dictionary)[key])])
			return "{%s}" % ",".join(pairs)
		TYPE_ARRAY:
			var items := PackedStringArray()
			for item in (value as Array):
				items.append(_canonical(item))
			return "[%s]" % ",".join(items)
	return str(value)


func _print_fingerprint(label: String, fingerprint: Dictionary) -> void:
	var keys: Array = fingerprint.keys()
	keys.sort()
	for layer in keys:
		var text: String = fingerprint[layer]
		print("    %-10s %-14s %6d chars  digest %d" % [label, layer, text.length(), hash(text)])
