class_name Gods
extends Node

## A7.1 / A7.2. THE_REWORK §1: *"the gods for each planet and moon and sun
## become visible at certain times"*.
##
## v6 broke the firmament open and put a void behind it. This is what is in the
## void. One god per body, each with its own hour, its own quarter of the sky
## and its own colour, so that after a few nights a player knows where to look
## and when — which is the entire difference between a sky event and a particle
## effect. A god that could appear anywhere at any time would teach nobody
## anything.
##
## The hours are the point of A7.1: `WorldClock.hour()` decides, not a timer and
## not a random roll. The Sun's god is up in the middle of the day and nothing
## else is; the outer bodies belong to the small hours. Two can overlap, three
## is the most the sky shader carries, and that ceiling is deliberate — a sky
## with everything in it at once is a planetarium, not an omen.

## `from` and `to` are hours on a 24 hour clock; a window that wraps midnight is
## written with `from` greater than `to` and read that way. `azimuth` is a
## compass heading in radians and `altitude` is degrees above the horizon, so a
## god sits in the same place in the sky every time it comes round.
const BODIES := [
	{
		"id": "sun", "name": "THE FURNACE",
		"from": 11.0, "to": 15.0, "azimuth": 0.6, "altitude": 52.0,
		"size": 5.5, "color": "ffd9a0", "intensity": 2.4,
	},
	{
		"id": "moon", "name": "THE WITNESS",
		"from": 21.0, "to": 4.0, "azimuth": 2.9, "altitude": 44.0,
		"size": 4.2, "color": "cfe0ff", "intensity": 1.5,
	},
	{
		"id": "mercury", "name": "THE MESSENGER", "prayer": "carriage",
		"from": 5.0, "to": 6.5, "azimuth": 1.7, "altitude": 14.0,
		"size": 1.6, "color": "d8c7a4", "intensity": 0.9,
	},
	{
		"id": "venus", "name": "THE MORNING DEBT", "prayer": "owing",
		"from": 4.0, "to": 6.0, "azimuth": 2.1, "altitude": 22.0,
		"size": 2.4, "color": "ffe3c2", "intensity": 1.3,
	},
	{
		"id": "mars", "name": "THE RED WARDEN", "prayer": "violence",
		"from": 20.0, "to": 23.5, "azimuth": 4.4, "altitude": 36.0,
		"size": 2.1, "color": "ff8a5c", "intensity": 1.1,
	},
	{
		"id": "jupiter", "name": "THE MAGISTRATE", "prayer": "judgement",
		"from": 0.5, "to": 3.5, "azimuth": 5.3, "altitude": 58.0,
		"size": 3.6, "color": "e8c58a", "intensity": 1.2,
	},
	{
		"id": "saturn", "name": "THE ACCOUNTANT", "prayer": "debt",
		"from": 1.5, "to": 5.0, "azimuth": 0.2, "altitude": 30.0,
		"size": 3.0, "color": "d9cf9a", "intensity": 1.0,
	},
	{
		"id": "uranus", "name": "THE TURNED FACE", "prayer": "exile",
		"from": 2.0, "to": 4.0, "azimuth": 3.7, "altitude": 66.0,
		"size": 1.8, "color": "a8d8d4", "intensity": 0.8,
	},
	{
		"id": "neptune", "name": "THE DROWNED KING", "prayer": "drowning",
		"from": 22.0, "to": 2.0, "azimuth": 5.9, "altitude": 25.0,
		"size": 2.0, "color": "7fa8d8", "intensity": 0.85,
	},
]

## How many the sky shader carries at once. Three slots, filled by whichever
## gods are up, in table order.
const SLOTS := 3

## A7.2. How near the middle of the frame a god has to sit, and for how long,
## before the world counts it as having been seen. A sighting should cost the
## player a moment of standing still and looking up — glancing past one while
## running does not make you a witness.
const SIGHTING_ANGLE := 0.22
const SIGHTING_SECONDS := 1.4

