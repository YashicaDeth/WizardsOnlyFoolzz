class_name RunTimer
extends RefCounted

## Greg, 26 September (question boxes): the first 30 minutes are timed. The
## timer is hidden while you play and shown on a card when you surface, with
## the time spent in each area. "Working" means no crash, no dead end, under
## 30 minutes.
##
## Kept in WorldHistory, so it survives scene changes, deaths (a rebirth in
## the vat does not restart the clock) and quitting mid-run. A run starts the
## first time the vat room loads with no run open, and ends on surfacing.

const SUBJECT := "opening_run"
const TARGET_SECONDS := 30.0 * 60.0
const LABELS := {
	"growing_floor": "GROWING FLOOR",
	"service_arcade": "SERVICE ARCADE",
	"lower_works": "LOWER WORKS",
	"old_drains": "OLD DRAINS",
	"support_unit": "SUPPORT UNIT",
	"vehicle_bay": "VEHICLE BAY",
}


static func _now() -> float:
	return Time.get_unix_time_from_system()


static func record() -> Dictionary:
	return WorldHistory.subject(SUBJECT)


static func running() -> bool:
	var run := record()
	return not run.is_empty() and not bool(run.get("finished", false))


## Opens a run unless one is already going.
static func start() -> void:
	if running():
		return
	WorldHistory.update_subject(SUBJECT, {
		"kind": "run", "started": _now(), "finished": false, "areas": [], "total": 0.0,
	}, "opening_run_started")


static func elapsed() -> float:
	var run := record()
	if run.is_empty():
		return 0.0
	if bool(run.get("finished", false)):
		return float(run.get("total", 0.0))
	return maxf(0.0, _now() - float(run.get("started", _now())))


## First arrival in an area (re-entering the same area in a row is not new).
static func enter(area: String) -> void:
	if not running():
		return
	var run := record()
	var areas: Array = (run.get("areas", []) as Array).duplicate(true)
	if not areas.is_empty() and str((areas[areas.size() - 1] as Dictionary).get("area", "")) == area:
		return
	areas.append({"area": area, "at": snappedf(elapsed(), 0.1)})
	WorldHistory.amend_subject(SUBJECT, {"areas": areas})


## Ends the run on surfacing. Returns the summary for the card, or {} when
## there was no run (the Hunt started directly, or the run already ended).
static func finish() -> Dictionary:
	if not running():
		return {}
	var total := snappedf(elapsed(), 0.1)
	WorldHistory.update_subject(SUBJECT, {"finished": true, "total": total}, "opening_run_finished")
	return summary()


## [{label, seconds}] per area in the order entered, plus the total.
static func summary() -> Dictionary:
	var run := record()
	var areas: Array = run.get("areas", [])
	var total := float(run.get("total", elapsed()))
	var rows: Array = []
	for index in areas.size():
		var entry: Dictionary = areas[index]
		var until: float = float((areas[index + 1] as Dictionary).get("at", total)) if index + 1 < areas.size() else total
		rows.append({"label": str(LABELS.get(str(entry.area), str(entry.area).to_upper())), "seconds": maxf(0.0, until - float(entry.at))})
	return {"rows": rows, "total": total, "under_target": total <= TARGET_SECONDS}


static func clock(seconds: float) -> String:
	var whole := int(round(seconds))
	return "%d:%02d" % [whole / 60, whole % 60]
