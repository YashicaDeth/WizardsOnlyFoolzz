class_name BlackMirror
extends RefCounted

## I0.5. The handheld's shell, re-specified by Greg: *"the internet portal
## through the black mirror phone device with a jester design on the back of the
## black cracked mirror you look into."*
##
## The distinction is the whole design. A screen is a thing you **read** — it
## sits in front of you and prints at you. A mirror is a thing you **look into**,
## which means the surface is dark and reflective *before* it is informational,
## content surfaces up out of the depth rather than being stamped on the front,
## and something is always looking back.
##
## So the glass here is drawn in four layers, back to front:
##
##   1. the black, which is nearly all of it;
##   2. the reflection — the reader's own face, unreliable;
##   3. the cracks, which are damage to a mirror rather than dead LCD pixels;
##   4. the content, which the page draws on top and which the glass tints.
##
## The jester lives on the back of the case: CellOutz sold you a fool's errand,
## and the collective above is literally called wizardsonlyfoolz. The joke is
## supposed to land twice.

const GLASS := Color("05060a")
const SHEEN := Color("2a3340")
const CRACK := Color("8f9cab")
const REFLECT := Color("1a2029")
const JESTER := Color("7d2230")
const BELL := Color("c9a23a")
## C10.2. The mirror remains black around the working aperture, but the area
## being read has its own phosphor bed. This is shared glass behaviour rather
## than six page backgrounds, so changing apps cannot change whether the
## device is usable after dark.
const READING_EDGE := Color("07100e")
const READING_CENTRE := Color("0c1b17")
const READING_LIP := Color("6f9478")
const NIGHT_PHOSPHOR := Color("b9f5cf")


## Camera telemetry for the Black Mirror's rear sensor. This is deliberately a
## camera model rather than a colour effect: exposure and gain adapt at
## different rates, gain creates noise, clipped highlights bloom, focus hunts
## under motion/low contrast, and the sensor reports a battery load for the
## device controller to consume.
static func night_vision_state(overrides: Dictionary = {}) -> Dictionary:
	var state := {
		"enabled": false,
		"gain": 1.0,
		"exposure": 1.0,
		"noise": 0.0,
		"bloom": 0.0,
		"focus_distance": 3.0,
		"focus_confidence": 1.0,
		"battery": 1.0,
		"battery_draw": 0.0,
		"drain_per_second": 0.0025,
		"sensor_temperature": 0.0,
	}
	state.merge(overrides, true)
	return state


