extends Node

## Clothes eat the blow before skin does, then they are gone. What this owns:
## cloth absorbs part of a hit while it holds, two solid slashes breach it,
## naked zones behave exactly as before, and mending only comes from outside.
## Plus the shell mesh: the body's own profile, one lift further out.

const GARMENT := preload("res://systems/clothing_shell.gd")

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

	print("CLOTHING_SHELL_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
