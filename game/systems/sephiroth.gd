class_name Sephiroth
extends RefCounted

## AV. Ten sephiroth plus the one that is not on the map, and four worlds as
## the registers each is seen in — DESIGN/COSMOLOGY.md: "Malkuth is 3D and the
## game is played there; the wizard eyes are 4D; the godhead is past Keter."
##
## Nothing here invents the godhead fight (K v3-v10, unbuilt elsewhere) or the
## authored art/shader pass (AV1.5-AV1.7 — the shader `FINAL_V.md` §16 names
## sits as 21 uncommitted files in a different worktree entirely and is out of
## scope until that lands somewhere real). What this builds is the ladder
## itself, the one mechanic Greg called load-bearing ("the higher you have to
## be to talk or even fight, conjure, evoke etc"), and the memory contract —
## AV1.1-AV1.4, AV2.1-AV2.5, AV3.1.
##
## Altitude is deliberately not a new persisted field: `WorldHistory` fields
## belong to Lane 4 alone (AGENT_SPLIT_6.md), and a decaying level-plus-
## timestamp pair is exactly the shape `WorldHistory.chaos_magick()` already
## uses without adding one. Altitude here goes a step further and needs no
## stored field at all — it is a pure read of events `substances.gd` and
## `meditation.gd` already record (`substance_taken`, `meditation_ended`,
## `meditation_interrupted`), decayed by real elapsed time since each one.
## "The substance decides which door opens, not a menu" (AV2.2) falls out of
## that for free: there is no function here that raises altitude directly,
## only one that reads what already happened.

const SubstancesTable := preload("res://systems/substances.gd")

## AV1.1. Ten sephiroth, ordered low to high, each a real place with its own
## tradition name. `order` is also what AV2's floors scale against — Malkuth
## needs no altitude at all ("the game is played there"); Keter needs nearly
## all of it.
const PLANES := {
	"malkuth": {"name": "Malkuth", "order": 0, "role": "The Kingdom — Ashbloom itself, the only plane you did not have to leave your body to reach"},
	"yesod": {"name": "Yesod", "order": 1, "role": "The Foundation — where a signal is still just a signal, before it means anything"},
	"hod": {"name": "Hod", "order": 2, "role": "Splendour — the ledgers, the paperwork of the world made visible as a place"},
	"netzach": {"name": "Netzach", "order": 3, "role": "Victory — want, want, want, with a face on it"},
	"tiferet": {"name": "Tiferet", "order": 4, "role": "Beauty — the one register everything else is judged against"},
	"gevurah": {"name": "Gevurah", "order": 5, "role": "Severity — every debt this world has ever written down, held at once"},
	"chesed": {"name": "Chesed", "order": 6, "role": "Mercy — the wash `AscentEntities` prices, seen from where it is minted"},
	"binah": {"name": "Binah", "order": 7, "role": "Understanding — the dark, fertile womb-register; grief with a structure to it"},
	"chokmah": {"name": "Chokmah", "order": 8, "role": "Wisdom — a raw signal with no channel narrow enough to carry it yet"},
	"keter": {"name": "Keter", "order": 9, "role": "The Crown — the last real address before the godhead, which has none"},
}

## AV1.3. Real, unmapped, unreachable on purpose — where the deliriants go.
## Present in the data (it is a real place a subject can be registered as)
## but never in `reachable_planes()`, `floor_requirement()` or `petition()`.
const DAATH := "daath"

## AV1.2. Four worlds as *registers* on top of the planes above, not a second
## set of planes — the same Malkuth reads differently depending which of
## these it is seen through. `valence` is what makes AV1.6 true without a
## second art set: hellscape and angelscape are the same `describe()` call
## with the world's own valence flipping the register, not two assets.
const WORLDS := {
	"assiah": {"name": "Assiah", "role": "Action — matter, cost, the body paying for what it reaches", "valence": "material"},
	"yetzirah": {"name": "Yetzirah", "role": "Formation — image before object, the register a vision arrives in", "valence": "infernal"},
	"beriah": {"name": "Beriah", "role": "Creation — where an intention first has a shape at all", "valence": "celestial"},
	"atziluth": {"name": "Atziluth", "role": "Emanation — nearest the source; almost nothing survives being seen this close", "valence": "celestial"},
}

## AV2.1. Four rising floors, as a multiplier against a plane's own order —
## Malkuth's floors are all 0 (you are already standing in it); Keter's
## "fight" floor clamps at 100, which is deliberately unreachable by ordinary
## means, matching AV2.4's "not a difficulty setting."
const FLOOR_BASE_PER_ORDER := 9.0
const FLOOR_MULTIPLIER := {
	"see": 1.0,
	"talk": 1.3,
	"conjure": 1.7,
	"fight": 2.2,
}
const FLOOR_ORDER := ["see", "talk", "conjure", "fight"]

