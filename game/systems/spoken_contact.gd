class_name SpokenContact
extends Node

## Speaking to somebody in the world, and being understood.
##
## The overworld has had half of this for a while. `ProximityVoice` captures
## while you hold the key and reports how long you spoke and how loud, which is
## what the witness ledger and the positional acknowledgement need. What it has
## never had is the words: it measures the microphone, it does not transcribe
## it. So an NPC could be told it had been spoken to, but never what was said,
## and the reply had to be one of a handful of written lines.
##
## `VoiceInput` has the words. It drives Vosk through `tools/voice_listener.py`
## and has been used only in the conversation lab.
##
## These are two different microphones in practice -- Python owns one through
## sounddevice, Godot owns the other through a capture bus -- and that is why
## this composes them rather than replacing either. The level meter, the
## duration, the witnesses and the positional reply keep working exactly as they
## did; the transcript arrives alongside them.
##
## The grace period is the part worth understanding. Vosk finalises an utterance
## *after* the key comes up, so the words are not there at the moment the player
## stops speaking. Without a bounded wait the NPC either answers before the
## sentence is finished or waits for a transcript that is never coming, and both
## read as the game ignoring you.

## One completed contact: who was addressed, what was said, and what the capture
## measured. `transcript` is empty when there is no recogniser or it heard
## nothing, which is a normal outcome rather than a failure -- the listener
## still knows they were spoken to.
signal contact(subject_id: String, transcript: String, result: Dictionary)
signal failed(reason: String)

## How long to wait for Vosk after the key comes up. Long enough for it to
## finalise a sentence, short enough that a man standing over a body is not left
## looking at nothing.
const TRANSCRIPT_GRACE := 1.8

var proximity: Object = null
var recogniser: Object = null

var _subject := ""
var _result: Dictionary = {}
var _transcript := ""
var _waiting := false
var _grace := 0.0


## Both halves are made here unless they were handed in first, so the common
## case is one line at the call site and a test can supply its own.
func configure(capture: Object = null, words: Object = null) -> void:
	proximity = capture if capture != null else _make_proximity()
	recogniser = words if words != null else _make_recogniser()
	if proximity is Node and not (proximity as Node).is_inside_tree():
		add_child(proximity as Node)
	if recogniser is Node and not (recogniser as Node).is_inside_tree():
		add_child(recogniser as Node)
	if proximity != null and proximity.has_signal("capture_failed"):
		proximity.capture_failed.connect(func(reason: String): failed.emit(reason))
	if recogniser != null and recogniser.has_signal("utterance_final"):
		recogniser.utterance_final.connect(_on_utterance)
	# Started once and left running. The recogniser is a subprocess and a player
	# who talks to six people should not pay to spawn it six times.
	if recogniser != null and recogniser.has_method("start"):
		recogniser.start()


func _make_proximity() -> Object:
	var capture := preload("res://systems/proximity_voice.gd").new()
	capture.name = "ProximityVoice"
	return capture


func _make_recogniser() -> Object:
	var words := VoiceInput.new()
	words.name = "VoiceInput"
	return words


## Whether the words half is actually available. The caller uses this to say so
## in the prompt: being told the game cannot hear you is worth knowing before
## you hold the key down and say something.
func transcribes() -> bool:
	return recogniser != null and recogniser.has_method("available") and bool(recogniser.available())


func begin(subject_id: String, anchor: Node3D) -> bool:
	if proximity == null or not proximity.has_method("begin"):
		return false
	if not bool(proximity.begin(subject_id, anchor)):
		return false
	_subject = subject_id
	_transcript = ""
	_waiting = false
	if transcribes():
		recogniser.set_listening(true)
	return true


func finish() -> void:
	if proximity == null or not proximity.has_method("finish"):
		return
	_result = proximity.finish()
	if transcribes():
		recogniser.set_listening(false)
	if not bool(_result.get("sent", false)):
		# Nothing usable was captured, so there is nothing to wait for. The
		# failure has already gone out through `capture_failed`.
		_waiting = false
		return
	if not transcribes():
		# No recogniser on this machine. They were still spoken to, and that is
		# the behaviour the overworld already had.
		_deliver()
		return
	_waiting = true
	_grace = TRANSCRIPT_GRACE


func _on_utterance(text: String) -> void:
	if not _waiting:
		return
	_transcript = text.strip_edges()
	_deliver()


func _process(delta: float) -> void:
	if not _waiting:
		return
	_grace -= delta
	if _grace <= 0.0:
		# Vosk heard nothing it was willing to commit to. They were still spoken
		# to, and the listener is told so with an empty transcript rather than
		# being left waiting on a sentence that is not coming.
		_deliver()


func _deliver() -> void:
	_waiting = false
	contact.emit(_subject, _transcript, _result.duplicate(true))
	_transcript = ""
	_result = {}