## Advances a sensor state by one frame. `sample` accepts ambient_luminance
## (0..1), highlight_luminance (0..1), subject_distance, contrast and motion.
## Supplying battery in either dictionary is an integration hook for whatever
## inventory/power system ultimately owns the handset charge.
static func step_night_vision(previous: Dictionary, sample: Dictionary, delta: float) -> Dictionary:
	var state := night_vision_state(previous)
	var dt := maxf(0.0, delta)
	if sample.has("battery"):
		state.battery = clampf(float(sample.battery), 0.0, 1.0)
	var requested := bool(sample.get("enabled", state.enabled))
	state.enabled = requested and float(state.battery) > 0.001
	if not state.enabled:
		state.gain = move_toward(float(state.gain), 1.0, dt * 4.0)
		state.exposure = move_toward(float(state.exposure), 1.0, dt * 2.0)
		state.noise = move_toward(float(state.noise), 0.0, dt * 3.0)
		state.bloom = move_toward(float(state.bloom), 0.0, dt * 4.0)
		state.battery_draw = 0.0
		return state

	var ambient := clampf(float(sample.get("ambient_luminance", 0.05)), 0.0005, 1.0)
	var highlights := clampf(float(sample.get("highlight_luminance", ambient)), 0.0, 1.0)
	var contrast := clampf(float(sample.get("contrast", 0.5)), 0.0, 1.0)
	var motion := clampf(float(sample.get("motion", 0.0)), 0.0, 1.0)
	# Exposure reacts slowly; electronic gain catches up fast and is capped so
	# darkness remains darkness instead of becoming a flat green daylight scene.
	var target_exposure := clampf(0.18 / ambient, 0.7, 5.5)
	var target_gain := clampf(0.32 / (ambient * target_exposure), 1.0, 18.0)
	state.exposure = move_toward(float(state.exposure), target_exposure, dt * 1.4)
	state.gain = move_toward(float(state.gain), target_gain, dt * 9.0)
	var gain_pressure := clampf((float(state.gain) - 1.0) / 17.0, 0.0, 1.0)
	state.sensor_temperature = move_toward(float(state.sensor_temperature), gain_pressure, dt * 0.18)
	state.noise = clampf(gain_pressure * 0.62 + float(state.sensor_temperature) * 0.25 + motion * 0.13, 0.0, 1.0)
	state.bloom = clampf(maxf(0.0, highlights * float(state.exposure) - 0.72) * (0.4 + gain_pressure), 0.0, 1.0)

	var subject_distance := clampf(float(sample.get("subject_distance", state.focus_distance)), 0.25, 200.0)
	var focus_speed := lerpf(8.0, 1.2, clampf((1.0 - contrast) * 0.7 + motion * 0.5, 0.0, 1.0))
	state.focus_distance = move_toward(float(state.focus_distance), subject_distance, dt * focus_speed)
	var focus_error := absf(float(state.focus_distance) - subject_distance) / maxf(subject_distance, 0.25)
	state.focus_confidence = clampf(contrast * (1.0 - motion * 0.65) * (1.0 - minf(focus_error, 1.0)), 0.0, 1.0)

	state.battery_draw = float(state.drain_per_second) * (1.0 + gain_pressure * 1.8 + float(state.bloom) * 0.35)
	state.battery = maxf(0.0, float(state.battery) - float(state.battery_draw) * dt)
	if float(state.battery) <= 0.001:
		state.enabled = false
	return state


## Converts a captured colour after the telemetry has been stepped. The caller
## can use this in a canvas shader equivalent later; keeping a deterministic CPU
## reference here makes the sensor response testable and documents the contract.
static func night_vision_sample(source: Color, state: Dictionary, sensor_uv: Vector2, clock: float) -> Color:
	if not bool(state.get("enabled", false)):
		return source
	var luminance := source.r * 0.2126 + source.g * 0.7152 + source.b * 0.0722
	var sensed_light := luminance * float(state.get("exposure", 1.0)) * float(state.get("gain", 1.0))
	# Deterministic analogue grain and a faint rolling scan band. Neither changes
	# scene geometry, so this remains safe as a shader/reference implementation.
	var seed_value := sin(sensor_uv.dot(Vector2(12.9898, 78.233)) + floor(clock * 30.0) * 0.173) * 43758.5453
	var grain := (fposmod(seed_value, 1.0) - 0.5) * float(state.get("noise", 0.0)) * 0.32
	var scan := sin((sensor_uv.y + clock * 0.12) * 780.0) * 0.018
	var resolved := clampf(sensed_light + grain + scan, 0.0, 1.0)
	var phosphor := NIGHT_PHOSPHOR * resolved
	var bloom := float(state.get("bloom", 0.0)) * smoothstep(0.68, 1.0, resolved)
	return Color(clampf(phosphor.r + bloom * 0.35, 0.0, 1.0), clampf(phosphor.g + bloom * 0.55, 0.0, 1.0), clampf(phosphor.b + bloom * 0.42, 0.0, 1.0), source.a)


## The dark ground the whole device sits on. Drawn first; everything else is
## depth added to it.
static func draw_glass(canvas: CanvasItem, rect: Rect2, alpha: float, clock: float) -> void:
	canvas.draw_rect(rect, GLASS * Color(1, 1, 1, alpha))
	# A slow sheen crossing the glass, so it reads as a surface with an angle to
	# it rather than as a black rectangle.
	var sweep := fposmod(clock * 0.11, 1.6) - 0.3
	var band := rect.size.x * 0.42
	var at := rect.position.x + rect.size.x * sweep
	for step in 7:
		var offset := float(step) / 7.0
		canvas.draw_rect(
			Rect2(at + offset * band * 0.4, rect.position.y, band * 0.18, rect.size.y),
			SHEEN * Color(1, 1, 1, (0.05 - offset * 0.006) * alpha)
		)


