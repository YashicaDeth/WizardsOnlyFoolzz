class_name WorldWeather
extends RefCounted

## W1.2. Contamination has weather — it moves, it settles, it gets worse.
##
## A5 made contamination a property of every surface, painted in once at
## authoring time. That answers what a wall looks like; it says nothing about
## whether the air over the Bone Yard is worse today than it was a week ago.
## Nothing in the project has ever asked that question, because nothing
## tracked an answer.
##
## Deliberately not a new persisted number, for the same reason `world_clock.gd`
## is not a sixth autoload: everything this needs already exists and already
## persists. `WorldHistory.chaos_magick()` (AS4.2) is a real, decaying, bumped
## number already — a ritual or a god sighting puts something loose in the air,
## and it is honest that the air should read worse while that is still true.
## `WorldClock.day()`/`daylight()` (W1.1) are real too. `contamination()` below
## is a pure function of both, the same way `WorldClock` is a pure function of
## one stored minute — so this file, like that one, has nothing to save or
## load and cannot drift out of sync with either source.
##
## "Moves" here is temporal: the reading genuinely changes on its own between
## events, continuously, rather than sitting still until something bumps it.
## A live map of contamination fronts crossing the region — the ground west of
## the Wire reading worse than the ground east of it — is real future work and
## is not this pass; that needs a per-place value this project does not have
## anywhere yet, for anything.

## "It gets worse": a floor that only ever rises with elapsed time, worn into
## the world the way a ruin never gets less ruined. Twenty days of run puts it
## a little over a third of the way to the ceiling below — slow enough that a
## short playtest never notices it, real enough that a save kept for a long
## run does.
const AMBIENT_PER_DAY := 0.006
const AMBIENT_CEILING := 0.55

## "It moves" / "it settles": worse at night, receding through the day, so the
## number is never static even with nothing happening. Reuses `daylight()`
## rather than authoring a second day curve.
const NIGHT_PUSH := 0.18

## A storm already loose in the air (AS4.2) is contamination too, not a
## separate fact politely declining to overlap with this one.
const STORM_PUSH := 0.25


## 0..1. How contaminated the air reads right now, with no place-argument yet
## because nothing in the project tracks contamination by place — see above.
static func contamination() -> float:
	var ambient := clampf(float(WorldClock.day()) * AMBIENT_PER_DAY, 0.0, AMBIENT_CEILING)
	var night := (1.0 - WorldClock.daylight()) * NIGHT_PUSH
	var storm := WorldHistory.chaos_magick() * STORM_PUSH
	return clampf(ambient + night + storm, 0.0, 1.0)


## The ambient floor alone, with no storm and no time-of-day pushed in. What a
## calm, sunlit day still reads, and the number that never goes down.
static func ambient_contamination() -> float:
	return clampf(float(WorldClock.day()) * AMBIENT_PER_DAY, 0.0, AMBIENT_CEILING)