## AV2.5's "sustaining is its own problem": altitude decays on its own once
## nothing is feeding it, same half-life shape `WorldHistory.chaos_magick()`
## uses. In real elapsed milliseconds (`Time.get_ticks_msec()`, what
## `record_event()` actually stamps each event with) rather than game-world
## minutes: events carry no `world_minute` field, and `WorldHistory` fields
## belong to Lane 4 alone, so this reads the timestamp that already exists
## instead of asking for a new one. The one honest cost of that choice: ticks
## reset to near-zero on every process restart, so altitude effectively
## resets toward 0 across a save/reload rather than persisting mid-trip —
## which reads as correct for "how high are you right now" (nobody expects to
## reload a save still mid-dose) rather than as a bug, but is named here
## rather than left implicit.
const ALTITUDE_HALF_LIFE_MSEC := 12.0 * 60.0 * 1000.0
## How much of a substance's own `consciousness_cost` (`substances.gd`)
## becomes altitude. Above 1 on purpose: a single door-substance (18-26 cost)
## should clear "talk" outright, matching "the substance decides which door
## opens" — reading the menu is not the gate, taking the thing is.
const ALTITUDE_PER_CONSCIOUSNESS_COST := 1.4
## Meditation is the slow, safe route (`meditation.gd`'s own framing:
## "cannot be rushed") — a full `ENTITY_THRESHOLD_SECONDS` (60s) hold reaches
## exactly "talk", same tier a single dose of the weaker door-substance does,
## for no body cost at all, over triple the time.
const ALTITUDE_PER_MEDITATION_SECOND := 0.5


## AV1.1/AV1.3. Every real, mapped, reachable place — Da'ath is not a return
## value error, it is real data (`plane(DAATH)` returns a row), it is simply
## never in this list.
static func reachable_planes() -> Array:
	var ids := PLANES.keys()
	ids.sort_custom(func(a, b): return int(PLANES[a].order) < int(PLANES[b].order))
	return ids


static func plane(plane_id: String) -> Dictionary:
	if plane_id == DAATH:
		return {"name": "Da'ath", "order": -1, "role": "Knowledge — real, and not on any chart that names the other ten", "daath": true}
	return PLANES.get(plane_id, {})


## AV1.4's "a licence to depart" needs a departure floor too, so it is not
## folded silently into the entry cost.
static func floor_requirement(plane_id: String, floor_name: String) -> float:
	if plane_id == DAATH or not PLANES.has(plane_id):
		return INF
	var order := float(PLANES[plane_id].order)
	var multiplier := float(FLOOR_MULTIPLIER.get(floor_name, 1.0))
	return clampf(order * FLOOR_BASE_PER_ORDER * multiplier, 0.0, 100.0)


## AV1.2/AV1.6. The same plane, read through one of the four worlds. Not a
## second description authored per plane per world (40 of them) — the base
## role plus the register's own valence, which is the mechanism AV1.5/AV1.7
## defer the actual art to, not a replacement for it.
static func perceive(plane_id: String, world_id: String) -> Dictionary:
	var base := plane(plane_id)
	if base.is_empty():
		return {}
	var world: Dictionary = WORLDS.get(world_id, {})
	if world.is_empty():
		return base
	var valence := str(world.get("valence", "material"))
	var tone := "seen plainly, as weight and consequence"
	if valence == "infernal":
		tone = "seen as debt, as teeth, as a bill coming due"
	elif valence == "celestial":
		tone = "seen as light with no source, and a voice that is patient about it"
	return {
		"name": str(base.name), "role": str(base.role), "world": str(world.name),
		"tone": tone, "daath": bool(base.get("daath", false)),
	}


## AV2. Pure function over events `substances.gd`/`meditation.gd` already
## record — nothing here writes anything, nothing here is a stored field.
static func altitude(subject_id: String) -> float:
	var now := Time.get_ticks_msec()
	var total := 0.0
	for event in WorldHistory.events:
		var details: Dictionary = event.get("details", {})
		# Not `WorldHistory.event_actor()` — that reads `details.actor`,
		# defaulting to "player" when absent, and neither `substance_taken`
		# nor `meditation_ended` sets it. Both do set `subject_id`, which is
		# the field this actually needs to filter on.
		if str(details.get("subject_id", "")) != subject_id:
			continue
		var event_type := str(event.get("type", ""))
		var contribution := 0.0
		if event_type == "substance_taken":
			var substance_id := str(details.get("substance_id", ""))
			var data: Dictionary = SubstancesTable.CATALOG.get(substance_id, {})
			contribution = float(data.get("consciousness_cost", 0.0)) * ALTITUDE_PER_CONSCIOUSNESS_COST
		elif event_type == "meditation_ended" or event_type == "meditation_interrupted":
			contribution = float(details.get("held_seconds", 0.0)) * ALTITUDE_PER_MEDITATION_SECOND
		if contribution <= 0.0:
			continue
		var elapsed := maxf(float(now) - float(event.get("time_msec", now)), 0.0)
		total += contribution * pow(0.5, elapsed / ALTITUDE_HALF_LIFE_MSEC)
	return clampf(total, 0.0, 100.0)


