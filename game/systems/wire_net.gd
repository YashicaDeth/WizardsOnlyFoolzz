class_name WireNet
extends RefCounted

const WoundCatalog := preload("res://systems/wound_catalog.gd")
const PlayerActionLedger := preload("res://systems/player_action_ledger.gd")

## The surviving internet, as a simulation rather than a screen.
##
## `DESIGN/IN_GAME_INTERNET.md` specifies the Wire in full and almost none of it
## was built — one reactive headline in the derby was the entire implementation.
## This is the model underneath it: accounts derived from real `WorldHistory`
## subjects, reach that is deliberately *not* combat skill, replies weighted by
## the gap in standing, and the faction hierarchy read as a recruitment pyramid.
##
## Three rules from that document drive every number here.
##
## **Clout is the world's estimate of power, and it can be wrong.** Reach comes
## from connections and from how often the world reports on you, with only a
## small contribution from how dangerous you actually are. Vale Nine can kill
## nearly anyone in the region and has almost no followers; Doctor Vanta is a
## rumour with a surgical crown and outranks the entire Bone Yard. That gap is
## the point, and it is what makes the Wire a second progression ladder instead
## of a reskin of the first.
##
## **High-clout accounts do not answer.** A Chief with a large account is *less*
## reachable than a nobody. Messaging them is not the route; an intermediary
## inside their network, leverage worth their attention, or enough standing of
## your own is the route. One exception, and it is the most useful mechanic in
## here: somebody who hates you will always reply. Being loathed is access.
##
## **Everything is reciprocal.** Every hostile action raises `exposure`, and
## exposure is what lets somebody else run the same playbook back at you — the
## trace that arrives at a physical place. A consequence-free harassment toy
## would be both worse design and a worse joke.
##
## Kept free of any `Node` so it can be tested headlessly and so the drawing in
## `world_index.gd` owns no simulation.

## Relations that lend reach. A grudge is not influence — being hated by a
## powerful person does not give you followers, it gives you a problem.
const INFLUENCE_KINDS := ["command", "ally", "bond", "saved", "known"]

## Account bands. CROWN and CIRCLE carry the verified mark and are the ones the
## design says will not read a DM.
const TIERS := [
	{"name": "CROWN", "floor": 4000, "verified": true, "answers": 0.02},
	{"name": "CIRCLE", "floor": 2200, "verified": true, "answers": 0.08},
	{"name": "PROMOTER", "floor": 900, "verified": false, "answers": 0.28},
	{"name": "EARNER", "floor": 250, "verified": false, "answers": 0.55},
	{"name": "INTAKE", "floor": 0, "verified": false, "answers": 0.78},
]

## Signal grade is a property of *place*, per the design: no coverage in the
## caves, ordinary coverage near a mast, and the underbelly only through a
## physical access point rather than a menu toggle.
const SIGNAL_NONE := 0
const SIGNAL_SURFACE := 1
const SIGNAL_UNDERBELLY := 2

var signal_grade := SIGNAL_SURFACE
var strain := 0.0
var exposure := 0
var traced_by := ""

var _accounts: Dictionary = {}
var _coverage: Dictionary = {}

## W1.4. Factions share the one WorldClock, but they do not share a shift.
## These are communications windows, not a second simulation clock: patrols,
## shops and bodies may still exist outside them. A faction subject may provide
## `wire_hours: [start, end]`; this table is the stable baseline for the cast
## already in the world. Equal endpoints mean an institutional 24-hour channel.
const FACTION_WIRE_HOURS := {
	"celloutz": [0.0, 0.0],
	"ashline_wreckers": [18.0, 6.0],
	"gate_lanterns": [5.0, 18.0],
	"black_mile": [20.0, 8.0],
	"soft_rot": [4.0, 16.0],
	"choir_of_marrow": [22.0, 5.0],
	"vanity_row": [12.0, 2.0],
	"honeyvein": [7.0, 21.0],
	"long_static": [0.0, 10.0],
	"wizardsonlyfoolz": [19.0, 4.0],
}

const QUIET_ACTIVITY := 0.12


func _init(grade: int = SIGNAL_SURFACE) -> void:
	signal_grade = grade
	rebuild()


## Accounts are derived, never authored. A subject that enters the world gets an
## account the next time this runs, which is what makes the Wire react to the
## Hunt System without either system knowing about the other.
func rebuild() -> void:
	_accounts.clear()
	_coverage.clear()
	for event in WorldHistory.events:
		var details: Dictionary = event.get("details", {})
		for key in ["subject", "subject_id", "target", "rival", "victim", "actor"]:
			var named := str(details.get(key, ""))
			if named != "":
				_coverage[named] = int(_coverage.get(named, 0)) + 1
	for subject_id in WorldHistory.all_subjects():
		var subject: Dictionary = WorldHistory.subject(subject_id)
		if str(subject.get("kind", "person")) != "person":
			continue
		_accounts[subject_id] = _build_account(subject_id, subject)


## K3.2 v2. "Nothing yet stops a player climbing both ladders at once." K3.1's
## own answer left the *axis* (`tree_alignment()`) freely reversible right up
## until an ending actually locks it, deliberately — this is a different
## claim, about real standing rather than the axis: nothing charged for
## holding genuine command-relation weight in a Descent faction and in
## wizardsonlyfoolz *at the same time*. Real friction rather than a hard
## block, same register as `Boons`/`Substances`: reach is halved once both
## sides are genuinely being climbed at once, not merely touched in passing.
const DESCENT_LEDGER_FACTIONS := ["celloutz", "ashline_wreckers", "black_mile", "soft_rot", "choir_of_marrow", "vanity_row", "honeyvein", "long_static"]
const ASCENT_LEDGER_FACTIONS := ["wizardsonlyfoolz"]
const DUAL_LADDER_THRESHOLD := 20
const DUAL_LADDER_PENALTY := 0.5


func _ladder_commitment(relations: Dictionary, faction_ids: Array) -> int:
	var total := 0
	for other in relations:
		var edge: Dictionary = relations[other]
		if faction_ids.has(str(other)) and INFLUENCE_KINDS.has(str(edge.get("kind", ""))):
			total += int(edge.get("strength", 0))
	return total


func _ladder_split_penalty(relations: Dictionary) -> float:
	var descent := _ladder_commitment(relations, DESCENT_LEDGER_FACTIONS)
	var ascent := _ladder_commitment(relations, ASCENT_LEDGER_FACTIONS)
	if descent >= DUAL_LADDER_THRESHOLD and ascent >= DUAL_LADDER_THRESHOLD:
		return DUAL_LADDER_PENALTY
	return 1.0


