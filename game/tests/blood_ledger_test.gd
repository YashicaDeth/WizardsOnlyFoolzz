extends Node

## Blood is credited from facts the game already records, to the weapon that
## earned it, and an unlock bought with it changes a number the arsenal uses.

var failures: Array[String] = []


class FakeHunt:
	extends Node
	var arsenal: Node = null
	var player_unseen := false
	var bare_handed := false
	var carried_limb_index := -1


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()

	# --- The first fight is recorded before the Hunt (and the ledger) exists.
	WorldHistory.record_event("service_arcade_breach_tool_taken", {"location": "service_arcade"})
	WorldHistory.record_event("facility_guard_fired", {"subject_id": "guard_hollis", "damage": 0.0, "warning": true})
	WorldHistory.record_event("facility_guard_fired", {"subject_id": "guard_hollis", "damage": 18.0})
	WorldHistory.record_event("facility_guard_rammed", {"subject_id": "guard_hollis", "downed": false})
	WorldHistory.record_event("facility_guard_rammed", {"subject_id": "guard_hollis", "downed": true})
	WorldHistory.record_event("facility_guard_rammed", {"subject_id": "guard_hollis", "downed": true})
	WorldHistory.record_event("lower_works_sentinel_strike", {"location": "lower_works", "damage": 6})
	WorldHistory.record_event("lower_works_sentinel_breached", {"location": "lower_works", "range": 4.0})

	var hunt := FakeHunt.new()
	var hud := Control.new()
	hud.name = "HUD"
	hunt.add_child(hud)
	add_child(hunt)
	var rig := BaselineHuman.new()
	rig.gore = false
	add_child(rig)
	rig.build("blood_holder")
	var arsenal := HunterArsenal.new()
	hunt.add_child(arsenal)
	arsenal.configure(rig)
	hunt.arsenal = arsenal
	var base_sword := float(arsenal.weapon_definition("sword").damage)
	var base_spread := float(arsenal.weapon_definition("sidearm").spread)

	var ledger := BloodLedger.new()
	ledger.attach(hunt)
	# 18 shot / 3 = 6 bled; rams 14 + 14 + 14; one takedown 15; sentinel 6 / 3 = 2; breach kill 12.
	check(ledger.weapon_blood("breach_tool") == 6 + 14 * 3 + 15 + 2 + 12, "the first fight's record pays the breach tool on arrival (got %d)" % ledger.weapon_blood("breach_tool"))
	check(int(ledger.weapon_record("breach_tool").get("takedowns", 0)) == 1, "Hollis going down twice is one takedown, not two")
	check(ledger.readout.active_count() == 1 and ledger.readout.text_of(0) == "+%d BLOOD // BREACH TOOL" % ledger.weapon_blood("breach_tool"), "arrival shows one coalesced popup: %s" % ledger.readout.text_of(0))
	var before_catch := ledger.weapon_blood("breach_tool")
	var second := BloodLedger.new()
	add_child(second)
	check(second.weapon_blood("breach_tool") == before_catch, "a second ledger reloads the saved record without paying the same fight twice")
	second.queue_free()

	# --- Live facts in the Hunt, each to its own weapon.
	PlayerActionLedger.record("npc_anatomy_hit", {"subject_id": "mark_a", "weapon": "sword", "zone": "torso", "result": {"damage": 44.0}})
	check(ledger.weapon_blood("sword") == 11, "a 44-damage cleaver hit pays the cleaver 11 (got %d)" % ledger.weapon_blood("sword"))
	WorldHistory.record_event("firearm_anatomy_hit", {"subject_id": "mark_b", "weapon": "sidearm", "zones": ["torso"], "damage": 24.0})
	check(ledger.weapon_blood("sidearm") == 6, "a 24-damage pistol hit pays the pistol 6")
	WorldHistory.update_subject("mark_b", {"status": "dead", "killed_by": "player"}, "npc_killed")
	check(ledger.weapon_blood("sidearm") == 18 and int(ledger.weapon_record("sidearm").kills) == 1, "the kill pays the weapon that last hurt that body, 12")
	check(ledger.weapon_blood("sword") == 11, "a pistol kill pays nothing to the cleaver")
	WorldHistory.record_event("npc_resolution", {"subject_id": "mark_a", "outcome": "execute", "actor": "player"})
	WorldHistory.update_subject("mark_a", {"status": "dead", "killed_by": "player"}, "npc_killed")
	check(ledger.weapon_blood("sword") == 41, "an execution pays the cleaver 30, and the death it causes is not paid again (got %d)" % ledger.weapon_blood("sword"))
	check(int(ledger.weapon_record("sword").get("finishers", 0)) == 1 and int(ledger.weapon_record("sword").get("kills", 0)) == 0, "the finisher is counted as a finisher")
	WorldHistory.update_subject("player", {"anatomy_state": {"blood": 5000}}, "anatomy_changed")
	WorldHistory.update_subject("player", {"anatomy_state": {"blood": 4600}}, "anatomy_changed")
	check(ledger.weapon_blood("sword") == 51, "400 ml of your own blood pays the weapon in hand 10 (got %d)" % ledger.weapon_blood("sword"))
	WorldHistory.update_subject("player", {"anatomy_state": {"blood": 5000}}, "anatomy_changed")
	check(ledger.weapon_blood("sword") == 51, "blood coming back pays nothing")
	PlayerActionLedger.record("grapple_takedown", {"subject_id": "mark_c"})
	check(ledger.weapon_blood("grapple") == 15 and ledger.style_earned("martial") == 15, "a grapple takedown is martial blood")
	hunt.player_unseen = true
	PlayerActionLedger.record("npc_anatomy_hit", {"subject_id": "mark_d", "weapon": "sword", "zone": "head", "result": {"damage": 8.0}})
	hunt.player_unseen = false
	check(ledger.weapon_blood("sword") == 53 and ledger.weapon_blood("unseen") == 2 and ledger.style_earned("stealth") == 2, "a blow nobody saw also feeds the stealth tree")
	ledger.flush()
	check(int((WorldHistory.subject(BloodLedger.SUBJECT).weapons as Dictionary).sword.blood) == 53, "the world's record holds the cleaver's blood")

	# --- Spending it changes the weapon.
	check(not ledger.can_unlock("light_hand"), "LIGHT HAND needs FIRST CUT first")
	check(not ledger.can_unlock("soft_foot"), "stealth cannot afford a 20-blood node with 2")
	var melee_before := ledger.available("melee")
	check(ledger.unlock("first_cut"), "FIRST CUT opens with the cleaver's blood")
	check(ledger.available("melee") == melee_before - 20, "opening it spent 20 from the melee pool")
	check(is_equal_approx(float(arsenal.weapon_definition("sword").damage), base_sword * 1.10), "the cleaver now does 10%% more damage (%.2f -> %.2f)" % [base_sword, float(arsenal.weapon_definition("sword").damage)])
	arsenal.select_weapon("sword")
	var swing: Dictionary = arsenal.begin_attack()
	check(is_equal_approx(float(swing.damage), base_sword * 1.10), "the swing report the Hunt resolves carries the learned damage")
	check(is_equal_approx(float(arsenal.weapon_definition("sidearm").spread), base_spread), "a melee node leaves the pistol alone")
	check(WorldHistory.event_count("blood_node_unlocked") == 1, "the unlock is recorded as a player act")
	check(ledger.available("firearm") == 18 and not ledger.unlock("steady_hand"), "IRON holds 18, so a 20-blood STEADY HAND is refused")
	WorldHistory.record_event("firearm_anatomy_hit", {"subject_id": "mark_e", "weapon": "sidearm", "zones": ["head"], "damage": 24.0})
	check(ledger.unlock("steady_hand"), "one more pistol hit and STEADY HAND opens")
	check(is_equal_approx(float(arsenal.weapon_definition("sidearm").spread), base_spread * 0.85) and is_equal_approx(float(arsenal.weapon_definition("shotgun").spread), float(HunterArsenal.WEAPONS.shotgun.spread) * 0.85), "every gun tightens 15%")
	var fresh := HunterArsenal.new()
	add_child(fresh)
	fresh.configure(rig)
	var reloaded := BloodLedger.new()
	add_child(reloaded)
	reloaded.apply_to_arsenal(fresh)
	check(is_equal_approx(float(fresh.weapon_definition("sword").damage), base_sword * 1.10), "a reloaded ledger reapplies what was learned to a fresh arsenal")

	# --- Tree view and popup plumbing.
	ledger.tree_view.toggle()
	check(ledger.tree_view.visible and ledger.tree_view.selected_node() == "first_cut", "the tree opens on the first style's first node")
	ledger.tree_view.move(0, 1)
	check(ledger.tree_view.selected_node() in ["light_hand", "clean_killer"], "down walks the melee tree")
	ledger.readout.lines.clear()
	ledger.readout.push("sword", "ASHLINE CLEAVER", 4, Color.RED)
	ledger.readout.push("sword", "ASHLINE CLEAVER", 3, Color.RED)
	check(ledger.readout.active_count() == 1 and ledger.readout.text_of(0) == "+7 BLOOD // ASHLINE CLEAVER", "blood from one weapon in quick succession is one line")

	print("BLOOD_LEDGER_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
