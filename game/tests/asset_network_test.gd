extends Node

const ASSET_NETWORK := preload("res://systems/asset_network.gd")
const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")

var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition: failures.append(label)

func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	WorldHistory.register_subject("wounded_witness", {"name": "Wounded Witness", "kind": "person", "status": "downed", "relations": {}})
	WorldHistory.register_subject("dead_witness", {"name": "Dead Witness", "kind": "person", "status": "dead"})
	var network := ASSET_NETWORK.new()
	var stamped := network.mind_stamp("wounded_witness", {"downed": true})
	check(bool(stamped.get("asset", false)), "a real downed person is made an asset")
	check(not bool(((stamped.relations as Dictionary).player as Dictionary).consensual), "the coercion is explicit rather than disguised as consent")
	var recruitment_events := WorldHistory.events.filter(func(event: Dictionary) -> bool: return str(event.get("type", "")) == "nonconsensual_recruitment")
	check(PLAYER_ACTION_LEDGER.count("nonconsensual_recruitment") == 1 and recruitment_events.size() == 1 and str((recruitment_events[0].get("details", {}) as Dictionary).get("action_id", "")).begins_with("action_"), "the rewrite and recruitment fact share one identified player act")
	check(network.mind_stamp("dead_witness").is_empty(), "a corpse cannot be recruited")
	check(network.assets().size() == 1 and str(network.assets()[0].id) == "wounded_witness", "the handheld roster lists controlled people")
	var order := network.task("wounded_witness", "observe", "bone_yard_gate")
	check(str(order.get("state", "")) == "queued", "an asset can receive a remote task")
	check(PLAYER_ACTION_LEDGER.count("asset_tasked") == 1, "issuing the queued order enters the player-action ledger once")
	var running := network.execute_task("wounded_witness")
	check(str(running.get("state", "")) == "executing", "the queued task can be remotely executed")
	var command_events := WorldHistory.events.filter(func(event: Dictionary) -> bool: return str(event.get("type", "")) == "remote_asset_command")
	check(command_events.size() == 1 and PLAYER_ACTION_LEDGER.count("remote_asset_command") == 1 and str((command_events[0].get("details", {}) as Dictionary).get("action_id", "")).begins_with("action_"), "remote execution enters world history through one identified player act")
	check(network.task("wounded_witness", "become_a_menu_unit").is_empty(), "only authored world verbs can be tasked")
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0, "every asset transaction closes its nested ledger batch")
	print("ASSET_NETWORK_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
