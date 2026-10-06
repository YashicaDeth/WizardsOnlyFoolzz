class_name Materia
extends RefCounted

## drug-70. The materia by class (DESIGN/THE_BRAIN.md §4): what each class of
## substance does to the screen, to the body you play, and what it costs, over
## a curve on the world clock.
##
## Greg (5 Oct): "making the drug pass VFX and game mechanics, smoking physics,
## and then using TouchDesigner to make interesting drug sequences."
##
## What this owns, and what it leaves alone:
##
## - The picture is `psychedelic.gdshader` at different dials. A class is a
##   preset of those dials at its peak, never a shader of its own (FINAL_V §16:
##   "one shader, many dials"). `PsychedelicRig.set_dial()` is the only way in.
## - The curve is onset, peak and comedown in **world minutes**
##   (`WorldClock.minutes()`), not in frames or real seconds, so sleeping off a
##   comedown and a time-skip both read through it the way the rest of the
##   world does.
## - Tolerance is per class per world day: the second dose of a class in one
##   day is weaker, the third weaker again.
## - The three authored substances (`substances.gd`) keep their own curves in
##   `substance_experience.gd`; here they are filed under `new_world`, which is
##   THE_BRAIN's own definition of them ("substances that only exist after the
##   collapse, made from what is left"). Which real class each one *reads as*
##   is Greg's call and is asked in AgentHub/queue/questions.
##
## The boundary (THE_BRAIN §4) holds in this file: no quantities, no routes, no
## preparation, no combinations. A class has a feeling, a picture and a cost.
## Durations are game pacing on the world clock and are not real ones.
##
## Deliriants are horror, never fun: darkness, figures at the edge of vision,
## and lost time. They do not raise altitude (they go to Da'ath, which is not
## on the map) and `materia_test` asserts their preset never touches the bright
## palette or any of the decorative dials.

const PlaneLadderRef := preload("res://systems/plane_ladder.gd")

## Dials, all behind one switch each. Defaults are noted in REMASTER_LOG.md.
## Scales the picture (0 = no screen effect at all, the mechanics still apply).
static var visual_scale := 1.0
## Scales sway, aim, stamina, pain and perception.
static var feel_scale := 1.0
## Scales lungs, body and standing costs.
static var cost_scale := 1.0
## How much weaker each repeat of a class in the same world day is. 0.55 means
## the second dose is 55% of the first, the third 30%.
static var tolerance_falloff := 0.55

const CLASS_ORDER := [
	"stimulant", "cannabinoid", "psychedelic", "dissociative", "deliriant",
	"empathogen", "depressant", "opioid", "new_world",
]

## Palettes, as gradient stops dark to light, keyed by name. Fed into the
## shader's LUT. "prism" is the bright cycling one and is the only palette
## called fun anywhere in this project; the deliriant never gets it.
const FUN_PALETTE := "prism"
const PALETTES := {
	"prism": ["2a0b4a", "c2177a", "ff8a1e", "d8f23a", "3ef0e6"],
	"warm": ["2b0d14", "a83a4c", "f2a07a", "ffe3c8"],
	"ash": ["050404", "1c1210", "33231d", "4a4a3e"],
	"cold": ["03060c", "1d3550", "7d9ab4", "d4e2ee"],
	"sodium": ["0b1214", "2c5560", "d08a3c", "f3e7c9"],
	"smoke": ["0f140a", "3d4a22", "a3a660", "e8e2b8"],
	"lead": ["0b0c0f", "3a3f48", "8a8f96", "c9cbcc"],
	"honey": ["120a04", "5a3410", "b77a2c", "efcf8e"],
	"wire": ["1a2418", "8a9a4a", "e6d4ac"],
}

