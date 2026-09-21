extends Node

## Blood pooling grows and merges. Per-drop splats are the right answer for
## spatter; this test owns the other half — a bleed onto one spot becomes one
## growing stain, and two bleeds that meet become one stain rather than two
## overlapping decals. Pure logic plus the live `keep()` path, no scene needed
## beyond this node itself.

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

	# --- growth is sublinear: doubling blood never doubles width ---------------
	var r1: float = POOL.radius_for(1.0)
	var r4: float = POOL.radius_for(4.0)
	check(r1 > 0.0, "one drop covers ground (r=%.4f)" % r1)
	check(absf(r4 - 2.0 * r1) < 0.001, "four times the blood is twice the width, not four times (%.4f vs %.4f)" % [r4, 2.0 * r1])
	check(POOL.radius_for(0.0) == 0.0, "no blood is no pool")
	var capped: float = POOL.radius_for(999999.0)
	check(capped <= POOL.MAX_RADIUS + 0.001, "a lake is refused: one pool never outgrows %.2fm" % POOL.MAX_RADIUS)

	# --- nearby feeds merge ----------------------------------------------------
	var pools: Array = []
	POOL.feed(pools, Vector3.ZERO, 4.0)
	POOL.feed(pools, Vector3(0.1, 0.0, 0.0), 4.0)
	check(pools.size() == 1, "two bleeds that touch are one stain, not two decals")
	check(absf(float(pools[0].volume) - 8.0) < 0.001, "and the volume adds (%.2f)" % float(pools[0].volume))

	# --- distant feeds stay separate -------------------------------------------
	POOL.feed(pools, Vector3(5.0, 0.0, 0.0), 4.0)
	check(pools.size() == 2, "a bleed five metres off starts its own pool")

	# --- the middle moves toward the new blood ---------------------------------
	var drift: Array = []
	POOL.feed(drift, Vector3.ZERO, 1.0)
	POOL.feed(drift, Vector3(0.1, 0.0, 0.0), 3.0)
	check(absf(drift[0].pos.x - 0.075) < 0.001, "the deep end sits where the blood went (x=%.4f)" % drift[0].pos.x)

	# --- the cap absorbs instead of erasing ------------------------------------
	var many: Array = []
	for index in 400:
		POOL.feed(many, Vector3(float(index) * 3.0, 0.0, 0.0), 1.0)
	check(many.size() <= POOL.pool_budget(), "four hundred feeds fit the budget (%d of %d)" % [many.size(), POOL.pool_budget()])
	var kept := 0.0
	for pool: Dictionary in many:
		kept += float(pool.volume)
	check(absf(kept - 400.0) < 0.01, "and none of it vanished at the cap (%.1f of 400 kept)" % kept)
	check(POOL.feed(many, Vector3.ZERO, -2.0) == -1, "negative blood is refused")

	# --- old blood reads old ----------------------------------------------------
	var wet: StandardMaterial3D = POOL.pool_material(0.0)
	var dry: StandardMaterial3D = POOL.pool_material(1.0)
	check(dry.albedo_color.v < wet.albedo_color.v, "a pool darkens as it dries, like the streaks do")

	# --- the mesh is real --------------------------------------------------------
	var mesh: ArrayMesh = POOL.build_pool_mesh(0.3, 7)
	check(mesh != null and mesh.get_surface_count() == 1, "a pool builds one flat mesh, not a placeholder")

	# --- the live path pins a node to the scene ----------------------------------
	POOL.clear()
	var first: int = POOL.keep(self, Vector3(0.0, 0.5, 0.0), 2.0)
	check(first == 0, "the first feed opens pool zero")
	check(POOL.pool_count(self) == 1, "and the scene knows it has one pool")
	check(get_node_or_null("BloodPool") != null, "with a node pinned to it")
	var again: int = POOL.keep(self, Vector3(0.05, 0.5, 0.0), 2.0)
	check(again == 0 and POOL.pool_count(self) == 1, "a neighbouring feed joins it instead of doubling it")
	POOL.clear()
	check(POOL.pool_count(self) == 0, "clear() leaves no pools behind for the next scene")

	print("BLOOD_POOL_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
