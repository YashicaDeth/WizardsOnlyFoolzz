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

	func _init(preferred_language := "en_AU") -> void:
		voice_id = NPCSpeechOutput.best_voice(preferred_language, true)

	func speak(text: String, interrupt: bool = true) -> void:
		if voice_id.is_empty() or text.strip_edges().is_empty():
			return
		DisplayServer.tts_speak(text, voice_id, volume, pitch, rate, 0, interrupt)

	func stop() -> void:
		DisplayServer.tts_stop()

	func is_speaking() -> bool:
		return DisplayServer.tts_is_speaking()


## Subtitles only. Used when the OS has no speech, and in headless tests, where
## the point is that the conversation loop does not care which one it has.
class SilentVoice extends Voice:
	var last_spoken := ""

	func speak(text: String, _interrupt: bool = true) -> void:
		last_spoken = text


## Chooses for the caller: a real voice where one exists, silence where none
## does. No configuration required to get the better of the two.
static func make(preferred_language := "en_AU") -> Voice:
	if available():
		return NativeVoice.new(preferred_language)
	return SilentVoice.new()
