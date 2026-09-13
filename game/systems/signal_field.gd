class_name SignalField
extends RefCounted

## Whether you have signal, and why, decided by where you are standing.
##
## C5. `DESIGN/IN_GAME_INTERNET.md` states it as a pillar rather than a feature:
## *"Reached through the world, not only the menu: a 5G mast is a physical
## landmark that extends coverage, a terminal in a shop is a fixed access point,
## and connectivity is a property of place. No signal in the caves."*
##
## Until now `WireNet` took its grade as a constructor argument and every caller
## passed `SIGNAL_SURFACE`, which meant the Wire was always available and the
## whole design collapsed into a menu. This is the thing that was missing.
##
## Three grades, and the gap between the second and third is the one that
## matters: the underbelly is not a toggle, it is a place you have to physically
## reach. That was recorded as an open question and this is the answer being
## built rather than deferred again — it is reversible by changing one table.

const NONE := 0
const SURFACE := 1
const UNDERBELLY := 2

## Emitters are world objects. `reach` is metres; `grade` is the best signal
## available inside it. A terminal is short-ranged and deep, a mast is
## long-ranged and shallow, which is exactly the trade the design wants.
const EMITTERS := [
	{
		"id": "bone_yard_mast", "kind": "mast", "at": Vector2(-155.0, 0.0),
		"reach": 240.0, "grade": SURFACE, "name": "BONE YARD MAST",
	},
	{
		"id": "tunnel_mast", "kind": "mast", "at": Vector2(65.0, 115.0),
		"reach": 200.0, "grade": SURFACE, "name": "TUNNEL MOUTH RELAY",
	},
	{
		"id": "black_mile_mast", "kind": "mast", "at": Vector2(-150.0, -122.0),
		"reach": 180.0, "grade": SURFACE, "name": "BLACK MILE REPEATER",
	},
	{
		"id": "ossuary_terminal", "kind": "terminal", "at": Vector2(135.0, 0.0),
		"reach": 26.0, "grade": UNDERBELLY, "name": "OSSUARY WORKS TERMINAL",
	},
	{
		"id": "communion_terminal", "kind": "terminal", "at": Vector2(130.0, -122.0),
		"reach": 22.0, "grade": UNDERBELLY, "name": "COMMUNION TERMINAL",
	},
]

## Places that swallow signal whatever is transmitting nearby. The caves are
## named in the design, so they are named here.
const DEAD_ZONES := [
	{"at": Vector2(135.0, 40.0), "reach": 60.0, "name": "THE OSSUARY, BELOW"},
	{"at": Vector2(-150.0, 60.0), "reach": 48.0, "name": "QUARRY UNDERCUT"},
]

var at := Vector2.ZERO
## D8's neural lace, when the player took it: coverage without a mast. The
## modifier is a real mechanical trade and this is the half that pays out.
var laced := false


func stand_at(world_position: Vector2) -> void:
	at = world_position


## The best grade available here, and what is providing it.
func reading() -> Dictionary:
	for zone in DEAD_ZONES:
		if at.distance_to(zone.at as Vector2) <= float(zone.reach):
			# A lace is a receiver, not a miracle. Underground is underground.
			return {"grade": NONE, "source": str(zone.name), "kind": "dead", "strength": 0.0, "id": ""}
	var best_grade := NONE
	var best_strength := 0.0
	var source := "NO CARRIER"
	var kind := "none"
	# I3.2. The emitter's own id, so `BrokenWeb.reachable_from()` can ask
	# "what is reachable from exactly where I am standing" instead of every
	# caller re-deriving it from `source`'s display name.
	var emitter_id := ""
	for emitter in EMITTERS:
		var distance := at.distance_to(emitter.at as Vector2)
		var reach := float(emitter.reach)
		if distance > reach:
			continue
		var strength := clampf(1.0 - pow(distance / reach, 1.8), 0.0, 1.0)
		var emitter_grade := int(emitter.grade)
		if emitter_grade > best_grade or (emitter_grade == best_grade and strength > best_strength):
			best_grade = emitter_grade
			best_strength = strength
			source = str(emitter.name)
			kind = str(emitter.kind)
			emitter_id = str(emitter.id)
	if best_grade == NONE and laced:
		return {"grade": SURFACE, "source": "NEURALACE", "kind": "lace", "strength": 0.45, "id": ""}
	return {"grade": best_grade, "source": source, "kind": kind, "strength": best_strength, "id": emitter_id}


func grade() -> int:
	return int(reading().get("grade", NONE))


## Emitters near enough to be worth drawing on the map, with their reach, so
## coverage can be read as territory rather than guessed at.
func nearby(radius: float = 400.0) -> Array:
	var out: Array = []
	for emitter in EMITTERS:
		if at.distance_to(emitter.at as Vector2) <= radius:
			var entry := (emitter as Dictionary).duplicate()
			entry["distance"] = at.distance_to(emitter.at as Vector2)
			entry["in_reach"] = entry["distance"] <= float(emitter.reach)
			out.append(entry)
	out.sort_custom(func(a, b): return float(a.distance) < float(b.distance))
	return out


## The nearest thing that would give you a signal, for the device to point at
## when it has none. Being told "no signal" is useless; being told which way to
## walk is a direction.
func nearest_carrier() -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for emitter in EMITTERS:
		var distance := at.distance_to(emitter.at as Vector2)
		if distance < best_distance:
			best_distance = distance
			best = (emitter as Dictionary).duplicate()
			best["distance"] = distance
	return best
