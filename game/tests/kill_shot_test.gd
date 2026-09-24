extends Node

## When the world is allowed to stop.
##
## The failure this guards against is not a crash. It is the camera firing over
## a wound the victim would have walked away from -- a player who watches an
## X-ray finisher and is then shot by the subject of it will not believe the
## next one.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _snapshot(dead: bool, ruptured: Array) -> Dictionary:
	var organs := {}
	for organ_id in BaselineHuman.ORGAN_LAYOUT:
		organs[organ_id] = {"ruptured": ruptured.has(organ_id)}
	return {"dead": dead, "organs": organs}


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	print("-- a rifle through the head is what this is for --")
	var head := KillShot.earned("sniper", "head", _snapshot(true, ["brain"]))
	check(not head.is_empty(), "the shot earns the camera")
	check(str(head.get("organ", "")) == "brain", "and it knows what it destroyed (%s)" % str(head.get("organ", "")))
	check(str(head.get("zone", "")) == "head", "and where")
	check(str(head.get("label", "")).contains("LONGVIEW"), "the caption names the weapon (%s)" % str(head.get("label", "")))
	check(str(head.get("label", "")).contains("BRAIN"), "and the organ")

	print("-- the camera does not lie about somebody still standing --")
	var alive := KillShot.earned("sniper", "head", _snapshot(false, ["brain"]))
	check(alive.is_empty(), "a survivable hit earns nothing, however ugly")

	print("-- nor over a death the plate cannot show --")
	# Dead, but from blood loss rather than from anything rupturing on contact.
	var bled := KillShot.earned("sniper", "left_arm", _snapshot(true, []))
	check(bled.is_empty(), "bleeding out is a real death and the wrong occasion")
	var gut := KillShot.earned("sniper", "torso", _snapshot(true, ["gut", "liver"]))
	check(gut.is_empty(), "a ruptured gut is a slow death, not a finisher")

	print("-- and not for every weapon that happens to finish somebody --")
	check(KillShot.earned("shotgun", "head", _snapshot(true, ["brain"])).is_empty(), "a shotgun kill is just a kill")
	check(KillShot.earned("sword", "head", _snapshot(true, ["brain"])).is_empty(), "the sword has executions of its own")
	check(KillShot.earned("sidearm", "torso", _snapshot(true, ["heart"])).is_empty(), "and the sidearm is not the shot you line up")

	print("-- it reports the organ in the zone that was hit --")
	# Both vital organs gone. A torso shot should be reported as the heart, not
	# as the brain, whichever order the constant happens to list them in.
	var both := KillShot.earned("sniper", "torso", _snapshot(true, ["brain", "heart"]))
	check(str(both.get("organ", "")) == "heart", "a chest shot reads as the heart (%s)" % str(both.get("organ", "")))
	var both_head := KillShot.earned("sniper", "head", _snapshot(true, ["brain", "heart"]))
	check(str(both_head.get("organ", "")) == "brain", "and a head shot as the brain (%s)" % str(both_head.get("organ", "")))

	print("-- a limb hit that still killed reports the vital that went --")
	var far := KillShot.earned("sniper", "right_arm", _snapshot(true, ["heart"]))
	check(not far.is_empty(), "it is still a finisher")
	check(str(far.get("organ", "")) == "heart", "named by what was destroyed, not where it entered")

	print("-- nothing in an empty snapshot crashes it --")
	check(KillShot.earned("sniper", "torso", {}).is_empty(), "an empty snapshot is simply not a finisher")
	check(KillShot.earned("sniper", "torso", {"dead": true}).is_empty(), "nor one with no organs in it")

	print("KILL_SHOT_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
