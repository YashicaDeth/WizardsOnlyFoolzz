class_name CharacterSheet
extends RefCounted

const PlayerActionLedger := preload("res://systems/player_action_ledger.gd")

## Who you are, as data rather than as a hardcoded dictionary.
##
## D1. `bone_yard_hunt.gd` registers the player with literal values — elo 1000,
## one cybernetic, a fixed memory line — and that is the entire character
## system. Everything in `DESIGN/CHARACTER_CREATION.md` writes into this
## instead, and the rule is that nothing downstream should ever need to know
## *which route* produced a number: a preset, a random decanting, a birth chart
## and a personality questionnaire all land in the same sheet.
##
## The design's own ordering is followed here — the sheet first, because
## everything else writes into it, then traits, because every trait hooks
## machinery that already exists and is therefore the highest value per line in
## the whole section.

## Four attributes, deliberately not the usual six. They are the axes the game
## already resolves things against: how hard you hit, how fast you answer, how
## well you hold, and how the world reads you before it knows anything.
const ATTRIBUTES := ["physical", "reflex", "composure", "presence"]

## D4. Consequences of the Reset, not fantasy species. Each carries a
## silhouette hint for the rig, a metabolism, a social price, and a baseline
## pull on the Ascent/Descent axis `WorldHistory.tree_alignment()` already uses.
const RACES := {
	"decanted": {
		"name": "DECANTED", "attributes": {"physical": 0, "reflex": 0, "composure": 0, "presence": -1},
		"build": 1.0, "metabolism": "standard", "tree": 0.0,
		"note": "Vat-grown. No kin, no history, a debt in the meat.",
		"price": "Cheap to replace, and everyone knows it.",
	},
	"soft_rot": {
		"name": "SOFT ROT", "attributes": {"physical": 1, "reflex": -1, "composure": 1, "presence": -2},
		"build": 1.05, "metabolism": "spore", "tree": 0.18,
		"note": "Mycelial graft. Recovers in spore-heavy air, suffers in clean.",
		"price": "Reads as contagious to anyone who is not Communion.",
	},
	"marrow_cut": {
		"name": "MARROW-CUT", "attributes": {"physical": 2, "reflex": -1, "composure": 1, "presence": 0},
		"build": 1.12, "metabolism": "standard", "tree": -0.35,
		"note": "Bone replaced to rewrite allegiance. Durable and strong.",
		"price": "Structurally owned by somebody. They know where the bone went.",
	},
	"roadborn": {
		"name": "ROADBORN", "attributes": {"physical": 1, "reflex": 2, "composure": -1, "presence": 0},
		"build": 0.98, "metabolism": "fuel", "tree": -0.12,
		"note": "Cybernetic since childhood. Tolerant of fuel and radiation.",
		"price": "Illiterate in anything that is not a machine.",
	},
	"unreset": {
		"name": "UNRESET", "attributes": {"physical": -2, "reflex": -1, "composure": 2, "presence": 2},
		"build": 0.94, "metabolism": "frail", "tree": 0.22,
		"note": "Alive before the flash and should not be. Knows things nobody can.",
		"price": "Fragile, slow, and a target the moment anyone works it out.",
	},
	"lantern_born": {
		"name": "LANTERN-BORN", "attributes": {"physical": 0, "reflex": 0, "composure": 1, "presence": 2},
		"build": 1.0, "metabolism": "standard", "tree": 0.4,
		"note": "Gate Lantern stock, raised to the Ascent. Socially trusted.",
		"price": "Trust the Hunt System can take away, and will.",
	},
}

