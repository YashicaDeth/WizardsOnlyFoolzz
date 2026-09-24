class_name BloodLedger
extends Node

## Blood: the experience each weapon and fighting style earns by being used
## (Greg, 24 September 2026; rates and trees in `BloodTrees`).
##
## It writes nothing into the fight. Every credit is derived from a fact the
## game already records in `WorldHistory` — a hit, a kill, an execution, your
## own blood dropping — so the combat code, the Service Arcade and Lower Works
## needed no new writes. Events are read live through `event_recorded`, and on
## creation the ledger catches up on everything recorded since it last looked,
## which is how the first fight (Hollis, the Lower Works sentinel) pays out
## before the Hunt, the scene that owns this, has ever been loaded.
##
## The record lives in the `blood_ledger` subject: blood per weapon, earned and
## spent per style, which tree nodes are open. Unlocks reach the weapon through
## `HunterArsenal.set_blood_modifiers()`, the same scale path fitted parts use.
##
## The host needs one declaration, `BloodLedger.new()`, one `attach(self)` and
## one key calling `toggle_tree()`.

signal blood_earned(weapon_id: String, style_id: String, amount: int, kind: String)
signal node_unlocked(node_id: String)

const SUBJECT := "blood_ledger"
const VERSION := 1
const GUARD_ID := "guard_hollis"
const SENTINEL_ID := "lower_works_sentinel"
const KIND_COUNTS := {
	"hit": "hits", "kill": "kills", "takedown": "takedowns",
	"finisher": "finishers", "bled": "bled",
}

var state: Dictionary = {}
## The scene that owns the fight, read (never written) for what is in hand now
## and whether anyone can see the player. Null in tests and headless use.
var host: Node = null
var readout: BloodReadout = null
var tree_view: BloodTreeView = null
var _dirty := false
var _catching_up := false
var _catch_totals: Dictionary = {}
var _applied_arsenal: Node = null
## Saves are batched: the record is written at most this often while playing.
const FLUSH_INTERVAL := 0.5
var _since_flush := 0.0


func _init() -> void:
	state = _fresh()


func _ready() -> void:
	name = "BloodLedger"
	load_state()
	if not WorldHistory.event_recorded.is_connected(_on_event_recorded):
		WorldHistory.event_recorded.connect(_on_event_recorded)
	catch_up()


## The Hunt's one call. Builds the popup and the tree view on its HUD, then
## joins the scene (which catches up on anything recorded elsewhere).
func attach(owner_scene: Node, hud: Node = null) -> void:
	host = owner_scene
	if hud == null:
		hud = owner_scene.get_node_or_null("HUD")
	if hud == null:
		hud = owner_scene
	readout = BloodReadout.new()
	readout.name = "BloodReadout"
	hud.add_child(readout)
	blood_earned.connect(_on_blood_earned)
	tree_view = BloodTreeView.new()
	tree_view.name = "BloodTreeView"
	tree_view.ledger = self
	hud.add_child(tree_view)
	owner_scene.add_child(self)
	apply_to_arsenal()


func toggle_tree() -> void:
	if tree_view != null:
		tree_view.toggle()


func _process(delta: float) -> void:
	if host != null and is_instance_valid(host):
		var arsenal: Variant = host.get("arsenal")
		if arsenal is Node and arsenal != _applied_arsenal:
			apply_to_arsenal()
	_since_flush += delta
	if _dirty and _since_flush >= FLUSH_INTERVAL:
		flush()


func _exit_tree() -> void:
	if _dirty:
		flush()


# ---------------------------------------------------------------- the record

func _fresh() -> Dictionary:
	return {
		"version": VERSION, "last_sequence": 0,
		"weapons": {}, "styles": {}, "unlocked": [],
		"last_hit_by": {}, "finished": {}, "last_weapon": "",
		"player_blood": -1.0, "bled_carry": 0.0,
	}


func load_state() -> void:
	var stored := WorldHistory.subject(SUBJECT)
	state = _fresh()
	for key in stored:
		if state.has(key):
			state[key] = stored[key]


