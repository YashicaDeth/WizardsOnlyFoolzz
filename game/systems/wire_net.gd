class_name WireNet
extends RefCounted

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
	var tier := _tier_for(reach)
	return {
		"id": subject_id,
		"name": str(subject.get("name", subject_id)),
		"handle": _handle(str(subject.get("name", subject_id))),
		"faction": str(subject.get("faction", "Unbound")),
		"faction_id": str(subject.get("faction_id", "")),
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
		"last_seen": _last_seen(subject_id, subject),
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
func _last_seen(subject_id: String, subject: Dictionary) -> String:
	var status := str(subject.get("status", "")).to_lower()
	if status in ["active", "following", "hunting", "awake"]:
		return "ONLINE NOW"
	if status in ["roaming", "cultivating", "waiting"]:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(subject_id) & 0x7fffffff
		return "%d MIN AGO" % rng.randi_range(3, 240)
	if status in ["dead", "downed", "executed"]:
		return "LAST POST STANDS"
	return "%d DAYS AGO" % ((hash(subject_id) & 0x7f) % 900 + 4)


func accounts_by_reach() -> Array:
	var listing: Array = []
	for key in _accounts:
		var account: Dictionary = _accounts[key]
		if int(account.band) > signal_grade:
			continue
		listing.append(account)
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
## a dead ranked subject leaves a genuine vacancy, which is
## `DESIGN/HUNT_SYSTEM.md`'s promotion mechanic surfaced as a view before the
## promotion itself is built. The presentation is original: a faction hierarchy
## is nobody's property, but another game's specific way of drawing one is.
const RANKS := ["CROWN", "INNER CIRCLE", "PROMOTER", "EARNER", "INTAKE"]


func pyramid(faction_id: String) -> Dictionary:
	var faction: Dictionary = WorldHistory.subject(faction_id)
	var members: Array = []
	for key in _accounts:
		var account: Dictionary = _accounts[key]
		if str(account.faction_id) == faction_id:
			members.append(account)
	members.sort_custom(func(a, b): return int(a.influence) > int(b.influence))
	var tiers: Array = []
	for index in RANKS.size():
		tiers.append({"rank": RANKS[index], "members": [], "buy_in": int(pow(3.0, float(RANKS.size() - index)) * 40.0)})
	for member in members:
		var slot := 0
		var influence := int(member.influence)
		if influence >= 70:
			slot = 0
		elif influence >= 45:
			slot = 1
		elif influence >= 25:
			slot = 2
		elif influence >= 10:
			slot = 3
		else:
			slot = 4
		tiers[slot]["members"].append(member)
	# Downline is what the pitch is actually selling, so it is counted honestly:
	# everybody strictly beneath you in your own faction.
	var running := 0
	for index in range(tiers.size() - 1, -1, -1):
		tiers[index]["downline"] = running
		running += (tiers[index]["members"] as Array).size()
	var vacancies: Array = []
	for index in tiers.size():
		if (tiers[index]["members"] as Array).is_empty() and index < RANKS.size() - 1:
			var claimant := _claimant(tiers, index)
			vacancies.append({"rank": RANKS[index], "claimant": claimant})
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
		return str(wounds[0])
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
		exposure += int(result.exposure)
		if int(result.grudge) != 0:
			var subject: Dictionary = WorldHistory.subject(subject_id)
			WorldHistory.update_subject(subject_id, {"grudge": int(subject.get("grudge", 0)) + int(result.grudge)}, "wire_action")
		WorldHistory.record_event("wire_%s" % action, {"subject": subject_id, "exposure": exposure})
		_accounts[subject_id]["grudge"] = int(_accounts[subject_id]["grudge"]) + int(result.grudge)
		_accounts[subject_id]["reach"] = maxi(40, int(_accounts[subject_id]["reach"]) + int(result.reach))
	return result


## Reciprocity, and the reason exposure is tracked at all. Past a threshold
## somebody runs the trace back and arrives where you are.
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
	for index in count:
		# Roughly one post in three is the world actually reporting on itself.
		# The rest is what the platform would rather you read.
		if index % 3 == 1 and not reports.is_empty():
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
			"replies": rng.randi_range(0, 340),
		})
	return posts


func _report_post(event: Dictionary, rng: RandomNumberGenerator, voices: Array) -> Dictionary:
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