## The reader, in the glass. Deliberately vague — a silhouette and two lights
## where eyes are, moving slightly out of time with the viewer. `presence` is
## how strongly they show: a bright page hides the reflection, a dark one does
## not, which is true of real glass and also means the mirror asserts itself
## most when there is least to read.
static func draw_reflection(canvas: CanvasItem, rect: Rect2, alpha: float, clock: float, presence: float) -> void:
	if presence <= 0.01:
		return
	var centre := rect.get_center() + Vector2(sin(clock * 0.23) * 6.0, cos(clock * 0.17) * 4.0)
	var scale := minf(rect.size.x, rect.size.y) * 0.5
	var tint := REFLECT * Color(1, 1, 1, presence * alpha)

	# Head and shoulders, low contrast, slightly off-centre.
	canvas.draw_colored_polygon(_ellipse(centre + Vector2(0, -scale * 0.12), scale * 0.19, scale * 0.24, 18), tint)
	canvas.draw_colored_polygon(PackedVector2Array([
		centre + Vector2(-scale * 0.46, scale * 0.62),
		centre + Vector2(-scale * 0.24, scale * 0.14),
		centre + Vector2(scale * 0.24, scale * 0.14),
		centre + Vector2(scale * 0.46, scale * 0.62),
	]), tint)

	# Two lights where the eyes are. They blink on their own schedule, which is
	# the part that makes it look back rather than sit there.
	var blink := sin(clock * 0.9) * sin(clock * 2.3)
	if blink > -0.72:
		for side in [-1.0, 1.0]:
			canvas.draw_circle(centre + Vector2(side * scale * 0.075, -scale * 0.14), maxf(1.0, scale * 0.012), CRACK * Color(1, 1, 1, 0.5 * presence * alpha))


## The readable part of the black mirror. Drawn after the broad reflection and
## before page content: the reader still exists in the surrounding glass, but
## never sits at equal weight behind type, chart marks or instrument needles.
## Layered insets make emitted light belong to the glass instead of looking
## like a flat UI rectangle.
static func draw_reading_bed(canvas: CanvasItem, rect: Rect2, alpha: float, light_level: float) -> void:
	if rect.size.x <= 2.0 or rect.size.y <= 2.0:
		return
	var energy := clampf(light_level, 0.0, 1.0)
	canvas.draw_rect(rect, READING_EDGE * Color(1, 1, 1, 0.94 * alpha))
	for layer in 6:
		var through := float(layer + 1) / 6.0
		var inset := minf(rect.size.x, rect.size.y) * through * 0.055
		var tone := READING_EDGE.lerp(READING_CENTRE, through)
		canvas.draw_rect(rect.grow(-inset), tone * Color(1, 1, 1, (0.24 + energy * 0.10) * alpha))
	var lip := READING_LIP * Color(1, 1, 1, (0.18 + energy * 0.16) * alpha)
	canvas.draw_rect(rect.grow(-1.0), lip, false, 1.0)


## Testable colour contract for the shared reading surface. Kept here beside
## the renderer so a later palette pass cannot quietly make the night aperture
## brighter than its smallest labels.
static func reading_contrast(foreground: Color, opacity := 1.0, centre := READING_CENTRE) -> float:
	var composited := centre.lerp(foreground, clampf(opacity * foreground.a, 0.0, 1.0))
	var bright := _relative_luminance(composited)
	var dark := _relative_luminance(centre)
	return (maxf(bright, dark) + 0.05) / (minf(bright, dark) + 0.05)


static func _relative_luminance(colour: Color) -> float:
	return 0.2126 * _linear_channel(colour.r) + 0.7152 * _linear_channel(colour.g) + 0.0722 * _linear_channel(colour.b)


static func _linear_channel(channel: float) -> float:
	return channel / 12.92 if channel <= 0.04045 else pow((channel + 0.055) / 1.055, 2.4)