## The classes. `onset`, `peak` and `comedown` are world minutes (the clock runs
## 0.4 world minutes a real second, so a 60-minute arc is two and a half real
## minutes). `dials` is the shader at the top of the curve. `feel` is signed:
## sway and perception 0-1, aim and stamina -1 (worse) to +1 (better), pain is
## relief 0-1. `cost` is paid once, at the dose. `altitude` is how high the
## class carries you at peak (PlaneLadder's 0-100 scale); `plane` is where it
## goes; `register` is which of the four worlds it is seen through.
## `xray_reach` scales how far the X-ray reads.
const CLASSES := {
	"stimulant": {
		"onset": 3.0, "peak": 22.0, "comedown": 34.0, "palette": "sodium",
		"dials": {"chromatic_offset": 0.003, "saturation_shift": 0.15, "pulse_strength": 0.6, "lut_strength": 0.15},
		"feel": {"sway": 0.05, "aim": 0.25, "stamina": 0.5, "pain": 0.1, "perception": 0.1},
		"cost": {"body": 5.0, "standing": 0.1},
		"altitude": 0.0, "plane": "malkuth", "register": "assiah", "xray_reach": 1.1,
	},
	"cannabinoid": {
		"onset": 2.0, "peak": 26.0, "comedown": 30.0, "palette": "smoke",
		"dials": {"displacement_strength": 0.015, "displacement_scroll": 0.12, "feedback_strength": 0.25,
			"feedback_zoom": 1.004, "lut_strength": 0.3, "saturation_shift": 0.1, "pulse_strength": 0.3},
		"feel": {"sway": 0.25, "aim": -0.15, "stamina": -0.15, "pain": 0.3, "perception": 0.3},
		"cost": {"body": 3.0, "standing": 0.05},
		"altitude": 12.0, "plane": "yesod", "register": "yetzirah", "xray_reach": 1.0,
	},
	"psychedelic": {
		"onset": 10.0, "peak": 40.0, "comedown": 45.0, "palette": "prism",
		"dials": {"kaleidoscope_segments": 6.0, "kaleidoscope_spin": 0.25, "kaleidoscope_clear": 0.42, "lut_strength": 0.55, "palette_cycle": 0.08,
			"displacement_strength": 0.05, "feedback_strength": 0.45, "feedback_zoom": 1.015, "feedback_spin": 0.04,
			"chromatic_offset": 0.012, "pulse_strength": 0.5, "saturation_shift": 0.45},
		"feel": {"sway": 0.35, "aim": -0.35, "stamina": 0.0, "pain": 0.15, "perception": 0.85},
		"cost": {"body": 8.0, "standing": 0.2},
		"altitude": 48.0, "plane": "tiferet", "register": "beriah", "xray_reach": 1.6,
	},
	"dissociative": {
		"onset": 3.0, "peak": 18.0, "comedown": 25.0, "palette": "cold",
		"dials": {"tunnel": 0.55, "feedback_strength": 0.6, "feedback_zoom": 0.985, "saturation_shift": -0.5,
			"lut_strength": 0.35, "displacement_strength": 0.02, "chromatic_offset": 0.004,
			"cut_intensity": 0.08, "cut_rate": 1.5},
		"feel": {"sway": 0.6, "aim": -0.5, "stamina": -0.3, "pain": 0.7, "perception": 0.5},
		"cost": {"body": 10.0, "standing": 0.25},
		"altitude": 36.0, "plane": "hod", "register": "yetzirah", "xray_reach": 0.7,
	},
	"deliriant": {
		"onset": 15.0, "peak": 50.0, "comedown": 60.0, "palette": "ash",
		"dials": {"darkness": 0.75, "edge_figures": 1.0, "saturation_shift": -0.65, "lut_strength": 0.45,
			"displacement_strength": 0.025, "displacement_scroll": 0.05, "cut_intensity": 0.12, "cut_rate": 0.7,
			"feedback_strength": 0.2},
		"feel": {"sway": 0.5, "aim": -0.6, "stamina": -0.2, "pain": 0.2, "perception": 0.0},
		"cost": {"body": 16.0, "standing": 0.3},
		# Da'ath is not on the map: nothing is reached and nothing comes back.
		"altitude": 0.0, "plane": "daath", "register": "assiah", "xray_reach": 0.4,
		# Lost time: world minutes that go missing at random through the peak.
		"lost_minutes": 18.0,
	},
	"empathogen": {
		"onset": 6.0, "peak": 30.0, "comedown": 40.0, "palette": "warm",
		"dials": {"lut_strength": 0.4, "saturation_shift": 0.3, "feedback_strength": 0.2, "feedback_zoom": 1.003,
			"pulse_strength": 0.7, "chromatic_offset": 0.004, "displacement_strength": 0.008},
		"feel": {"sway": 0.15, "aim": -0.1, "stamina": 0.3, "pain": 0.3, "perception": 0.2},
		"cost": {"body": 9.0, "standing": 0.15},
		"altitude": 20.0, "plane": "netzach", "register": "beriah", "xray_reach": 1.0,
	},
	"depressant": {
		"onset": 4.0, "peak": 28.0, "comedown": 35.0, "palette": "lead",
		"dials": {"saturation_shift": -0.3, "displacement_strength": 0.02, "displacement_scroll": 0.08,
			"feedback_strength": 0.35, "darkness": 0.2, "lut_strength": 0.2},
		"feel": {"sway": 0.55, "aim": -0.45, "stamina": -0.4, "pain": 0.35, "perception": 0.0},
		"cost": {"body": 7.0, "standing": 0.1},
		"altitude": 0.0, "plane": "malkuth", "register": "assiah", "xray_reach": 0.8,
	},
	"opioid": {
		"onset": 3.0, "peak": 30.0, "comedown": 45.0, "palette": "honey",
		"dials": {"lut_strength": 0.45, "saturation_shift": -0.15, "darkness": 0.35, "feedback_strength": 0.3,
			"displacement_strength": 0.01, "displacement_scroll": 0.05, "tunnel": 0.15},
		"feel": {"sway": 0.3, "aim": -0.2, "stamina": -0.35, "pain": 0.9, "perception": 0.0},
		"cost": {"body": 14.0, "standing": 0.3},
		"altitude": 0.0, "plane": "malkuth", "register": "assiah", "xray_reach": 0.9,
	},
	"new_world": {
		"onset": 4.0, "peak": 24.0, "comedown": 30.0, "palette": "wire",
		"dials": {"lut_strength": 0.4, "melt_strength": 0.05, "displacement_strength": 0.04, "cut_intensity": 0.2,
			"cut_rate": 6.0, "chromatic_offset": 0.01, "feedback_strength": 0.35, "feedback_zoom": 1.01},
		"feel": {"sway": 0.3, "aim": -0.25, "stamina": 0.0, "pain": 0.2, "perception": 0.6},
		"cost": {"body": 8.0, "standing": 0.2},
		"altitude": 30.0, "plane": "hod", "register": "yetzirah", "xray_reach": 1.3,
	},
}