func flush() -> void:
	_dirty = false
	_since_flush = 0.0
	WorldHistory.amend_subject(SUBJECT, state.duplicate(true))


func weapon_blood(weapon_id: String) -> int:
	return int((state.weapons.get(weapon_id, {}) as Dictionary).get("blood", 0))


func weapon_record(weapon_id: String) -> Dictionary:
	return (state.weapons.get(weapon_id, {}) as Dictionary).duplicate(true)


func style_earned(style_id: String) -> int:
	return int((state.styles.get(style_id, {}) as Dictionary).get("earned", 0))


## Blood a style still has to spend on its tree.
func available(style_id: String) -> int:
	var style := state.styles.get(style_id, {}) as Dictionary
	return int(style.get("earned", 0)) - int(style.get("spent", 0))


func is_unlocked(node_id: String) -> bool:
	return node_id in (state.unlocked as Array)


func has_flag(flag_name: String) -> bool:
	for node_id in state.unlocked:
		if str((BloodTrees.NODES.get(str(node_id), {}) as Dictionary).get("flag", "")) == flag_name:
			return true
	return false


func requirements_met(node_id: String) -> bool:
	var node := BloodTrees.NODES.get(node_id, {}) as Dictionary
	for parent in node.get("requires", []):
		if not is_unlocked(str(parent)):
			return false
	return not node.is_empty()


func can_unlock(node_id: String) -> bool:
	if is_unlocked(node_id) or not requirements_met(node_id):
		return false
	var node := BloodTrees.NODES[node_id] as Dictionary
	return available(str(node.style)) >= int(node.cost)


## Greg: small nodes open by themselves once a weapon style has earned
## enough; they cost nothing. Checked every time that style earns blood.
func _open_automatic(style_id: String) -> void:
	var earned := int((state.styles.get(style_id, {}) as Dictionary).get("earned", 0))
	for node_id in BloodTrees.NODES:
		var node := BloodTrees.NODES[node_id] as Dictionary
		if str(node.style) != style_id or not bool(node.get("auto", false)):
			continue
		if is_unlocked(str(node_id)) or not requirements_met(str(node_id)) or earned < int(node.cost):
			continue
		var opened: Array = (state.unlocked as Array).duplicate()
		opened.append(str(node_id))
		state.unlocked = opened
		_dirty = true
		PlayerActionLedger.record("blood_node_unlocked", {"node": str(node_id), "style": style_id, "cost": 0, "auto": true})
		apply_to_arsenal()
		node_unlocked.emit(str(node_id))


## Blood is fuel: opening a node spends it from that style's own pool.
## Automatic nodes are never bought; they open themselves.
func unlock(node_id: String) -> bool:
	if bool((BloodTrees.NODES.get(node_id, {}) as Dictionary).get("auto", false)):
		return false
	if not can_unlock(node_id):
		return false
	var node := BloodTrees.NODES[node_id] as Dictionary
	var style := (state.styles.get(str(node.style), {"earned": 0, "spent": 0}) as Dictionary).duplicate()
	style["spent"] = int(style.get("spent", 0)) + int(node.cost)
	state.styles[str(node.style)] = style
	var opened: Array = (state.unlocked as Array).duplicate()
	opened.append(node_id)
	state.unlocked = opened
	flush()
	PlayerActionLedger.record("blood_node_unlocked", {
		"node": node_id, "style": str(node.style), "cost": int(node.cost),
	})
	apply_to_arsenal()
	node_unlocked.emit(node_id)
	return true


## Push every unlocked scale onto the arsenal's weapons. Defaults to the host's.
func apply_to_arsenal(arsenal: Node = null) -> void:
	if arsenal == null and host != null and is_instance_valid(host):
		var from_host: Variant = host.get("arsenal")
		arsenal = from_host as Node if from_host is Node else null
	if arsenal == null or not arsenal.has_method("set_blood_modifiers"):
		return
	for weapon_id in HunterArsenal.WEAPONS:
		arsenal.call("set_blood_modifiers", str(weapon_id), BloodTrees.weapon_scales(state.unlocked, str(weapon_id)))
	_applied_arsenal = arsenal