## D2. Project Zomboid's budget: positives cost, negatives refund. The bar for
## a trait is that it hooks a system that already exists — every one of these
## names a file it drives.
const TRAITS := {
	"hospital_strength": {
		"name": "HOSPITAL STRENGTH", "cost": 3,
		"attributes": {"physical": 2, "composure": -2},
		"note": "You do not feel the break until after.",
		"hooks": "anatomy_component: pain reported separately from health",
	},
	"no_pain_receptors": {
		"name": "NO PAIN RECEPTORS", "cost": 1,
		"attributes": {"composure": 1},
		"note": "Pain never reports, so you do not know you are bleeding out.",
		"hooks": "anatomy_component: pain suppressed, blood volume untouched",
	},
	"clerical_error": {
		"name": "CLERICAL ERROR", "cost": -2,
		"attributes": {},
		"note": "Part of your sheet is transcribed wrong. You are not told which.",
		"hooks": "the sheet itself",
	},
	"pre_owned_organs": {
		"name": "PRE-OWNED ORGANS", "cost": -1,
		"attributes": {},
		"note": "Free hardware. Somebody holds the lien and will collect.",
		"hooks": "anatomy cybernetics slots, and a debt",
	},
	"doomscroller": {
		"name": "DOOMSCROLLER", "cost": -1,
		"attributes": {"presence": 1},
		"note": "Wire strain accrues faster. Rumours reach you earlier.",
		"hooks": "wire_net: strain rate and distortion",
	},
	"famous_for_something": {
		"name": "FAMOUS FOR SOMETHING", "cost": 3,
		"attributes": {"presence": 2},
		"note": "Start with reach, and a face people recognise.",
		"hooks": "wire_net reach, witness_ledger recognition",
	},
	"speaks_when_nervous": {
		"name": "SPEAKS WHEN NERVOUS", "cost": -2,
		"attributes": {},
		"note": "Proximity voice carries further. To everyone.",
		"hooks": "proximity_voice radius",
	},
	"the_tube_stayed_in": {
		"name": "THE TUBE STAYED IN", "cost": -1,
		"attributes": {"physical": -1},
		"note": "Cosmetic, permanent, and nobody mentions it.",
		"hooks": "baseline_human rig attachment",
	},
}

## D8. Each is a real trade. The pillar that makes it work is already written
## into `DESIGN/IN_GAME_INTERNET.md`: in a world that actually had an
## apocalypse, the conspiracy poster is sometimes right. So the chip *works* —
## and the people who warned you about it were also right.
const MODIFIERS := {
	"neuralace": {
		"name": "NEURALACE", "note": "Coverage with no mast. A socket in your head.",
		"gives": "Wire signal anywhere above ground, and Crowns will answer.",
		"costs": "You can be traced, tasked, and pressed into.",
	},
	"mast_tithe": {
		"name": "THE MAST TITHE", "note": "You are on the register. The masts know you.",
		"gives": "Faster reports, cheaper contact, a map overlay.",
		"costs": "Your position is a matter of record, permanently.",
	},
	"full_schedule": {
		"name": "THE FULL SCHEDULE", "note": "Every course, on time, all of them.",
		"gives": "Spore and fuel metabolisms tolerate far more.",
		"costs": "Something in the blood answers to a frequency you did not choose.",
	},
}

const SIGNS := ["ARIES", "TAURUS", "GEMINI", "CANCER", "LEO", "VIRGO", "LIBRA", "SCORPIO", "SAGITTARIUS", "CAPRICORN", "AQUARIUS", "PISCES"]
const ELEMENTS := ["fire", "earth", "air", "water"]
const MODALITIES := ["cardinal", "fixed", "mutable"]
## Real tropical assignments. The zodiac is common property; getting it wrong
## would be the one thing Greg would notice instantly.
const SIGN_ELEMENT := ["fire", "earth", "air", "water", "fire", "earth", "air", "water", "fire", "earth", "air", "water"]
const SIGN_MODALITY := ["cardinal", "fixed", "mutable", "cardinal", "fixed", "mutable", "cardinal", "fixed", "mutable", "cardinal", "fixed", "mutable"]
## Which attribute each element feeds. Fire is force, earth is holding, air is
## speed of answer, water is how you are read.
const ELEMENT_ATTRIBUTE := {"fire": "physical", "earth": "composure", "air": "reflex", "water": "presence"}

const BASE_POINTS := 6
const BASE_ATTRIBUTE := 4

## AX1.3. Clinical on purpose. These are the words on the facility's form, and
## the facility does not editorialise -- it measures, files and moves on, which
## is more unpleasant than if it sneered.
const ANATOMY_SEX := {
	"unformed": {"name": "UNFORMED", "note": "grown without the question being asked"},
	"female": {"name": "FEMALE", "note": "grown to specification"},
	"male": {"name": "MALE", "note": "grown to specification"},
	"intersex": {"name": "INTERSEX", "note": "grown to specification; the form has no second box"},
	"reconstructed": {"name": "RECONSTRUCTED", "note": "a previous instance was altered and this one inherited it"},
}