signal god_seen(body: Dictionary)

var sky_material: ShaderMaterial
var camera: Camera3D

var _watching := ""
var _watched_for := 0.0


func bind(material: ShaderMaterial, watcher: Camera3D) -> void:
	sky_material = material
	camera = watcher


## Whether `body` is up at `at`, handling a window that runs through midnight.
static func is_up(body: Dictionary, at: float) -> bool:
	var from := float(body["from"])
	var to := float(body["to"])
	if from <= to:
		return at >= from and at <= to
	return at >= from or at <= to


## Where in the sky it sits, as a unit direction. Fixed per god on purpose: the
## sky is a clock face and these are the numbers on it.
static func direction(body: Dictionary) -> Vector3:
	var altitude := deg_to_rad(float(body["altitude"]))
	var azimuth := float(body["azimuth"])
	var flat := cos(altitude)
	return Vector3(sin(azimuth) * flat, sin(altitude), cos(azimuth) * flat).normalized()


## Everything up right now, nearest the horizon first — which is the order a
## player reading the sky would meet them in.
static func up_now(at: float) -> Array:
	var present := []
	for body: Dictionary in BODIES:
		if is_up(body, at):
			present.append(body)
	present.sort_custom(func(first, second): return float(first["altitude"]) < float(second["altitude"]))
	return present


func _process(delta: float) -> void:
	if sky_material == null:
		return
	var at := WorldClock.hour()
	var present := up_now(at)
	for slot in SLOTS:
		if slot < present.size():
			var body: Dictionary = present[slot]
			var dir := direction(body)
			var tint := Color(body["color"])
			# Fades in and out across the first and last half hour of its
			# window, so a god arrives rather than being switched on.
			var strength := float(body["intensity"]) * _edge_fade(body, at)
			sky_material.set_shader_parameter("god%d_place" % slot, Vector4(dir.x, dir.y, dir.z, deg_to_rad(float(body["size"]))))
			sky_material.set_shader_parameter("god%d_tint" % slot, Vector4(tint.r, tint.g, tint.b, strength))
		else:
			sky_material.set_shader_parameter("god%d_tint" % slot, Vector4(0, 0, 0, 0))
	_watch(present, delta)


## Half an hour of arrival and half an hour of leaving.
func _edge_fade(body: Dictionary, at: float) -> float:
	var from := float(body["from"])
	var to := float(body["to"])
	var since := fposmod(at - from, 24.0)
	var until := fposmod(to - at, 24.0)
	return clampf(minf(since, until) / 0.5, 0.0, 1.0)


## A7.2. Looking at one, long enough, is an event. Recorded once per god per
## day: the Witness is up every night, and a world that wrote that down every
## night would be recording the weather rather than an omen.
func _watch(present: Array, delta: float) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	var forward := -camera.global_transform.basis.z
	var nearest := ""
	var nearest_body := {}
	var best := SIGHTING_ANGLE
	for body: Dictionary in present:
		var angle := forward.angle_to(direction(body))
		if angle < best:
			best = angle
			nearest = String(body["id"])
			nearest_body = body
	if nearest.is_empty():
		_watching = ""
		_watched_for = 0.0
		return
	if nearest != _watching:
		_watching = nearest
		_watched_for = 0.0
	_watched_for += delta
	if _watched_for < SIGHTING_SECONDS:
		return
	var key := "god_seen_%s_day_%d" % [nearest, WorldClock.day()]
	if bool(WorldHistory.flag(key, false)):
		return
	WorldHistory.set_flag(key, true)
	WorldHistory.record_event("god_seen", {
		"god": nearest,
		"name": nearest_body.get("name", ""),
		"prayer": nearest_body.get("prayer", ""),
		"day": WorldClock.day(),
		"hour": WorldClock.hour(),
		"stamp": WorldClock.long_stamp(),
	})
	god_seen.emit(nearest_body)