## Damage to a mirror: long forks from an impact point, not a grid of dead
## pixels. Deterministic from `seed_value`, so the same device is always broken
## in the same places.
## C5.6 v3. `origin_norm` used to not exist at all — every device, every
## impact, cracked from the exact same point (74%, 22% into the rect)
## regardless of where anything actually happened to it. An impact should
## crack the glass where it landed, so the caller now says where that was
## (normalised 0..1 within `rect`); the old fixed point is only the default
## for a caller that genuinely has no location to give.
static func draw_cracks(canvas: CanvasItem, rect: Rect2, alpha: float, seed_value: int, severity: float, origin_norm := Vector2(0.74, 0.22)) -> void:
	if severity <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var origin := rect.position + rect.size * origin_norm
	var forks := 3 + int(severity * 6.0)
	for fork in forks:
		var heading := rng.randf() * TAU
		var length := (0.25 + rng.randf() * 0.7) * minf(rect.size.x, rect.size.y)
		var points := PackedVector2Array([origin])
		var cursor := origin
		var steps := 3 + rng.randi_range(0, 3)
		for step in steps:
			heading += rng.randf_range(-0.42, 0.42)
			cursor += Vector2.from_angle(heading) * (length / float(steps))
			points.append(cursor)
		canvas.draw_polyline(points, CRACK * Color(1, 1, 1, 0.18 * severity * alpha), 1.0)
		# The bright edge that catches light along one side of a real crack.
		canvas.draw_polyline(points, Color(1, 1, 1, 0.05 * severity * alpha), 2.4)
	canvas.draw_circle(origin, 3.0, CRACK * Color(1, 1, 1, 0.3 * severity * alpha))


## The jester on the back of the case. Shown when the device is turned over,
## and as a small pressed mark on the front bezel the rest of the time.
static func draw_jester(canvas: CanvasItem, at: Vector2, size: float, alpha: float, clock: float) -> void:
	var sway := sin(clock * 1.3) * size * 0.05
	# Three-pointed hood, a bell on each point.
	var points := PackedVector2Array([
		at + Vector2(0, size * 0.26),
		at + Vector2(-size * 0.52, -size * 0.06),
		at + Vector2(-size * 0.30, -size * 0.44) + Vector2(sway, 0),
		at + Vector2(0, -size * 0.14),
		at + Vector2(size * 0.30, -size * 0.44) - Vector2(sway, 0),
		at + Vector2(size * 0.52, -size * 0.06),
	])
	canvas.draw_colored_polygon(points, JESTER * Color(1, 1, 1, 0.85 * alpha))
	for bell in [Vector2(-size * 0.30, -size * 0.44) + Vector2(sway, 0), Vector2(size * 0.30, -size * 0.44) - Vector2(sway, 0), Vector2(-size * 0.52, -size * 0.06), Vector2(size * 0.52, -size * 0.06)]:
		canvas.draw_circle(at + bell, size * 0.07, BELL * Color(1, 1, 1, 0.9 * alpha))
	# The face is a hole. Nothing in the hood, which is the joke.
	canvas.draw_colored_polygon(_ellipse(at + Vector2(0, size * 0.06), size * 0.22, size * 0.26, 16), GLASS * Color(1, 1, 1, alpha))
	for side in [-1.0, 1.0]:
		canvas.draw_circle(at + Vector2(side * size * 0.08, size * 0.02), size * 0.03, BELL * Color(1, 1, 1, 0.5 * alpha))
	# A grin drawn as a curve of teeth rather than a line.
	for tooth in 5:
		var t := float(tooth) / 4.0
		var x := lerpf(-size * 0.11, size * 0.11, t)
		var y := size * 0.14 + sin(t * PI) * size * 0.05
		canvas.draw_rect(Rect2(at + Vector2(x - size * 0.015, y), Vector2(size * 0.03, size * 0.045)), BELL * Color(1, 1, 1, 0.6 * alpha))


static func _ellipse(centre: Vector2, radius_x: float, radius_y: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in segments:
		var angle := TAU * float(index) / float(segments)
		points.append(centre + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points