## What the institution writes down regardless of what the body is, which is
## the same distortion AX1.4 applies to origin: your choice stays true and
## their paperwork does not have to.
const ANATOMY_SEX_FILED := {
	"unformed": "UNSPECIFIED / GROWER'S DISCRETION",
	"female": "F / STANDARD",
	"male": "M / STANDARD",
	"intersex": "F / STANDARD",
	"reconstructed": "SEE PRIOR INSTANCE",
}

var route := "preset"
var race := "decanted"
var traits: Array = []
var modifiers: Array = []
var birth := {"year": 2007, "month": 1, "day": 11, "hour": 2, "minute": 30}
var instrument: Dictionary = {}
## These choices are physical: the hunt rig reads them when it grows the body,
## so a marked, altered player is not a menu portrait that disappears on load.
var appearance: Dictionary = {"face": 0.5, "build": 0.5, "wear": 0.4, "mutation": 0.0, "ink": 0.0, "piercings": 0.0}
var under_skin: Dictionary = {"skeleton": "standard", "organs": "standard", "blood": "O-RUST", "grown_with": []}
## AX1.3. The direction doc lists "anatomical sex options" among the things
## creation has to offer, and the game had none at all -- the body was grown
## without the question being asked, which in a game about a facility growing
## you is the institution's answer rather than an absence.
##
## Written as anatomy rather than identity, because that is what the vat is
## deciding and it is the only part the facility gets a say in. `UNFORMED` is
## the default because a decanted body genuinely is: nothing was chosen for it
## yet, and choosing is the player's first act of ownership over it.
var anatomy_sex := "unformed"
## AX1.3. The face is seven named axes now, not one slider. `appearance.face`
## is still written -- derived from these -- so the body rig and every older
## reader keep working while the axes are the thing the player actually set.
var face: Dictionary = FaceModel.blank()


## Call after touching `face`. Keeps the legacy scalar the body rig reads in
## step with the axes, so the two records can never disagree.
func sync_face() -> void:
	appearance["face"] = FaceModel.scalar(face)
var display_name := "THE HUNTER"


# --- the chart (D5) --------------------------------------------------------

## Ordinary tropical sign boundaries, matching `natal_sigil.gd` so the wheel the
## player is shown and the numbers they are given cannot disagree.
func sun_sign_index() -> int:
	const CUSPS := [20, 19, 21, 20, 21, 21, 23, 23, 23, 23, 22, 22]
	var month := clampi(int(birth.get("month", 1)), 1, 12)
	var index := (month + 8) % 12
	if int(birth.get("day", 1)) >= CUSPS[month - 1]:
		index = (index + 1) % 12
	return index


func sun_sign() -> String:
	return SIGNS[sun_sign_index()]


## The rising sign, approximated by advancing one sign per two hours from
## sunrise. This is the "derived wheel" the design flags: honest, deterministic,
## and *not* an ephemeris. Real planetary longitudes remain the open decision.
func ascendant_index() -> int:
	var hour := float(birth.get("hour", 12)) + float(birth.get("minute", 0)) / 60.0
	return wrapi(sun_sign_index() + int(floor((hour - 6.0) / 2.0)), 0, 12)


func ascendant() -> String:
	return SIGNS[ascendant_index()]


## Element balance across sun, ascendant and the two signs either side of the
## sun — enough placements to produce a spread rather than a single spike, and
## to let an even chart mean something.
func element_balance() -> Dictionary:
	var balance := {"fire": 0.0, "earth": 0.0, "air": 0.0, "water": 0.0}
	var sun := sun_sign_index()
	for entry in [[sun, 2.0], [ascendant_index(), 1.5], [wrapi(sun - 1, 0, 12), 0.75], [wrapi(sun + 1, 0, 12), 0.75]]:
		var index: int = entry[0]
		balance[SIGN_ELEMENT[index]] = float(balance[SIGN_ELEMENT[index]]) + float(entry[1])
	return balance


func modality() -> String:
	return SIGN_MODALITY[sun_sign_index()]


