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

	# --- The armed bodies carry the generated swords (Greg, 30 Sep). ---
	var carried := []
	for entry: Dictionary in demo.bodies:
		var held := entry.get("weapon_node") as Node3D
		if held != null and held.get_child_count() > 0:
			carried.append(str(held.get_child(0).name))
	check(not carried.is_empty() and carried.all(func(n: String) -> bool: return n in preload("res://systems/generated_model.gd").SWORDS), "armed bodies hold generated swords: %s" % [carried])

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

	# --- Looking all the way up never drives the camera into the floor. ---
	var pitch_before: float = demo.pitch
	demo.pitch = 0.9
	await _frames(60)
	check(demo.pitch <= SandboxAvatar.PITCH_MAX + 0.001, "third person holds the tilt at the orbit's limit (%.2f)" % demo.pitch)
	check(demo.camera.global_position.y >= avatar.global_position.y + SandboxAvatar.CAMERA_MIN_HEIGHT - 0.05, "and the camera stays above knee height (%.2f m)" % (demo.camera.global_position.y - avatar.global_position.y))
	demo.pitch = pitch_before
	await _frames(30)

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

	# --- Codex's moveset: a light from the keys lands on the locked body. ---
	await _frames(60)
	demo.stamina = 100.0
	demo.moveset.reset()
	var light: Dictionary = demo._moveset_request(false)
	check(bool(light.get("accepted", false)) and str(light.get("attack", "")) == "light_1", "LMB tap in third person starts light one")
	check(demo.stamina < 100.0, "and it costs stamina (%.0f)" % demo.stamina)
	await _frames(45)
	check(demo._moveset_struck.has(rig), "the sweep crossed the locked body and cut it")
	check(str(demo.last_note).begins_with("HIT") or str(demo.last_note).contains("OFF") or str(demo.last_note).begins_with("PARRIED") or str(demo.last_note).begins_with("BLOCKED"), "the cut went through the guard read: %s" % demo.last_note)
	await _frames(60)

	# --- Held past HEAVY_HOLD it is the heavy. ---
	demo.stamina = 100.0
	demo._blade_held = 0.0
	await _frames(30)
	check(demo.moveset.current_attack() == "heavy", "held, the press becomes the heavy (%s)" % demo.moveset.current_attack())
	await _frames(90)

	# --- The roll: carries the body, and its i-frames let a blow through. ---
	avatar.release_lock()
	demo.stamina = 100.0
	var roll_from: Vector3 = demo.eye
	check(demo._begin_dodge(Vector3.RIGHT), "SPACE with a direction rolls")
	await _frames(12)
	check(demo.roll.is_invulnerable(), "a fifth of a second in, the roll is invulnerable")
	var health_before: int = demo.simulation_health
	var armed: Dictionary = demo.bodies[1]
	armed["swing"] = BladeRead.LEFT
	demo._enemy_strike(armed, armed.holder)
	check(demo.simulation_health == health_before and str(demo.last_note).begins_with("ROLLED THROUGH"), "a blow inside the i-frames passes through")
	await _frames(40)
	check(demo.eye.x > roll_from.x + 3.0, "the roll carried the body (%.2f m)" % (demo.eye.x - roll_from.x))
	check(not demo.roll.is_rolling(), "and ended")

	# --- Knockback: a blow shoves the body back along it; poise breaks. ---
	var mark: Dictionary = demo.bodies[2]
	var mark_holder := mark.holder as Node3D
	var mark_rig: BaselineHuman = mark.rig
	var poise: Knockback = mark.knockback
	var shove_from := mark_holder.global_position
	demo._shove(mark, mark_rig, {"impulse": 28.0, "attack": "light_1"}, Vector3(1, 0, 0), 1.0)
	await _frames(60)
	var moved := mark_holder.global_position - shove_from
	check(moved.x > 0.2 and moved.x < 0.35 and absf(moved.z) < 0.02, "a cleaver light shoves the body ~0.25 m along the blow (%.2f m)" % moved.x)
	poise.reset()
	demo._shove(mark, mark_rig, {"impulse": 28.0, "attack": "heavy"}, Vector3(1, 0, 0), 1.0)
	check(demo.last_note == "POISE BROKEN" and poise.poise >= Knockback.MAX_POISE - 0.01, "a heavy breaks poise, and the body gets its footing back after")
	check(float(mark.attack_ready) > float(demo.SPAR_LEVELS[demo.spar_level].cadence), "and its next strike is put off: the opening")
	poise.reset()
	var blocked_from := mark_holder.global_position
	demo._shove(mark, mark_rig, {"impulse": 28.0, "attack": "light_1"}, Vector3(1, 0, 0), 0.0)
	await _frames(30)
	check(mark_holder.global_position.distance_to(blocked_from) < 0.01, "a blow that does not get through does not shove")

	# --- A death falls as a ragdoll. ---
	# A blow from -X to +X, then the finish (the path finishers take).
	var stood_at := mark_holder.global_position
	mark_rig.hit("torso", 20.0, 30.0, "blunt", "", Vector3(1, 0, 0))
	mark_rig.anatomy.finish("test")
	await _frames(120)
	check(mark_rig.anatomy.dead and mark_rig.ragdoll_body != null, "killed, the body hands its parts to a ragdoll")
	if mark_rig.ragdoll_body != null:
		var torso := mark_rig.parts.get("torso") as Node3D
		check(torso != null and torso.global_position.x > stood_at.x + 0.1, "and falls along the blow (torso %.2f m toward +X, y %.2f)" % [(torso.global_position.x - stood_at.x) if torso != null else 0.0, torso.global_position.y if torso != null else 0.0])

	# --- The Souls guard over the shoulder, and being hit. ---
	await _frames(60)
	var foe: Dictionary = demo.bodies[1]
	var foe_holder := foe.holder as Node3D
	var front := Vector3(-sin(avatar.facing_yaw), 0.0, -cos(avatar.facing_yaw))
	var place_foe := func(ahead: bool, who: Node3D) -> void:
		var at: Vector3 = demo.eye + (front if ahead else -front) * 1.4
		who.global_position = Vector3(at.x, 0.9, at.z)
		demo.player_poise.reset()
		demo.player_stun = 0.0
		demo.simulation_health = 100
	demo.guarding = true
	demo.guard_held = 1.0
	demo.stamina = 100.0
	place_foe.call(true, foe_holder)
	foe["swing"] = BladeRead.LEFT
	demo._enemy_strike(foe, foe_holder)
	check(str(demo.last_note).begins_with("BLOCKED") and absf(demo.stamina - (100.0 - demo.GUARD_BLOCK_STAMINA)) < 0.01, "a late guard blocks a side blow from the front and costs stamina: %s" % demo.last_note)
	check(demo.player_stun == 0.0, "a block does not stun")
	place_foe.call(true, foe_holder)
	demo.guard_held = 0.05
	foe["swing"] = BladeRead.LOW
	demo._enemy_strike(foe, foe_holder)
	check(str(demo.last_note).begins_with("PARRIED"), "a guard raised just in time parries, whatever the side: %s" % demo.last_note)
	if not demo._holds_weapon(foe):
		foe["weapon_node"] = null
	place_foe.call(false, foe_holder)
	demo.guard_held = 1.0
	foe["swing"] = BladeRead.HIGH
	demo._enemy_strike(foe, foe_holder)
	check(str(demo.last_note).begins_with("HIT"), "from behind the guard meets nothing: %s" % demo.last_note)
	place_foe.call(true, foe_holder)
	demo.guarding = true
	demo.stamina = 10.0
	foe["swing"] = BladeRead.RIGHT
	demo._enemy_strike(foe, foe_holder)
	check(not demo.guarding and demo.simulation_health < 100 and demo.stamina == 0.0, "with no stamina left the guard breaks and the blow comes through")
	# An armed one (the parry above disarmed the first).
	foe = demo.bodies[3]
	foe_holder = foe.holder as Node3D
	place_foe.call(true, foe_holder)
	demo.guarding = false
	demo.stamina = 100.0
	var struck_from: Vector3 = demo.eye
	foe["swing"] = BladeRead.RIGHT
	demo._enemy_strike(foe, foe_holder)
	check(demo.player_stun > 0.0, "an open hit stuns you for a moment")
	check(not bool(demo._moveset_request(false).get("accepted", false)) and not demo._begin_dodge(Vector3.RIGHT), "stunned, you can neither swing nor roll")
	await _frames(40)
	var pushed: Vector3 = demo.eye - struck_from
	check(pushed.dot(-front) > 0.05, "and the blow shoves you back, away from it (%.2f m)" % pushed.dot(-front))
	check(demo.player_stun == 0.0, "the stun wears off")
	demo.guarding = false

	# --- Back to first person: the eye again. ---
	demo.third_person = false
	avatar.third_person = false
	avatar.release_lock()
	await _frames(90)
	check(demo.camera.global_position.distance_to(demo.eye) < 0.05 and not avatar.visible and demo.view_gear.visible, "V again: back in the eye, viewmodel in hand")

	print("THIRD_PERSON_SANDBOX_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
