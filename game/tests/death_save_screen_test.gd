extends Node

## Job 7's complete state seam: checkpoint, death, audible walk-through
## recovery, a save/reload boundary, and restoration at the filed checkpoint.

var failures: Array[String] = []


class CheckpointHost extends Node:
	var resumed := false

	func _resume_from_checkpoint() -> void:
		resumed = true


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {
		"kind": "person", "name": "THE HUNTER", "blood_fragments": 3,
	})
	var carry := Carry.new()
	carry.items.append({"label": "HOTLINE CLEAVER", "kind": "weapon"})
	carry.save_to_history()

	var checkpoint := FacilityCheckpoints.new()
	add_child(checkpoint)
	checkpoint.file("examiner_office_door", Vector3(8.0, 0.5, -12.0))
	var death := VatRebirth.die("service_arcade", "test death", "numbered_guard", Vector3(3.0, 0.0, -4.0))
	var remains := WorldHistory.subject(str(death.remains_id))
	check((remains.get("items", []) as Array).size() == 1 and int(remains.get("blood_fragments", 0)) == 3,
		"death leaves carried gear and blood fragments at the corpse")
	check(Carry.new().items.is_empty() and int(WorldHistory.subject("player").get("blood_fragments", -1)) == 0,
		"the regrown body carries neither reward")
	VatRebirth.complete()

	var player := CharacterBody3D.new()
	player.position = Vector3(20.0, 0.0, 20.0)
	add_child(player)
	var site := RebirthSite.new()
	add_child(site)
	site.setup("service_arcade", player)
	await get_tree().process_frame
	var sigil := site.get_node_or_null("BloodSigil_%s" % str(death.remains_id)) as Node3D
	var heart := sigil.get_node_or_null("Heartbeat") as AudioStreamPlayer3D if sigil != null else null
	check(heart != null and heart.stream != null and heart.max_distance >= 18.0,
		"the organ-sigil has a positional heartbeat audible beyond its glow")
	player.global_position = sigil.global_position
	site._process(0.1)
	check(bool(WorldHistory.subject(str(death.remains_id)).get("recovered", false)) and VatRebirth.carries("HOTLINE CLEAVER"),
		"walking into the sigil recovers the exact corpse inventory")
	check(int(WorldHistory.subject("player").get("blood_fragments", 0)) == 3 and site._sigils.is_empty(),
		"blood fragments return once and the consumed sigil disappears")

	# Test mode suppresses real player-file writes. The snapshot is the same
	# complete payload the save layer persists, so clearing it models quitting.
	var saved := WorldHistory.snapshot()
	WorldHistory.clear_history()
	check(WorldHistory.subject(FacilityCheckpoints.SUBJECT).is_empty(), "quitting clears the live checkpoint state")
	check(WorldHistory.restore_snapshot(saved), "loading restores the persisted world payload")
	var restored_player := CharacterBody3D.new()
	add_child(restored_player)
	var host := CheckpointHost.new()
	add_child(host)
	var loader := FacilityCheckpoints.new()
	add_child(loader)
	loader.host = host
	loader.player = restored_player
	check(loader.restore(), "the loaded checkpoint is accepted")
	check(restored_player.global_position.is_equal_approx(Vector3(8.0, 0.5, -12.0)) and host.resumed,
		"continue resumes the route at the examiner office checkpoint")

	print("DEATH_SAVE_SCREEN_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