## How fast you commit and how cheaply you change. A real mechanic against the
## Hunt System, where adaptation is the enemy's entire trick.
func commitment() -> float:
	match modality():
		"cardinal":
			return 0.85
		"fixed":
			return 1.0
		_:
			return 0.6


## The house you start the skill wheel in. `DESIGN/CHARACTER_CREATION.md` makes
## progression a walk around your own chart, so this is its entry point.
func ruling_house() -> String:
	return SIGNS[ascendant_index()]


# --- the instrument (D6) ---------------------------------------------------

## Original items on real axes. The five-factor model and the dark triad are
## scientific common property; published inventories are licensed instruments,
## so the wording here is written rather than borrowed.
const ITEMS := [
	{"text": "When something goes wrong, you assume somebody arranged it.", "axis": "machiavellianism"},
	{"text": "You have walked past someone who needed help and not thought about it again.", "axis": "psychopathy"},
	{"text": "You would rather be talked about badly than not talked about.", "axis": "narcissism"},
	{"text": "You finish what you start even when it stops being worth finishing.", "axis": "conscientiousness"},
	{"text": "Crowds leave you emptier than they found you.", "axis": "extraversion", "reverse": true},
	{"text": "You notice what a room is for before you notice who is in it.", "axis": "openness"},
	{"text": "You keep a tally of who owes you, and it is accurate.", "axis": "agreeableness", "reverse": true},
	{"text": "You sleep badly, and it is never about anything specific.", "axis": "neuroticism"},
	{"text": "Being lied to bothers you less than being lied to badly.", "axis": "machiavellianism"},
	{"text": "You have been told you are hard to read. You took it as a compliment.", "axis": "psychopathy"},
]

## The satire is in the scoring, not the questions: this is onboarding for
## something being grown to hunt people, so it reports dark-triad scores as
## *aptitudes*. A decent honest answer gets told, politely, that they are a poor
## fit — and gets decanted anyway, because the debt is already in the meat.
func score_instrument(answers: Array) -> Dictionary:
	var axes := {
		"openness": 0.0, "conscientiousness": 0.0, "extraversion": 0.0,
		"agreeableness": 0.0, "neuroticism": 0.0,
		"narcissism": 0.0, "machiavellianism": 0.0, "psychopathy": 0.0,
	}
	for index in mini(answers.size(), ITEMS.size()):
		var item: Dictionary = ITEMS[index]
		var value := clampf(float(answers[index]), 0.0, 1.0)
		if bool(item.get("reverse", false)):
			value = 1.0 - value
		axes[item.axis] = float(axes[item.axis]) + value
	instrument = axes
	return axes


func dark_triad() -> float:
	if instrument.is_empty():
		return 0.0
	var total := float(instrument.get("narcissism", 0.0)) + float(instrument.get("machiavellianism", 0.0)) + float(instrument.get("psychopathy", 0.0))
	return clampf(total / 5.0, 0.0, 1.0)


func aptitude_verdict() -> String:
	var dark := dark_triad()
	if dark > 0.66:
		return "EXCEPTIONAL FIT. WE ARE PLEASED."
	if dark > 0.33:
		return "SUITABLE. NO CONCERNS RAISED."
	return "POOR FIT FOR THE ROLE. PROCEEDING REGARDLESS."


# --- the budget (D2) -------------------------------------------------------

func points_spent() -> int:
	var spent := 0
	for trait_id in traits:
		spent += int((TRAITS.get(trait_id, {}) as Dictionary).get("cost", 0))
	return spent


func points_left() -> int:
	return BASE_POINTS - points_spent()


## N1.3. "Overspending is possible and the game lets you do it." This used to
## be the gate `toggle_trait()` enforced, which is exactly what made
## overspending impossible — kept as `is_affordable()` below for whoever
## wants to warn on a choice rather than block it.
func can_take(trait_id: String) -> bool:
	return not traits.has(trait_id) and TRAITS.has(trait_id)


func is_affordable(trait_id: String) -> bool:
	if not can_take(trait_id):
		return false
	return points_left() - int((TRAITS[trait_id] as Dictionary).get("cost", 0)) >= 0


func toggle_trait(trait_id: String) -> bool:
	if traits.has(trait_id):
		traits.erase(trait_id)
		return true
	if not can_take(trait_id):
		return false
	traits.append(trait_id)
	return true


