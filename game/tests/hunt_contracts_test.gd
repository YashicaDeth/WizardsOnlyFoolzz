extends Node

const CONTRACTS := preload("res://systems/hunt_contracts.gd")
const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")

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
	CosmologyFactions._seed()
	AscentEntities.seed_entities()
	TheFourHorsemen.seed_horsemen()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person", "bond": 40.0})
	WorldHistory.register_subject("signal_broker", {"name": "THE SIGNAL BROKER", "kind": "person", "status": "active"})

	var unnoticed := CONTRACTS.publish("clear_frequency", "signal_broker", "frequency", "Pins a dead carrier over the Clear Frequency", "blood", 300.0)
	check(not bool(unnoticed.get("ok", false)), "an ascent entity cannot post top-tier work before it has actually noticed the player")
	WorldHistory.amend_subject("clear_frequency", {"has_noticed": true})
	var malformed := CONTRACTS.publish("clear_frequency", "signal_broker", "crime", "Is allegedly bad", "blood", 300.0)
	check(not bool(malformed.get("ok", false)), "a moral label cannot substitute for a frequency or aura obstruction")

	var offered := CONTRACTS.publish("clear_frequency", "signal_broker", "frequency", "Pins a dead carrier over the Clear Frequency", "blood", 300.0)
	var contract_id := str(offered.get("id", ""))
	check(bool(offered.get("ok", false)) and not contract_id.is_empty(), "a noticed ascent patron publishes one exact-target job")
	check(str(offered.get("target_id", "")) == "signal_broker" and str(offered.get("patron_side", "")) == "ascent", "the offer keeps its real patron, side, target and obstruction")
	check(CONTRACTS.offers().size() == 1, "the unconsumed offer appears in the live job market")

	var blood_before := float(WorldHistory.subject("player").get("anatomy_state", {}).get("blood", 5000.0))
	var accepted := CONTRACTS.accept(contract_id)
	var blood_after := float(WorldHistory.subject("player").get("anatomy_state", {}).get("blood", 5000.0))
	check(bool(accepted.get("ok", false)) and str(accepted.get("status", "")) == "active", "taking the offer consumes it into one active contract")
	check(is_equal_approx(blood_before - blood_after, 300.0), "acceptance costs the promised 300 blood in the real anatomy ledger")
	check(int(accepted.get("uses_remaining", -1)) == 0 and CONTRACTS.offers().is_empty() and CONTRACTS.active().size() == 1, "the consumed offer cannot remain for another hunter")
	var second := CONTRACTS.accept(contract_id)
	var blood_after_second := float(WorldHistory.subject("player").get("anatomy_state", {}).get("blood", 5000.0))
	check(not bool(second.get("ok", true)) and is_equal_approx(blood_after, blood_after_second), "accepting the same contract twice is refused without charging twice")
	check(PLAYER_ACTION_LEDGER.count("hunt_contract_consumed") == 1, "the entire acceptance has one compact player-action receipt")

	var early := CONTRACTS.resolve(contract_id)
	check(not bool(early.get("ok", true)), "the contract cannot complete while its exact target still blocks the frequency")
	WorldHistory.amend_subject("signal_broker", {"status": "spared"})
	var completed := CONTRACTS.resolve(contract_id)
	check(bool(completed.get("ok", false)) and str(completed.get("target_outcome", "")) == "spared", "a real nonlethal target resolution completes the exact contract")

	var false_crown := CONTRACTS.publish("famine", "signal_broker", "aura", "Holds a ration aura across the route", "standing", 5.0)
	check(not bool(false_crown.get("ok", false)), "a waiting Horseman cannot pose as the current top demon")
	WorldHistory.register_subject("aura_keeper", {"name": "AURA KEEPER", "kind": "person", "status": "active"})
	var crown_offer := CONTRACTS.publish("war", "aura_keeper", "aura", "Keeps the pit's panic aura coherent", "standing", 5.0)
	check(bool(crown_offer.get("ok", false)) and str(crown_offer.get("patron_side", "")) == "descent", "the live CROWN holder can publish top-demon work through the same market")
	WorldHistory.register_subject("empty_hunter", {
		"name": "EMPTY HUNTER", "kind": "person",
		"anatomy_state": {"blood": 200.0, "blood_capacity": 5000.0},
	})
	var blood_offer := CONTRACTS.publish("war", "aura_keeper", "aura", "Keeps the pit's panic aura coherent", "blood", 300.0)
	var refused := CONTRACTS.accept(str(blood_offer.get("id", "")), "empty_hunter")
	var still_offered := WorldHistory.subject(str(blood_offer.get("id", "")))
	check(not bool(refused.get("ok", true)) and str(still_offered.get("status", "")) == "offered" and int(still_offered.get("uses_remaining", 0)) == 1,
		"a hunter who cannot pay is refused without silently consuming the offer")

	print("HUNT_CONTRACTS_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
