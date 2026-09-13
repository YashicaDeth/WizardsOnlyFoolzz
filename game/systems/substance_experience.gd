class_name SubstanceExperience
extends RefCounted

## AU4. What a state actually looks like.
##
## `substances.gd` already decides what a dose costs your body and what it does
## to pain and consciousness, and it does all of that on the frame you take it.
## That is correct for the ledger and wrong for the experience: nothing you take
## in this game has ever had a *shape in time*. This file is that shape, and
## only that shape - it owns no body state, charges nothing, and never writes to
## anatomy. `Substances.take()` remains the only thing that can cost you.
##
## AU4.1: a substance maps to a curve through the rig's named states, not to one
## fixed dial set. AU4.2: come-up, peak, trails and come-down are phases with
## real durations. AU4.3: a bad trip is a different shape, not a bigger one.
## AU4.5: tolerance moves the curve, the same way E4.3 moves a rite's price.
##
## Pure functions of (substance, elapsed, potency, tolerance). No clock
## autoload, no node, no rig reference - `psy_lab.tscn` and the garage (AU3)
## both drive `psychedelic_rig.gd` from what this returns, which is why the demo
## path and the game path cannot drift apart.

const Substances := preload("res://systems/substances.gd")

## Every dial `psychedelic_rig.gd` exposes, at rest. Anything a phase does not
## name is held here rather than left at whatever the last phase set, which is
## the bug that made the first capture sheet converge on flat grey.
const REST := {
	"lut_strength": 0.0,
	"kaleidoscope_segments": 0.0,
	"kaleidoscope_spin": 0.0,
	"feedback_strength": 0.0,
	"feedback_zoom": 1.0,
	"feedback_spin": 0.0,
	"chromatic_offset": 0.0,
	"displacement_strength": 0.0,
	"displacement_scroll": 0.3,
	"cut_intensity": 0.0,
	"cut_seed": 0.0,
	"cut_rate": 8.0,
}

## The three substances, each a different *shape* rather than a different
## intensity of the same shape - which is the whole point of AU4.1. Marrow Dust
## is body: it swims and it does not open anything. Choir Bloom is the fungal
## door, so it is the geometric one. Static Hymn is a dead mast's feedback
## inhaled off a speaker cone, so it is trails and cuts and almost no symmetry -
## the drug sounds like what it does to the screen.
const PROFILES := {
	"marrow_dust": {
		"bad_trip_floor": 4,
		"phases": [
			{"name": "come_up", "seconds": 8.0, "dials": {
				"chromatic_offset": 0.004, "displacement_strength": 0.015,
			}},
			{"name": "peak", "seconds": 26.0, "dials": {
				"chromatic_offset": 0.009, "displacement_strength": 0.045,
				"displacement_scroll": 0.18, "lut_strength": 0.22,
			}},
			{"name": "trails", "seconds": 18.0, "dials": {
				"chromatic_offset": 0.006, "displacement_strength": 0.03,
				"feedback_strength": 0.28, "feedback_zoom": 1.008,
			}},
			{"name": "come_down", "seconds": 20.0, "dials": {
				"chromatic_offset": 0.002, "lut_strength": 0.08,
			}},
		],
	},
	"choir_bloom": {
		"bad_trip_floor": 2,
		"phases": [
			{"name": "come_up", "seconds": 16.0, "dials": {
				"chromatic_offset": 0.006, "displacement_strength": 0.02,
				"lut_strength": 0.2,
			}},
			{"name": "rising", "seconds": 20.0, "dials": {
				"kaleidoscope_segments": 3.0, "kaleidoscope_spin": 0.15,
				"chromatic_offset": 0.012, "displacement_strength": 0.04,
				"lut_strength": 0.35,
			}},
			{"name": "peak", "seconds": 40.0, "dials": {
				"kaleidoscope_segments": 6.0, "kaleidoscope_spin": 0.35,
				"chromatic_offset": 0.018, "displacement_strength": 0.05,
				"lut_strength": 0.5,
			}},
			{"name": "trails", "seconds": 30.0, "dials": {
				"kaleidoscope_segments": 2.0, "feedback_strength": 0.55,
				"feedback_zoom": 1.02, "feedback_spin": 0.06,
				"chromatic_offset": 0.01, "lut_strength": 0.3,
			}},
			{"name": "come_down", "seconds": 34.0, "dials": {
				"chromatic_offset": 0.005, "lut_strength": 0.14,
				"feedback_strength": 0.18, "feedback_zoom": 1.006,
			}},
		],
	},
	"static_hymn": {
		"bad_trip_floor": 1,
		"phases": [
			{"name": "come_up", "seconds": 6.0, "dials": {
				"cut_intensity": 0.12, "cut_rate": 4.0, "chromatic_offset": 0.008,
			}},
			{"name": "peak", "seconds": 30.0, "dials": {
				"cut_intensity": 0.55, "cut_rate": 9.0, "cut_seed": 2.0,
				"chromatic_offset": 0.02, "displacement_strength": 0.06,
				"feedback_strength": 0.4, "feedback_zoom": 1.012, "lut_strength": 0.4,
			}},
			{"name": "trails", "seconds": 26.0, "dials": {
				"feedback_strength": 0.62, "feedback_zoom": 1.015,
				"feedback_spin": 0.1, "cut_intensity": 0.2, "cut_rate": 5.0,
				"chromatic_offset": 0.012,
			}},
			{"name": "come_down", "seconds": 22.0, "dials": {
				"cut_intensity": 0.06, "cut_rate": 2.0, "feedback_strength": 0.2,
				"feedback_zoom": 1.004,
			}},
		],
	},
}

