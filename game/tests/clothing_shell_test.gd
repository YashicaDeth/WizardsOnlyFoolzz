extends Node

## Clothes eat the blow before skin does, then they are gone. What this owns:
## cloth absorbs part of a hit while it holds, two solid slashes breach it,
## naked zones behave exactly as before, and mending only comes from outside.
## Plus the shell mesh: the body's own profile, one lift further out.

const GARMENT := preload("res://systems/clothing_shell.gd")
const HUMAN := preload("res://systems/baseline_human.gd")

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
