extends Control

## AG4.2. Blood on the lens.
##
## Greg: *"in the first person it has that blood splatter effects and just
## generally in the game make that more integral or just do more instead of just
## being lame asf"*.
##
## The world spray was the only blood in the game: small spheres that fly, land
## and stain the floor. Correct, and completely absent from the one surface the
## player is actually looking at. You can open a man's throat from half a metre
## away in this game and walk off clean, which is the single biggest reason the
## first person reads as watching violence rather than committing it.
##
## So: you wear it. Four things make this read as blood on a lens rather than as
## a red overlay, and all four are the difference between this and the effect
## Greg is calling lame.
##
##   - **Spatter has direction.** A dose arrives from somewhere — the tail
##     points back along the blow, because that is where the arm was.
##   - **It has depth.** Some of it is on the near glass and out of focus: big,
##     soft, pale. Some is in focus: small, sharp, nearly black. A single
##     uniform layer is what makes screen blood look like a filter.
##   - **It runs.** A heavy drop is too heavy to hold and it goes down the
##     glass, tapering, leaving the track it took.
##   - **It dries.** Arterial red for a few seconds, then brown, then a stain
##     that is still there a minute later. Nothing here disappears cleanly.
##
## The centre of the screen is kept clearer than the edges on purpose. This is
## meant to be felt, not to take the game off you.

const ARTERIAL := Color("8e0f0c")
const VENOUS := Color("5a0a14")
const DRIED := Color("39201a")
const FILM := Color("c25b3c")

## Past this many doses the glass is saturated and new ones replace old rather
## than stacking, so a long fight cannot end in an opaque red screen.
const MAX_MARKS := 46
## Seconds for a mark to go from arterial to dry. Deliberately long.
const DRYING := 22.0
## And how long after that before it is gone entirely.
const FADING := 70.0

var marks: Array = []
var _rng := RandomNumberGenerator.new()
var _clock := 0.0
## Rises on a heavy dose and falls away: a brief wet sheen over everything,
## which is what actually sells the moment of being sprayed.
var sheen := 0.0


func _init() -> void:
	name = "BloodVeil"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Take a dose. `strength` is 0..1 — a graze against a severed artery. `from` is
## a screen-space direction the blood arrived along, normalised, which is what
## gives the spatter its tail; pass Vector2.ZERO for a dose with no direction,
## like standing over something that burst.
func splash(strength: float, from := Vector2.ZERO) -> void:
	var force := clampf(strength, 0.0, 1.0)
	if force <= 0.01:
		return
	sheen = minf(1.0, sheen + force * 0.8)
	var count := 3 + roundi(force * 14.0)
	# Where on the glass it lands. A directional dose lands biased toward the
	# side it came from, rather than evenly over the screen.
	var anchor := size * 0.5
	if from.length() > 0.01:
		anchor += from.normalized() * size.length() * 0.22
	for index in count:
		var scatter := size.length() * (0.06 + _rng.randf() * 0.30) * (0.6 + force)
		var at := anchor + Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)).normalized() * scatter
		# Keep the middle of the screen readable. A mark that lands dead centre
		# is pushed outward rather than dropped, so the dose is not quietly
		# smaller when you are looking straight at what you hit.
		var from_centre := at - size * 0.5
		var clear := size.y * 0.16
		if from_centre.length() < clear and from_centre.length() > 0.01:
			at = size * 0.5 + from_centre.normalized() * clear
		_add_mark(at, force, from)
	while marks.size() > MAX_MARKS:
		marks.pop_front()
	queue_redraw()


func _add_mark(at: Vector2, force: float, from: Vector2) -> void:
	# Depth. About a third of every dose lands on the near glass, where it is
	# large, soft and pale because it is far outside the focal plane. The rest
	# is sharp. Mixing the two is what stops this reading as one flat layer.
	var near := _rng.randf() < 0.34
	var radius := (_rng.randf_range(16.0, 46.0) if near else _rng.randf_range(3.0, 15.0)) * (0.6 + force * 0.8)
	marks.append({
		"at": at,
		"radius": radius,
		"near": near,
		"born": _clock,
		# Heavy, in-focus marks run. A soft near-glass smear does not: it is
		# spread too thin to gather.
		"runs": (not near) and radius > 8.0 and _rng.randf() < 0.7,
		"run": 0.0,
		"run_speed": _rng.randf_range(6.0, 26.0) * (0.5 + force),
		"seed": _rng.randi(),
		# The cast-off tail, pointing back the way the blood came.
		"tail": from.normalized() * radius * _rng.randf_range(1.2, 3.4) if from.length() > 0.01 else Vector2.ZERO,
		"satellites": _rng.randi_range(2, 6),
	})


func _process(delta: float) -> void:
	_clock += delta
	sheen = maxf(0.0, sheen - delta * 1.35)
	var moving := false
	for mark: Dictionary in marks:
		if not bool(mark.get("runs", false)):
			continue
		var age: float = _clock - float(mark["born"])
		# It runs while it is wet and stops as it dries, which is why a track
		# has a head at the bottom and nothing new above it.
		if age > DRYING * 0.55:
			continue
		mark["run"] = float(mark["run"]) + float(mark["run_speed"]) * delta
		moving = true
	# Marks expire from the front, and the list is built oldest-first.
	while not marks.is_empty() and _clock - float(marks[0]["born"]) > DRYING + FADING:
		marks.pop_front()
		moving = true
	if moving or sheen > 0.01:
		queue_redraw()


