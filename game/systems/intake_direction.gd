class_name IntakeDirection
extends RefCounted

## D3.4 and D8.3. How the intake is *delivered*, kept apart from what the intake
## collects.
##
## The scene was built and then left undirected. The handler cycled six lines on
## a flat five-second timer no matter what you were doing, so he said the same
## things in the same order whether you had just picked a race, been
## mistranscribed, or signed a socket into your own skull. That is a script
## being read out, not a person working near you.
##
## Two things live here:
##
## - **Delivery** (D3.4). What he says is chosen by what just happened, and how
##   long he holds before the next line depends on what he just did. The pause
##   after taking something out of you is not the pause after ticking a box.
## - **Procedures** (D8.3). Each opt-in modifier is an authored beat rather than
##   a checkbox that silently sets a flag — he does the thing to you, on camera,
##   and says what it costs while he does it. Declining gets its own beat,
##   because D8.4 makes refusing the harder road and it should feel chosen.
##
## Everything is data. `vat_intake.gd` plays it; it does not decide it.

## What he does to you when you sign for one, as a run of beats. `shot` is the
## camera the scene should be on: the tank, his hands, the clipboard, or your
## own face in the swing-arm mirror.
const PROCEDURES := {
	"neuralace": [
		{"line": "Tilt. This one goes in behind the ear, and you'll feel the cold before the rest.", "hold": 3.0, "shot": "close"},
		{"line": "There. You'll hear the masts before you hear people. Everyone says that.", "hold": 3.2, "shot": "tank"},
		{"line": "Signed for. If a Crown calls, you answer. That's the whole of it.", "hold": 2.6, "shot": "clipboard"},
	],
	"mast_tithe": [
		{"line": "Thumb on the plate. It wants a print and a bit of the blood under it.", "hold": 2.8, "shot": "close"},
		{"line": "You're on the register now. Reports come faster. So do the people reading them.", "hold": 3.0, "shot": "clipboard"},
		{"line": "Where you are is a matter of record. Permanently. That's not a threat, it's the form.", "hold": 3.2, "shot": "mirror"},
	],
	"full_schedule": [
		{"line": "Every course, on time, all of them. Hold out the arm you like least.", "hold": 3.0, "shot": "close"},
		{"line": "Spore and fuel will stop bothering you. Mostly.", "hold": 2.6, "shot": "tank"},
		{"line": "Something in the blood answers to a frequency now. Not mine. Don't ask me whose.", "hold": 3.4, "shot": "mirror"},
	],
}

## Refusing is the harder road (D8.4), so it is a beat rather than silence.
const DECLINES := {
	"neuralace": {"line": "Suit yourself. You'll be deaf out there and you'll find out where.", "hold": 2.6, "shot": "clipboard"},
	"mast_tithe": {"line": "Off the register. Nobody comes when you shout, then.", "hold": 2.6, "shot": "clipboard"},
	"full_schedule": {"line": "Unmedicated. The air out there is not going to negotiate.", "hold": 2.8, "shot": "clipboard"},
}

