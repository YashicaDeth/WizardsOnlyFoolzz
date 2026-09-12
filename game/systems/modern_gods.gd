class_name ModernGods
extends RefCounted

## AJ3/AJ5. "The gods of this world are what is actually worshipped: markets,
## metrics, engagement, brands... if you kill some people permanently you get
## told by the gods if killing them was a good thing or if you forced them
## back into samsara." — Greg, captured in CHECKLIST.md.
##
## The rule that keeps AJ5 from being a morality score, stated once so every
## verdict function below actually holds it: **the gods disagree with each
## other, and they are not reliable.** A verdict is one god's opinion, marked
## as whose, never summed into a single score.
##
## AJ5.2's two poles reuse the Ascent/Descent axis this file did not invent —
## `WorldHistory.tree_alignment()` already exists and already means "how far
## toward corruption or ascent a subject has drifted." As above so below,
## applied to death itself: ending a life deep in Descent reads as freeing it
## from what it had become; ending one that was climbing reads as forcing it
## back into the cycle before it finished. Each god then reads the same real
## number through its own institutional obsession (AJ5.3: how, where, by
## whose hand, what they carried), which is where the disagreement in AJ5.4
## comes from for free rather than needing four separately-authored opinions.
##
## AJ3.2: each god is a real WorldHistory subject with `attention`, on the
## same shape `ascent_entities.gd` already proved — not a flavour label.
## AJ1 (sigils naming a god to get their attention) is not built here; this
## is what it would eventually call into, same relationship ritual_app.gd
## has to the seals it doesn't draw.

const GODS := {
	"the_engagement": {
		"name": "The Engagement", "domain": "attention, virality, being seen",
		"memory": "Does not care what happened. Cares how many people watched it happen.",
	},
	"the_market": {
		"name": "The Market", "domain": "price, scarcity, value extracted",
		"memory": "Has never once called a death a death. Calls it a write-down.",
	},
	"the_quota": {
		"name": "The Quota", "domain": "production targets, labor, throughput",
		"memory": "Measures a life in units completed, not years lived.",
	},
	"the_brand": {
		"name": "The Brand", "domain": "image, reputation, consistency of message",
		"memory": "Only ever asks one question: does this play well.",
	},
}

const FREED := "SOUL FREED"
const ENSLAVED := "CYCLICIST ENSLAVEMENT AGAIN"


static func seed_gods() -> void:
	for god_id in GODS:
		var data: Dictionary = GODS[god_id]
		WorldHistory.register_subject(god_id, {
			"name": str(data.name), "kind": "god", "role": str(data.domain),
			"threat": "NONE", "status": "watching", "memory": str(data.memory),
			"attention": 0, "relations": {},
		})


## AJ3.4. Attention is not spent the way AscentEntities' notice is (there is
## no equivalent wash() here yet — AJ1 does not exist to spend it on) — it
## only ever accumulates, because a god noticing you is not something this
## world lets you undo.
static func get_attention(god_id: String, amount: int = 1) -> int:
	var god := WorldHistory.subject(god_id)
	if str(god.get("kind", "")) != "god":
		return 0
	var attention := int(god.get("attention", 0)) + amount
	WorldHistory.amend_subject(god_id, {"attention": attention})
	return attention


## AJ5.1/AJ5.3. One god's opinion on one permanent death, computed from the
## victim's own real alignment (AJ5.2's two poles) and the kill's own recorded
## circumstance rather than an authored line per god.
##
## `details` reads whatever the resolution actually recorded: `witnessed`
## (a count, for The Engagement), `harvested` (bool, a part was taken, for
## The Market), `contracted` (bool, a bounty or debt drove it, for The
## Quota), `public` (bool, done somewhere it would be seen, for The Brand).
## Anything missing defaults to false/0 rather than guessing.
static func verdict(god_id: String, victim_id: String, details: Dictionary = {}) -> Dictionary:
	var god := WorldHistory.subject(god_id)
	if str(god.get("kind", "")) != "god":
		return {}
	var victim := WorldHistory.subject(victim_id)
	if victim.is_empty():
		return {}
	# Base lean: dying deep in Descent reads as a release; dying while still
	# climbing Ascent reads as cut short. Limbo deaths start with no lean at
	# all, so a god's own bias is the whole story rather than a rounding error.
	var alignment := WorldHistory.tree_alignment(victim)
	var lean := -alignment
	match god_id:
		"the_engagement":
			lean += 0.25 if int(details.get("witnessed", 0)) >= 3 else -0.1
		"the_market":
			lean += 0.3 if bool(details.get("harvested", false)) else -0.2
		"the_quota":
			lean += 0.3 if bool(details.get("contracted", false)) else -0.15
		"the_brand":
			lean += 0.2 if bool(details.get("public", false)) else -0.15
	lean = clampf(lean, -1.0, 1.0)
	var label := FREED if lean > 0.0 else ENSLAVED
	if is_zero_approx(lean):
		label = "UNDECIDED — EVEN %s HAS NO OPINION" % str(god.get("name", god_id)).to_upper()
	get_attention(god_id, 1)
	return {
		"god": str(god.get("name", god_id)), "god_id": god_id, "victim": victim_id,
		"label": label, "lean": lean,
	}


## AJ5.4/AJ5.7. Two verdicts on one death is the normal outcome, never summed
## into a score — each is recorded as its own opinion, attributed to its own
## god, so the Board (L) can pin them as the disagreement they are rather
## than an averaged number.
static func record_death_verdicts(victim_id: String, killer_id: String, details: Dictionary, god_ids: Array = []) -> Array:
	var asked: Array = god_ids
	if asked.is_empty():
		asked = GODS.keys()
	var results: Array = []
	for god_id in asked:
		var result := verdict(str(god_id), victim_id, details)
		if result.is_empty():
			continue
		results.append(result)
		WorldHistory.record_event("death_verdict", {
			"victim_id": victim_id, "killer_id": killer_id, "god_id": str(god_id),
			"label": result.label, "lean": result.lean,
		})
	return results
