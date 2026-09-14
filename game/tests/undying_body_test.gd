extends Node

## B8.1/B8.2. "The rig survives what kills everybody else, visibly", and "what
## is left when a body fails but its spirit does not".
##
## The load-bearing test is the last section. An undying body is only undying if
## *every* path to death goes through the same door, and this component had three
## that each set `dead = true` themselves — one of which was a second copy of the
## fatal-organ branch at a different indentation that the first patch here
## missed. So rather than test the three paths that are known about, the last
## check reads the source and fails if a fourth ever appears.

const ANATOMY := preload("res://systems/anatomy_component.gd")

var failures: Array[String] = []

func check(c: bool, label: String) -> void:
	print("PASS " if c else "FAIL ", label)
	if not c:
		failures.append(label)

func _make(undying: bool) -> AnatomyComponent:
	var body: AnatomyComponent = ANATOMY.new()
	add_child(body)
	body.configure("undying_test_%s" % ("yes" if undying else "no"))
	body.undying = undying
	return body

func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()

	# --- the same wound, two bodies ----------------------------------------
	var mortal := _make(false)
	var rig := _make(true)
	mortal.finish("shot")
	check(mortal.dead, "an ordinary body dies of what kills it")

	# Drained first, because the interesting question about rising is what it
	# does to a body that has actually lost something. Failing at full blood and
	# checking that blood is still full proves nothing.
	rig.blood_remaining = rig.blood_capacity * 0.08
	rig.finish("shot")
	check(not rig.dead, "the rig takes the same thing and does not die")
	check(rig.failed, "but it has failed — this is not a body shrugging it off")
	check(rig.downed, "and it is on the ground, not still fighting")
	check(rig.failures.size() == 1, "the failure is recorded rather than forgotten")
	check(str(rig.failures[0].get("type", "")) == "shot", "and it remembers what did it")

	# --- visibly -----------------------------------------------------------
	check(rig.spirit_burden > 0.0, "surviving costs the body something permanent")
	var burdened := rig.flame_condition()
	var clean := _make(true)
	check(burdened < clean.flame_condition(), "and the flame reads lower for it — the spirit shows through harder, on the body")

	# --- what is left ------------------------------------------------------
	var risen: Dictionary = rig.rise()
	check(bool(risen.get("failures", 0) == 1), "rising reports the history rather than clearing it")
	check(not rig.failed and not rig.downed, "the body is back up")
	check(not rig.dead, "and still not dead")
	check(rig.spirit_burden > 0.0, "the burden does not come back down — this is the cost that makes undying mean something")
	check(rig.blood_remaining < rig.blood_capacity, "standing up is not healing: blood is not restored to full")
	check(rig.blood_remaining > rig.blood_capacity * 0.08, "but it is brought up to where a body can be conscious, or getting up means nothing")
	check(rig.rise().get("risen", true) == false, "a body that has not failed cannot rise again")

	# Each failure costs more.
	var before := rig.spirit_burden
	rig.finish("shot again")
	check(rig.spirit_burden > before, "the second failure costs again — it gets worse, it does not plateau")
	check(rig.failures.size() == 2, "and both are on the record")

	# --- the other two doors ------------------------------------------------
	var organ_rig := _make(true)
	organ_rig.damage_organ("brain", 999.0)
	check(not organ_rig.dead, "a destroyed brain does not kill it either")
	check(organ_rig.failed, "it fails instead")

	var bleed_rig := _make(true)
	bleed_rig.blood_remaining = 1.0
	bleed_rig.bleed_rate = 500.0
	for _f in 30:
		await get_tree().process_frame
	check(not bleed_rig.dead, "and bleeding out does not kill it")
	check(bleed_rig.failed, "it fails instead")

	# An ordinary body still dies of all three, or this is not a carve-out, it
	# is a bug that spares everybody.
	var m2 := _make(false)
	m2.damage_organ("brain", 999.0)
	check(m2.dead, "an ordinary body still dies of a destroyed brain")

	# --- no fourth door -----------------------------------------------------
	var src := FileAccess.open("res://systems/anatomy_component.gd", FileAccess.READ)
	var text := src.get_as_text()
	src.close()
	var sets := 0
	var emits := 0
	for line: String in text.split("\n"):
		var bare := line.strip_edges()
		if bare.begins_with("#"):
			continue
		if bare == "dead = true":
			sets += 1
		if bare.begins_with("died.emit"):
			emits += 1
	check(sets == 1, "exactly one place in the whole component sets `dead` (found %d)" % sets)
	check(emits == 1, "and exactly one place emits `died` (found %d)" % emits)

	print("UNDYING_BODY_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
