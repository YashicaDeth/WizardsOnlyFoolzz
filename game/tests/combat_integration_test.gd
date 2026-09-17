extends Node

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	# I9. The world-side half of universal inspection: the pickup remains on its
	# table while the same reliquary that presents held weapons presents its live
	# geometry. This is checked before relocating to the isolated combat range.
	var station_pickups: Array = hunt.substance_station.pickups()
	var ground_pickup: Dictionary = station_pickups[0]
	hunt.player = (ground_pickup["node"] as Node3D).global_position
	var inspect_press := InputEventKey.new()
	inspect_press.keycode = KEY_I
	inspect_press.pressed = true
	var inspect_release := InputEventKey.new()
	inspect_release.keycode = KEY_I
	inspect_release.pressed = false
	hunt._equip_weapon(1)
	hunt._unhandled_input(inspect_press)
	check(str((WorldHistory.recent_events(1)[0] as Dictionary).get("type", "")) == "held_item_inspected" and hunt.inspected_world_item.is_empty(),
		"a held weapon owns I even while a world pickup is within inspection range")
	hunt._unhandled_input(inspect_release)
	hunt._put_the_weapons_down()
	hunt._unhandled_input(inspect_press)
	check(str((WorldHistory.recent_events(1)[0] as Dictionary).get("type", "")) == "world_item_inspected" and not hunt.inspected_world_item.is_empty(),
		"slot 5 frees the same I verb to inspect the nearby world object")
	hunt._unhandled_input(inspect_release)
	var world_preview: Dictionary = hunt._nearest_world_item_for_inspection()
	hunt.inspected_world_item = world_preview
	hunt.inspect_held = true
	hunt._update_held_reliquary()
	check(not world_preview.is_empty() and hunt.held_reliquary.displayed_source_id == (ground_pickup["node"] as Node3D).get_instance_id(),
		"I presents a nearby world pickup through the universal 3D reliquary")
	check((hunt.substance_station.pickups() as Array).size() == station_pickups.size(),
		"world inspection leaves the real pickup on its table")
	var lifted_events_before := WorldHistory.event_count("substance_lifted")
	var lifted_receipts_before := PlayerActionLedger.count("substance_lifted")
	hunt._interact()
	check((hunt.substance_station.pickups() as Array).size() == station_pickups.size() - 1,
		"E still takes the inspected world pickup through its established interaction")
	check(WorldHistory.event_count("substance_lifted") == lifted_events_before + 1,
		"one physical lift emits one substance event rather than the former duplicate pair")
	check(PlayerActionLedger.count("substance_lifted") == lifted_receipts_before + 1,
		"the lift receives one durable action-ledger receipt")
	var lifted_event: Dictionary = WorldHistory.recent_events(1)[0]
	check(not str((lifted_event.get("details", {}) as Dictionary).get("action_id", "")).is_empty(),
		"the established substance event carries its stable action id")
	hunt.inspect_held = false
	hunt.inspected_world_item.clear()
	hunt.player_body.position = Vector3(175, 0.9, 125)
	hunt.player = hunt.player_body.position + Vector3.UP * 0.6
	# The remaining takeable families use the same adapter, not bespoke panels.
	hunt._spawn_dropped_handheld({"serial": 73421, "condition": 0.72, "battery": 0.4}, hunt.player, false)
	var device_preview: Dictionary = hunt._nearest_world_item_for_inspection()
	check(str(device_preview.get("item_id", "")) == "black_mirror" and device_preview.get("source") == hunt.dropped_handheld,
		"the dropped Black Mirror enters the same world inspection grammar")
	hunt.dropped_handheld.queue_free()
	hunt.dropped_handheld = null
	var cache: Node3D = hunt._spawn_loot_cache(hunt.player, ["rust scrip", "field dressing"])
	var cache_preview: Dictionary = hunt._nearest_world_item_for_inspection()
	check(str(cache_preview.get("kind", "")) == "cache" and str(cache_preview.get("detail", "")) == "2 ITEMS",
		"a salvage cache enters the same grammar with its live contents summarized")
	var cache_items_before: int = (WorldHistory.subject("inventory").get("items", []) as Array).size()
	var cache_events_before := WorldHistory.event_count("loot_collected")
	var cache_receipts_before := PlayerActionLedger.count("loot_collected")
	hunt._interact()
	check(not hunt.loose_loot.has(cache) and (WorldHistory.subject("inventory").get("items", []) as Array).size() == cache_items_before + 2,
		"E takes the inspected cache and moves its exact contents into inventory")
	check(WorldHistory.event_count("loot_collected") == cache_events_before + 1 and PlayerActionLedger.count("loot_collected") == cache_receipts_before + 1,
		"one cache pickup emits one event and one durable action receipt")
	hunt.yaw = 0.0
	hunt.pitch = 0.0
	hunt.third_person = false
	hunt._update_camera()
	var inspection_subject: Dictionary = hunt._spawn_encounter_actor({
		"instance_id": "inspection_subject", "kind": "friendly", "display_name": "MERCY BELL",
	}, hunt.player + Vector3(0, -0.5, 1.2))
	inspection_subject.node.position = hunt.player + Vector3(0, -0.5, 1.2)
	var subject_preview: Dictionary = hunt._nearest_world_item_for_inspection()
	hunt.inspected_world_item = subject_preview
	hunt.inspect_held = true
	hunt._update_held_reliquary()
	check(str(subject_preview.get("kind", "")) == "person" and subject_preview.get("source") == inspection_subject.node,
		"a nearby living person enters the same world inspection grammar")
	check(int(hunt.held_reliquary.mesh_count) > 0 and hunt.held_reliquary.displayed_source_id == inspection_subject.node.get_instance_id(),
		"person inspection presents that subject's live body geometry")
	hunt.inspect_held = false
	hunt.inspected_world_item.clear()
	hunt.encounter_actors.erase(inspection_subject)
	inspection_subject.node.queue_free()
	hunt._spawn_encounter_actor({"instance_id": "armed_target", "kind": "hostile", "summary": "ballistic target"}, hunt.player + Vector3(0, 0, 6))
	var actor: Dictionary = hunt.encounter_actors.back()
	actor.node.position = hunt.player + Vector3(0, -0.5, 6)
	await get_tree().physics_frame
	hunt._equip_weapon(1)
	var shell_before := int(hunt.arsenal.ammo.shotgun.loaded)
	var trigger_receipts_before := PlayerActionLedger.count("weapon_fired")
	hunt._attack()
	check(int(hunt.arsenal.ammo.shotgun.loaded) == shell_before - 1, "live Hunt input fires a chambered shotgun shell")
	check(PlayerActionLedger.count("weapon_fired") == trigger_receipts_before + 1,
		"one trigger pull receives one player-action receipt rather than one per pellet")
	# AF1.1. Damage now resolves when the round actually lands, not on the
	# frame the trigger went down — `hunt.set_physics_process(false)` above
	# only stops `hunt`'s own callback; `ballistics`, a real child node with
	# its own `_physics_process`, still steps on every one of these.
	for _tick in 10:
		await get_tree().physics_frame
	check(actor.anatomy.wounds.size() > 0, "live pellets resolve against the NPC BaselineHuman")
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0 and not bool(WorldHistory.get("_ledger_batch_dirty")),
		"every delayed pellet closes its anatomy and response transaction on impact")
	var wounded_zones: Array[String] = []
	for wound in actor.anatomy.wounds:
		var zone := str(wound.get("zone", ""))
		if not wounded_zones.has(zone):
			wounded_zones.append(zone)
	check(not wounded_zones.is_empty() and wounded_zones.all(func(zone): return BaselineHuman.ZONES.has(zone)), "firearm reports canonical anatomy zones %s" % str(wounded_zones))
	# AF1.1. Nine pellets now each carry their own real hit — nine
	# `firearm_anatomy_hit`/`anatomy_changed` events for one shotgun blast
	# where there used to be one batched pair — so the single `weapon_fired`
	# this pull records is easily buried in that pellet-level detail within
	# a 12-event window; widened rather than special-cased around it.
	check(WorldHistory.recent_events(24).any(func(event): return str(event.get("type", "")) == "weapon_fired"), "weapon discharge enters world history")
	var fired_events: Array = WorldHistory.events.filter(func(event: Dictionary): return str(event.get("type", "")) == "weapon_fired")
	check(not fired_events.is_empty() and not str(((fired_events.back() as Dictionary).get("details", {}) as Dictionary).get("action_id", "")).is_empty(),
		"the established weapon event carries the trigger pull's stable action id")
	var reload_receipts_before := PlayerActionLedger.count("weapon_reloaded")
	hunt.arsenal.cooldown = 0.0
	hunt._reload_weapon()
	hunt.arsenal.tick(float(hunt.arsenal.current().reload) + 0.01)
	check(PlayerActionLedger.count("weapon_reloaded") == reload_receipts_before + 1,
		"a completed physical reload receives one durable action receipt")
	var reload_event: Dictionary = WorldHistory.events.filter(func(event: Dictionary): return str(event.get("type", "")) == "weapon_reloaded").back()
	check(int((reload_event.get("details", {}) as Dictionary).get("loaded", 0)) == int(hunt.arsenal.current().magazine),
		"the reload receipt records the ammunition state after the magazine arrives")

	# Lock-on: the verb that makes third-person combat aimable at all.
	hunt.third_person = true
	hunt.lock_target = ""
	# A fresh body: the shotgun target above may already be down or dead, and a
	# lock is only ever offered on someone still standing.
	var lock_at: Vector3 = hunt.player + Vector3(0, -0.5, 5)
	hunt._spawn_encounter_actor({"instance_id": "lock_subject", "kind": "hostile"}, lock_at)
	var locked_actor: Dictionary = hunt.encounter_actors.back()
	locked_actor.node.position = lock_at
	await get_tree().physics_frame
	hunt._toggle_lock()
	check(hunt.lock_target == str(locked_actor.subject_id), "lock acquires the nearby hostile (%s)" % hunt.lock_target)
	hunt._steer_lock(0.5)
	check(hunt.lock_screen.x >= 0.0, "locked target reports a reticle position")
	# A second body closer to the player must not steal the swing.
	var closer: Vector3 = hunt.player + Vector3(0.4, -0.5, 1.2)
	hunt._spawn_encounter_actor({"instance_id": "lock_decoy", "kind": "hostile"}, closer)
	var decoy: Dictionary = hunt.encounter_actors.back()
	decoy.node.position = closer
	var decoy_wounds: int = decoy.anatomy.wounds.size()
	var locked_wounds: int = locked_actor.anatomy.wounds.size()
	hunt._equip_weapon(0)
	hunt._attack_nearest_encounter_actor({"damage": 20.0, "impulse": 10.0, "damage_type": "cut", "range": 9.0, "weapon": "cleaver"})
	check(decoy.anatomy.wounds.size() == decoy_wounds, "a nearer body does not steal a locked strike")
	check(locked_actor.anatomy.wounds.size() > locked_wounds, "the locked target takes the strike")
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0 and not bool(WorldHistory.get("_ledger_batch_dirty")), "the landed swing closes anatomy, response and its receipt together")
	hunt._toggle_lock()
	check(hunt.lock_target.is_empty(), "lock releases")

	# B6 is not a detached-limb death animation. The live encounter actor loses
	# the arm, remains hostile, and the same AI update uses its degraded anatomy
	# to slow and weaken subsequent attacks.
	var full_cycle: float = hunt._actor_attack_cycle(locked_actor)
	var full_damage: int = hunt._actor_attack_damage(locked_actor)
	locked_actor.rig.hit("right_arm", 44.0, 28.0, "cut", "", Vector3.RIGHT)
	var sever: Dictionary = locked_actor.rig.hit("right_arm", 44.0, 28.0, "cut", "", Vector3.RIGHT)
	check(bool(sever.get("severed", false)), "a directional blow severs a live encounter actor mid-fight")
	hunt._apply_maiming_state(locked_actor, ["right_arm"], Vector3.RIGHT)
	check(locked_actor.state == "maimed" and not locked_actor.anatomy.dead and not locked_actor.anatomy.downed, "the maimed actor remains alive, standing and hostile")
	check(hunt._actor_attack_cycle(locked_actor) > full_cycle, "the one-armed fighter attacks more slowly")
	check(hunt._actor_attack_damage(locked_actor) < full_damage, "the one-armed fighter hits less hard")
	check(WorldHistory.recent_events(20).any(func(event): return str(event.get("type", "")) == "limb_severed_in_combat"), "mid-fight limb loss enters persistent world history")
	for candidate in hunt.encounter_actors:
		candidate.disposition = "friendly"
	locked_actor.disposition = "hostile"
	locked_actor.node.position = hunt.player + Vector3(0, -0.5, 2.0)
	locked_actor.attack_time = hunt._actor_attack_cycle(locked_actor)
	var player_health_before: int = hunt.health
	hunt._update_encounter_actors(0.01)
	check(hunt.health == player_health_before - hunt._actor_attack_damage(locked_actor), "the maimed actor actually continues attacking through the normal AI loop")

	# The limb does not stop being real when it hits the ground. Pick it up through
	# the Hunt interaction, equip it from CARRY, and strike with it.
	var loose_limb := RigidBody3D.new()
	hunt.add_child(loose_limb)
	loose_limb.global_position = hunt.player
	GoreChunks.register_whole_limb(loose_limb, "left_arm", "carry_victim")
	var body_part_preview: Dictionary = hunt._nearest_world_item_for_inspection()
	check(str(body_part_preview.get("kind", "")) == "body_part" and body_part_preview.get("source") == loose_limb,
		"a takeable body part enters the same world inspection grammar")
	var carry_before: int = hunt.handheld.carry.items.size()
	hunt._interact()
	check(hunt.handheld.carry.items.size() == carry_before + 1 and str(hunt.handheld.carry.items.back().kind) == "limb", "E picks the physical limb up into the real CARRY inventory")
	hunt._equip_carried_limb()
	check(hunt.carried_limb_index >= 0 and hunt.carried_limb_model != null, "slot 4 visibly equips the carried limb")
	var carried_hand := hunt.carried_limb_model.get_node_or_null("CarriedLimbGripHand") as Node3D
	check(carried_hand != null and carried_hand.get_node_or_null("HumiliationCuff") != null,
		"the improvised limb is visibly held by the same costumed articulated hand")
	check(carried_hand != null and carried_hand.get_node_or_null("FirstPersonForearm") != null,
		"the limb grip continues into an authored lower-right arm")
	hunt._update_hud()
	var limb_reliquary: Control = hunt.held_reliquary as Control
	check(limb_reliquary != null and int(limb_reliquary.displayed_source_id) == hunt.carried_limb_model.get_instance_id() and int(limb_reliquary.mesh_count) > 0,
		"the same carried limb appears as real rotating geometry in the universal held-item reliquary")
	var limb_rest_rotation: Vector3 = hunt.carried_limb_model.rotation
	hunt.inspect_held = true
	for _inspect_limb in 18:
		hunt._update_held_inspection(1.0 / 60.0)
	check(hunt.carried_limb_model.rotation.distance_to(limb_rest_rotation) > 0.25,
		"inspection hefts the dead weight and turns its cut end toward the player")
	hunt.inspect_held = false
	hunt.lock_target = str(locked_actor.subject_id)
	hunt.attack_cooldown = 0.0
	var target_wounds: int = locked_actor.anatomy.wounds.size()
	var limb_condition: float = float(hunt.handheld.carry.items[hunt.carried_limb_index].condition)
	var melee_receipts_before := PlayerActionLedger.count("npc_anatomy_hit")
	hunt._attack()
	hunt._resolve_strike()
	check(locked_actor.anatomy.wounds.size() > target_wounds, "the severed limb hits an NPC through the normal melee resolver")
	check(PlayerActionLedger.count("npc_anatomy_hit") == melee_receipts_before + 1,
		"one connecting melee swing receives one action receipt")
	check(float(hunt.handheld.carry.items[hunt.carried_limb_index].condition) < limb_condition, "the improvised limb loses condition when swung")
	var sale: Dictionary = hunt._sell_first_carried_part()
	check(int(sale.get("price", 0)) > 0 and hunt.carried_limb_index == -1, "a broker can buy the same carried limb and unequip it cleanly")

	# B5. A body with hardware in it is a thing you dig into, and the dig
	# survives the body leaving the AI's books when it dies.
	# The earlier _interact() left the resolution form open over a downed body,
	# and digging while deciding someone's fate is refused by design.
	hunt.resolution_ui.close_menu()
	hunt.panel_mode = ""
	var victim_at: Vector3 = hunt.player + Vector3(0, -0.5, 1.6)
	hunt._spawn_encounter_actor({"instance_id": "rob_subject", "kind": "hostile"}, victim_at)
	var victim: Dictionary = hunt.encounter_actors.back()
	victim.node.position = victim_at
	victim.rig.install_prosthetic("head", {"name": "rangefinder eye"})
	await get_tree().physics_frame
	check(hunt._nearest_robbable().is_empty(), "a body still standing is not robbable")
	victim.anatomy.go_down()
	await get_tree().physics_frame
	check(str(hunt._nearest_robbable().get("subject_id", "")) == str(victim.subject_id), "a downed body within reach is")
	# Ashline bodies also carry a torso plate, so the dig picks between two real
	# implants rather than finding the only one there is.
	hunt._begin_extraction()
	var dug_zone := str(hunt.extraction_session.get("zone", ""))
	check(victim.rig.anatomy.installed_parts.has(dug_zone), "F opens a dig into a zone that actually has hardware in it (%s)" % dug_zone)
	var required: float = float(hunt.extraction_session.required)
	hunt._update_extraction(required * 0.5, true)
	check(not bool(hunt.extraction_session.get("complete", false)), "half the time does not finish it")
	check(victim.rig.exposed_layer("head") > 0, "and the body is visibly opened partway while you work")
	var carry_before_rob: int = hunt.handheld.carry.items.size()
	hunt._update_extraction(required, true)
	check(hunt.extraction_session.is_empty(), "finishing the dig closes the session")
	check(hunt.handheld.carry.items.size() == carry_before_rob + 1, "and moves the part into CARRY")
	var robbed: Dictionary = hunt.handheld.carry.items.back()
	check(str(robbed.kind) == "cybernetic" and str(robbed.lien) == str(victim.subject_id), "the carried part remembers whose body it came out of")
	check(not victim.rig.anatomy.installed_parts.has(dug_zone), "and the socket it came out of is empty")
	check(int(WorldHistory.subject(str(victim.subject_id)).get("grudge", 0)) > 0, "a living owner remembers being robbed")
	check(not Extraction.robbable_zones(victim.rig.anatomy.snapshot()).any(func(target): return str(target.zone) == dug_zone and str(target.kind) == "cybernetic"), "that socket is not offered again")

	# The same verb works on a corpse the AI has already forgotten.
	var corpse_at: Vector3 = hunt.player + Vector3(1.2, -0.5, 0.6)
	hunt._spawn_encounter_actor({"instance_id": "corpse_subject", "kind": "hostile"}, corpse_at)
	var corpse: Dictionary = hunt.encounter_actors.back()
	corpse.node.position = corpse_at
	corpse.rig.install_prosthetic("torso", {"name": "ceramic sternum"})
	await get_tree().physics_frame
	hunt._kill_encounter_actor(hunt.encounter_actors.find(corpse), "test")
	check(not hunt.encounter_actors.has(corpse) and hunt.dead_bodies.size() > 0, "a killed body leaves the AI's books but stays in the world")
	check(str(hunt._nearest_robbable().get("subject_id", "")) == str(corpse.subject_id), "and a corpse is still robbable")
	hunt._begin_extraction()
	hunt._update_extraction(float(hunt.extraction_session.required) + 0.1, true)
	check(str((hunt.handheld.carry.items.back() as Dictionary).implant) == "ceramic sternum", "the corpse gives up its hardware")

	# B6.5/B6.6. The player is a body on the same rig as everyone else, so what
	# a lost limb does to an NPC it has to do to the player too.
	hunt.player_rig.anatomy.bleed_rate = 0.0
	# The player has taken real hits by this point in the scenario, so the
	# baseline is whatever they have left rather than a pristine body.
	var healthy_swing: float = hunt._player_swing_scale()
	var healthy_speed: float = hunt._player_speed_scale()
	var pristine := BaselineHuman.new()
	hunt.add_child(pristine)
	pristine.build("scale_reference", {})
	await get_tree().physics_frame
	check(is_equal_approx(pristine.anatomy.combat_ratio(), 1.0) and is_equal_approx(pristine.anatomy.mobility_ratio(), 1.0), "an unhurt body swings and runs at full")
	hunt._equip_carried_limb()
	var held_before: int = hunt.carried_limb_index
	var player_sever: Dictionary = hunt.player_rig.hit("left_arm", 60.0, 30.0, "cut", "", Vector3.LEFT)
	if not bool(player_sever.get("severed", false)):
		player_sever = hunt.player_rig.hit("left_arm", 60.0, 30.0, "cut", "", Vector3.LEFT)
	check(bool(player_sever.get("severed", false)) or hunt.player_rig.severed.has("left_arm"), "the player's own arm comes off on the same rule as everyone else's")
	check(not hunt.player_rig.anatomy.dead, "and losing it does not kill them")
	check(hunt.player_rig.anatomy.bleed_rate > 0.0, "a fresh stump bleeds (%0.2f mL/s)" % hunt.player_rig.anatomy.bleed_rate)
	hunt._player_lost_limb("left_arm")
	check(hunt._player_swing_scale() < healthy_swing, "a one-armed player hits softer")
	check(WorldHistory.recent_events(10).any(func(event): return str(event.get("type", "")) == "player_limb_severed"), "the player's maiming enters world history like anyone else's")
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0, "maiming state, forced drop and severing fact close one injury transaction")
	if held_before >= 0:
		check(hunt.carried_limb_index == -1, "the arm that was holding something drops it")
	hunt.player_rig.hit("left_leg", 90.0, 30.0, "cut", "", Vector3.LEFT)
	hunt.player_rig.hit("left_leg", 90.0, 30.0, "cut", "", Vector3.LEFT)
	check(hunt._player_speed_scale() < healthy_speed, "and a wrecked leg slows the run")
	check(hunt._player_speed_scale() >= 0.5, "but never below a speed you could still retreat at")

	print("COMBAT_INTEGRATION_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