# ----------------------------------------------------------------- crediting

func credit(weapon_id: String, amount: int, kind: String, stealth := false) -> int:
	if amount <= 0 or weapon_id.is_empty():
		return 0
	var style_id := BloodTrees.weapon_style(weapon_id)
	var record := (state.weapons.get(weapon_id, {}) as Dictionary).duplicate()
	record["blood"] = int(record.get("blood", 0)) + amount
	var count_key := str(KIND_COUNTS.get(kind, kind))
	record[count_key] = int(record.get(count_key, 0)) + 1
	state.weapons[weapon_id] = record
	var style := (state.styles.get(style_id, {"earned": 0, "spent": 0}) as Dictionary).duplicate()
	style["earned"] = int(style.get("earned", 0)) + amount
	state.styles[style_id] = style
	if kind != "bled" and style_id != "stealth":
		state.last_weapon = weapon_id
	_dirty = true
	if _catching_up:
		_catch_totals[weapon_id] = int(_catch_totals.get(weapon_id, 0)) + amount
	else:
		blood_earned.emit(weapon_id, style_id, amount, kind)
	# Opened after the event being read is finished: recording the unlock is
	# itself an event, and a nested one would move `last_sequence` past facts
	# the ledger has not read yet (it lost the first fight's breach-tool blood).
	if not _auto_pending.has(style_id):
		_auto_pending.append(style_id)
	if not _reading and not _catching_up:
		_flush_automatic()
	# Stealth earns its own blood beside the weapon's, not instead of it.
	if stealth and style_id != "stealth":
		credit("unseen", amount, kind)
	return amount


## Read every event recorded since the ledger last looked.
func catch_up() -> void:
	_catching_up = true
	_catch_totals.clear()
	for event in WorldHistory.events:
		consume(event, false)
	_catching_up = false
	_flush_automatic()
	for weapon_id in _catch_totals:
		blood_earned.emit(str(weapon_id), BloodTrees.weapon_style(str(weapon_id)), int(_catch_totals[weapon_id]), "record")
	_catch_totals.clear()
	if _dirty:
		flush()


func _on_event_recorded(event: Dictionary) -> void:
	if _reading:
		return
	_reading = true
	consume(event, true)
	_reading = false
	_flush_automatic()


var _auto_pending: Array[String] = []
var _reading := false


func _flush_automatic() -> void:
	while not _auto_pending.is_empty():
		_open_automatic(_auto_pending.pop_front())


