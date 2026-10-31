class_name DecalBaker
extends RefCounted

## The procedural maps for the eight blood decals (`DESIGN/DECALS_3D_VFX_BRIEF.md`
## section 4). Every map is built from noise and shapes, seeded, so the same
## seed gives the same bytes on any machine. Nothing is traced from the
## reference PNGs; they only set the proportions each recipe aims for.
##
## Maps come back as Images: mask (L8, white = ink), wet (L8, white = fresh),
## flow (RGB8: RG direction around 0.5, B = reveal order), orm (RGB8: R
## occlusion, G roughness, B metallic 0) and normal (RGB8). The TouchDesigner
## patch (`TD_PATCH.md`) and hand art replace these under the same names
## without anything downstream changing (section 10).

const IDS := ["d1_spray", "d2_pool", "d3_drag", "d4_handprint", "d5_drips", "d6_arc", "d7_print", "d8_spatter"]


## Everything for one decal at `size` pixels square. `extra` carries what the
## shader needs beyond maps (the drip streams).
static func bake(id: String, seed_value: int, size: int = 512) -> Dictionary:
	var k := float(size) / 1024.0
	var mask := PackedFloat32Array()
	var wet := PackedFloat32Array()
	var reveal := PackedFloat32Array()
	var extra := {}
	match id:
		"d1_spray":
			mask = _spray(seed_value, size, k)
			wet = _interior(mask, size, 18.0 * k, 0.25, 0.8)
		"d2_pool":
			mask = _pool(seed_value, size, k)
			wet = _interior(mask, size, 90.0 * k, 0.55, 0.95)
		"d3_drag":
			mask = _drag(seed_value, size, k)
			wet = _ramp_x(mask, size, 1.0, 0.0)
		"d4_handprint":
			mask = _handprint(seed_value, size, k)
			wet = _interior(mask, size, 40.0 * k, 0.45, 0.95)
		"d5_drips":
			var drips := _drips(seed_value, size, k)
			mask = drips.mask
			wet = drips.wet
			extra["streams"] = drips.streams
		"d6_arc":
			var arc := _arc(seed_value, size, k)
			mask = arc.mask
			wet = arc.wet
			reveal = arc.reveal
		"d7_print":
			mask = _print(seed_value, size, k)
			wet = _filled(size, 1.0)
		"d8_spatter":
			var spatter := _spatter(seed_value, size, k)
			mask = spatter.mask
			wet = spatter.wet
		_:
			push_error("DecalBaker: no recipe for %s" % id)
			mask = _filled(size, 0.0)
			wet = _filled(size, 0.0)
	for index in wet.size():
		wet[index] = minf(wet[index], 1.0) * (1.0 if mask[index] > 0.02 else 0.0)
	if reveal.is_empty():
		reveal = _spread_order(mask, size, k)
	var height := _blur(mask, size, maxi(1, roundi(3.0 * k)))
	var crust := _noise(seed_value + 91, size, 5.0 * k, 3, 0.5)
	return {
		"id": id,
		"size": size,
		"mask": _image_l8(mask, size),
		"wet": _image_l8(wet, size),
		"flow": _flow_image(id, mask, reveal, size, k),
		"orm": _orm_image(mask, wet, crust, size),
		"normal": _normal_image(height, crust, wet, size),
		"mask_values": mask,
		"extra": extra,
	}


## Fraction of the frame that is ink, and the ink's bounding box in pixels.
static func measure(mask: PackedFloat32Array, size: int) -> Dictionary:
	var inked := 0
	var low := Vector2i(size, size)
	var high := Vector2i(-1, -1)
	for y in size:
		for x in size:
			if mask[y * size + x] >= 0.5:
				inked += 1
				low = Vector2i(mini(low.x, x), mini(low.y, y))
				high = Vector2i(maxi(high.x, x), maxi(high.y, y))
	var box := Vector2i(maxi(0, high.x - low.x + 1), maxi(0, high.y - low.y + 1))
	return {"ink": float(inked) / float(size * size), "bbox": box, "bbox_1024": Vector2(box) * (1024.0 / float(size))}


