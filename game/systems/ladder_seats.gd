class_name LadderSeats
extends RefCounted

## Brief 1 of `DESIGN/PROMPT_ROADMAP.md`: `ladder-seats`.
##
## `PyramidSociety` says where a person *belongs*; it recomputes that from the
## twelve dimensions on every call, so a death does not leave a hole in it — the
## next person simply slides up the same instant. That is a sorting rule, not a
## ladder. This is the ladder: a fixed set of seats, one occupant each, and the
## two things a seat can do that a sort cannot.
##
##   **A seat can stand empty.** When its occupant dies it is emptied, and it
##   carries the hour it fills, which is the next dawn, not the next frame. The
##   player can see a hole and act before it closes.
##
##   **A seat refills from below.** At that dawn the highest-ranked person in the
##   band beneath it moves up, vacating their own seat, which then waits for the
##   dawn after. One band per dawn, so a death at the top is a slow, readable
##   reshuffle rather than an instant re-sort.
##
## Whose ranking? `PyramidSociety.pyramid()`'s, read rather than copied: the
## twelve-dimension lexicographic order is the society's own rule and a second
## copy of it here would drift from it the first time anyone tunes a gate.
##
## `THE_LADDER.md` §5 proposes that a promotion needs a sponsor, and names the
## fallback if Greg says no: *seniority — the longest-serving person in the band
## below takes the seat at dawn*. He has not answered, so this is the fallback,
## recorded plainly: seniority first, the pyramid's own order to break a tie, and
## no sponsor and no retinue. A seat with nobody beneath it stands empty at the
## next dawn, and the board says so instead of inventing a promotion.

const Society := preload("res://systems/pyramid_society.gd")

const SCHEMA_VERSION := 1
## The first hour `WorldClock.phase()` calls dawn. A seat that fills "at dawn"
## has to fill at the hour the game is willing to name dawn.
const DAWN_HOUR := 6.5
## The two authored people the facility already introduces. Kept here as a
## starting roster so a scene can seat them in one call; nothing about them is
## invented — the ids and names are `FacilityGuardPost`'s own constants.
const FACILITY_ROSTER := {
	# 47 is the senior of the two and holds an office seat; Hollis is the junior
	# man and waits a band below him, which is what makes his death a promotion
	# somebody can see. Neither number is lore — the gates in `PyramidSociety`
	# read them, and the doors and the board are the only places they show.
	"guard_hollis": {
		"name": "HOLLIS", "role": "Support Unit checkpoint guard", "faction_id": "celloutz",
		"social_power": {"class": 30, "influence": 34, "wealth": 18, "access": 56, "reputation": 16, "fear": 26, "respect": 28, "faction": 62, "combat": 40, "leverage": 32, "knowledge": 44, "relationships": 24},
	},
	"guard_celloutz_47": {
		"name": "CELLOUTZ SECURITY 47", "role": "Service Arcade patrol", "faction_id": "celloutz",
		"social_power": {"class": 34, "influence": 44, "wealth": 24, "access": 52, "reputation": 24, "fear": 34, "respect": 20, "faction": 70, "combat": 52, "leverage": 30, "knowledge": 30, "relationships": 22},
	}
}

var society: PyramidSociety
var faction_id := "celloutz"
## One seat per place in every capped band, in band order, in slot order. The
## OUTSIDE band is the crowd and owns no seats.
var seats: Array[Dictionary] = []
## Everything the board did, oldest first: vacated, promoted, stood empty.
var history: Array[Dictionary] = []
## The dead who held a seat, so FALLEN can name the seat as well as the person.
var fallen: Dictionary = {}

var _next_record := 1


## Build the board and empty every seat. Called once per save.
func begin(pyramid: PyramidSociety = null, faction := "celloutz") -> void:
	society = pyramid if pyramid != null else Society.new()
	faction_id = faction
	seats.clear()
	history.clear()
	fallen.clear()
	_next_record = 1
	for band_index in Society.BANDS.size():
		var definition: Dictionary = Society.BANDS[band_index]
		var capacity := int(definition.capacity)
		if capacity < 0:
			continue
		for slot in capacity:
			seats.append({
				"id": "seat_%d_%02d" % [band_index, slot],
				"band_index": band_index,
				"band_id": str(definition.id),
				"band_label": str(definition.label),
				"slot": slot,
				"occupant_id": "",
				"occupant_since": 0.0,
				"empty_since": 0.0,
				"fills_at": 0.0,
				"last_vacated_id": "",
				"last_vacated_name": "",
				"emptied_by": "",
				"history": [],
			})


