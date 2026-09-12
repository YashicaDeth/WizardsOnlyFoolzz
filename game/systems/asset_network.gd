class_name AssetNetwork
extends RefCounted

## F6. The handheld's coercive personnel channel. An asset is an existing
## person in WorldHistory, never a generated unit or an inventory token.

const TASKS := ["observe", "retrieve", "sabotage", "report"]


func mind_stamp(subject_id: String, anatomy_state: Dictionary = {}) -> Dictionary:
	var subject := WorldHistory.subject(subject_id)
	if subject.is_empty() or str(subject.get("kind", "person")) != "person":
		return {}
	if str(subject.get("status", "")) in ["dead", "executed"]:
		return {}
	var relations: Dictionary = subject.get("relations", {}).duplicate(true)
	relations["player"] = {"kind": "coerced", "strength": 100, "consensual": false}
	var changes := {
		"asset": true,
		"controller": "player",
		"status": "mind_stamped",
		"disposition": "asset",
		"relations": relations,
		"memory": "The handheld wrote the Hunter's command over my own intent.",
		"remote_task": {},
	}
	if not anatomy_state.is_empty():
		changes["anatomy_state"] = anatomy_state.duplicate(true)
	var stamped := WorldHistory.update_subject(subject_id, changes, "asset_mind_stamped")
	WorldHistory.record_event("nonconsensual_recruitment", {
		"actor": "player", "subject_id": subject_id, "method": "handheld_mind_stamp",
		"consensual": false,
	})
	return stamped


func assets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for subject_id in WorldHistory.all_subjects():
		var subject: Dictionary = WorldHistory.subject(str(subject_id))
		if bool(subject.get("asset", false)) and str(subject.get("controller", "")) == "player":
			var row := subject.duplicate(true)
			row["id"] = str(subject_id)
			result.append(row)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("name", a.id)) < str(b.get("name", b.id)))
	return result


func task(subject_id: String, command: String, target: String = "") -> Dictionary:
	var subject := WorldHistory.subject(subject_id)
	command = command.to_lower()
	if not _is_controlled(subject) or command not in TASKS:
		return {}
	var order := {"command": command, "target": target, "state": "queued"}
	WorldHistory.update_subject(subject_id, {"remote_task": order}, "asset_tasked")
	return order


func execute_task(subject_id: String) -> Dictionary:
	var subject := WorldHistory.subject(subject_id)
	if not _is_controlled(subject):
		return {}
	var order: Dictionary = subject.get("remote_task", {})
	if order.is_empty() or str(order.get("state", "")) != "queued":
		return {}
	order = order.duplicate(true)
	order["state"] = "executing"
	order["started_at"] = WorldHistory.event_count() + 1
	WorldHistory.update_subject(subject_id, {"remote_task": order, "status": "deployed"}, "asset_task_executed")
	WorldHistory.record_event("remote_asset_command", {
		"actor": "player", "subject_id": subject_id,
		"command": order.command, "target": order.target,
	})
	return order


func roster_line() -> String:
	var roster := assets()
	if roster.is_empty():
		return "ASSETS // NONE STAMPED"
	var labels: Array[String] = []
	for asset in roster:
		var order: Dictionary = asset.get("remote_task", {})
		var state := str(order.get("command", asset.get("status", "idle"))).to_upper()
		labels.append("%s [%s]" % [str(asset.get("name", asset.id)).to_upper(), state])
	return "ASSETS // " + "  ·  ".join(labels)


func _is_controlled(subject: Dictionary) -> bool:
	return bool(subject.get("asset", false)) and str(subject.get("controller", "")) == "player"
