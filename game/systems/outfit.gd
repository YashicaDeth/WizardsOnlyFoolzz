class_name Outfit
extends RefCounted

## Clothing as parts you put on (Greg, 24 September: "make the jester outfit
## clothing parts you can put on").
##
## `ClothingShell` gives each of the six body zones a cloth layer with an
## integrity; this file says which *part* covers which zones, so a garment is
## an item you can take off, carry, skin, sell or put back on. The jester set
## is four parts. The facility forces it on you with the collar locked (the
## Hunt dresses you in it on arrival); once you break the lock, every part is
## an ordinary item (Greg: "forced on, then yours").
##
## A part also carries what the revolved shell cannot: the cap's belled
## points, the ruff, the puffed cuffs and the curled shoes, built here as
## extra geometry on the body part they belong to.

const SKINS := preload("res://systems/weapon_skins.gd")
const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")

const SUBJECT := "outfit"

const PARTS := {
	"jester_cap": {"label": "BELLED CAP", "zones": ["head"], "style": "jester", "extra": "bell_cap", "mass": 0.3, "shell": false},
	"jester_doublet": {"label": "RUFF AND MOTLEY DOUBLET", "zones": ["torso"], "style": "jester", "extra": "ruff", "mass": 1.2, "collar": true},
	"jester_sleeves": {"label": "GLOVES AND SLEEVES", "zones": ["left_arm", "right_arm"], "style": "jester", "extra": "cuffs", "mass": 0.5},
	"jester_hose": {"label": "PANTALOONS AND CURLED SHOES", "zones": ["left_leg", "right_leg"], "style": "jester", "extra": "curled_shoes", "mass": 0.9},
}
const JESTER_SET := ["jester_cap", "jester_doublet", "jester_sleeves", "jester_hose"]

const WINE := Color("4a1428")
const BONE := Color("cfc2a4")
const BELL := Color("b8862e")


# --- the record -----------------------------------------------------------------

## What you are wearing: {parts: {part_id: integrity}, locked: bool}. A world
## with no record yet is the facility's: the full set, collar locked.
static func worn() -> Dictionary:
	var record := WorldHistory.subject(SUBJECT)
	if not bool(record.get("initialized", false)):
		return forced_jester()
	return {"parts": (record.get("parts", {}) as Dictionary).duplicate(true), "locked": bool(record.get("locked", false))}


static func forced_jester() -> Dictionary:
	var parts := {}
	for part_id in JESTER_SET:
		parts[part_id] = 1.0
	# The punishment started before you saw the form: the cap arrives torn.
	parts["jester_cap"] = 0.35
	return {"parts": parts, "locked": true}


static func _save(state: Dictionary, event := "outfit_changed") -> void:
	WorldHistory.update_subject(SUBJECT, {"initialized": true, "parts": state.parts, "locked": state.locked}, event)


## The zone-by-zone wardrobe `BaselineHuman.dress()` reads, with a style and a
## skin per zone from the parts worn.
static func wardrobe_for(state: Dictionary) -> Dictionary:
	var wardrobe := {"styles": {}, "skins": {}, "no_shell": [], "parts": (state.parts as Dictionary).duplicate(), "locked": bool(state.locked)}
	for part_id: String in state.parts:
		var part: Dictionary = PARTS.get(part_id, {})
		if part.is_empty():
			continue
		var skin := SkinLoadout.applied(part_id)
		for zone: String in part.zones:
			wardrobe[zone] = float(state.parts[part_id])
			wardrobe.styles[zone] = str(part.style)
			if not skin.is_empty():
				wardrobe.skins[zone] = skin
			# A cap protects the head but is not a sack over the face: its
			# cloth is the crown and points built in `_bell_cap`.
			if not bool(part.get("shell", true)):
				wardrobe.no_shell.append(zone)
	return wardrobe


## Dress `rig` in what the record says, extras and all.
static func dress(rig: BaselineHuman, state: Dictionary = {}) -> void:
	if rig == null:
		return
	if state.is_empty():
		state = worn()
	rig.dress(wardrobe_for(state))
	build_extras(rig)


# --- verbs ----------------------------------------------------------------------

static func part_item(part_id: String, integrity := 1.0) -> Dictionary:
	var part: Dictionary = PARTS.get(part_id, {})
	return {
		"label": str(part.get("label", "GARMENT")),
		"kind": "garment",
		"garment": part_id,
		"condition": clampf(integrity, 0.0, 1.0),
		"mass": float(part.get("mass", 0.5)),
		"perishes": false,
		"age": 0.0,
	}


