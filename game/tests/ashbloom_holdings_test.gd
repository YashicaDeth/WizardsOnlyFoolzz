extends Node

const HOLDINGS := preload("res://systems/ashbloom_holdings.gd")
const MAP := preload("res://systems/living_map.gd")
const INDEX := preload("res://systems/world_index.gd")
const BOARD := preload("res://systems/pin_board.gd")

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
	var fresh_jurisdiction := HOLDINGS.jurisdiction_at((HOLDINGS.DEFINITIONS[2] as Dictionary).at)
	check(str(fresh_jurisdiction.place_id) == "ashbloom:bone_yard" and str(fresh_jurisdiction.held_by) == "ashline_wreckers",
		"a world position resolves to the same canonical place and holder local law will use")
	check(int(HOLDINGS.overview().revealed_count) == 0, "jurisdiction lookup does not reveal unsurveyed land to the player")
	check(HOLDINGS.DEFINITIONS.all(func(definition: Dictionary):
		return str(WorldHistory.subject(str(definition.record)).get("kind", "")) == "place"),
		"every map polygon has one first-class WorldHistory place record")

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
	var first_record := str(first.record)
	check(bool(WorldHistory.subject(first_record).get("revealed", false)), "the same reveal opens the canonical place record for INDEX, Board and local law")
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

	var index := INDEX.new()
	index.size = Vector2(960, 540)
	add_child(index)
	index.open()
	check(index._rail_cache.any(func(row: Dictionary): return str(row.id) == first_record),
		"a revealed holding appears in the existing INDEX FILE register")
	check(not index._draw_icon(0, first_record, Rect2(0, 0, 100, 100)),
		"INDEX refuses to invent a human portrait for land")
	var board := BOARD.new()
	board.size = Vector2(960, 540)
	add_child(board)
	check(board.pin(first_record, "record"), "the revealed holding can be physically pinned to the conspiracy Board")
	var place_cards: Array = board.cards.filter(func(card): return card.id == first_record)
	check(place_cards.size() == 1 and place_cards[0].kind == "record", "the pinned land is a filed survey record rather than a fabricated photograph")
	check(place_cards.size() == 1 and place_cards[0].body.contains("ASHLINE WRECKERS") and place_cards[0].body.contains("QUARRY"),
		"the Board card carries the holding's live owner and field evidence")
	check(board.lay_string("theory_frequency", first_record), "the holding can be tied by red string to an existing place theory")

	# A save made before place records existed may already contain changed land.
	# Migration must copy the saved row, never silently restore its authored owner.
	WorldHistory.clear_history()
	var legacy_holdings := {}
	for definition: Dictionary in HOLDINGS.DEFINITIONS:
		legacy_holdings[str(definition.id)] = {
			"revealed": str(definition.id) == "bone_yard",
			"revealed_at": "LEGACY STAMP",
			"held_by": "celloutz" if str(definition.id) == "bone_yard" else str(definition.held_by),
		}
	WorldHistory.register_subject(HOLDINGS.SUBJECT, {
		"kind": "territory", "name": "THE ASHBLOOM EXPANSE",
		"holdings": legacy_holdings, "active_holding": "bone_yard", "revealed_count": 1,
	})
	HOLDINGS.ensure()
	check(str(WorldHistory.subject("ashbloom:bone_yard").get("held_by", "")) == "celloutz",
		"migrating an older save preserves its recorded holder instead of restoring the authored default")

	print("ASHBLOOM_HOLDINGS_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
