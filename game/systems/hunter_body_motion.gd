class_name HunterBodyMotion
extends Node

## Procedural placeholder animation for the gameplay body. It poses the visible
## mesh and its matching anatomy hitbox together, so first-person presence does
## not create a second pair of invulnerable floating arms.

signal foot_planted(side: String)

var rig: BaselineHuman
var first_person := false
var gait_phase := 0.0
var speed_blend := 0.0
var crouch_blend := 0.0
var attack_time := 0.0
var attack_duration := 0.0
var recoil_time := 0.0
var reload_time := 0.0
var interaction_time := 0.0
var landing_time := 0.0
var grounded_last := true
var prior_step_index := 0
var elapsed := 0.0
var state := "idle"
var camera_offset := Vector3.ZERO
var camera_roll := 0.0
var fov_add := 0.0
var step_voice: AudioStreamPlayer3D


func configure(body_rig: BaselineHuman) -> void:
	rig = body_rig
	step_voice = AudioStreamPlayer3D.new()
	# G5.1. Footsteps were on Master too.
	AudioBus.route(step_voice, "Bodies")
	step_voice.name = "Footsteps"
	step_voice.stream = _footstep_stream()
	step_voice.volume_db = -14.0
	step_voice.max_distance = 18.0
	step_voice.pitch_scale = 0.94
	rig.add_child(step_voice)


func set_perspective(is_first_person: bool) -> void:
	first_person = is_first_person


func trigger_attack(duration: float, weapon_kind: String) -> void:
	attack_duration = maxf(0.12, duration)
	attack_time = attack_duration
	state = "shoot" if weapon_kind == "firearm" else "attack"


func trigger_recoil(strength: float) -> void:
	recoil_time = maxf(recoil_time, 0.10 + clampf(strength / 60.0, 0.0, 0.16))


func trigger_reload(duration: float) -> void:
	reload_time = maxf(0.1, duration)
	state = "reload"


func trigger_interaction() -> void:
	interaction_time = 0.38
	state = "interact"


func update(delta: float, velocity: Vector3, grounded: bool, sprinting: bool, crouching: bool, dodging: bool) -> void:
	if rig == null or rig.anatomy.dead or rig.is_downed():
		return
	elapsed += delta
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var target_speed := clampf(horizontal_speed / 7.0, 0.0, 1.5)
	speed_blend = move_toward(speed_blend, target_speed, delta * 5.0)
	crouch_blend = move_toward(crouch_blend, 1.0 if crouching else 0.0, delta * 6.0)
	var cadence := lerpf(5.2, 9.0, clampf(speed_blend, 0.0, 1.0))
	gait_phase += delta * cadence * speed_blend
	if grounded and not grounded_last:
		landing_time = 0.22
	grounded_last = grounded
	attack_time = maxf(0.0, attack_time - delta)
	recoil_time = maxf(0.0, recoil_time - delta)
	reload_time = maxf(0.0, reload_time - delta)
	interaction_time = maxf(0.0, interaction_time - delta)
	landing_time = maxf(0.0, landing_time - delta)
	_choose_state(horizontal_speed, grounded, sprinting, crouching, dodging)
	_pose(horizontal_speed, sprinting, crouching, dodging)
	_update_camera_motion(horizontal_speed, sprinting, grounded)
	_update_steps(grounded, horizontal_speed, sprinting)


func _choose_state(horizontal_speed: float, grounded: bool, sprinting: bool, crouching: bool, dodging: bool) -> void:
	if attack_time > 0.0 or recoil_time > 0.0 or reload_time > 0.0 or interaction_time > 0.0:
		return
	if dodging:
		state = "dodge"
	elif not grounded:
		state = "air"
	elif crouching:
		state = "crouch"
	elif horizontal_speed > 8.0 or sprinting:
		state = "sprint"
	elif horizontal_speed > 0.25:
		state = "walk"
	elif rig.anatomy.pain > 45.0:
		state = "injury"
	else:
		state = "idle"