## AU4.3. A bad trip is not the peak turned up. It is the symmetry going away
## and the frame starting to cut - the two things that read as *losing control*
## rather than as seeing more. Kaleidoscope drops to a number too low to be
## pretty, the spin reverses, and everything that was decorative becomes fast.
const BAD_TRIP := {
	"kaleidoscope_segments": 3.0,
	"kaleidoscope_spin": -0.8,
	"displacement_strength": 0.12,
	"chromatic_offset": 0.03,
	"cut_intensity": 0.45,
	"cut_rate": 6.0,
	"lut_strength": 0.7,
}

## AU4.5. Each repeat of the same substance shortens the good part and lengthens
## the bad one, and pushes the bad-trip roll closer to happening. Capped, so a
## heavy user still gets an experience rather than a flat screen.
const TOLERANCE_CAP := 6
const TOLERANCE_MAGNITUDE_FALLOFF := 0.11
const TOLERANCE_PEAK_FALLOFF := 0.13


static func profile(substance_id: String) -> Dictionary:
	return (PROFILES.get(substance_id, {}) as Dictionary).duplicate(true)


## Potency stretches the whole curve rather than only its height: a strong batch
## lasts longer as well as hitting harder, which is what makes an unlabelled one
## genuinely risky (AU1.3's potency roll is the same number).
static func duration(substance_id: String, potency: float = 1.0, tolerance: int = 0) -> float:
	var shape := profile(substance_id)
	if shape.is_empty():
		return 0.0
	var total := 0.0
	for raw_phase in shape.get("phases", []) as Array:
		total += _phase_seconds(raw_phase as Dictionary, potency, tolerance)
	return total


static func _phase_seconds(phase: Dictionary, potency: float, tolerance: int) -> float:
	var seconds := float(phase.get("seconds", 0.0)) * clampf(potency, 0.2, 2.5)
	# Tolerance eats the peak specifically. The come-down does not get shorter
	# because you have done this before - if anything that is the part regulars
	# describe as longer.
	var held := clampi(tolerance, 0, TOLERANCE_CAP)
	match str(phase.get("name", "")):
		"peak", "rising":
			seconds *= maxf(0.35, 1.0 - float(held) * TOLERANCE_PEAK_FALLOFF)
		"come_down":
			seconds *= 1.0 + float(held) * 0.08
	return seconds


## Deterministic: the same subject, substance and dose count answers the same
## way every time it is asked, the same guarantee `roll_strain()` makes. A first
## dose of anything is never a bad trip - like a first casting never burning its
## seal (E4.3), the escalation has to be given room to mean something.
static func is_bad_trip(subject_id: String, substance_id: String, tolerance: int, potency: float = 1.0) -> bool:
	var shape := profile(substance_id)
	if shape.is_empty() or tolerance <= 0:
		return false
	var floor_at := int(shape.get("bad_trip_floor", 3))
	if tolerance < floor_at:
		return false
	var chance := clampf(float(tolerance - floor_at + 1) * 0.16 * clampf(potency, 0.5, 2.0), 0.0, 0.8)
	var rng := RandomNumberGenerator.new()
	rng.seed = (hash(subject_id + substance_id) + tolerance * 7919) & 0x7fffffff
	return rng.randf() < chance


