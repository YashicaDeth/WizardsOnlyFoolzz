extends Node

## Staged gore capture: a dressed body bleeding onto the floor, pools growing,
## prints walking out. Saves viewport PNGs for a human to open — per the house
## rule, no visual claim without looking. Run WINDOWED, not headless: headless
## has no renderer and captures black.
##
## Usage (from P:/GameDev/AllusionsTooGrandeur):
##   TEMP=P:/GameDev/Temp TMP=P:/GameDev/Temp \
##   "P:/GameDev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe" \
##   --path game res://tests/brutalism_capture.tscn -- --capture="P:/GameDev/Temp/brutalism.png"

const GARMENT := preload("res://systems/clothing_shell.gd")
const POOL := preload("res://systems/blood_pool.gd")
const PRINTS := preload("res://systems/footprints.gd")
const RIG := preload("res://systems/baseline_human.gd")

var failures: Array[String] = []


func check(c: bool, label: String) -> void:
	print("PASS " if c else "FAIL ", label)
	if not c:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	POOL.clear()
	PRINTS.clear()

	# --- a room to bleed in ----------------------------------------------------
	var camera := Camera3D.new()
	# Close enough to read cloth from skin: the garment question cannot be
	# answered from across the room.
	camera.position = Vector3(0.85, 1.25, 1.35)
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.9, 0.0))
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0.0)
	sun.light_energy = 1.1
	add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.5, 2.2, 1.5)
	fill.light_energy = 0.7
	add_child(fill)
	var floor_body := StaticBody3D.new()
	add_child(floor_body)
	var floor_shape := CollisionShape3D.new()
	var plane := WorldBoundaryShape3D.new()
	floor_shape.shape = plane
	floor_body.add_child(floor_shape)
	var floor_mesh := MeshInstance3D.new()
	var grid := PlaneMesh.new()
	grid.size = Vector2(12.0, 12.0)
	floor_mesh.mesh = grid
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color("4a4642")
	concrete.roughness = 0.95
	floor_mesh.material_override = concrete
	add_child(floor_mesh)

	# --- the body: dressed, shot twice, bleeding --------------------------------
	var rig: BaselineHuman = RIG.new()
	add_child(rig)
	rig.build("capture_dummy", {})
	await get_tree().process_frame
	rig.position = Vector3.ZERO
	rig.dress(GARMENT.fresh_wardrobe())
	var torso := rig.parts.get("torso") as Node3D
	# One round: enough to bleed and soak, not enough to breach — the jacket
	# has to survive staging or there is nothing to photograph.
	var at := torso.global_position + Vector3(-0.04, 0.10, 0.16)
	rig.hit_at(at, 34.0, 7.0, "ballistic", Vector3(0, 0, -1))
	check(float(rig.anatomy.bleed_rate) > 0.0, "sanity: the staged body bleeds")

	# --- pre-grown evidence so one frame shows every system ----------------------
	POOL.keep(self, Vector3(0.5, 0.0, 0.4), 30.0)
	POOL.keep(self, Vector3(-0.6, 0.0, -0.2), 12.0)
	PRINTS.step(self, self, Vector3(0.5, 0.0, 0.4), "left")
	for stride in 6:
		PRINTS.step(self, self, Vector3(0.9 + float(stride) * 0.35, 0.0, 0.4 - float(stride) * 0.12), "left" if stride % 2 == 0 else "right")

	# Let drips fall, streaks lengthen, and the renderer settle.
	var waited := 0.0
	while float(rig.get("_bleed_seconds")) < 4.0 and waited < 25.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	check(float(rig.get("_bleed_seconds")) >= 4.0, "four seconds of bleeding staged (%.1fs)" % float(rig.get("_bleed_seconds")))
	check(POOL.pool_count(self) >= 2, "pools on the floor (%d)" % POOL.pool_count(self))
	check(PRINTS.print_count(self) >= 4, "prints walking out (%d)" % PRINTS.print_count(self))
	var garment_node := (rig.parts.get("torso") as Node3D).get_node_or_null("Garment")
	check(garment_node != null, "garment rendered on the staged body")

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var path := argument.trim_prefix("--capture=")
			var image := get_viewport().get_texture().get_image()
			check(image.save_png(path) == OK, "staged capture saved to %s" % path)

	print("BRUTALISM_CAPTURE_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
