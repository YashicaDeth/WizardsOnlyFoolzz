class_name FacilityCheckpoints
extends Node

## Close v0.1 checkpoints on the connected facility route. WorldHistory
## already persists each amendment; this node records the latest safe place
## and restores it when Continue opens vat_chamber again. Rebirth always wins
## and starts in the tank instead.

const SUBJECT := "facility_checkpoint"
const SCENE := "res://vat_chamber.tscn"

var host: Node
var player: CharacterBody3D
var facility: Node3D
var _vat_filed := false


func setup(route_host: Node, body: CharacterBody3D, connected_facility: Node3D) -> void:
	host = route_host
	player = body
	facility = connected_facility
	name = "FacilityCheckpoints"
	for lift_id: String in facility.lifts:
		var lift: FacilityElevator = facility.lifts[lift_id]
		lift.arrived.connect(_on_lift_arrived.bind(lift_id, lift))
	restore()


func _process(_delta: float) -> void:
	if player == null or facility == null:
		return
	if not _vat_filed and bool(host.get("breakout_complete")):
		_vat_filed = true
		file("vat", player.global_position)
	# The examiner office threshold is the first close checkpoint after the vat.
	if player.global_position.x > 6.5 and player.global_position.x < 10.5 and player.global_position.y > -2.0:
		file("examiner_office_door", player.global_position)


func _on_lift_arrived(stop: int, lift_id: String, lift: FacilityElevator) -> void:
	file("%s_lift_%d" % [lift_id, stop], lift.cab.global_position + Vector3(0, 0.35, 0))


func file(checkpoint_id: String, at: Vector3) -> void:
	var current := WorldHistory.subject(SUBJECT)
	if str(current.get("id", "")) == checkpoint_id:
		return
	var data := {"kind": "checkpoint", "id": checkpoint_id, "scene": SCENE, "position": [at.x, at.y, at.z]}
	WorldHistory.begin_ledger_batch()
	WorldHistory.update_subject(SUBJECT, data, "facility_checkpoint_reached")
	WorldHistory.record_event("facility_checkpoint_reached", {"checkpoint": checkpoint_id, "location": checkpoint_id})
	WorldHistory.commit_ledger_batch()


func restore() -> bool:
	if VatRebirth.is_pending():
		return false
	var saved := WorldHistory.subject(SUBJECT)
	if saved.is_empty() or str(saved.get("scene", "")) != SCENE:
		return false
	var at: Array = saved.get("position", [])
	if at.size() != 3:
		return false
	player.global_position = Vector3(float(at[0]), float(at[1]), float(at[2]))
	if host.has_method("_resume_from_checkpoint"):
		host.call("_resume_from_checkpoint")
	WorldHistory.record_event("facility_checkpoint_restored", {"checkpoint": str(saved.get("id", ""))})
	return true