func _build_account(subject_id: String, subject: Dictionary) -> Dictionary:
	var influence := 0
	var relations: Dictionary = subject.get("relations", {})
	for other in relations:
		var edge: Dictionary = relations[other]
		if INFLUENCE_KINDS.has(str(edge.get("kind", ""))):
			influence += int(edge.get("strength", 0))
	var coverage := int(_coverage.get(subject_id, 0))
	var elo := int(subject.get("elo", 1000))
	# Skill contributes, but barely. A reputation for violence travels; it does
	# not travel nearly as far as knowing everybody.
	var skill_reach := maxi(0, elo - 950) / 6
	var manufactured := _manufactured(subject_id, subject)
	var reach := 40 + influence * 46 + coverage * 120 + skill_reach + manufactured
	reach = int(float(reach) * _ladder_split_penalty(relations))
	var tier := _tier_for(reach)
	var faction_id := str(subject.get("faction_id", ""))
	var activity := faction_activity(faction_id)
	return {
		"id": subject_id,
		"name": str(subject.get("name", subject_id)),
		"handle": _handle(str(subject.get("name", subject_id))),
		"faction": str(subject.get("faction", "Unbound")),
		"faction_id": faction_id,
		"role": str(subject.get("role", "unindexed")),
		"reach": reach,
		"influence": influence,
		"coverage": coverage,
		"manufactured": manufactured,
		"elo": elo,
		"grudge": int(subject.get("grudge", 0)),
		"status": str(subject.get("status", "unknown")),
		"tier": str(tier.name),
		"verified": bool(tier.verified),
		"answers": float(tier.answers),
		"band": _band_for(subject),
		"activity": activity,
		"last_seen": _last_seen(subject_id, subject, activity),
	}


## Bought reach. Brokers, adjudicators and anyone whose role is talking rather
## than fighting has a number that was partly purchased, and the interface says
## so — the design's "it can be wrong, bought or manufactured" made legible.
func _manufactured(subject_id: String, subject: Dictionary) -> int:
	var role := str(subject.get("role", "")).to_lower()
	var buys := role.contains("adjudicator") or role.contains("anatomist") or role.contains("broker") or role.contains("captain")
	if not buys:
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(subject_id) & 0x7fffffff
	return rng.randi_range(300, 1800)


func _tier_for(reach: int) -> Dictionary:
	for tier in TIERS:
		if reach >= int(tier.floor):
			return tier
	return TIERS[TIERS.size() - 1]


## The underbelly is not a moral category, it is a routing one: people the
## surface feeds will not carry. A rumoured anatomist selling replacement arms
## is down there because no ordinary feed will host him.
func _band_for(subject: Dictionary) -> int:
	var status := str(subject.get("status", "")).to_lower()
	var faction := str(subject.get("faction_id", ""))
	if status in ["rumoured", "unlocated"] or faction == "choir_of_marrow":
		return SIGNAL_UNDERBELLY
	return SIGNAL_SURFACE


## A dormant profile reading "last online two minutes ago" should be unsettling,
## so the number is real: it comes from the subject's status, not from decoration.
func _last_seen(subject_id: String, subject: Dictionary, activity := 1.0) -> String:
	var status := str(subject.get("status", "")).to_lower()
	var faction_id := str(subject.get("faction_id", ""))
	if not faction_id.is_empty() and activity <= QUIET_ACTIVITY + 0.001 and status not in ["dead", "downed", "executed"]:
		var schedule := faction_schedule(faction_id)
		return "QUIET UNTIL %02d:00" % int(schedule.get("start", 0.0))
	if status in ["active", "following", "hunting", "awake"]:
		return "ONLINE NOW"
	if status in ["roaming", "cultivating", "waiting"]:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(subject_id) & 0x7fffffff
		return "%d MIN AGO" % rng.randi_range(3, 240)
	if status in ["dead", "downed", "executed"]:
		return "LAST POST STANDS"
	return "%d DAYS AGO" % ((hash(subject_id) & 0x7f) % 900 + 4)


## A continuous activity value rather than an online/offline switch. Inside a
## shift it rises toward the middle and falls toward handover; outside it keeps
## a small automated residue. Windows crossing midnight use the same math.
func faction_schedule(faction_id: String) -> Dictionary:
	var faction := WorldHistory.subject(faction_id)
	var authored: Array = faction.get("wire_hours", [])
	var hours: Array = authored if authored.size() >= 2 else FACTION_WIRE_HOURS.get(faction_id, [8.0, 20.0])
	return {"start": float(hours[0]), "end": float(hours[1])}


func faction_activity(faction_id: String, at := -1.0) -> float:
	if faction_id.is_empty():
		return 0.45
	var schedule := faction_schedule(faction_id)
	var start := fposmod(float(schedule.start), WorldClock.HOURS_PER_DAY)
	var finish := fposmod(float(schedule.end), WorldClock.HOURS_PER_DAY)
	if is_equal_approx(start, finish):
		return 1.0
	var hour_at: float = WorldClock.hour() if float(at) < 0.0 else fposmod(float(at), WorldClock.HOURS_PER_DAY)
	var duration := fposmod(finish - start, WorldClock.HOURS_PER_DAY)
	var elapsed := fposmod(hour_at - start, WorldClock.HOURS_PER_DAY)
	if elapsed > duration:
		return QUIET_ACTIVITY
	var through := clampf(elapsed / duration, 0.0, 1.0)
	return lerpf(0.62, 1.0, sin(through * PI))


## Mean traffic across factions that actually have people on this reachable
## Wire. No new population is invented just to make the gauge move.
func network_activity() -> float:
	var seen: Dictionary = {}
	for account_data: Dictionary in _accounts.values():
		var faction_id := str(account_data.get("faction_id", ""))
		if not faction_id.is_empty():
			seen[faction_id] = faction_activity(faction_id)
	if seen.is_empty():
		return 0.0
	var total := 0.0
	for value in seen.values():
		total += float(value)
	return clampf(total / float(seen.size()), 0.0, 1.0)


func activity_band() -> String:
	var activity := network_activity()
	if activity >= 0.72:
		return "CROWDED"
	if activity >= 0.38:
		return "RESTLESS"
	return "QUIET"


func accounts_by_reach() -> Array:
	var listing: Array = []
	for key in _accounts:
		var entry: Dictionary = _accounts[key]
		if int(entry.band) > signal_grade:
			continue
		listing.append(entry)
	listing.sort_custom(func(a, b): return int(a.reach) > int(b.reach))
	return listing


func account(subject_id: String) -> Dictionary:
	return _accounts.get(subject_id, {})


func player() -> Dictionary:
	return _accounts.get("player", {})


# --- the rank pyramid ------------------------------------------------------

