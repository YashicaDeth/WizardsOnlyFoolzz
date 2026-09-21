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
signal customization_changed(weapon_id: String, customization: Dictionary)

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
		# A first accurate hit should open a fight, not silently finish it. At
		# 38 damage this round also delivered 26.6 damage to the nearest organ:
		# enough to rupture the 18-point brain on contact. Twenty-four leaves it
		# barely intact, so the first shot makes a severe, readable wound and a
		# deliberate follow-up finishes the same target through the same anatomy.
		"label": "MERCY NINE", "kind": "firearm", "damage": 24.0,
		"impulse": 18.0, "range": 76.0, "cooldown": 0.28,
		"pellets": 1, "spread": 0.008, "magazine": 10, "reserve": 50,
		"reload": 1.3, "damage_type": "ballistic",
	},
	"sniper": {
		# The shot you take once. Everything about it is the opposite of the
		# shotgun: it reaches across the whole bone yard, it is accurate enough
		# that the zone you aimed at is the zone you hit, and it makes you pay for
		# a miss with a bolt cycle you cannot hurry.
		#
		# 78 is calibrated against the anatomy rather than picked for feel. The
		# sidearm's 24 already delivers 26.6 to the nearest organ and the brain
		# has 18 points, so a head hit ruptures it. At 78 there is no argument: a
		# clean head or heart hit is over. That is what makes the kill camera
		# honest when it fires, rather than a flourish played over a wound the
		# victim would have walked away from.
		"label": "ASHLINE LONGVIEW", "kind": "firearm", "damage": 78.0,
		"impulse": 46.0, "range": 240.0, "cooldown": 1.65,
		"pellets": 1, "spread": 0.0015, "magazine": 4, "reserve": 16,
		"reload": 3.2, "damage_type": "ballistic",
	},
	"facility_sidearm": {
		# The first firearm is a guard's service hand-cannon, not the ordinary
		# surface pistol. One good hit can end a fight; its three rounds cannot
		# replace the broken tools and melee weapons the escape already taught.
		"label": "CELL OUTZ BREACH NINE", "kind": "firearm", "damage": 52.0,
		"impulse": 30.0, "range": 68.0, "cooldown": 0.44,
		"pellets": 1, "spread": 0.011, "magazine": 3, "reserve": 0,
		"reload": 1.5, "damage_type": "ballistic",
	},
}
## The hunter's own three. The sniper is not here for the same reason
## `facility_sidearm` is not: it is a weapon you come into possession of, and
## a rifle that reaches across the whole bone yard is not something the game
## should hand you at spawn.
const SLOT_ORDER := ["sword", "shotgun", "sidearm"]
## AF10.10. These are attachment points on the object, not perks on its
## holder. The future crafting screen may decide where a part comes from, but
## it must install through this vocabulary so the Hunt, range and cab all read
## the same weapon-owned record.
const CUSTOMIZATION_SLOTS := {
	"shotgun": ["sight", "muzzle", "stock"],
	"sidearm": ["sight", "muzzle", "grip"],
}
const CUSTOMIZATION_SCALES := {
	"damage_scale": Vector2(0.25, 2.0),
	"impulse_scale": Vector2(0.25, 2.0),
	"range_scale": Vector2(0.25, 2.0),
	"spread_scale": Vector2(0.25, 2.0),
	"cooldown_scale": Vector2(0.5, 2.0),
	"reload_scale": Vector2(0.5, 2.0),
}

var current_id := "sword"
var cooldown := 0.0
var reload_remaining := 0.0
var shot_serial := 0
var ammo := {
	"shotgun": {"loaded": 5, "reserve": 25},
	"sidearm": {"loaded": 10, "reserve": 50},
	"facility_sidearm": {"loaded": 0, "reserve": 0, "spare_magazines": []},
}
## AN2.4. Missing means unworn — a weapon starts at full condition and this
## dict only ever gains an entry the first time something actually wears it,
## the same lazy shape `ammo` above would use if a fresh magazine were free.
var condition: Dictionary = {}
## AF10.10. One dictionary per weapon, then one installed part per physical
## slot. Nothing is stored on a player, vehicle or range actor: any holder asks
## `current()`/`weapon_definition()` and receives the numbers belonging to the
## weapon it actually has. Part records remain data (id, label, provenance and
## modifiers) so a later crafting/persistence layer can move them intact.
var customization: Dictionary = {}
var models: Dictionary = {}
var hand: Node3D

