extends Node

## Being heard, and being understood, are two different things.
##
## The overworld has only ever had the first. `ProximityVoice` measures the
## microphone -- how long, how loud, who was in range -- and that is what the
## witness ledger and the positional reply need. It does not transcribe, so an
## NPC knew it had been spoken to and never what was said.
##
## Driven with stubs rather than a live microphone: the suite must pass on a
## machine with no Python, no Vosk model and no input device, which is exactly
## the machine the fallback path exists for.

const GRACE := SpokenContact.TRANSCRIPT_GRACE

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


## Stands in for the capture bus. Always succeeds; the interesting cases are
## about the words, not the microphone.
class StubCapture extends Node:
	signal capture_started(subject_id: String)
	signal capture_finished(subject_id: String, result: Dictionary)
	signal capture_failed(reason: String)

	var sent := true
	var began := ""

	func begin(subject_id: String, _anchor: Node3D) -> bool:
		began = subject_id
		return true

	func finish(_send := true) -> Dictionary:
		return {"sent": sent, "duration": 1.4, "peak": 0.6}


## Stands in for Vosk. `speaks` is what it will eventually return; `deaf` is a
## machine with no model installed.
class StubRecogniser extends Node:
	signal utterance_final(text: String)
	signal listening_changed(listening: bool)
	signal status_changed(status: String)

	var deaf := false
	var started := false
	var listening := false

	func available() -> bool:
		return not deaf

	func start(_device := -1) -> bool:
		started = true
		return true

	func set_listening(want: bool) -> void:
		listening = want

	func say(text: String) -> void:
		utterance_final.emit(text)


func _build(deaf := false) -> Array:
	var link := SpokenContact.new()
	add_child(link)
	var capture := StubCapture.new()
	var words := StubRecogniser.new()
	words.deaf = deaf
	link.configure(capture, words)
	return [link, capture, words]


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	print("-- the recogniser is started once, not once per person --")
	var built := _build()
	var link: SpokenContact = built[0]
	var words: StubRecogniser = built[2]
	check(words.started, "the listener is running before anybody is addressed")
	check(link.transcribes(), "and the link knows it can hear words")

	print("-- holding the key opens both halves --")
	var box := {"subject": "", "transcript": "", "result": {}, "count": 0}
	link.contact.connect(func(subject: String, transcript: String, result: Dictionary) -> void:
		box.subject = subject
		box.transcript = transcript
		box.result = result
		box.count = int(box.count) + 1)
	check(link.begin("ashline_captain", null), "the contact opens")
	check(words.listening, "the recogniser is listening while the key is down")

	print("-- and the words arrive after it comes up --")
	link.finish()
	check(not words.listening, "the recogniser stops on release")
	check(int(box.count) == 0, "nothing is delivered yet, because Vosk has not finalised")
	words.say("  you are going to tell me who sent you  ")
	await get_tree().process_frame
	check(int(box.count) == 1, "the contact lands when the sentence does")
	check(str(box.subject) == "ashline_captain", "against the person who was addressed")
	check(str(box.transcript) == "you are going to tell me who sent you", "carrying what was said, trimmed")
	check(float((box.result as Dictionary).get("duration", 0.0)) > 0.0, "and what the capture measured")

	print("-- a sentence that never finalises still lands --")
	box.count = 0
	box.transcript = "unset"
	link.begin("ashline_captain", null)
	link.finish()
	var waited := 0.0
	while int(box.count) == 0 and waited < GRACE + 1.5:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	check(int(box.count) == 1, "the wait is bounded (%.1fs)" % waited)
	check(waited >= GRACE - 0.3, "it did wait for the words first (%.1fs)" % waited)
	check(str(box.transcript).is_empty(), "and reports that nothing was understood")
	link.queue_free()

	print("-- a machine with no recogniser behaves as the overworld already did --")
	var deaf_built := _build(true)
	var deaf_link: SpokenContact = deaf_built[0]
	var deaf_box := {"count": 0, "transcript": "unset"}
	deaf_link.contact.connect(func(_subject: String, transcript: String, _result: Dictionary) -> void:
		deaf_box.count = int(deaf_box.count) + 1
		deaf_box.transcript = transcript)
	check(not deaf_link.transcribes(), "the link knows it cannot hear words")
	deaf_link.begin("ashline_captain", null)
	deaf_link.finish()
	check(int(deaf_box.count) == 1, "the contact is immediate, with nothing to wait for")
	check(str(deaf_box.transcript).is_empty(), "and empty, which is still a contact")
	deaf_link.queue_free()

	print("-- a capture that failed is not a contact at all --")
	var failed_built := _build()
	var failed_link: SpokenContact = failed_built[0]
	var failed_capture: StubCapture = failed_built[1]
	failed_capture.sent = false
	var failed_box := {"count": 0}
	failed_link.contact.connect(func(_s: String, _t: String, _r: Dictionary) -> void:
		failed_box.count = int(failed_box.count) + 1)
	failed_link.begin("ashline_captain", null)
	failed_link.finish()
	await get_tree().create_timer(GRACE + 0.4).timeout
	check(int(failed_box.count) == 0, "nobody is told they were spoken to when nothing was captured")
	failed_link.queue_free()

	print("SPOKEN_CONTACT_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
