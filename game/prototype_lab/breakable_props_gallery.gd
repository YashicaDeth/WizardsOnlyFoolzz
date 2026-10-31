extends Node3D

## Every `BreakableProp` kind (DESIGN/GOAL_LOOP_2.md 0.2), whole in the back
## row and broken in the front, so the silhouettes and what each one breaks
## into can be judged side by side. `-- --shot=PATH` settles the pieces and
## captures one frame; `-- --reel` breaks the back row one by one for a clip.

const PROP := preload("res://systems/breakable_prop.gd")
const WORLD_BREAK := preload("res://systems/world_break.gd")

var whole: Array[BreakableProp] = []
var broken: Array[BreakableProp] = []


func _ready() -> void:
	# Room in the shared pool for every kind at once; at a lower tier the cap
	# rightly recycles the first breaks before the shot is taken.
	WorldLook.set_quality_name("ULTRA")
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.05, 0.045, 0.05)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.32, 0.3, 0.28)
	env.environment.glow_enabled = true
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 28, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 3.0, 3.5)
	lamp.light_color = Color("d08a3c")
	lamp.omni_range = 12.0
	add_child(lamp)
	# The floor the pieces land on: a real body on the layer they collide with.
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(30, 0.2, 30)
	ground.add_child(shape)
	var slab := MeshInstance3D.new()
	var slab_mesh := BoxMesh.new()
	slab_mesh.size = Vector3(30, 0.2, 30)
	# Plain, so the pieces on it can be read.
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("3a3631")
	slab_mesh.material = floor_material
	slab.mesh = slab_mesh
	ground.add_child(slab)
	ground.position.y = -0.1
	add_child(ground)

	var reel := "--reel" in OS.get_cmdline_user_args()
	var x := -5.0
	for kind: String in PROP.KINDS:
		whole.append(PROP.place(self, kind, "gallery_%s" % kind, Vector3(x, 0, -1.4)))
		if not reel:
			broken.append(PROP.place(self, kind, "gallery_%s_broken" % kind, Vector3(x, 0, 2.2)))
		var label := Label3D.new()
		label.text = kind.to_upper()
		label.font_size = 48
		label.outline_size = 8
		label.position = Vector3(x, 2.25, -1.4)
		add_child(label)
		x += 2.0

	var cam := Camera3D.new()
	cam.fov = 58.0
	# The reel has one row, so it comes in close enough to see what flies.
	cam.position = Vector3(0, 2.1, 4.6) if reel else Vector3(0, 3.0, 7.4)
	add_child(cam)
	cam.look_at(Vector3(0, 0.45, -1.4) if reel else Vector3(0, 0.35, 0.2))

	await get_tree().physics_frame
	for prop in broken:
		_break(prop)
	if reel:
		for prop in whole:
			for _frame in 20:
				await get_tree().process_frame
			_break(prop)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shot="):
			_shoot(argument.trim_prefix("--shot="))


## Breaks it the way the breach tool does, however many blows that takes,
## struck from the camera's side as a player would strike it.
func _break(prop: BreakableProp) -> void:
	for _blow in 3:
		if not prop.broken:
			WORLD_BREAK.hit(prop, FacilityGuardPost.RAM_DAMAGE, "melee", prop.global_position, Vector3(0, 0, -1), "breach_tool", "melee")


func _shoot(path: String) -> void:
	# Long enough for the pieces to land and stop.
	for _frame in 150:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)
	get_tree().quit(0)
