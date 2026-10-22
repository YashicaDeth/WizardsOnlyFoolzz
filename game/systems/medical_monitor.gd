class_name MedicalMonitor
extends RefCounted

## The body as an instrument reading (Carl 0.8.71's `M` screen, adopted in
## `DESIGN/CARL_COMPARISON.md`).
##
## Greg's rule for the design is "the body is the health bar"
## (`ARCHITECTURE/SYSTEM_MAP.md`): everything this prints already exists in
## `AnatomyComponent`, the wound table and `BaselineHuman.severed`. There is no
## second copy of any number here — `readout()` asks the body every time it is
## called, so a monitor left open while a body bleeds out is reading the same
## fields the simulation is writing.
##
## Oxygen and perfusion came later, as one model (`Perfusion`) owned by the
## anatomy rather than a number kept here: flow is derived from blood volume,
## open vessels, the spine and the heart, and the oxygen reserve is the one
## value that model remembers. The screen reads both live, like everything else.
## The pulse came with them and is derived the same way — `Perfusion.pulse()`
## reads the same fields plus the reserve, so a heart that stops stops printing.
##
## The rule for values the body does not have stays: **print `UNKNOWN`, not a
## guess.** A missing body has no circulation to report, and says so.

const CellOutzType := preload("res://systems/celloutz_type.gd")

const BONE := Color("e6d4ac")
const HOT := Color("a8281a")
const BRASS := Color("b0552a")
const SCAN := Color("35b7a7")
const SOOT := Color(0.05, 0.036, 0.028, 0.88)
const DIM := Color(0.55, 0.5, 0.44, 0.8)

## What a label says when the body genuinely cannot answer.
const UNKNOWN := "UNKNOWN"
const NONE := "NONE"


## Every number on the screen, read live from one body.
##
## `has_anatomy` is false for anything that is not a real rig (a machine that
## answers `xray_report()`, a missing body), and then every physiological field
## is null so `lines()` can print `UNKNOWN` rather than a plausible zero.
static func readout(body: Node) -> Dictionary:
	var out := {
		"subject": "", "has_anatomy": false,
		"blood_ml": null, "capacity_ml": null, "blood_pct": null,
		"bleed": null, "internal_bleed": null,
		"oxygen": null, "perfusion": null, "pulse": null,
		"consciousness": null, "pain": null,
		"vessels_open": null, "spine": null,
		"downed": false,
		"fractures": [], "exposed": [],
		"last_hit": {},
		"dead": false, "failed": false,
	}
	var rig := body as BaselineHuman
	if rig == null or not is_instance_valid(rig) or rig.anatomy == null:
		return out
	var anatomy := rig.anatomy
	out.has_anatomy = true
	out.subject = str(anatomy.subject_id)
	out.dead = bool(anatomy.dead)
	out.failed = bool(anatomy.failed)
	out.capacity_ml = snappedf(float(anatomy.blood_capacity), 0.1)
	out.blood_ml = snappedf(float(anatomy.blood_remaining), 0.1)
	out.blood_pct = roundi(clampf(float(anatomy.blood_remaining) / maxf(1.0, float(anatomy.blood_capacity)), 0.0, 1.0) * 100.0)
	out.bleed = snappedf(float(anatomy.bleed_rate), 0.1)
	out.internal_bleed = snappedf(float(anatomy.internal_bleed_rate), 0.1)
	out.oxygen = anatomy.oxygen_pct()
	out.perfusion = anatomy.perfusion_pct()
	out.pulse = anatomy.pulse_bpm()
	out.downed = bool(anatomy.downed)
	out.consciousness = roundi(clampf(float(anatomy.consciousness), 0.0, 100.0))
	out.pain = roundi(clampf(float(anatomy.pain), 0.0, 100.0))
	# The body's vessel granularity is the limb: `_sever_limb()` opens the stump's
	# vessel and nothing finer is tracked, so this counts open stumps rather than
	# pretending to know how many vessels a body has.
	out.vessels_open = rig.severed.size()
	# The spine is an organ here, and `xray_findings()` already states it, but a
	# list of strings is not a number the screen can lay out.
	var spine: Dictionary = anatomy.organs.get("spine", {})
	if spine.is_empty():
		out.spine = null
	elif bool(spine.get("removed", false)):
		out.spine = "TAKEN"
	elif bool(spine.get("ruptured", false)):
		out.spine = "RUPTURED"
	else:
		var damaged: Array = spine.get("vertebrae_damaged", [])
		out.spine = "%d / %d DAMAGED" % [damaged.size(), BaselineHuman.SPINE_VERTEBRAE] if not damaged.is_empty() else "INTACT"
	for zone_id in anatomy.zones:
		var kind := str((anatomy.zones[zone_id] as Dictionary).get("fracture", ""))
		if not kind.is_empty():
			out.fractures.append({"zone": str(zone_id), "kind": kind})
	for organ_id in anatomy.organs:
		var organ: Dictionary = anatomy.organs[organ_id]
		if bool(organ.get("ruptured", false)):
			out.exposed.append("RUPTURED " + str(OrganSystem.ORGAN_LABELS.get(organ_id, str(organ_id).to_upper())))
		elif bool(organ.get("removed", false)):
			out.exposed.append("TAKEN " + str(OrganSystem.ORGAN_LABELS.get(organ_id, str(organ_id).to_upper())))
	var wounds: Array = anatomy.wounds
	if not wounds.is_empty():
		var wound: Dictionary = wounds[wounds.size() - 1]
		out.last_hit = {
			"zone": str(wound.get("zone", "")),
			"type": str(wound.get("type", "")),
			"damage": snappedf(float(wound.get("damage", 0.0)), 0.1),
			"absorbed": snappedf(float(wound.get("absorbed", 0.0)), 0.01),
			"fracture": str(wound.get("fracture", "")),
			"time_msec": int(wound.get("time_msec", 0)),
		}
	return out


