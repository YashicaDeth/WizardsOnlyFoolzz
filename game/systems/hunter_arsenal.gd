class_name HunterArsenal
extends Node

## One combat vocabulary for held weapons. The arsenal decides timing, spread,
## ammunition and the model in the hunter's real hand; BaselineHuman remains
## the authority for what a hit does to flesh, bone, organs and prosthetics.

const HUNTER_BODY_MOTION := preload("res://systems/hunter_body_motion.gd")

signal equipped(weapon_id: String)
signal fired(weapon_id: String, report: Dictionary)
signal reload_started(weapon_id: String)
signal reload_finished(weapon_id: String)

const WEAPONS := {
	"sword": {
		"label": "ASHLINE CLEAVER", "kind": "melee", "damage": 44.0,
		"impulse": 28.0, "reach": 3.7, "cooldown": 0.58,
		"windup": 0.28, "stamina": 20.0, "damage_type": "cut",
	},
	"shotgun": {
		"label": "BONE YARD 12G", "kind": "firearm", "damage": 16.0,
		"impulse": 34.0, "range": 42.0, "cooldown": 0.92,
		"pellets": 10, "spread": 0.075, "magazine": 5, "reserve": 25,
		"reload": 2.15, "damage_type": "ballistic",
	},
	"sidearm": {
		"label": "MERCY NINE", "kind": "firearm", "damage": 38.0,
		"impulse": 18.0, "range": 76.0, "cooldown": 0.28,
		"pellets": 1, "spread": 0.008, "magazine": 10, "reserve": 50,
		"reload": 1.3, "damage_type": "ballistic",
	},
}
const SLOT_ORDER := ["sword", "shotgun", "sidearm"]

var current_id := "sword"
var cooldown := 0.0
var reload_remaining := 0.0
var shot_serial := 0
var ammo := {
	"shotgun": {"loaded": 5, "reserve": 25},
	"sidearm": {"loaded": 10, "reserve": 50},
}
var models: Dictionary = {}
var hand: Node3D


func configure(rig: BaselineHuman) -> void:
	hand = rig.parts.get("right_arm") as Node3D
	if hand == null:
		return
	for weapon_id in SLOT_ORDER:
		var model := _build_weapon_model(weapon_id)
		hand.add_child(model)
		models[weapon_id] = model
	_update_models()