## The smokeables and substances already in the world, by class. Cigarettes
## and vapes are THE_BRAIN's "stimulant, legal"; joints, spliffs and bongs are
## its cannabinoids. The three authored substances are new-world (see above).
const ITEM_CLASS := {
	"cigarette": "stimulant", "vape": "stimulant",
	"joint": "cannabinoid", "spliff": "cannabinoid", "bong": "cannabinoid",
	"marrow_dust": "new_world", "choir_bloom": "new_world", "static_hymn": "new_world",
}

## The dials the deliriant may never move off rest: everything that makes a
## frame prettier rather than worse.
const DECORATIVE_DIALS := ["kaleidoscope_segments", "kaleidoscope_spin", "palette_cycle", "mirror_fold", "pulse_strength"]

const DOSES_KEY := "materia_doses"
const FEEL_KEYS := ["sway", "aim", "stamina", "pain", "perception"]


static func class_of(item_id: String) -> String:
	return str(ITEM_CLASS.get(item_id, item_id if CLASSES.has(item_id) else ""))


static func preset(class_id: String) -> Dictionary:
	return (CLASSES.get(class_id, {}) as Dictionary).duplicate(true)


## Total length of the arc, in world minutes.
static func duration(class_id: String) -> float:
	var spec: Dictionary = CLASSES.get(class_id, {})
	if spec.is_empty():
		return 0.0
	return float(spec.onset) + float(spec.peak) + float(spec.comedown)


## Where on the arc, `minutes` world minutes after the dose. `level` is 0-1:
## up through onset, held through peak, down through comedown. Smooth at both
## seams, so a dial never jumps.
static func curve(class_id: String, minutes: float) -> Dictionary:
	var spec: Dictionary = CLASSES.get(class_id, {})
	if spec.is_empty() or minutes < 0.0:
		return {"phase": "sober", "level": 0.0}
	var onset := float(spec.onset)
	var peak := float(spec.peak)
	var down := float(spec.comedown)
	if minutes < onset:
		return {"phase": "onset", "level": smoothstep(0.0, 1.0, minutes / maxf(onset, 0.001))}
	if minutes < onset + peak:
		return {"phase": "peak", "level": 1.0}
	if minutes < onset + peak + down:
		return {"phase": "comedown", "level": 1.0 - smoothstep(0.0, 1.0, (minutes - onset - peak) / maxf(down, 0.001))}
	return {"phase": "sober", "level": 0.0}