# --- D1 spray: fine arterial mist, two noise scales broken into droplets.
static func _spray(seed_value: int, size: int, k: float) -> PackedFloat32Array:
	var fine := _noise(seed_value, size, 11.0 * k, 4, 0.55)
	var coarse := _noise(seed_value + 1, size, 41.0 * k, 4, 0.55)
	var envelope := _ellipse(size, Vector2(0.5, 0.5), Vector2(0.36, 0.33), 0.5)
	var out := PackedFloat32Array()
	out.resize(size * size)
	for index in out.size():
		# The spray thins toward its edge: a higher bar the further out.
		var bar := (1.0 - envelope[index]) * 0.34
		var a := 1.0 if fine[index] > 0.62 + bar else 0.0
		var b := 1.0 if coarse[index] > 0.71 + bar else 0.0
		out[index] = maxf(a, b) * (1.0 if envelope[index] > 0.0 else 0.0)
	out = _threshold(_blur(out, size, maxi(1, roundi(3.0 * k))), 0.35)
	return _erode_islands(out, size, maxi(1, roundi(6.0 * k * k)))


# --- D2 pool: one low-frequency body, a ragged rim, soft edge.
static func _pool(seed_value: int, size: int, k: float) -> PackedFloat32Array:
	var body_field := _noise(seed_value, size, 260.0 * k, 3, 0.4)
	var rim_field := _noise(seed_value + 1, size, 16.0 * k, 3, 0.5)
	var envelope := _ellipse(size, Vector2(0.5, 0.5), Vector2(0.43, 0.33), 1.0)
	var body := PackedFloat32Array()
	body.resize(size * size)
	for index in body.size():
		body[index] = 1.0 if envelope[index] * 0.78 + body_field[index] * 0.42 > 0.48 else 0.0
	var band := _blur(body, size, maxi(1, roundi(10.0 * k)))
	var out := PackedFloat32Array()
	out.resize(size * size)
	for index in out.size():
		var near_edge := band[index] > 0.2 and band[index] < 0.8
		var rim := 1.0 if near_edge and rim_field[index] > 0.6 else 0.0
		out[index] = maxf(body[index], rim)
	return _smooth_threshold(_blur(out, size, maxi(1, roundi(6.0 * k))), 0.5, 0.08)


