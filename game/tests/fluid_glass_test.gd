extends Node

## lab-46: GlassTank + FluidBody in the mechanics lab's liquid station.
## Crack stages, the burst (shards thrown out), the pour, a pool that is
## still there after 60 s, wading, and a shock that reaches a dummy standing
## in the pool and not one on dry floor. Prints the sim cost while pouring.

var failures: Array[String] = []
var lab: Node3D


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	BloodPool.clear()
	Footprints.clear()
	lab = load("res://lab/mechanics_lab.tscn").instantiate()
	add_child(lab)
	await _frames(3)
	var station = lab.liquid
	var tank: GlassTank = station.tank
	var fluid: FluidBody = station.fluid
	var face: Vector3 = tank.body.global_position + Vector3(0, 0.2, tank.radius)

	var material := tank.body.get_node("Wall").mesh.surface_get_material(0) as ShaderMaterial
	var last := 0.0
	for stage in range(1, tank.blows):
		var result: Dictionary = station.strike(face + Vector3(0.1 * stage, 0.1 * stage, 0), Vector3.FORWARD)
		var crack := float(material.get_shader_parameter("crack"))
		check(not result.broken and tank.crack_stage() == stage and crack > last, "blow %d cracks the glass a stage (crack %.2f)" % [stage, crack])
		last = crack
	check(not tank.broken and fluid.blob_count() == 0, "cracked glass still holds")

	station.strike(face, Vector3.FORWARD)
	check(tank.broken, "the last blow bursts it")
	check(tank.shards.size() == GlassTank.COLUMNS * GlassTank.ROWS * 2, "into %d shards" % tank.shards.size())
	await _frames(2)
	var outward := 0
	for shard in tank.shards:
		var radial := Vector3(shard.global_position.x - tank.global_position.x, 0, shard.global_position.z - tank.global_position.z).normalized()
		if shard.linear_velocity.dot(radial) > 0.0:
			outward += 1
	check(outward > tank.shards.size() * 0.7, "the fluid throws most of them outward (%d)" % outward)

	# The pour: several seconds, slowing, the stub keeping the bottom.
	var worst := 0
	var peak := 0
	for frame in 60:
		var start := Time.get_ticks_usec()
		fluid._physics_process(0.0)
		worst = maxi(worst, Time.get_ticks_usec() - start)
		peak = maxi(peak, fluid.blob_count())
		await _frames(1)
	check(peak > 40, "a pour, not a trickle (%d blobs in the air)" % peak)
	var level_1s: float = tank.level
	check(level_1s < 1.0 and level_1s > 0.2, "one second in the tank is part drained (%.2f)" % level_1s)
	await _seconds(7.0)
	check(tank.level < level_1s and tank.level > 0.0, "it drained to the stub and kept the rest (%.2f)" % tank.level)
	check(fluid.blob_count() == 0, "and the pour has landed")
	var poured: float = fluid.volume()
	check(poured > tank.spill_volume * 0.6, "the floor holds the spill (%.1f L of %.1f)" % [poured * 1000.0, tank.spill_volume * 1000.0])
	check(fluid.wet_cells() > 60, "spread across the floor (%d cells)" % fluid.wet_cells())
	print("FLUID_GLASS_PERF sim worst %d us per frame while pouring, %d blobs peak" % [worst, peak])
	check(worst < 6000, "the sim fits a 144 fps frame on this CPU (%d us)" % worst)

	# Persistence: a minute later it is still there, a little gone to the grate.
	fluid.simulate(60.0, 1.0 / 30.0)
	check(fluid.volume() > poured * 0.5, "after 60 s the pool persists (%.1f L)" % (fluid.volume() * 1000.0))
	check(fluid.wet_cells() > 40, "still covering the floor (%d cells)" % fluid.wet_cells())
	print("FLUID_GLASS drained to grate %.2f L in 60 s" % (fluid.drained * 1000.0))

	# Wading.
	var feet: Vector3 = station.wet_dummy.global_position + Vector3(0.3, 0, 0)
	check(fluid.wet_at(feet), "the floor by the wet dummy is wet")
	var splashes_before: int = fluid.splashes
	for step in 40:
		station.wade(lab.player, feet + Vector3(0.05 * step, 0, 0), Vector3(3, 0, 0), 1.0 / 60.0)
	check(fluid.splashes > splashes_before, "wading splashes")
	check(Footprints.print_count(lab) > 0, "and leaves wet prints (%d)" % Footprints.print_count(lab))
	var rippling := false
	for value in fluid.ripple:
		if absf(value) > 0.0001:
			rippling = true
			break
	fluid._step_grid(1.0 / 30.0)
	check(rippling, "and ripples")

	# Current.
	var wet: BaselineHuman = station.wet_dummy
	var dry: BaselineHuman = station.dry_dummy
	check(fluid.wet_at(wet.global_position), "the wet dummy stands in the pool")
	check(not fluid.wet_at(dry.global_position), "the dry dummy does not")
	var wet_before := _hp(wet)
	var dry_before := _hp(dry)
	var struck: Array = station.shock(fluid.global_position + Vector3(0, 0, 1.0))
	check(struck.has(wet) and _hp(wet) < wet_before, "the shock reaches the dummy in the pool (%.1f -> %.1f)" % [wet_before, _hp(wet)])
	check(not struck.has(dry) and is_equal_approx(_hp(dry), dry_before), "and not the one on dry floor")
	# Drawn here rather than after a frame: the 60 s simulate makes the next
	# process delta longer than the shock lasts.
	fluid._draw_arcs()
	check(fluid.shock_left > 0.0 and fluid.get_node("Arcs").visible, "arcs crawl over the wet floor")

	# Refill resets.
	station.press()
	check(not tank.broken and fluid.volume() == 0.0, "USE again refills")

	print("FLUID_GLASS_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _hp(rig: BaselineHuman) -> float:
	return rig.zone_health("left_leg") + rig.zone_health("right_leg") + rig.zone_health("torso")


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().physics_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
