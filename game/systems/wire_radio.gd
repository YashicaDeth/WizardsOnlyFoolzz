class_name WireRadio
extends RefCounted

## A tunable radio, and a second transmission channel for the world.
##
## Greg's ask was Oxenfree's dial in the Fallout register: a real instrument you
## sweep, not a track selector. It earns its place for two reasons that were
## already in the design before the radio was:
##
## - **Coverage is a property of place.** `DESIGN/IN_GAME_INTERNET.md` already
##   gates the Wire that way — no signal in the caves — so a station you can only
##   receive standing in one valley *is* a location, and tuning becomes a reason
##   to stand somewhere specific.
## - **The Hunt System needs a slower carrier.** `DESIGN/HUNT_SYSTEM.md` wants
##   knowledge that propagates late and distorted. The Wire feed is the fast,
##   unreliable channel; a half-tuned broadcast is the slow one, and it repeats
##   what the feed said hours ago with the details worn off.
##
## So this is not a music player with a skin. What you can hear depends on where
## you are standing, what you hear is often wrong, and some of it is a job.

## Stations are authored, but their reach is physical. `at` is a world position
## and `reach` is metres; outside that you get the carrier and nothing else.
const STATIONS := [
	{
		"khz": 88.6, "name": "BONE YARD PIT CONTROL", "kind": "wire",
		"at": Vector2(-155.0, 0.0), "reach": 220.0,
		"voice": "results, delays, and whose car is being cut up",
	},
	{
		"khz": 97.2, "name": "THE FULL SCHEDULE", "kind": "preacher",
		"at": Vector2(130.0, -122.0), "reach": 300.0,
		"voice": "a man explaining what the masts are really for",
	},
	{
		"khz": 104.9, "name": "UNNAMED CARRIER", "kind": "numbers",
		"at": Vector2(135.0, 0.0), "reach": 160.0,
		"voice": "a woman reading five-digit groups, forever",
	},
	{
		"khz": 112.4, "name": "SOFT ROT COMMUNION", "kind": "music",
		"at": Vector2(130.0, -122.0), "reach": 260.0,
		"voice": "something with too many strings, recorded in a cave",
	},
	{
		"khz": 121.5, "name": "GATE LANTERN RELAY", "kind": "hook",
		"at": Vector2(65.0, 115.0), "reach": 180.0,
		"voice": "somebody asking for help by name, on a loop",
	},
]

const BAND_LOW := 86.0
const BAND_HIGH := 124.0
## How far off a station's frequency you can sit and still hear it at all.
const BANDWIDTH := 1.6
## Seconds a hook station must be held locked before it becomes a real lead.
const LOCK_SECONDS := 3.5

var khz := 88.6
var listener := Vector2.ZERO
var lock_seconds := 0.0
var last_hook := ""


func _init(start_khz := 88.6) -> void:
	khz = start_khz


func tune(delta_khz: float) -> void:
	khz = clampf(khz + delta_khz, BAND_LOW, BAND_HIGH)
	lock_seconds = 0.0


func stand_at(world_position: Vector2) -> void:
	listener = world_position


## How well a given station is coming in, 0 to 1, from *both* how close the dial
## is and how close you are standing. Two independent axes on purpose: a station
## you are tuned perfectly to is still noise if you are the wrong side of a hill.
func strength(station: Dictionary) -> float:
	var detune := absf(khz - float(station.khz))
	if detune > BANDWIDTH:
		return 0.0
	var dial := 1.0 - pow(detune / BANDWIDTH, 1.6)
	var distance := listener.distance_to(station.at as Vector2)
	var reach := float(station.reach)
	# A soft edge rather than a hard cutoff, so walking toward a transmitter is
	# audible as it happens instead of snapping on at a boundary.
	var place := clampf(1.0 - pow(distance / reach, 2.2), 0.0, 1.0)
	return clampf(dial * place, 0.0, 1.0)


## The station currently being received best, with its strength. Empty when the
## dial is sitting on carrier.
func receiving() -> Dictionary:
	var best: Dictionary = {}
	var best_strength := 0.0
	for station in STATIONS:
		var here := strength(station)
		if here > best_strength:
			best_strength = here
			best = station
	if best_strength < 0.08:
		return {}
	var found := (best as Dictionary).duplicate()
	found["strength"] = best_strength
	return found


