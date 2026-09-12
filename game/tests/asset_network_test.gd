extends Node

const ASSET_NETWORK := preload("res://systems/asset_network.gd")

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
	check(network.mind_stamp("dead_witness").is_empty(), "a corpse cannot be recruited")
	check(network.assets().size() == 1 and str(network.assets()[0].id) == "wounded_witness", "the handheld roster lists controlled people")
	var order := network.task("wounded_witness", "observe", "bone_yard_gate")
	check(str(order.get("state", "")) == "queued", "an asset can receive a remote task")
	var running := network.execute_task("wounded_witness")
	check(str(running.get("state", "")) == "executing", "the queued task can be remotely executed")
	check(WorldHistory.event_count("remote_asset_command") == 1, "remote execution enters world history")
	check(network.task("wounded_witness", "become_a_menu_unit").is_empty(), "only authored world verbs can be tasked")
	print("ASSET_NETWORK_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