func _draw() -> void:
	if marks.is_empty() and sheen <= 0.01:
		return

	# The wet sheen: a brief warm film over the whole lens the instant a heavy
	# dose lands. Gone within a second and a half, and doing most of the work of
	# making the hit land.
	if sheen > 0.01:
		draw_rect(Rect2(Vector2.ZERO, size), Color(FILM, sheen * 0.13))

	for mark: Dictionary in marks:
		var age: float = _clock - float(mark["born"])
		var drying := clampf(age / DRYING, 0.0, 1.0)
		var life := 1.0 - clampf((age - DRYING) / FADING, 0.0, 1.0)
		if life <= 0.0:
			continue
		# Arterial into venous into dry brown. Two steps, not one, because blood
		# does not go straight from red to brown and the middle is what makes it
		# look like it is drying rather than fading.
		var tint: Color = ARTERIAL.lerp(VENOUS, minf(drying * 2.0, 1.0)).lerp(DRIED, maxf(drying * 2.0 - 1.0, 0.0))
		var near := bool(mark["near"])
		var alpha: float = life * (0.30 if near else 0.82)
		var at: Vector2 = mark["at"] + Vector2(0.0, float(mark["run"]))
		var radius: float = mark["radius"]

		if bool(mark.get("runs", false)) and float(mark["run"]) > 1.0:
			_draw_run(mark, at, radius, tint, alpha)
		_draw_blot(mark, at, radius, tint, alpha, near)


## The track a running drop leaves: a taper from where it started to where it is
## now, thinning as it goes because it is leaving blood behind it.
func _draw_run(mark: Dictionary, head: Vector2, radius: float, tint: Color, alpha: float) -> void:
	var travelled: float = mark["run"]
	var steps := clampi(roundi(travelled / 7.0), 1, 26)
	for step in steps:
		var along := float(step) / float(steps)
		var point := head - Vector2(0.0, travelled * along)
		# Tracks wander: a drop on glass follows what is already wet.
		var wobble := sin(along * 7.0 + float(mark["seed"] % 17)) * radius * 0.22
		draw_circle(point + Vector2(wobble, 0.0), radius * (0.82 - along * 0.62), Color(tint, alpha * (1.0 - along * 0.55)))


## The mark itself. Not a circle — a circle is exactly what makes screen blood
## look cheap. A blot is a lumpy body with satellites thrown off around it and,
## when the dose had direction, a tail pointing back along it.
func _draw_blot(mark: Dictionary, at: Vector2, radius: float, tint: Color, alpha: float, near: bool) -> void:
	var seed_value: int = mark["seed"]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	# The body, as an irregular polygon rather than a disc.
	var points := PackedVector2Array()
	var lobes := 11
	for index in lobes:
		var angle := TAU * float(index) / float(lobes)
		var reach := radius * (0.74 + rng.randf() * 0.5)
		points.append(at + Vector2(cos(angle), sin(angle)) * reach)
	draw_colored_polygon(points, Color(tint, alpha))

	# A darker centre. Blood pools thickest in the middle of a mark and that
	# gradient is most of what reads as wet.
	if not near:
		draw_circle(at, radius * 0.45, Color(tint.darkened(0.35), alpha * 0.8))

	# Cast-off: the thin tail flung back along the blow.
	var tail: Vector2 = mark["tail"]
	if tail.length() > 1.0:
		var steps := 7
		for step in range(1, steps + 1):
			var along := float(step) / float(steps)
			draw_circle(at + tail * along, radius * 0.4 * (1.0 - along), Color(tint, alpha * (1.0 - along) * 0.85))

	# Satellite droplets. A drop striking glass throws a ring of smaller ones,
	# and their absence is why a plain disc never looks like impact.
	for _index in int(mark["satellites"]):
		var angle := rng.randf() * TAU
		var distance := radius * rng.randf_range(1.15, 2.6)
		var speck := radius * rng.randf_range(0.06, 0.2)
		draw_circle(at + Vector2(cos(angle), sin(angle)) * distance, speck, Color(tint, alpha * 0.85))


## Wiped, or washed off in rain. Takes the wet marks and leaves the dried ones,
## because that is what wiping glass actually does.
func wipe(thoroughness := 0.7) -> void:
	var kept: Array = []
	for mark: Dictionary in marks:
		var age: float = _clock - float(mark["born"])
		if age > DRYING * 0.8 and randf() > thoroughness * 0.5:
			kept.append(mark)
	marks = kept
	sheen = 0.0
	queue_redraw()


## How bloody the lens is, 0..1. For anything that wants to react to the state
## of the player rather than to an event — the Choir noticing, an NPC deciding
## whether to talk to you, the mirror in the room (AH1.5).
func soaked() -> float:
	if marks.is_empty():
		return 0.0
	var total := 0.0
	for mark: Dictionary in marks:
		var age: float = _clock - float(mark["born"])
		var life := 1.0 - clampf((age - DRYING) / FADING, 0.0, 1.0)
		total += float(mark["radius"]) * life
	return clampf(total / (float(MAX_MARKS) * 16.0), 0.0, 1.0)