## AF10.12. A firearm that has fired enough rounds can fail to cycle cleanly —
## missing means clean, the same lazy shape `condition` above uses. A jam
## does not cost the shot that caused it (the round already left the barrel);
## it costs the next trigger pull, until the action is cleared.
var jammed: Dictionary = {}
var jam_clear_remaining := 0.0
const JAM_CLEAR_TIME := 1.4
## Chance a shot fails to cycle, purely a function of how worn the weapon
## already is: zero for a pristine weapon, rising as condition falls, so a
## gun that has never been fired never jams and one run down to nothing jams
## more often than it does not.
const JAM_CHANCE_AT_ZERO := 0.35
## Firing wears a weapon the same way a connecting melee hit does (AN2.4) —
## `wear_weapon` does not care which one asked.
const FIREARM_WEAR_PER_SHOT := 0.006
var _rng := RandomNumberGenerator.new()

## AF1.4. The magazine node inside each built model, found by name once at
## build time, plus the local position it sits at when nothing is happening —
## read off the node rather than hardcoded, so retuning the mesh in
## `held_gear.gd` cannot quietly desync the rest pose the reload animates back
## to. A weapon with no such child (the sword) is simply absent from both and
## `_update_reload_visual` skips it.
var _magazine_nodes: Dictionary = {}
var _magazine_rest: Dictionary = {}
const MAGAZINE_DROP := Vector3(0, -0.145, 0.012)


func configure(rig: BaselineHuman) -> void:
	_rng.randomize()
	hand = rig.parts.get("right_arm") as Node3D
	if hand == null:
		return
	for weapon_id in SLOT_ORDER:
		var model := _build_weapon_model(weapon_id)
		hand.add_child(model)
		models[weapon_id] = model
		var magazine := model.find_child("magazine", true, false) as Node3D
		if magazine != null:
			_magazine_nodes[weapon_id] = magazine
			_magazine_rest[weapon_id] = magazine.position
	_update_models()