## Seat one person, and return the seat they took, or empty when every place
## they are eligible for is taken and they are therefore the crowd.
func register(person_id: String, definition: Dictionary = {}, at := -1.0) -> Dictionary:
	if society == null:
		begin()
	if person_id.is_empty():
		return {}
	if has_seat(person_id):
		return seat_of(person_id)
	society.register_subject(person_id, definition)
	var seat := _first_free_from(_eligible_band(person_id))
	if seat.is_empty():
		return {}
	var now := at if at >= 0.0 else WorldClock.minutes()
	seat["occupant_id"] = person_id
	seat["occupant_since"] = now
	seat["empty_since"] = 0.0
	seat["fills_at"] = 0.0
	return seat.duplicate(true)


## Seat the people the facility already names. Returns how many were placed.
func register_facility(extra: Dictionary = {}) -> int:
	var placed := 0
	for person_id in FACILITY_ROSTER:
		if not register(str(person_id), FACILITY_ROSTER[person_id]).is_empty():
			placed += 1
	for person_id in extra:
		if extra[person_id] is Dictionary and not register(str(person_id), extra[person_id]).is_empty():
			placed += 1
	return placed


func has_seat(person_id: String) -> bool:
	return not seat_of(person_id).is_empty()


func seat_of(person_id: String) -> Dictionary:
	for seat in seats:
		if str(seat.occupant_id) == person_id:
			return seat
	return {}


func seat_by_id(seat_id: String) -> Dictionary:
	for seat in seats:
		if str(seat.id) == seat_id:
			return seat
	return {}


func empty_seats() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for seat in seats:
		if str(seat.occupant_id).is_empty():
			found.append(seat)
	return found


## A death empties the seat at once and names the dawn it fills.
func vacate(person_id: String, death: Dictionary = {}, at := -1.0) -> Dictionary:
	var seat := seat_of(person_id)
	if seat.is_empty():
		return {}
	var now := at if at >= 0.0 else WorldClock.minutes()
	society.mark_dead(person_id, death)
	var dead_name := str(society.subject(person_id).get("name", person_id))
	seat["occupant_id"] = ""
	seat["occupant_since"] = 0.0
	seat["empty_since"] = now
	seat["fills_at"] = next_dawn(now)
	seat["last_vacated_id"] = person_id
	seat["last_vacated_name"] = dead_name
	seat["emptied_by"] = "death"
	var record := {
		"id": "ladder_%06d" % _next_record,
		"type": "vacated",
		"person_id": person_id,
		"name": dead_name,
		"seat_id": str(seat.id),
		"band_label": str(seat.band_label),
		"at": now,
		"fills_at": float(seat.fills_at),
	}
	_next_record += 1
	_in_seat(seat, record)
	WorldHistory.record_event("ladder_seat_vacated", {
		"person_id": person_id,
		"name": dead_name,
		"seat_id": str(seat.id),
		"band_id": str(seat.band_id),
		"fills_at": float(seat.fills_at),
	})
	fallen[person_id] = {
		"id": person_id,
		"name": dead_name,
		"seat_id": str(seat.id),
		"band_label": str(seat.band_label),
		"died_at": now,
	}
	return seat.duplicate(true)


## Fill every seat that has reached its dawn. Safe to call every frame: it does
## nothing until a seat is due. Returns the promotions and the stands-empty.
func catch_up(at := -1.0) -> Array[Dictionary]:
	var now := at if at >= 0.0 else WorldClock.minutes()
	var changes: Array[Dictionary] = []
	var rounds := 0
	while rounds < 64:
		rounds += 1
		var due := _earliest_due(now)
		if due.is_empty():
			break
		var promotion := _promote_into(due, now)
		if promotion.is_empty():
			continue
		changes.append(promotion)
	return changes


## Absolute minute of the first dawn strictly after `minute`.
static func next_dawn(minute: float) -> float:
	var day_start := floorf(minute / WorldClock.MINUTES_PER_DAY) * WorldClock.MINUTES_PER_DAY
	var dawn := day_start + DAWN_HOUR * WorldClock.MINUTES_PER_HOUR
	if dawn <= minute:
		dawn += WorldClock.MINUTES_PER_DAY
	return dawn