## Take a part off and put it in the bag. The locked collar holds the whole
## set on until it is broken.
static func take_off(rig: BaselineHuman, carry: Carry, part_id: String) -> Dictionary:
	var state := worn()
	if not (state.parts as Dictionary).has(part_id):
		return {"ok": false, "reason": "NOT WEARING IT"}
	if bool(state.locked):
		return {"ok": false, "reason": "THE COLLAR IS LOCKED"}
	var integrity := float(state.parts[part_id])
	state.parts.erase(part_id)
	WorldHistory.begin_ledger_batch()
	_save(state)
	if carry != null:
		carry.items.append(part_item(part_id, integrity))
		carry.save_to_history()
	PLAYER_ACTION_LEDGER.record("garment_removed", {"garment": part_id})
	WorldHistory.commit_ledger_batch()
	dress(rig, state)
	return {"ok": true, "garment": part_id}


## Put on the garment at `index` in the bag. Whatever covered the same zones
## comes off into the bag first.
static func put_on(rig: BaselineHuman, carry: Carry, index: int) -> Dictionary:
	if carry == null or index < 0 or index >= carry.items.size():
		return {"ok": false, "reason": "NOTHING THERE"}
	var item: Dictionary = carry.items[index]
	var part_id := str(item.get("garment", ""))
	if str(item.get("kind", "")) != "garment" or not PARTS.has(part_id):
		return {"ok": false, "reason": "NOT CLOTHING"}
	var state := worn()
	WorldHistory.begin_ledger_batch()
	carry.items.remove_at(index)
	var zones: Array = PARTS[part_id].zones
	for other: String in (state.parts as Dictionary).keys():
		for zone in PARTS.get(other, {}).get("zones", []):
			if zone in zones:
				carry.items.append(part_item(other, float(state.parts[other])))
				state.parts.erase(other)
				break
	state.parts[part_id] = float(item.get("condition", 1.0))
	_save(state)
	carry.save_to_history()
	PLAYER_ACTION_LEDGER.record("garment_worn", {"garment": part_id})
	WorldHistory.commit_ledger_batch()
	dress(rig, state)
	return {"ok": true, "garment": part_id}


## Break the collar's lock. It takes something to break it with: a blade, the
## ram, a tool. After this every part comes off like any other clothing.
static func break_lock(rig: BaselineHuman, with_what: String) -> Dictionary:
	var state := worn()
	if not bool(state.locked):
		return {"ok": false, "reason": "ALREADY BROKEN"}
	if with_what.is_empty():
		return {"ok": false, "reason": "NOTHING TO BREAK IT WITH"}
	state.locked = false
	WorldHistory.begin_ledger_batch()
	_save(state, "collar_lock_broken")
	PLAYER_ACTION_LEDGER.record("collar_lock_broken", {"with": with_what})
	WorldHistory.commit_ledger_batch()
	dress(rig, state)
	return {"ok": true}


# --- the parts the shell cannot be ----------------------------------------------

static func build_extras(rig: BaselineHuman) -> void:
	for zone: String in rig.parts:
		var part := rig.parts[zone] as Node3D
		if part == null or not is_instance_valid(part):
			continue
		for child in part.get_children():
			if str(child.name).begins_with("GarmentExtra"):
				part.remove_child(child)
				child.queue_free()
	var parts: Dictionary = rig.wardrobe.get("parts", {})
	for part_id: String in parts:
		var spec: Dictionary = PARTS.get(part_id, {})
		if spec.is_empty():
			continue
		var skin := SkinLoadout.applied(part_id)
		var cloth: Material = SKINS.material_for(skin) if not skin.is_empty() else _cloth(WINE)
		var trim: Material = SKINS.material_for(skin) if not skin.is_empty() else _cloth(BONE)
		match str(spec.extra):
			"bell_cap":
				_bell_cap(rig, cloth, trim)
			"ruff":
				_ruff(rig, trim)
			"cuffs":
				for zone in ["left_arm", "right_arm"]:
					_cuff(rig, zone, trim, cloth)
			"curled_shoes":
				for zone in ["left_leg", "right_leg"]:
					_shoe(rig, zone, cloth)


static func _size(rig: BaselineHuman, zone: String) -> Vector3:
	return (rig._layout.get(zone, {}) as Dictionary).get("size", Vector3.ONE)