func tick(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if jam_clear_remaining > 0.0:
		jam_clear_remaining = maxf(0.0, jam_clear_remaining - delta)
		if jam_clear_remaining <= 0.0:
			jammed[current_id] = false
		return
	if reload_remaining <= 0.0:
		_update_reload_visual()
		return
	reload_remaining = maxf(0.0, reload_remaining - delta)
	if reload_remaining <= 0.0:
		_finish_reload()
	_update_reload_visual()


## AF1.4. Three phases inside the one reload timer already driving `state()`'s
## `reload_ratio`, so nothing here can drift out of sync with how long a
## reload actually takes: the old magazine drops clear of the well (first
## third), the well sits visibly empty (middle third — the part the wording
## actually names, and the part that never showed before this), and the
## fresh magazine rises back into place (final third). Outside a reload the
## magazine simply sits at rest, which is also where a freshly-equipped
## weapon's model starts.
func _update_reload_visual() -> void:
	var magazine := _magazine_nodes.get(current_id) as Node3D
	if magazine == null:
		return
	var rest: Vector3 = _magazine_rest.get(current_id, magazine.position)
	var definition: Dictionary = current()
	var duration := float(definition.get("reload", 0.0))
	if reload_remaining <= 0.0 or duration <= 0.0:
		magazine.visible = true
		magazine.position = rest
		return
	var progress := 1.0 - (reload_remaining / duration)
	if progress < 0.34:
		magazine.visible = true
		magazine.position = rest.lerp(rest + MAGAZINE_DROP, progress / 0.34)
	elif progress < 0.66:
		magazine.visible = false
	else:
		magazine.visible = true
		magazine.position = (rest + MAGAZINE_DROP).lerp(rest, (progress - 0.66) / 0.34)


func select_slot(slot: int) -> bool:
	if slot < 0 or slot >= SLOT_ORDER.size() or reload_remaining > 0.0 or jam_clear_remaining > 0.0:
		return false
	current_id = SLOT_ORDER[slot]
	_update_models()
	equipped.emit(current_id)
	return true


func current() -> Dictionary:
	return weapon_definition(current_id)


## The authored definition plus the parts fitted to this particular weapon.
## Multipliers compose rather than overwrite, so two parts never fight over a
## copied damage/spread field and removing either one recovers the base value.
func weapon_definition(weapon_id: String) -> Dictionary:
	if not WEAPONS.has(weapon_id):
		return {}
	var result: Dictionary = (WEAPONS[weapon_id] as Dictionary).duplicate(true)
	for part_value in weapon_customization(weapon_id).values():
		var part := part_value as Dictionary
		var modifiers := part.get("modifiers", {}) as Dictionary
		for scale_name in CUSTOMIZATION_SCALES:
			if not modifiers.has(scale_name):
				continue
			var property_name := str(scale_name).trim_suffix("_scale")
			if result.has(property_name):
				result[property_name] = float(result[property_name]) * float(modifiers[scale_name])
	return result


func weapon_customization(weapon_id: String = "") -> Dictionary:
	var key := weapon_id if weapon_id != "" else current_id
	return (customization.get(key, {}) as Dictionary).duplicate(true)


## Install a crafted/found part on the weapon itself. Unknown weapon slots are
## refused instead of becoming silent holder perks. Modifier names are a small
## mechanical vocabulary and are clamped here once, at the ownership boundary.
func install_customization(weapon_id: String, slot: String, part: Dictionary) -> bool:
	if not WEAPONS.has(weapon_id) or not CUSTOMIZATION_SLOTS.has(weapon_id):
		return false
	if slot not in (CUSTOMIZATION_SLOTS[weapon_id] as Array) or str(part.get("id", "")).is_empty():
		return false
	var fitted := part.duplicate(true)
	var requested := fitted.get("modifiers", {}) as Dictionary
	var modifiers: Dictionary = {}
	for scale_name in requested:
		if not CUSTOMIZATION_SCALES.has(scale_name):
			continue
		var bounds: Vector2 = CUSTOMIZATION_SCALES[scale_name]
		modifiers[scale_name] = clampf(float(requested[scale_name]), bounds.x, bounds.y)
	fitted["modifiers"] = modifiers
	var installed := weapon_customization(weapon_id)
	installed[slot] = fitted
	customization[weapon_id] = installed
	_sync_customization_meta(weapon_id)
	customization_changed.emit(weapon_id, installed.duplicate(true))
	return true


## AX3.4. Called by the guard's physical loadout, not by player creation. The
## rounds passed here are the rounds left in that exact gun; no reserve magazine
## is conjured when ownership changes.
## Picked up rather than issued, the same way the breach nine is. Takes the
## rifle and whatever rounds came with it; a found weapon with an empty
## magazine is still worth carrying, so zero rounds is allowed here where the
## breach nine refuses it -- that one arrives mid-escape with what it has, and
## this one can be scavenged for later.
func acquire_sniper(rounds_left: int = -1) -> bool:
	var magazine := int(WEAPONS.sniper.magazine)
	var loaded := magazine if rounds_left < 0 else mini(rounds_left, magazine)
	ammo["sniper"] = {
		"loaded": loaded,
		"reserve": int(WEAPONS.sniper.reserve) if rounds_left < 0 else maxi(0, rounds_left - loaded),
		"spare_magazines": [],
	}
	current_id = "sniper"
	if hand != null and not models.has(current_id):
		var model := _build_weapon_model(current_id)
		hand.add_child(model)
		models[current_id] = model
		var magazine_node := model.find_child("magazine", true, false) as Node3D
		if magazine_node != null:
			_magazine_nodes[current_id] = magazine_node
			_magazine_rest[current_id] = magazine_node.position
	_update_models()
	equipped.emit(current_id)
	return true


func acquire_facility_sidearm(rounds_left: int) -> bool:
	if rounds_left <= 0:
		return false
	ammo["facility_sidearm"] = {
		"loaded": mini(rounds_left, int(WEAPONS.facility_sidearm.magazine)),
		"reserve": 0,
		"spare_magazines": [],
	}
	current_id = "facility_sidearm"
	if hand != null and not models.has(current_id):
		var model := _build_weapon_model(current_id)
		hand.add_child(model)
		models[current_id] = model
		var magazine := model.find_child("magazine", true, false) as Node3D
		if magazine != null:
			_magazine_nodes[current_id] = magazine
			_magazine_rest[current_id] = magazine.position
	_update_models()
	equipped.emit(current_id)
	return true


func remove_customization(weapon_id: String, slot: String) -> Dictionary:
	var installed := weapon_customization(weapon_id)
	if not installed.has(slot):
		return {}
	var removed := (installed[slot] as Dictionary).duplicate(true)
	installed.erase(slot)
	if installed.is_empty():
		customization.erase(weapon_id)
	else:
		customization[weapon_id] = installed
	_sync_customization_meta(weapon_id)
	customization_changed.emit(weapon_id, installed.duplicate(true))
	return removed


## Models are consumers too. Keeping the complete record on the weapon mount
## gives authored attachment geometry a stable seam without teaching the hand,
## player or vehicle what an optic is.
func _sync_customization_meta(weapon_id: String) -> void:
	var model := models.get(weapon_id) as Node3D
	if model != null and is_instance_valid(model):
		model.set_meta("weapon_customization", weapon_customization(weapon_id))


## AN2.4. 1.0 is unworn and new; 0.0 has nothing left to give.
func weapon_condition(id: String = "") -> float:
	return float(condition.get(id if id != "" else current_id, 1.0))


## What connecting with something actually costs the edge, calibre or firing
## pin — never healed here, the same one-way rule `implant_condition` and a
## carried limb's own wear already run on. Returns the value left so a caller
## can react to it (`_carry_current_weapon`) without a second lookup.
func wear_weapon(amount: float, id: String = "") -> float:
	var key := id if id != "" else current_id
	var value := clampf(weapon_condition(key) - maxf(0.0, amount), 0.0, 1.0)
	condition[key] = value
	return value


func state() -> Dictionary:
	var definition: Dictionary = current()
	if definition.kind == "firearm":
		_ensure_spare_magazines(current_id)
	var rounds := ammo.get(current_id, {}) as Dictionary
	return {
		"id": current_id,
		"label": definition.label,
		"kind": definition.kind,
		"loaded": int(rounds.get("loaded", -1)),
		"reserve": int(rounds.get("reserve", -1)),
		# AF1.5. The bag as it actually is — a caller that wants to show
		# discrete magazines (a half-full one looking different from a full
		# one) has real data to draw from rather than one flattened number.
		"spare_magazines": (rounds.get("spare_magazines", []) as Array).duplicate(),
		"reloading": reload_remaining > 0.0,
		"reload_ratio": reload_remaining / float(definition.get("reload", 1.0)) if reload_remaining > 0.0 else 0.0,
		# AF10.12. Jammed is its own state, distinct from reloading: nothing
		# about the magazine moves while an action is being cleared.
		"jammed": bool(jammed.get(current_id, false)),
		"clearing_jam": jam_clear_remaining > 0.0,
		"jam_clear_ratio": jam_clear_remaining / JAM_CLEAR_TIME if jam_clear_remaining > 0.0 else 0.0,
		"customization": weapon_customization(current_id),
	}


func begin_attack(heavy := false) -> Dictionary:
	var definition: Dictionary = current()
	if cooldown > 0.0 or reload_remaining > 0.0 or jam_clear_remaining > 0.0:
		return {"accepted": false, "reason": "busy"}
	if definition.kind == "firearm":
		if bool(jammed.get(current_id, false)):
			return {"accepted": false, "reason": "jammed"}
		var rounds: Dictionary = ammo[current_id]
		if int(rounds.loaded) <= 0:
			return {"accepted": false, "reason": "empty"}
		rounds.loaded = int(rounds.loaded) - 1
		ammo[current_id] = rounds
		# AF10.12. The shot that causes the jam still fires — the round has
		# already left the barrel by the time the action fails to cycle for
		# the next one. Wear first, so the roll below reads the condition
		# this very shot left the weapon in.
		wear_weapon(FIREARM_WEAR_PER_SHOT, current_id)
		if _rng.randf() < _jam_chance(current_id):
			jammed[current_id] = true
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
		# AF10.12. True only on the shot that just caused the jam — a caller
		# wanting a distinct "that one jammed" cue reads it here rather than
		# polling `state()` after the fact.
		"caused_jam": bool(jammed.get(current_id, false)),
	}