## The faction hierarchy, read in the register the design asked for: a
## recruitment pyramid where rank is sold rather than earned, everyone has a
## downline, and the top is structurally unreachable.
##
## The data underneath it is real — command relation strength is the ladder, and
## a dead ranked subject leaves a genuine vacancy, which is filled from the
## existing faction roster by the promotion machinery below. The presentation
## is original: a faction hierarchy is nobody's property, but another game's
## specific way of drawing one is.
const RANKS := ["CROWN", "INNER CIRCLE", "PROMOTER", "EARNER", "INTAKE"]
const DEAD_STATUSES := ["dead", "executed", "killed"]

## K1.3. The pyramid's own rank names are MLM-register on purpose for the
## seven Sin-factions, and wrong for an ascending order that talks about
## itself in signal terms — "Frequency is rank" is the doctrine, so the
## grades should sound like it. Display-only: the buy-in math, the tiering
## and `promote_successor()` all still run on `RANKS` underneath: this is
## never a second rank system, only what a panel would print for it.
const FACTION_RANK_LABELS := {
	"wizardsonlyfoolz": {
		"CROWN": "Clear", "INNER CIRCLE": "Harmonic", "PROMOTER": "Sideband",
		"EARNER": "Carrier", "INTAKE": "Static",
	},
}


func rank_label(faction_id: String, generic_rank: String) -> String:
	var aliases: Dictionary = FACTION_RANK_LABELS.get(faction_id, {})
	return str(aliases.get(generic_rank, generic_rank))


func pyramid(faction_id: String) -> Dictionary:
	var faction: Dictionary = WorldHistory.subject(faction_id)
	var members: Array = []
	for key in _accounts:
		var entry: Dictionary = _accounts[key]
		if str(entry.faction_id) == faction_id and not DEAD_STATUSES.has(str(entry.status).to_lower()):
			members.append(entry)
	members.sort_custom(func(a, b): return int(a.influence) > int(b.influence))
	var tiers: Array = []
	for index in RANKS.size():
		tiers.append({"rank": RANKS[index], "members": [], "buy_in": int(pow(3.0, float(RANKS.size() - index)) * 40.0)})
	for member in members:
		var subject := WorldHistory.subject(str(member.id))
		var explicit_rank := str(subject.get("faction_rank", ""))
		var slot := RANKS.find(explicit_rank)
		if slot < 0:
			slot = _influence_rank_index(int(member.influence))
		tiers[slot]["members"].append(member)
	# Downline is what the pitch is actually selling, so it is counted honestly:
	# everybody strictly beneath you in your own faction.
	var running := 0
	for index in range(tiers.size() - 1, -1, -1):
		tiers[index]["downline"] = running
		running += (tiers[index]["members"] as Array).size()
	var vacancies: Array = (faction.get("vacant_posts", []) as Array).duplicate(true)
	for index in tiers.size():
		if (tiers[index]["members"] as Array).is_empty() and index < RANKS.size() - 1 and not vacancies.any(func(v): return str((v as Dictionary).get("rank", "")) == str(RANKS[index])):
			var claimant := _claimant(tiers, index)
			vacancies.append({"rank": RANKS[index], "claimant": claimant, "structural": true})
	for vacancy in vacancies:
		if not (vacancy as Dictionary).has("claimant"):
			vacancy["claimant"] = _best_successor(faction_id, str(vacancy.get("former", ""))).get("name", "")
	return {
		"id": faction_id,
		"name": str(faction.get("name", faction_id)),
		"doctrine": str(faction.get("doctrine", "No stated doctrine.")),
		"threat": str(faction.get("threat", "UNKNOWN")),
		"territory": str(faction.get("territory", "unmapped")),
		"tiers": tiers,
		"vacancies": vacancies,
		"headcount": members.size(),
	}


func _influence_rank_index(influence: int) -> int:
	if influence >= 70:
		return 0
	if influence >= 45:
		return 1
	if influence >= 25:
		return 2
	if influence >= 10:
		return 3
	return 4


## F3. A death creates a saved post on the faction itself. It is not inferred
## later from an empty drawing slot, so quitting between the death and the
## succession cannot silently heal the hierarchy.
func open_vacancy(subject_id: String) -> Dictionary:
	var fallen := WorldHistory.subject(subject_id)
	var faction_id := str(fallen.get("faction_id", ""))
	if fallen.is_empty() or faction_id.is_empty():
		return {}
	var account_data := _accounts.get(subject_id, _build_account(subject_id, fallen)) as Dictionary
	var rank := str(fallen.get("faction_rank", ""))
	if not RANKS.has(rank):
		rank = str(RANKS[_influence_rank_index(int(account_data.get("influence", 0)))])
	var faction := WorldHistory.subject(faction_id)
	var vacancies: Array = (faction.get("vacant_posts", []) as Array).duplicate(true)
	for existing in vacancies:
		if str((existing as Dictionary).get("former", "")) == subject_id:
			return existing
	var vacancy := {"rank": rank, "former": subject_id, "opened_sequence": WorldHistory.next_sequence}
	vacancies.append(vacancy)
	WorldHistory.begin_ledger_batch()
	WorldHistory.amend_subject(faction_id, {"vacant_posts": vacancies})
	WorldHistory.record_event("faction_post_vacated", {"faction_id": faction_id, "rank": rank, "former": subject_id})
	WorldHistory.commit_ledger_batch()
	return vacancy


## Fill one saved vacancy with a person who was already present. ELO is
## deliberately absent from the score: connections, loyalty, wealth and debt
## decide office; fighting decides whether the office-holder survives it.
func promote_successor(faction_id: String, rank: String = "") -> Dictionary:
	var faction := WorldHistory.subject(faction_id)
	var vacancies: Array = (faction.get("vacant_posts", []) as Array).duplicate(true)
	var vacancy_index := -1
	for index in vacancies.size():
		if rank.is_empty() or str((vacancies[index] as Dictionary).get("rank", "")) == rank:
			vacancy_index = index
			break
	if vacancy_index < 0:
		return {}
	var vacancy: Dictionary = vacancies[vacancy_index]
	var successor := _best_successor(faction_id, str(vacancy.get("former", "")))
	if successor.is_empty():
		return {}
	var subject_id := str(successor.id)
	var subject := WorldHistory.subject(subject_id)
	WorldHistory.begin_ledger_batch()
	WorldHistory.update_subject(subject_id, {
		"faction_rank": str(vacancy.rank),
		"previous_role": str(subject.get("role", "unindexed")),
		"role": "%s of %s" % [str(vacancy.rank).capitalize(), str(faction.get("name", faction_id))],
	}, "faction_member_promoted")
	vacancies.remove_at(vacancy_index)
	WorldHistory.amend_subject(faction_id, {"vacant_posts": vacancies})
	WorldHistory.record_event("faction_post_filled", {
		"faction_id": faction_id, "rank": vacancy.rank, "former": vacancy.get("former", ""),
		"successor": subject_id, "influence": successor.influence, "loyalty": successor.loyalty,
		"debt_leverage": successor.debt_leverage, "wealth": successor.wealth,
	})
	rebuild()
	WorldHistory.commit_ledger_batch()
	var promoted := WorldHistory.subject(subject_id)
	# The caller already receives the promoted subject; include its stable id so
	# consequences of succession (an inherited hunt, debt, command) can attach
	# to the real person without re-deriving who won the post from rank labels.
	promoted["id"] = subject_id
	return promoted


