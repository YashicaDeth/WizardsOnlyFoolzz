extends Node

## imp-61: the pour as one surface, splashes where it lands, a pool that
## flows around solids instead of under them, and the sounds. Greg (5 Oct
## ~19:00): "Fix and improve the pour (a real liquid surface, not spheres)
## and add sound." Headless: it proves the wiring and the simulation; how the
## surface looks is proven by tests/fluid_glass_capture.tscn through
## render_one.cmd.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	await _obstacle_alone()
	await _sphere_fallback()
	await _station()
	print("FLUID_SURFACE_SOUND_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## A FluidBody on a bare floor with one crate standing in it: fluid poured
## beside the crate goes round it, never under it.
func _obstacle_alone() -> void:
	var room := Node3D.new()
	add_child(room)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(10, 0.2, 10)
	floor_shape.shape = slab
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0, -0.1, 0)
	room.add_child(floor_body)
	var crate := StaticBody3D.new()
	var crate_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 0.6, 0.6)
	crate_shape.shape = box
	crate.add_child(crate_shape)
	crate.position = Vector3(0.6, 0.3, 0)
	room.add_child(crate)
	var fluid := FluidBody.new()
	room.add_child(fluid)
	fluid.setup(room, 1.92, Vector2(1.7, 1.7))
	await _frames(2)
	for drop in 40:
		fluid.deposit(Vector3(0.0, 0, 0), 0.0006)
	# A blob landing on the crate's top runs off to open floor.
	fluid.deposit(Vector3(0.6, 0, 0), 0.0006)
	fluid.simulate(6.0, 1.0 / 30.0)
	check(fluid.obstacles_scanned and fluid.blocked_cells() >= 16, "the crate's cells read as solid (%d)" % fluid.blocked_cells())
	check(not fluid.blocked_at(fluid.to_global(Vector3(-1.0, 0, 0))), "open floor does not")
	var under := 0.0
	for index in fluid.depth.size():
		if fluid.blocked[index] == 1:
			under += fluid.depth[index]
	check(under == 0.0, "no fluid under the crate")
	check(fluid.wet_at(fluid.to_global(Vector3(1.0, 0, 0.0))), "it went round to the far side")
	check(is_equal_approx(snappedf(fluid.volume(), 0.000001), snappedf(fluid.landed, 0.000001)), "and none was lost (%.2f L of %.2f)" % [fluid.volume() * 1000.0, fluid.landed * 1000.0])
	room.queue_free()
	await _frames(1)


func _sphere_fallback() -> void:
	var fluid := FluidBody.new()
	fluid.surface = false
	add_child(fluid)
	fluid.setup(self, 1.0, Vector2(0.5, 0.0))
	check(fluid.get_node_or_null("Pour") is MultiMeshInstance3D and fluid.get_node_or_null("Surface") == null, "surface off: the old spheres")
	fluid.emit(fluid.to_global(Vector3(0, 1, 0)), Vector3.ZERO, 0.0001)
	fluid.simulate(1.5)
	check(fluid.blob_count() == 0 and fluid.landed > 0.0, "and they still pour and land")
	fluid.queue_free()
	await _frames(1)


func _station() -> void:
	WorldHistory.clear_history()
	BloodPool.clear()
	Footprints.clear()
	FluidSound.reset_counts()
	var lab: Node3D = load("res://lab/mechanics_lab.tscn").instantiate()
	add_child(lab)
	await _frames(3)
	var station = lab.liquid
	var tank: GlassTank = station.tank
	var fluid: FluidBody = station.fluid
	var surface := fluid.get_node_or_null("Surface") as FluidSurface
	check(surface != null and fluid.get_node_or_null("Pour") == null, "the station's pour draws as a surface, not spheres")
	check(surface != null and surface.multimesh.instance_count == FluidBody.MAX_BLOBS and surface.viewport.own_world_3d, "its splats live in their own world (no game camera sees them)")

	var face: Vector3 = tank.body.global_position + Vector3(0, 0.2, tank.radius)
	for stage in range(1, tank.blows):
		station.strike(face + Vector3(0.1 * stage, 0.1 * stage, 0), Vector3.FORWARD)
	check(FluidSound.count("glass_crack_1") == 1 and FluidSound.count("glass_crack_2") == 1 and FluidSound.count("glass_crack_3") == 1, "a crack sound per stage")
	station.strike(face, Vector3.FORWARD)
	check(FluidSound.count("glass_burst") == 1 and FluidSound.count("fluid_gush") == 1, "the burst and the gush")
	check(tank._pour_sound != null and tank._pour_sound.stream != null, "and a pour loop")

	var droplets := 0
	for frame in 90:
		await _frames(1)
		for size in fluid._size:
			if size < 1.0:
				droplets += 1
	check(fluid.impact_splashes > 0, "landings splash (%d crowns)" % fluid.impact_splashes)
	check(droplets > 0, "crown droplets fly (%d droplet-frames)" % droplets)
	check(FluidSound.count("fluid_splash") + FluidSound.count("fluid_splat") > 0, "splashes heard (%d splash, %d splat)" % [FluidSound.count("fluid_splash"), FluidSound.count("fluid_splat")])
	await _seconds(7.0)
	check(fluid.blob_count() == 0, "the pour has landed")
	check(tank._pour_sound == null or not tank._pour_sound.playing, "and the pour sound stopped with it")

	check(fluid.blocked_at(tank.global_position), "the plinth reads as solid")
	var under := 0.0
	for index in fluid.depth.size():
		if fluid.blocked[index] == 1:
			under += fluid.depth[index]
	check(under == 0.0, "nothing pooled under the plinth or the props")
	check(fluid.volume() > tank.spill_volume * 0.6, "the floor still holds the spill (%.1f L)" % (fluid.volume() * 1000.0))

	var feet: Vector3 = station.wet_dummy.global_position + Vector3(0.3, 0, 0)
	for step in 40:
		station.wade(lab.player, feet + Vector3(0.05 * step, 0, 0), Vector3(3, 0, 0), 1.0 / 60.0)
	check(FluidSound.count("wade_1") + FluidSound.count("wade_2") + FluidSound.count("wade_3") > 0, "wading is heard")
	lab.queue_free()
	await _frames(1)


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().physics_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
