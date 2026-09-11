class_name RealityMisfireDirector
extends Node3D

signal misfire_triggered(encounter: Dictionary, world_position: Vector3)

const ENCOUNTER_LIBRARY := [
	{"id": "tea_truce", "title": "THE KETTLE KNOWS YOUR NAME", "kind": "friendly", "weight": 18, "summary": "A masked scavenger offers tea and one true rumour."},
	{"id": "wrong_funeral", "title": "YOUR FUNERAL, WRONG DATE", "kind": "social", "weight": 15, "summary": "A procession insists you already died here next Thursday."},
	{"id": "cap_market", "title": "MUSHROOM STOCK EXCHANGE", "kind": "trade", "weight": 16, "summary": "Soft Rot brokers gamble on which giant cap opens next."},
	{"id": "radio_child", "title": "THE RADIO HAS A CHILD", "kind": "mystery", "weight": 14, "summary": "A buried handset asks you to teach it a lie."},
	{"id": "ashline_toll", "title": "PAY THE ROAD IN TEETH", "kind": "hostile", "weight": 19, "summary": "Ashline collectors erect a moving checkpoint behind you."},
	{"id": "dead_weather", "title": "WEATHER GOD, MOSTLY DEAD", "kind": "boss", "weight": 7, "summary": "An ancient storm intelligence mistakes your heartbeat for thunder."},
	{"id": "nix_cache", "title": "NIX WAS HERE TOMORROW", "kind": "bond", "weight": 11, "summary": "A medical cache contains a note written after you found it."},
]

var seeded_encounters: Array[Dictionary] = []
var triggered: Dictionary = {}
var discovery_radius := 13.0
var cooldown_until := 0

func resolve(instance_id: String, outcome: String) -> void:
	WorldHistory.update_subject("misfire:" + instance_id, {"status": "resolved", "outcome": outcome}, "misfire_resolved")


func generate(seed_value: int, region_size: Vector2, count: int = 18) -> void:
	seeded_encounters.clear()
	triggered.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in count:
		var chosen: Dictionary = _weighted_pick(rng)
		var position := Vector3(rng.randf_range(-region_size.x * 0.46, region_size.x * 0.46), 0.0, rng.randf_range(-region_size.y * 0.46, region_size.y * 0.46))
		var instance := chosen.duplicate(true)
		instance["instance_id"] = "%s_%02d" % [str(chosen.id), index]
		instance["position"] = position
		seeded_encounters.append(instance)


func update_player_position(player_position: Vector3) -> void:
	for encounter in seeded_encounters:
		var instance_id := str(encounter.instance_id)
		if triggered.has(instance_id):
			continue
		if WorldHistory.subject("misfire:" + instance_id).get("status", "") == "resolved":
			continue
		if Time.get_ticks_msec() < cooldown_until:
			return
		var position: Vector3 = encounter.position
		if player_position.distance_to(position) <= discovery_radius:
			triggered[instance_id] = true
			cooldown_until = Time.get_ticks_msec() + 15000
			WorldHistory.register_subject("misfire:" + instance_id, {"status": "discovered", "kind": encounter.kind})
			misfire_triggered.emit(encounter.duplicate(true), position)


func _weighted_pick(rng: RandomNumberGenerator) -> Dictionary:
	var total := 0
	for entry in ENCOUNTER_LIBRARY:
		total += int(entry.weight)
	var roll := rng.randi_range(1, total)
	for entry in ENCOUNTER_LIBRARY:
		roll -= int(entry.weight)
		if roll <= 0:
			return entry
	return ENCOUNTER_LIBRARY[0]
