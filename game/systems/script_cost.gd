class_name ScriptCost
extends RefCounted

## Which function is eating the frame.
##
## `sandbox_perf_probe` answered exactly this question for draw calls, by
## charging every visible mesh to the subsystem that built it -- which is how
## anybody knows `ProceduralAshbloomDistricts` owns 2141 of them. Script time
## never had the equivalent. `process` sits at 20.16ms against a 16.67ms
## budget, the thirty-odd `_update_*` calls in
## `bone_yard_hunt._physics_process` are where it goes, and which of them is
## unknown. It has been guessed at twice and the brief has listed it as the
## biggest unexamined thing in the project for as long as it has existed.
##
## **Off by default, and free when off.** `mark()` and `lap()` both return on a
## bool before touching the clock, so a shipping frame does not measure itself.
## The probe turns it on, samples, and turns it off again.
##
## Charged per label rather than per call site, so a function called twice in a
## frame -- `_update_hud()` is -- shows its true total and says it was called
## twice, rather than appearing as two smaller entries that look innocent.

static var active := false
static var _total_us: Dictionary = {}
static var _calls: Dictionary = {}
static var _frames := 0


static func enable() -> void:
	active = true


static func disable() -> void:
	active = false


static func reset() -> void:
	_total_us.clear()
	_calls.clear()
	_frames = 0


## Start of a run of laps. Zero when inactive, which `lap()` treats as "do
## nothing" so the caller needs no branch of its own.
static func mark() -> int:
	return Time.get_ticks_usec() if active else 0


## Charge everything since `since` to `label`, and hand back a fresh mark so
## laps chain down a function without a second clock read between them.
static func lap(label: String, since: int) -> int:
	if not active or since == 0:
		return 0
	var now := Time.get_ticks_usec()
	_total_us[label] = int(_total_us.get(label, 0)) + (now - since)
	_calls[label] = int(_calls.get(label, 0)) + 1
	return now


## One pass of the instrumented function. Counted separately from calls,
## because the per-frame cost is what has to fit in the budget and a function
## called three times a frame spends three times as long there.
static func frame() -> void:
	if active:
		_frames += 1


static func frames() -> int:
	return _frames


## Worst first, in microseconds per frame -- the unit the budget is in.
##
## `share` is against the measured total rather than against 16.67ms, because
## what matters first is which of these to open, not how far over the frame is.
static func ranked() -> Array:
	var spans := maxi(_frames, 1)
	var measured := 0
	for label: String in _total_us:
		measured += int(_total_us[label])
	var out: Array = []
	for label: String in _total_us:
		var total := int(_total_us[label])
		out.append({
			"label": label,
			"per_frame_us": float(total) / float(spans),
			"total_us": total,
			"calls_per_frame": float(int(_calls.get(label, 0))) / float(spans),
			"share": float(total) / float(maxi(measured, 1)),
		})
	out.sort_custom(func(a, b): return float(a.per_frame_us) > float(b.per_frame_us))
	return out


## Everything the instrumented laps accounted for, in milliseconds per frame.
##
## Compared against `Performance.TIME_PROCESS`, the gap is whatever is *not*
## instrumented -- engine work, uninstrumented calls, the rest of the scene
## tree. A small gap means the list below is the whole story; a large one means
## the expensive thing has not been wrapped yet, and reporting the ranking
## without saying which would be the more misleading of the two.
static func measured_ms() -> float:
	var spans := maxi(_frames, 1)
	var measured := 0
	for label: String in _total_us:
		measured += int(_total_us[label])
	return float(measured) / float(spans) / 1000.0