func _best_successor(faction_id: String, excluded_id: String) -> Dictionary:
	var candidates: Array = []
	for subject in WorldHistory.subjects_in_faction(faction_id):
		var subject_id := str(subject.id)
		if subject_id == excluded_id or DEAD_STATUSES.has(str(subject.get("status", "")).to_lower()):
			continue
		var account_data := _accounts.get(subject_id, _build_account(subject_id, subject)) as Dictionary
		var relations: Dictionary = subject.get("relations", {})
		var faction_edge: Dictionary = relations.get(faction_id, {})
		var loyalty := int(subject.get("loyalty", 0)) + (int(faction_edge.get("strength", 0)) if str(faction_edge.get("kind", "")) in ["command", "ally", "bond", "known"] else 0)
		var debt_leverage := 0
		for other in WorldHistory.subjects_in_faction(faction_id):
			var edge: Dictionary = (other.get("relations", {}) as Dictionary).get(subject_id, {})
			if str(edge.get("kind", "")) in ["owes", "debt"]:
				debt_leverage += int(edge.get("strength", 0))
		var wealth := int(subject.get("wealth", subject.get("scrip", 0)))
		@warning_ignore("integer_division")
		var score := int(account_data.get("influence", 0)) * 4 + loyalty * 3 + debt_leverage * 2 + wealth / 10
		candidates.append({
			"id": subject_id, "name": str(subject.get("name", subject_id)), "score": score,
			"influence": int(account_data.get("influence", 0)), "loyalty": loyalty,
			"debt_leverage": debt_leverage, "wealth": wealth,
		})
	candidates.sort_custom(func(a, b): return int(a.score) > int(b.score) if int(a.score) != int(b.score) else str(a.id) < str(b.id))
	return candidates[0] if not candidates.is_empty() else {}


## Who takes an empty post. Per the Hunt System this is not a generated
## replacement — it is whoever is already positioned, which may be a worse
## fighter with better connections, and that is meant to be worse news.
func _claimant(tiers: Array, empty_index: int) -> String:
	for index in range(empty_index + 1, tiers.size()):
		var members: Array = tiers[index]["members"]
		if not members.is_empty():
			return str((members[0] as Dictionary).name)
	return ""


func factions() -> Array:
	var listing: Array = []
	for subject_id in WorldHistory.all_subjects():
		var subject: Dictionary = WorldHistory.subject(subject_id)
		if str(subject.get("kind", "")) == "faction":
			listing.append(subject_id)
	listing.sort()
	return listing


# --- K4.4: signal territory ------------------------------------------------

## "A Sin does not hold a keep. It holds a channel." — DESIGN/FACTIONS.md,
## applied to whichever faction actually has a `channel` field (every Sin,
## per `bone_yard_hunt.gd` and `cosmology_factions.gd`). `signal_control`
## starts at 100 the first time a faction is contested at all, read fresh
## from the subject each time rather than cached, so two contests in the same
## session never disagree about where it started.
const CONTEST_ACTIONS := ["out_publish", "discredit", "hijack", "flood", "cut"]


func faction_signal_control(faction_id: String) -> float:
	return float(WorldHistory.subject(faction_id).get("signal_control", 100.0))


## The real reach standing behind a channel: every account already on that
## faction's own roster, summed. Not the faction's own `reach` field — there
## isn't one — so out-publishing a Sin means actually out-reaching the people
## who make up its audience, not beating a number invented for this purpose.
func _channel_reach(faction_id: String) -> float:
	var total := 0.0
	for entry in accounts_by_reach():
		if str(entry.faction_id) == faction_id:
			total += float(entry.reach)
	return total


## Real evidence, read off the same `trace`/`expose` actions `act()` already
## implements — a faction cannot be discredited on nothing, and this file
## does not invent a second evidence system to make the check real.
func leverage_on_faction(faction_id: String) -> String:
	for event in events_against_faction(faction_id):
		if str(event.get("type", "")) in ["wire_trace", "wire_expose"]:
			var target_id := str((event.get("details", {}) as Dictionary).get("subject", ""))
			var target := WorldHistory.subject(target_id)
			return "the pattern already traced on %s" % str(target.get("name", target_id))
	return ""


func events_against_faction(faction_id: String) -> Array:
	var out: Array = []
	for event in WorldHistory.events:
		var target_id := str((event.get("details", {}) as Dictionary).get("subject", ""))
		if str(WorldHistory.subject(target_id).get("faction_id", "")) == faction_id:
			out.append(event)
	return out


## The five routes from DESIGN/FACTIONS.md, each a real requirement against
## real state rather than a cost paid to a menu. `at_terminal` stands in for
## the physical-access requirement the design calls out for hijack/cut —
## whoever wires the world reads a player standing at a mast and passes it in.
func contest_channel(faction_id: String, action: String, subject_id: String = "player", at_terminal: bool = false) -> Dictionary:
	if not CONTEST_ACTIONS.has(action):
		return {"ok": false, "reason": "UNKNOWN ACTION"}
	var faction := WorldHistory.subject(faction_id)
	if faction.is_empty() or str(faction.get("kind", "")) != "faction":
		return {"ok": false, "reason": "NO SUCH FACTION"}
	if str(faction.get("channel", "")).is_empty():
		return {"ok": false, "reason": "THIS FACTION HOLDS NO CHANNEL TO CONTEST"}
	var control := faction_signal_control(faction_id)
	var result := {"ok": true, "headline": "", "detail": ""}
	match action:
		"out_publish":
			var my_reach := float(player().get("reach", 40)) if subject_id == "player" else float(account(subject_id).get("reach", 40))
			var their_reach := _channel_reach(faction_id)
			if my_reach <= their_reach:
				return {"ok": false, "reason": "YOUR REACH (%d) DOES NOT YET PASS THEIRS (%d)" % [int(my_reach), int(their_reach)]}
			control = maxf(0.0, control - 12.0)
			result.headline = "OUT-PUBLISHED"
			result.detail = "SLOW AND NON-VIOLENT. IT WILL TAKE MORE THAN ONE PASS."
		"discredit":
			var held := leverage_on_faction(faction_id)
			if held.is_empty():
				return {"ok": false, "reason": "NOTHING TRUE TO DISCREDIT THEM WITH YET"}
			control = maxf(0.0, control - 30.0)
			result.headline = "DISCREDITED"
			result.detail = held.to_upper()
		"hijack":
			if not at_terminal:
				return {"ok": false, "reason": "NEEDS PHYSICAL ACCESS TO A TERMINAL OR MAST"}
			control = maxf(0.0, control - 45.0)
			result.headline = "CHANNEL HIJACKED"
		"flood":
			control = maxf(0.0, control - 8.0)
			result.headline = "CHANNEL FLOODED"
			result.detail = "A DENIAL MOVE. NOTHING PROPAGATES THROUGH IT NOW, YOURS INCLUDED."
		"cut":
			if not at_terminal:
				return {"ok": false, "reason": "NEEDS PHYSICAL ACCESS TO THE MAST ITSELF"}
			control = 0.0
			result.headline = "MAST CUT"
			result.detail = "COVERAGE IS GONE FOR EVERYONE HERE, INCLUDING YOU."
	# Control, the public act and every resulting grudge are one consequence
	# chain. Player contests get a receipt; autonomous actors remain ordinary
	# world events rather than being falsely charged to the player.
	WorldHistory.begin_ledger_batch()
	WorldHistory.amend_subject(faction_id, {"signal_control": control})
	var details := {"faction_id": faction_id, "action": action, "subject_id": subject_id, "control_after": control}
	if subject_id == "player":
		PlayerActionLedger.record("channel_contested", details)
	else:
		WorldHistory.record_event("channel_contested", details)
	_retaliate(faction_id, action, subject_id)
	WorldHistory.commit_ledger_batch()
	result["control_after"] = control
	return result