func _pose(horizontal_speed: float, sprinting: bool, crouching: bool, dodging: bool) -> void:
	var gait := sin(gait_phase)
	var opposite := sin(gait_phase + PI)
	var locomotion := clampf(horizontal_speed / 7.0, 0.0, 1.0)
	var leg_swing := gait * 0.52 * locomotion * (1.32 if sprinting else 1.0)
	var arm_swing := opposite * 0.34 * locomotion
	var injury := 1.0 - rig.anatomy.mobility_ratio()
	_set_zone_pose("left_leg", Vector3(0, -0.24 * crouch_blend, 0), Vector3(leg_swing + crouch_blend * 0.45, 0, injury * -0.12))
	_set_zone_pose("right_leg", Vector3(0, -0.24 * crouch_blend, 0), Vector3(-leg_swing + crouch_blend * 0.45, 0, injury * 0.12))
	# M4.4. Was 1.14 rad (65 degrees) — enough to swing the whole forearm box up
	# past the lens at FOV 78, where it read as a screen-filling black slab
	# rather than a held weapon. A shallower raise keeps the arm in the lower
	# third of frame the way a held weapon actually sits.
	var arm_raise := 0.62 if first_person else 0.0
	var fp_spread := 0.045 if first_person else 0.0
	_set_zone_pose("left_arm", Vector3(-fp_spread, -0.05 * crouch_blend, 0), Vector3(arm_swing + arm_raise, 0, 0.08))
	_set_zone_pose("right_arm", Vector3(fp_spread, -0.05 * crouch_blend, 0), Vector3(-arm_swing + arm_raise, 0, -0.08))
	var torso := rig.parts.get("torso") as Node3D
	if torso != null:
		var rest: Vector3 = torso.get_meta("rest_position", torso.position)
		# M4.1/M4.4. The eye sits only ~0.23 m above the torso's own top edge and
		# the torso's front face is flush with the capsule centre the camera is
		# measured from, so at FOV 78 the chest was close enough to read as a
		# solid black slab under the chin rather than a body glimpsed below the
		# chin. Nudging it back and down in first person only (never seen from
		# outside, so third person and any future onlooker keep the real
		# proportions) gives the eye the same clearance a real neck would.
		var fp_recede := Vector3(0, -0.16, 0.28) if first_person else Vector3.ZERO
		torso.position = rest + fp_recede + Vector3(0, sin(elapsed * 1.7) * 0.008 - crouch_blend * 0.22, 0)
		torso.rotation = Vector3(crouch_blend * 0.18 + (0.30 if dodging else 0.0), 0, -gait * 0.025 * locomotion)
	# Weapon actions layer over locomotion instead of replacing the body.
	if attack_time > 0.0 and attack_duration > 0.0:
		var progress := 1.0 - attack_time / attack_duration
		var swing := sin(progress * PI)
		var right := rig.parts.get("right_arm") as Node3D
		if right != null:
			right.rotation.x += swing * 0.55
			right.rotation.z -= swing * 1.05
	if recoil_time > 0.0:
		var kick := recoil_time * 2.8
		for zone_id in ["left_arm", "right_arm"]:
			var arm := rig.parts.get(zone_id) as Node3D
			if arm != null:
				arm.rotation.x -= kick
	if reload_time > 0.0:
		var left := rig.parts.get("left_arm") as Node3D
		if left != null:
			left.rotation.x = 0.9 + sin(reload_time * 8.0) * 0.12
			left.rotation.z = -0.72


func _set_zone_pose(zone_id: String, offset: Vector3, angles: Vector3) -> void:
	var part := rig.parts.get(zone_id) as Node3D
	var hitbox := rig.get_node_or_null("%s_hitbox" % zone_id) as Node3D
	if part == null:
		return
	var rest_position: Vector3 = part.get_meta("rest_position", part.position)
	var rest_rotation: Vector3 = part.get_meta("rest_rotation", Vector3.ZERO)
	part.position = rest_position + offset
	part.rotation = rest_rotation + angles
	if hitbox != null:
		hitbox.position = part.position
		hitbox.rotation = part.rotation


func _update_camera_motion(horizontal_speed: float, sprinting: bool, grounded: bool) -> void:
	var moving := clampf(horizontal_speed / 7.0, 0.0, 1.0) if grounded else 0.0
	var breath: float = sin(elapsed * (2.25 if sprinting else 1.55)) * (0.010 if sprinting else 0.006)
	var step_bob: float = abs(sin(gait_phase)) * 0.022 * moving
	var side: float = sin(gait_phase * 0.5) * 0.010 * moving
	var landing: float = sin(clampf(landing_time / 0.22, 0.0, 1.0) * PI) * -0.055
	var recoil: float = -recoil_time * 0.18
	camera_offset = Vector3(side, breath + step_bob + landing, recoil)
	camera_roll = sin(gait_phase * 0.5) * 0.006 * moving
	fov_add = lerpf(0.0, 2.4, speed_blend if sprinting else 0.0) - landing_time * 3.0


func _update_steps(grounded: bool, horizontal_speed: float, sprinting: bool) -> void:
	if not grounded or horizontal_speed < 0.8:
		return
	var step_index := floori(gait_phase / PI)
	if step_index == prior_step_index:
		return
	prior_step_index = step_index
	var side := "left" if step_index % 2 == 0 else "right"
	step_voice.pitch_scale = (1.08 if sprinting else 0.92) + sin(float(step_index) * 2.1) * 0.05
	step_voice.play()
	foot_planted.emit(side)


func _footstep_stream() -> AudioStreamWAV:
	var rate := 16000
	var sample_count := int(rate * 0.075)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 701913
	for index in sample_count:
		var t := float(index) / rate
		var envelope := pow(1.0 - float(index) / sample_count, 2.8)
		var thump := sin(TAU * 72.0 * t) * 0.62
		var grit := rng.randf_range(-1.0, 1.0) * 0.28
		var sample := clampi(roundi((thump + grit) * envelope * 32767.0), -32768, 32767)
		bytes[index * 2] = sample & 0xff
		bytes[index * 2 + 1] = (sample >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	return stream