## AF1.4/AF1.5. Reserve ammunition is real, discrete magazines, not one
## abstract pool a mag tops itself up from. Seeded once, lazily, from the
## authored `reserve` — full magazines until the last one, which carries
## whatever is left over — so nothing about the starting loadout had to be
## re-authored to gain this.
func _ensure_spare_magazines(weapon_id: String) -> void:
	var rounds: Dictionary = ammo[weapon_id]
	if rounds.has("spare_magazines"):
		return
	var capacity := int(WEAPONS[weapon_id].magazine)
	var remaining := int(rounds.get("reserve", 0))
	var magazines: Array[int] = []
	while remaining > 0 and capacity > 0:
		var take := mini(capacity, remaining)
		magazines.append(take)
		remaining -= take
	rounds["spare_magazines"] = magazines
	ammo[weapon_id] = rounds


## The one place `reserve` is written — kept as a live total alongside
## `spare_magazines` rather than only ever computed in `state()`, so any
## existing caller reading `ammo[weapon_id].reserve` directly (this file's
## own tests included) never has to learn the new shape underneath it.
func _sync_reserve(weapon_id: String) -> void:
	var rounds: Dictionary = ammo[weapon_id]
	var total := 0
	for magazine in (rounds.spare_magazines as Array):
		total += int(magazine)
	rounds.reserve = total
	ammo[weapon_id] = rounds