## Exactly what the screen prints, in order. The test asserts on this, so the
## drawn panel and the measured one cannot drift apart.
static func lines(body: Node) -> Array[String]:
	var report := readout(body)
	var out: Array[String] = []
	if not bool(report.has_anatomy):
		out.append("BODY // UNKNOWN")
		out.append("BLD UNKNOWN")
		out.append("BLEED UNKNOWN")
		out.append("INTERNAL UNKNOWN")
		out.append("O2 UNKNOWN  PERF UNKNOWN")
		out.append("PULSE UNKNOWN")
		out.append("CON UNKNOWN  PAIN UNKNOWN")
		out.append("VESSELS UNKNOWN")
		out.append("SPINE UNKNOWN")
		out.append("FRACTURES UNKNOWN")
		out.append("EXPOSED UNKNOWN")
		out.append("HIT UNKNOWN")
		out.append("ABSORBED UNKNOWN")
		return out
	var subject := str(report.subject).to_upper()
	# The header states the worst thing true of the body, in the order the body
	# cares about it. DOWN is the anatomy's own `downed` — a body on the floor
	# that the resolution window can still decide about — not a new state.
	var standing := ""
	if bool(report.dead):
		standing = "  DEAD"
	elif bool(report.failed):
		standing = "  FAILED"
	elif bool(report.downed):
		standing = "  DOWN"
	out.append("BODY // %s%s" % [subject if not subject.is_empty() else "SUBJECT", standing])
	out.append("BLD %.2f L  %d%% OF %.2f L" % [float(report.blood_ml) / 1000.0, int(report.blood_pct), float(report.capacity_ml) / 1000.0])
	out.append("BLEED %.1f mL/s" % float(report.bleed))
	out.append("INTERNAL %.1f mL/s" % float(report.internal_bleed))
	# Flow and the reserve it feeds, side by side because they answer different
	# questions: a body can still move blood with its lungs ruined.
	out.append("O2 %d%%  PERF %d%%" % [int(report.oxygen), int(report.perfusion)])
	# The rate that flow is being made at, derived on read like the two above.
	# A body with nothing circulating prints NONE rather than a number it does
	# not have.
	var bpm := int(report.pulse)
	out.append(("PULSE %d BPM" % bpm) if bpm > 0 else ("PULSE %s" % NONE))
	out.append("CON %d%%  PAIN %d" % [int(report.consciousness), int(report.pain)])
	out.append("VESSELS %d OPEN" % int(report.vessels_open))
	out.append(("SPINE %s" % str(report.spine)) if report.spine != null else "SPINE UNKNOWN")
	var fractures: Array = report.fractures
	if fractures.is_empty():
		out.append("FRACTURES %s" % NONE)
	else:
		var named: Array[String] = []
		for entry: Dictionary in fractures:
			named.append("%s %s" % [str(entry.zone).replace("_", " ").to_upper(), str(entry.kind).to_upper()])
		out.append("FRACTURES " + ", ".join(named))
	var exposed: Array = report.exposed
	out.append("EXPOSED " + ("NONE" if exposed.is_empty() else ", ".join(PackedStringArray(exposed))))
	var hit: Dictionary = report.last_hit
	if hit.is_empty():
		# Both lines always print, so the panel is the same height whether or not
		# anything has been done to the body yet.
		out.append("HIT %s" % NONE)
		out.append("ABSORBED %s" % NONE)
	else:
		out.append("HIT %s %.0f // %s%s" % [
			str(hit.type).to_upper(), float(hit.damage),
			str(hit.zone).replace("_", " ").to_upper(),
			" // FRACTURE" if not str(hit.fracture).is_empty() else "",
		])
		out.append("ABSORBED %d%%" % roundi(float(hit.absorbed) * 100.0))
	return out


## Draws the panel into a caller's canvas, the way `XrayCursor` and the scan
## overlay do, so a screen can carry it without owning a node.
static func paint(canvas: CanvasItem, at: Vector2, body: Node, alpha := 1.0) -> void:
	paint_lines(canvas, at, lines(body), alpha)


static func paint_lines(canvas: CanvasItem, at: Vector2, printed: Array[String], alpha := 1.0) -> void:
	if printed.is_empty():
		return
	var width := 0.0
	for line in printed:
		width = maxf(width, CellOutzType.width(line, 10.0, 1.0))
	var box := Rect2(at, Vector2(width + 20.0, 12.0 + printed.size() * 14.0))
	canvas.draw_rect(box, SOOT * Color(1, 1, 1, alpha))
	canvas.draw_rect(box, BRASS * Color(1, 1, 1, 0.7 * alpha), false, 1.0)
	var y := box.position.y + 5.0
	for index in printed.size():
		# The first line is the header, the blood and bleed lines are the ones
		# that move, and an absent value is drawn dim rather than as a number.
		var tone: Color = BONE
		if index == 0:
			tone = BRASS
		elif str(printed[index]).contains(UNKNOWN) or str(printed[index]).ends_with(NONE):
			tone = DIM
		elif str(printed[index]).begins_with("BLEED") or str(printed[index]).begins_with("BLD"):
			tone = HOT if index == 2 and str(printed[index]) != "BLEED 0.0 mL/s" else SCAN
		CellOutzType.draw_text(canvas, Vector2(box.position.x + 10.0, y), printed[index], 10.0, tone * Color(1, 1, 1, alpha), 1.0)
		y += 14.0
