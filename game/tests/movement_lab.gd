extends Node3D

## Playable movement proving ground: flat acceleration, diagonal travel, a
## narrow doorway, a low curb, opposing ramps and a snag-prone inside corner.
## In ATG_TEST_MODE it validates the exact movement helper used by the Hunt.

const MOTOR := preload("res://systems/hunter_motor.gd")
var body: CharacterBody3D
var camera: Camera3D
var yaw := 0.0
var pitch := -0.14
var failures: Array[String] = []
var automated := false


func _ready() -> void:
	_build_course()
	_build_player()
	automated = OS.get_environment("ATG_TEST_MODE") == "1" and not _is_capture_run()
	if automated:
		await _run_checks()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if automated:
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	MOTOR.move_body(body, MOTOR.wish_direction(input, yaw), 7.0 if not Input.is_action_pressed("sprint") else 12.0, delta)
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0026
		pitch = clampf(pitch - event.relative.y * 0.0024, -0.75, 0.42)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build_player() -> void:
	body = CharacterBody3D.new()
	body.name = "MovementProbe"
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.8
	collision.shape = capsule
	body.add_child(collision)
	add_child(body)
	body.position = Vector3(0, 1.0, -8)
	MOTOR.configure(body)
	var rig := BaselineHuman.new()
	body.add_child(rig)
	rig.position.y = -0.9
	rig.build("movement_probe", {"gore": false, "flesh": Color("6f5a49")})
	camera = Camera3D.new()
	camera.current = true
	add_child(camera)
	_update_camera()


func _build_course() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = WorldLook.environment("ashbloom")
	add_child(environment)
	_static_box("Floor", Vector3(0, -0.5, 5), Vector3(24, 1, 34), Vector3.ZERO, Color("24251b"))
	_static_box("WallLeft", Vector3(-2.3, 1.2, 2), Vector3(3.6, 2.4, 0.45), Vector3.ZERO, Color("44332a"))
	_static_box("WallRight", Vector3(2.3, 1.2, 2), Vector3(3.6, 2.4, 0.45), Vector3.ZERO, Color("44332a"))
	_static_box("Curb", Vector3(-5, 0.1, -1), Vector3(3.5, 0.2, 2), Vector3.ZERO, Color("6a5037"))
	_static_box("Ramp", Vector3(5, 0.45, 3), Vector3(3.5, 0.35, 6), Vector3(-0.18, 0, 0), Color("59603b"))
	_static_box("SnagA", Vector3(-5, 1.2, 9), Vector3(0.5, 2.4, 7), Vector3.ZERO, Color("3e2b24"))
	_static_box("SnagB", Vector3(-2, 1.2, 12.2), Vector3(6, 2.4, 0.5), Vector3.ZERO, Color("3e2b24"))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.light_energy = 1.5
	light.shadow_enabled = true
	add_child(light)
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.text = "MOVEMENT LAB / W FORWARD / S BACK / A-D STRAFE\nDOOR / CURB / RAMP / INSIDE CORNER"
	label.position = Vector2(24, 24)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("dce6ba"))
	layer.add_child(label)


func _static_box(node_name: String, at: Vector3, dimensions: Vector3, rotation_value: Vector3, tint: Color) -> void:
	var solid := StaticBody3D.new()
	solid.name = node_name
	solid.position = at
	solid.rotation = rotation_value
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	solid.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh.material = WorldLook.surface(tint, "dirt", node_name.hash())
	mesh_instance.mesh = mesh
	solid.add_child(mesh_instance)
	add_child(solid)


func _update_camera() -> void:
	var forward := MOTOR.camera_forward(yaw)
	var look := Vector3(forward.x * cos(pitch), sin(pitch), forward.z * cos(pitch)).normalized()
	var focus := body.global_position + Vector3.UP * 0.6
	var desired := body.global_position - look * 5.5 + Vector3.UP * 1.4
	camera.global_position = MOTOR.collision_safe_camera(get_world_3d().direct_space_state, focus, desired, [body.get_rid()])
	camera.look_at(focus + look * 4)


func _is_capture_run() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--scene="):
			return true
	return false


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _run_checks() -> void:
	check(MOTOR.wish_direction(Vector2(0, -1), 0).dot(Vector3.BACK) > 0.99, "W follows camera forward")
	check(MOTOR.wish_direction(Vector2(0, 1), 0).dot(Vector3.FORWARD) > 0.99, "S moves behind camera")
	# These two used to read `.dot(Vector3.LEFT)` and `.dot(Vector3.RIGHT)`, and
	# that is how an inverted strafe survived: the line above establishes that
	# the player faces `Vector3.BACK` at yaw 0, so pinning A and D against the
	# world's LEFT and RIGHT treated the player as facing the other way for two
	# of the four keys. A test written in world axes cannot catch a frame error,
	# because it is making the same assumption the code is.
	#
	# Strafing right is turning ninety degrees right and walking forward. That
	# is what the input means, it holds at any yaw, and an inverted right vector
	# cannot satisfy it. Mouse-right decreases yaw, so right is `yaw - PI/2`.
	for at_yaw: float in [0.0, PI * 0.5, PI, -PI * 0.75]:
		var strafe_right := MOTOR.wish_direction(Vector2(1, 0), at_yaw)
		var strafe_left := MOTOR.wish_direction(Vector2(-1, 0), at_yaw)
		check(strafe_right.dot(MOTOR.camera_forward(at_yaw - PI * 0.5)) > 0.99,
			"D at yaw %.2f goes where turning right would take you" % at_yaw)
		check(strafe_left.dot(MOTOR.camera_forward(at_yaw + PI * 0.5)) > 0.99,
			"A at yaw %.2f goes where turning left would take you" % at_yaw)
		check(strafe_right.dot(MOTOR.camera_forward(at_yaw)) < 0.01,
			"and strafing at yaw %.2f is square to the way you are facing" % at_yaw)
	check(is_equal_approx(MOTOR.wish_direction(Vector2(1, -1), 0).length(), 1.0), "diagonal input has no speed boost")
	check(MOTOR.wish_direction(Vector2(0, -1), PI * 0.5).dot(Vector3.RIGHT) > 0.99, "movement rotates with camera yaw")
	check(is_equal_approx(body.floor_snap_length, 0.42), "floor snap crosses curbs and descending ramps")
	check(body.floor_max_angle >= deg_to_rad(49), "walkable slope allowance is configured")
	for frame in 10:
		await get_tree().physics_frame
	var camera_clamped := MOTOR.collision_safe_camera(
		get_world_3d().direct_space_state,
		Vector3(1, 1, 0),
		Vector3(1, 1, 4),
		[body.get_rid()]
	)
	check(camera_clamped.z < 1.8, "third-person camera cannot pass through the doorway wall")
	check(MOTOR.third_person_clearance_blend(Vector3.ZERO, Vector3(0, 0, 0.4)) < 0.01,
		"a camera crushed onto the body yields to first-person framing")
	check(MOTOR.third_person_clearance_blend(Vector3.ZERO, Vector3(0, 0, 2.0)) > 0.99,
		"a clear shoulder camera preserves full third-person framing")
	var before := body.position
	for frame in 35:
		MOTOR.move_body(body, MOTOR.wish_direction(Vector2(0, -1), 0), 7.0, 1.0 / 60.0)
		await get_tree().physics_frame
	check(body.position.z > before.z + 1.0, "physical W motion advances through the course")
	check(absf(body.position.x - before.x) < 0.15, "forward travel does not drift sideways")
	print("MOVEMENT_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