## K4.6 v2. "The Sins are named and placed but do not act on the world" —
## a Sin does not have to spawn a counter-raid to stop being furniture; its
## own captain remembering who did this is enough to make it real, since
## grudge is what the rest of the Hunt System (RivalRegistry, F2 propagation)
## already reads. Scaled by how much the action actually cost the faction, so
## cutting a mast is remembered harder than flooding it for an afternoon.
const RETALIATION_GRUDGE := {
	"out_publish": 6, "discredit": 10, "hijack": 15, "flood": 4, "cut": 20,
}


func _retaliate(faction_id: String, action: String, subject_id: String) -> void:
	var grudge_gain := int(RETALIATION_GRUDGE.get(action, 0))
	if grudge_gain <= 0 or subject_id.is_empty():
		return
	var relations: Dictionary = WorldHistory.subject(faction_id).get("relations", {})
	for member_id in relations:
		if str((relations[member_id] as Dictionary).get("kind", "")) != "command":
			continue
		var captain := WorldHistory.subject(str(member_id))
		if str(captain.get("kind", "")) != "person":
			continue
		WorldHistory.update_subject(str(member_id), {"grudge": int(captain.get("grudge", 0)) + grudge_gain}, "channel_contest_remembered")
	# K2.5 v2. "The Horsemen exist as subjects with no behaviour of their
	# own." Whoever actually reigns notices an attack on any Sin CellOutz
	# commands, not only that Sin's own captain — half the grudge, since it
	# is once removed from them, but real: the same grudge field, so a
	# Horseman who has accumulated enough of it is exactly as meetable as any
	# other rival the Hunt System already produces.
	var celloutz_relations: Dictionary = WorldHistory.subject("celloutz").get("relations", {})
	if celloutz_relations.has(faction_id):
		var reigning := TheFourHorsemen.current_reign()
		if not reigning.is_empty():
			var horseman := WorldHistory.subject(reigning)
			@warning_ignore("integer_division")
			WorldHistory.update_subject(reigning, {"grudge": int(horseman.get("grudge", 0)) + maxi(1, grudge_gain / 2)}, "channel_contest_remembered_by_horseman")


## FACTIONS.md's implementation order, step 7 ("coupling: signal control
## gates grudge propagation"), from this side of the seam. Kept as a plain
## 0-1 multiplier rather than a yes/no gate — a half-flooded channel should
## carry a rumour half as far, not either the full distance or none of it —
## so whoever wires F2's actual propagation (Codex's file) can multiply by
## this rather than needing a second read of `signal_control`.
func signal_reach_factor(faction_id: String) -> float:
	return clampf(faction_signal_control(faction_id) / 100.0, 0.0, 1.0)


# --- contact ---------------------------------------------------------------

## Whether a DM gets read, and what comes back.
##
## The controlling term is the *ratio* of standing, not the difference, because
## the design's claim is structural: a nobody messaging a Crown is not slightly
## unlikely to be read, it is categorically not how that conversation happens.
func contact(subject_id: String, opener: String = "neutral") -> Dictionary:
	var target := account(subject_id)
	if target.is_empty():
		return {"ok": false, "reply": "", "reason": "NO SUCH ACCOUNT"}
	if signal_grade < int(target.band):
		return {"ok": false, "reply": "", "reason": "NO ROUTE FROM HERE"}
	var mine := player()
	var my_reach := float(mine.get("reach", 40))
	var their_reach := maxf(1.0, float(target.reach))
	var routes: Array = []
	# Routes multiply your effective standing and raise the ceiling; they are
	# deliberately not flat bonuses on the probability. A flat bonus large enough
	# to matter against a Crown is large enough to erase the hierarchy entirely,
	# which is the one thing this system is for — an early version handed a
	# nobody a 43% chance of being read by the most connected person in the
	# region, because +0.35 swamps a 9:1 gap in standing.
	var effective := my_reach
	var ceiling := float(target.answers)
	var broker := intermediary(subject_id)
	if broker != "":
		effective *= 3.0
		ceiling += 0.30
		routes.append("VIA %s" % broker.to_upper())
	var lever := leverage(subject_id)
	if lever != "":
		effective *= 2.5
		ceiling += 0.25
		routes.append("LEVERAGE HELD")
	# Being hated is access. A rival who wants you dead reads everything you
	# send, which is the cheapest route to a Crown in the game and costs exactly
	# what you would expect it to. It is the one thing allowed to beat the tier
	# ceiling outright.
	if int(target.grudge) >= 30:
		effective *= 6.0
		ceiling = 0.95
		routes.append("THEY WANT YOU")
	var chance := clampf(effective / their_reach * 0.8, 0.0, 0.95)
	chance = clampf(minf(chance, ceiling), 0.0, 0.95)
	var rng := RandomNumberGenerator.new()
	rng.seed = (hash(subject_id) * 31 + WorldHistory.next_sequence) & 0x7fffffff
	var answered := rng.randf() < chance
	strain += 0.6
	var reply := _reply_for(target, opener, answered, rng)
	return {
		"ok": answered,
		"reply": reply,
		"chance": chance,
		"routes": routes,
		"reason": "" if answered else _silence_for(target),
		"target": str(target.name),
	}


