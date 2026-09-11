class_name Clinch
extends RefCounted

## F7. Having hold of somebody is a conversation you are winning, not just a
## wrestling match.
##
## The checklist calls this the highest value per line of code in the whole
## list, and the reason is that nothing here is new — it is four built systems
## being introduced to each other. The clinch already tracks advantage. The
## anatomy already tracks pain and consciousness. `WorldHistory` already tracks
## bond, grudge and, since E1.1, what you have actually done. `Extraction`
## already knows how to take a part off a body. This is the table that turns
## those four numbers into what a held person will and will not give you.
##
## The part worth stating plainly, because it is the design rather than a
## balance choice: **the two ladders do different social work.** A player deep
## on Descent is frightening, and fear is leverage — threats land, compliance
## comes fast, and every ounce of it is bought with more grudge. A player on
## Ascent is trusted, and trust is the other kind of leverage — they will
## actually listen, and what they give is given rather than taken. Someone in
## Limbo has neither and has to rely on the hold itself.
##
## So the same grip produces a different scene depending on who is doing the
## gripping, which is what `DESIGN/RITUAL_AND_KARMA.md` means by the axis
## having consequences rather than being a slider.

## Below this nothing is on offer — they are not held well enough to be talking
## to you at all.
const MINIMUM_HOLD := 0.15
## A successful persuasion writes this much debt, which is what
## `_accepts_recruitment` reads later in the downed window (F7.3).
const PERSUADED_DEBT := 12.0


## How much of a grip you have, before either ladder is applied. Advantage is
## the hold; pain and fading consciousness are what the hold has cost them.
static func hold_strength(advantage: float, anatomy: Dictionary) -> float:
	var pain := clampf(float(anatomy.get("pain", 0.0)) / 100.0, 0.0, 1.0)
	var fading := 1.0 - clampf(float(anatomy.get("consciousness", 100.0)) / 100.0, 0.0, 1.0)
	return clampf(clampf(advantage, -1.0, 1.0) * 0.55 + pain * 0.25 + fading * 0.2, 0.0, 1.0)


## What they will give up to make you stop. Fear does this work, so a player who
## has been executing people on the ground is better at it — and it costs
## goodwill every time.
static func coercion(advantage: float, anatomy: Dictionary, subject: Dictionary, karma: float) -> float:
	var dread := maxf(0.0, -clampf(karma, -1.0, 1.0)) * 0.3
	var defiance := clampf(float(subject.get("grudge", 0)) / 100.0, 0.0, 1.0) * 0.2
	return clampf(hold_strength(advantage, anatomy) + dread - defiance, 0.0, 1.0)


## What they will give you willingly. Trust does this work, so it runs off the
## other end of the axis, and an existing bond counts for more than the grip.
static func persuasion(advantage: float, anatomy: Dictionary, subject: Dictionary, karma: float) -> float:
	var standing := maxf(0.0, clampf(karma, -1.0, 1.0)) * 0.3
	var bond := clampf(float(subject.get("bond", 0)) / 100.0, 0.0, 1.0) * 0.35
	var hatred := clampf(float(subject.get("grudge", 0)) / 100.0, 0.0, 1.0) * 0.4
	return clampf(hold_strength(advantage, anatomy) * 0.6 + standing + bond - hatred, 0.0, 1.0)


## Everything the hold currently affords, as one answer the UI and the input
## handler can both read rather than each deciding for themselves.
static func options(advantage: float, anatomy: Dictionary, subject: Dictionary, karma: float) -> Dictionary:
	var hold := hold_strength(advantage, anatomy)
	var threat := coercion(advantage, anatomy, subject, karma)
	var talk := persuasion(advantage, anatomy, subject, karma)
	return {
		"hold": hold,
		"coercion": threat,
		"persuasion": talk,
		# You can always try to take something off someone you are holding; the
		# question is only whether they can stop you.
		"rob": hold >= MINIMUM_HOLD,
		"persuade": hold >= MINIMUM_HOLD,
		"threaten": hold >= MINIMUM_HOLD,
		# They give up rather than be put down. This is the outcome that feeds
		# the downed window with somebody who is not simply unconscious.
		"surrender": threat >= 0.8 or talk >= 0.8,
	}


## Talking. What comes back is a decision plus the record changes that go with
## it, so the caller writes them once rather than each caller inventing its own
## idea of what being persuaded does to a person.
static func persuade(subject: Dictionary, advantage: float, anatomy: Dictionary, karma: float) -> Dictionary:
	var talk := persuasion(advantage, anatomy, subject, karma)
	if hold_strength(advantage, anatomy) < MINIMUM_HOLD:
		return {"accepted": false, "reason": "You do not have enough of them to be talking.", "line": ""}
	if talk < 0.45:
		# Refusing is not neutral. You had hold of them and they said no.
		return {
			"accepted": false,
			"reason": "They will not hear it.",
			"line": "Do it or let go. I am not owed to you.",
			"grudge": 4,
		}
	return {
		"accepted": true,
		"reason": "They will owe you for letting go.",
		"line": "Alright. Alright. Ask me somewhere that is not here.",
		"consent": talk >= 0.7,
		"debt": PERSUADED_DEBT * talk,
		"bond": 6 if talk >= 0.7 else 3,
	}


## Leaning on them. Fast, reliable where persuasion is not, and it buys the
## compliance with a grudge that outlives the hold — which is the machinery
## F2 will later propagate along the relation graph.
static func threaten(subject: Dictionary, advantage: float, anatomy: Dictionary, karma: float) -> Dictionary:
	var threat := coercion(advantage, anatomy, subject, karma)
	if hold_strength(advantage, anatomy) < MINIMUM_HOLD:
		return {"accepted": false, "reason": "They are not held well enough to care.", "line": ""}
	if threat < 0.4:
		return {
			"accepted": false,
			"reason": "They are not frightened of you.",
			"line": "You are not the worst thing that has had hold of me.",
			"grudge": 6,
		}
	return {
		"accepted": true,
		"reason": "They give it up to make you stop.",
		"line": "Take it. Take it and get off me.",
		"yields": true,
		"grudge": 9 + roundi(threat * 8.0),
		"karma": -0.04,
	}