## Seven rows: the five bands, then YOU, then FALLEN. The screen that draws this
## is brief 3; the board itself is this data.
func board(at := -1.0) -> Dictionary:
	var now := at if at >= 0.0 else WorldClock.minutes()
	var rows: Array[Dictionary] = []
	var empties := 0
	for band_index in Society.BANDS.size():
		var definition: Dictionary = Society.BANDS[band_index]
		var row := {
			"band_id": str(definition.id),
			"band_label": str(definition.label),
			"capacity": int(definition.capacity),
			"seats": [],
		}
		for seat in seats:
			if int(seat.band_index) != band_index:
				continue
			var card := card_for(seat, now)
			if bool(card.get("empty", false)):
				empties += 1
			(row.seats as Array).append(card)
		rows.append(row)
	return {
		"schema_version": SCHEMA_VERSION,
		"faction_id": faction_id,
		"headcount": _living_count(),
		"empty_seats": empties,
		"next_fill": _next_fill_stamp(now),
		"rows": rows,
		"you": {},
		"fallen": fallen.values().duplicate(true),
		"crowd": _crowd_ids(),
	}


## One card. The fields are `THE_CAST.md` §7's, minus the two the board cannot
## honestly fill yet: no scar line until the scar ledger (brief 2), no aim word
## and no retinue until Greg answers `THE_LADDER.md` §5.
func card_for(seat: Dictionary, now := -1.0) -> Dictionary:
	var at := now if now >= 0.0 else WorldClock.minutes()
	if str(seat.occupant_id).is_empty():
		return {
			"empty": true,
			"seat_id": str(seat.id),
			"band_id": str(seat.band_id),
			"band_label": str(seat.band_label),
			"empty_since": float(seat.empty_since),
			"fills_at": float(seat.fills_at),
			"fills_at_stamp": stamp(float(seat.fills_at)) if float(seat.fills_at) > 0.0 else "",
			"fills_in_hours": maxf(0.0, (float(seat.fills_at) - at) / WorldClock.MINUTES_PER_HOUR),
			"was": str(seat.get("last_vacated_name", "")),
			"emptied_by": str(seat.get("emptied_by", "death")),
		}
	var entry := society.subject(str(seat.occupant_id))
	var power: Dictionary = entry.get("social_power", {})
	var alignment := float(entry.get("alignment", 0.0))
	return {
		"empty": false,
		"seat_id": str(seat.id),
		"band_id": str(seat.band_id),
		"band_label": str(seat.band_label),
		"occupant_id": str(seat.occupant_id),
		"name": str(entry.get("name", seat.occupant_id)),
		"role": str(entry.get("role", "")),
		"side": "ABOVE" if alignment > 0.15 else ("BELOW" if alignment < -0.15 else "HINGE"),
		"traits": _traits(power),
		"seated_at": float(seat.occupant_since),
		"seated_stamp": stamp(float(seat.occupant_since)),
		"promoted_into": str(seat.last_vacated_name) if float(seat.occupant_since) > 0.0 and not str(seat.last_vacated_id).is_empty() else "",
		"scar_line": "",
		"aim": "",
		"retinue": 0,
	}


## "DAY 2 · 06:30", so an empty seat can be read without a clock beside it.
static func stamp(minute: float) -> String:
	var day := int(minute / WorldClock.MINUTES_PER_DAY) + 1
	var into_day := fmod(minute, WorldClock.MINUTES_PER_DAY)
	return "DAY %d · %02d:%02d" % [day, int(into_day / WorldClock.MINUTES_PER_HOUR), int(fmod(into_day, WorldClock.MINUTES_PER_HOUR))]


## The board is part of the save: seats, the dead, and the society they came
## from travel together, because a restored board whose society disagreed with
## its seats would seat the wrong person at the next death.
func snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"faction_id": faction_id,
		"next_record": _next_record,
		"seats": JSON.parse_string(JSON.stringify(seats)),
		"history": JSON.parse_string(JSON.stringify(history)),
		"fallen": JSON.parse_string(JSON.stringify(fallen)),
		"society": society.snapshot(),
	}


