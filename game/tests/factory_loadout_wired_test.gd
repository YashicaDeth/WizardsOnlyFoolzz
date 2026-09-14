extends Node

## N5.8. `install_factory_loadout()` (N5.2-N5.7) was only ever called from its
## own unit test — the real player, built by `bone_yard_hunt.gd`'s
## `_build_player_rig()`, never got CellOutz's locked hardware at all, so the
## whole "you don't want to go rogue yet, do you" mechanic was dead on
## arrival in actual play. This proves the real spawn path, not a bare
## AnatomyComponent: a fresh decant carries factory hardware, hardware the
## character sheet already grew into a zone wins that zone instead of being
## silently overwritten, and a restored body never gets re-locked.

const HUNT := preload("res://bone_yard_hunt.tscn")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	# A genuine first decanting: no character-creation choices, no prior save.
	WorldHistory.clear_history()
	var fresh: Node = HUNT.instantiate()
	add_child(fresh)
	for _settle in 10:
		await get_tree().process_frame
	var fresh_parts: Dictionary = fresh.player_rig.anatomy.installed_parts

	check(bool(fresh_parts.get("head", {}).get("locked", false)), "a fresh decant actually carries CellOutz's locked head hardware")
	check(bool(fresh_parts.get("torso", {}).get("locked", false)), "and the locked torso hardware")
	check(not fresh_parts.has("left_arm"), "left_arm stays empty rather than gaining hardware that would make it un-severable (B6.5/B6.6)")
	check(not bool(fresh_parts.get("right_arm", {}).get("locked", false)), "while the sheet's own default arm stays unlocked, since it was never CellOutz's")
	# The regression this excludes left_arm to prevent: any installed part on a
	# limb zone stops it from ever accumulating sever stress.
	var arm_hit: Dictionary = fresh.player_rig.hit("left_arm", 60.0, 30.0, "cut", "", Vector3.LEFT)
	if not bool(arm_hit.get("severed", false)):
		arm_hit = fresh.player_rig.hit("left_arm", 60.0, 30.0, "cut", "", Vector3.LEFT)
	check(bool(arm_hit.get("severed", false)) or fresh.player_rig.severed.has("left_arm"), "a fresh player's own arm can still be severed like anyone else's")
	fresh.free()

	# The sheet already grew something into one of CellOutz's three zones —
	# that has a body's worth of history behind it and must win the slot.
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"anatomy": {"cybernetics": ["quiet-heart regulator"]}})
	var grown: Node = HUNT.instantiate()
	add_child(grown)
	for _settle in 10:
		await get_tree().process_frame
	var grown_parts: Dictionary = grown.player_rig.anatomy.installed_parts
	check(not bool(grown_parts.get("torso", {}).get("locked", false)), "a torso the sheet already grew something into is not overwritten by the factory loadout")
	check(str(grown_parts.get("torso", {}).get("id", "")) == "quiet-heart regulator", "and it is still the sheet's own part, not swapped out")
	check(bool(grown_parts.get("head", {}).get("locked", false)), "while the zone the sheet left alone still gets CellOutz's hardware")
	grown.free()

	# A returning player who already pulled their locked head implant must not
	# have it silently re-locked back in on the next load.
	WorldHistory.clear_history()
	var first: Node = HUNT.instantiate()
	add_child(first)
	for _settle in 10:
		await get_tree().process_frame
	first.player_rig.anatomy.pull_part("head", true)
	WorldHistory.amend_subject("player", {"anatomy_state": first.player_rig.anatomy.snapshot()})
	first.free()

	var reloaded: Node = HUNT.instantiate()
	add_child(reloaded)
	for _settle in 10:
		await get_tree().process_frame
	var reloaded_parts: Dictionary = reloaded.player_rig.anatomy.installed_parts
	check(not reloaded_parts.has("head"), "a slot already pulled stays pulled across a reload rather than being re-locked")
	reloaded.free()

	if failures.is_empty():
		print("factory loadout: CellOutz's hardware finally reaches the actual player")
		get_tree().quit(0)
	else:
		print("factory loadout FAILURES: ", failures)
		get_tree().quit(1)