## The whole point of the file. Where you are on the curve, and what the rig
## should be set to, at `elapsed` seconds after the dose.
##
## Phases cross-fade into each other rather than switching. A drug that stepped
## between dial sets would read as the game changing its mind, and Rule 3 in
## AGENT_SPLIT.md calls every hard cut a bug - that applies to a shader as much
## as to a camera.
static func state_at(substance_id: String, elapsed: float, potency: float = 1.0, tolerance: int = 0, bad := false) -> Dictionary:
	var shape := profile(substance_id)
	if shape.is_empty():
		return {"phase": "sober", "progress": 0.0, "done": true, "dials": REST.duplicate()}
	var phases: Array = shape.get("phases", [])
	if elapsed < 0.0:
		return {"phase": "sober", "progress": 0.0, "done": false, "dials": REST.duplicate()}

	var magnitude := clampf(potency, 0.2, 2.0) * maxf(0.3, 1.0 - float(clampi(tolerance, 0, TOLERANCE_CAP)) * TOLERANCE_MAGNITUDE_FALLOFF)
	var cursor := 0.0
	for index in phases.size():
		var phase: Dictionary = phases[index]
		var seconds := _phase_seconds(phase, potency, tolerance)
		if seconds <= 0.0:
			continue
		if elapsed < cursor + seconds:
			var within := (elapsed - cursor) / seconds
			# Each phase fades in from the one before it over its own first
			# third, and holds after that. Only the last phase fades out, to
			# rest. The first version also faded *out* toward the next phase
			# over the final third, which double-counted every interior
			# boundary: the end of phase N had already arrived at phase N+1's
			# target, and then phase N+1 started by fading in from phase N's -
			# a jump backwards of a whole phase width at every seam, which is
			# exactly the hard cut Rule 3 calls a bug. Fading in once is
			# continuous because the value a phase starts at is the value the
			# previous phase was holding.
			var from := REST.duplicate() if index == 0 else _targets(phases[index - 1] as Dictionary, magnitude, bad)
			var here := _targets(phase, magnitude, bad)
			var dials: Dictionary
			if within < 0.34:
				dials = _blend(from, here, smoothstep(0.0, 1.0, within / 0.34))
			elif index == phases.size() - 1 and within > 0.66:
				dials = _blend(here, REST.duplicate(), smoothstep(0.0, 1.0, (within - 0.66) / 0.34))
			else:
				dials = here
			return {
				"phase": str(phase.get("name", "")),
				"progress": clampf(elapsed / maxf(duration(substance_id, potency, tolerance), 0.001), 0.0, 1.0),
				"done": false,
				"bad": bad,
				"dials": dials,
			}
		cursor += seconds
	return {"phase": "sober", "progress": 1.0, "done": true, "bad": bad, "dials": REST.duplicate()}


## A bad trip replaces the phase's own shape from the peak onward rather than
## being mixed into it - half a bad trip is just a muddy good one.
static func _targets(phase: Dictionary, magnitude: float, bad: bool) -> Dictionary:
	var named: Dictionary = phase.get("dials", {})
	if bad and str(phase.get("name", "")) in ["peak", "rising", "trails"]:
		named = BAD_TRIP
	var out := REST.duplicate()
	for dial_name: String in named:
		out[dial_name] = _scale(dial_name, float(named[dial_name]), magnitude)
	return out


## Not every dial scales the same way. `feedback_zoom` is a multiplier around
## 1.0 and scaling it like an amplitude would send it to zero; segment counts
## are counts and want rounding, not 5.4 mirrors; scroll and rate are speeds
## that should not fall out from under a weak dose.
static func _scale(dial_name: String, value: float, magnitude: float) -> float:
	match dial_name:
		"feedback_zoom":
			return 1.0 + (value - 1.0) * magnitude
		"kaleidoscope_segments":
			return 0.0 if value <= 0.0 else maxf(2.0, roundf(value * magnitude))
		"displacement_scroll", "cut_rate", "cut_seed":
			return value
		_:
			return value * magnitude


static func _blend(from: Dictionary, to: Dictionary, amount: float) -> Dictionary:
	var out := {}
	for dial_name: String in REST:
		out[dial_name] = lerpf(float(from.get(dial_name, REST[dial_name])), float(to.get(dial_name, REST[dial_name])), amount)
	# Mirrors are whole. Interpolating 6 to 0 through 3.4 draws a shape that
	# does not exist rather than a kaleidoscope closing.
	out["kaleidoscope_segments"] = 0.0 if float(out["kaleidoscope_segments"]) < 2.0 else roundf(float(out["kaleidoscope_segments"]))
	return out


