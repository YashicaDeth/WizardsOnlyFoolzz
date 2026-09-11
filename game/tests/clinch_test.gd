extends Node

## F7. The claim is that having hold of somebody is a conversation, that the two
## ladders do different social work — fear coerces, standing persuades — and
## that what happens in the clinch reaches the downed window afterwards.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var fresh := {"pain": 0.0, "consciousness": 100.0}
	var hurt := {"pain": 70.0, "consciousness": 55.0}
	var stranger := {}

	# --- the hold itself ----------------------------------------------------
	check(Clinch.hold_strength(-1.0, fresh) <= 0.0, "losing the clinch is no hold at all")
	check(Clinch.hold_strength(1.0, fresh) > Clinch.hold_strength(0.2, fresh), "winning it is a better hold")
	check(Clinch.hold_strength(0.2, hurt) > Clinch.hold_strength(0.2, fresh), "and a hurt body is easier to hold than a fresh one")
	check(not bool(Clinch.options(-0.9, fresh, stranger, 0.0).persuade), "you cannot negotiate from underneath")

	# --- the two ladders do different work ----------------------------------
	var feared := Clinch.coercion(0.5, fresh, stranger, -0.9)
	var neutral_threat := Clinch.coercion(0.5, fresh, stranger, 0.0)
	var saintly := Clinch.coercion(0.5, fresh, stranger, 0.9)
	check(feared > neutral_threat and neutral_threat >= saintly, "a feared player leans on people better (%.2f > %.2f >= %.2f)" % [feared, neutral_threat, saintly])

	var trusted := Clinch.persuasion(0.5, fresh, stranger, 0.9)
	var neutral_talk := Clinch.persuasion(0.5, fresh, stranger, 0.0)
	var dreaded := Clinch.persuasion(0.5, fresh, stranger, -0.9)
	check(trusted > neutral_talk and neutral_talk >= dreaded, "and a trusted one talks people round better (%.2f > %.2f >= %.2f)" % [trusted, neutral_talk, dreaded])
	check(feared > dreaded, "the same person on Descent coerces better than they persuade")
	check(trusted > saintly, "and on Ascent persuades better than they coerce")

	# --- history is in the room ---------------------------------------------
	var enemy := {"grudge": 90}
	var friend := {"bond": 80}
	check(Clinch.persuasion(0.5, fresh, enemy, 0.0) < Clinch.persuasion(0.5, fresh, stranger, 0.0), "somebody who hates you will not be talked round")
	check(Clinch.persuasion(0.5, fresh, friend, 0.0) > Clinch.persuasion(0.5, fresh, stranger, 0.0), "somebody who owes you will")

	# --- talking ------------------------------------------------------------
	var refused := Clinch.persuade(enemy, 0.5, fresh, -0.5)
	check(not bool(refused.accepted) and int(refused.get("grudge", 0)) > 0, "being refused costs you: you had hold of them and they said no")
	var agreed := Clinch.persuade(friend, 0.9, hurt, 0.8)
	check(bool(agreed.accepted), "a trusted player with a real hold gets a yes")
	check(float(agreed.get("debt", 0.0)) > 0.0, "and is owed for it afterwards")
	check(bool(agreed.get("consent", false)), "a strong yes is consent, which is what recruitment needs")

	# --- leaning ------------------------------------------------------------
	var leaned := Clinch.threaten(stranger, 0.9, hurt, -0.8)
	check(bool(leaned.accepted) and bool(leaned.get("yields", false)), "a frightening player gets compliance")
	check(int(leaned.get("grudge", 0)) > 0, "and buys it with a grudge that outlives the hold")
	check(float(leaned.get("karma", 0.0)) < 0.0, "leaning on a held person is itself an act that counts")
	var unafraid := Clinch.threaten({"grudge": 95}, 0.3, fresh, 0.6)
	check(not bool(unafraid.accepted), "somebody who is not frightened of you simply refuses")

	# --- surrender is the seam into the downed window -----------------------
	check(bool(Clinch.options(1.0, hurt, friend, 0.9).surrender), "a total hold on a willing person is a surrender")
	check(not bool(Clinch.options(0.2, fresh, enemy, 0.0).surrender), "a weak hold on a hostile one is not")

	print("CLINCH_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
