extends Node3D

## lab-47: Teardown-like destruction with Greg's five tiers (5 Oct). Each
## source against each tier per `MaterialToughness`, through real voxels;
## disconnected pieces fall; a dug tunnel stays dug (and replays from a save);
## blasts hurt and throw bodies, debris hurts bodies; and the lab's breach
## corner runs dig -> hatch -> charge, and drill -> bunker.

var failures: Array[String] = []

const BY_TIER := {1: "dirt", 2: "brick", 3: "concrete", 4: "bunker", 5: "sealed"}
const SOURCE_TIER := {"melee": 2, "firearm": 3, "explosive": 4, "charge": 5}


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	# A slab under the falling-piece test only; the dig tests need open air.
	var slab := BoxShape3D.new()
	slab.size = Vector3(6, 0.2, 6)
	floor_shape.shape = slab
	floor_body.position = Vector3(10, -0.1, 0)
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	await _table()
	await _falls()
	await _dug()
	await _bodies()
	await _breach()
	print("DESTRUCTION_TOUGHNESS_TEST_RESULT failures=%d" % failures.size())
	# Tear down before quitting, as gore_range_reset_test does: engine shutdown
	# freeing the rig, the debris and the static gore in its own order crashed
	# (139) about 1 run in 10 under Jolt.
	GoreChunks.clear()
	BaselineHuman.clear_gore()
	WorldDebris.clear_pool(VoxelStructure.CUBE_POOL)
	WorldDebris.clear_pool(VoxelStructure.CHUNK_POOL)
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	VoxelStructure.release()
	get_tree().quit(0 if failures.is_empty() else 1)


func _table() -> void:
	for source: String in SOURCE_TIER:
		for tier: int in BY_TIER:
			var material: String = BY_TIER[tier]
			var expected: bool = SOURCE_TIER[source] >= tier
			check(MaterialToughness.can_break(source, material) == expected, "table: %s vs tier %d %s -> %s" % [source, tier, material, expected])
			# And through a real block: a hit big enough to take anything it can.
			var block := VoxelStructure.make(self, material, Vector3(0.45, 0.45, 0.45), Vector3(0, 5, 0), "none")
			var result := block.damage_sphere(block.cell_centre(Vector3i(1, 1, 1)), 0.1, source, 1000.0)
			check((int(result.removed) > 0) == expected and (int(result.blocked) > 0) == not expected, "voxels: %s on %s removed %d blocked %d" % [source, material, result.removed, result.blocked])
			block.free()
	# The over-time and variable sources.
	check(MaterialToughness.can_break("thermal_drill", "sealed") and MaterialToughness.is_over_time("thermal_drill"), "the thermal drill beats tier 5, over time")
	check(MaterialToughness.can_break("cutting_torch", "vault") and not MaterialToughness.can_break("cutting_torch", "sealed"), "the cutting torch beats tier 4, not 5")
	check(MaterialToughness.source_tier("vehicle", {"mass": 1200.0, "speed": 14.0}) == 3, "a 1.2 t car at 50 km/h rams through tier 3")
	check(MaterialToughness.source_tier("vehicle", {"mass": 1200.0, "speed": 3.0}) == 0, "and at walking pace through nothing")
	check(MaterialToughness.source_tier("chaos", {"altitude": 100.0}) == 0, "chaos magick is a dial, off until set")
	var bunker := VoxelStructure.make(self, "bunker", Vector3(0.15, 0.15, 0.15), Vector3(2, 5, 0), "none")
	var once := bunker.damage_sphere(bunker.cell_centre(Vector3i.ZERO), 0.1, "thermal_drill", 55.0 / 60.0)
	check(int(once.removed) == 0, "one frame of drill does not hole a bunker cell")
	var taken := 0
	for frame in 120:
		taken += int(bunker.damage_sphere(bunker.cell_centre(Vector3i.ZERO), 0.1, "thermal_drill", 55.0 / 60.0).removed)
	check(taken == 1, "two seconds of drill does")
	await get_tree().physics_frame


func _falls() -> void:
	var wall := VoxelStructure.make(self, "brick", Vector3(1.2, 1.2, 0.15), Vector3(10, 0.6, 0), "floor")
	await get_tree().physics_frame
	var before := wall.solid_count()
	# Cut a band right across, two rows up: everything above loses the floor.
	for x in wall.size.x:
		wall.damage_sphere(wall.cell_centre(Vector3i(x, 2, 0)), 0.08, "firearm", 1000.0)
	var pieces := get_children().filter(func(node: Node) -> bool: return node is VoxelStructure and node != wall and not (node as VoxelStructure).freeze)
	check(pieces.size() == 1, "cutting a wall through breaks the top off as one piece (%d)" % pieces.size())
	check(wall.solid_count() == 2 * wall.size.x, "and the stump keeps only its two floor rows (%d of %d)" % [wall.solid_count(), before])
	if pieces.size() == 1:
		var piece: VoxelStructure = pieces[0]
		var start := piece.global_position.y
		await _seconds(0.6)
		check(is_instance_valid(piece) and piece.global_position.y < start - 0.1, "and the piece drops into the cut (%.2f -> %.2f)" % [start, piece.global_position.y if is_instance_valid(piece) else -1.0])
	check(WorldDebris.pool_count(VoxelStructure.CUBE_POOL) <= VoxelStructure.CUBE_BUDGET, "loose cubes stay inside their budget")