## AF10.12. How likely a shot is to jam the action, purely a function of how
## worn the weapon already is: zero for anything at full condition, rising to
## `JAM_CHANCE_AT_ZERO` as condition runs out.
func _jam_chance(id: String) -> float:
	return (1.0 - weapon_condition(id)) * JAM_CHANCE_AT_ZERO


## AF10.12. Clearing a jam is a real action of its own, not a reload — no
## magazine moves and nothing about ammunition changes, which is why this
## does not go through `_finish_reload()`. Bound to the same input as a
## reload (`_reload_weapon()`) because both are "work the action" to a
## player, and a jammed gun cannot usefully be reloaded until it is clear.
func reload() -> bool:
	var definition: Dictionary = current()
	if definition.kind != "firearm" or reload_remaining > 0.0 or jam_clear_remaining > 0.0 or cooldown > 0.0:
		return false
	if bool(jammed.get(current_id, false)):
		jam_clear_remaining = JAM_CLEAR_TIME
		return true
	_ensure_spare_magazines(current_id)
	var rounds: Dictionary = ammo[current_id]
	if int(rounds.loaded) >= int(definition.magazine) or (rounds.spare_magazines as Array).is_empty():
		return false
	reload_remaining = float(definition.reload)
	reload_started.emit(current_id)
	return true


func shot_directions(forward: Vector3, up: Vector3, spread_scale := 1.0) -> Array[Vector3]:
	var definition: Dictionary = current()
	var count := int(definition.get("pellets", 1))
	var spread := float(definition.get("spread", 0.0)) * clampf(spread_scale, 0.0, 1.0)
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


## AF1.4. The magazine actually leaves — whatever was still chambered in it
## goes back into the bag as its own magazine rather than dissolving into one
## abstract reserve number (AF1.5: a magazine dropped half-full is still
## half-full later) — and a new one arrives: the fullest spare on hand, not
## whichever happened to sit first in the bag. A full swap, not a top-up —
## the old model let a nearly-full magazine "reload" for one round; a
## physical magazine cannot.
func _finish_reload() -> void:
	var definition: Dictionary = current()
	if definition.kind != "firearm":
		return
	var rounds: Dictionary = ammo[current_id]
	var spares: Array = rounds.spare_magazines
	if spares.is_empty():
		return
	var leaving := int(rounds.loaded)
	if leaving > 0:
		spares.append(leaving)
	var best_index := 0
	for index in spares.size():
		if int(spares[index]) > int(spares[best_index]):
			best_index = index
	var incoming: int = spares[best_index]
	spares.remove_at(best_index)
	rounds.loaded = incoming
	rounds.spare_magazines = spares
	ammo[current_id] = rounds
	_sync_reserve(current_id)
	reload_finished.emit(current_id)


func _update_models() -> void:
	for weapon_id in models:
		(models[weapon_id] as Node3D).visible = weapon_id == current_id


