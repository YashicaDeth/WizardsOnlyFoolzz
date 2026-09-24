extends Node

const ARSENAL := preload("res://systems/hunter_arsenal.gd")
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var rig := BaselineHuman.new()
	rig.gore = false
	add_child(rig)
	rig.build("armed_test")
	var arsenal: Node = ARSENAL.new()
	add_child(arsenal)
	arsenal.configure(rig)
	check(arsenal.current_id == "sword" and arsenal.models.size() == 3, "hunter receives three modeled weapon slots")
	check(arsenal.models.sword.visible and not arsenal.models.shotgun.visible, "only equipped weapon is visible in the real hand")
	var sword: Dictionary = arsenal.begin_attack(true)
	check(sword.accepted and sword.kind == "melee" and float(sword.damage) > 60.0, "heavy sword attack has distinct force and cost")
	arsenal.tick(2.0)
	check(arsenal.select_slot(1), "slot 2 equips shotgun")
	var shell_before := int(arsenal.ammo.shotgun.loaded)
	var blast: Dictionary = arsenal.begin_attack()
	check(blast.accepted and blast.kind == "firearm" and int(arsenal.ammo.shotgun.loaded) == shell_before - 1, "shotgun consumes one chambered shell")
	var pellets: Array[Vector3] = arsenal.shot_directions(Vector3.FORWARD, Vector3.UP)
	var cone_is_valid: bool = pellets.size() == 10
	for pellet in pellets:
		cone_is_valid = cone_is_valid and is_equal_approx(pellet.length(), 1.0) and pellet.dot(Vector3.FORWARD) > 0.98
	check(cone_is_valid, "shotgun produces ten normalized pellets inside its authored cone")
	# Ballistics do not own a separate health pool. Repeated pellets cross the
	# shared arm threshold and therefore cause the same persistent limb loss as
	# any other source of anatomy damage.
	for pellet in 5:
		rig.hit("left_arm", float(blast.damage), float(blast.impulse), "ballistic")
	check(rig.severed.has("left_arm") and not rig.parts.left_arm.visible, "shotgun damage can disable and detach an NPC limb")
	arsenal.tick(2.0)
	check(arsenal.reload(), "shotgun starts reload when shells are missing")
	arsenal.tick(3.0)
	check(int(arsenal.ammo.shotgun.loaded) == 5 and int(arsenal.ammo.shotgun.reserve) == 24, "reload transfers only required reserve ammunition")
	check(arsenal.select_slot(2) and arsenal.models.sidearm.visible, "slot 3 equips sidearm and updates held model")
	var pistol: Dictionary = arsenal.begin_attack()
	check(pistol.accepted and pistol.pellets == 1 and pistol.range > blast.range, "sidearm is precise and longer ranged than shotgun")
	# --- a weapon you picked up is a weapon you can get back to ----------------
	#
	# `select_slot()` indexed SLOT_ORDER and refused anything past its three
	# entries, while `acquire_sniper()` set `current_id` directly without going
	# through a slot. So a rifle was in your hands until you pressed 1, and then
	# it was gone: still owned, still loaded, still in `models`, and unreachable
	# by any input in the game.
	check(not arsenal.carried().has("sniper"), "a rifle nobody has found is not being carried")
	check(arsenal.carried().size() == 3, "so what you carry is what you were issued (%d)" % arsenal.carried().size())
	check(arsenal.acquire_sniper(), "the rifle can be picked up")
	check(arsenal.current_id == "sniper", "and picking it up puts it in your hands")
	check(arsenal.carried().has("sniper"), "now it is something you are carrying")

	# The actual bug: switch away, and try to come back.
	check(arsenal.select_slot(0) and arsenal.current_id == "sword", "switching to the issued first slot still works")
	check(arsenal.select_weapon("sniper") and arsenal.current_id == "sniper", "and the rifle can be reached again by name")
	check(arsenal.select_slot(3) and arsenal.current_id == "sniper", "or by its position in what you carry")

	# Backwards compatibility: everything that looks a weapon up with
	# SLOT_ORDER.find() has to keep landing on the same index.
	check(arsenal.select_slot(1) and arsenal.current_id == "shotgun", "the issued slots have not moved")
	check(arsenal.select_slot(2) and arsenal.current_id == "sidearm", "any of them")

	# Wrapping, so there is never a dead end to get stuck on.
	check(arsenal.select_slot(0) and arsenal.cycle(-1) and arsenal.current_id == "sniper", "cycling back from the first wraps onto the last")
	check(arsenal.cycle(1) and arsenal.current_id == "sword", "and forward from the last wraps round again")
	check(arsenal.select_slot(9) == false, "a slot nobody is carrying is still refused")

	print("ARSENAL_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