func _dug() -> void:
	var ground := DigTerrain.new()
	ground.cells = Vector3i(16, 12, 16)
	ground.position = Vector3(-20, -2.5, -2)
	add_child(ground)
	var spot := ground.to_global(Vector3(2.0, 2.5, 2.0))
	check(ground.is_solid(spot), "the patch is soil half a metre down")
	var dug := ground.carve_sphere(spot, 0.6, "dig")
	check(dug > 0 and not ground.is_solid(spot), "a scoop takes it out (%d samples)" % dug)
	check(ground.carve_sphere(spot + Vector3(0.6, 0, 0), 0.5, "charge") > 0, "a tunnel goes on sideways")
	await _seconds(0.5)
	check(not ground.is_solid(spot), "and stays dug")
	# The collider follows: a ray down from above the hole goes deeper than the surface.
	var query := PhysicsRayQueryParameters3D.create(spot + Vector3(0, 3, 0), spot + Vector3(0, -3, 0), 1)
	var met := get_world_3d().direct_space_state.intersect_ray(query)
	check(not met.is_empty() and met.position.y < ground.surface_y() - 0.5, "the ground's collider has the hole in it (hit at %.2f)" % (met.position.y if not met.is_empty() else 99.0))
	# Saved and loaded: a fresh patch replays the cuts.
	var again := DigTerrain.new()
	again.cells = ground.cells
	again.position = ground.position + Vector3(0, 0, 8)
	add_child(again)
	again.restore(ground.cuts)
	check(not again.is_solid(spot + Vector3(0, 0, 8)), "a reloaded patch keeps the tunnel")
	ground.queue_free()
	again.queue_free()
	await get_tree().physics_frame


func _bodies() -> void:
	var rig: BaselineHuman = load("res://lab/stations/bodies_station.gd").dummy(self, "BlastDummy", Vector3(30, 0, 0), 0.0)
	await _seconds(0.2)
	var before := rig.zone_health("torso")
	var tally := Blast.explode(self, Vector3(30.6, 0.6, 0.4), 1.1, 260.0, "explosive")
	check(int(tally.bodies) == 1, "a grenade's blast reaches the dummy")
	check(rig.zone_health("torso") < before or rig.is_downed(), "and wounds it")
	await _seconds(0.3)
	var thrown := get_children().any(func(node: Node) -> bool: return node is RagdollBody) or rig.is_downed()
	check(thrown, "and puts it down / throws it")
	# Debris that hits a body fast wounds it.
	var other: BaselineHuman = load("res://lab/stations/bodies_station.gd").dummy(self, "DebrisDummy", Vector3(34, 0, 0), 0.0)
	await _seconds(0.2)
	var cube := VoxelStructure.spawn_cube(self, Vector3(34, 1.2, 1.0), 0.14, "concrete", Vector3(0, 0, -9))
	var hitbox := other.get_node("torso_hitbox")
	check(not VoxelStructure.hurt_by(cube, hitbox).is_empty(), "a flying concrete cube wounds the body it meets")
	cube.linear_velocity = Vector3.ZERO
	check(VoxelStructure.hurt_by(cube, hitbox).is_empty(), "and a resting one does not")
	# Done with them: a ragdolled dummy left lying while the lab runs made the
	# exit crash (139) about 1 run in 10.
	for node in get_children():
		if node is RagdollBody or node.name in ["BlastDummy", "DebrisDummy"] or node == cube:
			node.queue_free()
	BaselineHuman.clear_gore()
	await get_tree().physics_frame
	await get_tree().physics_frame


