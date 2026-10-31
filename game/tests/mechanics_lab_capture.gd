extends Node

## Job 1 PROOF: one PNG per station in its "after" state, plus the whole yard.
## Windowed only (headless draws nothing and says so):
##   Godot --path game --resolution 1600x900 res://tests/mechanics_lab_capture.tscn -- --shots=P:/GameDev/Temp/mechanics_lab
## Writes yard.png, liquid.png, weather.png, destruction.png, bodies.png,
## bodies_rigged.png, bodies_wounded.png, vehicle_pad.png into the folder,
## then (tidy-80) overview.png, plan.png, one bay_N_<name>.png per bay,
## walkway_south.png and readouts.png (the SELECT dials on).

const WORLD_BREAK := preload("res://systems/world_break.gd")

var lab: Node3D
var eye: Camera3D
var shots := "P:/GameDev/Temp/mechanics_lab"


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shots="):
			shots = argument.trim_prefix("--shots=")
	DirAccess.make_dir_recursive_absolute(shots)
	BloodPool.clear()
	lab = load("res://lab/mechanics_lab.tscn").instantiate()
	add_child(lab)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	eye = Camera3D.new()
	eye.fov = 70.0
	add_child(eye)
	await _seconds(0.5)
	eye.current = true

	# Liquid: the tank broken and its spill spread.
	lab.liquid.press()
	await _seconds(3.0)
	await _shot("liquid", lab.liquid.to_global(Vector3(2.6, 1.9, 1.6)), lab.liquid.to_global(Vector3(0, 0.4, -2.0)))

	# Destruction: a round through each kind of prop, rounds and two blows on
	# the voxel walls (lab-47: brick and concrete, not the old Wall_ panels),
	# and holes in the open ground in front.
	var station = lab.destruction
	for prop: BreakableProp in station.props.duplicate():
		if prop.name.begins_with("Crate_1") or prop.name.begins_with("Pane_0") or prop.name.begins_with("Pipe_1"):
			WORLD_BREAK.hit(prop, 200.0, "round", prop.global_position, Vector3(0, 0, -1), "sniper", "firearm")
		elif prop.name.begins_with("Crate_0"):
			WORLD_BREAK.hit(prop, 44.0, "melee", prop.global_position, Vector3(0, 0, -1), "sword", "melee")
	for wall: VoxelStructure in [station.brick_wall, station.concrete_wall]:
		var front_z: float = wall.size.z * wall.voxel
		for index in 3:
			var at: Vector3 = wall.to_global(Vector3(0.4 + float(index) * 0.5, 0.6 + float(index) * 0.4, front_z))
			WORLD_BREAK.hit(wall, 200.0, "round", at, Vector3(0, 0, -1), "sniper", "firearm")
		WORLD_BREAK.hit(wall, 44.0, "melee", wall.to_global(Vector3(wall.size.x * wall.voxel - 0.5, 1.2, front_z)), Vector3(0, 0, -1), "sword", "melee")
	for index in 5:
		var at: Vector3 = station.to_global(Vector3(-1.5 + float(index) * 0.8, 3.0, 2.6))
		lab.ballistics.fire(at, Vector3(0.05, -1, 0.02), "rifle" if index % 2 == 0 else "pistol")
	await _seconds(2.0)
	await _shot("destruction", station.to_global(Vector3(1.0, 2.4, 6.0)), station.to_global(Vector3(-0.5, 0.6, -0.5)))

	# Bodies: an arm off, a dummy killed into its ragdoll, the X-ray on.
	# Job 2: the rigged skins up close, standing and untouched, X-ray off.
	await _shot("bodies_rigged", lab.bodies.to_global(Vector3(0.0, 1.5, 1.4)), lab.bodies.to_global(Vector3(0, 1.0, -1.6)))
	var rigs: Array = lab.bodies.rigs()
	var cut := Plane(Vector3.UP, (rigs[0] as BaselineHuman).parts["left_arm"].global_position)
	(rigs[0] as BaselineHuman).hit_at((rigs[0] as BaselineHuman).parts["left_arm"].global_position, 90.0, 20.0, "cut", Vector3.LEFT, -1.0, cut)
	for blow in 4:
		(rigs[2] as BaselineHuman).hit_at((rigs[2] as BaselineHuman).parts["head"].global_position, 80.0, 40.0, "ballistic", Vector3(0, 0, -1))
	lab.bodies.press()
	await _seconds(2.0)
	await _shot("bodies", lab.bodies.to_global(Vector3(0.5, 1.8, 3.4)), lab.bodies.to_global(Vector3(0, 0.9, -1.6)))
	# The same wounds and ragdoll with the X-ray off: the skin is what reads.
	lab.bodies.press()
	await _seconds(0.5)
	await _shot("bodies_wounded", lab.bodies.to_global(Vector3(-0.8, 1.4, 1.2)), lab.bodies.to_global(Vector3(-0.8, 0.7, -1.6)))

	# Weather: acid rain long enough to eat the cabinet and burn the open dummy.
	var weather = lab.weather
	weather.apply("acid")
	for second in 32:
		weather._process(1.0)
	await _seconds(2.0)
	await _shot("weather", weather.to_global(Vector3(-1.0, 2.6, 9.5)), weather.to_global(Vector3(0.5, 0.8, 0.0)))

	await _shot("vehicle_pad", lab.vehicles.to_global(Vector3(0, 6, 10)), lab.vehicles.to_global(Vector3(0, 0, 0)))
	weather.apply("storm")
	await _seconds(1.5)
	await _shot("yard", Vector3(0, 24, 34), Vector3(0, 0, 0))
	weather.apply("clear")
	await _bays()
	get_tree().quit(0)


