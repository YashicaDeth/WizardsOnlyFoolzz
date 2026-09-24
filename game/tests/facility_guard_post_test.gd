extends Node

## AX route beat 5 in place: Hollis, his biometric door and his gun in the
## Service Arcade, driven through the arcade's own E, LMB and frame calls.

const ARCADE := preload("res://service_arcade.tscn")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _carried(label: String) -> Dictionary:
	for entry in WorldHistory.subject("inventory").get("items", []):
		if entry is Dictionary and str(entry.get("label", "")) == label:
			return entry
	return {}


func _door_blocks(post: FacilityGuardPost) -> bool:
	for child in post.door_body.get_children():
		if child is CollisionShape3D:
			return not (child as CollisionShape3D).disabled
	return false


func _fresh_arcade() -> Node:
	WorldHistory.clear_history()
	var arcade = ARCADE.instantiate()
	add_child(arcade)
	return arcade


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	# --- The post exists on the route and holds it. ---
	var arcade = _fresh_arcade()
	await get_tree().process_frame
	var post: FacilityGuardPost = arcade.guard_post
	check(post != null and post.guard != null and post.barrier != null, "the arcade places Hollis, his reader and his door")
	check(post.global_position.z < arcade.CARD_AT.z and post.global_position.z < arcade.WEAPON_AT.z and post.global_position.z > arcade.GATE_AT.z,
		"the door stands between both tools and the pressure gate")
	check(not post.door_open and _door_blocks(post), "the D-section door is shut and solid")
	check(str(WorldHistory.subject(FacilityGuardPost.GUARD_ID).get("status", "")) == "on post", "Hollis is a persistent person in the world record")

	# --- Walking up with nothing in hand. ---
	var in_range: Vector3 = post.guard.global_position + Vector3(0, 0, 5.0)
	arcade.player.global_position = in_range
	arcade._physics_process(0.016)
	check(post.warned, "he warns you when you come into view")
	check(arcade.blood == 100.0 and WorldHistory.event_count("facility_guard_fired") == 1, "his first shot inside range is a warning")
	post.fire_cooldown = 0.0
	arcade.player.global_position = in_range
	arcade._physics_process(0.016)
	check(arcade.blood < 100.0, "the next one lands and costs blood")
	arcade.player.global_position = post.guard.global_position + Vector3(0, 0, 1.2)
	arcade._interact()
	check(not post.door_open, "with nothing to meet him with, E at the guard opens nothing")
	arcade.queue_free()
	await get_tree().process_frame

	# --- Coercion: the ram at his chest, his own hand on the reader. ---
	arcade = _fresh_arcade()
	await get_tree().process_frame
	post = arcade.guard_post
	arcade.weapon_taken = true
	arcade.player.global_position = post.guard.global_position + Vector3(0, 0, 1.6)
	check(post.prompt_for(arcade.player.global_position, true).begins_with("[E] RAM TO HIS CHEST"), "up close with the ram, the prompt offers coercion")
	arcade._interact()
	check(post.coerced and post.door_open and not post.guard.anatomy.downed, "coerced, a living Hollis palms the reader and the door opens")
	check(not _door_blocks(post), "the opened door no longer blocks the artery")
	var accesses: Array = WorldHistory.events.filter(func(event): return str(event.get("type", "")) == "facility_biometric_access")
	check(accesses.size() == 1 and str(accesses[0].get("details", {}).get("method", "")) == "whole_body", "the reader records one whole-body access")
	check(str(WorldHistory.subject(FacilityGuardPost.GUARD_ID).get("status", "")) == "coerced", "the world remembers that he was coerced, not killed")
	var fired_before := WorldHistory.event_count("facility_guard_fired")
	for tick in 30:
		post.fire_cooldown = 0.0
		arcade._physics_process(0.016)
	check(WorldHistory.event_count("facility_guard_fired") == fired_before, "a coerced guard does not shoot")
	arcade._interact()
	var gun := _carried(FacilityGuardPost.GUN_LABEL)
	check(not gun.is_empty() and int(gun.get("rounds", 0)) == 3, "his dropped gun goes into Carry with three rounds")
	check(not bool(post.loadout.gun_available) and WorldHistory.event_count("facility_guard_weapon_taken") == 1, "the gun transfer is the loadout's own, recorded once")
	arcade._interact()
	check(WorldHistory.event_count("facility_guard_weapon_taken") == 1 and WorldHistory.subject("inventory").get("items", []).size() == 1, "he cannot be farmed for a second gun")
	arcade.queue_free()
	await get_tree().process_frame

	# --- Violence: ram him down, drag his hand to the reader, take the gun. ---
	arcade = _fresh_arcade()
	await get_tree().process_frame
	post = arcade.guard_post
	arcade.weapon_taken = true
	arcade.player.global_position = post.guard.global_position + Vector3(0, 0, 1.6)
	var swings := 0
	while not post.guard_down() and swings < 6:
		check(post.strike(arcade.player.global_position), "ram swing %d lands on Hollis" % (swings + 1))
		swings += 1
	check(post.guard_down() and swings <= 3, "the ram puts him down in %d swings" % swings)
	check(not post.door_open, "a downed guard does not open anything by himself")
	arcade._interact()
	check(post.door_open, "dragging his hand to the reader opens the door")
	accesses = WorldHistory.events.filter(func(event): return str(event.get("type", "")) == "facility_biometric_access")
	check(accesses.size() == 1, "and the reader records that access once")
	arcade._interact()
	check(not _carried(FacilityGuardPost.GUN_LABEL).is_empty(), "his gun comes off his body into Carry")
	check(str(WorldHistory.subject(FacilityGuardPost.GUARD_ID).get("status", "")) in ["down", "dead"], "the world remembers him put down at his door")
	fired_before = WorldHistory.event_count("facility_guard_fired")
	for tick in 30:
		post.fire_cooldown = 0.0
		arcade._physics_process(0.016)
	check(WorldHistory.event_count("facility_guard_fired") == fired_before, "a downed guard does not shoot")
	arcade.queue_free()

	print("FACILITY_GUARD_POST_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
