extends Node

const VAT := preload("res://vat_chamber.tscn")
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
	WorldHistory.clear_history()
	var vat = VAT.instantiate()
	add_child(vat)
	await get_tree().process_frame
	check(BrainIndex.chip("player").is_empty(), "the procedure is not recorded before the intake is filed")
	var filed_state: Dictionary = vat.intake.sheet.apply_to_world()
	vat.intake.filed.emit(filed_state)
	await get_tree().process_frame
	var chip := BrainIndex.chip("player")
	check(not chip.is_empty(), "the captured opening installs the wetwire as decanting begins")
	check(str(chip.get("owner_faction", "")) == "celloutz" and str(chip.get("installed_by", "")) == "growing_floor_intake",
		"the hardware names the institution and procedure that put it there")
	check(not WorldHistory.subject("player").has("anatomy_state"),
		"pre-decant installation does not counterfeit a restored body")
	var installed_sequence := -1
	var woke_sequence := -1
	for event: Dictionary in WorldHistory.events:
		if str(event.get("type", "")) == "wetwire_installed":
			installed_sequence = int(event.get("sequence", -1))
		elif str(event.get("type", "")) == "opening_woke":
			woke_sequence = int(event.get("sequence", -1))
	check(installed_sequence >= 0 and installed_sequence < woke_sequence,
		"the institution installs it before the world records the player waking")
	vat.queue_free()
	await get_tree().process_frame

	var hunt = HUNT.instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(hunt.player_rig.anatomy.installed_parts.has("head"),
		"the same installed chip reaches the live player head")
	check(hunt._all_rigs().has(hunt.player_rig), "the player's real body participates in the X-ray sweep")
	hunt._update_xray(0.2, true)
	check(WorldHistory.event_count("captivity_procedure_recalled") == 1,
		"the first later look into the body recovers the captured procedure")
	check("FOREIGN TOWER IN YOUR SKULL" in hunt.prompt.text and str(chip.get("serial", "")) in hunt.prompt.text,
		"the reveal names the physical hardware rather than presenting a lore card")
	hunt._update_xray(0.2, false)
	hunt._update_xray(0.2, true)
	check(WorldHistory.event_count("captivity_procedure_recalled") == 1,
		"repeated scans cannot counterfeit repeated memories")
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0,
		"installation and recollection leave the ledger closed")
	hunt.queue_free()
	print("CAPTIVITY_PROCEDURE_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