## --- what the world remembers -------------------------------------------
## A dose is an event with a start, which is all the state this needs. The
## subject carries its own dose history so tolerance survives a scene change
## and reads from the same record as everything else (J10.3).

const DOSES_KEY := "doses"


static func tolerance(subject_id: String, substance_id: String) -> int:
	var history: Dictionary = WorldHistory.subject(subject_id).get("substance_history", {})
	return int(history.get(substance_id, 0))


## `now` is supplied rather than read from a clock here, so a test can run a
## whole trip in a loop and the game can pass `WorldClock` seconds without this
## file having to know which of those it is talking to.
static func begin(subject_id: String, substance_id: String, now: float, potency: float = 1.0) -> Dictionary:
	if not Substances.CATALOG.has(substance_id):
		return {"ok": false, "reason": "NO SUCH SUBSTANCE"}
	if not PROFILES.has(substance_id):
		return {"ok": false, "reason": "NO AUTHORED EXPERIENCE"}
	var subject := WorldHistory.subject(subject_id)
	if subject.is_empty():
		return {"ok": false, "reason": "NO SUCH SUBJECT"}
	var held := tolerance(subject_id, substance_id)
	var bad := is_bad_trip(subject_id, substance_id, held, potency)
	var doses: Array = (subject.get(DOSES_KEY, []) as Array).duplicate()
	var dose := {
		"substance_id": substance_id,
		"started_at": now,
		"potency": potency,
		"tolerance": held,
		"bad": bad,
		"seconds": duration(substance_id, potency, held),
	}
	doses.append(dose)
	var history: Dictionary = (subject.get("substance_history", {}) as Dictionary).duplicate()
	history[substance_id] = held + 1
	WorldHistory.amend_subject(subject_id, {DOSES_KEY: doses, "substance_history": history})
	WorldHistory.record_event("substance_experience_began", {
		"subject_id": subject_id, "substance_id": substance_id,
		"bad": bad, "tolerance": held, "seconds": float(dose["seconds"]),
	})
	return {"ok": true, "dose": dose}


## Every live dose at once, combined. Stacking is by strongest-wins per dial
## rather than by sum: two doses should not add to a kaleidoscope with eleven
## mirrors and a feedback strength above 1, and the one you took second is
## usually the one you can feel.
static func dials_for(subject_id: String, now: float) -> Dictionary:
	var dials := REST.duplicate()
	var live := 0
	for raw_dose in WorldHistory.subject(subject_id).get(DOSES_KEY, []) as Array:
		var dose: Dictionary = raw_dose
		var elapsed := now - float(dose.get("started_at", 0.0))
		if elapsed < 0.0 or elapsed > float(dose.get("seconds", 0.0)):
			continue
		var state := state_at(
			str(dose.get("substance_id", "")), elapsed,
			float(dose.get("potency", 1.0)), int(dose.get("tolerance", 0)),
			bool(dose.get("bad", false)),
		)
		live += 1
		var theirs: Dictionary = state["dials"]
		for dial_name: String in REST:
			var mine := float(dials[dial_name])
			var other := float(theirs[dial_name])
			match dial_name:
				"feedback_zoom":
					dials[dial_name] = other if absf(other - 1.0) > absf(mine - 1.0) else mine
				"kaleidoscope_spin", "feedback_spin":
					dials[dial_name] = other if absf(other) > absf(mine) else mine
				"displacement_scroll", "cut_rate":
					dials[dial_name] = other if live == 1 else minf(mine, other)
				_:
					dials[dial_name] = maxf(mine, other)
	return dials


## Drops finished doses. Call at a seam, not every frame - the same discipline
## `reconcile_album()` keeps, so reading the rig never mutates the record.
static func settle(subject_id: String, now: float) -> int:
	var kept: Array = []
	for raw_dose in WorldHistory.subject(subject_id).get(DOSES_KEY, []) as Array:
		var dose: Dictionary = raw_dose
		if now - float(dose.get("started_at", 0.0)) <= float(dose.get("seconds", 0.0)):
			kept.append(dose)
	WorldHistory.amend_subject(subject_id, {DOSES_KEY: kept})
	return kept.size()


## The one call the garage (AU3.4) and `psy_lab.tscn` both make. Drives the real
## rig with the real curve, so there is no demo path that can drift from the
## game path.
static func drive(rig: Object, subject_id: String, now: float) -> Dictionary:
	var dials := dials_for(subject_id, now)
	if rig != null and rig.has_method("set_dial"):
		for dial_name: String in dials:
			rig.set_dial(dial_name, float(dials[dial_name]))
	return dials
