extends Node

## B6.1/B6.2. Greg: limbs *"that shoot missiles, grapple"*. The item's own
## phrasing is the load-bearing part — "through the anatomy rather than
## around it". A capability that is an ability flag beside the body never
## hears about the arm coming off; one read through the anatomy cannot help
## but hear about it, which is B6.2 falling out of B6.1 rather than being
## bolted on beside it.

const ANATOMY := preload("res://systems/anatomy_component.gd")
const HUMAN := preload("res://systems/baseline_human.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()

	# --- B6.1: the capability is the hardware's, read off its own profile ---
	var body: AnatomyComponent = ANATOMY.new()
	add_child(body)
	body.configure("capability_test")
	check(not body.limb_can("left_arm", "grapple"), "a bare arm cannot grapple — there is nothing in it to do it with")

	body.install_part("left_arm", {"id": "ashline industrial arm"})
	check(body.limb_can("left_arm", "grapple"), "an industrial arm can, because of what is installed in it")
	check(not body.limb_can("right_arm", "grapple"), "and the other arm still cannot — this is the limb's, not the body's")
	check(body.capable_sites("grapple") == ["left_arm"], "which limb it is, is answerable without asking about each one")

	# Capability is read off the catalogue's own profile rather than a second
	# table, so a piece of hardware that is not a limb drive grants nothing.
	body.install_part("right_arm", {"id": "ledger thumb"})
	check(not body.limb_can("right_arm", "grapple"), "a ledger thumb is hardware and still cannot grapple")

	# --- dead hardware does nothing ----------------------------------------
	body.damage_implant("left_arm", 1000.0)
	check(body.implant_condition("left_arm") <= 0.0, "sanity: the arm's hardware is wrecked")
	check(not body.limb_can("left_arm", "grapple"), "wrecked hardware is a weight on the end of your arm, not a grapple")

	# --- a capability the catalogue has no limb for yet --------------------
	var launcher: AnatomyComponent = ANATOMY.new()
	add_child(launcher)
	launcher.configure("launcher_test")
	launcher.install_part("right_arm", {"id": "test launcher arm", "profile": "launcher_limb", "zone": "right_arm", "max_condition": 100.0, "condition": 100.0})
	check(launcher.limb_can("right_arm", "launch"), "the same routing carries a launching limb, not only a grappling one")
	check(not launcher.limb_can("right_arm", "grapple"), "and it does not quietly grant every capability at once")

	# --- B6.2: through the rig, a severed limb can do nothing --------------
	var rig: BaselineHuman = HUMAN.new()
	add_child(rig)
	rig.build("sever_test", {})
	rig.anatomy.install_part("left_arm", {"id": "ashline industrial arm"})
	check(rig.limb_can("left_arm", "grapple"), "the rig agrees the arm can grapple while it is still attached")
	check(rig.capable_limbs("grapple") == ["left_arm"], "and lists it as the limb to reach with")

	rig.severed.append("left_arm")
	check(not rig.limb_can("left_arm", "grapple"), "the moment it comes off it can do nothing — nothing had to remember to switch a flag")
	check(rig.capable_limbs("grapple").is_empty(), "and it is no longer offered as a limb to reach with")
	check(rig.anatomy.limb_can("left_arm", "grapple"), "the hardware is still installed and still intact — it is the body that vetoes it, which is the layering the item asks for")

	# --- B6.2 end to end: a hold actually ends when the arm does -----------
	var hunt: Node = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	for _settle in 60:
		await get_tree().process_frame

	hunt.set("grapple_target", "somebody")
	hunt.set("grapple_with", "left_arm")
	var hunt_rig: BaselineHuman = hunt.get("player_rig")
	check(hunt_rig != null, "sanity: the hunt grounds have a player rig")
	check(not hunt_rig.severed.has("left_arm"), "sanity: the arm is on to begin with")

	hunt_rig.severed.append("left_arm")
	hunt.call("_update_grapple", 0.1)
	check(str(hunt.get("grapple_target")) == "", "severing the holding arm actually ends the hold")

	print("LIMB_CAPABILITY_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
