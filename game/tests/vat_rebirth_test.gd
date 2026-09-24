extends Node

## Death is rebirth in a vat (Greg, 24 September 2026), through the real
## route: Hollis shoots you dead in the Service Arcade, your gear stays on the
## body, the claimant's vat grows you back with no examination, and the
## arcade you walk back into remembers everything, Hollis included.

const ARCADE := preload("res://service_arcade.tscn")
const VAT := preload("res://vat_chamber.tscn")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _labels() -> Array:
	return (WorldHistory.subject("inventory").get("items", []) as Array).map(func(item): return str(item.get("label", "")) if item is Dictionary else str(item))


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	# --- The system: who claims you, what stays behind, what comes back. ---
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person", "status": "loose"})
	var carry := Carry.new()
	carry.items.append({"label": "BREACH TOOL", "kind": "tool", "mass": 4.0, "perishes": false, "age": 0.0})
	carry.items.append({"label": "CELL OUTZ BREACH NINE", "kind": "weapon", "rounds": 2, "mass": 1.1, "perishes": false, "age": 0.0})
	carry.save_to_history()
	Clothing.wear("player", "scavenged_coat")
	check(VatRebirth.claimant() == "celloutz", "with no other claim, CellOutz owns the body it grew")
	var death := VatRebirth.die("service_arcade", "shot", "guard_hollis", Vector3(1, 0, -28))
	check(_labels().is_empty() and Clothing.worn("player") == "bare", "nothing carried or worn survives the death")
	var remains := WorldHistory.subject(str(death.remains_id))
	check((remains.get("items", []) as Array).size() == 2 and str(remains.get("worn_layer", "")) == "scavenged_coat", "the old body keeps the gear, the gun and the coat")
	check(VatRebirth.is_pending() and int(WorldHistory.subject("player").get("deaths", 0)) == 1, "the player is marked for regrowth and the death is counted")
	check(str(death.scene) == "res://vat_chamber.tscn" and WorldHistory.event_count("player_died") == 1, "the death is recorded and routes to the claimant's vat")
	WorldHistory.amend_subject("player", {"captor_faction": "choir_of_marrow"})
	check(VatRebirth.claimant() == "choir_of_marrow" and str(VatRebirth.vat_for(VatRebirth.claimant()).label) == "OSSUARY INTAKE TANK", "a captor's claim decides whose vat grows you")
	WorldHistory.amend_subject("player", {"captor_faction": ""})
	var recovered := VatRebirth.recover(str(death.remains_id))
	check(bool(recovered.ok) and _labels().has("BREACH TOOL") and Clothing.worn("player") == "scavenged_coat", "the old body can be stripped of everything it held")
	check(not bool(VatRebirth.recover(str(death.remains_id)).ok), "and only once")

	# --- The preset is saved when the examination is filed. ---
	WorldHistory.clear_history()
	var opening = VAT.instantiate()
	add_child(opening)
	await get_tree().process_frame
	var filed_name: String = opening.intake.sheet.display_name
	opening.intake._finish_filing()
	await get_tree().process_frame
	check(CharacterPresets.names().has(filed_name), "filing the examination saves the character preset")
	opening.queue_free()
	await get_tree().process_frame

	# --- Hollis escalates and kills; the gear stays on the arcade floor. ---
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person", "status": "loose"})
	var arcade = ARCADE.instantiate()
	add_child(arcade)
	await get_tree().process_frame
	arcade.player.global_position = arcade.WEAPON_AT
	arcade._interact()
	arcade.player.global_position = arcade.CARD_AT
	arcade._interact()
	check(_labels().has("BREACH TOOL") and _labels().has("STAFF ACCESS CARD"), "the ram and the card go into Carry when taken")
	var post: FacilityGuardPost = arcade.guard_post
	var in_range: Vector3 = post.guard.global_position + Vector3(0, 0, 6.0)
	arcade.player.global_position = in_range
	arcade._physics_process(0.016)
	check(arcade.blood == 100.0 and WorldHistory.event_count("facility_guard_fired") == 1, "his first shot is a warning over your head")
	for tick in 20:
		if arcade.died:
			break
		post.fire_cooldown = 0.0
		arcade.player.global_position = in_range
		arcade._physics_process(0.016)
	check(arcade.died, "standing in his line of fire, his shots kill you")
	check(_labels().is_empty() and not arcade.weapon_taken, "you die with nothing in your hands")
	var left_here := VatRebirth.remains_at("service_arcade")
	check(left_here.size() == 1 and (left_here[0].get("items", []) as Array).size() == 2, "your old body lies in the arcade holding the ram and the card")
	check(int(WorldHistory.subject(FacilityGuardPost.GUARD_ID).get("killed_player", 0)) == 1, "Hollis remembers that he killed you")
	arcade.queue_free()
	await get_tree().process_frame

	# --- Regrown in the vat: no examination, straight to the tank. ---
	var vat = VAT.instantiate()
	add_child(vat)
	await get_tree().process_frame
	check(vat.rebirth and vat.intake == null and vat.phase == "submerged", "the regrown body wakes in the tank with no examination")
	check(str(vat.active_beats[0].text).begins_with("REGROWTH COMPLETE  //  BODY 2"), "the tank says which body this is")
	vat.clock = 5.7
	vat.phase = "voiding"
	vat._update_sequence(0.05)
	check(vat.breakout_complete and not VatRebirth.is_pending(), "breaking out completes the rebirth")
	check(str(WorldHistory.subject("player").get("status", "")) == "regrown", "the record says regrown, not decanted")
	vat.queue_free()
	await get_tree().process_frame

	# --- The arcade the regrown body walks back into. ---
	arcade = ARCADE.instantiate()
	add_child(arcade)
	await get_tree().process_frame
	post = arcade.guard_post
	check(not arcade.card_on_pedestal and not arcade.weapon_on_floor and not arcade.weapon_taken, "the pedestals stay empty and your hands are empty")
	check(arcade.remains_nodes.size() == 1 and arcade.objective.text.contains("RECOVER YOUR GEAR"), "your old body is there, and the objective points you at it")
	check(post.knows_player and post.warning_shots_left == 0, "Hollis knows you, and you get no warning shot this time")
	arcade.player.global_position = post.guard.global_position + Vector3(0, 0, 6.0)
	arcade._physics_process(0.016)
	check(arcade.blood < 100.0, "his first shot at the regrown body lands")
	var body_at: Vector3 = (arcade.remains_nodes.values()[0][0] as Node3D).global_position
	arcade.player.global_position = body_at + Vector3(0, 1.0, 0.8)
	arcade._interact()
	check(arcade.weapon_taken and arcade.card_taken and _labels().has("BREACH TOOL"), "taking your gear back off the old body puts the ram back in your hands")
	arcade.queue_free()
	await get_tree().process_frame

	# --- Lower Works reads what you carry, not what you once took. ---
	var inventory_without_ram: Array = (WorldHistory.subject("inventory").get("items", []) as Array).filter(func(item): return str(item.get("label", "")) != "BREACH TOOL")
	WorldHistory.amend_subject("inventory", {"items": inventory_without_ram})
	var city = load("res://buried_city.tscn").instantiate()
	add_child(city)
	await get_tree().process_frame
	check(not city.breach_tool_ready, "a ram lost to a death is not ready in Lower Works")
	city.queue_free()

	print("VAT_REBIRTH_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
