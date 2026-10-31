class_name NPCSpeechOutput
extends RefCounted

## AI NPC Communication & Relationship System, section 2's output pipeline and
## section 6's voice direction.
##
## "Keep provider integrations behind interfaces so STT/LLM/TTS vendors can be
## swapped." So this is the interface, plus the one provider that needs nothing
## bought, installed or signed up for: `DisplayServer`'s native OS speech.
##
## On this machine that finds `Microsoft James`, en_AU -- an Australian male
## voice, which is what section 6 asks for. It is not the performance the
## character bible describes; a SAPI voice cannot do "dry and gravelly without
## becoming cartoonishly raspy". It is a real voice speaking real lines today,
## with the seam sitting exactly where a better one drops in.
##
## What "better" looks like, in order of effort:
##   - Piper (MIT, local, neural). No key, no network, far better quality.
##     Implement `PipedVoice` below against its stdin/stdout interface.
##   - A cloud TTS with a streaming endpoint, behind the same two methods.

## Section 6: Australian male, 55-65. Preferred in order, falling back to
## whatever the machine actually has rather than failing silent.
const PREFERRED_LANGUAGES := ["en_AU", "en_GB", "en_US"]
const PREFERRED_NAMES := ["james", "mark", "david"]


## Picks the closest voice on this machine to the character bible. Returns "" if
## the OS has no speech at all, which is a supported state -- subtitles keep
## working and nothing errors.
static func best_voice(language_hint := "en_AU", masculine := true) -> String:
	var voices := DisplayServer.tts_get_voices()
	if voices.is_empty():
		return ""
	var ordered: Array[String] = [language_hint]
	for language in PREFERRED_LANGUAGES:
		if not ordered.has(language):
			ordered.append(language)
	# Language first, then the named preference inside it. A wrong-accent voice
	# of the right gender is a worse miss than the reverse for this character:
	# the accent is the half of the direction a listener notices immediately.
	for language in ordered:
		var matches: Array = []
		for voice in voices:
			if str((voice as Dictionary).get("language", "")) == language:
				matches.append(voice)
		if matches.is_empty():
			continue
		if masculine:
			for wanted in PREFERRED_NAMES:
				for voice in matches:
					if str((voice as Dictionary).get("name", "")).to_lower().contains(wanted):
						return str((voice as Dictionary).get("id", ""))
		return str((matches[0] as Dictionary).get("id", ""))
	return str((voices[0] as Dictionary).get("id", ""))


static func available() -> bool:
	return not DisplayServer.tts_get_voices().is_empty()


## The provider interface. Two methods, because that is all a speech backend
## has to do: say a line, and stop saying it.
class Voice extends RefCounted:
	func speak(_text: String, _interrupt: bool = true) -> void:
		pass

	func stop() -> void:
		pass

	func is_speaking() -> bool:
		return false


## The one that works with nothing installed.
class NativeVoice extends Voice:
	var voice_id := ""
	## Section 6: "Measured pace." SAPI's default is a news reader; the examiner
	## is not in a hurry and never raises his voice, so this sits under default
	## rate and under full volume.
	var rate := 0.86
	var pitch := 0.88
	var volume := 62

	func _init(selected_voice_id: String) -> void:
		voice_id = selected_voice_id

	func speak(text: String, interrupt: bool = true) -> void:
		if voice_id.is_empty() or text.strip_edges().is_empty():
			return
		DisplayServer.tts_speak(text, voice_id, volume, pitch, rate, 0, interrupt)

	func stop() -> void:
		DisplayServer.tts_stop()

	func is_speaking() -> bool:
		return DisplayServer.tts_is_speaking()


