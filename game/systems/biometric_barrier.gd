class_name BiometricBarrier
extends Node3D

## The facility authenticates tissue, not consent. A guard's body remains a
## credential whether they walk to the reader, are dragged there, or arrive in
## pieces. Life state is deliberately absent from the decision.

signal access_granted(subject_id: String, method: String)
signal access_refused(reason: String)

@export var barrier_id := "d_section_biometric_01"
@export var authorized_subject_ids: Array[String] = []
@export var implant_spoof_enabled := false

var opened := false
var last_readout := "PRESENT AUTHORIZED BIOMETRIC"


func present_body(body: Node) -> Dictionary:
	if body == null or not is_instance_valid(body):
		return _refuse("NO BODY PRESENT")
	var subject_id := str(body.get_meta("subject_id", ""))
	return _authorize(subject_id, "whole_body")


func present_anatomy(sample: Dictionary) -> Dictionary:
	var subject_id := str(sample.get("subject_id", ""))
	var anatomy_id := str(sample.get("zone", sample.get("organ_id", sample.get("limb_id", ""))))
	if anatomy_id.is_empty():
		return _refuse("NO READABLE TISSUE")
	return _authorize(subject_id, "removed_anatomy")


func present_implant_spoof(subject_id: String) -> Dictionary:
	if not implant_spoof_enabled:
		return _refuse("IMPLANT HANDSHAKE REJECTED")
	return _authorize(subject_id, "implant_spoof")


func _authorize(subject_id: String, method: String) -> Dictionary:
	if subject_id.is_empty() or subject_id not in authorized_subject_ids:
		return _refuse("BIOMETRIC NOT CLEARED")
	opened = true
	last_readout = "IDENTITY ACCEPTED // %s" % subject_id.to_upper()
	access_granted.emit(subject_id, method)
	WorldHistory.record_event("facility_biometric_access", {
		"barrier_id": barrier_id,
		"subject_id": subject_id,
		"method": method,
	})
	return {"accepted": true, "subject_id": subject_id, "method": method}


func _refuse(reason: String) -> Dictionary:
	last_readout = reason
	access_refused.emit(reason)
	return {"accepted": false, "reason": reason}