static func _mount(rig: BaselineHuman, zone: String, extra_name: String) -> Node3D:
	var part := rig.parts.get(zone) as Node3D
	if part == null:
		return null
	var root := Node3D.new()
	root.name = "GarmentExtra_%s" % extra_name
	part.add_child(root)
	return root


static func _cloth(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


static func _bell_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = BELL
	material.metallic = 0.9
	material.roughness = 0.28
	return material


static func _ball(parent: Node3D, at: Vector3, radius: float, material: Material, squash := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.scale = squash
	node.material_override = material
	parent.add_child(node)
	return node


## A tapered horn from `from` toward `to`, drooping on the way.
static func _horn(parent: Node3D, from: Vector3, to: Vector3, radius: float, material: Material) -> void:
	var steps := 6
	for step in steps:
		var t := float(step) / float(steps - 1)
		var at := from.lerp(to, t) + Vector3(0, sin(t * PI) * 0.05 - t * t * 0.06, 0)
		_ball(parent, at, radius * (1.0 - t * 0.7), material)


static func _bell_cap(rig: BaselineHuman, cloth: Material, trim: Material) -> void:
	var size := _size(rig, "head")
	var root := _mount(rig, "head", "bell_cap")
	if root == null:
		return
	var top := Vector3(0, size.y * 0.42, 0.01)
	# The crown, then three points: left, right and back, each with its bell.
	_ball(root, top, size.x * 0.52, cloth, Vector3(1.0, 0.45, 1.0))
	var bell := _bell_material()
	for tip in [Vector3(-0.24, 0.1, 0.02), Vector3(0.24, 0.1, 0.02), Vector3(0.0, 0.14, 0.2)]:
		_horn(root, top, top + tip, 0.06, cloth if tip.x <= 0.0 else trim)
		_ball(root, top + tip + Vector3(0, -0.075, 0), 0.022, bell)
	# The band round the brow.
	for index in 14:
		var a := TAU * float(index) / 14.0
		_ball(root, Vector3(cos(a) * size.x * 0.5, size.y * 0.22, sin(a) * size.z * 0.5), 0.022, trim)


static func _ruff(rig: BaselineHuman, trim: Material) -> void:
	var size := _size(rig, "torso")
	var root := _mount(rig, "torso", "ruff")
	if root == null:
		return
	# A locked ruff at the throat: two rings of pleats round the neck.
	var y := size.y * 0.5 - 0.035
	for ring in 2:
		var count := 16 + ring * 4
		var radius := 0.085 + ring * 0.035
		for index in count:
			var a := TAU * (float(index) + ring * 0.5) / float(count)
			var node := _ball(root, Vector3(cos(a) * radius, y - ring * 0.012, sin(a) * radius), 0.03, trim, Vector3(1.0, 0.45, 1.0))
			node.rotation.y = -a
	# The lock itself, at the front of the collar. Gone once it is broken.
	var lock := _ball(root, Vector3(0, y - 0.02, -0.125), 0.02, _bell_material(), Vector3(1.2, 1.0, 0.6))
	lock.name = "CollarLock"
	lock.visible = bool(rig.wardrobe.get("locked", false))


static func _cuff(rig: BaselineHuman, zone: String, trim: Material, cloth: Material) -> void:
	var size := _size(rig, zone)
	var root := _mount(rig, zone, "cuff")
	if root == null:
		return
	var y := -size.y * 0.5 + 0.06
	for index in 10:
		var a := TAU * float(index) / 10.0
		_ball(root, Vector3(cos(a) * size.x * 0.42, y, sin(a) * size.z * 0.42), 0.03, trim if index % 2 == 0 else cloth)
	# A puff at the shoulder too.
	_ball(root, Vector3(0, size.y * 0.42, 0), size.x * 0.6, cloth, Vector3(1.0, 0.7, 1.0))


static func _shoe(rig: BaselineHuman, zone: String, cloth: Material) -> void:
	var size := _size(rig, zone)
	var root := _mount(rig, zone, "shoe")
	if root == null:
		return
	var sole := Vector3(0, -size.y * 0.5 + 0.035, -0.02)
	_ball(root, sole, 0.06, cloth, Vector3(1.0, 0.6, 1.5))
	# The toe runs forward and curls up into a bell.
	var tip := sole
	for step in 5:
		var t := float(step + 1) / 5.0
		tip = sole + Vector3(0, t * t * 0.09, -0.07 - t * 0.1)
		_ball(root, tip, 0.04 * (1.0 - t * 0.6), cloth)
	_ball(root, tip + Vector3(0, 0.03, 0), 0.018, _bell_material())
