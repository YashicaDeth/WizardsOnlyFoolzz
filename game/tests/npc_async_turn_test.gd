extends Node

## A turn answered on a later frame is still the same turn.
##
## `NPCConversationComponent.hear()` returned its reply on the frame it was
## called, which is why the Ollama brain could never be wired to it: a model
## over HTTP cannot answer on that frame. The obvious fix -- a second code path
## for async brains -- is the one that rots, because the ruling, the
## relationship move, the memory and the spoken line would exist twice and
## drift apart.
##
## So there is one `_resolve()` and two ways of reaching it. This proves that
## the async way reaches it with everything intact, using a stub brain rather
## than a live model, because a suite that only passes on a machine with a
## model pulled is a suite nobody runs.

const NPC := "async_examiner"

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


## The smallest thing that behaves like a language model: it answers late, and
## it answers over a signal.
class StubAsyncBrain extends Node:
	signal replied(reply: Dictionary)

	var delivered := 0

	func respond_async(_transcript: String, _perception: Dictionary, _npc_id: String, _memories: Array = []) -> void:
		# Late, deliberately. Answering synchronously here would let a
		# regression in the component pass this suite.
		_answer.call_deferred()

	func _answer() -> void:
		delivered += 1
		replied.emit({
			"ok": true,
			"addressed_to_npc": true,
			"intent": "threaten_and_rob",
			"tone": "cold",
			"speech": "Hand me what you are carrying.",
			"requested_game_action": {"type": "consider_robbery_compliance", "target": "player"},
			"memory_candidate": "asked me for everything I had",
			"emotion": {},
		})


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()

	var player := Node3D.new()
	add_child(player)
	player.global_position = Vector3(0, 0, 1.5)

	var component := NPCConversationComponent.new()
	add_child(component)
	component.global_position = Vector3.ZERO
	var brain := StubAsyncBrain.new()
	component.configure(NPC, {"name": "EXAMINER", "identity": "An examiner."}, player, brain)
	await get_tree().process_frame

	# The defect this suite missed the first time. A Node brain left outside the
	# tree never runs `_ready()`, so `NPCOllamaBrain` never probes, never reports
	# itself available, and quietly answers from the mock forever. The stub does
	# not need `_ready()`, which is why every other check here still passed.
	check(brain.is_inside_tree(), "a Node brain is put in the tree, or it never gets _ready()")

	# Connected before the turn is dispatched, and through a Dictionary rather
	# than a bare local: GDScript lambdas capture locals by *value*, so
	# `turn = finished` inside one assigns to the closure's own copy and the
	# outer variable never changes. A Dictionary is a reference and does.
	var box := {"turn": {}}
	component.answered.connect(func(finished: Dictionary) -> void: box.turn = finished)

	# A demand from someone empty-handed is not a robbery, and the validator
	# rules it `none` -- correctly. `npc_conversation_test` arms the player for
	# the same reason: the interesting path is the one where the threat is real.
	WorldHistory.amend_subject("player", {"weapon_drawn": true})

	print("-- a brain that cannot answer yet says so, rather than refusing --")
	var immediate := component.hear("Hand over everything.")
	check(not bool(immediate.get("ok", false)), "the call does not return a finished turn")
	check(bool(immediate.get("pending", false)), "it returns a pending marker")
	check(str(immediate.get("reason", "")) == "thinking", "...that says what it is waiting for (%s)" % str(immediate.get("reason", "")))
	check(component.thinking, "and the component knows it is mid-turn")

	print("-- and the turn arrives whole --")
	var waited := 0.0
	while (box.turn as Dictionary).is_empty() and waited < 5.0:
		await get_tree().create_timer(0.05).timeout
		waited += 0.05
	var turn: Dictionary = box.turn
	check(not turn.is_empty(), "the answer landed (%.2fs)" % waited)
	check(bool(turn.get("ok", false)), "as a finished turn")
	check(str(turn.get("speech", "")) != "", "with a line in it")
	check(not component.thinking, "and the component is no longer mid-turn")

	print("-- section 5: it went through the ruling, not around it --")
	var result: Dictionary = turn.get("result", {})
	check(str(result.get("requested", "")) == "consider_robbery_compliance", "the action it asked for was put to the validator")
	check(["refuse", "comply", "flee", "call_for_help", "attack"].has(str(result.get("action", ""))), "and Godot chose the outcome (%s)" % str(result.get("action", "")))
	check(str(turn.get("speech", "")).contains(str(result.get("fact", "!!"))), "the spoken line carries what happened, not what was asked for")

	print("-- section 3: the relationship moved, and Godot moved it --")
	check(float(NPCRelationship.state(NPC).familiarity) > 0.0, "talking to him made the player less of a stranger")
	check(component.memories().size() > 0, "and a durable fact was kept")
	check(int(turn.get("latency_ms", -1)) >= 0, "the turn reports how long it took")

	print("-- overhearing is still not being spoken to, on the async path --")
	player.global_position = Vector3(0, 0, 40.0)
	var shouted := component.hear("Hello?")
	check(str(shouted.get("reason", "")) == "out_of_earshot", "speech from far outside hearing never reaches the brain")
	check(brain.delivered == 1, "and the brain was not asked a second time (%d)" % brain.delivered)

	print("NPC_ASYNC_TURN_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
