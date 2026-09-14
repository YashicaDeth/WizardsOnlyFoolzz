extends Node

## AD3.2. "Cybernetics change what movement is possible, not just the
## numbers." The second half is the whole item: a limb that makes you 12%
## faster has changed a number. These change whether a move exists at all —
## a bare body cannot leave the ground twice and reads a chest-high barrier
## as a wall; an augmented one can and does not. Both route through the same
## `capable_limbs()` path B6.1 built, so a severed leg takes the move with
## it (B6.2) without either of these having to hear about it.

const HUNT := preload("res://bone_yard_hunt.tscn")

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

	var hunt: Node = HUNT.instantiate()
	add_child(hunt)
	for _settle in 60:
		await get_tree().process_frame
	var rig: BaselineHuman = hunt.get("player_rig")
	check(rig != null, "sanity: the hunt grounds have a player rig")

	# --- bare body: the ceiling is the bare ceiling ------------------------
	check(rig.capable_limbs("vault_high").is_empty(), "a bare body has no limb that clears a wall")
	check(rig.capable_limbs("kick_off").is_empty(), "and none that kicks off nothing")
	var bare_ceiling: float = float(hunt.call("_vault_ceiling"))
	check(is_equal_approx(bare_ceiling, hunt.get("VAULT_MAX_TOP")), "so its vault ceiling is exactly AD1.2's own line (%.2f)" % bare_ceiling)

	# --- the hardware, in a real leg ---------------------------------------
	rig.anatomy.install_part("right_leg", {"id": "heel anchors"})
	check(rig.limb_can("right_leg", "vault_high"), "heel anchors in a leg can clear what a bare body cannot")
	check(rig.limb_can("right_leg", "kick_off"), "and can kick off nothing")
	check(not rig.limb_can("left_leg", "kick_off"), "the other leg cannot — this is the limb's, not the body's")

	var augmented_ceiling: float = float(hunt.call("_vault_ceiling"))
	check(augmented_ceiling > bare_ceiling, "the vault ceiling actually rises with it (%.2f -> %.2f)" % [bare_ceiling, augmented_ceiling])
	check(is_equal_approx(augmented_ceiling, hunt.get("VAULT_MAX_TOP_AUGMENTED")), "to the authored augmented ceiling, not an arbitrary number")

	# The point of the item, stated as the thing that is actually different:
	# there is a band of obstacle height that is a wall for one body and a
	# vault for the other. Not a faster vault — a possible one.
	var band := augmented_ceiling - bare_ceiling
	check(band > 0.3, "leaving a real band of obstacle that is a wall bare and a vault augmented (%.2fm)" % band)

	# --- the kick-off is binary, and the ground takes it back --------------
	hunt.set("kick_off_spent", 0)
	check(int(hunt.get("kick_off_spent")) == 0, "sanity: nothing spent on the ground")

	# Airborne with hardware: the press is accepted rather than refused.
	hunt.set("jump_queued", false)
	var body: CharacterBody3D = hunt.get("player_body")
	body.velocity.y = 6.0
	body.global_position.y += 3.0
	for _air in 2:
		await get_tree().physics_frame
	check(not body.is_on_floor(), "sanity: the body is genuinely airborne")

	hunt.call("_jump")
	check(bool(hunt.get("jump_queued")), "an airborne press is accepted with the hardware in the leg")

	# --- and refused without it -------------------------------------------
	rig.anatomy.pull_part("right_leg", true)
	check(rig.capable_limbs("kick_off").is_empty(), "pulling the hardware takes the move back")
	hunt.set("jump_queued", false)
	hunt.set("kick_off_spent", 0)
	hunt.call("_jump")
	check(not bool(hunt.get("jump_queued")), "and an airborne press is refused again, exactly as it always was")
	check(is_equal_approx(float(hunt.call("_vault_ceiling")), bare_ceiling), "with the vault ceiling back at the bare line")

	# --- B6.2 consistency: severing takes it too --------------------------
	rig.anatomy.install_part("right_leg", {"id": "heel anchors"})
	check(rig.limb_can("right_leg", "kick_off"), "sanity: refitted")
	rig.severed.append("right_leg")
	check(not rig.limb_can("right_leg", "kick_off"), "and severing the leg takes the move with it, with nothing here needing to know")
	check(is_equal_approx(float(hunt.call("_vault_ceiling")), bare_ceiling), "including the vault ceiling, which drops back on its own")

	print("AUGMENTED_MOVEMENT_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
