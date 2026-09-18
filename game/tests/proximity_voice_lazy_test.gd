extends Node

## Runs without ATG_TEST_MODE deliberately: initialising the production Hunt
## must not open a Windows capture device before the player asks to speak.

func _ready() -> void:
	var voice := ProximityVoice.new()
	add_child(voice)
	await get_tree().process_frame
	var passed := not voice.available and voice.microphone == null and not voice.is_processing()
	print("PASS " if passed else "FAIL ", "proximity voice leaves the microphone closed until first use")
	get_tree().quit(0 if passed else 1)