## How strong the next dose of this class would be, given what was already
## taken today. 1.0 for the first of the day.
static func tolerance_strength(subject_id: String, class_id: String, day := -1) -> float:
	var today := WorldClock.day() if day < 0 else day
	var repeats := 0
	for raw in WorldHistory.subject(subject_id).get(DOSES_KEY, []) as Array:
		var dose: Dictionary = raw
		if str(dose.get("class", "")) == class_id and int(dose.get("day", -1)) == today:
			repeats += 1
	return pow(tolerance_falloff, float(repeats))


## Take one. `source` is the item it came from (a smokeable id, a substance id,
## or "sample" in the lab). Pays the cost once, records the dose, returns it.
## `now` is world minutes and is supplied so a test can run a day in a loop.
static func dose(subject_id: String, class_id: String, now: float, source := "sample", smoked := false) -> Dictionary:
	if not CLASSES.has(class_id):
		return {"ok": false, "reason": "NO SUCH CLASS"}
	var spec: Dictionary = CLASSES[class_id]
	var day := int(floor(now / WorldClock.MINUTES_PER_DAY))
	var strength := tolerance_strength(subject_id, class_id, day)
	var record := {
		"class": class_id, "source": source, "started": now, "day": day,
		"strength": strength, "smoked": smoked,
	}
	var subject := WorldHistory.subject(subject_id)
	var doses: Array = (subject.get(DOSES_KEY, []) as Array).duplicate()
	doses.append(record)
	WorldHistory.begin_ledger_batch()
	# The cost. Body is consciousness now and pain on the way down, through the
	# same `anatomy_state` every other dose writes; standing is recorded on the
	# event (who notices it is Greg's call, see the question file).
	var cost: Dictionary = spec.cost
	var anatomy: Dictionary = (subject.get("anatomy_state", {}) as Dictionary).duplicate()
	var body := float(cost.get("body", 0.0)) * cost_scale * strength
	anatomy["consciousness"] = clampf(float(anatomy.get("consciousness", 100.0)) - body, 0.0, 100.0)
	WorldHistory.amend_subject(subject_id, {DOSES_KEY: doses, "anatomy_state": anatomy})
	WorldHistory.record_event("materia_dose", {
		"subject_id": subject_id, "class": class_id, "source": source,
		"strength": snappedf(strength, 0.01), "smoked": smoked,
		"body_cost": snappedf(body, 0.01),
		"standing_cost": snappedf(float(cost.get("standing", 0.0)) * cost_scale * strength, 0.01),
	})
	WorldHistory.commit_ledger_batch()
	record["ok"] = true
	return record


## Every live dose at once. Returns the shader dials (strongest deviation from
## rest wins per dial, so two doses never stack into a broken picture), the
## summed feel, the altitude and the dominant class.
## `ladder_altitude` is `PlaneLadder.altitude()` if the caller already has it:
## that read walks the whole event log, so a per-frame caller passes a cached
## value instead of paying for it every frame.
static func state(subject_id: String, now: float, ladder_altitude := -1.0) -> Dictionary:
	var rest: Dictionary = PsychedelicRig.NEUTRAL
	var dials: Dictionary = rest.duplicate()
	var feel := {}
	for key in FEEL_KEYS:
		feel[key] = 0.0
	var altitude := 0.0
	var top_class := ""
	var top_level := 0.0
	var phase := "sober"
	var plane := "malkuth"
	var xray := 1.0
	for raw in WorldHistory.subject(subject_id).get(DOSES_KEY, []) as Array:
		var record: Dictionary = raw
		var class_id := str(record.get("class", ""))
		var arc := curve(class_id, now - float(record.get("started", 0.0)))
		var level := float(arc.level) * float(record.get("strength", 1.0))
		if level <= 0.0:
			continue
		var spec: Dictionary = CLASSES[class_id]
		var mine := peak_dials(class_id, level * visual_scale)
		for dial_name: String in mine:
			var neutral := float(rest.get(dial_name, 0.0))
			if absf(float(mine[dial_name]) - neutral) > absf(float(dials[dial_name]) - neutral):
				dials[dial_name] = mine[dial_name]
		var spec_feel: Dictionary = spec.feel
		for key in FEEL_KEYS:
			feel[key] = float(feel[key]) + float(spec_feel.get(key, 0.0)) * level * feel_scale
		altitude = maxf(altitude, float(spec.altitude) * level)
		if level > top_level:
			top_level = level
			top_class = class_id
			phase = str(arc.phase)
			plane = str(spec.plane)
			xray = lerpf(1.0, float(spec.xray_reach), level)
	feel["sway"] = clampf(float(feel.sway), 0.0, 1.0)
	feel["perception"] = clampf(float(feel.perception), 0.0, 1.0)
	feel["pain"] = clampf(float(feel.pain), 0.0, 1.0)
	feel["aim"] = clampf(float(feel.aim), -1.0, 1.0)
	feel["stamina"] = clampf(float(feel.stamina), -1.0, 1.0)
	return {
		"dials": dials, "feel": feel, "class": top_class, "level": top_level,
		"phase": phase, "plane": plane, "xray_reach": xray,
		"altitude": maxf(altitude, ladder_altitude if ladder_altitude >= 0.0 else PlaneLadderRef.altitude(subject_id)),
		"palette": str((CLASSES.get(top_class, {}) as Dictionary).get("palette", "")),
	}


