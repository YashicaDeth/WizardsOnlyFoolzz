extends Node3D

## Greg, 28 September: the sound pass. Every sound is synthesized and not
## silent, footsteps come a stride apart on the floor, hits play impact /
## crack / voice, and the music bed rises with tension.

const AMBIENT_AUDIO := preload("res://systems/ambient_audio.gd")
const AMBIENT_BED := preload("res://systems/ambient_bed.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _loudest(wav: AudioStreamWAV) -> int:
	var peak := 0
	for index in range(0, wav.data.size(), 64):
		peak = maxi(peak, absi(wav.data.decode_s16(index)))
	return peak


func _ready() -> void:
	for kind: String in AMBIENT_AUDIO.LENGTHS:
		var wav: AudioStreamWAV = AMBIENT_AUDIO.stream(kind)
		check(wav != null and _loudest(wav) > 800, "%s is synthesized and audible (%d)" % [kind, _loudest(wav)])
		check((wav.loop_mode == AudioStreamWAV.LOOP_FORWARD) == (kind in AMBIENT_AUDIO.LOOPS), "%s loops only if it is a bed" % kind)

	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -0.5
	add_child(floor_body)
	var body := CharacterBody3D.new()
	var capsule := CollisionShape3D.new()
	capsule.shape = CapsuleShape3D.new()
	body.add_child(capsule)
	body.position.y = 1.0
	add_child(body)
	var camera := Camera3D.new()
	body.add_child(camera)
	for i in 30:
		body.velocity = Vector3.ZERO
		body.move_and_slide()
		await get_tree().physics_frame
	var steps := 0
	for i in 60:
		body.velocity = Vector3(0, 0, -3.0)
		body.move_and_slide()
		if AMBIENT_AUDIO.step(camera, body, 1.0 / 60.0):
			steps += 1
		await get_tree().physics_frame
	check(steps == 1, "walking 3 m at 3 m/s takes one stride-long step (%d)" % steps)
	var feet := camera.get_node_or_null("Footsteps") as AudioStreamPlayer
	check(feet != null and feet.stream == AMBIENT_AUDIO.stream("step_bare"), "bare wet feet by default in the opening")
	body.set_meta("surface", "metal")
	steps = 0
	for i in 60:
		body.velocity = Vector3(0, 0, -7.0)
		body.move_and_slide()
		if AMBIENT_AUDIO.step(camera, body, 1.0 / 60.0):
			steps += 1
		await get_tree().physics_frame
	check(steps >= 3 and feet.stream == AMBIENT_AUDIO.stream("step_metal"), "running on metal: metal steps (%d)" % steps)
	check(feet.volume_db > -10.0, "running is louder")

	check(AMBIENT_AUDIO.hit(self, Vector3.ZERO, {"fracture": "closed"}, false) == ["impact", "crack", "grunt"], "a break cracks and they cry out")
	check(AMBIENT_AUDIO.hit(self, Vector3.ZERO, {}, true) == ["impact"], "the dead only take the impact")

	for room: String in AMBIENT_BED.PROFILES:
		var bed = AMBIENT_BED.new().setup(room)
		add_child(bed)
		check(bed.layers.size() >= 2 and bed.music.size() == 3, "%s has a room bed and music" % room)
		bed.queue_free()
	var vat = AMBIENT_BED.new().setup("vat")
	add_child(vat)
	vat.tension = 0.1
	for i in 120:
		vat._process(0.1)
	var calm: float = (vat.music["industrial"] as AudioStreamPlayer).volume_db
	vat.tension = 1.0
	for i in 120:
		vat._process(0.1)
	check(calm <= -59.0 and (vat.music["industrial"] as AudioStreamPlayer).volume_db > -16.0, "the industrial layer rises only with tension")
	check(vat.screams_heard >= 1, "far screams in the vat room")

	print("AMBIENT_AUDIO_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
