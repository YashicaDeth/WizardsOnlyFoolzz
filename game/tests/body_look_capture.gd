extends Node3D

## imp-60 (Greg, 5 Oct ~19:00: "improve the bodies further (checker skin,
## helmet heads, hunched idle, ankle gaps)"). The four rigged people of the
## first thirty minutes, built the way the game builds them, in one dim room:
## the player base, a numbered guard, a freed subject and the examiner. Each
## is shot from the front, the side and close on the face.
## Run windowed: render_one.cmd body_look_capture --out=DIR

const GUARD := preload("res://systems/v01_guard.gd")
const FREED := preload("res://systems/v01_freed_subject.gd")
const EXAMINER_LOOK := preload("res://systems/examiner_look.gd")

var out_dir := "P:/GameDev/Temp/body_look"
var eye: Camera3D


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	_build_room()
	var people := {
		"player": _player(),
		"guard": _guard(),
		"freed_subject": _freed(),
		"examiner": _examiner(),
	}
	var x := -2.4
	for key: String in people:
		var holder := people[key] as Node3D
		holder.position = Vector3(x, 0, 0)
		# The rig faces -Z; turn everyone to the camera.
		holder.rotation.y = PI
		x += 1.6
	eye = Camera3D.new()
	eye.fov = 40.0
	add_child(eye)
	eye.current = true
	# Long enough for the idle to settle out of its blend.
	for _frame in 90:
		await get_tree().process_frame
	_shoot_at(Vector3(0, 1.0, 7.0), Vector3(0, 0.9, 0), 45.0)
	await _capture("lineup_front")
	for key: String in people:
		var at := (people[key] as Node3D).global_position
		_shoot_at(at + Vector3(0, 1.0, 3.2), at + Vector3(0, 0.9, 0), 40.0)
		await _capture("%s_front" % key)
		_shoot_at(at + Vector3(3.2, 1.0, 0.0), at + Vector3(0, 0.9, 0), 40.0)
		await _capture("%s_side" % key)
		_shoot_at(at + Vector3(0.25, 1.62, 0.85), at + Vector3(0, 1.58, 0), 35.0)
		await _capture("%s_face" % key)
	get_tree().quit()


func _build_room() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0b0d0c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("39403a")
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(14, 10)
	floor_mesh.mesh = plane
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color("2a2b27")
	concrete.roughness = 0.95
	floor_mesh.material_override = concrete
	add_child(floor_mesh)
	# The facility's green-white overhead pool, and a warm low fill.
	var key := SpotLight3D.new()
	key.light_color = Color("dfeee0")
	key.light_energy = 6.0
	key.spot_range = 12.0
	key.spot_angle = 55.0
	key.shadow_enabled = true
	key.position = Vector3(0.6, 4.2, 3.0)
	add_child(key)
	key.look_at(Vector3(0, 0.8, 0))
	var fill := OmniLight3D.new()
	fill.light_color = Color("b48a62")
	fill.light_energy = 0.9
	fill.omni_range = 9.0
	fill.position = Vector3(-3.0, 1.2, 3.5)
	add_child(fill)


## As bone_yard_hunt builds the player: their papers, the forced rig, the outfit.
func _player() -> Node3D:
	var holder := Node3D.new()
	add_child(holder)
	var rig := BaselineHuman.new()
	rig.name = "Player"
	holder.add_child(rig)
	var config := BaselineHuman.config_from_subject({})
	config["rigged"] = true
	config["gore"] = true
	rig.build("player", config)
	rig.dress(ClothingShell.humiliation_wardrobe())
	Outfit.dress(rig)
	var look := HunterAppearance.new()
	rig.add_child(look)
	look.configure(rig, {})
	return holder


## The foes build their own bodies; their brains and hosts stay out of it.
func _guard() -> Node3D:
	var guard := GUARD.new()
	guard.configure("pistol", "07", 0.0)
	guard.set("foe_id", "look_guard_07")
	add_child(guard)
	guard.call("_build_body")
	return guard


func _freed() -> Node3D:
	var freed := FREED.new()
	freed.configure(1)
	freed.set("foe_id", "look_freed_1")
	add_child(freed)
	freed.call("_build_body")
	return freed


## As examiner_fight dresses him: the decanted base, his face axes, his mask.
func _examiner() -> Node3D:
	var holder := Node3D.new()
	add_child(holder)
	var body := BaselineHuman.new()
	body.name = "OfficeExaminer"
	holder.add_child(body)
	body.build("office_examiner", BaselineHuman.config_from_subject({"race": "decanted"}).merged({"gore": true, "rigged": true}, true))
	var appearance := HunterAppearance.new()
	body.add_child(appearance)
	appearance.configure(body, {"axes": {"brow": 0.7, "jaw": 0.6, "cheek": 0.2, "eyes": 0.3, "nose": 0.55, "mouth": 0.4}})
	EXAMINER_LOOK.dress(body, false)
	return holder


func _shoot_at(from: Vector3, at: Vector3, fov: float) -> void:
	eye.fov = fov
	eye.global_position = from
	eye.look_at(at)


func _capture(shot: String) -> void:
	for _frame in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [out_dir, shot]
	print("CAPTURED: " if get_viewport().get_texture().get_image().save_png(path) == OK else "CAPTURE_FAILED: ", path)