## Delivery, by what just happened rather than by rota. `hold` is how long he
## sits with it before saying anything else — the pause is the performance.
const LINES := {
	"idle": [
		{"line": "Don't try to talk. Blink once for yes. I'll know.", "hold": 4.5},
		{"line": "Right. Intake. This is the bit where you become a number.", "hold": 4.2},
		{"line": "Debt's already in the meat, so the form's a formality.", "hold": 4.8},
		{"line": "I've done four hundred of these. Four hundred and one.", "hold": 4.0},
	],
	"page": [
		{"line": "Next sheet. Try to keep up, you're the one in the tank.", "hold": 3.0},
		{"line": "This part they actually read. Sometimes.", "hold": 3.2},
	],
	"chose": [
		{"line": "Noted.", "hold": 2.0},
		{"line": "Fine. That's what I'll put.", "hold": 2.2},
		{"line": "Nod if you understand. Not like that. Fine, I'll put yes.", "hold": 3.0},
	],
	"slipped": [
		{"line": "...that's what you said, isn't it. Near enough.", "hold": 3.6},
		{"line": "You'd be amazed how many of these come back wrong.", "hold": 3.8},
		{"line": "It's down now. Can't be helped, not in ink.", "hold": 4.0},
	],
	"refused": [
		{"line": "No budget. You get what the vat gave you.", "hold": 3.0},
	],
	# Greg, first launch (2026-09-24): you should be able to answer his
	# straightforward questions. You cannot speak -- the tube is in -- so every
	# answer is something a body in a tank can actually do.
	"ask": [
		{"line": "You awake in there? Blink once for yes.", "hold": 3.0, "answers": ["BLINK ONCE", "BLINK TWICE", "STARE"]},
		{"line": "Any pain? One blink yes, two no. Doesn't change anything, it's just a box.", "hold": 3.4, "answers": ["BLINK ONCE", "BLINK TWICE", "STARE"]},
		{"line": "Can you read the form from in there? Blink.", "hold": 3.0, "answers": ["BLINK ONCE", "BLINK TWICE", "STARE"]},
	],
	"stared": [
		{"line": "Staring is not an answer. I'll put yes.", "hold": 2.6},
		{"line": "Right. Unresponsive. That's a box too.", "hold": 2.6},
	],
	# V: thinking out loud. The tube is in, but the pickup on the tank is not
	# fussy about what counts as speech.
	"heard": [
		{"line": "Was that you? Tube's in, you can't -- never mind.", "hold": 3.0},
		{"line": "Thinking loud again. The mic picks that up, you know.", "hold": 3.0},
		{"line": "Keep that to yourself. It's all recorded.", "hold": 2.8},
	],
	# D4.6 v2. Race was data the world read — build factor, metabolism,
	# social price, the Tree pull — and the intake never once said so out
	# loud. He has an opinion on every one of these, because a man who has
	# processed four hundred bodies has seen this exact one before.
	"race_decanted": [
		{"line": "Vat-grown, straight down the middle. Don't take it personal, everyone in this room is.", "hold": 3.6},
	],
	"race_soft_rot": [
		{"line": "Spore graft. Keep that quiet near the Ossuary crowd, they'll clock it before you sit down.", "hold": 3.8},
	],
	"race_marrow_cut": [
		{"line": "Somebody rewrote your bones to buy your allegiance. Somebody still holds the receipt for that.", "hold": 3.8},
	],
	"race_roadborn": [
		{"line": "Cyber since you were small enough to fit the rig. You'll read a bumper better than a face.", "hold": 3.8},
	],
	"race_unreset": [
		{"line": "Before the flash. I have processed four hundred of these and never once had one admit it.", "hold": 4.0},
	],
	"race_lantern_born": [
		{"line": "Gate Lantern stock, raised to the Ascent. That'll open doors up top and close them in the Yard.", "hold": 3.8},
	],
}


## One line, chosen for the moment. Deterministic per moment so a scene plays
## the same way twice if nothing the player did was different.
static func line_for(context: String, moment: int) -> Dictionary:
	var pool: Array = LINES.get(context, LINES.idle)
	var chosen: Dictionary = pool[abs(moment) % pool.size()]
	return chosen.duplicate()


## The run of beats for signing, or the single beat for refusing.
static func procedure(modifier_id: String, accepted: bool) -> Array:
	if not accepted:
		var refusal: Dictionary = DECLINES.get(modifier_id, {})
		return [refusal.duplicate()] if not refusal.is_empty() else []
	var beats: Array = PROCEDURES.get(modifier_id, [])
	var out: Array = []
	for beat in beats:
		out.append((beat as Dictionary).duplicate())
	return out


## How long the whole procedure takes, so the caller can hold input for exactly
## as long as the scene is playing and no longer.
static func duration(beats: Array) -> float:
	var total := 0.0
	for beat in beats:
		total += float((beat as Dictionary).get("hold", 2.5))
	return total