## Piper: MIT, local, neural, no key and no network. This is the "better" the
## header has been pointing at since this file was written.
##
## Why it is worth a subprocess. SAPI on this machine offers Microsoft David
## (en-US) and Zira (en-US) and nothing else -- the comment above used to claim
## it found `Microsoft James`, en_AU, and that voice is simply not installed.
## So the native path gives the examiner an American accent and a news-reader
## delivery, which is the half of section 6's direction a listener notices
## first. Piper measured at a real-time factor of 0.062 on this box: a quarter
## of a second of compute for four seconds of speech.
##
## Synthesis runs on a `Thread` because `OS.execute()` blocks until the process
## exits, and a quarter-second stall every time somebody speaks is a quarter
## second of the game stopping. The thread writes a wav, the main thread loads
## and plays it.
class PipedVoice extends Voice:
	const EXE := "P:/GameDev/Tools/piper/piper/piper.exe"
	const MODEL := "P:/GameDev/Tools/piper/piper/en_GB-alan-medium.onnx"

	## Section 6: "Low, dry, measured. He is not in a hurry." Piper's default
	## pace is a shade quick for that, and stretching phonemes is the dial that
	## slows a delivery without dropping the pitch into parody.
	const LENGTH_SCALE := 1.12

	## The speaker, and the only clock this class has. It is a `Node` because the
	## worker's result has to be picked up on the main thread, and `_process` is
	## where a `RefCounted` can borrow one. See `_synthesise` for why the worker
	## is polled rather than poked.
	class Speaker extends AudioStreamPlayer:
		var pump: Callable

		func _process(_delta: float) -> void:
			if pump.is_valid():
				pump.call()

	var player: Speaker
	var last_error := ""
	var _spoken_path := ""
	var _thread: Thread = null
	var _sequence := 0
	## The worker's outbox. Everything the worker learns goes in here under the
	## mutex, and nothing it learns is ever applied to the tree from there.
	var _mail := Mutex.new()
	var _posted: Dictionary = {}

	static func installed() -> bool:
		return FileAccess.file_exists(EXE) and FileAccess.file_exists(MODEL)

	## Needs somewhere in the tree to put its speaker, which is the one thing
	## the other backends do not -- `DisplayServer` speaks without a node.
	func _init(host: Node) -> void:
		player = Speaker.new()
		player.bus = "Master"
		player.pump = _collect
		player.set_process(false)
		host.add_child(player)
		# A voice can outlive the node that made it -- anything still holding one
		# at exit keeps it from ever reaching `NOTIFICATION_PREDELETE` -- so the
		# one join that has to happen is hooked to the tree going away instead.
		if host.is_inside_tree():
			_watch_the_exit(host)
		else:
			host.tree_entered.connect(_watch_the_exit.bind(host), CONNECT_ONE_SHOT)

	## The engine does not wait for threads. A worker still inside `OS.execute()`
	## when the process tears down is `exit 139`, which is what a test that
	## speaks a line and quits had been doing all along. This is the only place a
	## line is waited for rather than polled, and it only happens on the way out.
	func _watch_the_exit(host: Node) -> void:
		var tree := host.get_tree()
		if tree != null and not tree.root.tree_exiting.is_connected(_wait_for_worker):
			tree.root.tree_exiting.connect(_wait_for_worker)

	func _wait_for_worker() -> void:
		if _thread == null:
			return
		_thread.wait_to_finish()
		_thread = null

	func speak(text: String, interrupt: bool = true) -> void:
		var line := text.strip_edges()
		if line.is_empty():
			return
		if interrupt:
			stop()
		# One line at a time. A backlog of synthesised speech nobody is waiting
		# for any more is worse than a dropped line, because it arrives after
		# the conversation has moved on.
		if _thread != null and _thread.is_alive():
			return
		# A finished worker may have landed since the last frame. It belongs to
		# the line this one is replacing, so it goes rather than plays over it.
		_discard(_settle())
		_sequence += 1
		_thread = Thread.new()
		_thread.start(_synthesise.bind(line, _sequence))
		_listen(true)

	func stop() -> void:
		if player != null and is_instance_valid(player):
			player.stop()

	func is_speaking() -> bool:
		return player != null and is_instance_valid(player) and player.playing

	## Runs on the worker. It writes files and runs `OS.execute()` and touches
	## nothing else: no node, no `call_deferred`, no `_play`.
	##
	## Posting a deferred call from here was the bug. `call_deferred()` is a
	## message queued on the main thread's queue from the wrong thread, and when
	## the tree quits with one still in flight it is delivered into an object that
	## is already gone -- which took the whole process down on exit (exit 139 in
	## `standing_contact_test`). The result goes into `_posted` behind the mutex
	## instead, and the main thread collects it in `_collect`.
	func _synthesise(line: String, sequence: int) -> void:
		var base := OS.get_user_data_dir()
		var text_path := "%s/piper_in_%d.txt" % [base, sequence]
		var wav_path := "%s/piper_out_%d.wav" % [base, sequence]
		var handle := FileAccess.open(text_path, FileAccess.WRITE)
		if handle == null:
			_post({"text": text_path, "error": "cannot write %s" % text_path})
			return
		handle.store_string(line)
		handle.close()
		# Piper reads its text from stdin, and `OS.execute()` has no stdin to
		# give it, so the text goes via a file and cmd pipes it in. Quoting
		# every path because this project lives under "P:/GameDev".
		var command := "type \"%s\" | \"%s\" --model \"%s\" --output_file \"%s\" --length_scale %s --quiet" % [
			text_path.replace("/", "\\"), EXE.replace("/", "\\"),
			MODEL.replace("/", "\\"), wav_path.replace("/", "\\"),
			str(LENGTH_SCALE),
		]
		var output: Array = []
		var code := OS.execute("cmd.exe", ["/c", command], output, true)
		# Captured rather than discarded: a synthesis that fails silently is a
		# character who has simply stopped speaking, with nothing anywhere
		# saying why.
		_post({
			"wav": wav_path, "text": text_path,
			"error": "" if code == 0 else "piper exit %d: %s" % [code, "
".join(output)],
		})

	func _post(line: Dictionary) -> void:
		_mail.lock()
		_posted = line
		_mail.unlock()

	## Main thread, once a frame while a worker is out. Applies what the worker
	## posted, if anything, and stops asking to be called when nothing is left.
	func _collect() -> void:
		var line := _settle()
		if _thread != null:
			return
		_listen(false)
		if line.is_empty():
			return
		last_error = str(line.get("error", ""))
		var wav := str(line.get("wav", ""))
		if wav.is_empty():
			_discard(line)
			return
		_play(wav, str(line.get("text", "")))

	func _listen(on: bool) -> void:
		if player != null and is_instance_valid(player):
			player.set_process(on)

	## Main thread only. Joins a worker that has finished and hands back what it
	## posted, or `{}` while it is still working. `_thread` stays set until the
	## join has happened, so "still working" and "nothing to say" are not the
	## same answer.
	func _settle() -> Dictionary:
		if _thread == null or _thread.is_alive():
			return {}
		# Always joined, never merely observed: `is_alive()` reads false the
		# instant the worker returns, but the Thread itself is not finished with
		# until it has been waited for, and freeing it unjoined is the warning
		# and the crash this class used to leave on exit.
		_thread.wait_to_finish()
		_thread = null
		_mail.lock()
		var line := _posted
		_posted = {}
		_mail.unlock()
		return line

	func _play(wav_path: String, text_path: String) -> void:
		# The one before this is finished with now that a new line is starting.
		# Left alone they accumulate in the user directory for the life of the
		# install, a wav per line anybody ever said.
		if not _spoken_path.is_empty() and _spoken_path != wav_path:
			DirAccess.remove_absolute(_spoken_path)
		_spoken_path = wav_path
		if FileAccess.file_exists(wav_path):
			var stream := AudioStreamWAV.load_from_file(wav_path)
			if stream != null and player != null and is_instance_valid(player):
				player.stream = stream
				player.play()
		if not text_path.is_empty():
			DirAccess.remove_absolute(text_path)

	## A line nobody is going to hear, with the files it left behind.
	func _discard(line: Dictionary) -> void:
		if line.is_empty():
			return
		for key in ["wav", "text"]:
			var path := str(line.get(key, ""))
			if not path.is_empty():
				DirAccess.remove_absolute(path)

	## A synthesis still running when this is freed takes its `Thread` with it, and
	## Godot tears a Thread that was never waited for down badly enough to take the
	## process with it. The last thing this does is let its worker finish.
	func _notification(what: int) -> void:
		if what != NOTIFICATION_PREDELETE or _thread == null:
			return
		_thread.wait_to_finish()
		_thread = null


## Subtitles only. Used when the OS has no speech, and in headless tests, where
## the point is that the conversation loop does not care which one it has.
class SilentVoice extends Voice:
	var last_spoken := ""

	func speak(text: String, _interrupt: bool = true) -> void:
		last_spoken = text


## Chooses for the caller: a real voice where one exists, silence where none
## does. No configuration required to get the better of the two.
## Chooses for the caller, best first: Piper where it is installed, the OS voice
## where it is not, silence where there is neither. No configuration required to
## get the best of the three.
##
## `host` is only needed by Piper, which has to hang a speaker in the tree.
## Passing null keeps the old behaviour exactly, so every existing caller and
## every headless test is unaffected.
static func make(preferred_language := "en_AU", host: Node = null) -> Voice:
	if host != null and PipedVoice.installed():
		return PipedVoice.new(host)
	if available():
		# Resolve the voice in the owning script before constructing the nested
		# class. Having NativeVoice name its owner creates a script-resource
		# reference cycle that otherwise retains the Hunt's loaded resource graph.
		return NativeVoice.new(best_voice(preferred_language, true))
	return SilentVoice.new()