# --- D3 drag smear: directional, fresh at -X, tapering to nothing at +X.
static func _drag(seed_value: int, size: int, k: float) -> PackedFloat32Array:
	var stretched := _noise_stretched(seed_value, size, 24.0 * k, 6.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := PackedFloat32Array()
	out.resize(size * size)
	var centre := size * 0.5
	var half := size * 0.2
	for y in size:
		var across := 1.0 - clampf(absf(float(y) - centre) / half, 0.0, 1.0)
		for x in size:
			var along := float(x) / float(size)
			var ramp := 1.0 - along * 0.4 * 2.2
			var start := clampf((along - 0.1) / 0.04, 0.0, 1.0)
			var v := stretched[y * size + x] * 0.55 + across * 0.75
			out[y * size + x] = 1.0 if v * ramp * start > 0.55 else 0.0
	# Four streaks off the body, staggered, the marks of whatever dragged.
	for streak in 4:
		var offset := rng.randf_range(40.0, 120.0) * k * (1.0 if streak % 2 == 0 else -1.0)
		var length := rng.randf_range(0.6, 0.9)
		var y0 := centre + offset
		var x0 := size * 0.1
		var x1 := size * (0.1 + 0.8 * length)
		_stamp_capsule(out, size, Vector2(x0, y0), Vector2(x1, y0 + rng.randf_range(-10.0, 10.0) * k), 4.0 * k, 1.0, 1.4 * k)
	return _smooth_threshold(_blur(out, size, maxi(1, roundi(1.5 * k))), 0.5, 0.1)


# --- D4 handprint: a hand skeleton in metres, then chaos.
static func _handprint(seed_value: int, size: int, k: float) -> PackedFloat32Array:
	var frame := Vector2(0.20, 0.25)
	var px := Vector2(float(size) / frame.x, float(size) / frame.y)
	var to_px := func(metres: Vector2) -> Vector2: return (metres + frame * 0.5) * px
	var out := _filled(size, 0.0)
	# Palm 0.11 x 0.10 m, a rounded block low in the frame.
	var palm_centre := Vector2(0.0, 0.035)
	_stamp_rounded_rect(out, size, to_px.call(palm_centre), Vector2(0.11, 0.10) * px * 0.5, 0.025 * px.x, 1.0)
	# Four fingers splayed 8-22 degrees, and the thumb at 40.
	var fingers := [
		{"base": Vector2(-0.039, -0.012), "angle": -22.0, "length": 0.075},
		{"base": Vector2(-0.013, -0.015), "angle": -8.0, "length": 0.095},
		{"base": Vector2(0.013, -0.015), "angle": 8.0, "length": 0.09},
		{"base": Vector2(0.038, -0.01), "angle": 18.0, "length": 0.075},
	]
	for finger in fingers:
		var direction := Vector2(0.0, -1.0).rotated(deg_to_rad(float(finger.angle)))
		var tip: Vector2 = finger.base + direction * float(finger.length)
		_stamp_capsule_metric(out, size, px, to_px.call(finger.base), to_px.call(tip), 0.01, 1.0)
	var thumb_base := Vector2(-0.05, 0.05)
	var thumb_tip := thumb_base + Vector2(0.0, -1.0).rotated(deg_to_rad(-40.0)) * 0.06
	_stamp_capsule_metric(out, size, px, to_px.call(thumb_base), to_px.call(thumb_tip), 0.012, 1.0)
	# The wrist drag, lighter, behind the palm; and three beads at the wrist.
	_stamp_rounded_rect(out, size, to_px.call(Vector2(0.004, 0.1)), Vector2(0.06, 0.04) * px * 0.5, 0.012 * px.x, 0.4)
	for bead in 3:
		_stamp_ellipse(out, size, to_px.call(Vector2(-0.02 + bead * 0.02, 0.122)), Vector2(0.002, 0.002) * px, 1.0)
	out = _warp(out, size, seed_value, 3.0 * k, 1.5 * k)
	return _smooth_threshold(_blur(out, size, maxi(1, roundi(1.5 * k))), 0.3, 0.12)


# --- D5 drips: 5-9 non-parallel streams from the top edge, each ending in a bulb.
static func _drips(seed_value: int, size: int, k: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mask := _filled(size, 0.0)
	var wet := _filled(size, 0.0)
	var streams: Array = []
	var count := rng.randi_range(5, 9)
	var x := 0.12
	for stream in count:
		x += rng.randf_range(0.04, 0.14)
		if x > 0.9:
			break
		var width := rng.randf_range(6.0, 18.0) * k
		var length := rng.randf_range(0.4, 0.95)
		var top := Vector2(x * size, size * 0.06)
		var drift := rng.randf_range(-12.0, 12.0) * k
		var bottom := Vector2(top.x + drift, size * (0.06 + length * 0.86))
		var steps := 48
		for step_index in steps + 1:
			var t := float(step_index) / float(steps)
			var at := top.lerp(bottom, t)
			# The film is thinnest at the top, where it has run furthest.
			var w := width * (0.5 + 0.5 * t)
			_stamp_ellipse(mask, size, at, Vector2(w * 0.5, w * 0.5), 1.0)
		var bulb := width * 1.6 * 0.5
		_stamp_ellipse(mask, size, bottom, Vector2(bulb, bulb * 1.15), 1.0)
		_stamp_ellipse(wet, size, bottom + Vector2(0, bulb * 0.2), Vector2(bulb, bulb), 1.0)
		streams.append(Vector4(top.x / size, top.y / size, bottom.y / size, bulb / size))
	mask = _blur_horizontal(mask, size, maxi(1, roundi(2.0 * k)))
	return {"mask": _smooth_threshold(mask, 0.45, 0.1), "wet": wet, "streams": streams}


# --- D6 arterial arc: a ballistic curve, a mist tail, heavy leading drops.
static func _arc(seed_value: int, size: int, k: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mask := _filled(size, 0.0)
	var wet := _filled(size, 0.0)
	var reveal := _filled(size, 1.0)
	var p0 := Vector2(0.1, 0.55) * size
	var p1 := Vector2(0.52, 0.02) * size
	var p2 := Vector2(0.95, 0.25) * size
	var samples := 220
	for sample in samples + 1:
		var t := float(sample) / float(samples)
		var at := _bezier(p0, p1, p2, t)
		var w := lerpf(14.0, 3.0, t) * k * 0.5
		_stamp_order(mask, reveal, size, at, w, t)
		if t < 0.3:
			_stamp_ellipse(wet, size, at, Vector2(w, w), 1.0 - t / 0.3)
	# The mist: 90 particles thrown along the tangent, fanned 14 degrees.
	for particle in 90:
		var t := rng.randf_range(0.25, 1.0)
		var at := _bezier(p0, p1, p2, t)
		var tangent := (_bezier(p0, p1, p2, minf(1.0, t + 0.01)) - at).normalized()
		var throw := tangent.rotated(deg_to_rad(rng.randf_range(-14.0, 14.0))) * rng.randf_range(4.0, 60.0) * k
		_stamp_order(mask, reveal, size, at + throw, rng.randf_range(0.6, 1.6) * k, t)
	# Twelve heavy droplets in the first quarter, where the pressure was.
	for drop in 12:
		var t := rng.randf_range(0.02, 0.25)
		var at := _bezier(p0, p1, p2, t) + Vector2(rng.randf_range(-18.0, 18.0), rng.randf_range(-6.0, 22.0)) * k
		var r := rng.randf_range(3.0, 6.0) * k
		_stamp_order(mask, reveal, size, at, r, t)
		_stamp_ellipse(wet, size, at, Vector2(r, r), 1.0)
	return {"mask": _smooth_threshold(_blur(mask, size, 1), 0.4, 0.1), "wet": wet, "reveal": reveal}


# --- D7 one footprint: heel, ball, five toes, a thin film between.
static func _print(seed_value: int, size: int, k: float) -> PackedFloat32Array:
	var frame := Vector2(0.12, 0.30)
	var px := Vector2(float(size) / frame.x, float(size) / frame.y)
	var to_px := func(metres: Vector2) -> Vector2: return (metres + frame * 0.5) * px
	var out := _filled(size, 0.0)
	_stamp_ellipse(out, size, to_px.call(Vector2(0.0, 0.095)), Vector2(0.03, 0.025) * px, 1.0)
	_stamp_ellipse(out, size, to_px.call(Vector2(0.004, -0.035)), Vector2(0.0375, 0.0225) * px, 1.0)
	# The arch is mostly empty: weight on the ball and heel, a film on the outside.
	_stamp_capsule_metric(out, size, px, to_px.call(Vector2(0.018, 0.08)), to_px.call(Vector2(0.024, -0.02)), 0.011, 0.3)
	var toes := [Vector2(-0.024, -0.083), Vector2(-0.005, -0.09), Vector2(0.012, -0.087), Vector2(0.026, -0.08), Vector2(0.037, -0.07)]
	var radii := [0.0115, 0.009, 0.0085, 0.008, 0.007]
	for toe in toes.size():
		_stamp_ellipse(out, size, to_px.call(toes[toe]), Vector2(radii[toe], radii[toe] * 1.15) * px, 1.0)
	out = _warp(out, size, seed_value, 4.0 * k, 2.0 * k)
	return _smooth_threshold(_blur(out, size, maxi(1, roundi(1.5 * k))), 0.25, 0.1)


# --- D8 spatter on tile: power-law droplets, satellites with tails, see-through.
static func _spatter(seed_value: int, size: int, k: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var drops := _filled(size, 0.0)
	var wet := _filled(size, 0.0)
	var centre := Vector2(size, size) * 0.5
	var reach := size * 0.44
	var count := rng.randi_range(40, 70)
	for drop in count:
		# Density falling as r^-1.5: r = reach * u^2 samples that falloff.
		var r := reach * pow(rng.randf(), 2.0)
		var at := centre + Vector2(r, 0.0).rotated(rng.randf() * TAU)
		var radius := (3.0 + 3.0 * pow(rng.randf(), 3.0)) * k
		if drop < 4:
			radius = rng.randf_range(18.0, 30.0) * k
		_stamp_ellipse(drops, size, at, Vector2(radius, radius), 1.0)
		# Three droplets dried right through; four beads that never dry.
		var freshness := 0.0 if drop >= count - 3 else (1.0 if drop in [4, 5, 6, 7] else 0.7)
		_stamp_ellipse(wet, size, at, Vector2(radius * 0.7, radius * 0.7), freshness)
	for satellite in 5:
		var angle := rng.randf() * TAU
		var at := centre + Vector2(reach * rng.randf_range(0.55, 0.85), 0.0).rotated(angle)
		var radius := 15.0 * k
		_stamp_ellipse(drops, size, at, Vector2(radius, radius), 1.0)
		var tail := Vector2(rng.randf_range(20.0, 45.0) * k, 0.0).rotated(angle)
		_stamp_capsule(drops, size, at, at + tail, radius * 0.6, 1.0, radius * 0.1)
		_stamp_ellipse(wet, size, at, Vector2(radius * 0.6, radius * 0.6), 0.7)
	var film := _blur(drops, size, maxi(1, roundi(14.0 * k)))
	var mask := PackedFloat32Array()
	mask.resize(size * size)
	for index in mask.size():
		# Opacity maxes at 0.85 in a droplet and 0.35 in the film, so the
		# grout reads through.
		var core := 0.85 if drops[index] > 0.5 else 0.0
		mask[index] = maxf(core, minf(0.35, film[index] * 0.9))
	return {"mask": mask, "wet": wet}


# --- maps ---

static func _interior(mask: PackedFloat32Array, size: int, radius: float, low: float, high: float) -> PackedFloat32Array:
	var depth := _blur(mask, size, maxi(1, roundi(radius)))
	var out := PackedFloat32Array()
	out.resize(size * size)
	for index in out.size():
		out[index] = smoothstep(low, high, depth[index]) * mask[index]
	return out


static func _ramp_x(mask: PackedFloat32Array, size: int, from: float, to: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(size * size)
	for y in size:
		for x in size:
			out[y * size + x] = lerpf(from, to, float(x) / float(size)) * mask[y * size + x]
	return out


## Where spreading reaches first: the thick middle, then out to the edge.
static func _spread_order(mask: PackedFloat32Array, size: int, k: float) -> PackedFloat32Array:
	var depth := _blur(mask, size, maxi(1, roundi(24.0 * k)))
	var out := PackedFloat32Array()
	out.resize(size * size)
	for index in out.size():
		out[index] = 1.0 - clampf(depth[index], 0.0, 1.0)
	return out


static func _flow_image(id: String, mask: PackedFloat32Array, reveal: PackedFloat32Array, size: int, k: float) -> Image:
	var soft := _blur(mask, size, maxi(1, roundi(12.0 * k)))
	var bytes := PackedByteArray()
	bytes.resize(size * size * 3)
	for y in size:
		for x in size:
			var index := y * size + x
			var direction := Vector2(1.0, 0.0)
			if id != "d3_drag":
				# Blood spreads downhill of its own thickness: outward.
				var gx := soft[y * size + mini(size - 1, x + 1)] - soft[y * size + maxi(0, x - 1)]
				var gy := soft[mini(size - 1, y + 1) * size + x] - soft[maxi(0, y - 1) * size + x]
				direction = -Vector2(gx, gy)
				direction = direction.normalized() if direction.length() > 0.0001 else Vector2.ZERO
			bytes[index * 3] = _byte(direction.x * 0.5 + 0.5)
			bytes[index * 3 + 1] = _byte(direction.y * 0.5 + 0.5)
			bytes[index * 3 + 2] = _byte(reveal[index])
	return Image.create_from_data(size, size, false, Image.FORMAT_RGB8, bytes)


## Section 2's roughness contract: fresh 0.08-0.16, drying up to a crust of
## 0.58-0.78, never fully matte.
static func _orm_image(mask: PackedFloat32Array, wet: PackedFloat32Array, crust: PackedFloat32Array, size: int) -> Image:
	var bytes := PackedByteArray()
	bytes.resize(size * size * 3)
	for index in size * size:
		var w := wet[index]
		var dry_rough := lerpf(0.58, 0.78, crust[index])
		var rough := lerpf(dry_rough, lerpf(0.08, 0.16, crust[index]), w)
		var occlusion := lerpf(1.0, 0.55, (1.0 - w) * mask[index])
		bytes[index * 3] = _byte(occlusion)
		bytes[index * 3 + 1] = _byte(rough)
		bytes[index * 3 + 2] = 0
	return Image.create_from_data(size, size, false, Image.FORMAT_RGB8, bytes)


## The meniscus from the soft height, and crust where it has dried.
static func _normal_image(height: PackedFloat32Array, crust: PackedFloat32Array, wet: PackedFloat32Array, size: int) -> Image:
	var h := PackedFloat32Array()
	h.resize(size * size)
	for index in h.size():
		h[index] = height[index] + (crust[index] - 0.5) * 0.35 * (1.0 - wet[index]) * height[index]
	var bytes := PackedByteArray()
	bytes.resize(size * size * 3)
	var strength := 6.0
	for y in size:
		for x in size:
			var dx := (h[y * size + mini(size - 1, x + 1)] - h[y * size + maxi(0, x - 1)]) * strength
			var dy := (h[mini(size - 1, y + 1) * size + x] - h[maxi(0, y - 1) * size + x]) * strength
			var n := Vector3(-dx, -dy, 1.0).normalized()
			var index := (y * size + x) * 3
			bytes[index] = _byte(n.x * 0.5 + 0.5)
			bytes[index + 1] = _byte(n.y * 0.5 + 0.5)
			bytes[index + 2] = _byte(n.z * 0.5 + 0.5)
	return Image.create_from_data(size, size, false, Image.FORMAT_RGB8, bytes)


# --- primitives (section 5, CPU side) ---

static func _noise(seed_value: int, size: int, feature_px: float, octaves: int, gain: float) -> PackedFloat32Array:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 1.0 / maxf(1.0, feature_px)
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.fractal_gain = gain
	return _from_l8(noise.get_image(size, size, false, false, true), size)


## Noise stretched `ratio`:1 along X, for directional structure.
static func _noise_stretched(seed_value: int, size: int, feature_px: float, ratio: float) -> PackedFloat32Array:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 1.0 / maxf(1.0, feature_px)
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	var narrow := maxi(4, roundi(size / ratio))
	var image := noise.get_image(narrow, size, false, false, true)
	image.resize(size, size, Image.INTERPOLATE_BILINEAR)
	return _from_l8(image, size)


static func _ellipse(size: int, centre: Vector2, radii: Vector2, softness: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(size * size)
	for y in size:
		for x in size:
			var d := ((Vector2(x, y) / float(size) - centre) / radii).length()
			out[y * size + x] = clampf((1.0 - d) / maxf(0.001, softness), 0.0, 1.0)
	return out


static func _threshold(a: PackedFloat32Array, bar: float) -> PackedFloat32Array:
	var out := a.duplicate()
	for index in out.size():
		out[index] = 1.0 if a[index] > bar else 0.0
	return out


static func _smooth_threshold(a: PackedFloat32Array, bar: float, soft: float) -> PackedFloat32Array:
	var out := a.duplicate()
	for index in out.size():
		out[index] = smoothstep(bar - soft, bar + soft, a[index])
	return out


## Separable box blur, twice, which is close enough to a gaussian.
static func _blur(a: PackedFloat32Array, size: int, radius: int) -> PackedFloat32Array:
	var out := a
	for pass_index in 2:
		out = _blur_horizontal(out, size, radius)
		out = _blur_vertical(out, size, radius)
	return out


static func _blur_horizontal(a: PackedFloat32Array, size: int, radius: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(size * size)
	var span := float(radius * 2 + 1)
	for y in size:
		var row := y * size
		var sum := 0.0
		for x in range(-radius, radius + 1):
			sum += a[row + clampi(x, 0, size - 1)]
		for x in size:
			out[row + x] = sum / span
			sum += a[row + mini(size - 1, x + radius + 1)] - a[row + maxi(0, x - radius)]
	return out


static func _blur_vertical(a: PackedFloat32Array, size: int, radius: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(size * size)
	var span := float(radius * 2 + 1)
	for x in size:
		var sum := 0.0
		for y in range(-radius, radius + 1):
			sum += a[clampi(y, 0, size - 1) * size + x]
		for y in size:
			out[y * size + x] = sum / span
			sum += a[mini(size - 1, y + radius + 1) * size + x] - a[maxi(0, y - radius) * size + x]
	return out


## Drops every island of ink smaller than `min_area` pixels.
static func _erode_islands(a: PackedFloat32Array, size: int, min_area: int) -> PackedFloat32Array:
	var out := a.duplicate()
	var seen := PackedByteArray()
	seen.resize(size * size)
	var stack := PackedInt32Array()
	var island := PackedInt32Array()
	for start in out.size():
		if seen[start] == 1 or out[start] < 0.5:
			continue
		island.clear()
		stack.append(start)
		seen[start] = 1
		while not stack.is_empty():
			var index: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			island.append(index)
			var x := index % size
			var y := index / size
			for neighbour in [index - 1 if x > 0 else -1, index + 1 if x < size - 1 else -1, index - size if y > 0 else -1, index + size if y < size - 1 else -1]:
				if neighbour >= 0 and seen[neighbour] == 0 and out[neighbour] >= 0.5:
					seen[neighbour] = 1
					stack.append(neighbour)
		if island.size() < min_area:
			for index in island:
				out[index] = 0.0
	return out


## Pushes the mask around by a noise field so edges aren't mechanically clean.
static func _warp(a: PackedFloat32Array, size: int, seed_value: int, feature_px: float, displacement: float) -> PackedFloat32Array:
	var fx := _noise(seed_value + 17, size, maxf(2.0, feature_px * 4.0), 2, 0.5)
	var fy := _noise(seed_value + 29, size, maxf(2.0, feature_px * 4.0), 2, 0.5)
	var out := PackedFloat32Array()
	out.resize(size * size)
	for y in size:
		for x in size:
			var index := y * size + x
			var sx := clampi(roundi(x + (fx[index] - 0.5) * 2.0 * displacement), 0, size - 1)
			var sy := clampi(roundi(y + (fy[index] - 0.5) * 2.0 * displacement), 0, size - 1)
			out[index] = a[sy * size + sx]
	return out


static func _stamp_ellipse(a: PackedFloat32Array, size: int, centre: Vector2, radii: Vector2, value: float) -> void:
	var r := Vector2(maxf(0.5, radii.x), maxf(0.5, radii.y))
	for y in range(maxi(0, floori(centre.y - r.y)), mini(size, ceili(centre.y + r.y) + 1)):
		for x in range(maxi(0, floori(centre.x - r.x)), mini(size, ceili(centre.x + r.x) + 1)):
			var d := ((Vector2(x, y) - centre) / r).length()
			if d <= 1.0:
				a[y * size + x] = maxf(a[y * size + x], value)


## A capsule from `from` to `to`, radius tapering from `radius` to `end_radius`.
static func _stamp_capsule(a: PackedFloat32Array, size: int, from: Vector2, to: Vector2, radius: float, value: float, end_radius: float = -1.0) -> void:
	var tail := radius if end_radius < 0.0 else end_radius
	var steps := maxi(2, ceili(from.distance_to(to) / maxf(0.5, minf(radius, tail) * 0.5)))
	for step_index in steps + 1:
		var t := float(step_index) / float(steps)
		var r := lerpf(radius, tail, t)
		_stamp_ellipse(a, size, from.lerp(to, t), Vector2(r, r), value)


## A capsule whose radius is in metres, drawn into a frame with its own
## pixels-per-metre on each axis, so it stays round in the world.
static func _stamp_capsule_metric(a: PackedFloat32Array, size: int, px: Vector2, from: Vector2, to: Vector2, radius_m: float, value: float) -> void:
	var steps := maxi(2, ceili(from.distance_to(to) / 2.0))
	for step_index in steps + 1:
		_stamp_ellipse(a, size, from.lerp(to, float(step_index) / float(steps)), px * radius_m, value)


static func _stamp_rounded_rect(a: PackedFloat32Array, size: int, centre: Vector2, half: Vector2, corner: float, value: float) -> void:
	for y in range(maxi(0, floori(centre.y - half.y)), mini(size, ceili(centre.y + half.y) + 1)):
		for x in range(maxi(0, floori(centre.x - half.x)), mini(size, ceili(centre.x + half.x) + 1)):
			var q := (Vector2(x, y) - centre).abs() - half + Vector2(corner, corner)
			var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - corner
			if d <= 0.0:
				a[y * size + x] = maxf(a[y * size + x], value)


## A disc that also records when along its curve it was laid (for ARC_DRAW).
static func _stamp_order(mask: PackedFloat32Array, order: PackedFloat32Array, size: int, centre: Vector2, radius: float, t: float) -> void:
	var r := maxf(0.6, radius)
	for y in range(maxi(0, floori(centre.y - r)), mini(size, ceili(centre.y + r) + 1)):
		for x in range(maxi(0, floori(centre.x - r)), mini(size, ceili(centre.x + r) + 1)):
			if Vector2(x, y).distance_to(centre) <= r:
				var index := y * size + x
				mask[index] = 1.0
				order[index] = minf(order[index], t)


static func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	return p0.lerp(p1, t).lerp(p1.lerp(p2, t), t)


static func _filled(size: int, value: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(size * size)
	out.fill(value)
	return out


static func _from_l8(image: Image, size: int) -> PackedFloat32Array:
	if image.get_format() != Image.FORMAT_L8:
		image.convert(Image.FORMAT_L8)
	var bytes := image.get_data()
	var out := PackedFloat32Array()
	out.resize(size * size)
	for index in out.size():
		out[index] = float(bytes[index]) / 255.0
	return out


static func _image_l8(a: PackedFloat32Array, size: int) -> Image:
	var bytes := PackedByteArray()
	bytes.resize(size * size)
	for index in a.size():
		bytes[index] = _byte(a[index])
	return Image.create_from_data(size, size, false, Image.FORMAT_L8, bytes)


static func _byte(value: float) -> int:
	return clampi(roundi(value * 255.0), 0, 255)
