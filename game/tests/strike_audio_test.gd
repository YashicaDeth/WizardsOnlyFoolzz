extends Node

## One whoosh per swing (not one per frame while the blade is fast), a crack
## only after a hard one, both voices routed off Master, and neither sample
## silent.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _rms(stream: AudioStreamWAV) -> float:
	var data := stream.data
	var total := 0.0
	var n := data.size() / 2
	for i in n:
		var v := float(data.decode_s16(i * 2)) / 32768.0
		total += v * v
	return sqrt(total / maxf(float(n), 1.0))


func _swing(audio: StrikeAudio, dt: float, commit: float) -> void:
	for i in 12:
		var a := float(i) * 0.4
		audio.feed(Vector3(sin(a), 0, -cos(a)), dt, commit)
	for i in 12:
		audio.feed(Vector3(0, 0, -1), dt, commit)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var audio := StrikeAudio.new()
	add_child(audio)
	var dt := 1.0 / 60.0
	for i in 20:
		audio.feed(Vector3(0, 0, -1), dt, 1.0)
	check(audio.swings == 0, "a still weapon makes no sound")
	_swing(audio, dt, 0.3)
	check(audio.swings == 1, "one fast swing is one whoosh, not one per frame")
	check(audio.cracks == 0, "a light swing does not crack the cable")
	_swing(audio, dt, 0.9)
	check(audio.swings == 2, "the next swing re-arms after the blade slows")
	check(audio.cracks == 1, "a hard swing cracks the cable after the whoosh")
	var whoosh := audio.get_node("Whoosh") as AudioStreamPlayer3D
	var crack := audio.get_node("Crack") as AudioStreamPlayer3D
	check(whoosh.bus != "Master" and crack.bus != "Master", "both voices go through the mixer, not straight to Master")
	check(_rms(whoosh.stream) > 0.02 and _rms(crack.stream) > 0.02, "neither generated sample is silent")
	print("STRIKE_AUDIO_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