## A class's dials at `level` (0 rest, 1 peak), scaled the way each dial wants:
## zoom is a multiplier around 1, segment counts are whole, rates are speeds.
static func peak_dials(class_id: String, level: float) -> Dictionary:
	var rest: Dictionary = PsychedelicRig.NEUTRAL
	var out: Dictionary = rest.duplicate()
	var spec: Dictionary = CLASSES.get(class_id, {})
	for dial_name: String in spec.get("dials", {}):
		var target := float(spec.dials[dial_name])
		var neutral := float(rest.get(dial_name, 0.0))
		match dial_name:
			"kaleidoscope_segments":
				out[dial_name] = 0.0 if level < 0.3 else maxf(2.0, roundf(target * level))
			"cut_rate", "displacement_scroll":
				out[dial_name] = target
			"kaleidoscope_clear":
				# Held, not grown: the middle stays clear from the first fold on.
				out[dial_name] = target if level > 0.0 else neutral
			_:
				out[dial_name] = lerpf(neutral, target, clampf(level, 0.0, 1.5))
	return out


## The planes a level of altitude lets you see, low to high. Da'ath is never
## in the list; the deliriant's own plane is reported by `state().plane`.
static func planes_seen(altitude: float) -> Array:
	var out: Array = []
	for plane_id in PlaneLadderRef.reachable_planes():
		if altitude >= PlaneLadderRef.floor_requirement(str(plane_id), "see"):
			out.append(str(plane_id))
	return out


## The palette as a 256 x 1 LUT texture for the shader. A LUT baked out of
## TouchDesigner (`art/materia/lut_<name>.png`, MateriaBakes) replaces it.
static func palette_texture(palette_name: String) -> Texture2D:
	var baked := MateriaBakes.texture("lut_%s.png" % palette_name)
	if baked != null:
		return baked
	var stops: Array = PALETTES.get(palette_name, PALETTES["wire"])
	var image := Image.create(256, 1, false, Image.FORMAT_RGB8)
	for x in 256:
		var t := float(x) / 255.0 * float(stops.size() - 1)
		var index := mini(int(floor(t)), stops.size() - 2)
		image.set_pixel(x, 0, Color(str(stops[index])).lerp(Color(str(stops[index + 1])), t - float(index)))
	return ImageTexture.create_from_image(image)


## Brightest stop of a palette, by luminance. The deliriant's must stay dark.
## A baked LUT counts: if one replaces the palette, its middle row is read,
## so a bright bake cannot slip a fun palette onto the deliriant unnoticed.
static func palette_peak_luminance(palette_name: String) -> float:
	var best := 0.0
	var baked := MateriaBakes.image_of("lut_%s.png" % palette_name)
	if baked != null:
		var row := baked.get_height() / 2
		for x in baked.get_width():
			best = maxf(best, baked.get_pixel(x, row).get_luminance())
		return best
	for stop in PALETTES.get(palette_name, []) as Array:
		best = maxf(best, Color(str(stop)).get_luminance())
	return best


## Drops doses whose arc is over. Call at a seam (the lab does it each
## minute), never every frame.
static func settle(subject_id: String, now: float) -> int:
	var kept: Array = []
	for raw in WorldHistory.subject(subject_id).get(DOSES_KEY, []) as Array:
		var record: Dictionary = raw
		var over := float(record.get("started", 0.0)) + duration(str(record.get("class", "")))
		# Kept through the rest of the world day so tolerance still counts it.
		if now <= over or int(record.get("day", -1)) == int(floor(now / WorldClock.MINUTES_PER_DAY)):
			kept.append(record)
	WorldHistory.amend_subject(subject_id, {DOSES_KEY: kept})
	return kept.size()
