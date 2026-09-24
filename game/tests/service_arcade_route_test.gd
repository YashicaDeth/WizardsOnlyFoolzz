extends Node

const ARCADE := preload("res://service_arcade.tscn")

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
	var arcade = ARCADE.instantiate()
	add_child(arcade)
	await get_tree().process_frame
	arcade.player.global_position = arcade.CARD_AT
	arcade._interact()
	check(arcade.card_taken and not arcade.card_visual.visible and not arcade.card_label.visible, "the orange card can be collected at its physical pedestal without leaving a stale take prompt")
	arcade.player.global_position = arcade.WEAPON_AT
	arcade._interact()
	# It leaves the floor for your hands rather than vanishing (2026-09-24).
	check(arcade.weapon_taken and arcade.weapon_visual.get_parent() == arcade.camera and not arcade.weapon_label.visible, "the breach tool visibly confirms its pickup: it is in your hands")
	arcade.player.global_position = arcade.GATE_AT
	arcade._interact()
	check(arcade.gate_open and arcade.gate_body.is_queued_for_deletion(), "the pressure gate opens after the card is collected")
	arcade.gate_open = false
	arcade.gate_body = null
	arcade.player.global_position = arcade.GATE_AT + Vector3(0, 0, 4.2)
	arcade._physics_process(0.016)
	check(arcade.gate_open, "approaching the gate opens it if a transition-frame E press was missed")
	arcade._interact()
	check(arcade.lower_works_requested, "the opened gate's own control threshold carries the player onward instead of leaving them in the arcade")
	arcade.queue_free()
	print("SERVICE_ARCADE_ROUTE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