func tick(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if reload_remaining <= 0.0:
		return
	reload_remaining = maxf(0.0, reload_remaining - delta)
	if reload_remaining <= 0.0:
		_finish_reload()


func select_slot(slot: int) -> bool:
	if slot < 0 or slot >= SLOT_ORDER.size() or reload_remaining > 0.0:
		return false
	current_id = SLOT_ORDER[slot]
	_update_models()
	equipped.emit(current_id)
	return true


func current() -> Dictionary:
	return WEAPONS[current_id]


func state() -> Dictionary:
	var definition: Dictionary = current()
	var rounds := ammo.get(current_id, {}) as Dictionary
	return {
		"id": current_id,
		"label": definition.label,
		"kind": definition.kind,
		"loaded": int(rounds.get("loaded", -1)),
		"reserve": int(rounds.get("reserve", -1)),
		"reloading": reload_remaining > 0.0,
		"reload_ratio": reload_remaining / float(definition.get("reload", 1.0)) if reload_remaining > 0.0 else 0.0,
	}


func begin_attack(heavy := false) -> Dictionary:
	var definition: Dictionary = current()
	if cooldown > 0.0 or reload_remaining > 0.0:
		return {"accepted": false, "reason": "busy"}
	if definition.kind == "firearm":
		var rounds: Dictionary = ammo[current_id]
		if int(rounds.loaded) <= 0:
			return {"accepted": false, "reason": "empty"}
		rounds.loaded = int(rounds.loaded) - 1
		ammo[current_id] = rounds
	cooldown = float(definition.cooldown) * (1.45 if heavy else 1.0)
	shot_serial += 1
	return {
		"accepted": true,
		"weapon": current_id,
		"kind": definition.kind,
		"damage": float(definition.damage) * (1.55 if heavy and definition.kind == "melee" else 1.0),
		"impulse": float(definition.impulse) * (1.4 if heavy else 1.0),
		"damage_type": definition.damage_type,
		"windup": float(definition.get("windup", 0.0)) * (1.35 if heavy else 1.0),
		"stamina": float(definition.get("stamina", 0.0)) * (1.55 if heavy else 1.0),
		"pellets": int(definition.get("pellets", 1)),
		"spread": float(definition.get("spread", 0.0)),
		"range": float(definition.get("range", definition.get("reach", 3.0))),
		"heavy": heavy,
	}


func reload() -> bool:
	var definition: Dictionary = current()
	if definition.kind != "firearm" or reload_remaining > 0.0 or cooldown > 0.0:
		return false
	var rounds: Dictionary = ammo[current_id]
	if int(rounds.loaded) >= int(definition.magazine) or int(rounds.reserve) <= 0:
		return false
	reload_remaining = float(definition.reload)
	reload_started.emit(current_id)
	return true


func shot_directions(forward: Vector3, up: Vector3) -> Array[Vector3]:
	var definition: Dictionary = current()
	var count := int(definition.get("pellets", 1))
	var spread := float(definition.get("spread", 0.0))
	var result: Array[Vector3] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [current_id, shot_serial])
	var right := forward.cross(up).normalized()
	var corrected_up := right.cross(forward).normalized()
	for pellet in count:
		var radius := sqrt(rng.randf()) * spread
		var angle := rng.randf() * TAU
		result.append((forward + right * cos(angle) * radius + corrected_up * sin(angle) * radius).normalized())
	return result


func _finish_reload() -> void:
	var definition: Dictionary = current()
	if definition.kind != "firearm":
		return
	var rounds: Dictionary = ammo[current_id]
	var needed := int(definition.magazine) - int(rounds.loaded)
	var moved := mini(needed, int(rounds.reserve))
	rounds.loaded = int(rounds.loaded) + moved
	rounds.reserve = int(rounds.reserve) - moved
	ammo[current_id] = rounds
	reload_finished.emit(current_id)


func _update_models() -> void:
	for weapon_id in models:
		(models[weapon_id] as Node3D).visible = weapon_id == current_id


## M4.4 / the first-person pass. This used to build each weapon out of three
## `BoxMesh` primitives with hand-tuned counter-rotations cancelling the arm
## pose, and every comment in it was about fighting that inheritance rather than
## about the weapon. `HeldGear` owns the geometry now — swept sections with a
## real edge on the blade and a real rake on the grip — so what is left here is
## the one thing this file is actually the authority on: where in the hand it
## goes.
##
## The counter-rotation stays and stays explained. `hunter_body_motion.gd`
## pitches `right_arm` forward so the hand reads in frame at all, and a model
## parented to that arm inherits the pitch a second time unless it is cancelled;
## read from the constant rather than copied, so retuning the pose does not
## quietly lay the blade down across the view again.
func _build_weapon_model(weapon_id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "%s_mount" % weapon_id
	root.position = Vector3(-0.122, -0.226, -0.859)
	root.rotation = Vector3(-HUNTER_BODY_MOTION.FIRST_PERSON_ARM_RAISE - 0.12, 0.0, 0.12)
	var gear := HeldGear.build_weapon(weapon_id)
	# `HeldGear` builds muzzle-forward down -Z, which is where the camera looks.
	# The arm mount is authored the other way round, from when the model was
	# three boxes stacked down -Y, and the rest of the hunt's framing is tuned
	# against that. Turned here rather than there, so the two conventions meet
	# in one line instead of being argued about at every call site.
	gear.rotation.y += PI
	root.add_child(gear)
	return root
