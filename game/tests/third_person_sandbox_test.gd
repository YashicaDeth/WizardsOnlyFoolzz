extends Node

## Greg, 30 September: the sandbox is where melee is tested in first AND third
## person, and third person "breaks". V used to flip a flag and nothing else.
## Now: a body on the player's feet, the shoulder camera, a lock, blows that
## leave the body rather than the lens, and a mouse that is only the camera.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var demo = load("res://gore_demo.tscn").instantiate()
	add_child(demo)
	await _frames(3)
	var avatar: SandboxAvatar = demo.avatar

	# --- First person is unchanged: the eye, the viewmodel, no body. ---
	check(demo.camera.global_position.distance_to(demo.eye) < 0.05, "first person: the camera is the eye")
	check(not avatar.visible and demo.view_gear.visible, "first person: no body in view, the viewmodel in hand")

	# --- V: over the shoulder. ---
	demo.third_person = true
	avatar.third_person = true
	await _frames(90)
	var look: Vector3 = -demo.camera.global_transform.basis.z
	var back: Vector3 = demo.camera.global_position - demo.eye
	check(avatar.visible and not demo.view_gear.visible, "third person: the body shows and the floating viewmodel hides")
	check(back.length() > 2.0 and back.dot(look) < 0.0, "the camera sits behind the head (%.2f m back)" % back.length())
	check(absf(avatar.global_position.y) < 0.05 and Vector2(avatar.global_position.x - demo.eye.x, avatar.global_position.z - demo.eye.z).length() < 0.01, "the body stands on the player's feet")
	check(absf(demo.camera.fov - SandboxAvatar.THIRD_PERSON_FOV) < 1.0, "at the third-person field of view (%.1f)" % demo.camera.fov)

	# --- Your own body never stops your own trace. ---
	var through: Dictionary = demo._trace_body(demo.camera.global_position, (demo.eye - demo.camera.global_position).normalized())
	check(through.is_empty() or through.get("rig") != avatar.rig, "a trace from behind passes through your own body")

	# --- Keys drive the third-person swing, one side each. ---
	demo.arsenal.select_slot(HunterArsenal.SLOT_ORDER.find("sword"))
	for side in [BladeRead.LEFT, BladeRead.RIGHT, BladeRead.HIGH, BladeRead.LOW]:
		await _frames(40)
		demo._tp_swing_side = side
		demo._tp_swing_left = 0.2
		await _frames(8)
		check(BladeRead.swing_side(demo.arm.velocity) == side, "a %s swing drives the arm %s (read %s)" % [side, side, BladeRead.swing_side(demo.arm.velocity)])
	await _frames(40)

	# --- Z locks the nearest body in view; the blow goes to it. ---
	var target: Dictionary = demo.bodies[0]
	var holder := target.holder as Node3D
	var away := Vector3(holder.global_position.x, 0.0, holder.global_position.z) + Vector3(0.0, 0.0, 1.6)
	demo.eye = Vector3(away.x, demo.stance_height, away.z)
	demo.yaw = 0.0
	demo.pitch = -0.1
	await _frames(2)
	check(avatar.toggle_lock(demo.bodies, demo.eye, Vector3(0, 0, -1)) and avatar.lock_target == holder, "Z locks the body in front")
	var strike: Vector3 = avatar.strike_direction(demo.eye)
	var toward: Vector3 = (holder.global_position - demo.eye).normalized()
	check(strike.dot(toward) > 0.95, "the blow heads at the lock, not where the camera points")
	demo.yaw = 1.4
	await _frames(60)
	var aim_now: Vector3 = -demo.camera.global_transform.basis.z
	check(Vector2(aim_now.x, aim_now.z).normalized().dot(Vector2(toward.x, toward.z).normalized()) > 0.8, "a lock turns the view back onto the body")

	# --- A third-person sword swing lands on the locked body. ---
	var rig: BaselineHuman = target.rig
	var notes_before: String = demo.last_note
	demo.pending_melee = {}
	demo._melee_swing()
	await _frames(40)
	check(demo.pending_melee.is_empty(), "the swing resolved")
	check(not str(demo.last_note).begins_with("MISS") and demo.last_note != notes_before, "and it connected: %s" % demo.last_note)

	# --- Back to first person: the eye again. ---
	demo.third_person = false
	avatar.third_person = false
	avatar.release_lock()
	await _frames(90)
	check(demo.camera.global_position.distance_to(demo.eye) < 0.05 and not avatar.visible and demo.view_gear.visible, "V again: back in the eye, viewmodel in hand")

	print("THIRD_PERSON_SANDBOX_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