# --- N2: broken runs, honestly labelled ------------------------------------

## N2.4. Derived from the numbers a player actually chose, never an authored
## "these traits are broken together" list — overspending on the same budget
## every honest build respects is already the whole signal. Set to 1 rather
## than something larger: today's roster only has two cost-3 traits and one
## cost-1, so the maximum overspend reachable at all is 1 (take every
## positive-cost trait, refund none of it) — a higher threshold would make
## `is_broken_build()` unreachable rather than rare. Revisit upward as D8
## grows the trait list.
const BROKEN_OVERSPEND_THRESHOLD := 1


func overspent_by() -> int:
	return maxi(0, -points_left())


func is_broken_build() -> bool:
	return overspent_by() >= BROKEN_OVERSPEND_THRESHOLD


# --- the numbers everything else reads -------------------------------------

## Attributes, assembled from every route at once. Nothing downstream should
## have to know whether a point came from a race, a chart or a checkbox.
func attributes() -> Dictionary:
	var values := {}
	for key in ATTRIBUTES:
		values[key] = float(BASE_ATTRIBUTE)
	var race_data: Dictionary = RACES.get(race, RACES.decanted)
	for key in (race_data.get("attributes", {}) as Dictionary):
		values[key] = float(values[key]) + float((race_data.attributes as Dictionary)[key])
	# The chart contributes as a *distribution*, not a bonus: a heavy element
	# makes a specialist and an even chart makes a generalist with no peak.
	var balance := element_balance()
	var total := 0.0
	for element in balance:
		total += float(balance[element])
	for element in balance:
		var attribute: String = ELEMENT_ATTRIBUTE[element]
		values[attribute] = float(values[attribute]) + (float(balance[element]) / maxf(1.0, total)) * 5.0 - 1.25
	for trait_id in traits:
		for key in ((TRAITS.get(trait_id, {}) as Dictionary).get("attributes", {}) as Dictionary):
			values[key] = float(values[key]) + float(((TRAITS[trait_id] as Dictionary).attributes as Dictionary)[key])
	if not instrument.is_empty():
		# The questionnaire is load-bearing: answering it honestly and decently
		# costs you presence in a world that rewards the other thing.
		values["presence"] = float(values["presence"]) + dark_triad() * 2.0 - 0.5
		values["composure"] = float(values["composure"]) + float(instrument.get("neuroticism", 0.0)) * -0.4
	for key in values:
		values[key] = snappedf(clampf(float(values[key]), 1.0, 12.0), 0.1)
	return values


## Where this character sits on the Ascent/Descent axis before they have done
## anything. Race sets a baseline; the dark triad drags it down.
func tree_pull() -> float:
	var pull := float((RACES.get(race, RACES.decanted) as Dictionary).get("tree", 0.0))
	pull -= dark_triad() * 0.35
	if modifiers.has("neuralace"):
		pull -= 0.08
	return clampf(pull, -1.0, 1.0)


## Starting Wire reach. The ascendant decides how the world reads you before it
## knows anything, which is exactly what reach already models.
func starting_reach() -> int:
	var reach := 40 + int(attributes().get("presence", 4.0) * 26.0)
	if traits.has("famous_for_something"):
		reach += 900
	if modifiers.has("mast_tithe"):
		reach += 180
	return reach


# --- D1.2: everything writes into it ---------------------------------------