static func has_floor(subject_id: String, plane_id: String, floor_name: String) -> bool:
	return altitude(subject_id) >= floor_requirement(plane_id, floor_name)


## AV1.4. The petition verb: a name, a seal, an offering, paid through
## `Boons.pay()` (the one real body/standing ledger every other cost in this
## project already spends against) — never a travel action. Refuses outright
## on Da'ath (AV1.3) and on an unreachable "see" floor before a single credit
## is spent.
static func petition(subject_id: String, plane_id: String, seal: String, offering_kind: String, offering_amount: float, offering_target: String = "") -> Dictionary:
	if plane_id == DAATH or not PLANES.has(plane_id):
		return {"ok": false, "reason": "NOT ON ANY CHART THAT NAMES THE OTHER TEN"}
	if seal.is_empty():
		return {"ok": false, "reason": "A PETITION WITH NO SEAL IS NOISE"}
	if not has_floor(subject_id, plane_id, "see"):
		return {"ok": false, "reason": "NOT HIGH ENOUGH TO BE SEEN YET"}
	# AV3.5. Every creditor collects the moment you set foot anywhere, before
	# the offering for *this* plane is even weighed — so you cannot visit the
	# plane you can afford while dodging the one you cannot. A default here
	# does not block the petition; it just means you arrive owing more and
	# audible to fewer of them (`PlaneVoices.clarity()`).
	var collected := PlaneVoices.collect_due(subject_id)
	var payment := Boons.pay(subject_id, offering_kind, offering_amount, offering_target)
	if not bool(payment.get("ok", false)):
		return payment
	WorldHistory.record_event("plane_petitioned", {
		"subject_id": subject_id, "plane_id": plane_id, "seal": seal,
		"offering_kind": offering_kind, "offering_amount": offering_amount,
		"altitude_at_petition": altitude(subject_id),
	})
	# AV3.2. The trip is now on the record; fold it into what this plane
	# remembers about the subject.
	PlaneVoices.remember(plane_id, subject_id)
	return {"ok": true, "plane_id": plane_id, "collected": collected}


## AV1.4's other half. A real cost to leave, same ledger, so "a licence to
## depart" is a fact about the body and not a phrase.
static func depart(subject_id: String, plane_id: String, offering_kind: String, offering_amount: float, offering_target: String = "") -> Dictionary:
	if plane_id == DAATH or not PLANES.has(plane_id):
		return {"ok": false, "reason": "NOT A PLACE YOU COULD HAVE BEEN"}
	var payment := Boons.pay(subject_id, offering_kind, offering_amount, offering_target)
	if not bool(payment.get("ok", false)):
		return payment
	WorldHistory.record_event("plane_departed", {"subject_id": subject_id, "plane_id": plane_id})
	PlaneVoices.remember(plane_id, subject_id)
	return {"ok": true}


## AV2.3. "Coming down mid-conversation is a real failure and the entity
## remembers it." Called by whatever is holding a `talk`/`conjure`/`fight`
## interaction open on its own clock — refuses and records the failure the
## moment altitude has actually dropped below the floor that action needed,
## rather than only checking once at the start.
static func sustain_or_fail(subject_id: String, plane_id: String, floor_name: String) -> Dictionary:
	if has_floor(subject_id, plane_id, floor_name):
		return {"ok": true}
	WorldHistory.record_event("plane_altitude_failed", {
		"subject_id": subject_id, "plane_id": plane_id, "floor": floor_name,
		"altitude_at_failure": altitude(subject_id),
	})
	# AV3.2/AV2.3. The entity remembers the fall, and it costs more standing
	# than a clean trip ever earned.
	PlaneVoices.remember(plane_id, subject_id)
	return {"ok": false, "reason": "CAME DOWN MID-%s" % floor_name.to_upper()}


## AV3.1. Registers every reachable plane as a real `WorldHistory` subject —
## same shape `AscentEntities.seed_entities()` already uses for the order's
## lower ranks, kept as a distinct table rather than merged into `ENTITIES`
## since a plane is a place with a voice, not one of that order's personified
## ranks. Da'ath is deliberately not registered here either: nothing should
## be able to ask WorldHistory about a relationship with a place that is not
## on the map.
static func register_planes() -> void:
	for plane_id in reachable_planes():
		var data: Dictionary = PLANES[plane_id]
		WorldHistory.register_subject(plane_id, {
			"name": str(data.name), "kind": "plane", "role": str(data.role),
			"order": int(data.order), "relations": {},
		})
