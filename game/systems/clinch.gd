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

## B6.1. A grip is made of arms. So is a gun.
##
## Until this pass the clinch was a pure number: advantage in, hold out, and the
## only anatomy it read was the *held* person's pain and consciousness. That is
## the right reading of what the hold costs **them** — but it left out what the
## hold is **made of**, so a player with one arm on the floor held people exactly
## as well as a player with two. The grip went around the anatomy instead of
## through it.
##
## Everything below resolves both jobs against the same zones `apply_hit`
## already damages, which is the whole of B6.1: a limb is a limb whichever job
## you give it, an arm that has been ruined is ruined for both, and an arm
## committed to one of them is not available for the other.
const GRIP_LIMBS: Array[String] = ["left_arm", "right_arm"]

## `AnatomyComponent.DEFAULT_ZONES.left_arm.health`. Named here rather than
## imported because this class stays a `RefCounted` that takes plain snapshot
## dictionaries — it never needs the component itself, and a test can hand it a
## hand-built body.
const ARM_HEALTH := 65.0

## Under this an arm cannot be committed to anything. It is still attached and
## still hurts; it will not close on a person or hold a weapon down.
const LIMB_USABLE := 0.18

## What a broken arm is still worth. A compound fracture does not stop a limb
## gripping, it stops it gripping *well* — the structure is what failed, and the
## hand on the end of it still closes.
const FRACTURED_GRIP := 0.45

## The second hand is worth less than the first. Two hands on somebody is a
## better hold than one, but it is not twice the hold, and the difference
## between one arm and none is far larger than between two and one.
const SECOND_HAND := 0.45


## B6.2. What one arm can still do, from the zone the anatomy actually tracks.
##
## Zero has two spellings and both mean the same thing to a grip: a zone at or
## below zero health is disabled, and a zone that is *missing from the
## dictionary altogether* has been taken off the body — `Extraction` removes it,
## and a limb that is no longer there is not holding anybody. This is the line
## that makes B6.2 true, and it is one comparison rather than a severance flag,
## because the anatomy already says it.
static func limb_condition(holder: Dictionary, limb: String) -> float:
	var zones: Dictionary = holder.get("zones", {})
	if not zones.has(limb):
		return 0.0
	var zone: Dictionary = zones[limb]
	var health := float(zone.get("health", 0.0))
	if health <= 0.0:
		return 0.0
	var ratio := clampf(health / ARM_HEALTH, 0.0, 1.0)
	if not str(zone.get("fracture", "")).is_empty():
		ratio *= FRACTURED_GRIP
	return ratio


## Both arms at once, so a caller that wants to draw them does not ask twice.
static func limb_grip(holder: Dictionary) -> Dictionary:
	var out := {}
	for limb in GRIP_LIMBS:
		out[limb] = limb_condition(holder, limb)
	return out


## The arms that can still be given a job — gripping or shooting, the test is
## the same one.
static func usable_limbs(holder: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for limb in GRIP_LIMBS:
		if limb_condition(holder, limb) >= LIMB_USABLE:
			out.append(limb)
	return out


## How much hold this body is capable of, before any of it is applied to a
## person. An empty `holder` is a body nobody described, and it reads as whole —
## the older two-argument callers were written before arms were part of this and
## must keep answering what they answered then.
static func grip_capacity(holder: Dictionary) -> float:
	if holder.is_empty():
		return 1.0
	var arms: Array = limb_grip(holder).values()
	arms.sort()
	arms.reverse()
	if arms.is_empty() or float(arms[0]) <= 0.0:
		return 0.0
	var best := float(arms[0])
	var second := float(arms[1]) if arms.size() > 1 else 0.0
	# Normalised against two whole arms, so a whole body reads exactly 1.0
	# and one arm reads the fraction it actually is. Summing and clamping
	# instead put both at the ceiling, which said a one-armed player grips
	# as well as a whole one — the precise thing this segment exists to stop.
	return clampf((best + second * SECOND_HAND) / (1.0 + SECOND_HAND), 0.0, 1.0)


## B6.1. The arms left over once the grip has taken what it needs. A hand on
## somebody is not on a weapon; this is the whole of "limbs that shoot **and**
## grapple" rather than two systems that each assume they have the body.
static func free_limbs(holder: Dictionary, committed: Array) -> Array[String]:
	var out: Array[String] = []
	for limb in usable_limbs(holder):
		if not committed.has(limb):
			out.append(limb)
	return out


## Whether anything can be fired while this hold is on. A one-armed player who
## has that arm around somebody's throat has made a choice, and this is where
## the choice costs them.
static func can_shoot(holder: Dictionary, committed: Array) -> bool:
	return not free_limbs(holder, committed).is_empty()


## How well, which is not the same question. One good arm still points a weapon;
## it does not hold it down, and a broken one does neither well.
static func gun_steadiness(holder: Dictionary, committed: Array) -> float:
	var free := free_limbs(holder, committed)
	if free.is_empty():
		return 0.0
	var conditions: Array[float] = []
	for limb in free:
		conditions.append(limb_condition(holder, limb))
	conditions.sort()
	conditions.reverse()
	var best := conditions[0]
	var second := conditions[1] if conditions.size() > 1 else 0.0
	return clampf(best * 0.7 + second * 0.3, 0.0, 1.0)


## How much of a grip you have, before either ladder is applied. Advantage is
## the hold; pain and fading consciousness are what the hold has cost them.
static func hold_strength(advantage: float, anatomy: Dictionary, holder: Dictionary = {}) -> float:
	var pain := clampf(float(anatomy.get("pain", 0.0)) / 100.0, 0.0, 1.0)
	var fading := 1.0 - clampf(float(anatomy.get("consciousness", 100.0)) / 100.0, 0.0, 1.0)
	var grip := clampf(clampf(advantage, -1.0, 1.0) * 0.55 + pain * 0.25 + fading * 0.2, 0.0, 1.0)
	# B6.2. The arms are a ceiling on the hold, not a term added to it.
	# Somebody unconscious and in agony is still not being held by a body
	# that has nothing left to hold them with.
	return clampf(grip * grip_capacity(holder), 0.0, 1.0)


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
static func options(advantage: float, anatomy: Dictionary, subject: Dictionary, karma: float, holder: Dictionary = {}, committed: Array = GRIP_LIMBS) -> Dictionary:
	var hold := hold_strength(advantage, anatomy, holder)
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
	# B6.1. What the body has left while this is going on. `committed`
	# defaults to both arms because the hold in this game is a two-handed
	# one until something says otherwise; hand it one limb and the other
	# stays free to fire, which is the choice the segment is about.
	"grip_capacity": grip_capacity(holder),
	"limbs": limb_grip(holder),
	"free_limbs": free_limbs(holder, committed),
	"shoot": can_shoot(holder, committed),
	"steadiness": gun_steadiness(holder, committed),
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
