extends Node

## Clothes eat the blow before skin does, then they are gone. What this owns:
## cloth absorbs part of a hit while it holds, two solid slashes breach it,
## naked zones behave exactly as before, and mending only comes from outside.
## Plus the shell mesh: the body's own profile, one lift further out.

const GARMENT := preload("res://systems/clothing_shell.gd")
const HUMAN := preload("res://systems/baseline_human.gd")
const PURSE := preload("res://systems/carry.gd")

var failures: Array[String] = []


func check(c: bool, label: String) -> void:
	print("PASS " if c else "FAIL ", label)
	if not c:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	# --- cloth takes the edge off, once --------------------------------------
	var wardrobe := GARMENT.fresh_wardrobe()
	check(wardrobe.size() == 6, "a dressed body covers all six zones")
	var first: Dictionary = GARMENT.resolve_hit(wardrobe, "torso", 30.0, "cut")
	check(float(first.passed) < 30.0 and float(first.absorbed) > 0.0, "a slash meets cloth first (%.1f of 30 reaches skin)" % float(first.passed))
	check(not bool(first.breached), "but one slash does not open the jacket")

	# --- then it is gone -------------------------------------------------------
	var second: Dictionary = GARMENT.resolve_hit(wardrobe, "torso", 30.0, "cut")
	check(bool(second.breached), "two solid slashes breach it")
	var third: Dictionary = GARMENT.resolve_hit(wardrobe, "torso", 30.0, "cut")
	check(float(third.absorbed) == 0.0 and float(third.passed) == 30.0, "and rags stop nothing — a long fight ends naked")

	# --- bullets punch through, fists barely notice ------------------------------
	var dressed := GARMENT.fresh_wardrobe()
	var bullet: Dictionary = GARMENT.resolve_hit(dressed, "torso", 30.0, "ballistic")
	var blade: Dictionary = GARMENT.resolve_hit(GARMENT.fresh_wardrobe(), "torso", 30.0, "cut")
	check(float(bullet.absorbed) < float(blade.absorbed), "a bullet is slowed less than a blade (%.1f vs %.1f)" % [float(bullet.absorbed), float(blade.absorbed)])
	var blunt_wardrobe := GARMENT.fresh_wardrobe()
	var blunt: Dictionary = GARMENT.resolve_hit(blunt_wardrobe, "torso", 30.0, "blunt")
	check(float(blunt.absorbed) < float(bullet.absorbed), "a club barely meets the cloth at all (%.1f)" % float(blunt.absorbed))

	# --- naked is unchanged -------------------------------------------------------
	var bare: Dictionary = GARMENT.resolve_hit({}, "torso", 30.0, "cut")
	check(float(bare.passed) == 30.0, "no garment entry passes everything, so undressed rigs keep every old damage number")

	# --- ragged cloth stops less ---------------------------------------------------
	var worn := {"torso": 0.2}
	var ragged: Dictionary = GARMENT.resolve_hit(worn, "torso", 30.0, "cut")
	check(float(ragged.absorbed) < float(blade.absorbed), "a hanging thread stops less than a whole jacket")

	# --- mending is bought, not waited for ------------------------------------------
	var mended: float = GARMENT.mend(wardrobe, "torso", 0.5)
	check(mended > 0.0 and mended <= 1.0, "cloth comes back by repair (%.2f)" % mended)
	check(GARMENT.mend(wardrobe, "torso", 99.0) == 1.0, "and never past whole — mending is not armour")

	# --- the till: mending spends scrip, or refuses ------------------------------------
	WorldHistory.register_subject("inventory", {"items": [], "rust_scrip": 30})
	var purse = PURSE.new()
	var till_ward := GARMENT.fresh_wardrobe()
	GARMENT.resolve_hit(till_ward, "torso", 30.0, "cut")
	GARMENT.resolve_hit(till_ward, "torso", 30.0, "cut")
	var mend_bill: int = GARMENT.price_to_mend(till_ward)
	var sale: Dictionary = purse.spend_on_mending(till_ward)
	check(bool(sale.get("ok", false)), "a torn wardrobe mends for %d scrip" % mend_bill)
	check(int(sale.get("wallet", -1)) == 30 - mend_bill, "taken from the wallet, not the air (%d left)" % int(sale.get("wallet", -1)))
	check(float(till_ward["torso"]) == 1.0, "and the jacket comes back whole")
	check(not bool(purse.spend_on_mending(till_ward).get("ok", true)), "whole cloth refuses the till")
	WorldHistory.register_subject("inventory", {"items": [], "rust_scrip": 0})
	var broke: Dictionary = purse.spend_on_mending(GARMENT.ruin_wardrobe())
	check(not bool(broke.get("ok", true)) and str(broke.get("reason", "")) == "NOT ENOUGH SCRIP", "an empty wallet is refused with the reason")
	check(GARMENT.price_to_mend(GARMENT.fresh_wardrobe()) == 0, "whole cloth costs nothing to mend")
	var torn := GARMENT.fresh_wardrobe()
	GARMENT.resolve_hit(torn, "torso", 30.0, "cut")
	GARMENT.resolve_hit(torn, "torso", 30.0, "cut")
	var bill: int = GARMENT.price_to_mend(torn)
	check(bill == GARMENT.MEND_PRICE_PER_FULL, "a breached jacket bills a full restore (%d scrip)" % bill)
	check(GARMENT.price_to_mend({}) == 0, "and nakedness is not damage — nothing to mend, nothing billed")

	# --- the rig wears it, tears it, stains it ---------------------------------------
	var rig: BaselineHuman = HUMAN.new()
	add_child(rig)
	rig.build("tailor_dummy", {})
	await get_tree().process_frame
	rig.dress(GARMENT.fresh_wardrobe())
	var torso_part := rig.parts.get("torso") as Node3D
	check(torso_part.get_node_or_null("Garment") != null, "a dressed rig renders the garment over the flesh")
	var torso := rig.parts.get("torso") as Node3D
	var at := torso.global_position + Vector3(-0.04, 0.10, 0.16)
	rig.dress({})
	var naked: Dictionary = rig.hit_at(at, 34.0, 7.0, "ballistic", Vector3(0, 0, -1))
	check(float(naked.get("cloth_absorbed", -1.0)) == 0.0, "an undressed rig absorbs nothing and reports it")
	# queue_free is deferred — the garment is gone next frame, not this one.
	await get_tree().process_frame
	check(torso_part.get_node_or_null("Garment") == null or not is_instance_valid(torso_part.get_node_or_null("Garment")), "and undressing takes the garment off the body")
	rig.dress(GARMENT.fresh_wardrobe())
	var clad: Dictionary = rig.hit_at(at, 34.0, 7.0, "ballistic", Vector3(0, 0, -1))
	check(float(clad.get("cloth_absorbed", 0.0)) > 0.0, "a dressed rig eats part of the round in the cloth (%.1f)" % float(clad.get("cloth_absorbed", 0.0)))
	check(float(clad.get("damage", 0.0)) < float(naked.get("damage", 0.0)), "so less reaches the anatomy (%.1f vs %.1f)" % [float(clad.get("damage", 0.0)), float(naked.get("damage", 0.0))])

	# --- blood runs down the jacket, not into it --------------------------------------
	var bleeder: BaselineHuman = HUMAN.new()
	add_child(bleeder)
	bleeder.build("streak_dummy", {})
	await get_tree().process_frame
	bleeder.dress(GARMENT.fresh_wardrobe())
	var b_torso := bleeder.parts.get("torso") as Node3D
	var b_at := b_torso.global_position + Vector3(-0.04, 0.10, 0.16)
	bleeder.hit_at(b_at, 34.0, 7.0, "ballistic", Vector3(0, 0, -1))
	# Streaks need real bleed time, and headless frames run at wildly varying
	# rates — wait for the seconds, not a frame count, or the length gate
	# flakes by milliseconds.
	var waited := 0
	while float(bleeder.get("_bleed_seconds")) < 1.5 and waited < 400:
		await get_tree().process_frame
		waited += 1
	var garment_node := b_torso.get_node_or_null("Garment") as Node3D
	check(garment_node != null and garment_node.get_node_or_null("BloodStreak") != null, "a dressed wound runs down the garment")
	var bare_bleeder: BaselineHuman = HUMAN.new()
	add_child(bare_bleeder)
	bare_bleeder.build("streak_bare", {})
	await get_tree().process_frame
	var bb_torso := bare_bleeder.parts.get("torso") as Node3D
	bare_bleeder.hit_at(bb_torso.global_position + Vector3(-0.04, 0.10, 0.16), 34.0, 7.0, "ballistic", Vector3(0, 0, -1))
	waited = 0
	while float(bare_bleeder.get("_bleed_seconds")) < 1.5 and waited < 400:
		await get_tree().process_frame
		waited += 1
	check(bb_torso.get_node_or_null("BloodStreak") != null, "while bare skin still runs directly")
	bleeder.queue_free()
	bare_bleeder.queue_free()

	# --- the shell is the body's own silhouette, further out -----------------------
	var skin: ArrayMesh = BodyMesh.leg(0.42)
	var shell: ArrayMesh = GARMENT.shell_mesh("left_leg", 0.42)
	check(shell != null and shell.get_surface_count() == skin.get_surface_count(), "a garment builds the same surfaces as the flesh under it")
	var skin_box := skin.get_aabb()
	var shell_box := shell.get_aabb()
	check(shell_box.size.x > skin_box.size.x and shell_box.size.y >= skin_box.size.y - 0.001, "standing slightly off it, never inside it")
	var cloth: StandardMaterial3D = GARMENT.shell_material(0.0)
	var whole: StandardMaterial3D = GARMENT.shell_material(1.0)
	check(cloth.albedo_color.v > whole.albedo_color.v, "a shredded garment reads threadbare beside a whole one")
	# The revolve winds inward; culled, only the far inside of the shell drew
	# and every garment read as a thin outline around bare skin.
	check(whole.cull_mode == BaseMaterial3D.CULL_DISABLED, "cloth draws both faces, so the garment covers the body instead of outlining it")

	# --- the humiliation rig arrives already punished ---------------------------------
	var motley := GARMENT.humiliation_wardrobe()
	check(motley.size() == 7, "the rig covers six zones plus what it is")
	check(float(motley["head"]) < 1.0, "and the collar arrives damaged (%.2f)" % float(motley["head"]))
	var wine: StandardMaterial3D = GARMENT.shell_material(1.0, 0.0, "jester", "torso")
	var bone: StandardMaterial3D = GARMENT.shell_material(1.0, 0.0, "jester", "left_arm")
	var undyed: StandardMaterial3D = GARMENT.shell_material(1.0)
	check(not wine.albedo_color.is_equal_approx(bone.albedo_color), "motley reads per zone, not as one tint")
	check(not wine.albedo_color.is_equal_approx(undyed.albedo_color), "and the punishment reads apart from work cloth")
	var torn_ruff: StandardMaterial3D = GARMENT.shell_material(float(motley["head"]), 0.0, "jester", "head")
	var whole_ruff: StandardMaterial3D = GARMENT.shell_material(1.0, 0.0, "jester", "head")
	check(torn_ruff.albedo_color.v > whole_ruff.albedo_color.v, "the damaged ruff still threadbares like any cloth")

	# --- the rest of the wardrobe ---------------------------------------------------
	var clown: StandardMaterial3D = GARMENT.shell_material(1.0, 0.0, "clown", "right_arm")
	var clown_head: StandardMaterial3D = GARMENT.shell_material(1.0, 0.0, "clown", "head")
	check(not clown.albedo_color.is_equal_approx(clown_head.albedo_color), "clown reads per zone too, loud instead of dark")
	var ruins := GARMENT.ruin_wardrobe()
	check(float(ruins["torso"]) < 0.2, "ruin cloth arrives pre-torn (%.2f)" % float(ruins["torso"]))
	var ruin_hit: Dictionary = GARMENT.resolve_hit(ruins, "torso", 30.0, "cut")
	check(float(ruin_hit.absorbed) < 2.0, "and barely stops anything (%.1f)" % float(ruin_hit.absorbed))
	check(GARMENT.price_to_mend(ruins) > GARMENT.MEND_PRICE_PER_FULL * 4, "but bills near-full to restore (%d scrip)" % GARMENT.price_to_mend(ruins))
	var penitent := GARMENT.penitent_wardrobe()
	check(str(penitent["style"]) == "dunce" and float(penitent["head"]) < 0.2, "the penitent wears the cap over ruins")

	# --- blood stays in the weave --------------------------------------------------
	var clad_zone := str(clad.get("zone", "torso"))
	var soak: float = GARMENT.soak_of(rig, clad_zone)
	check(soak > 0.0, "the cloth keeps the stain (soak %.3f)" % soak)
	check(GARMENT.soak_of(rig, "head") == 0.0, "but only where the blood landed")
	var bloodied: StandardMaterial3D = GARMENT.shell_material(1.0, soak)
	# Dried blood is redder, not darker, than undyed cloth — the stain reads in
	# the red channel, which is what the eye actually catches at a glance.
	check(bloodied.albedo_color.r > whole.albedo_color.r, "a bloodied jacket reads bloodier than a clean one")
	rig.queue_free()

	print("CLOTHING_SHELL_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
