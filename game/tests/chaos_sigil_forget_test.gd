extends Node

## AJ1.5. "Forgetting is mechanical: a charged sigil you keep looking at
## does not fire." A real clock against WorldClock's own time, not a flavour
## flag — charging is itself a moment of attention, looking at it again
## resets the clock, and only real elapsed time without either lets it fire.

var failures: Array[String] = []


func check(condition: bool, what: String) -> void:
	print("PASS " if condition else "FAIL ", what)
	if not condition:
		failures.append(what)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	WorldHistory.world_minute = 0.0
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})

	print("AJ1.5 - charging it is itself a moment of attention, not a blank slate")
	var sigil: Dictionary = ChaosSigil.charge("let the debt go quiet", "player").get("sigil", {})
	check(not ChaosSigil.can_fire(sigil), "freshly charged, it cannot fire yet - the intent is still fully in mind")
	var too_soon := ChaosSigil.fire(sigil)
	check(not bool(too_soon.get("ok", false)), "attempting to fire it immediately is refused")
	check(str(too_soon.get("reason", "")) == "STILL BEING HELD IN MIND", "and says why, in the same register charge()'s own refusals use")

	print("AJ1.5 - real time passing actually lets it go")
	WorldClock.pass_time(ChaosSigil.FORGET_HOURS - 0.5)
	check(not ChaosSigil.can_fire(sigil), "not quite long enough yet")
	WorldClock.pass_time(1.0)
	check(ChaosSigil.can_fire(sigil), "long enough now, genuinely forgotten")

	print("AJ1.5 - looking at it again resets the clock rather than letting the delay keep counting underneath")
	var glanced_at := ChaosSigil.remember(sigil)
	check(not ChaosSigil.can_fire(glanced_at), "checking on it again puts it right back in mind")
	WorldClock.pass_time(ChaosSigil.FORGET_HOURS + 1.0)
	check(ChaosSigil.can_fire(glanced_at), "and it takes the full delay again from that point, not from the original charge")

	print("AJ1.5 - firing an actually-forgotten sigil succeeds, once")
	var fired := ChaosSigil.fire(glanced_at)
	check(bool(fired.get("ok", false)), "a genuinely forgotten sigil actually fires")
	var spent: Dictionary = fired.get("sigil", {})
	check(bool(spent.get("fired", false)), "and carries its own spent state")
	var refire := ChaosSigil.fire(spent)
	check(not bool(refire.get("ok", false)) and str(refire.get("reason", "")) == "ALREADY SPENT", "firing it twice is refused, not a free second effect")

	print("AJ1.5 - a sigil that was never charged cannot be fired at all")
	var uncharged := ChaosSigil.seal_for("never charged")
	var never_charged_fire := ChaosSigil.fire(uncharged)
	check(not bool(never_charged_fire.get("ok", false)) and str(never_charged_fire.get("reason", "")) == "NEVER CHARGED", "charging is not skippable on the way to firing")

	print("AJ1.5 - a real, findable event only on an actual fire")
	var events: Array[String] = []
	for event in WorldHistory.events:
		events.append(str(event.get("type", "")))
	check(events.count("sigil_fired") == 1, "exactly one fire really happened, the refused attempts recorded nothing")

	print("CHAOS_SIGIL_FORGET_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
