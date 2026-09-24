extends Node

## The overworld event generator: enough distinct events (Greg asked for
## hundreds), the same seed always gives the same event, every event ends in a
## quest, a trade or a fight, and the two written-in-full events exist.

const Generator := preload("res://systems/event_generator.gd")
const Parts := preload("res://systems/event_parts.gd")

var failures: Array[String] = []


func _ready() -> void:
	var events := Generator.all_events()
	var count := events.size()
	print("EVENT_GENERATOR distinct=%d raw=%d" % [count, Generator.raw_combinations()])
	_check(count >= 300, "at least 300 distinct events (got %d)" % count)
	_check(count < Generator.raw_combinations(), "the coherence filter removes something")

	var ids := {}
	for event in events:
		ids[event.id] = true
	_check(ids.size() == count, "every event id is distinct")

	var kinds := {"quest": 0, "trade": 0, "fight": 0}
	var bad := 0
	for event in events:
		var outcome: Dictionary = event.outcome
		var kind := str(outcome.get("kind", ""))
		if not kinds.has(kind):
			bad += 1
			continue
		kinds[kind] += 1
		match kind:
			"quest":
				if str((outcome.get("task", {}) as Dictionary).get("title", "")).is_empty():
					bad += 1
			"trade":
				var offer: Dictionary = outcome.get("offer", {})
				if str(offer.get("gives", "")).is_empty() or str(offer.get("asks", "")).is_empty():
					bad += 1
			"fight":
				if not str(outcome.get("tier", "")) in ["mini_boss", "boss"]:
					bad += 1
		if (event.beats as Array).is_empty():
			bad += 1
	print("EVENT_GENERATOR outcomes quest=%d trade=%d fight=%d" % [kinds.quest, kinds.trade, kinds.fight])
	_check(bad == 0, "every event resolves to a complete quest, trade or fight with beats (%d bad)" % bad)
	for kind in kinds:
		_check(int(kinds[kind]) > 0, "some events end in %s" % kind)

	# Determinism: the same seed gives the same event.
	var first := Generator.pick(4242)
	var again := Generator.pick(4242)
	_check(not first.is_empty() and str(first.id) == str(again.id), "the same seed picks the same event")
	var spread := {}
	for seed_value in 200:
		spread[str(Generator.pick(seed_value).id)] = true
	_check(spread.size() > 60, "200 seeds give a spread of events (%d distinct)" % spread.size())
	var actors := {}
	for seed_value in 400:
		actors[str(Generator.pick(seed_value).actor)] = true
	_check(actors.size() == Parts.ACTORS.size(), "every actor can be picked (%d of %d)" % [actors.size(), Parts.ACTORS.size()])
	_check(str(Generator.event_by_id(str(first.id)).get("id", "")) == str(first.id), "an event id looks the same event up again")

	# Incoherent combinations are filtered.
	_check(not Generator.is_coherent("crazed_driver", "your_life", "ruined_shrine", "ram", "goes_crazy"), "a car cannot ram you in a shrine")
	_check(not Generator.is_coherent("wounded_courier", "a_trade", "road", "ram", "names_a_price"), "a courier on foot cannot ram")
	_check(not Generator.is_coherent("failed_subject", "your_life", "road", "collapse", "names_a_price"), "someone with nothing to sell cannot name a price")
	for event in Generator.events_matching({"actor": "crazed_driver"}):
		if not "drivable" in (Parts.PLACES[event.place].tags as Array):
			failures.append("driver event off drivable ground: %s" % event.id)
			break

	# The two written in full.
	var driver := Generator.signature_event("crazed_driver")
	_check(not driver.is_empty() and bool(driver.signature), "THE CRAZED DRIVER is a coherent signature event")
	_check(str(driver.get("staging", "")) == "vehicle_ram" and str((driver.get("outcome", {}) as Dictionary).get("kind", "")) == "fight", "the driver rams and ends in a fight")
	var monks := Generator.signature_event("splinter_monks")
	_check(not monks.is_empty() and bool(monks.signature), "THE SPLINTER MONKS is a coherent signature event")
	_check(str(monks.get("staging", "")) == "monk_rite" and bool(monks.get("vision", false)), "the monks invoke a spirit vision")
	_check(str((monks.get("outcome", {}) as Dictionary).get("kind", "")) == "trade", "the monks' signature ends in a trade")
	var freed := 0
	for event in Generator.events_matching({"actor": "splinter_monks", "outcome": "quest"}):
		if str(((event.outcome as Dictionary).task as Dictionary).parent) == "end_all_suffering":
			freed += 1
	_check(freed > 0, "freeing the splinter is filed under END ALL SUFFERING")

	for failure in failures:
		print("FAIL ", failure)
	print("EVENT_GENERATOR_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok ", what)
	else:
		failures.append(what)
