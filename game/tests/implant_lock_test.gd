extends Node

## N5.2/N5.3/N5.4/N5.5/N5.6/N5.7. Factory hardware fills real slots and is
## locked — locked has to mean discouraged, never disabled, and what comes
## out has to be a real carried object with a lien on it, not a number that
## just vanishes. N5.5: pulling a locked part is recorded and CellOutz's own
## standing toward you actually moves, since the axis they sit on is
## "Ownership" and defying their lock is the Ascent act of refusing it.

const ANATOMY := preload("res://systems/anatomy_component.gd")
const CARRY := preload("res://systems/carry.gd")

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
	WorldHistory.register_subject("player", {"faction_id": ""})
	var body: Node = ANATOMY.new()
	add_child(body)
	body.configure("implant_test")
	body.install_factory_loadout()

	var standing_before := WorldHistory.faction_price_factor("celloutz", WorldHistory.subject("player"))

	check(body.installed_parts.has("head") and body.installed_parts.has("torso") and body.installed_parts.has("left_arm"), "the factory loadout actually fills its three real zones")
	check(not body.installed_parts.has("right_arm"), "and leaves the zones it does not touch genuinely empty")
	check(bool(body.installed_parts.head.get("locked", false)), "factory hardware actually comes in locked")

	# A locked slot warns rather than silently refusing or silently complying.
	var warned: Dictionary = body.pull_part("head")
	check(not bool(warned.get("ok", true)), "a locked slot is not pulled on the first ask")
	check(str(warned.get("reason", "")) == "LOCKED", "and says why")
	check(str(warned.get("warning", "")) == ANATOMY.LOCKED_WARNING, "in CellOutz's own words, not a generic refusal")
	check(body.installed_parts.has("head"), "and the hardware has not actually moved yet")

	# Confirmed, it actually goes — locked means discouraged, never disabled.
	var pulled: Dictionary = body.pull_part("head", true)
	check(bool(pulled.get("ok", false)), "confirmed, the same call that was refused now succeeds")
	check(not body.installed_parts.has("head"), "and the slot is genuinely empty now")
	check(absf(body.implant_condition("head")) < 0.001, "which reads as a real zero, not a hidden fallback (N5.6)")

	# N5.5: defying a locked slot is CellOutz's axis being defied specifically,
	# so their own price toward you actually moves, not karma in the abstract.
	var standing_after := WorldHistory.faction_price_factor("celloutz", WorldHistory.subject("player"))
	check(standing_after < standing_before, "pulling CellOutz's own lock makes CellOutz price you worse (%.3f -> %.3f)" % [standing_before, standing_after])

	# N5.7: it comes out shaped for Carry.take_chunk(), lien attached, not a
	# number that dissolves.
	var info: Dictionary = pulled.get("info", {})
	check(str(info.get("lien", "")) == "celloutz", "the pulled part still carries CellOutz's own lien")
	check(str(info.get("implant", "")) != "", "and is a named object, not an anonymous entry")
	var carry := CARRY.new()
	var carried: Dictionary = carry.take_chunk(info)
	check(not carried.is_empty() and str(carried.get("lien", "")) == "celloutz", "and Carry accepts it as a real carried object with that same lien intact")

	# An empty slot is refused outright — there is nothing there to warn about.
	var nothing: Dictionary = body.pull_part("right_leg")
	check(not bool(nothing.get("ok", true)) and str(nothing.get("reason", "")) == "EMPTY", "pulling an empty slot is refused, not a false success")

	# An unlocked part needs no confirmation at all. "heel anchors" is the
	# catalog's own right_leg entry — install_part() keys storage off the
	# part's authored zone, not whatever zone_id a caller passes.
	body.install_part("right_leg", {"id": "heel anchors"})
	var unlocked: Dictionary = body.pull_part("right_leg")
	check(bool(unlocked.get("ok", false)), "a part that was never locked comes out on the first ask")

	check(WorldHistory.event_count("implant_pulled") == 2, "every real pull is actually recorded (%d)" % WorldHistory.event_count("implant_pulled"))

	# N5.5's gate: hardware that was never CellOutz's lock to begin with is not
	# an act of defiance against them, so it does not touch their standing.
	var standing_final := WorldHistory.faction_price_factor("celloutz", WorldHistory.subject("player"))
	check(is_equal_approx(standing_final, standing_after), "pulling a part that was never locked does not move CellOutz's price again (%.3f -> %.3f)" % [standing_after, standing_final])

	if failures.is_empty():
		print("implant lock: discouraged, never disabled, and never free")
		get_tree().quit(0)
	else:
		print("implant lock FAILURES: ", failures)
		get_tree().quit(1)
