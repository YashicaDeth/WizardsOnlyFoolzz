class_name ContactEntities
extends RefCounted

## AU5/AV. Who is on the other side of the door, and what a storyboard artist
## needs in order to draw them.
##
## AT already establishes the rule: *you do not get to the planes except through
## the brain, and the drugs are the only thing you can reach without
## permission.* That makes a door substance the one unpermitted entrance in the
## game - and until now it opened onto nothing. `Substances._glimpse_one()`
## picked a random `AscentEntities` id, which are the wizardsonlyfoolz lower
## ranks: an org chart, not an encounter. This file is the encounter.
##
## **Not a second mythology.** These are not new gods and they do not outrank
## anything in `cosmology_factions.gd`. They are what the low planes look like
## from inside a brain that got in without a key, which is why they are all
## *doing something already* and none of them are waiting for you. The one rule
## that governs every entry: **nothing here has a quest.** An entity that hands
## out objectives is a vendor with a costume.
##
## Sourcing note for whoever picks this up: the visual grammar below comes from
## the documented phenomenology of altered perception - the standard taxonomy of
## effect (drifting, tracers, symmetry, recursion, autonomous entity contact) -
## used the way a painter uses anatomy. It is deliberately *not* a description
## of how to obtain or take anything, and the substances it hangs off are this
## world's inventions, not real compounds.

## The perceptual vocabulary. Every entity names which of these it arrives
## through, so its appearance is built out of effects the rig can already do
## rather than being a model that fades in. This is the AU5 taxonomy in code.
const CHANNELS := {
	"drift": "Surfaces breathe, flow and morph without changing what they are",
	"tracer": "Motion leaves a decaying afterimage behind it",
	"symmetry": "The frame folds onto itself - mirrors, tiling, rosettes",
	"recursion": "A shape contains a smaller copy of the shape",
	"acuity": "Detail sharpens past what the eye can really resolve",
	"depth": "Distance stops agreeing with size",
	"colour": "Hue rotates independently of what is lit",
	"cut": "The frame drops a beat and comes back wrong",
	"autonomy": "Something in the frame is moving on its own intent",
}

## `autonomy` is the one that matters and the one that is hardest to earn. A
## pattern is not an entity. The line this file draws: an entity has **its own
## attention** - it can notice you, and it can decline to.
const CONTACT_FLOOR := 0.62

## The catalogue. Storyboard fields are deliberately concrete - `form`, `does`,
## `regard`, `leaves` - because "an indescribable presence" is not something
## anybody can draw, and every entry here has to survive being drawn.
const CATALOG := {
	"the_lattice_weavers": {
		"label": "The Lattice Weavers",
		"register": "machine elves",
		"substance": "choir_bloom",
		"phase": "peak",
		"channels": ["symmetry", "recursion", "acuity", "autonomy"],
		"form": "Hands, mostly. Too many, jointed wrong, working at a loom that is also the room's own tiling. They are made of the pattern they are making, so they only exist where the symmetry is - step out of the fold and there is nobody there.",
		"does": "Weaving, at speed, and showing you what they are weaving. They are proud of it. They want you to look at the work, not at them.",
		"regard": "Delighted and completely uninterested in you personally. They will hand you things. The things do not exist afterwards.",
		"leaves": "The conviction that you were shown something enormous and the total inability to say what. Files a record with no content (AT2.4).",
		"threat": 0.0,
		"storyboard": "Frame is already folded before they arrive. They come out of the fold lines, not through the air. Never show one against a flat wall.",
	},
	"the_jester_that_counts": {
		"label": "The Jester That Counts",
		"register": "jester",
		"substance": "choir_bloom",
		"phase": "trails",
		"channels": ["tracer", "cut", "autonomy", "depth"],
		"form": "One figure, motley made of the afterimages of itself, so it is always several frames of one movement at once. The face is the only part that does not trail, and it is always already looking at you.",
		"does": "Counting. Out loud, in a number system that is not base ten, and the count is of something about you. It gets things right that it should not know.",
		"regard": "Amused, and the amusement is at your expense. It is the only entity in the catalogue that addresses you directly.",
		"leaves": "A number. The number means nothing and the player will spend the rest of the run looking for what it counts.",
		"threat": 0.35,
		"storyboard": "Its trail is the character. Animate the trail first and the body second. When it stops moving it should almost vanish.",
	},
	"the_horned_auditor": {
		"label": "The Horned Auditor",
		"register": "baphomet",
		"substance": "static_hymn",
		"phase": "peak",
		"channels": ["depth", "cut", "autonomy", "colour"],
		"form": "Seated, patient, horned, and scaled wrong - it reads as both very close and very large, and the frame cannot settle which. Goat in the head and something clerical in the posture. A ledger open on its knee.",
		"does": "Reading your ledger. Actually yours - `world_history.gd`'s record of what you have done. It finds a real entry and holds a finger on it.",
		"regard": "Neutral to the point of insult. It is not judging you, it is reconciling you, and it does not care about the outcome.",
		"leaves": "One event from the player's real history, surfaced. That is the whole payload and it is enough.",
		"threat": 0.5,
		"storyboard": "Never move the camera toward it. It should get closer without getting bigger. The horns are the last thing the frame resolves.",
	},
	"the_carrier_choir": {
		"label": "The Carrier Choir",
		"register": "faceless / numbers station",
		"substance": "static_hymn",
		"phase": "trails",
		"channels": ["cut", "tracer", "colour"],
		"form": "Not figures. A row of mouths at the edge of the frame, in the static, opening in sequence. You never see what they are attached to.",
		"does": "Broadcasting. The same sequence, endlessly, in a voice that is several voices agreeing exactly.",
		"regard": "None. They have not noticed you and will not. This is the entry that proves autonomy is not the same as attention.",
		"leaves": "A frequency. `wire_radio.gd` can carry it, which makes this the only contact with a consequence outside the trip (Lane 4 owns that field - ask).",
		"threat": 0.15,
		"storyboard": "Peripheral only. The instant it is centred in frame it should be gone.",
	},
	"the_one_in_the_marrow": {
		"label": "The One In The Marrow",
		"register": "body horror / hypnagogic",
		"substance": "marrow_dust",
		"phase": "peak",
		"channels": ["drift", "depth", "autonomy"],
		"form": "Your own body, from inside, with something else using it. The hands move a half beat before you move them.",
		"does": "Nothing dramatic. Ordinary movements, slightly early. It is the only entity that is not elsewhere.",
		"regard": "It does not regard you. It is you, with the authorship moved.",
		"leaves": "A stretch of input where the game moved your hands first (AD - Lane 1 owns the motor, so this is an ask, not a reach).",
		"threat": 0.65,
		"storyboard": "No new model. The existing first-person arms, animated on a lead. The horror is entirely in the timing.",
	},
}

