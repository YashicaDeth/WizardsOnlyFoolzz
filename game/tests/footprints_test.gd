extends Node

## Feet cross gore and the floor forgets. What this owns: dry floor prints
## nothing, standing in a pool soaks the foot, one soaking walks out as a
## fading trail and then nothing, and the night never holds more than the cap.

const PRINTS := preload("res://systems/footprints.gd")
const POOL := preload("res://systems/blood_pool.gd")

var failures: Array[String] = []


func check(c: bool, label: String) -> void:
	print("PASS " if c else "FAIL ", label)
	if not c:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	POOL.clear()
	PRINTS.clear()

	# --- dry floor is silent ----------------------------------------------------
	var dry := Vector3(4.0, 0.5, 0.0)
	check(not PRINTS.step(self, self, dry, "left"), "a dry footfall leaves nothing")
	check(PRINTS.print_count(self) == 0, "and the floor agrees")

	# --- standing in blood soaks the foot -----------------------------------------
	var stain := Vector3.ZERO
	POOL.keep(self, stain, 8.0)
	check(PRINTS.step(self, self, stain, "left"), "stepping in a pool prints")
	check(PRINTS.wetness(self) > 0.5, "and the foot comes away wet (%.2f)" % PRINTS.wetness(self))
	check(get_node_or_null("BloodPrint") != null, "with a node pinned to the floor")

	# --- one soaking walks out as a fading trail ------------------------------------
	var had := PRINTS.print_count(self)
	for stride in 12:
		var at := Vector3(1.0 + float(stride) * 0.6, 0.5, 0.0)
		PRINTS.step(self, self, at, "left" if stride % 2 == 0 else "right")
	# Prints are never freed mid-run, so the run's own prints are the tail of
	# the child list — counting measurements instead once overstated this.
	var made := PRINTS.print_count(self) - had
	check(made >= 4, "a soaking lays a real trail (%d prints)" % made)
	var prints := []
	for child in get_children():
		if child is MeshInstance3D and child.has_meta("print"):
			prints.append(child)
	var sizes: Array[float] = []
	for index in range(prints.size() - made, prints.size()):
		sizes.append((prints[index] as MeshInstance3D).mesh.get_aabb().size.x)
	# Rim seeds jitter the outline ±5%, so per-step monotonicity would test the
	# noise rather than the trail. The property that matters is the walk-out:
	# the last print is meaningfully smaller than the first.
	if sizes.is_empty():
		check(false, "and it fades as it walks out (no prints to compare)")
	else:
		check(sizes[-1] < sizes[0] * 0.9, "and it fades as it walks out (%.3f to %.3f)" % [sizes[0], sizes[-1]])
	var last_wet: float = PRINTS.wetness(self)
	check(last_wet < PRINTS.MIN_WET, "until the foot runs dry (%.3f)" % last_wet)

	# --- the night stays bounded ------------------------------------------------------
	PRINTS.clear()
	POOL.clear()
	POOL.keep(self, stain, 40.0)
	for stride in 200:
		PRINTS.step(self, self, stain, "left")
	check(PRINTS.print_count(self) <= PRINTS.MAX_PRINTS, "two hundred steps fit the cap (%d of %d)" % [PRINTS.print_count(self), PRINTS.MAX_PRINTS])
	PRINTS.clear()
	POOL.clear()
	check(PRINTS.print_count(self) == 0, "clear() leaves no prints behind for the next scene")

	print("FOOTPRINTS_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