## Tidy-80: the hall from above (with the roof, and without it as a plan),
## then each bay from its walkway edge, standing where the START menu puts
## you so the HUD reads as it would there.
func _bays() -> void:
	await _seconds(1.0)
	await _shot("overview", Vector3(0, 46, 52), Vector3(0, 0, 2))
	var roof := lab.get_node_or_null("Roof") as Node3D
	if roof != null:
		roof.visible = false
	await _shot("plan", Vector3(0, 70, 8), Vector3(0, 0, 0))
	if roof != null:
		roof.visible = true
	for index in lab.BAYS.size():
		var rect: Rect2 = lab.BAYS[index].rect
		var centre := Vector3(rect.get_center().x, 0.6, rect.get_center().y)
		var from: Vector3
		if rect.end.y <= 0.0:
			# Under the roof: from the walkway, below the roof.
			from = Vector3(centre.x, 4.0, rect.end.y + 4.0)
		elif rect.size.y > 25.0:
			from = Vector3(centre.x - 4.0, 13.0, 26.0)
		elif rect.position.y < 0.0:
			from = Vector3(centre.x - 2.0, 4.2, rect.end.y + 3.0)
			centre.z = -2.0
		else:
			from = Vector3(centre.x, 8.0, rect.end.y + 5.0)
		lab.go_to(index)
		await _seconds(0.4)
		var name := "bay_%d_%s" % [index, str(lab.BAYS[index].title).to_lower().replace(" + ", "_").replace(" ", "_")]
		await _shot(name, from, centre)
	# From the walkway, the open row's signs turned to you; then SELECT's dials.
	await _shot("walkway_south", Vector3(-6, 2.2, -1.5), Vector3(-16, 1.2, 10))
	lab.readouts = true
	await _seconds(0.3)
	await _shot("readouts", Vector3(-4, 3.0, 16), Vector3(-4, 1.0, 9))
	lab.readouts = false


func _shot(label: String, from: Vector3, at: Vector3) -> void:
	eye.global_position = from
	eye.look_at(at)
	# The dummy renderer never posts a frame; say so instead of hanging.
	if DisplayServer.get_name() == "headless":
		print("MECHANICS_LAB_CAPTURE %s: headless, nothing rendered" % label)
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		print("MECHANICS_LAB_CAPTURE %s: nothing rendered (headless?)" % label)
		return
	var path := "%s/%s.png" % [shots, label]
	image.save_png(path)
	print("MECHANICS_LAB_CAPTURE ", path)


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
