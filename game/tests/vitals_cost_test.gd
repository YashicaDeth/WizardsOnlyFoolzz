extends Node

## What the vitals model costs on a body nobody is looking at.
##
## `Perfusion` and `AnatomyComponent._process()` claim an intact bystander pays
## one compare a frame and never enters the model. This turns that claim into
## something that fails loudly:
##
## - **Behaviour.** Every body here carries a `CountingVitals`, a `Perfusion`
##   that records each `advance()` it is asked for. Sixty-four intact bodies run
##   real frames in the tree and the count must stay at zero; one wound later,
##   only that body's count moves. Switching `_process` off would have hidden a
##   gate that never worked, so counting entries is the part that proves it.
## - **Wall clock, isolated.** `_process()` in a typed loop with the tree's own
##   ticking off, measured beside two references: a script whose `_process` does
##   nothing (the floor every ticked node pays) and a body with the model
##   engaged (what the gate saves).
## - **Wall clock, in place.** The frame with all sixty-four ticking, then none,
##   then all again — read against its own noise floor and reported for the
##   coarse instrument it is, the way `population_budget_test` reads the crowd.
## - **The body that cannot leave.** A body whose bleeding has been stopped but
##   whose circulation is short can never refill past its delivery, so it stays
##   in the model from then on. That is the ceiling on what "free" can mean, and
##   it is measured rather than assumed.

const BODIES := 64
const SETTLE_FRAMES := 180
const WOUND_FRAMES := 30
const CALLS := 64000
## A frame is 16600µs. One microsecond per body is 0.006% of a frame, and sixty
## bodies still come to 0.06ms.
const IDLE_BUDGET_US := 1.0
## Sixty-four bystanders must not add a tenth of a millisecond to a frame.
const CROWD_BUDGET_MS := 0.10
## A settled downed body recomputes its target every frame by design (it is not
## settled in a way that can be cached without duplicating the body). It must
## still be small enough to be a rounding error.
const SETTLED_BUDGET_US := 10.0

var failures: Array[String] = []
var checks := 0


func check(condition: bool, label: String) -> void:
	checks += 1
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


## A `Perfusion` that counts entries into the model. Not production
## instrumentation: the gate has to be provable from outside the class that
## claims it, or its only evidence is the comment beside it.
class CountingVitals extends Perfusion:
	var advances := 0

	func advance(anatomy: Object, open_vessels: int, delta: float) -> bool:
		advances += 1
		return super(anatomy, open_vessels, delta)


## The floor every ticked node pays — a script with a `_process` that does
## nothing. Whatever an idle body costs above this is the model's own share.
class EmptyTick extends Node:
	func _process(_delta: float) -> void:
		pass