## Relations you can actually lean on for an introduction. A grudge is not one:
## somebody who hates you will not vouch for you, and an early version let a
## strength-1 grudge edge act as a reference into a Crown's inbox.
const BROKER_KINDS := ["bond", "ally", "saved", "known", "command"]
const BROKER_FLOOR := 8


## A mutual connection with less reach than the target — somebody already inside
## their network who can be leaned on. This is the intended route to a Crown.
func intermediary(subject_id: String) -> String:
	var target := account(subject_id)
	if target.is_empty():
		return ""
	var subject: Dictionary = WorldHistory.subject(subject_id)
	var their_relations: Dictionary = subject.get("relations", {})
	var mine: Dictionary = WorldHistory.subject("player").get("relations", {})
	for other in their_relations:
		if not mine.has(other):
			continue
		var broker := account(str(other))
		if broker.is_empty() or int(broker.reach) >= int(target.reach):
			continue
		var edge: Dictionary = mine[other]
		if not BROKER_KINDS.has(str(edge.get("kind", ""))):
			continue
		if int(edge.get("strength", 0)) < BROKER_FLOOR:
			continue
		return str(broker.name)
	return ""


## Something recorded about them that they would rather was not. Leverage is
## read out of real history, so it cannot be farmed — it exists because
## something happened.
func leverage(subject_id: String) -> String:
	var subject: Dictionary = WorldHistory.subject(subject_id)
	var wounds: Array = subject.get("wounds", [])
	if not wounds.is_empty():
		return WoundCatalog.label(wounds[0])
	var injury := str(subject.get("injury", "none"))
	if injury != "none" and injury != "":
		return injury
	return ""


func _silence_for(target: Dictionary) -> String:
	match str(target.tier):
		"CROWN":
			return "MESSAGE FILED. NOBODY READS THIS INBOX."
		"CIRCLE":
			return "SCREENED BY SOMEONE WHO IS NOT THEM."
		"PROMOTER":
			return "SEEN. NOT ANSWERED."
		_:
			return "NO REPLY YET."


func _reply_for(target: Dictionary, opener: String, answered: bool, rng: RandomNumberGenerator) -> String:
	if not answered:
		return ""
	if int(target.grudge) >= 30:
		var hostile := [
			"i know what you drive.",
			"come to the yard then. bring the arm you owe me.",
			"you typed. that means you are somewhere with signal. narrows it.",
		]
		return hostile[rng.randi_range(0, hostile.size() - 1)]
	match opener:
		"threaten":
			return "everyone types like that until the second time."
		"apologise":
			return "noted. does not unbreak anything."
		"offer":
			return "what have you got that is not stolen from someone i know."
		_:
			var neutral := [
				"who is this",
				"if you are selling, i am not buying, and i am not selling either.",
				"the yard is not safe this week. that is the whole message.",
				"you are the third person to ask me that today and the other two are dead.",
			]
			return neutral[rng.randi_range(0, neutral.size() - 1)]


# --- actions ---------------------------------------------------------------

## Q1.4. "Stalking a feed is a way of finding somebody in the world, not
## flavour." Most events already carry a real `location` (`bone_yard_hunt.gd`
## sets it on nearly everything it records) — this reads the most recent one
## that actually names the subject, rather than inventing a tracker. Refuses
## honestly when nobody has recorded where they were.
func locate(subject_id: String) -> Dictionary:
	for index in range(WorldHistory.events.size() - 1, -1, -1):
		var event: Dictionary = WorldHistory.events[index]
		var details: Dictionary = event.get("details", {})
		if str(details.get("location", "")).is_empty():
			continue
		var names_subject := false
		for key in ["subject", "subject_id", "target", "rival", "victim", "actor", "listener", "speaker"]:
			if str(details.get(key, "")) == subject_id:
				names_subject = true
				break
		if names_subject:
			return {"ok": true, "location": str(details.location), "from_event": str(event.get("type", "")), "sequence": int(event.get("sequence", 0))}
	return {"ok": false, "location": "", "reason": "NO RECORDED SIGHTING"}


## The active half of the social layer. Each returns a costed outcome and moves
## the player's exposure, because the design is explicit that these must never
## ship before their costs work or the whole thing reads as a toy.
func act(subject_id: String, action: String) -> Dictionary:
	var target := account(subject_id)
	if target.is_empty():
		return {"ok": false, "headline": "NO SUCH ACCOUNT", "detail": ""}
	if signal_grade < int(target.band):
		return {"ok": false, "headline": "NO ROUTE FROM HERE", "detail": "FIND A TERMINAL."}
	var rng := RandomNumberGenerator.new()
	rng.seed = (hash(subject_id + action) + WorldHistory.next_sequence) & 0x7fffffff
	var result := {"ok": true, "headline": "", "detail": "", "grudge": 0, "exposure": 0, "reach": 0}
	match action:
		"observe":
			result.headline = "WATCHING %s" % str(target.name).to_upper()
			result.detail = "%s  ·  REACH %d  ·  %s" % [str(target.role).to_upper(), int(target.reach), str(target.last_seen)]
			result["location"] = locate(subject_id)
			strain += 0.4
		"expose":
			var held := leverage(subject_id)
			if held == "":
				result.ok = false
				result.headline = "NOTHING TRUE TO PUBLISH"
				result.detail = "YOU DO NOT HAVE ANYTHING ON THEM YET."
			else:
				result.headline = "PUBLISHED AGAINST %s" % str(target.name).to_upper()
				result.detail = distort("their own people already knew about the %s" % held, 1)
				result.grudge = 22
				result.exposure = 2
				result.reach = int(float(target.reach) * -0.18)
		"fabricate":
			var holds := rng.randf() < 0.62
			result.headline = "FABRICATION PUBLISHED"
			if holds:
				result.detail = distort("it is spreading. nobody has checked it.", 2)
				result.grudge = 30
				result.exposure = 3
			else:
				result.detail = "DISPROVEN. IT CAME BACK ONTO YOUR OWN ACCOUNT."
				result.grudge = 12
				result.exposure = 5
				result.reach = -240
		"audit":
			# D2.4 v2. Pulling your own record, to check it against what you
			# actually said at intake — a real lookup at a real, if small,
			# price, not a free tooltip on your own dossier.
			result.headline = "RECORD PULLED"
			result.detail = "SOMEBODY IS GOING TO SEE THAT YOU LOOKED."
			result.exposure = 1
		"retract":
			result.headline = "RETRACTED"
			result.detail = "WALKED BACK IN PUBLIC. EVERYONE ALREADY SAW YOU SAY IT THE FIRST TIME."
			result.grudge = 6
			result.exposure = 2
		"trace":
			var pattern := rng.randi_range(0, 3)
			result.headline = "PATTERN ON %s" % str(target.name).to_upper()
			result.detail = ["POSTS BEFORE DAWN, NEAR A MAST.", "ONLY EVER POSTS AFTER A KILLING.", "SAME BACKGROUND IN EVERY IMAGE. QUARRY WALL.", "GOES QUIET WHEN THE CHOIR MOVE."][pattern]
			result.exposure = 1
			strain += 0.8
		"swarm":
			result.headline = "SWARM TURNED ONTO %s" % str(target.name).to_upper()
			result.detail = "THEIR OWN FACTION IS IN THE REPLIES. THIS ARRIVES SOMEWHERE PHYSICAL."
			result.grudge = 45
			result.exposure = 7
			result.reach = int(float(target.reach) * -0.3)
		_:
			result.ok = false
			result.headline = "UNKNOWN ACTION"
	if result.ok:
		WorldHistory.begin_ledger_batch()
		exposure += int(result.exposure)
		if int(result.grudge) != 0:
			var subject: Dictionary = WorldHistory.subject(subject_id)
			WorldHistory.update_subject(subject_id, {"grudge": int(subject.get("grudge", 0)) + int(result.grudge)}, "wire_action")
		PlayerActionLedger.record("wire_%s" % action, {"actor": "player", "subject": subject_id, "exposure": exposure})
		_accounts[subject_id]["grudge"] = int(_accounts[subject_id]["grudge"]) + int(result.grudge)
		_accounts[subject_id]["reach"] = maxi(40, int(_accounts[subject_id]["reach"]) + int(result.reach))
		WorldHistory.commit_ledger_batch()
	return result


