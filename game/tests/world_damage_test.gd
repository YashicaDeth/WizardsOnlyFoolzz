extends Node

## AB2.1/AB2.2/AB2.3. The destruction primitive `DESIGN/DESTRUCTION.md`
## scopes as step one: a breakable thing's condition, read cheaply, recorded
## where everything else persistent already lives, refused for a subject the
## world does not know about. No geometry, no break-state visuals — this is
## the ledger the honest scope actually calls for first.

const WORLD_DAMAGE := preload("res://systems/world_damage.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()

	check(is_equal_approx(WORLD_DAMAGE.condition("street_light_9"), 1.0), "a subject nobody has ever damaged simply reads as intact")
	check(WORLD_DAMAGE.band("street_light_9") == "intact", "and the generic band agrees (\"%s\")" % WORLD_DAMAGE.band("street_light_9"))

	var phantom := WORLD_DAMAGE.damage("street_light_9", 0.3, "test")
	check(not bool(phantom.get("ok", false)), "damage refuses a subject the world does not know about yet, rather than inventing one")

	WorldHistory.register_subject("street_light_9", {"kind": "streetlight"})
	var first_hit := WORLD_DAMAGE.damage("street_light_9", 0.05, "grazed")
	check(bool(first_hit.get("ok", false)), "damage lands once the subject is real")
	check(is_equal_approx(WORLD_DAMAGE.condition("street_light_9"), 0.95), "and the condition actually moved by exactly the amount applied (%.2f)" % WORLD_DAMAGE.condition("street_light_9"))
	check(str(first_hit.get("band", "")) == "intact" and not bool(first_hit.get("crossed_band", true)), "a light graze at 0.95 is still \"intact\" on the generic ladder, so nothing crossed yet")

	var recent := WorldHistory.recent_events(5)
	check(recent.any(func(event): return str(event.get("type", "")) == "object_damaged" and str(event.get("details", {}).get("subject_id", "")) == "street_light_9"), "the hit is recorded in WorldHistory, not just mutated in place")

	var second_hit := WORLD_DAMAGE.damage("street_light_9", 0.55, "vehicle_impact")
	check(is_equal_approx(WORLD_DAMAGE.condition("street_light_9"), 0.4), "a second hit accumulates rather than overwriting the first (%.2f)" % WORLD_DAMAGE.condition("street_light_9"))
	check(str(second_hit.get("band", "")) == "wrecked" and bool(second_hit.get("crossed_band", false)), "and a real hit at 0.4 is reported as actually crossing out of \"intact\" (\"%s\")" % str(second_hit.get("band", "")))

	var overkill := WORLD_DAMAGE.damage("street_light_9", 5.0, "explosion")
	check(is_equal_approx(WORLD_DAMAGE.condition("street_light_9"), 0.0), "damage floors at zero rather than going negative")
	check(WORLD_DAMAGE.is_destroyed("street_light_9"), "and reads as genuinely destroyed once it does")
	check(str(overkill.get("band", "")) == "destroyed", "the generic ladder's own bottom rung")

	var fixed := WORLD_DAMAGE.repair("street_light_9", 0.35, "crew_patch")
	check(bool(fixed.get("ok", false)) and is_equal_approx(WORLD_DAMAGE.condition("street_light_9"), 0.35), "repair moves it back up by exactly what was applied (%.2f)" % WORLD_DAMAGE.condition("street_light_9"))
	check(not WORLD_DAMAGE.is_destroyed("street_light_9"), "and it is no longer destroyed once repaired above zero")
	WORLD_DAMAGE.repair("street_light_9", 5.0, "crew_patch")
	check(is_equal_approx(WORLD_DAMAGE.condition("street_light_9"), 1.0), "repair ceilings at full rather than overshooting")

	# An object class with its own authored break states has to be able to
	# ask against its own ladder, not just the generic one.
	WorldHistory.register_subject("vault_door_1", {"kind": "door"})
	var door_bands := [
		{"floor": 0.5, "label": "sealed"},
		{"floor": 0.0, "label": "blown"},
	]
	var door_hit := WORLD_DAMAGE.damage("vault_door_1", 0.6, "charge", door_bands)
	check(str(door_hit.get("band", "")) == "blown", "a caller's own ladder is what decides the band, not the generic one (\"%s\")" % str(door_hit.get("band", "")))
	check(WorldHistory.event_count("object_damaged") == 4 and WorldHistory.event_count("object_repaired") == 2 and int(WorldHistory.get("_ledger_batch_depth")) == 0, "every accepted mutation records exactly once and closes its ledger transaction")
	# Condition is one shared number regardless of which ladder asked about it
	# last — 0.4 left over from a 0.6 hit reads "wrecked" on the *generic*
	# ladder even though the door's own ladder called the identical number
	# "blown". Two vocabularies over one real value, not two values.
	check(WORLD_DAMAGE.band("vault_door_1") == "wrecked", "and querying it later with the generic ladder reads the same real number through its own words (\"%s\")" % WORLD_DAMAGE.band("vault_door_1"))

	if failures.is_empty():
		print("world damage: a condition, read cheap, recorded once, refused nowhere it should not land")
		get_tree().quit(0)
	else:
		print("world damage FAILURES: ", failures)
		get_tree().quit(1)
