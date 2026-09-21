class_name VoiceInput
extends Node

## AI NPC Communication & Relationship System, section 2's input pipeline:
## "microphone -> voice activity / push-to-talk -> streaming speech-to-text ->
## utterance buffer -> intent/context request."
##
## Godot owns a microphone but not a recogniser, and the two offline engines
## that need no API key are Windows SAPI and Vosk. SAPI was measured before
## being rejected: on open dictation it returned "Added to a gold funds and
## this was his vision commission" at confidence 0.04. So this drives Vosk,
## through `tools/voice_listener.py`.
##
## Godot cannot read a child process's stdout asynchronously, so the two sides
## share two small files. Dull, and completely reliable:
##
##   state.txt       written here:  "listen" while the key is held, else "idle"
##   transcript.txt  written there: one final utterance per line
##
## Everything degrades. No Python, no model, no microphone, or a listener that
## dies mid-session -- each leaves `available()` false and the caller falls back
## to typed input rather than losing the ability to speak to anyone.

signal utterance_final(text: String)
signal listening_changed(listening: bool)
signal status_changed(status: String)

const MODEL_DIR := "P:/GameDev/Tools/vosk/vosk-model-small-en-us-0.15"
const BRIDGE_DIR := "P:/GameDev/Temp/voice_bridge"
const SCRIPT_PATH := "P:/GameDev/AllusionsTooGrandeur/tools/voice_listener.py"
const POLL_SECONDS := 0.12

var device_index := -1
var status := "off"
var listening := false

var _pid := -1
var _poll := 0.0
var _consumed := 0


func _ready() -> void:
	set_process(false)


## True when a recogniser is actually running and has reported itself ready.
## Deliberately not "the files exist" -- a listener that failed to load its
## model leaves the files behind and would otherwise look healthy.
func available() -> bool:
	return _pid > 0 and status in ["ready", "listening"]


static func model_installed() -> bool:
	return DirAccess.dir_exists_absolute(MODEL_DIR)


## Starts the recogniser. Returns false when anything is missing, having
## recorded why in `status`, so a settings screen can say which piece is absent
## instead of "voice unavailable".
func start(input_device := -1) -> bool:
	if _pid > 0:
		return true
	if not FileAccess.file_exists(SCRIPT_PATH):
		status = "missing_listener"
		status_changed.emit(status)
		return false
	if not model_installed():
		status = "missing_model"
		status_changed.emit(status)
		return false

	device_index = input_device
	DirAccess.make_dir_recursive_absolute(BRIDGE_DIR)
	# Truncated on start. A transcript file left from a previous session would
	# otherwise deliver last night's sentences as this session's first ones.
	_write(_bridge("transcript.txt"), "")
	_write(_bridge("state.txt"), "idle")
	_write(_bridge("status.txt"), "starting")
	_consumed = 0

	var arguments: PackedStringArray = [
		SCRIPT_PATH, "--model", MODEL_DIR, "--bridge", BRIDGE_DIR,
	]
	if input_device >= 0:
		arguments.append_array(["--device", str(input_device)])
	_pid = OS.create_process("python", arguments)
	if _pid <= 0:
		status = "no_python"
		status_changed.emit(status)
		return false
	status = "loading"
	status_changed.emit(status)
	set_process(true)
	return true


func stop() -> void:
	if _pid <= 0:
		return
	_write(_bridge("state.txt"), "quit")
	# Asked to stop first, then killed. The recogniser releases the microphone
	# on a clean exit; a bare kill can leave the device held.
	await get_tree().create_timer(0.35).timeout
	if _pid > 0:
		OS.kill(_pid)
	_pid = -1
	listening = false
	status = "off"
	set_process(false)
	status_changed.emit(status)


## Push-to-talk. Audio captured while this is false is discarded by the
## listener rather than buffered, which is a privacy property before it is a
## performance one: the microphone is only ever listened to on purpose.
func set_listening(want: bool) -> void:
	if not available() and want:
		return
	if listening == want:
		return
	listening = want
	_write(_bridge("state.txt"), "listen" if want else "idle")
	listening_changed.emit(listening)


func _process(delta: float) -> void:
	_poll += delta
	if _poll < POLL_SECONDS:
		return
	_poll = 0.0

	var reported := _read(_bridge("status.txt")).strip_edges()
	if not reported.is_empty() and reported != status:
		status = reported
		status_changed.emit(status)

	var body := _read(_bridge("transcript.txt"))
	if body.is_empty():
		return
	var lines := body.split("\n", false)
	# Consumed by count rather than by clearing the file: the listener appends
	# from another process, and truncating underneath it drops any utterance
	# written between the read and the write.
	while _consumed < lines.size():
		var line := str(lines[_consumed]).strip_edges()
		_consumed += 1
		if not line.is_empty():
			utterance_final.emit(line)


## Input devices as the recogniser sees them, for a settings screen. Shelling
## out rather than guessing, because Godot's own device list and PortAudio's
## indices are not the same numbering.
static func input_devices() -> Array[String]:
	var output: Array = []
	var code := OS.execute("python", [SCRIPT_PATH, "--model", "x", "--bridge", "x", "--list-devices"], output, true)
	var devices: Array[String] = []
	if code != 0:
		return devices
	for line in str("\n".join(output)).split("\n"):
		var text := str(line).strip_edges()
		if text.begins_with("DEVICE "):
			devices.append(text.trim_prefix("DEVICE "))
	return devices


func _bridge(name: String) -> String:
	return "%s/%s" % [BRIDGE_DIR, name]


func _write(path: String, body: String) -> void:
	var handle := FileAccess.open(path, FileAccess.WRITE)
	if handle != null:
		handle.store_string(body)
		handle.close()


func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var handle := FileAccess.open(path, FileAccess.READ)
	if handle == null:
		return ""
	var body := handle.get_as_text()
	handle.close()
	return body
