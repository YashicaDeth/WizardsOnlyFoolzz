extends Node

## AJ2.4. "Other people's sigils exist in the world and can be read, defaced
## or stolen." `read_object()`/`deface()`/`steal()` act on the exact same
## real `sigil_object` subject AJ1.6's `inscribe()` already creates - not a
## second, parallel record of what is physically in the world.

const ChaosSigil := preload("res://systems/chaos_sigil.gd")

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
	WorldHistory.register_subject("maker", {"name": "THE MAKER", "kind": "person", "grudge": 0.0})
	WorldHistory.register_subject("intruder", {"name": "THE INTRUDER", "kind": "person"})

	print("AJ2.4 - reading something that is not a sigil object at all")
	var not_found := ChaosSigil.read_object("nothing_here")
	check(not bool(not_found.get("ok", false)), "refuses a subject id that names nothing")
	var wrong_kind := ChaosSigil.read_object("maker")
	check(not bool(wrong_kind.get("ok", false)), "refuses a real subject that is not a sigil object")

	var charged: Dictionary = ChaosSigil.charge("burn the collector's ledger", "maker").get("sigil", {})
	var scratched: String = ChaosSigil.inscribe(charged, "maker", "scratched", "growing_floor").get("object_id", "")
	var worn: String = ChaosSigil.inscribe(charged, "maker", "worn", "on_the_body").get("object_id", "")

	print("AJ2.4 - other people's sigils can genuinely be read")
	var read_result := ChaosSigil.read_object(scratched)
	check(bool(read_result.get("ok", false)), "a real sigil object can be read by anyone who has its id")
	check(str(read_result.object.get("intent", "")) == "burn the collector's ledger", "and the reading shows the real stated intent")

	print("AJ2.4 - defacing marks the object and the maker actually feels it")
	var defaced := ChaosSigil.deface(scratched, "intruder")
	check(bool(defaced.get("ok", false)), "defacing a real, unspoiled object succeeds")
	check(bool(WorldHistory.subject(scratched).get("defaced", false)), "the object's own record now shows it")
	check(float(WorldHistory.subject("maker").get("grudge", 0.0)) > 0.0, "and the maker's own grudge actually rose")
	var redeface := ChaosSigil.deface(scratched, "intruder")
	check(not bool(redeface.get("ok", false)) and str(redeface.get("reason", "")) == "ALREADY DEFACED", "defacing an already-defaced object does nothing new")

	print("AJ2.4 - a fixed-in-place sigil cannot be stolen")
	var fixed_theft := ChaosSigil.steal(scratched, "intruder")
	check(not bool(fixed_theft.get("ok", false)) and str(fixed_theft.get("reason", "")) == "FIXED IN PLACE", "scratched-in media refuse theft outright")

	print("AJ2.4 - a portable sigil can genuinely be stolen")
	var grudge_before_theft := float(WorldHistory.subject("maker").get("grudge", 0.0))
	var theft := ChaosSigil.steal(worn, "intruder")
	check(bool(theft.get("ok", false)), "worn/carried media can actually change hands")
	check(str(WorldHistory.subject(worn).get("held_by", "")) == "intruder", "the object's own record shows who holds it now")
	check(str(WorldHistory.subject(worn).get("maker", "")) == "maker", "but who made it never changes")
	check(float(WorldHistory.subject("maker").get("grudge", 0.0)) > grudge_before_theft, "theft raises the maker's grudge harder than a defacement did")
	var re_steal := ChaosSigil.steal(worn, "intruder")
	check(not bool(re_steal.get("ok", false)) and str(re_steal.get("reason", "")) == "ALREADY IN THEIR OWN HANDS", "stealing what they already hold is refused")

	print("AJ2.4 - both acts leave a real, findable event")
	var events: Array[String] = []
	for event in WorldHistory.events:
		events.append(str(event.get("type", "")))
	check(events.count("sigil_defaced") == 1, "one defacement event, not zero and not two")
	check(events.count("sigil_stolen") == 1, "one theft event, not zero and not two")
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0, "object ownership, maker grudge and each public fact close one transaction")

	print("CHAOS_SIGIL_THEFT_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
