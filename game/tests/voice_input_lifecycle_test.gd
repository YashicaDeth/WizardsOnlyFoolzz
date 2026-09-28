extends Node

var failures: Array[String] = []


class FakeVoiceInput extends VoiceInput:
	var last_state := ""
	var killed_pid := -1

	func _write(_path: String, body: String) -> void:
		last_state = body

	func _terminate_process(process_id: int) -> void:
		killed_pid = process_id


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var voice := FakeVoiceInput.new()
	add_child(voice)
	voice._pid = 4321
	voice.listening = true
	voice.status = "listening"
	voice._exit_tree()
	check(voice.last_state == "quit", "tree exit asks the recogniser to release the microphone")
	check(voice.killed_pid == 4321, "tree exit makes listener termination certain")
	check(voice._pid == -1 and not voice.listening and voice.status == "off", "tree exit clears all local listener state")
	print("VOICE_INPUT_LIFECYCLE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
