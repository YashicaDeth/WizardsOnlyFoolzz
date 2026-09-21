class_name NPCOllamaBrain
extends Node

## A real language model behind the examiner, running on this machine.
##
## Greg: "do the local we can do that and then we can have much much freerer
## dialogue." So: Ollama on localhost, no key, no account, no network once the
## model is pulled, and nothing leaving the machine.
##
## This changes only who writes the sentence. Everything the spec's
## architecture rule protects stays exactly where it was:
##
##   - the reply still goes through `NPCDialogueContract.parse()`, so a model
##     that returns prose, truncated JSON or an invented intent is refused the
##     same way the mock would be;
##   - it still only *requests* actions, and `NPCActionValidator` still rules;
##   - it still cannot touch a relationship number.
##
## A local 3B model will produce malformed JSON sometimes. That is not a
## problem to be prompted away, it is the reason the airlock was built first.
## When parsing fails, `MockBrain` answers instead and the player gets a line
## in character rather than a stutter.

signal thinking_started()
signal thinking_finished(latency_ms: int)

const ENDPOINT := "http://127.0.0.1:11434/api/generate"
const DEFAULT_MODEL := "llama3.2:3b"
## A conversational turn that takes four seconds is not a conversation. Past
## this the fallback answers instead -- late and in character beats correct and
## silent.
const TIMEOUT_SECONDS := 6.0

var model := DEFAULT_MODEL
var character: Dictionary = {}
var fallback: RefCounted
var last_error := ""
var available := false

var _http: HTTPRequest
var _pending := false
var _started_ms := 0
var _npc_id := ""
var _memories: Array = []


func _init(character_definition: Dictionary = {}) -> void:
	character = character_definition
	fallback = NPCDialogueBrain.MockBrain.new(character_definition)


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT_SECONDS
	add_child(_http)
	_http.request_completed.connect(_on_response)
	probe()


## Non-blocking check that a server is actually up. `available` stays false
## until one answers, so a game launched without Ollama running simply uses the
## mock and never stalls on a connection that is not coming.
func probe() -> void:
	var checker := HTTPRequest.new()
	checker.timeout = 2.0
	add_child(checker)
	checker.request_completed.connect(func(_result, code, _headers, _body):
		available = code == 200
		last_error = "" if available else "ollama not responding"
		checker.queue_free())
	if checker.request("http://127.0.0.1:11434/api/tags") != OK:
		available = false
		checker.queue_free()


## Matches `MockBrain.respond()`'s signature but answers later, so the caller
## awaits the signal rather than the return. The component treats a brain that
## is still thinking as a brain that has not spoken yet.
func respond_async(transcript: String, perception: Dictionary, npc_id: String, memories: Array = []) -> void:
	if _pending or not available:
		_deliver(fallback.respond(transcript, perception, npc_id))
		return
	_npc_id = npc_id
	_memories = memories
	_pending = true
	_started_ms = Time.get_ticks_msec()
	thinking_started.emit()

	var prompt := NPCDialogueBrain.prompt_for(character, perception, npc_id, transcript, memories)
	var payload := {
		"model": model,
		"prompt": prompt,
		"stream": false,
		# Ollama will hold the reply to the schema itself, which removes most of
		# the malformed-JSON problem at the source rather than catching it after.
		"format": "json",
		"options": {
			# Warm enough that he does not answer identically twice, cold enough
			# that he stays the same man. Section 6's performance is restrained.
			"temperature": 0.75,
			"top_p": 0.9,
			# A two-sentence reply does not need more, and every token is
			# latency the player is standing there waiting through.
			"num_predict": 160,
		},
	}
	var headers := ["Content-Type: application/json"]
	var error := _http.request(ENDPOINT, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		_pending = false
		last_error = "request failed: %d" % error
		_deliver(fallback.respond(transcript, perception, npc_id))


func _on_response(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_pending = false
	if code != 200:
		last_error = "http %d" % code
		_deliver(_fallback_now())
		return
	var envelope: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (envelope is Dictionary) or not (envelope as Dictionary).has("response"):
		last_error = "unexpected envelope"
		_deliver(_fallback_now())
		return
	# The model's text goes through the same airlock as everything else. It is
	# not trusted more for being local.
	var reply := NPCDialogueContract.parse(str((envelope as Dictionary).response))
	if not bool(reply.ok):
		last_error = "unparseable: %s" % str(reply.reason)
		_deliver(_fallback_now())
		return
	last_error = ""
	_deliver(reply)


func _fallback_now() -> Dictionary:
	return fallback.respond("", {"distance": 1.0}, _npc_id)


func _deliver(reply: Dictionary) -> void:
	thinking_finished.emit(Time.get_ticks_msec() - _started_ms)
	replied.emit(reply)


signal replied(reply: Dictionary)
