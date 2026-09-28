extends Node

## K's choir hum, J's sonar ping, and the crumble, creak and spark one-shots:
## each is audible (not silent, not clipping), and the hum and ping play only
## in their modes. Also writes each as a WAV for Greg to listen to.

const SIGHT_AUDIO := preload("res://systems/sight_audio.gd")
const SIGNAL_SIGHT := preload("res://systems/signal_sight.gd")

var failures := 0


func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1


func _ready() -> void:
	var out := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
	for kind in ["choir", "sonar", "crumble", "creak", "spark"]:
		var wav: AudioStreamWAV = SIGHT_AUDIO.stream(kind)
		var data := wav.data
		var peak := 0
		var total := 0.0
		for i in range(0, data.size(), 2):
			var v := absi(data.decode_s16(i))
			peak = maxi(peak, v)
			total += float(v * v)
		var rms := sqrt(total / float(data.size() / 2)) / 32767.0
		check(rms > 0.03 and peak < 32767, "%s is audible and not clipping (rms %.3f, peak %d)" % [kind, rms, peak])
		if not out.is_empty():
			wav.save_to_wav("%s/sound_%s.wav" % [out, kind])
	var camera := Camera3D.new()
	add_child(camera)
	var sight = SIGNAL_SIGHT.new()
	add_child(sight)
	sight.setup(camera)
	sight.enabled = true
	await get_tree().process_frame
	check(not sight.choir.playing and not sight.sonar.playing, "silent while the modes are off")
	sight.toggle_wizard()
	await get_tree().process_frame
	check(sight.choir.playing and not sight.sonar.playing, "K: the choir hums")
	sight.toggle_wizard()
	sight.hold_depth(true)
	await get_tree().process_frame
	check(sight.sonar.playing and not sight.choir.playing, "J: the sonar pings")
	sight.hold_depth(false)
	await get_tree().process_frame
	check(not sight.choir.playing and not sight.sonar.playing, "and both stop when you leave")
	print("SIGHT_AUDIO_TEST_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
