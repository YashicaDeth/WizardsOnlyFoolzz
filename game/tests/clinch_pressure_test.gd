extends Node

## O5.5. "Held and hurt is the pressure that makes recruitment possible."
##
## This one was already built — by F7, before O5 was written down — so the point
## of this test is not to prove new code works. It is to prove the chain
## actually connects end to end before the checklist claims it does, because a
## tick on an item nobody verified is worth nothing.
##
## The chain: pain and fading consciousness feed hold_strength, which feeds both
## persuasion and coercion, which decide whether a clinch produces consent,
## which is what the downed-resolution window reads when it asks whether
## somebody will actually join you.

const Clinch := preload("res://systems/clinch.gd")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _ready() -> void:
	print("O5.5 - held and hurt")
	var fresh := {"pain": 0.0, "consciousness": 100.0}
	var hurt := {"pain": 70.0, "consciousness": 100.0}
	var fading := {"pain": 70.0, "consciousness": 25.0}
	var nobody := {"bond": 0, "grudge": 0}

	var grip_fresh: float = Clinch.hold_strength(0.4, fresh)
	var grip_hurt: float = Clinch.hold_strength(0.4, hurt)
	var grip_fading: float = Clinch.hold_strength(0.4, fading)

	_check(grip_hurt > grip_fresh, "the same grip on a hurt body is a stronger hold (%.2f vs %.2f)" % [grip_hurt, grip_fresh])
	_check(grip_fading > grip_hurt, "and stronger again as they lose consciousness (%.2f)" % grip_fading)

	# Held but unhurt is a weaker position than hurt but barely held.
	var tight_on_fresh: float = Clinch.hold_strength(0.9, fresh)
	var loose_on_hurt: float = Clinch.hold_strength(0.1, fading)
	_check(tight_on_fresh > 0.0 and loose_on_hurt > 0.0, "both are real positions")
	_check(absf(tight_on_fresh - loose_on_hurt) < 0.35, "a bad grip on a broken body is close to a good grip on a whole one (%.2f vs %.2f)" % [tight_on_fresh, loose_on_hurt])

	# Persuasion rises with the hold.
	var talk_fresh: float = Clinch.persuasion(0.4, fresh, nobody, 0.0)
	var talk_hurt: float = Clinch.persuasion(0.4, fading, nobody, 0.0)
	_check(talk_hurt > talk_fresh, "somebody hurt is more persuadable (%.2f vs %.2f)" % [talk_hurt, talk_fresh])

	# And so does what they will give up to make it stop.
	var fear_fresh: float = Clinch.coercion(0.4, fresh, nobody, 0.0)
	var fear_hurt: float = Clinch.coercion(0.4, fading, nobody, 0.0)
	_check(fear_hurt > fear_fresh, "and more coercible (%.2f vs %.2f)" % [fear_hurt, fear_fresh])

	# A grudge resists both, so hurting somebody is not a universal solvent.
	var enemy := {"bond": 0, "grudge": 90}
	_check(Clinch.persuasion(0.4, fading, enemy, 0.0) < talk_hurt, "somebody who hates you resists being talked round")

	# The seam that makes this section true: enough hold produces consent, and
	# consent is what recruitment reads.
	var weak: Dictionary = Clinch.persuade(nobody, 0.05, fresh, 0.0)
	_check(not bool(weak.get("accepted", true)), "too little of them and there is nothing to talk about")

	var strong: Dictionary = Clinch.persuade({"bond": 40, "grudge": 0}, 0.95, fading, 0.6)
	_check(bool(strong.get("accepted", false)), "enough of them and they will hear it")
	_check(bool(strong.get("consent", false)), "and past the threshold it produces consent, which is what recruitment needs")
	_check(float(strong.get("debt", 0.0)) > 0.0, "plus a debt that outlives the hold")

	# Refusal is not neutral: you had hold of them and they said no.
	var refused: Dictionary = Clinch.persuade({"bond": 0, "grudge": 95}, 0.5, hurt, -0.5)
	_check(not bool(refused.get("accepted", true)), "somebody who will not hear it, does not")
	_check(int(refused.get("grudge", 0)) > 0, "and refusing costs you something anyway")

	print("")
	if failures.is_empty():
		print("O5.5 PASS")
	else:
		print("FAIL: %d" % failures.size())
		for failure in failures:
			print("  - ", failure)
	get_tree().quit(0 if failures.is_empty() else 1)
