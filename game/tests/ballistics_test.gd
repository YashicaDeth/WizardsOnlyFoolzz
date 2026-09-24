extends Node

## AF1. A round that travels is only worth the cost if it behaves like one, so
## this measures drop, drag, the difference between calibres, and whether brass
## ends up where brass ends up.

const BALLISTICS := preload("res://systems/ballistics.gd")

var failures: Array[String] = []
var hits: Array = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var tree := get_tree()
	await tree.process_frame

	var world := Node3D.new()
	tree.root.add_child(world)
	tree.current_scene = world

	# A wall to shoot at, forty metres out.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 20, 1)
	shape.shape = box
	wall.add_child(shape)
	world.add_child(wall)
	wall.global_position = Vector3(0, 5, -40)

	var guns: Ballistics = BALLISTICS.new()
	world.add_child(guns)
	guns.round_hit.connect(func(hit: Dictionary) -> void: hits.append(hit))
	await tree.physics_frame

	# ---- a round is in flight, not resolved on the frame it is fired.
	guns.fire(Vector3(0, 5, 0), Vector3.FORWARD, "rifle", 0.0, 1, "player")
	check(guns.rounds.size() == 1, "a fired round exists")
	check(hits.is_empty(), "and has not arrived yet")
	var first := (guns.rounds[0] as Dictionary)["at"] as Vector3

	await tree.physics_frame
	var second := (guns.rounds[0] as Dictionary)["at"] as Vector3 if not guns.rounds.is_empty() else first
	check(second.distance_to(first) > 1.0, "it moves metres per frame, not pixels")

	# It arrives.
	var waited := 0
	while hits.is_empty() and waited < 90:
		await tree.physics_frame
		waited += 1
	check(not hits.is_empty(), "the round reaches the wall")
	if not hits.is_empty():
		var hit: Dictionary = hits[0]
		check(str(hit["calibre"]) == "rifle", "and knows what it was")
		check(str(hit["shooter"]) == "player", "and who fired it")
		check(float(hit["energy"]) > 0.0, "carrying energy")
		check(float(hit["travelled"]) >= 39.0, "and reports the real distance it travelled")
		check(float(hit["flight_time"]) > 0.0, "and its own simulated flight time")
		# ---- it drops. Forty metres of rifle is a couple of centimetres.
		var drop: float = 5.0 - float((hit["position"] as Vector3).y)
		print("rifle drop over 40m: %.3f m" % drop)
		check(drop > 0.0, "a round falls on the way")
		check(drop < 1.0, "but not absurdly")
		check(is_equal_approx(float(hit["drop"]), drop), "the landing report exposes that same physical drop")

	# ---- drag: the light fast pellet loses more than the heavy slug.
	hits.clear()
	guns.clear()
	await tree.physics_frame
	var speeds := {}
	for calibre in ["buck", "slug"]:
		# Along +X, where there is no wall: with the aim corrected both of
		# these reached the wall inside twelve frames and the measurement
		# was reading the default off an empty list.
		guns.fire(Vector3(0, 5, 0), Vector3.RIGHT, calibre, 0.0, 1, "t")
		var started: float = (guns.rounds[guns.rounds.size() - 1] as Dictionary)["velocity"].length()
		for _step in 20:
			await tree.physics_frame
		# -1 means it was never seen again, which must not read as "kept all
		# its speed" — that is how the first version of this check passed
		# while measuring nothing at all.
		var kept := -1.0
		for entry: Dictionary in guns.rounds:
			if str(entry["calibre"]) == calibre:
				kept = float(entry["velocity"].length()) / started
		speeds[calibre] = kept
		guns.clear()
		await tree.physics_frame
	print("speed kept after 20 frames: buck %.3f  slug %.3f" % [speeds["buck"], speeds["slug"]])
	check(speeds["buck"] > 0.0 and speeds["slug"] > 0.0, "both rounds were still in flight to measure")
	check(speeds["buck"] < speeds["slug"], "buckshot sheds speed faster than a slug")

	# ---- a shotgun is nine things, and they spread.
	hits.clear()
	guns.clear()
	await tree.physics_frame
	guns.fire(Vector3(0, 5, 0), Vector3.FORWARD, "buck", 0.06, 9, "player")
	check(guns.rounds.size() == 9, "a shotgun fires nine projectiles")
	waited = 0
	while hits.size() < 9 and waited < 120:
		await tree.physics_frame
		waited += 1
	check(hits.size() >= 7, "most of the pattern arrives")
	if hits.size() >= 2:
		var spread_seen := 0.0
		for hit: Dictionary in hits:
			for other: Dictionary in hits:
				spread_seen = maxf(spread_seen, (hit["position"] as Vector3).distance_to(other["position"] as Vector3))
		print("pattern spread at 40m: %.2f m" % spread_seen)
		check(spread_seen > 0.5, "the pattern opens with distance")

	# ---- brass. It ejects, it lands, it lies down, and it stays.
	check(guns.casings.size() == 1, "a shotgun ejects one case for the whole pattern")
	for _shot in 11:
		guns.fire(Vector3(0, 5, 0), Vector3.FORWARD, "pistol", 0.0, 1, "player")
		await tree.physics_frame
	check(guns.casings.size() == 12, "and a pistol ejects one per trigger pull")
	var settled := 0
	for _step in 200:
		await tree.physics_frame
		settled = guns.spent_brass()
		if settled >= 10:
			break
	print("brass settled: ", settled, " of ", guns.casings.size())
	check(settled >= 10, "brass comes to rest on the floor")
	var upright := 0
	for shell: Dictionary in guns.casings:
		var node := shell["node"] as Node3D
		if float(shell.get("rest", 0.0)) > 0.0 and absf(node.rotation.x - PI * 0.5) > 0.01:
			upright += 1
	check(upright == 0, "and lies on its side rather than standing on end")

	# It stays. Nothing sweeps it up on its own.
	var count := guns.casings.size()
	for _step in 60:
		await tree.physics_frame
	check(guns.casings.size() == count, "and it is still there a second later")

	# ---- the wall keeps surface-aligned circular wounds, not black square quads.
	check(guns.marks.size() > 0, "the wall keeps its holes")
	var wound := guns.marks.back() as Node3D
	check(wound != null, "a hit leaves a bullet wound root")
	var wound_discs := 0
	if wound != null:
		for child in wound.get_children():
			var visual := child as MeshInstance3D
			if visual != null and visual.mesh is CylinderMesh:
				wound_discs += 1
	check(wound_discs == 2, "each wound is a rim and recessed core, never a flat square quad")

	# The same wound path must lie flat when the ground is what was struck.
	guns.mark_impact(Vector3(1, 0, 1), Vector3.UP, 8.0)
	var ground_wound := guns.marks.back() as Node3D
	check(ground_wound != null and ground_wound.global_transform.basis.y.dot(Vector3.UP) > 0.99, "ground wounds align their round face to the floor")

	# ---- and none of it grows without bound.
	for _volley in 40:
		guns.fire(Vector3(0, 5, 0), Vector3.FORWARD, "buck", 0.1, 9, "t")
	check(guns.rounds.size() <= guns.MAX_ROUNDS, "rounds in flight are capped")
	check(guns.casings.size() <= guns.MAX_CASINGS, "brass on the floor is capped")
	WorldLook.set_quality_name("PERFORMANCE")
	check(guns.round_budget() == 32, "performance route uses a bounded in-flight round budget")
	check(guns.casing_budget() == 32, "performance route uses a nearby brass budget")
	check(guns.wound_budget() == 64, "performance route uses a bounded impact-scar budget")
	WorldLook.set_quality_name("HIGH")
	check(guns.casing_budget() < guns.MAX_CASINGS and guns.wound_budget() < guns.MAX_CASINGS,
		"high quality still bounds persistent ballistic objects")
	WorldLook.set_quality_name("PERFORMANCE")

	if failures.is_empty():
		print("ballistics: sound")
		tree.quit(0)
	else:
		print("ballistics FAILURES: ", failures)
		tree.quit(1)