func restore(payload: Dictionary) -> void:
	begin(null, str(payload.get("faction_id", "celloutz")))
	_next_record = maxi(1, int(payload.get("next_record", 1)))
	if payload.get("society", {}) is Dictionary:
		society.restore(payload.society)
	var stored_seats: Array = payload.get("seats", [])
	for raw in stored_seats:
		if not raw is Dictionary:
			continue
		var stored: Dictionary = raw
		var seat := seat_by_id(str(stored.get("id", "")))
		if seat.is_empty():
			continue
		for key in stored:
			seat[key] = stored[key]
	var stored_history: Array = payload.get("history", [])
	for raw in stored_history:
		if raw is Dictionary:
			history.append((raw as Dictionary).duplicate(true))
	if payload.get("fallen", {}) is Dictionary:
		fallen = (payload.fallen as Dictionary).duplicate(true)


# --- Inside. --------------------------------------------------------------------

func _earliest_due(now: float) -> Dictionary:
	var due: Dictionary = {}
	for seat in seats:
		if not str(seat.occupant_id).is_empty():
			continue
		if float(seat.fills_at) <= 0.0 or float(seat.fills_at) > now:
			continue
		if due.is_empty() or float(seat.fills_at) < float(due.fills_at):
			due = seat
	return due


## The highest-ranked eligible person below `seat`'s band moves up. Their own
## seat empties for the dawn after, so a band fills from the bottom up over
## several dawns instead of all at once.
func _promote_into(seat: Dictionary, now: float) -> Dictionary:
	var band_index := int(seat.band_index)
	var candidate_id := _best_candidate(band_index)
	if candidate_id.is_empty():
		# Nobody below can hold this band. Say so at every dawn, and let the seat
		# keep its next hour rather than pretending it is about to fill.
		seat["fills_at"] = next_dawn(now)
		var stood := {
			"id": "ladder_%06d" % _next_record,
			"type": "stood_empty",
			"seat_id": str(seat.id),
			"band_label": str(seat.band_label),
			"at": now,
		}
		_next_record += 1
		_in_seat(seat, stood)
		return stood
	var promoted_name := str(society.subject(candidate_id).get("name", candidate_id))
	var from_seat := seat_of(candidate_id)
	var from_label := str(from_seat.get("band_label", "OUTSIDE"))
	if not from_seat.is_empty():
		from_seat["occupant_id"] = ""
		from_seat["occupant_since"] = 0.0
		from_seat["empty_since"] = now
		from_seat["fills_at"] = next_dawn(now)
		# The seat is empty because its holder moved up, not because anybody
		# died in it. The card says who left and why.
		from_seat["last_vacated_id"] = candidate_id
		from_seat["last_vacated_name"] = promoted_name
		from_seat["emptied_by"] = "promoted"
	var into_name := str(seat.last_vacated_name)
	seat["occupant_id"] = candidate_id
	seat["occupant_since"] = now
	seat["empty_since"] = 0.0
	seat["fills_at"] = 0.0
	var record := {
		"id": "ladder_%06d" % _next_record,
		"type": "promoted",
		"person_id": candidate_id,
		"name": promoted_name,
		"seat_id": str(seat.id),
		"band_label": str(seat.band_label),
		"from_band_label": from_label,
		"into_seat_of": into_name,
		"at": now,
	}
	_next_record += 1
	_in_seat(seat, record)
	# The promotion is a nemesis event on both subjects: the one who took the
	# seat and the one whose death made it worth taking.
	society.record_nemesis_event(candidate_id, "promoted", {
		"into_seat_of": into_name,
		"seat_id": str(seat.id),
		"band_id": str(seat.band_id),
		"from_band_id": str(from_seat.get("band_id", "outside")),
	})
	if not str(seat.last_vacated_id).is_empty():
		society.record_nemesis_event(str(seat.last_vacated_id), "seat_taken", {
			"taken_by": candidate_id,
			"seat_id": str(seat.id),
			"band_id": str(seat.band_id),
		})
	WorldHistory.record_event("ladder_promotion", {
		"person_id": candidate_id,
		"name": promoted_name,
		"into_seat_of": into_name,
		"seat_id": str(seat.id),
		"band_id": str(seat.band_id),
		"from_band_id": str(from_seat.get("band_id", "outside")),
	})
	return record