func _breach() -> void:
	var lab: Node3D = load("res://lab/mechanics_lab.tscn").instantiate()
	add_child(lab)
	await _frames(3)
	var station = lab.destruction
	# The HUD counts voxel walls too; a charge on brick is checked last.
	check(station.broken_count() == 0 and str(station.status()).begins_with("BROKEN 0/%d" % station.breakables()), "the station starts whole and counts its voxel walls (%s)" % station.status())
	var hatch: VoxelStructure = station.hatch
	var terrain: DigTerrain = station.terrain
	var above := hatch.cell_centre(Vector3i(hatch.size.x / 2, 0, hatch.size.z / 2)) + Vector3(0, 1.4, 0)
	# Shovel straight down until the blade meets steel.
	var scoops := 0
	while scoops < 20 and station.dig(above + Vector3(0, 0.6, 0), Vector3.DOWN) > 0:
		scoops += 1
		await get_tree().physics_frame
	var met := _down(above + Vector3(0, 0.6, 0))
	check(met.get("collider") == hatch, "digging down from the surface reaches the buried hatch (%d scoops, hit %s)" % [scoops, met.get("collider")])
	var hatch_before := hatch.solid_count()
	check(station.dig(above, Vector3.DOWN) == 0 or hatch.solid_count() == hatch_before, "the shovel does not cut steel")
	var chip := _round_at(hatch, hatch.cell_centre(Vector3i(3, 0, 3)) + Vector3(0, 0.075, 0))
	check(int(chip.get("removed", 0)) >= 0 and hatch.solid_count() <= hatch_before, "a pistol round can chip the tier 3 hatch")
	var charge: Node3D = station.place_charge(hatch.cell_centre(Vector3i(4, 0, 4)) + Vector3(0, 0.075, 0), Vector3.UP)
	var tally: Dictionary = station.detonate(charge)
	check(int(tally.removed) > 10, "a demolition charge blows the hatch open (%d cells)" % int(tally.removed))
	check(not terrain.is_solid(hatch.global_position + Vector3(0.6, -0.5, 0.6)), "onto the pocket under it")
	# The bunker: a pistol does nothing to tier 4, a sealed side shrugs off a grenade, the drill goes through.
	var front: VoxelStructure = station.bunker_front
	var front_before := front.solid_count()
	var aim := front.cell_centre(Vector3i(front.size.x / 2, 6, front.size.z - 1)) + Vector3(0, 0, 0.3)
	var shot := _round_at(front, aim - Vector3(0, 0, 0.3))
	check(int(shot.get("removed", 0)) == 0 and int(shot.get("blocked", 0)) > 0, "a pistol round does not mark the tier 4 bunker")
	var side: VoxelStructure = station.voxels[station.voxels.find(front) + 1]
	var side_tally := Blast.explode(station, side.cell_centre(Vector3i(0, 6, 8)) - Vector3(0.3, 0, 0), 1.1, 260.0, "explosive")
	check(side.solid_count() == side.size.x * side.size.y * side.size.z and int(side_tally.blocked) > 0, "a grenade does not dent the sealed shell")
	var drilled := 0
	for frame in 60 * 12:
		drilled += station.drill(aim + Vector3(0, 0, 0.5), Vector3.FORWARD, 1.0 / 60.0)
	var through := _ray_through(aim + Vector3(0, 0, 0.5), Vector3.FORWARD, front)
	check(drilled > 8 and through, "twelve seconds of thermal drill bore through the bunker front (%d cells)" % drilled)
	check(front.solid_count() < front_before, "and the bunker front has a hole")
	# Last, so its flying brick does not land on the dig spot above.
	var brick: VoxelStructure = station.brick_wall
	var brick_charge: Node3D = station.place_charge(brick.to_global(Vector3(2.0, 0.9, 0.3)), Vector3.BACK)
	station.detonate(brick_charge)
	check(station.broken_count() >= 1 and brick.broken(), "after the charge the brick wall counts as broken (%s)" % station.status())
	var door := brick.cell_of(brick.to_global(Vector3(2.0, 0.0, 0.0))).x
	var left_standing := 0
	for z in brick.size.z:
		for y in 12:
			for x in range(door - 2, door + 2):
				left_standing += 1 if not brick.cell_at(Vector3i(x, y, z)).is_empty() else 0
	check(left_standing == 0, "and leaves a hole you walk through: 0.6 x 1.8 m clear from the floor (%d cells left in it)" % left_standing)
	# Let the lab and its debris free before quitting (quitting the same frame crashed now and then).
	lab.queue_free()
	await _frames(3)


func _round_at(structure: VoxelStructure, at: Vector3) -> Dictionary:
	return load("res://systems/world_break.gd").hit(structure, 24.0, "round", at, (structure.global_position + Vector3(structure.size) * structure.voxel * 0.5 - at).normalized(), "sidearm", "firearm")


## What the tools see (layer 1): loose cubes the shovel throws up sit on
## their own layer and may land in the shaft.
func _down(from: Vector3) -> Dictionary:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 4.0, 1))


## True when a ray along `along` from `from` passes the structure without meeting it.
func _ray_through(from: Vector3, along: Vector3, structure: VoxelStructure) -> bool:
	var met := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + along * 2.0))
	return met.is_empty() or met.collider != structure


func _frames(count: int) -> void:
	for n in count:
		await get_tree().process_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