## A body's owner as the model reads it: `BaselineHuman` keeps the stumps in
## `severed`, and `_open_vessels()` reads that rather than counting its own.
class Holder extends Node:
	var severed: Array = []


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	var bodies: Array[AnatomyComponent] = []
	var counters: Array[CountingVitals] = []
	for index in BODIES:
		var holder := Holder.new()
		holder.name = "bystander_%d" % index
		add_child(holder)
		var anatomy := AnatomyComponent.new()
		holder.add_child(anatomy)
		anatomy.configure("cost_%d" % index, 5000.0, {})
		var counting := CountingVitals.new()
		anatomy.vitals = counting
		bodies.append(anatomy)
		counters.append(counting)

	# --- 1. the gate, under the engine's own dispatch ------------------------
	for _frame in SETTLE_FRAMES:
		await get_tree().process_frame
	var entries := 0
	for counter in counters:
		entries += counter.advances
	print("bystanders: %d bodies x %d frames -> %d entries into the model" % [BODIES, SETTLE_FRAMES, entries])
	check(entries == 0, "sixty-four intact bodies run %d frames without one entry into the vitals model" % SETTLE_FRAMES)
	var all_full := true
	for anatomy in bodies:
		if anatomy.oxygen_pct() != 100:
			all_full = false
	check(all_full, "every reserve is still full after them")

	# --- 2. and only the body somebody hurt is in it -------------------------
	var wounded: AnatomyComponent = bodies[0]
	wounded.bleed_rate = 45.0
	for _frame in WOUND_FRAMES:
		await get_tree().process_frame
	var neighbours := 0
	for index in range(1, BODIES):
		neighbours += counters[index].advances
	print("one bleeding, sixty-three intact: %d entries vs %d" % [counters[0].advances, neighbours])
	check(counters[0].advances > 0, "the wounded body is in the model every frame (%d entries)" % counters[0].advances)
	check(neighbours == 0, "its sixty-three neighbours stay out of it while it bleeds (%d entries)" % neighbours)
	check(wounded.vitals.oxygen < 100.0, "with the reserve already leaving full (%0.2f%%)" % wounded.vitals.oxygen)

	# --- 2b. blood taken out from outside the API still wakes it -------------
	# `v01_foe` and the organ system write these fields directly. A gate that
	# only looked at the reserve would leave the body reporting 100% on blood it
	# no longer has, so the volume is part of the condition.
	var drained: AnatomyComponent = bodies[5]
	drained.blood_remaining = drained.blood_capacity * 0.99
	for _frame in 8:
		await get_tree().process_frame
	check(counters[5].advances > 0, "blood removed directly still brings that body into the model (%d entries)" % counters[5].advances)
	check(drained.vitals.oxygen < 100.0, "and its reserve leaves full instead of holding a lie (%0.2f%%)" % drained.vitals.oxygen)

	# --- 3. microseconds, with the tree's ticking out of the way -------------
	for anatomy in bodies:
		anatomy.set_process(false)

	var idle: AnatomyComponent = bodies[1]
	var start := Time.get_ticks_usec()
	for _call in CALLS:
		idle._process(1.0 / 60.0)
	var idle_us := float(Time.get_ticks_usec() - start) / CALLS

	var empty := EmptyTick.new()
	add_child(empty)
	empty.set_process(false)
	start = Time.get_ticks_usec()
	for _call in CALLS:
		empty._process(1.0 / 60.0)
	var empty_us := float(Time.get_ticks_usec() - start) / CALLS

	# The same script with the model engaged. A six-hundredth of a second a call
	# so the body stays bleeding and alive for the whole loop instead of dying
	# halfway through and measuring a corpse.
	var engaged: AnatomyComponent = bodies[2]
	engaged.internal_bleed_rate = 2.0
	engaged.blood_remaining = engaged.blood_capacity * 0.8
	start = Time.get_ticks_usec()
	for _call in CALLS:
		engaged._process(1.0 / 600.0)
	var engaged_us := float(Time.get_ticks_usec() - start) / CALLS

	print("per body per frame: idle %.3fus | empty _process %.3fus | model engaged %.3fus" % [idle_us, empty_us, engaged_us])

	# What the gate would cost if it asked the model whether there is anywhere
	# for the reserve to go, rather than only whether the reserve is full.
	var probe: AnatomyComponent = bodies[4]
	start = Time.get_ticks_usec()
	for _call in CALLS:
		Perfusion.flow(probe, 0)
	var flow_us := float(Time.get_ticks_usec() - start) / CALLS
	start = Time.get_ticks_usec()
	for _call in CALLS:
		probe.lung_state()
	var lung_us := float(Time.get_ticks_usec() - start) / CALLS
	start = Time.get_ticks_usec()
	for _call in CALLS:
		Perfusion.oxygen_target(probe, 0)
	var target_us := float(Time.get_ticks_usec() - start) / CALLS
	print("model parts: flow %.3fus | lung_state %.3fus | oxygen_target %.3fus" % [flow_us, lung_us, target_us])
	check(idle_us <= IDLE_BUDGET_US,
		"an idle body costs %.3fus of a frame, inside the %.1fus budget" % [idle_us, IDLE_BUDGET_US])
	check(idle_us - empty_us < IDLE_BUDGET_US * 0.5,
		"and within %.3fus of a script that does nothing at all" % [idle_us - empty_us])
	check(idle_us < engaged_us * 0.5,
		"the gate keeps it at %.0f%% of what the same body costs in the model" % [100.0 * idle_us / maxf(engaged_us, 0.001)])

	# --- 4. in place, across a whole frame ----------------------------------
	for anatomy in bodies:
		anatomy.set_process(true)
	var with_ms := await _frames(120)
	for anatomy in bodies:
		anatomy.set_process(false)
	var without_ms := await _frames(120)
	for anatomy in bodies:
		anatomy.set_process(true)
	var again_ms := await _frames(120)
	var noise_ms := absf(with_ms - again_ms)
	var crowd_ms: float = (with_ms + again_ms) * 0.5 - without_ms
	print("frame: %.3f / %.3f ms with sixty-four bystanders, %.3f ms without -> %.3f ms for the crowd (noise %.3f ms)" % [
		with_ms, again_ms, without_ms, crowd_ms, noise_ms,
	])
	if crowd_ms <= noise_ms:
		print("  inside the noise of this scene: reported, not claimed")
	check(crowd_ms < CROWD_BUDGET_MS,
		"sixty-four unwatched bodies cost %.3f ms of a frame, inside %.2f ms" % [crowd_ms, CROWD_BUDGET_MS])

	# --- 5. the body that cannot come back to full ---------------------------
	# A stump with the bleeding stopped: delivery tops out below 100, so the
	# reserve hangs at what the circulation can hold and the model runs every
	# frame from then on. Caching that would mean caching the body's damage, so
	# it is measured as the honest ceiling rather than optimised away.
	var settled: AnatomyComponent = bodies[3]
	settled.set_process(false)
	(settled.get_parent() as Holder).severed = ["left_arm"]
	settled.vitals.oxygen = 88.0
	start = Time.get_ticks_usec()
	for _call in CALLS:
		settled._process(1.0 / 6000.0)
	var settled_us := float(Time.get_ticks_usec() - start) / CALLS
	print("settled body with one stump: %.3fus per frame at %.1f%% reserve" % [settled_us, settled.vitals.oxygen])
	check(settled_us < SETTLED_BUDGET_US,
		"a body that can never refill costs %.3fus a frame, inside %.1fus" % [settled_us, SETTLED_BUDGET_US])
	check(settled.vitals.oxygen < 100.0, "and it is still being told it is short (%0.1f%%)" % settled.vitals.oxygen)

	print("VITALS_COST_RESULT checks=%d failures=%d" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)


## Wall clock over N rendered frames. `TIME_FPS` only updates once a second, so
## it cannot be used for a difference this small.
func _frames(count: int) -> float:
	await get_tree().process_frame
	var start := Time.get_ticks_usec()
	for _frame in count:
		await get_tree().process_frame
	return float(Time.get_ticks_usec() - start) / 1000.0 / float(count)