## Apply one of HeldGear's authored grips to the already-mounted production
## model. Changing grip moves hands on the same object and never replaces it.
func apply_grip(grip_name: String) -> bool:
	if not HeldGear.GRIPS.has(grip_name):
		return false
	var mount := models.get(current_id) as Node3D
	if mount == null or not is_instance_valid(mount):
		return false
	var weapon := mount.get_node_or_null("%s_model" % current_id) as Node3D
	if weapon == null:
		return false
	var spec: Dictionary = HeldGear.GRIPS[grip_name]
	HeldGear.pose_mounted_hand(mount.get_node_or_null("RightGripHand") as Node3D, weapon, spec.right, 1)
	HeldGear.pose_mounted_hand(mount.get_node_or_null("LeftGripHand") as Node3D, weapon, spec.left, -1)
	return true


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
	root.position = Vector3(0.098, -0.232, -0.706)
	# Cancel the arm pose. Exactly cancel it — no trim term on the end.
	#
	# Two passes tried to fix a floating, badly angled sword by retuning this
	# line, and both made it worse, because the value here was never reaching
	# the model: `bone_yard_hunt._pose_weapon` assigned `model.rotation` every
	# frame from arm sway alone and discarded whatever was set at build time.
	# With that fixed, the honest value is the pure cancellation — the arm is
	# pitched forward by `FIRST_PERSON_ARM_RAISE` and undoing precisely that
	# leaves the weapon level in view space, which is what the trim terms were
	# groping toward while the real rotation was being thrown away.
	root.rotation = Vector3(-HUNTER_BODY_MOTION.FIRST_PERSON_ARM_RAISE, -0.34, 0.32)
	var visual_id := "sidearm" if weapon_id == "facility_sidearm" else weapon_id
	var gear := HeldGear.build_weapon(visual_id)
	# Hung off its grip rather than its origin. `HeldGear` builds each weapon
	# around the shape of the object, so a sword's origin is where the guard
	# meets the blade and not where a hand closes; mounted at the origin that
	# puts most of a metre of blade on the wrong side of the fist.
	var grip := gear.get_node_or_null("anchor_grip") as Node3D
	if grip != null:
		gear.position = -(gear.transform.basis * grip.position)
	root.add_child(gear)
	# Visible fingers are part of the weapon presentation, not an optional body
	# overlay. The grip anchors already author exactly where those fingers close.
	var right := HeldGear.build_humiliation_hand(1)
	right.name = "RightGripHand"
	HeldGear.set_pose(right, "trigger" if visual_id in ["shotgun", "sidearm"] else "wrap")
	# Each class seats the palm around a slightly different section. The old one
	# offset made the trigger hand acceptable on the sword, but buried the pistol
	# tang in the palm and left the shotgun wrist hovering below its stock.
	right.position = {
		"shotgun": Vector3(0.016, -0.010, 0.006),
		"sidearm": Vector3(0.014, -0.016, 0.008),
	}.get(visual_id, Vector3(0.019, -0.013, 0.0))
	right.rotation = Vector3(-PI * 0.5, 0.0, PI * 0.5)
	right.set_meta("grip_rest_position", right.position)
	right.set_meta("grip_rest_rotation", right.rotation)
	right.set_meta("forearm_entry", Vector3(0.47, -0.53, -0.30))
	root.add_child(right)
	var off_anchor_name := "forend" if visual_id == "shotgun" else ("grip_support" if visual_id == "sidearm" else "grip_low")
	var off_anchor := gear.get_node_or_null("anchor_%s" % off_anchor_name) as Node3D
	if off_anchor != null:
		var left := HeldGear.build_humiliation_hand(-1)
		left.name = "LeftGripHand"
		HeldGear.set_pose(left, "cup" if visual_id == "sidearm" else "wrap")
		var placed := gear.transform * off_anchor.transform
		var palm_clearance := Vector3(-0.017, -0.010, 0.005) if visual_id == "shotgun" else Vector3(-0.016, -0.014, 0.006)
		left.position = placed.origin + palm_clearance
		left.rotation = placed.basis.get_euler() + Vector3(-PI * 0.5, 0.0, -PI * 0.5)
		left.set_meta("grip_rest_position", left.position)
		left.set_meta("grip_rest_rotation", left.rotation)
		left.set_meta("forearm_entry", Vector3(-0.47, -0.53, -0.31))
		root.add_child(left)
	return root
