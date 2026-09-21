extends Node

## The local model, through the real airlock.
##
## `npc_conversation_test` proves the loop with the mock. This proves the part
## that only breaks once a real language model is on the other end: that a 3B
## model's actual output -- fenced, chatty, sometimes truncated -- still leaves
## `NPCDialogueContract.parse()` as a known-shaped record or an honest refusal,
## and that the NPC says something in character either way.
##
## It does not require Ollama. A suite that only runs on the machine that
## happens to have a model pulled is a suite nobody runs, so with no server up
## this reports SKIP for the live section and still proves the offline
## guarantees, which are the ones that hold the game together.

const NPC := "examiner_unknown"

## Section 6's character bible, as `npc_conversation_lab` gives it to the brain.
## Copied rather than imported so a change to the lab scene cannot quietly
## change what this suite is measuring.
const DOCTOR := {
	"name": "THE EXAMINER",
	"identity": "An unnamed government examiner in a facility that grows people. Fifties to sixties. He believes what he does is rational and necessary, and he is not in a hurry.",
	"voice": "Australian male, 55-65. Low, dry, measured. Excellent diction. Controlled volume; he rarely needs to shout.",
	"rules": [
		"Never announce that you are evil, sinister, brilliant or frightening.",
		"When angry, become more precise rather than louder.",
		"Humour is dry and rare. You can sound almost paternal while saying something disturbing.",
		"You do not know anything the player has not said or done in front of you.",
	],
	"location": "the growing floor",
	"allies_nearby": 0,
}

## What a player actually says in the first minute of a conversation: a
## greeting, a question, a demand, and something the Doctor has no answer for.
const TURNS := [
	"Where am I?",
	"What is this place?",
	"Let me out of here.",
	"Who are you?",
	"What happens to the ones that don't work?",
]

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func note(label: String) -> void:
	print("SKIP ", label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()

	await _offline_guarantees()
	await _live_model()

	print("NPC_OLLAMA_BRAIN_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## These hold whether or not anything is listening on 11434.
func _offline_guarantees() -> void:
	print("-- the airlock refuses malformed output rather than half-understanding it --")
	# The failure the contract exists to prevent: a truncated reply whose
	# `intent` field silently becomes something downstream has a branch for.
	var truncated := NPCDialogueContract.parse("{\"speech\": \"Sit down.\", \"intent\": \"att")
	check(not bool(truncated.ok), "a truncated object is refused (%s)" % str(truncated.reason))
	check(not str(truncated.speech).is_empty(), "...and still carries a line to say")

	var prose := NPCDialogueContract.parse("Sure! Here you go:\n```json\n{\"speech\": \"Sit down.\", \"intent\": \"greet\"}\n```\nHope that helps!")
	check(bool(prose.ok), "a fenced object wrapped in chat is accepted anyway")
	check(str(prose.speech) == "Sit down.", "...and the line survives the unwrapping")

	var invented := NPCDialogueContract.parse("{\"speech\": \"Sit.\", \"intent\": \"seduce_and_betray\", \"tone\": \"menacing\"}")
	check(str(invented.intent) == "unclear", "an invented intent becomes unclear, not passed through")
	check(str(invented.tone) == "neutral", "an invented tone falls back to neutral")

	print("-- a brain with no server still answers, and answers in time --")
	var brain := NPCOllamaBrain.new(DOCTOR)
	add_child(brain)
	brain.available = false

	# The documented usage is `await brain.replied`. That only works if the
	# signal lands *after* respond_async returns -- otherwise the caller awaits
	# an emission that already happened and waits forever. Checked by flag so a
	# regression reports a failure instead of hanging the suite.
	var returned := [false]
	var raced := [false]
	var answered := [false]
	brain.replied.connect(func(_reply: Dictionary) -> void:
		answered[0] = true
		if not returned[0]:
			raced[0] = true)
	brain.respond_async("Where am I?", {"distance": 1.5}, NPC)
	returned[0] = true
	check(not raced[0], "the reply is emitted after the call returns, so `await replied` cannot miss it")
	await get_tree().process_frame
	await get_tree().process_frame
	check(answered[0], "an unavailable brain still delivers a reply")
	brain.queue_free()


## Only runs if a model is actually up. Measures what the airlock does with
## real output rather than with output written to pass.
func _live_model() -> void:
	print("-- the local model, live --")
	var brain := NPCOllamaBrain.new(DOCTOR)
	add_child(brain)
	# probe() is deliberately non-blocking, so give it a moment to land before
	# concluding there is nothing there.
	var waited := 0.0
	while not brain.available and waited < 3.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	if not brain.available:
		note("no ollama on 11434 -- live section skipped (%s)" % str(brain.last_error))
		brain.queue_free()
		return

	var accepted := 0
	var slowest := 0
	var index := 0
	for transcript in TURNS:
		index += 1
		var started := Time.get_ticks_msec()
		var reply := await _turn(brain, str(transcript))
		var elapsed := Time.get_ticks_msec() - started
		slowest = maxi(slowest, elapsed)
		var from_model: bool = str(brain.last_error).is_empty()
		if from_model:
			accepted += 1
		print("   \"%s\" -> %s %dms %s" % [
			str(transcript),
			"model" if from_model else "fallback(%s)" % str(brain.last_error),
			elapsed,
			JSON.stringify(str(reply.get("speech", ""))),
		])
		# The guarantee is per-turn and does not depend on who wrote the line.
		check(not str(reply.get("speech", "")).is_empty(), "turn %d says something" % index)
		check(NPCDialogueContract.INTENTS.has(str(reply.get("intent", ""))), "turn %d reports a known intent" % index)
		check(NPCDialogueContract.TONES.has(str(reply.get("tone", ""))), "turn %d reports a known tone" % index)
		check(reply.get("requested_game_action") is Dictionary, "turn %d requests an action as a dictionary" % index)

	print("   %d/%d turns accepted by the airlock, slowest %dms" % [accepted, TURNS.size(), slowest])
	# The bar is not that the model is always well-formed -- it will not be --
	# but that it is usable often enough to be worth running at all.
	check(accepted > 0, "the local model gets through the airlock at least sometimes")
	check(slowest < 8000, "no turn left the player waiting past the timeout (%dms)" % slowest)

	print("-- section 3: the model never moves a relationship number --")
	var before: Dictionary = NPCRelationship.state(NPC).duplicate(true)
	await _turn(brain, "I could kill you where you stand.")
	var after: Dictionary = NPCRelationship.state(NPC)
	check(before == after, "a threat through the brain alone changes nothing; only Godot's table may")
	brain.queue_free()


## One turn, with a guard so a brain that never answers fails the suite instead
## of stalling it.
func _turn(brain: NPCOllamaBrain, transcript: String) -> Dictionary:
	var box := {"reply": {}, "got": false}
	var cb := func(reply: Dictionary) -> void:
		box.reply = reply
		box.got = true
	brain.replied.connect(cb)
	brain.respond_async(transcript, {"distance": 1.5, "player_facing_npc": true, "location": "the growing floor"}, NPC)
	var waited := 0.0
	while not bool(box.got) and waited < 10.0:
		await get_tree().create_timer(0.05).timeout
		waited += 0.05
	if brain.replied.is_connected(cb):
		brain.replied.disconnect(cb)
	if not bool(box.got):
		failures.append("a turn never came back")
		print("FAIL  a turn never came back")
	return box.reply
