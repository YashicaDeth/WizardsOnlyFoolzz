class_name FaceModel
extends RefCounted

## AX1.3. "Direct body/face/proportion customisation."
##
## The face was one float. `appearance["face"]` went in, `1 + int(face * 24)`
## came out, and that index picked one of twenty-five prebuilt variations --
## so a player could scroll through twenty-five faces and own none of them.
## Greg, 20 September: "character creation from the current body model with a
## new face."
##
## This is the new face: seven named axes a player recognises, each one a
## thing they can point at afterwards and say they chose. Nothing about the
## body model changes -- `variation()` below still produces the same kind of
## integer the rig has always consumed, derived from the axes instead of
## replacing them, so every existing consumer keeps working and the axes are
## the real record.
##
## The seventh axis is the one that only belongs in this game. You were grown
## in a tank by people who were not being careful, and GROWN WRONG is the
## slider for how much that shows. It is not a deformity setting -- it is the
## facility's workmanship.

const AXES := {
	"brow":      {"label": "BROW",      "low": "FINE",      "high": "HEAVY"},
	"jaw":       {"label": "JAW",       "low": "NARROW",    "high": "BROAD"},
	"nose":      {"label": "NOSE",      "low": "STRAIGHT",  "high": "BROKEN"},
	"eyes":      {"label": "EYES",      "low": "DEEP-SET",  "high": "PROMINENT"},
	"mouth":     {"label": "MOUTH",     "low": "THIN",      "high": "FULL"},
	"cheek":     {"label": "CHEEK",     "low": "HOLLOW",    "high": "FED"},
	"grown_wrong": {"label": "GROWN WRONG", "low": "CLEAN", "high": "THE TANK SHOWS"},
}

## The order they are presented in, which is the order a face is read in:
## the shape of the skull first, then what is on it, then what went wrong.
const ORDER := ["brow", "jaw", "cheek", "eyes", "nose", "mouth", "grown_wrong"]

const STEP := 0.2


static func blank() -> Dictionary:
	var face := {}
	for axis in ORDER:
		face[axis] = 0.5
	# Nothing was done carefully, but nothing was botched either. A decanted
	# body starts at the middle of every axis except this one, which starts
	# low because the facility does not intend the damage -- it just does not
	# prevent it.
	face["grown_wrong"] = 0.0
	return face


static func cycle(face: Dictionary, axis: String) -> Dictionary:
	if not AXES.has(axis):
		return face
	var next := face.duplicate(true)
	next[axis] = fmod(float(face.get(axis, 0.5)) + STEP, 1.0 + STEP * 0.5)
	if next[axis] > 1.0:
		next[axis] = 0.0
	return next


## What the axis reads as on the form. The facility writes words, not numbers,
## because a number would imply it measured carefully.
static func reading(face: Dictionary, axis: String) -> String:
	var spec: Dictionary = AXES.get(axis, {})
	if spec.is_empty():
		return ""
	var value := clampf(float(face.get(axis, 0.5)), 0.0, 1.0)
	if value < 0.2:
		return str(spec.low)
	if value < 0.4:
		return "SLIGHTLY " + str(spec.low)
	if value <= 0.6:
		return "UNREMARKABLE"
	if value <= 0.8:
		return "SLIGHTLY " + str(spec.high)
	return str(spec.high)


## The bridge to the body rig. `baseline_human.gd` has always asked for a
## single `variation` integer and it still gets one -- derived from every axis
## rather than from a lone slider, so two faces that differ anywhere differ
## here. Deterministic: the same face is the same body across loads, which is
## the whole reason the sheet is the record and the mesh is not.
## One prime per axis, none of them sharing a factor with 24. The obvious
## version of this -- `acc = acc * 6 + step`, then mod 24 -- is degenerate:
## 6^3 is 216, which is 0 mod 24, so only the last three axes could ever
## reach the result and the first four were decoration. The suite caught it
## at 2 of 7 axes having any effect.
const AXIS_PRIMES := {
	"brow": 5, "jaw": 7, "cheek": 11, "eyes": 13, "nose": 17, "mouth": 19, "grown_wrong": 23,
}

static func variation(face: Dictionary) -> int:
	var acc := 0
	for axis in ORDER:
		var step := int(round(clampf(float(face.get(axis, 0.5)), 0.0, 1.0) * 5.0))
		acc += step * int(AXIS_PRIMES.get(axis, 1))
	return 1 + (acc % 24)


## A single 0..1 figure for anything that still wants the old scalar, kept so
## `appearance["face"]` stays populated and nothing downstream has to know the
## axes exist yet.
static func scalar(face: Dictionary) -> float:
	return clampf(float(variation(face) - 1) / 23.0, 0.0, 1.0)


## Randomisation has to land on a face rather than on noise, so the skull
## axes correlate: a broad jaw tends to come with a heavier brow. Random
## faces that are pure noise all look like the same person wearing a bad
## expression.
static func randomise(rng: RandomNumberGenerator) -> Dictionary:
	var face := blank()
	var heft := rng.randf()
	face["jaw"] = clampf(heft + rng.randf_range(-0.2, 0.2), 0.0, 1.0)
	face["brow"] = clampf(heft + rng.randf_range(-0.25, 0.25), 0.0, 1.0)
	face["cheek"] = clampf(1.0 - heft + rng.randf_range(-0.3, 0.3), 0.0, 1.0)
	face["eyes"] = rng.randf()
	face["nose"] = rng.randf()
	face["mouth"] = rng.randf()
	# Most bodies come out of the tank close to intended. A few do not.
	face["grown_wrong"] = 0.0 if rng.randf() < 0.65 else rng.randf_range(0.2, 1.0)
	return face