## Reciprocity, and the reason exposure is tracked at all. Past a threshold
## somebody runs the trace back and arrives where you are.
## C3.4. A photograph posted to the Wire. This is the one publishable thing in
## the game with something real behind it — `expose` needs leverage you happen
## to hold and `fabricate` is a lie that might not stick, but a photograph
## carries the actual state of an actual body, so it always lands.
##
## Which is exactly why it is dangerous. The picture is evidence of what
## happened *and* evidence that you were standing close enough to take it, so
## the reach it earns is paid for in exposure, and everyone depicted has a new
## reason to know your name.
func publish_photograph(photo: Dictionary) -> Dictionary:
	var contents: Array = photo.get("contents", [])
	if contents.is_empty():
		return {"ok": false, "headline": "NOTHING IN FRAME", "detail": "YOU PHOTOGRAPHED AN EMPTY ROOM.", "reach": 0, "exposure": 0}
	var carnage := 0
	var named: Array[String] = []
	for entry in contents:
		var record: Dictionary = entry
		named.append(str(record.get("subject_id", "")))
		carnage += (record.get("severed", []) as Array).size() * 2
		carnage += (record.get("ruptured", []) as Array).size()
		if bool(record.get("dead", false)):
			carnage += 2
	var result := {
		"ok": true,
		"headline": "PUBLISHED / %d IN FRAME" % contents.size(),
		"detail": distort(str(photo.get("caption", "")), 1),
		"subjects": named,
		# The worse the picture, the further it travels and the worse it is for
		# you that it exists.
		"reach": 60 + carnage * 45,
		"exposure": 2 + carnage,
		"grudge": 8 + carnage * 4,
	}
	strain += 0.6 + float(carnage) * 0.2
	# Publishing and every depicted person's durable reaction are one act.
	WorldHistory.begin_ledger_batch()
	PlayerActionLedger.record("photograph_published", {
		"actor": "player",
		"photo": str(photo.get("id", "")),
		"subjects": named,
		"carnage": carnage,
		"location": str(photo.get("location", "")),
	})
	for subject_id in named:
		if subject_id == "" or subject_id == "player":
			continue
		var subject := WorldHistory.subject(subject_id)
		if subject.is_empty():
			continue
		WorldHistory.amend_subject(subject_id, {
			"grudge": mini(100, int(subject.get("grudge", 0)) + int(result.grudge)),
			"memory": "There is a picture of me like that, and everyone has seen it.",
		})
	WorldHistory.commit_ledger_batch()
	return result


func pending_trace() -> String:
	if exposure < 8:
		return ""
	var hunters := accounts_by_reach()
	hunters.sort_custom(func(a, b): return int(a.grudge) > int(b.grudge))
	for hunter in hunters:
		if str(hunter.id) == "player":
			continue
		if int(hunter.grudge) >= 25:
			traced_by = str(hunter.name)
			return traced_by
	return ""


## What spreads is not what was published. `DESIGN/HUNT_SYSTEM.md` makes this a
## rule for retellings; the Wire is the fastest carrier in the world, so it
## distorts the hardest.
func distort(text: String, hops: int) -> String:
	var swaps := {"the": "that", "already": "always", "their": "his", "nobody": "no one alive", "it": "all of it"}
	var words := text.split(" ")
	var rng := RandomNumberGenerator.new()
	rng.seed = (hash(text) + hops * 977) & 0x7fffffff
	var out: Array = []
	for word in words:
		var lower := str(word).to_lower()
		if swaps.has(lower) and rng.randf() < 0.28 * float(hops):
			out.append(str(swaps[lower]))
		else:
			out.append(str(word))
	return " ".join(out)


# --- the feed --------------------------------------------------------------

## An endless scroll that is not sorted for the reader's benefit. Real world
## history is interleaved with the register the design names — doom, wellness
## frequency mysticism, conspiracy collage, engagement bait, bots arguing with
## bots, dead forums, and somebody's lunch — because the joke and the horror are
## supposed to arrive in the same column.
const FILLER := {
	"doom": [
		"THIRD QUARRY COLLAPSE THIS MONTH. COUNCIL SAYS THE GROUND IS FINE.",
		"WATER RATION HALVED AGAIN. THE ANNOUNCEMENT WAS A PICTURE OF A LAKE.",
		"SOMETHING IS WALKING THE BURNT HIGHWAY AT NIGHT AND IT IS NOT A CONVOY.",
	],
	"wellness": [
		"your marrow has a RESONANT FREQUENCY and the masts are TUNED AGAINST IT",
		"detox protocol: no metal, no light, no talking. week one is the hardest.",
		"the spores are not the illness. the spores are the CURE ARRIVING BADLY.",
	],
	"collage": [
		"[image unavailable] 40 ARROWS POINTING AT THE SAME TOWER. TEXT IN SIX COLOURS.",
		"[image unavailable] AN EYE PASTED OVER A FAMILY PHOTOGRAPH. CAPTION: THEY KNEW IN 03.",
		"[image unavailable] A DIAGRAM CONNECTING THE CHOIR, THE RATION BOARD AND THE WEATHER.",
	],
	"bait": [
		"nobody will repost this. prove me wrong.",
		"name one thing the Board has done for you. i will wait. i have waited four years.",
		"unpopular opinion: the derby is rigged and you all know it",
	],
	"bot": [
		"AUTOMATED: your order of 1 (one) replacement femur has shipped.",
		"AUTOMATED: reply STOP to stop. AUTOMATED: reply STOP to stop.",
		"AUTOMATED: this account has been reinstated by an account that does not exist.",
	],
	"dead": [
		"last post in this forum: 4 years ago. subject: anyone else still getting through?",
		"thread locked. reason: the moderator is deceased.",
		"63 people are typing. none of them have been online since the flash.",
	],
	"lunch": [
		"found a tin with the label still on. it was peaches. i cried a bit.",
		"protein slab, third day running. it is grey and it is honest.",
	],
	"underbelly": [
		"MATCHED DONOR SET. WARM. NO QUESTIONS. TERMINAL ACCESS ONLY.",
		"we can rewrite whose side you are on. bring the bone, not the story.",
		"paying for footage of the quarry heat. the parts where it goes wrong.",
	],
}