## Who the seat goes to: the longest-serving person one band beneath it, and
## the pyramid's order when two have served as long. Seated people for every
## band but the last; for the last (OUTSIDE) the crowd itself, since that band
## owns no seats and everyone in it is available, ordered by their standing.
func _best_candidate(band_index: int) -> String:
	var below := band_index + 1
	if below >= Society.BANDS.size():
		return ""
	var rank := _rank_order()
	var candidates: Array[String] = []
	if int(Society.BANDS[below].capacity) < 0:
		for person_id in society.records:
			var entry: Dictionary = society.records[person_id]
			if str(entry.get("kind", "person")) != "person":
				continue
			if not faction_id.is_empty() and str(entry.get("faction_id", "")) != faction_id:
				continue
			if Society.DEAD_STATUSES.has(str(entry.get("status", "active")).to_lower()):
				continue
			if has_seat(str(person_id)):
				continue
			candidates.append(str(person_id))
	else:
		for seat in seats:
			if int(seat.band_index) != below or str(seat.occupant_id).is_empty():
				continue
			candidates.append(str(seat.occupant_id))
	var best := ""
	var best_key := [1.0e12, 1 << 30]
	for person_id in candidates:
		var seat := seat_of(person_id)
		# A seated person's seniority is the hour they took the seat. The crowd
		# has never held one, so they are all equally new and the standing decides.
		var served := float(seat.occupant_since) if not seat.is_empty() else 1.0e12
		var key := [served, int(rank.get(person_id, 1 << 20))]
		if key[0] < best_key[0] or (key[0] == best_key[0] and key[1] < best_key[1]):
			best = person_id
			best_key = key
	return best


## Every living person, in the society's own order. Read from `pyramid()` so the
## ladder and the pyramid cannot disagree about who outranks whom.
func _rank_order() -> Dictionary:
	var order := {}
	var index := 0
	for band in society.pyramid(faction_id).bands:
		for member in (band as Dictionary).members:
			order[str((member as Dictionary).id)] = index
			index += 1
	return order


## Where the society's own gates would seat this person. Read, never copied:
## the twelve dimensions and the four thresholds are `PyramidSociety`'s.
func _eligible_band(person_id: String) -> int:
	var entry := society.subject(person_id)
	if entry.is_empty():
		return Society.BANDS.size() - 1
	return society._eligible_band(entry.get("social_power", {}))


func _first_free_from(band_index: int) -> Dictionary:
	for seat in seats:
		if int(seat.band_index) < band_index:
			continue
		if str(seat.occupant_id).is_empty() and float(seat.fills_at) <= 0.0:
			return seat
	return {}


func _in_seat(seat: Dictionary, record: Dictionary) -> void:
	var seat_history: Array = seat.get("history", [])
	seat_history.append(record.duplicate(true))
	seat["history"] = seat_history
	history.append(record.duplicate(true))


func _living_count() -> int:
	var count := 0
	for person_id in society.records:
		var entry: Dictionary = society.records[person_id]
		if str(entry.get("kind", "person")) != "person":
			continue
		if not faction_id.is_empty() and str(entry.get("faction_id", "")) != faction_id:
			continue
		if Society.DEAD_STATUSES.has(str(entry.get("status", "active")).to_lower()):
			continue
		count += 1
	return count


func _crowd_ids() -> Array[String]:
	var ids: Array[String] = []
	for person_id in society.records:
		if has_seat(str(person_id)):
			continue
		var entry: Dictionary = society.records[person_id]
		if str(entry.get("kind", "person")) != "person":
			continue
		if Society.DEAD_STATUSES.has(str(entry.get("status", "active")).to_lower()):
			continue
		ids.append(str(person_id))
	return ids


## Three traits, as words. The twelve dimensions stay behind the card; the board
## names the three that carry this person, in the order the society compares
## them, so two cards can be compared by reading them.
func _traits(power: Dictionary) -> Array[String]:
	var ranked: Array = []
	for dimension in Society.DIMENSIONS:
		var value := float(power.get(str(dimension), 0.0))
		if value <= 0.0:
			continue
		ranked.append({"name": str(dimension), "value": value})
	ranked.sort_custom(func(a, b):
		if not is_equal_approx(float(a.value), float(b.value)):
			return float(a.value) > float(b.value)
		return str(a.name) < str(b.name))
	var traits: Array[String] = []
	for item in ranked:
		if traits.size() >= 3:
			break
		traits.append(str(item.name).to_upper())
	while traits.size() < 3:
		traits.append("—")
	return traits


func _next_fill_stamp(now: float) -> String:
	var soonest := 0.0
	for seat in empty_seats():
		var at := float(seat.fills_at)
		if at <= 0.0:
			continue
		if soonest <= 0.0 or at < soonest:
			soonest = at
	if soonest <= 0.0:
		return ""
	return stamp(soonest)
