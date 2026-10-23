extends Node

## Brief 1, `ladder-seats`. A seat is a place, not a sort: it can stand empty,
## it names the dawn it fills, and it fills from the band beneath it.

const Society := preload("res://systems/pyramid_society.gd")
const Ladder := preload("res://systems/ladder_seats.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func person(name: String, power: Dictionary, extra := {}) -> Dictionary:
	var definition := {"name": name, "role": "facility staff", "faction_id": "celloutz", "social_power": power}
	for key in extra:
		definition[key] = extra[key]
	return definition


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	WorldHistory.world_minute = 13.0 * 60.0

	# --- The shape of the board itself. -------------------------------------
	var ladder := Ladder.new()
	ladder.begin(Society.new(), "celloutz")
	check(ladder.seats.size() == 40, "the board has forty seats: 1 + 3 + 9 + 27")
	check(ladder.empty_seats().size() == 40, "a fresh board is entirely empty")
	check(ladder.seat_by_id("seat_2_08").band_label == "OFFICE", "seat ids carry their band and slot")

	# --- Seating by the society's own gates. --------------------------------
	var apex_power := {"class": 96, "influence": 90, "wealth": 88, "access": 92, "leverage": 88, "faction": 94, "relationships": 70}
	var seat := ladder.register("receiver", person("THE LAST RECEIVER", apex_power))
	check(not seat.is_empty() and str(seat.band_id) == "singularity", "the apex-eligible person takes the one seat at the top")
	ladder.register("runner_0", person("RUNNER ONE", {"class": 52, "influence": 62, "wealth": 60, "access": 44, "faction": 50, "leverage": 30}))
	ladder.register("runner_1", person("RUNNER TWO", {"class": 50, "influence": 58, "wealth": 58, "access": 42, "faction": 48, "leverage": 28}))
	check(str(ladder.seat_of("runner_0").band_id) == "office", "people who pass the office gate are seated in the office band")
	check(str(ladder.register("receiver", {}).get("id", "")) == "seat_0_00", "registering the same person twice keeps the same seat")
	# Someone who passes every gate but finds the seats taken falls a band.
	for index in 12:
		var power := apex_power.duplicate(true)
		power["relationships"] = 60 - index
		ladder.register("claimant_%d" % index, person("CLAIMANT %d" % index, power))
	var top_taken: String = str(ladder.seat_of("claimant_0").band_id)
	check(top_taken != "singularity", "a second apex-eligible person cannot take an occupied apex seat")
	check(int(ladder.seat_of("claimant_11").band_index) >= int(ladder.seat_of("claimant_0").band_index), "later claimants fall no higher than earlier ones")

	# --- A death empties the seat at once, and names its dawn. --------------
	var noon := 13.0 * 60.0
	var dawn := ladder.next_dawn(noon)
	check(dawn == 24.0 * 60.0 + 6.5 * 60.0, "next_dawn is the following morning, not the current one")
	var vacated := ladder.vacate("runner_0", {"cause": "killed", "location_id": "service_arcade"})
	check(str(vacated.occupant_id) == "" and str(vacated.last_vacated_name) == "RUNNER ONE", "a death empties the seat and remembers who held it")
	check(float(vacated.fills_at) == dawn, "the empty seat carries the dawn it fills")
	check(str(ladder.society.subject("runner_0").get("status", "")) == "dead", "the person is dead in the society the board is built from")
	check(ladder.board().next_fill.contains("06:30"), "the board names the next fill as an hour")
	check(ladder.catch_up(14.0 * 60.0).is_empty(), "no seat fills before its dawn")

	# --- At dawn the highest below moves up; their seat waits for the next. -
	var changes := ladder.catch_up(dawn)
	check(changes.size() == 1 and str(changes[0].type) == "promoted", "one promotion at the one dawn")
	var promoted_id: String = str(changes[0].person_id)
	check(promoted_id != "runner_1", "a peer in the same band is not promoted over the band beneath")
	check(str(changes[0].into_seat_of) == "RUNNER ONE", "the promotion names whose seat it was")
	check(str(ladder.seat_by_id("seat_2_00").get("occupant_id", "")) == promoted_id, "the promoted person sits in the vacated seat")
	check(ladder.seats.filter(func(held): return str(held.occupant_id) == promoted_id).size() == 1, "the promoted person holds exactly one seat")
	var emptied := ladder.empty_seats()
	var waiting := false
	for empty in emptied:
		if float(empty.fills_at) == ladder.next_dawn(dawn):
			waiting = true
	check(waiting, "the seat they left waits for the dawn after, not this one")
	check(ladder.catch_up(dawn).is_empty(), "the same dawn does not cascade through every band")

	# --- Both subjects carry the event. ------------------------------------
	var promoted_events := ladder.society.nemesis_history(promoted_id)
	var dead_events := ladder.society.nemesis_history("runner_0")
	check(promoted_events.any(func(event): return str(event.type) == "promoted"), "the promotion is a nemesis event on the person who took the seat")
	check(dead_events.any(func(event): return str(event.type) == "seat_taken"), "and on the person whose death made it worth taking")
	check(WorldHistory.event_count("ladder_promotion") == 1 and WorldHistory.event_count("ladder_seat_vacated") == 1, "the world records both facts once each")

	# --- The card. ---------------------------------------------------------
	var filled := ladder.card_for(ladder.seat_by_id("seat_2_00"))
	check(str(filled.get("name", "")) == str(ladder.society.subject(promoted_id).get("name", "")) and str(filled.band_label) == "OFFICE", "the card names the occupant and the band")
	check((filled.traits as Array).size() == 3 and not str(filled.traits[0]).is_empty(), "the card carries three traits as words")
	check(not filled.has("score") and not filled.has("level") and not filled.has("percent"), "no card carries a total, a level or a percentage")
	var empty_card := ladder.card_for(emptied[0])
	check(bool(empty_card.empty) and not str(empty_card.fills_at_stamp).is_empty(), "an empty seat is drawn and says when it fills")

	# --- A seat the band below cannot hold stands empty, and says so. -----
	var lonely := Ladder.new()
	lonely.begin(Society.new(), "celloutz")
	lonely.register("nobody", person("NOBODY IN PARTICULAR", apex_power))
	lonely.register("outsider", person("OUTSIDER", {"influence": 5}))
	check(not lonely.has_seat("outsider"), "someone who passes no gate is the crowd and owns no seat")
	lonely.vacate("nobody", {"cause": "killed"})
	var stood := lonely.catch_up(lonely.next_dawn(noon))
	check(stood.size() == 1 and str(stood[0].type) == "stood_empty", "a seat nobody below can hold stands empty")
	var seat_of_nobody := lonely.seat_by_id("seat_0_00")
	check(str(seat_of_nobody.get("occupant_id", "")).is_empty() and float(seat_of_nobody.fills_at) > 0.0, "and it keeps a next hour rather than a phantom fill")
	check(lonely.catch_up(float(seat_of_nobody.fills_at)).size() == 1, "a standing-empty seat is re-examined at the dawn after, once")

	# --- The crowd can take a seat in the lowest capped band. --------------
	var crowd_ladder := Ladder.new()
	crowd_ladder.begin(Society.new(), "celloutz")
	crowd_ladder.register("network_hand", person("NETWORK HAND", {"influence": 22, "faction": 20}), 12.0 * 60.0)
	check(str(crowd_ladder.seat_of("network_hand").band_id) == "network", "a network-eligible person takes a network seat")
	crowd_ladder.register("crowd_hand", person("CROWD HAND", {"influence": 5}))
	check(not crowd_ladder.has_seat("crowd_hand"), "the crowd hand waits outside")
	crowd_ladder.vacate("network_hand", {"cause": "killed"}, 12.5 * 60.0)
	crowd_ladder.catch_up(crowd_ladder.next_dawn(noon))
	check(str(crowd_ladder.seat_by_id("seat_3_00").get("occupant_id", "")) == "crowd_hand", "at dawn the crowd fills the lowest seat from outside")

	# --- Seniority, not rank: the one who has held a seat longest moves up. --
	var senior := Ladder.new()
	senior.begin(Society.new(), "celloutz")
	senior.register("top", person("TOP OF THE LADDER", apex_power))
	senior.register("junior", person("JUNIOR", {"class": 74, "influence": 66, "access": 54, "faction": 60}), 12.0 * 60.0)
	senior.register("veteran", person("VETERAN", {"class": 72, "influence": 60, "access": 52, "faction": 60}), 11.0 * 60.0)
	check(str(senior.seat_of("veteran").band_id) == "privy" and str(senior.seat_of("junior").band_id) == "privy", "both sit in the ring directly below the apex")
	senior.vacate("top", {"cause": "killed"}, 12.5 * 60.0)
	senior.catch_up(senior.next_dawn(noon))
	check(str(senior.seat_by_id("seat_0_00").get("occupant_id", "")) == "veteran", "the longest-serving person below takes the seat, not the highest-ranked")

	# --- The board reads as seven rows. ------------------------------------
	var board := ladder.board(dawn + 60.0)
	var labels: Array = []
	for row in board.rows:
		labels.append(str(row.band_label))
	check(labels == ["SINGULARITY", "PRIVY RING", "OFFICE", "NETWORK", "OUTSIDE"], "the board has the five bands in order")
	check((board.rows[4].seats as Array).is_empty(), "OUTSIDE is the crowd and draws no seats")
	check((board.fallen as Array).size() == 1 and str(board.fallen[0].name) == "RUNNER ONE", "the fallen are on the board with the seat they held")
	check(int(board.empty_seats) > 0, "the board counts its empty seats")

	# --- The board survives a save. ---------------------------------------
	var saved := JSON.stringify(ladder.snapshot())
	var restored := Ladder.new()
	restored.restore(JSON.parse_string(saved))
	check(str(restored.seat_by_id("seat_2_00").get("occupant_id", "")) == promoted_id, "seats survive JSON")
	check(str(restored.society.subject("runner_0").get("status", "")) == "dead" and (restored.board().fallen as Array).size() == 1, "the dead survive with the board")
	check(restored.seat_by_id("seat_2_00").occupant_id != "", "the promoted person is still seated after a restore")

	# --- The facility's own two people can be seated in one call. ---------
	var facility := Ladder.new()
	facility.begin(Society.new(), "celloutz")
	check(facility.register_facility() == 2, "the two authored facility guards can be seated")
	check(str(facility.seat_of("guard_celloutz_47").band_id) == "office" and str(facility.seat_of("guard_hollis").band_id) == "network", "47 holds an office seat and Hollis a network one")
	facility.vacate("guard_celloutz_47", {"cause": "killed"})
	facility.catch_up(facility.next_dawn(noon))
	check(str(facility.seat_of("guard_hollis").band_id) == "office", "Hollis moves up into 47's seat at dawn")

	print("LADDER_SEATS_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
