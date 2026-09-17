extends Node

const HOLDINGS := preload("res://systems/ashbloom_holdings.gd")
const MAP := preload("res://systems/living_map.gd")

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
	var fresh := HOLDINGS.overview()
	check((fresh.holdings as Array).size() == 5, "the surface authority owns the five settlements the world generator actually builds")
	check(int(fresh.revealed_count) == 0, "a new Ashbloom does not begin with its holdings revealed")

	var polygons := HOLDINGS.polygons()
	check(polygons.size() == 5 and polygons.values().all(func(polygon): return (polygon as PackedVector2Array).size() >= 3),
		"the five settlement centres produce five bounded territory polygons")
	var half := HOLDINGS.REGION_SIZE * 0.5
	var all_inside := true
	for polygon_variant in polygons.values():
		var polygon := polygon_variant as PackedVector2Array
		for point: Vector2 in polygon:
			if absf(point.x) > half.x + 0.01 or absf(point.y) > half.y + 0.01:
				all_inside = false
	check(all_inside, "every holding edge stays clipped to the real generated region")
	for definition: Dictionary in HOLDINGS.DEFINITIONS:
		check(HOLDINGS.nearest_id(definition.at) == str(definition.id), "%s lies inside its own holding" % str(definition.name))

	var first: Dictionary = HOLDINGS.DEFINITIONS[2]
	var discovered := HOLDINGS.observe(first.at)
	check(bool(discovered.revealed) and not str(discovered.revealed_at).is_empty(), "entering land reveals the whole named holding with a world timestamp")
	check(str(discovered.held_by) == str(first.held_by), "reveal reports who already holds the ground instead of assigning it to the player")
	check(WorldHistory.event_count("holding_revealed") == 1, "the reveal arrives as one persistent event")
	HOLDINGS.observe(first.at + Vector2(2, 2))
	check(WorldHistory.event_count("holding_revealed") == 1, "walking another metre inside it cannot fragment that event")
	HOLDINGS.observe((HOLDINGS.DEFINITIONS[1] as Dictionary).at)
	check(int(HOLDINGS.overview().revealed_count) == 2 and WorldHistory.event_count("holding_revealed") == 2,
		"crossing a real border reveals the next holding as a second whole piece")

	var map := MAP.new()
	map.size = Vector2(960, 540)
	add_child(map)
	map.observe(Vector3(first.at.x, 0, first.at.y), 0.0)
	check(bool(HOLDINGS.holding(str(first.id)).revealed), "the live map's ordinary observation path drives the same territory authority")
	check(MAP.DISTRICTS.size() == HOLDINGS.DEFINITIONS.size(), "map labels and generated holding authority share one definition table")

	print("ASHBLOOM_HOLDINGS_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
