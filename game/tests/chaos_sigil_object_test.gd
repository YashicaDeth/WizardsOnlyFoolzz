extends Node

## AJ1.6. "It goes into the world as an object - scratched, burned, carried
## or worn." A real, findable `WorldHistory` subject per inscription, not a
## flag on the sigil's own dictionary — so it can be stood next to, defaced
## or stolen later (AJ2.4), the same way any other physical thing can be.

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

	print("AJ1.6 - an uncharged intent cannot go into the world as though it were real")
	var uncharged := ChaosSigil.seal_for("never charged")
	var refused := ChaosSigil.inscribe(uncharged, "player", "scratched")
	check(not bool(refused.get("ok", false)), "refused without ever having been charged")
	check(str(refused.get("reason", "")) == "NOTHING CHARGED TO PUT INTO THE WORLD", "and says why")

	print("AJ1.6 - a charged sigil becomes a real object in one of the four real media")
	var sigil: Dictionary = ChaosSigil.charge("burn the debt collector's ledger", "player").get("sigil", {})
	var scratched := ChaosSigil.inscribe(sigil, "player", "scratched", "growing_floor")
	check(bool(scratched.get("ok", false)), "inscribing a charged sigil succeeds")
	var object_id := str(scratched.get("object_id", ""))
	check(not object_id.is_empty(), "and hands back a real object id")
	var object := WorldHistory.subject(object_id)
	check(str(object.get("kind", "")) == "sigil_object", "it is a real WorldHistory subject, findable by anyone who can read one")
	check(str(object.get("medium", "")) == "scratched", "carrying the medium it was actually made in")
	check(str(object.get("maker", "")) == "player", "and who actually made it")
	check(int(object.get("seed", -1)) == int(sigil.get("seed", -2)), "the same mark the sigil itself draws, not a different one")
	check(str(object.get("location_id", "")) == "growing_floor", "and where it was left")

	print("AJ1.6 - a made-up medium is refused rather than silently accepted")
	var bad_medium := ChaosSigil.inscribe(sigil, "player", "tattooed")
	check(not bool(bad_medium.get("ok", false)) and str(bad_medium.get("reason", "")) == "NO SUCH MEDIUM", "only the four real media are accepted")

	print("AJ1.6 - the same intent can genuinely go into the world twice, in different media")
	var worn := ChaosSigil.inscribe(sigil, "player", "worn")
	check(bool(worn.get("ok", false)), "a second inscription of the same sigil succeeds")
	check(str(worn.get("object_id", "")) != object_id, "and is a distinct object, not the same one moved")

	print("AJ1.6 - inscribing does not silently skip the event log")
	var events: Array[String] = []
	for event in WorldHistory.events:
		events.append(str(event.get("type", "")))
	check(events.count("sigil_inscribed") == 2, "one findable event per real inscription (%d)" % events.count("sigil_inscribed"))

	print("CHAOS_SIGIL_OBJECT_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
