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
	print("ARSENAL_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