## One recorded fact in, any blood it earned out. `live` means it happened this
## frame, so the host's hand and the watchers' eyes describe it.
func consume(event: Dictionary, live: bool) -> void:
	var sequence := int(event.get("sequence", 0))
	if sequence <= int(state.last_sequence):
		# The history was wiped and restarted underneath us: start again too.
		if WorldHistory.subject(SUBJECT).is_empty() and int(state.last_sequence) > 0:
			state = _fresh()
		else:
			return
	state.last_sequence = sequence
	var details := event.get("details", {}) as Dictionary
	var unseen := live and _host_unseen()
	match str(event.get("type", "")):
		"npc_anatomy_hit":
			var result := details.get("result", {}) as Dictionary
			_hit(str(details.get("weapon", "")), str(details.get("subject_id", "")), float(result.get("damage", 0.0)), unseen)
		"firearm_anatomy_hit":
			_hit(str(details.get("weapon", "")), str(details.get("subject_id", "")), float(details.get("damage", 0.0)), unseen)
		"melee_body_hit":
			# The swing comes through the player action ledger (it carries an
			# action id); the torque-arm surge writes the same event directly.
			var weapon := _held_weapon(live, "sword") if details.has("action_id") else "surge"
			_hit(weapon, str(details.get("target", "")), float(details.get("damage", 0.0)), unseen)
		"facility_guard_rammed":
			_hit("breach_tool", GUARD_ID, FacilityGuardPost.RAM_DAMAGE, false)
			if bool(details.get("downed", false)) and not state.finished.has(GUARD_ID):
				state.finished[GUARD_ID] = true
				credit("breach_tool", int(BloodTrees.RATES.takedown), "takedown")
		"lower_works_sentinel_breached":
			credit("breach_tool", int(BloodTrees.RATES.kill), "kill")
		"grapple_takedown":
			var subject_id := str(details.get("subject_id", ""))
			state.last_hit_by[subject_id] = "grapple"
			credit("grapple", int(BloodTrees.RATES.takedown), "takedown", unseen)
		"npc_resolution":
			if str(details.get("outcome", "")) == "execute" and str(details.get("actor", "player")) == "player":
				var subject_id := str(details.get("subject_id", ""))
				var weapon := str(state.last_hit_by.get(subject_id, _held_weapon(live, "hands")))
				state.finished[subject_id] = true
				credit(weapon, int(BloodTrees.RATES.finisher), "finisher", unseen or bool(details.get("unseen", false)))
		"npc_killed":
			var changes := details.get("changes", {}) as Dictionary
			var subject_id := str(details.get("subject_id", ""))
			if str(changes.get("killed_by", "")) == "player" and not state.finished.has(subject_id):
				var weapon := str(state.last_hit_by.get(subject_id, _held_weapon(live, "hands")))
				credit(weapon, int(BloodTrees.RATES.kill), "kill", unseen)
			state.finished.erase(subject_id)
			state.last_hit_by.erase(subject_id)
			_dirty = true
		"anatomy_changed":
			if str(details.get("subject_id", "")) == "player":
				var body := (details.get("changes", {}) as Dictionary).get("anatomy_state", {}) as Dictionary
				if body.has("blood"):
					var now := float(body.blood)
					var before := float(state.player_blood)
					if before >= 0.0 and now < before:
						_bleed((before - now) / float(BloodTrees.RATES.bled_ml_per_blood), live)
					state.player_blood = now
					_dirty = true
		"facility_guard_fired", "lower_works_sentinel_strike", "drain_bingyanger_strike":
			var damage := float(details.get("damage", 0.0))
			if damage > 0.0:
				_bleed(damage / float(BloodTrees.RATES.bled_damage_per_blood), live)
		"service_arcade_breach_tool_taken":
			state.last_weapon = "breach_tool"
			_dirty = true
		"facility_first_firearm":
			state.last_weapon = "facility_sidearm"
			_dirty = true


func _hit(weapon_id: String, subject_id: String, damage: float, unseen: bool) -> void:
	if weapon_id.is_empty():
		return
	if not subject_id.is_empty():
		state.last_hit_by[subject_id] = weapon_id
	credit(weapon_id, BloodTrees.hit_blood(damage), "hit", unseen)


## Your own blood lost pays whatever you were fighting with. Fractions carry.
func _bleed(points: float, live: bool) -> void:
	var carry := float(state.bled_carry) + maxf(points, 0.0)
	var whole := floori(carry)
	state.bled_carry = carry - float(whole)
	_dirty = true
	if whole > 0:
		var fallback := str(state.last_weapon) if not str(state.last_weapon).is_empty() else "hands"
		credit(_held_weapon(live, fallback), whole, "bled")


func _held_weapon(live: bool, fallback: String) -> String:
	if not live or host == null or not is_instance_valid(host):
		return fallback if not fallback.is_empty() else str(state.last_weapon)
	if host.get("bare_handed") == true:
		return "hands"
	var limb: Variant = host.get("carried_limb_index")
	if limb is int and int(limb) >= 0:
		return "severed_limb"
	var arsenal: Variant = host.get("arsenal")
	if arsenal is Node:
		return str((arsenal as Node).get("current_id"))
	return fallback


func _host_unseen() -> bool:
	if host == null or not is_instance_valid(host):
		return false
	return host.get("player_unseen") == true


func _on_blood_earned(weapon_id: String, style_id: String, amount: int, _kind: String) -> void:
	if readout == null or not is_instance_valid(readout):
		return
	var tone: Color = (BloodTrees.STYLES.get(style_id, {"tone": Color.WHITE}) as Dictionary).tone
	readout.push(weapon_id, BloodTrees.weapon_label(weapon_id), amount, tone)
