class_name CrystalBall
extends RefCounted

## B5.1. A crystal ball, carried in the arm or the pocket, and functional.
##
## Functional is the word that decides what this is. A prop that glows is not
## one, and neither is a divination system invented from nothing to give it
## something to say. So it reads state the world already keeps and cannot
## otherwise be seen: how much chaos magick is loose (`WorldHistory`, fed by
## rituals and, since A7.2, by looking at gods), which gods are up right now and
## what the next one is (`gods.gd`, off `WorldClock`), and how bad the air is
## about to get (A9.2 reads the same charge, so the ball is forecasting a storm
## from its actual cause rather than from a weather variable).
##
## It does not care whether it is installed in a limb or rattling in a pocket.
## `held_by()` answers that question for either, because "in the arm or the
## pocket" is the segment's own phrasing and a ball that only worked one way
## would be half the item.

const SIGHT_HOURS := 6.0


## True when this body has one, whichever way they are carrying it.
static func held_by(anatomy: AnatomyComponent, carried: Node = null) -> bool:
	if anatomy != null:
		for zone_id in anatomy.installed_parts:
			if str((anatomy.installed_parts[zone_id] as Dictionary).get("name", "")).to_lower() == "scrying ball":
				return true
	if carried != null and carried.has_method("first_index"):
		return int(carried.call("first_index", "scrying ball")) >= 0
	return false


## What it sees. Empty when nobody is holding one — the absence of a ball is not
## a reading of nothing, it is not a reading.
static func reading(anatomy: AnatomyComponent, carried: Node = null) -> Dictionary:
	if not held_by(anatomy, carried):
		return {}
	var charge := WorldHistory.chaos_magick()
	var hour := WorldClock.hour()
	var present: Array = Gods.up_now(hour)
	var names: Array[String] = []
	for body: Dictionary in present:
		names.append(str(body.get("name", "")))
	return {
		"charge": snappedf(charge, 0.01),
		"storm": _storm_words(charge),
		"gods_up": names,
		"next_god": _next_god(hour),
		"clouded": clampf(1.0 - charge, 0.0, 1.0),
	}


## A line to print, in the register the rest of the game speaks in. The ball is
## clearer the worse things are: it is a contamination artefact, so a quiet
## world gives it nothing to show and a charged one lights it up — which makes
## it most useful exactly when it is most alarming.
static func speak(anatomy: AnatomyComponent, carried: Node = null) -> String:
	var seen := reading(anatomy, carried)
	if seen.is_empty():
		return ""
	var lines: Array[String] = []
	if float(seen.charge) < 0.08:
		lines.append("THE GLASS IS DULL. NOTHING IS MOVING.")
	else:
		lines.append("THE GLASS IS %s // %s" % [str(seen.storm).to_upper(), WorldClock.long_stamp()])
	var up: Array = seen.gods_up
	if not up.is_empty():
		lines.append("UP NOW: %s" % ", ".join(up))
	var coming: Dictionary = seen.next_god
	if not coming.is_empty():
		lines.append("%s RISES IN %s HOURS" % [str(coming.get("name", "")), str(coming.get("in_hours", ""))])
	return "\n".join(lines)


## The next god to rise within the ball's sight, and how long until it does.
static func _next_god(hour: float) -> Dictionary:
	var soonest := {}
	var shortest := SIGHT_HOURS + 1.0
	for body: Dictionary in Gods.BODIES:
		if Gods.is_up(body, hour):
			continue
		var until := fposmod(float(body["from"]) - hour, 24.0)
		if until < shortest:
			shortest = until
			soonest = {"name": str(body.get("name", "")), "in_hours": snappedf(until, 0.1)}
	return soonest if shortest <= SIGHT_HOURS else {}


static func _storm_words(charge: float) -> String:
	if charge >= 0.75:
		return "boiling"
	if charge >= 0.4:
		return "turning"
	if charge >= 0.15:
		return "restless"
	return "settled"