func feed(count: int = 14, seed_offset: int = 0) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = (WorldHistory.next_sequence * 7919 + seed_offset) & 0x7fffffff
	var posts: Array = []
	var reports := WorldHistory.recent_events(6)
	var kinds := ["doom", "wellness", "collage", "bait", "bot", "dead", "lunch"]
	if signal_grade >= SIGNAL_UNDERBELLY:
		kinds.append("underbelly")
	var voices := accounts_by_reach()
	var active_voices: Array = voices.filter(func(voice: Dictionary): return float(voice.get("activity", 0.0)) > QUIET_ACTIVITY + 0.01)
	if not active_voices.is_empty():
		voices = active_voices
	var traffic := network_activity()
	var report_stride := 2 if traffic >= 0.72 else (3 if traffic >= 0.38 else 4)
	for index in count:
		# The proportion of live world reports now follows who is awake. Filler
		# never disappears—the platform is still farming attention during quiet
		# hours—but a crowded Wire carries events sooner and more often.
		if index % report_stride == 1 and not reports.is_empty():
			var event: Dictionary = reports[index % reports.size()]
			posts.append(_report_post(event, rng, voices))
			continue
		var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
		var lines: Array = FILLER[kind]
		var voice: Dictionary = voices[rng.randi_range(0, maxi(0, voices.size() - 1))] if not voices.is_empty() else {}
		posts.append({
			"kind": kind,
			"body": str(lines[rng.randi_range(0, lines.size() - 1)]),
			"author": str(voice.get("name", "UNATTRIBUTED")) if kind != "bot" else "CELLOUTZ AUTOMATION",
			"handle": str(voice.get("handle", "@unsigned")) if kind != "bot" else "@celloutz_sys",
			"reach": int(voice.get("reach", 0)),
			"verified": bool(voice.get("verified", false)) and kind != "bot",
			"band": SIGNAL_UNDERBELLY if kind == "underbelly" else SIGNAL_SURFACE,
			"replies": roundi(float(rng.randi_range(0, 340)) * lerpf(0.45, 1.55, traffic)),
		})
	return posts


func _report_post(event: Dictionary, rng: RandomNumberGenerator, _voices: Array) -> Dictionary:
	var event_type := str(event.get("type", "unknown")).replace("_", " ")
	var body := "CELLOUTZ WIRE // %s" % event_type.to_upper()
	var hops := rng.randi_range(1, 3)
	return {
		"kind": "report",
		"body": distort("%s. the yard is already telling it differently." % body, hops),
		"author": "CELLOUTZ WIRE",
		"handle": "@celloutz_wire",
		"reach": 9400,
		"verified": true,
		"band": SIGNAL_SURFACE,
		"replies": rng.randi_range(40, 900),
		"hops": hops,
	}


## The feed has teeth rather than being set dressing: reading costs attention,
## and the anatomy component can carry that the way it carries blood loss.
## Deliberately mild — the cost must be felt and must not make the Wire unusable.
func scroll(amount: float) -> float:
	strain = clampf(strain + amount * 0.35, 0.0, 100.0)
	return strain


func _handle(display_name: String) -> String:
	return "@" + display_name.to_lower().replace(" ", "_").replace("'", "")


## --- I6: the honest split on dark patterns --------------------------------
##
## The Wire is deliberately hostile and the player's own tools are deliberately
## not, and the gap between them is the joke. Nothing here is a lecture: the
## feed simply behaves the way feeds behave, and CARRY and the dossier behave
## the way a tool you own behaves, and the contrast does the work.

## Variable reward. Most pulls are filler; occasionally one carries something
## the player can act on. The schedule is intermittent on purpose, because a
## reliable feed would not be worth satirising.
const REWARD_CHANCE := 0.17
## What one more pull costs. Exposure is the currency the Wire actually takes.
const PULL_EXPOSURE := 1

var pulls := 0


## I6.1. There is no last page. `page` only moves the seed, so the feed always
## has more, and the longer the player scrolls the more of them they are
## showing to people who are watching.
func pull_feed(page: int, count: int = 14) -> Dictionary:
	pulls += 1
	var posts := feed(count, page * 977 + pulls)
	var rng := RandomNumberGenerator.new()
	rng.seed = (page * 4391 + pulls * 13) & 0x7fffffff
	var lead := {}
	if rng.randf() < REWARD_CHANCE:
		var voices := accounts_by_reach()
		if not voices.is_empty():
			var who: Dictionary = voices[rng.randi_range(0, voices.size() - 1)]
			lead = {"subject_id": str(who.get("id", "")), "name": str(who.get("name", "")), "why": "someone said where they would be"}
	# Scrolling is not free. Being in the feed is being seen in it.
	exposure += PULL_EXPOSURE
	strain = clampf(strain + 0.015, 0.0, 1.0)
	return {
		"posts": posts,
		"lead": lead,
		"exhausted": false,
		"exposure": exposure,
		"pulls": pulls,
	}


## I6.2. The contract the player's own tools keep, stated once so a panel can
## show it and so nothing drifts. CARRY, the dossier and the index are finite,
## complete, ordered and free — they never withhold, never reward at random and
## never cost you anything to open.
static func tool_contract() -> Dictionary:
	return {
		"finite": true,
		"complete": true,
		"ordered": true,
		"costs_exposure": false,
		"reward_schedule": "none",
	}


## I6.3. The same five properties for the Wire, so a panel can put the two
## side by side and let the reader draw the conclusion. This is the joke, and
## it only lands if it is legible rather than explained.
func feed_contract() -> Dictionary:
	return {
		"finite": false,
		"complete": false,
		"ordered": false,
		"costs_exposure": true,
		"reward_schedule": "intermittent",
	}
