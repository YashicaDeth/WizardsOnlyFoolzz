class_name FacilityGuardLoadout
extends RefCounted

## One physical guard owns both answers to the encounter: their biometric
## identity opens the barrier and their weapon becomes the player's first gun.

const FIRST_GUN_ROUNDS := 3

var subject_id: String
var gun_available := true


func _init(guard_subject_id := "guard_hollis") -> void:
	subject_id = guard_subject_id


func attach_to(guard: Node) -> void:
	guard.set_meta("subject_id", subject_id)
	guard.set_meta("facility_weapon", "facility_sidearm")
	guard.set_meta("facility_rounds", FIRST_GUN_ROUNDS)


func take_sidearm(guard: Node, arsenal: HunterArsenal) -> Dictionary:
	if not gun_available:
		return {"accepted": false, "reason": "already_taken"}
	if guard == null or arsenal == null or str(guard.get_meta("subject_id", "")) != subject_id:
		return {"accepted": false, "reason": "wrong_guard"}
	var anatomy = guard.get("anatomy")
	var disarmed := bool(guard.get_meta("disarmed", false))
	if anatomy == null or (not bool(anatomy.downed) and not bool(anatomy.dead) and not disarmed):
		return {"accepted": false, "reason": "guard_still_holds_it"}
	if not arsenal.acquire_facility_sidearm(FIRST_GUN_ROUNDS):
		return {"accepted": false, "reason": "transfer_failed"}
	gun_available = false
	guard.set_meta("facility_weapon", "")
	guard.set_meta("facility_rounds", 0)
	WorldHistory.record_event("facility_guard_weapon_taken", {
		"subject_id": subject_id,
		"weapon": "facility_sidearm",
		"rounds": FIRST_GUN_ROUNDS,
	})
	return {"accepted": true, "weapon": "facility_sidearm", "rounds": FIRST_GUN_ROUNDS}
