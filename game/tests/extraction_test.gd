extends Node

## B5. The claim is that robbing a body is a dig with a cost, not a loot roll:
## depth you have to get through, a tool that decides what survives the trip,
## a part that remembers whose it was, and somebody who saw you do it.

const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")

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
	WorldHistory.register_subject("settings", {"gore": "FULL"})
	WorldHistory.register_subject("inventory", {"items": [], "rust_scrip": 0})
	BaselineHuman.apply_gore_setting()
	GoreChunks.clear()

	var rig := BaselineHuman.new()
	add_child(rig)
	rig.build("mark_voss", {"cybernetics": {"head": {"name": "rangefinder eye"}, "right_arm": {"name": "salvaged torque arm"}}})
	await get_tree().physics_frame
	var anatomy: Dictionary = rig.anatomy.snapshot()

	# --- B5.2: you have to dig, and the depth is real ------------------------
	check(Extraction.target_layer(anatomy, "head") == GoreChunks.Layer.CYBERNETIC, "hardware sits at the deepest layer")
	check(Extraction.target_layer(anatomy, "left_leg") < 0, "a zone with nothing in it cannot be dug at all")
	check(Extraction.target_layer(anatomy, "torso", "heart") == GoreChunks.Layer.ORGAN, "an organ sits one layer shallower than hardware")
	var cold := Extraction.required_seconds(anatomy, "head", "blade")
	var opened := Extraction.required_seconds(anatomy, "head", "blade", GoreChunks.Layer.MUSCLE)
	check(opened < cold, "a body already opened in the fight is faster to rob (%0.2fs -> %0.2fs)" % [cold, opened])

	# --- the dig goes after what is worth taking -----------------------------
	var ranked := Extraction.robbable_zones(anatomy)
	check(str(ranked[0].kind) == "cybernetic", "hardware outranks meat, because it neither spoils nor grows back")
	var worn := BaselineHuman.new()
	add_child(worn)
	worn.build("worn_subject", {"cybernetics": {
		"head": {"name": "rangefinder eye", "condition": 8.0},
		"right_arm": {"name": "salvaged torque arm"},
	}})
	await get_tree().physics_frame
	var worn_ranked := Extraction.robbable_zones(worn.anatomy.snapshot())
	check(str(worn_ranked[0].zone) == "right_arm", "a ruined optic ranks below an intact arm drive")
	var tied := Extraction.robbable_zones(worn.anatomy.snapshot(), {"head": GoreChunks.Layer.BONE})
	check(str(tied[0].zone) == "right_arm", "exposure only breaks ties; it does not promote a wrecked part")

	# --- B5.3: the tool decides speed and what survives ----------------------
	var by_hand := Extraction.required_seconds(anatomy, "head", "hands")
	var by_kit := Extraction.required_seconds(anatomy, "head", "surgical")
	check(by_hand > cold and cold > by_kit, "hands are slower than a blade, a blade slower than a kit")
	check(Extraction.tool_for("sword", []) == "blade", "the equipped cleaver is a blade")
	check(Extraction.tool_for("sword", [{"label": "SURGICAL KIT"}]) == "surgical", "a carried kit beats the blade in your hand")
	check(Extraction.tool_for("shotgun", []) == "hands", "a shotgun is not a surgical instrument")

	# --- the dig itself ------------------------------------------------------
	var session := Extraction.begin("mark_voss", anatomy, "head", "hands")
	check(not session.is_empty() and not bool(session.complete), "a dig starts unfinished")
	check(Extraction.extract(session, anatomy).is_empty(), "an unfinished dig yields nothing")
	Extraction.dig(session, float(session.required) * 0.5)
	var halfway := Extraction.reached_layer(session)
	check(halfway > 0 and halfway < GoreChunks.Layer.CYBERNETIC, "halfway through, the body is opened partway (%d)" % halfway)
	Extraction.dig(session, float(session.required))
	check(bool(session.complete), "holding it long enough finishes the dig")

	# --- B5.4: what comes out knows what it is and whose it was --------------
	var rough := Extraction.extract(session, anatomy)
	check(str(rough.implant) == "rangefinder eye" and str(rough.zone) == "head", "the extracted part is the part that was installed")
	check(str(rough.lien) == "mark_voss", "and it carries the lien of the body it came off")
	var clean_session := Extraction.begin("mark_voss", anatomy, "head", "surgical")
	Extraction.dig(clean_session, float(clean_session.required))
	var clean := Extraction.extract(clean_session, anatomy)
	check(float(clean.condition) > float(rough.condition), "a surgical extraction preserves more of the part than bare hands (%0.2f vs %0.2f)" % [float(clean.condition), float(rough.condition)])

	var carry := Carry.new()
	var carried := carry.take_chunk(rough)
	check(str(carried.kind) == "cybernetic" and str(carried.lien) == "mark_voss", "the part enters CARRY with its condition and its lien")

	# --- the socket is empty afterwards --------------------------------------
	Extraction.strip_from_rig(rig, rough)
	check(not rig.anatomy.installed_parts.has("head"), "the body no longer has the part that was taken out of it")
	check(rig.exposed_layer("head") >= GoreChunks.Layer.BONE, "and the zone it came out of is opened to the bone")
	check(Extraction.target_layer(rig.anatomy.snapshot(), "head") < 0, "a robbed socket cannot be robbed twice")

	# --- B5.5: install a robbed part into yourself ---------------------------
	var player_rig := BaselineHuman.new()
	add_child(player_rig)
	player_rig.build("player", {})
	await get_tree().physics_frame
	check(not player_rig.anatomy.installed_parts.has("head"), "the player starts with nothing in that socket")
	var installed := carry.install_into(0, player_rig)
	check(not installed.is_empty() and player_rig.anatomy.installed_parts.has("head"), "a robbed implant installs into the player's own body")
	check(carry.items.is_empty(), "and leaves CARRY when it does")
	check(player_rig.anatomy.implant_condition("head") < 1.0, "it works as badly for you as it would have for them")

	# --- B5.6: someone notices ----------------------------------------------
	var ledger := WitnessLedger.new()
	var seen := Extraction.notice(ledger, rough, Vector3.ZERO, [
		{"id": "rook_sable", "at": Vector3(4, 0, 0), "alive": true},
		{"id": "dead_man", "at": Vector3(2, 0, 0), "alive": false},
		{"id": "far_away", "at": Vector3(500, 0, 0), "alive": true},
	], true, "ashbloom_bone_yard")
	check((seen.witnesses as Array) == ["rook_sable"], "only the living and the near see it happen")
	check(int(WorldHistory.subject("mark_voss").get("grudge", 0)) > 0, "a living owner remembers being cut open")
	check(ledger.in_flight().size() == 1, "and an account of it is walking home")
	var unseen := Extraction.notice(WitnessLedger.new(), rough, Vector3.ZERO, [], false, "ashbloom_bone_yard")
	check((unseen.witnesses as Array).is_empty() and not bool(unseen.stolen), "a dead owner and an empty field means nobody ever knows")
	var extraction_events := WorldHistory.events.filter(func(event: Dictionary) -> bool: return str(event.get("type", "")) == "part_extracted")
	check(extraction_events.size() == 2 and PLAYER_ACTION_LEDGER.count("part_extracted") == 2 and extraction_events.all(func(event: Dictionary) -> bool: return str((event.get("details", {}) as Dictionary).get("action_id", "")).begins_with("action_")), "seen and unseen extractions remain true world facts with one player receipt each")
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0, "extraction, testimony and the living owner's memory close one transaction")

	var hot := carry.take_chunk(rough.merged({"stolen": true}, true))
	var cold_goods := carry.take_chunk(rough)
	check(carry.sale_value(hot) < carry.sale_value(cold_goods), "the Choir prices a witnessed part below a quiet one (%d vs %d)" % [carry.sale_value(hot), carry.sale_value(cold_goods)])

	print("EXTRACTION_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