## The one place the sheet becomes the world's idea of the player. This replaces
## the hardcoded dictionary in `bone_yard_hunt.gd`.
func apply_to_world() -> Dictionary:
	var values := attributes()
	var race_data: Dictionary = RACES.get(race, RACES.decanted)
	var grown: Array = (under_skin.get("grown_with", []) as Array).duplicate()
	if traits.has("pre_owned_organs"):
		grown.append("pre-owned liver (lien held)")
	if traits.has("the_tube_stayed_in"):
		grown.append("feed tube, never removed")
	var state := {
		"name": display_name,
		"kind": "person",
		"role": str(race_data.get("name", "DECANTED")).capitalize() + " survivor",
		"faction": "Unbound",
		"elo": 1000,
		"grudge": 0,
		"status": "awake",
		"memory": "The derby door opened into Limbo.",
		"wounds": [],
		"attributes": values,
		"race": race,
		"traits": traits.duplicate(),
		"modifiers": modifiers.duplicate(),
		"birth": birth.duplicate(),
		"sun_sign": sun_sign(),
		"ascendant": ascendant(),
		"ruling_house": ruling_house(),
		"modality": modality(),
		"commitment": commitment(),
		"tree_pull": tree_pull(),
		"reach_seed": starting_reach(),
		"instrument": instrument.duplicate(),
		# D. What you chose to look like was collected on the sheet and then
		# never filed, so the body could not read it even in principle.
		"appearance": appearance.duplicate(),
		# N2.1/N2.2. Marked at creation, in the game's own register rather
		# than an error state — an overspent build reads as a run the game
		# already knows is broken, not a mistake nobody flagged.
		"broken_run": is_broken_build(),
		"overspent_by": overspent_by(),
		"anatomy": {
			"blood_type": str(under_skin.get("blood", "O-RUST")),
			"skeleton": str(under_skin.get("skeleton", "standard")),
			# Named `organ_set`, not `organs`, and the rename is the whole fix
			# for a crash rather than tidiness. `anatomy.organs` is a Dictionary
			# of live organ states everywhere else in the game — in
			# `anatomy_component.gd`, `extraction.gd`, `kill_cam.gd`,
			# `downed_resolution.gd` and the body inspector — and this is a
			# String naming which organ set you were decanted with. Two
			# different things under one key in one dictionary: the moment the
			# player had a sheet, the index's BODY page read "standard" where it
			# required a Dictionary and threw from inside `_draw`, every frame,
			# in the index and in the device both.
			"organ_set": str(under_skin.get("organs", "standard")),
			"cybernetics": grown,
		},
		"relations": {},
	}
	# D2.3. The handler wrote one field down wrong and does not mention it. The
	# sheet the world holds disagrees with the sheet you filled in, which is
	# §13's pillar pointed at the player's own record.
	if traits.has("clerical_error"):
		state = _mistranscribe(state)
	# D8.5 v2. D8.4 made declining a modifier the harder road, and the intake
	# scene gives a decline its own beat (D8.3) — but that beat plays once,
	# in the tank, and nothing after it ever knew you had taken the harder
	# road. A modifier absent from `modifiers` reads identically whether it
	# was actively refused or simply never offered; there was no fact
	# anywhere that distinguished "chose the hard way" from "there was no
	# choice". Recorded the same way N2.2 acknowledges an overspent build —
	# a real event in the world's own register — so it surfaces wherever
	# anything else naming the player does, `world_index.gd`'s FILE page
	# included, with no new UI required.
	var declined: Array = []
	for key in MODIFIERS.keys():
		if not modifiers.has(str(key)):
			declined.append(str(key))
	state["declined_modifiers"] = declined
	# Filing is one intake decision even when it also creates the subject,
	# records declined modifications and opens a broken achievement run.
	WorldHistory.begin_ledger_batch()
	WorldHistory.amend_subject("player", state)
	PlayerActionLedger.record("sheet_filed", {
		"actor": "player", "subject_id": "player", "changes": state.duplicate(true),
	})
	if not declined.is_empty():
		WorldHistory.record_event("modifiers_declined", {"subject": "player", "declined": declined})
	# N2.2. Achievement-run register, not an error dialog: the event names
	# the run broken and says so by how much, in the same voice as any other
	# record the world keeps.
	if bool(state.get("broken_run", false)):
		WorldHistory.record_event("achievement_run_started", {"overspent_by": int(state.get("overspent_by", 0))})
	WorldHistory.commit_ledger_batch()
	return state


