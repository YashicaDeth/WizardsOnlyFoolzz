extends Node3D

## imp-63: what a blast and a break show. A charge on a brick wall throws a
## fireball, a smoke column, brick dust and sparks, leaves soot on the wall
## round the hole and a scorch on the floor; debris is shaped by material;
## the dig patch is layered topsoil / clay / rock and its spoil says which.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var ground := StaticBody3D.new()
	var plane := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	plane.shape = box
	ground.add_child(plane)
	ground.position = Vector3(0, -0.5, 0)
	add_child(ground)
	var wall := VoxelStructure.make(self, "brick", Vector3(3.0, 2.1, 0.3), Vector3(0, 1.05, 0))
	BlastFx.of(self)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var front := Vector3(0, 0.9, 0.15)
	var started := Time.get_ticks_usec()
	var tally := Blast.explode(self, front - Vector3(0, 0, 0.2), 0.85, 520.0, "charge", Vector3.BACK)
	print("FX_TIMING first_charge_ms=%.1f" % ((Time.get_ticks_usec() - started) / 1000.0))
	check(int(tally.removed) > 50, "the charge holes the brick (%d cells)" % int(tally.removed))
	var fx := BlastFx.of(self)
	check(fx != null and fx.blasts == 1, "the blast went through BlastFx")
	check(fx.smoke.count() > 30, "a smoke column and brick dust in the volume (%d parcels)" % fx.smoke.count())
	check(fx.spark_count() > 20, "sparks fly (%d)" % fx.spark_count())
	check(fx.decal_count() == 2, "a scorch and a dust coat on the floor (%d decals)" % fx.decal_count())
	var dark := 0
	for i in wall.soot.size():
		if wall.cells[i] != 0 and wall.soot[i] > 100:
			dark += 1
	check(dark > 40, "the standing brick round the hole is sooted (%d cells)" % dark)
	var smoke_before := fx.smoke.count()
	fx.break_dust(Vector3(4, 1, 0), "concrete", 3, Vector3.BACK)
	check(fx.smoke.count() > smoke_before, "a round into concrete puffs dust")
	smoke_before = fx.smoke.count()
	var sparks_before := fx.spark_count()
	fx.break_dust(Vector3(4, 1, 0), "steel_sheet", 3, Vector3.BACK)
	check(fx.smoke.count() == smoke_before and fx.spark_count() > sparks_before, "steel sparks and throws no dust")
	# Debris by material.
	var splinter := BlastFx.piece_size("wood", 0.15)
	var shard := BlastFx.piece_size("steel_sheet", 0.15)
	var chunk := BlastFx.piece_size("brick", 0.15)
	check(splinter.z > splinter.x * 4.0, "wood breaks into splinters (%s)" % splinter)
	check(shard.y < shard.x * 0.2, "steel breaks into flat shards (%s)" % shard)
	check(chunk.x > chunk.y * 1.3, "brick breaks into half-brick chunks (%s)" % chunk)
	check(BlastFx.pieces_of("concrete", 14) < BlastFx.pieces_of("wood", 14), "concrete throws fewer pieces (more dust) than wood")
	var cube := VoxelStructure.spawn_cube(self, Vector3(6, 1, 0), 0.14, "wood", Vector3.ZERO)
	var shape := (cube.get_child(1) as CollisionShape3D).shape as BoxShape3D
	check(shape.size.z > shape.size.x * 4.0, "a flying wood piece collides as a splinter (%s)" % shape.size)
	# Layered ground.
	var terrain := DigTerrain.new()
	terrain.position = Vector3(10, -3, -3)
	add_child(terrain)
	var top := terrain.surface_y()
	check(terrain.layer_at(Vector3(13, top - 0.2, 0)) == "topsoil" and terrain.layer_at(Vector3(13, top - 1.0, 0)) == "clay" and terrain.layer_at(Vector3(13, top - 2.2, 0)) == "rock",
		"the ground is topsoil, then clay, then rock")
	var look: ShaderMaterial = null
	for child in terrain.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			look = (child as MeshInstance3D).mesh.surface_get_material(0) as ShaderMaterial
			break
	check(look != null and is_equal_approx(float(look.get_shader_parameter("surface_y")), top), "the soil shader knows where the surface is")
	check(BlastFx.colour_of("clay") != BlastFx.colour_of("rock"), "clay and rock spoil look different")
	VoxelStructure.release()
	BlastFx.release()
	print("DESTRUCTION_FX_TEST_RESULT failures=%d" % failures.size())
	for label in failures:
		print("  FAIL ", label)
	get_tree().quit(0 if failures.is_empty() else 1)
