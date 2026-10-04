extends Node

## ads-01. Aiming a firearm puts the eye on the line through the gun's rear
## and front sight, narrows the field, keeps the gun in view, steps further
## down the sight on L3 / SHIFT, sends the round down that line, and comes
## back out on release. Hip fire stays where it was.

const HUNT := preload("res://bone_yard_hunt.tscn")
const ADS := preload("res://systems/aim_down_sights.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _mouse(button: MouseButton, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	return event


func _key(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	return event


func _settle(hunt: Node, frames := 40) -> void:
	# The physics frame's order: the hand poses the gun, then the camera.
	for frame in frames:
		hunt._pose_weapon()
		hunt._update_camera()


## Rear and front sight in world space, off the live mount.
func _sights(hunt: Node) -> Array:
	var mount := hunt.arsenal.models[hunt.arsenal.current_id] as Node3D
	var local: Array = ADS.sight_points(mount)
	return [mount.global_transform * (local[0] as Vector3), mount.global_transform * (local[1] as Vector3)]


func _off_axis(camera: Camera3D, point: Vector3) -> float:
	var forward := -camera.global_transform.basis.z.normalized()
	var rel := point - camera.global_position
	return (rel - forward * rel.dot(forward)).length()


func _check_sight_line(hunt: Node, label: String) -> float:
	var camera: Camera3D = hunt.camera
	var points := _sights(hunt)
	var rear: Vector3 = points[0]
	var front: Vector3 = points[1]
	var forward := -camera.global_transform.basis.z.normalized()
	var rear_depth := (rear - camera.global_position).dot(forward)
	var front_depth := (front - camera.global_position).dot(forward)
	print("  %s: rear off-axis %.4f depth %.3f, front off-axis %.4f depth %.3f, fov %.1f" % [label, _off_axis(camera, rear), rear_depth, _off_axis(camera, front), front_depth, camera.fov])
	check(_off_axis(camera, rear) < 0.004 and _off_axis(camera, front) < 0.004,
		"%s: rear and front sight both sit on the eye's forward axis" % label)
	check(rear_depth > camera.near and front_depth > rear_depth,
		"%s: rear sight in front of the eye, front sight beyond it" % label)
	check((front - rear).normalized().dot(forward) > 0.9999,
		"%s: the barrel points where the eye looks" % label)
	return rear_depth


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var hunt := HUNT.instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Open ground, the spot the third-person route test uses: the spawn wreck
	# collapses the shoulder camera onto the eye and would prove nothing.
	hunt.player_body.position = Vector3(0.0, 0.9, 19.0)
	hunt.player_body.velocity = Vector3.ZERO
	hunt.player = hunt.player_body.position + Vector3.UP * 0.6
	hunt.yaw = 0.0
	hunt.pitch = 0.0
	var camera: Camera3D = hunt.camera

	# Hip: nothing about the unaimed gun moves.
	hunt._equip_weapon(2)
	check(str(hunt.arsenal.current().kind) == "firearm", "slot 2 is a firearm")
	_settle(hunt)
	var hip_fov: float = camera.fov
	var mount := hunt.arsenal.models[hunt.arsenal.current_id] as Node3D
	var hip_mount: Transform3D = mount.transform
	check(not hunt.ads.has_line, "hip carry leaves the gun in the hand")
	var rounds: Array = hunt.ballistics.rounds
	var before := rounds.size()
	hunt._resolve_firearm(hunt.arsenal.begin_attack())
	var hip_round: Dictionary = hunt.ballistics.rounds.back()
	var hip_forward := Vector3(sin(hunt.yaw) * cos(hunt.pitch), sin(hunt.pitch), cos(hunt.yaw) * cos(hunt.pitch)).normalized()
	check(hunt.ballistics.rounds.size() > before and (hip_round.origin as Vector3).distance_to(camera.global_position + hip_forward * 0.48) < 0.001,
		"hip fire leaves from where it always did")
	hunt.arsenal.cooldown = 0.0

	# Aim: first person.
	hunt._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT, true))
	check(hunt.firearm_aiming, "RMB / L2 shoulders the firearm")
	_settle(hunt)
	check(hunt.firearm_aim_blend > 0.99 and hunt.ads.has_line, "the sight comes up")
	var stage_one_depth := _check_sight_line(hunt, "stage 1")
	var stage_one_fov: float = camera.fov
	check(stage_one_fov < hip_fov - 15.0, "aiming narrows the field (%.1f -> %.1f)" % [hip_fov, stage_one_fov])
	check(mount.visible and mount.is_visible_in_tree(), "the weapon is drawn in view")
	var size := camera.get_viewport().get_visible_rect().size
	var front_screen := camera.unproject_position(_sights(hunt)[1])
	check(not camera.is_position_behind(_sights(hunt)[1]) and front_screen.distance_to(size * 0.5) < maxf(size.x, size.y) * 0.02,
		"the front sight is on the screen centre, where the round goes")
	var first_eye := camera.global_position

	# The round goes down the barrel.
	before = hunt.ballistics.rounds.size()
	hunt._resolve_firearm(hunt.arsenal.begin_attack())
	var aimed_round: Dictionary = hunt.ballistics.rounds.back()
	var points := _sights(hunt)
	var line := ((points[1] as Vector3) - (points[0] as Vector3)).normalized()
	var origin: Vector3 = aimed_round.origin
	var rel := origin - (points[0] as Vector3)
	check(hunt.ballistics.rounds.size() > before and (rel - line * rel.dot(line)).length() < 0.002 and rel.dot(line) > 0.0,
		"the aimed round starts on the sight line, ahead of the rear sight")
	check((aimed_round.initial_direction as Vector3).angle_to(line) < 0.01,
		"the aimed round travels along the sight line")
	check(hunt.ads.kick > 0.0, "an aimed shot kicks the gun")
	hunt.arsenal.cooldown = 0.0
	_settle(hunt, 60)
	_check_sight_line(hunt, "after recoil settles")

	# Further down the sight: SHIFT on the keyboard...
	hunt._unhandled_input(_key(KEY_SHIFT, true))
	hunt._unhandled_input(_key(KEY_SHIFT, false))
	check(hunt.ads.stage == 2, "SHIFT while aimed steps further down the sight")
	_settle(hunt)
	var stage_two_depth := _check_sight_line(hunt, "stage 2")
	check(camera.fov < stage_one_fov - 8.0, "stage 2 narrows again (%.1f -> %.1f)" % [stage_one_fov, camera.fov])
	check(stage_two_depth < stage_one_depth - 0.05, "stage 2 brings the eye closer to the rear sight")
	hunt._unhandled_input(_key(KEY_SHIFT, true))
	hunt._unhandled_input(_key(KEY_SHIFT, false))
	_settle(hunt)
	check(hunt.ads.stage == 1 and absf(camera.fov - stage_one_fov) < 0.5, "clicking again steps back to the first sight")

	# ...and L3 on the pad, through PadBridge as the real pad goes.
	var stick := InputEventJoypadButton.new()
	stick.button_index = JOY_BUTTON_LEFT_STICK
	stick.pressed = true
	Input.parse_input_event(stick)
	Input.flush_buffered_events()
	await get_tree().process_frame
	Input.flush_buffered_events()
	await get_tree().process_frame
	check(hunt.ads.stage == 2, "L3 on the pad steps further down the sight")
	var release := InputEventJoypadButton.new()
	release.button_index = JOY_BUTTON_LEFT_STICK
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await get_tree().process_frame

	# Third person: aiming still goes to the eye, not the shoulder.
	hunt._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT, false))
	hunt.third_person = true
	hunt.perspective_blend = 1.0
	_settle(hunt)
	var shoulder_gap: float = camera.global_position.distance_to(first_eye)
	print("  third person, unaimed: camera %.3f m from the eye" % shoulder_gap)
	check(shoulder_gap > 1.0, "the unaimed third-person camera really is out at the shoulder")
	hunt._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT, true))
	_settle(hunt)
	check(camera.global_position.distance_to(first_eye) < 0.08,
		"from third person, aiming brings the camera to the eye (%.3f m)" % camera.global_position.distance_to(first_eye))
	_check_sight_line(hunt, "aimed from third person")

	# Release: back out, and the zoom does not stick.
	hunt._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT, false))
	check(not hunt.firearm_aiming, "releasing lowers the firearm")
	_settle(hunt)
	check(hunt.firearm_aim_blend < 0.01 and hunt.ads.stage == 1 and not hunt.ads.has_line, "the sight blends back down and the stage resets")
	print("  released third person: camera %.3f m from the eye" % camera.global_position.distance_to(first_eye))
	check(absf(camera.global_position.distance_to(first_eye) - shoulder_gap) < 0.1, "released in third person, the camera returns to the shoulder")
	hunt.third_person = false
	hunt.perspective_blend = 0.0
	_settle(hunt)
	check(absf(camera.fov - hip_fov) < 0.5, "the field returns to the hip view")
	hunt._pose_weapon()
	check(mount.transform.origin.distance_to(hip_mount.origin) < 0.02 and mount.transform.basis.get_euler().distance_to(hip_mount.basis.get_euler()) < 0.05,
		"the gun goes back to the hand")

	# The shotgun has its own sight line.
	hunt._equip_weapon(1)
	if str(hunt.arsenal.current_id) == "shotgun":
		hunt._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT, true))
		_settle(hunt)
		_check_sight_line(hunt, "shotgun")
		hunt._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT, false))
		_settle(hunt)

	# SHIFT unaimed is still sprint, not a zoom.
	hunt._unhandled_input(_key(KEY_SHIFT, true))
	hunt._unhandled_input(_key(KEY_SHIFT, false))
	check(hunt.ads.stage == 1, "SHIFT without aiming does not touch the sight")

	print("AIM_DOWN_SIGHTS_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