## AV. Which plane a contact belongs to. Kept separate from the entry so that
## the plane can be renamed without rewriting five storyboards, and so
## `the_planes` work (AV, unbuilt) has something real to attach to.
const PLANE_OF := {
	"the_lattice_weavers": "the_weave",
	"the_jester_that_counts": "the_weave",
	"the_horned_auditor": "the_ledger_floor",
	"the_carrier_choir": "the_dead_band",
	"the_one_in_the_marrow": "no_plane_at_all",
}


static func all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entity_id: String in CATALOG:
		var entry: Dictionary = (CATALOG[entity_id] as Dictionary).duplicate(true)
		entry["id"] = entity_id
		entry["plane"] = str(PLANE_OF.get(entity_id, ""))
		out.append(entry)
	return out


static func find(entity_id: String) -> Dictionary:
	if not CATALOG.has(entity_id):
		return {}
	var entry: Dictionary = (CATALOG[entity_id] as Dictionary).duplicate(true)
	entry["id"] = entity_id
	entry["plane"] = str(PLANE_OF.get(entity_id, ""))
	return entry


## Everything a given substance can open onto, in the phase it opens there.
static func for_substance(substance_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in all():
		if str(entry.get("substance", "")) == substance_id:
			out.append(entry)
	return out


## Whether this dose reaches contact at all, and with whom.
##
## Contact is not guaranteed by taking a door substance - that would make an
## entity a purchase, which is the one thing E5 says they are not. It needs the
## dose to actually be deep enough, and it is deterministic per subject, dose
## count and substance so a save is reproducible and a test does not have to
## seed anything.
static func contact_for(subject_id: String, substance_id: String, tolerance: int, potency: float = 1.0) -> Dictionary:
	var candidates := for_substance(substance_id)
	if candidates.is_empty():
		return {}
	var depth := clampf(potency, 0.0, 2.0) * maxf(0.35, 1.0 - float(tolerance) * 0.08)
	if depth < CONTACT_FLOOR:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = (hash(subject_id + substance_id + "contact") + tolerance * 6151) & 0x7fffffff
	return candidates[rng.randi() % candidates.size()]


## AU4/AT2.4. A contact files itself, the way every drug experience does. What
## the record carries is what the entity *left* - never a summary of the
## encounter, because a summary of an encounter is the thing the player is
## supposed to be unable to produce.
static func record(subject_id: String, entity_id: String, substance_id: String) -> Dictionary:
	var entry := find(entity_id)
	if entry.is_empty():
		return {"ok": false, "reason": "NO SUCH CONTACT"}
	var met: Array = (WorldHistory.subject(subject_id).get("contacts", []) as Array).duplicate()
	var already := false
	for raw in met:
		if str((raw as Dictionary).get("id", "")) == entity_id:
			already = true
	if not already:
		met.append({"id": entity_id, "plane": str(entry.get("plane", "")), "first_through": substance_id})
	WorldHistory.begin_ledger_batch()
	WorldHistory.amend_subject(subject_id, {"contacts": met})
	WorldHistory.record_event("contact_made", {
		"subject_id": subject_id, "entity_id": entity_id,
		"substance_id": substance_id, "plane": str(entry.get("plane", "")),
		"first_time": not already,
	})
	WorldHistory.commit_ledger_batch()
	return {"ok": true, "entity": entry, "first_time": not already}
