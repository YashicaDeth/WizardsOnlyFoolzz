extends Node

## The examiner, out loud.
##
## `NPCSpeechOutput` was finished and unused: the conversation lab showed his
## lines as subtitles and never asked anything to say them, so the one character
## in this game with a written voice direction was mute.
##
## This proves the backend chain rather than the sound, because a headless test
## has no audio device and could never hear it anyway. What it can prove is that
## a line goes in, a real wav comes out, and that the chooser degrades in the
## right order when a backend is missing -- which is the part that decides
## whether a machine without Piper still gets a voice.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	print("-- the chooser degrades in the right order --")
	# Without a host there is nowhere to hang a speaker, so Piper cannot be
	# used however well it is installed. Every existing caller passes no host,
	# and this is what keeps them working exactly as before.
	var hostless := NPCSpeechOutput.make("en_AU")
	check(not (hostless is NPCSpeechOutput.PipedVoice), "no host means no Piper, so old callers are unaffected")
	check(hostless is NPCSpeechOutput.Voice, "...and they still get a usable voice back")

	if not NPCSpeechOutput.PipedVoice.installed():
		print("SKIP  piper is not installed at %s" % NPCSpeechOutput.PipedVoice.EXE)
		print("NPC_VOICE_TEST_RESULT failures=", failures.size())
		get_tree().quit(0 if failures.is_empty() else 1)
		return

	var voice := NPCSpeechOutput.make("en_AU", self)
	check(voice is NPCSpeechOutput.PipedVoice, "with a host and Piper present, Piper is chosen")

	print("-- a line goes in and a wav comes out --")
	var piped: NPCSpeechOutput.PipedVoice = voice
	# Clear anything a previous run left. The sequence restarts at 1 each run,
	# so without this the new wav overwrites the old one and a count never
	# changes -- which is what failed here, rather than the synthesis.
	for stale in _wavs():
		DirAccess.remove_absolute(str(stale))
	var before := _wav_count()
	piped.speak("That is the examination. Thank you, I mean that.")
	# Synthesis is threaded so the game does not stall on it; the test has to
	# wait the same way the game does.
	# Waiting for the file to *exist* was wrong: piper creates it and then
	# writes into it, so the wait ended the instant it was touched and the test
	# measured an empty file. Wait for content.
	var waited := 0.0
	while _size_of(_newest_wav()) < 4096 and waited < 25.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	check(_wav_count() > before, "the thread produced a wav (%.1fs)" % waited)
	check(str(piped.last_error).is_empty(), "piper reported no error (%s)" % str(piped.last_error))

	var newest := _newest_wav()
	check(newest != "", "and it is findable on disk")
	if newest != "":
		var size := _size_of(newest)
		# Piper writes a 44-byte header even when it synthesises nothing, so a
		# file existing is not the same as a file with speech in it.
		check(size > 4096, "and it has real audio in it (%d bytes)" % size)
		var stream := AudioStreamWAV.load_from_file(newest)
		check(stream != null, "and Godot can load it back as a stream")
		if stream != null:
			check(stream.get_length() > 0.4, "of a plausible length for the line (%.2fs)" % stream.get_length())

	print("-- an empty line is not worth a subprocess --")
	var quiet := _wav_count()
	piped.speak("   ")
	await get_tree().create_timer(1.0).timeout
	check(_wav_count() == quiet, "whitespace does not spawn a synthesis")

	print("NPC_VOICE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _wav_count() -> int:
	var found := 0
	for name in _wavs():
		found += 1
	return found


func _wavs() -> Array:
	var out: Array = []
	var dir := DirAccess.open(OS.get_user_data_dir())
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("piper_out_") and name.ends_with(".wav"):
			out.append("%s/%s" % [OS.get_user_data_dir(), name])
		name = dir.get_next()
	dir.list_dir_end()
	return out


func _newest_wav() -> String:
	var best := ""
	var best_at := -1
	for path in _wavs():
		var stamp := FileAccess.get_modified_time(str(path))
		if int(stamp) >= best_at:
			best_at = int(stamp)
			best = str(path)
	return best


func _size_of(path: String) -> int:
	var handle := FileAccess.open(path, FileAccess.READ)
	if handle == null:
		return 0
	var size := handle.get_length()
	handle.close()
	return int(size)
