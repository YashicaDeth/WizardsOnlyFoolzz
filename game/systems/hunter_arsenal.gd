class_name HunterArsenal
extends Node

## One combat vocabulary for held weapons. The arsenal decides timing, spread,
## ammunition and the model in the hunter's real hand; BaselineHuman remains
## the authority for what a hit does to flesh, bone, organs and prosthetics.

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


func _build_weapon_model(weapon_id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "%s_model" % weapon_id
	root.position = Vector3(-0.093, -0.716, -0.673)
	# M4.4. This rotation used to be a small artistic tilt on top of an
	# unrotated hand. The hand itself now carries a real first-person pose —
	# hunter_body_motion.gd's arm_raise pitches right_arm ~65 degrees forward
	# so it reads in frame at all — and every piece here is still authored
	# against the old, unrotated arm. Left alone that pitch is inherited twice
	# and the blade lies down across the view instead of standing in it, so
	# this cancels the pose rotation before adding the same small tilt back.
	root.rotation = Vector3(-1.14 - 0.12, 0.0, 0.08 + 0.04)
	match weapon_id:
		"sword":
			_piece(root, "grip", Vector3(0, -0.02, 0), Vector3(0.055, 0.23, 0.055), Color("35261e"), "cloth")
			_piece(root, "guard", Vector3(0, -0.15, 0), Vector3(0.26, 0.035, 0.055), Color("8b6040"), "metal")
			_piece(root, "blade", Vector3(0, -0.67, 0), Vector3(0.072, 1.02, 0.028), Color("999c93"), "metal", Vector3(0, 0, 0.035))
		"shotgun":
			_piece(root, "stock", Vector3(0, -0.04, 0.10), Vector3(0.12, 0.36, 0.13), Color("493429"), "wood", Vector3(-0.72, 0, 0))
			_piece(root, "receiver", Vector3(0, -0.24, -0.10), Vector3(0.13, 0.34, 0.14), Color("4b4f4b"), "metal", Vector3(-0.72, 0, 0))
			_piece(root, "barrel", Vector3(0, -0.55, -0.42), Vector3(0.075, 0.74, 0.075), Color("777c73"), "metal", Vector3(-0.72, 0, 0))
		"sidearm":
			_piece(root, "grip", Vector3(0, -0.06, 0), Vector3(0.10, 0.24, 0.09), Color("332b29"), "cloth", Vector3(0.28, 0, 0))
			_piece(root, "slide", Vector3(0, -0.22, -0.10), Vector3(0.11, 0.35, 0.09), Color("767a72"), "metal", Vector3(-0.72, 0, 0))
	return root


func _piece(parent: Node3D, piece_name: String, at: Vector3, dimensions: Vector3, tint: Color, kind: String, turn := Vector3.ZERO) -> void:
	var visual := MeshInstance3D.new()
	visual.name = piece_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var material: StandardMaterial3D = WorldLook.surface(tint, kind, piece_name.hash())
	# M4.4. The Ashbloom exterior crushes anything at hip height toward black —
	# it is the same reason the ground itself reads near-black in every capture,
	# not a broken material. A held weapon still has to read in that light, the
	# way the anatomy rig's own rim treatment lets a body read against it, so it
	# carries a faint self-lit edge rather than depending on the world's own key
	# light to find it.
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 0.4
	mesh.material = material
	visual.mesh = mesh
	visual.position = at
	visual.rotation = turn
	parent.add_child(visual)
