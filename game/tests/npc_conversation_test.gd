extends Node

## The conversation component's own contract, headless.
##
## The suite above it (`npc_relationship_test`) proves the spine in isolation.
## This proves the part that is easy to get subtly wrong once the pieces are
## wired together: that the NPC speaks *after* the ruling rather than before,
## that overhearing is not being spoken to, and that a refused action is not
## narrated as though it succeeded.

const NPC := "lab_examiner"

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()

	var player := Node3D.new()
	add_child(player)
	player.global_position = Vector3(0, 0, 2.0)

	var component := NPCConversationComponent.new()
	add_child(component)
	component.global_position = Vector3.ZERO
	component.configure(NPC, {"name": "EXAMINER", "location": "the lab"}, player)
	await get_tree().process_frame

	print("-- section 4: perception is Godot's, not the model's --")
	var perception := component.perceive()
	check(absf(float(perception.distance) - 2.0) < 0.2, "the component measures real distance (%.2f)" % float(perception.distance))
	check(not bool(perception.player_weapon_drawn), "an undrawn weapon is reported as undrawn")
	check(not perception.has("secret"), "no hidden world facts leak into perception")

	print("-- a turn moves the relationship and returns a line --")
	var greeting := component.hear("Hey, hello.")
	check(bool(greeting.get("ok", false)), "a greeting inside the interaction radius is answered")
	check(not str(greeting.get("speech", "")).is_empty(), "the NPC actually says something")
	check(float(NPCRelationship.state(NPC).familiarity) > 0.0, "talking to someone makes you less of a stranger")

	print("-- section 4: overhearing is not being spoken to --")
	player.global_position = Vector3(0, 0, 10.0)
	var overheard := component.hear("Hey, hello.")
	check(not bool(overheard.get("ok", false)), "speech from outside the interaction radius is not treated as directed")
	check(str(overheard.get("reason", "")) == "not_addressed", "...and says so plainly (%s)" % str(overheard.get("reason", "")))
	player.global_position = Vector3(0, 0, 60.0)
	var shouted := component.hear("Hello?")
	check(str(shouted.get("reason", "")) == "out_of_earshot", "speech from outside hearing range is not heard at all")

	print("-- section 5: the NPC speaks from what happened, not what it asked --")
	player.global_position = Vector3(0, 0, 2.0)
	WorldHistory.amend_subject("player", {"weapon_drawn": true})
	var robbery := component.hear("Hand over everything you're carrying.")
	check(bool(robbery.get("ok", false)), "a robbery demand is answered")
	var result: Dictionary = robbery.get("result", {})
	check(str(result.get("requested", "")) == "consider_robbery_compliance", "the brain requested a ruling")
	check(["refuse", "comply", "flee", "call_for_help", "attack"].has(str(result.get("action", ""))), "Godot chose a legal outcome (%s)" % str(result.get("action", "")))
	check(str(robbery.get("speech", "")).contains(str(result.get("fact", "!!"))), "the spoken line carries what actually happened, not what was asked for")
	check(float(NPCRelationship.state(NPC).fear) > 0.0, "being threatened with a weapon frightened them")

	print("-- memory is durable facts, not a transcript --")
	check(component.memories().size() > 0, "a durable fact was remembered")
	check(component.memories().size() <= component.MAX_MEMORIES, "memory stays bounded")

	print("-- latency is measured, for the debug HUD --")
	check(int(robbery.get("latency_ms", -1)) >= 0, "a turn reports how long it took")

	print("NPC_CONVERSATION_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