## Everything audible from here, for the dial to draw its ticks against. A
## station out of physical range is deliberately still listed at zero, because a
## dead marker on the dial is information: something transmits there, elsewhere.
func band() -> Array:
	var out: Array = []
	for station in STATIONS:
		var distance := listener.distance_to(station.at as Vector2)
		out.append({
			"khz": float(station.khz),
			"name": str(station.name),
			"kind": str(station.kind),
			"strength": strength(station),
			"in_reach": distance <= float(station.reach),
		})
	return out


## What is coming out of it right now. Static between stations, and a station
## heard weakly is heard *wrongly* rather than quietly - which is the point of
## carrying rumour on this channel.
func transmission() -> Dictionary:
	var station := receiving()
	if station.is_empty():
		return {"kind": "static", "text": _carrier(), "strength": 0.0, "name": "CARRIER"}
	var clarity := float(station.strength)
	var text := ""
	match str(station.kind):
		"wire":
			text = _wire_bulletin()
		"numbers":
			text = _numbers()
		"preacher":
			text = "…and the tithe is not money, it was never money, it is the part of you that answers when it calls…"
		"music":
			text = "[ instrument, detuned ]   [ a room with water in it ]   [ nobody singing ]"
		"hook":
			text = "…if anyone is still on this band. Gate Lanterns, waystation four. We are still here. We are not all still here…"
	if clarity < 0.62:
		text = _degrade(text, 1.0 - clarity)
	return {"kind": str(station.kind), "name": str(station.name), "text": text, "strength": clarity, "khz": float(station.khz)}


## A9.6. The radio repeats what the Wire already said, late and worn. Reuses the
## same distortion the Hunt System applies to every other retelling rather than
## inventing a second set of rules for it.
func _wire_bulletin() -> String:
	var events := WorldHistory.recent_events(8)
	if events.is_empty():
		return "…nothing from the pit tonight. That is not the same as nothing happening…"
	var event: Dictionary = events[(hash(str(khz)) + events.size()) % events.size()]
	var headline := "PIT CONTROL // %s" % str(event.get("type", "unknown")).replace("_", " ").to_upper()
	var wire := WireNet.new(WireNet.SIGNAL_SURFACE)
	return wire.distort("%s. that is hours old and the yard has already changed it." % headline, 2)


func _numbers() -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(khz * 100.0)
	var groups: Array = []
	for index in 5:
		groups.append("%05d" % rng.randi_range(0, 99999))
	return " ".join(groups)


func _carrier() -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(khz * 1000.0)
	var noise := ""
	for index in 46:
		noise += ["/", "\\\\", "|", ".", " ", "-", "_", "'"][rng.randi_range(0, 7)]
	return noise


## A weak signal drops syllables rather than fading. Deterministic per text and
## per dial position, so holding still does not make it shimmer.
func _degrade(text: String, amount: float) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = (hash(text) + int(khz * 100.0)) & 0x7fffffff
	var out := ""
	for index in text.length():
		if rng.randf() < amount * 0.5:
			out += "·" if rng.randf() < 0.35 else " "
		else:
			out += text[index]
	return out


## A9.3. Holding a lock on a hook station turns a half-heard signal into a real
## lead. Returns the hook's name the moment it resolves, empty otherwise, so the
## caller can announce it once rather than every frame.
func hold(delta: float) -> String:
	var station := receiving()
	if station.is_empty() or str(station.kind) != "hook" or float(station.strength) < 0.55:
		lock_seconds = 0.0
		return ""
	lock_seconds += delta
	if lock_seconds < LOCK_SECONDS:
		return ""
	lock_seconds = 0.0
	var name := str(station.name)
	if last_hook == name:
		return ""
	last_hook = name
	# A9.4. It goes into world history, which is what the index reads. The lead
	# arrives as a record like anything else rather than as a popup.
	WorldHistory.record_event("radio_lead", {
		"subject": "player",
		"station": name,
		"khz": float(station.khz),
		"lead": "waystation four, gate lanterns, still transmitting",
	})
	return name


func lock_progress() -> float:
	return clampf(lock_seconds / LOCK_SECONDS, 0.0, 1.0)