func _mistranscribe(state: Dictionary) -> Dictionary:
	var wrong := state.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(display_name + str(birth)) & 0x7fffffff
	# D2.4 v2. Which field and what it actually was, kept rather than thrown
	# away once the wrong value overwrites it — CLERICAL ERROR was previously
	# undiscoverable in principle, because nothing anywhere still held the
	# true answer to check the sheet against. Nested under its own key rather
	# than surfaced as a top-level field, so reading the dossier normally
	# still shows only the wrong sheet; something has to go looking, and
	# `world_index.gd`'s AUDIT action is what that costs.
	var field := ""
	var true_value: Variant = null
	match rng.randi_range(0, 3):
		0:
			var values: Dictionary = wrong["attributes"]
			var key: String = ATTRIBUTES[rng.randi_range(0, ATTRIBUTES.size() - 1)]
			field = "attributes.%s" % key
			true_value = values[key]
			values[key] = snappedf(maxf(1.0, float(values[key]) + rng.randf_range(-2.0, 2.0)), 0.1)
		1:
			field = "sun_sign"
			true_value = wrong["sun_sign"]
			wrong["sun_sign"] = SIGNS[rng.randi_range(0, 11)]
		2:
			field = "anatomy.blood_type"
			true_value = (wrong["anatomy"] as Dictionary)["blood_type"]
			(wrong["anatomy"] as Dictionary)["blood_type"] = ["A-ASH", "B-9", "AB-", "SAP", "NULL"][rng.randi_range(0, 4)]
		_:
			field = "race"
			true_value = wrong["race"]
			wrong["race"] = RACES.keys()[rng.randi_range(0, RACES.size() - 1)]
	wrong["transcription"] = "unverified"
	wrong["clerical_error"] = {"field": field, "true_value": true_value, "discovered": false}
	return wrong


## Restores a sheet from what the world holds. D1.3 — the sheet survives a
## reload because it lives in `WorldHistory` like everything else.
func load_from_world() -> bool:
	var state: Dictionary = WorldHistory.subject("player")
	if state.is_empty() or not state.has("race"):
		return false
	display_name = str(state.get("name", display_name))
	race = str(state.get("race", race))
	traits = (state.get("traits", []) as Array).duplicate()
	modifiers = (state.get("modifiers", []) as Array).duplicate()
	birth = (state.get("birth", birth) as Dictionary).duplicate()
	instrument = (state.get("instrument", {}) as Dictionary).duplicate()
	var anatomy: Dictionary = state.get("anatomy", {})
	under_skin["blood"] = str(anatomy.get("blood_type", "O-RUST"))
	under_skin["skeleton"] = str(anatomy.get("skeleton", "standard"))
	# Reads the new key, and falls back to the old one only when what is under
	# it is actually a String — a subject saved before the rename carries the
	# sheet's spelling, one saved after may legitimately carry the simulation's
	# Dictionary there, and `str()` of that would load a body as garbage.
	var legacy_organs: Variant = anatomy.get("organs", "standard")
	under_skin["organs"] = str(anatomy.get("organ_set",
		legacy_organs if legacy_organs is String else "standard"))
	under_skin["grown_with"] = (anatomy.get("cybernetics", []) as Array).duplicate()
	return true


## The decanting lottery. The vat gives you what it gives you.
##
## Found while proving N2 with a fixed seed: `pool.shuffle()` used to run
## here, and `Array.shuffle()` draws from Godot's *global* RNG, not this
## function's own seeded one — so the same seed produced a different build
## depending on how much global random state other systems had already
## burned through before this ran, not reproducibly at all. Each trait is
## rolled independently regardless of order, so the shuffle was never doing
## anything but that; removed rather than reimplemented.
func randomise(seed_value: int = 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else Time.get_ticks_msec()
	route = "random"
	race = RACES.keys()[rng.randi_range(0, RACES.size() - 1)]
	traits.clear()
	for trait_id in TRAITS.keys():
		if rng.randf() < 0.45:
			toggle_trait(str(trait_id))
	birth = {
		"year": rng.randi_range(1998, 2012), "month": rng.randi_range(1, 12),
		"day": rng.randi_range(1, 28), "hour": rng.randi_range(0, 23), "minute": rng.randi_range(0, 59),
	}
	under_skin["blood"] = ["O-RUST", "A-ASH", "B-9", "AB-", "SAP", "UNKNOWN"][rng.randi_range(0, 5)]
	# AX1.3. A random face, not random numbers. FaceModel correlates the skull
	# axes so RANDOM produces a person rather than seven unrelated sliders,
	# and the derived scalar keeps `appearance.face` honest for the body rig.
	face = FaceModel.randomise(rng)
	appearance["face"] = FaceModel.scalar(face)
