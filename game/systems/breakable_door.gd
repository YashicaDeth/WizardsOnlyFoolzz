class_name BreakableDoor
extends Node3D

## Destruction, first real case: the door the doctor left through, which Greg
## wants broken down "with a weapon which shows the destruction physics".
##
## It keeps to `DESIGN/DESTRUCTION.md` rather than faking a fracture solver:
##
## - **Condition in stages, not voxels.** The leaf is eight panels, a lock and
##   two hinges, each with its own condition. What breaks is a part, and the
##   stages you see (dented, holed, unlocked, hanging, down) are those parts
##   failing.
## - **Debris is real.** A panel that fails comes off as rigid pieces, a
##   shot-out lock or hinge drops as an object, and a leaf that loses both
##   hinges falls as one heavy body you can kick. All of it is registered with
##   `WorldDebris`, identified and budgeted, and none of it despawns on a timer.
## - **The record is the object.** The door's parts live in one `WorldHistory`
##   subject, so a door broken before a death or a reload is still broken.
##
## Every weapon works (Greg: the restraint, Hollis's gun, a heavy tool, your
## body) but they do not work the same: a gun takes out the lock or a hinge in
## a couple of rounds and does little to a panel, an axe tears panels out, the
## restraint gets there slowly, and a shoulder is weak but can burst a door
## that is already failing. Every blow is a noise, and the loud ones carry.

signal damaged(weapon: String, part: String, result: Dictionary)
signal broke_open(method: String)
signal noise(at: Vector3, loudness: float)

const WORLD_DEBRIS := preload("res://systems/world_debris.gd")
const BREAKABLE_PROP := preload("res://systems/breakable_prop.gd")
const FRAGMENT_POOL := "door_fragment"
const LEAF_POOL := "door_leaf"

const COLS := 2
const ROWS := 4
const PANEL_HP := 20.0
const LOCK_HP := 24.0
const HINGE_HP := 20.0
## A blow that lands this close to the lock or a hinge goes into it.
const PART_RADIUS := 0.24
## Enough panels gone and the leaf cannot hold together.
const PANELS_TO_COLLAPSE := 5
## A shoulder bursts a leaf whose remaining condition is below this.
const BURST_CONDITION := 0.45

const WEAPONS := {
	"restraint": {"panel": 7.0, "part": 5.0, "spread": 0.2, "loudness": 0.75, "impulse": 2.0},
	"axe": {"panel": 21.0, "part": 12.0, "spread": 0.35, "loudness": 0.85, "impulse": 3.5},
	"body": {"panel": 5.0, "part": 3.0, "spread": 0.9, "loudness": 0.7, "impulse": 5.0},
	"gun": {"panel": 8.0, "part": 13.0, "spread": 0.0, "loudness": 1.0, "impulse": 6.0},
}

@export var door_id := "door"
var width := 1.2
var height := 2.3
var thickness := 0.07
var colour := Color("b8b4a6")

var panels: Array[Dictionary] = []
var lock_hp := LOCK_HP
var hinge_hp: Array[float] = [HINGE_HP, HINGE_HP]
var state := "intact"
var broken := false
var fragments: Array[RigidBody3D] = []
var leaf_body_fallen: RigidBody3D

var _pivot: Node3D
var _leaf: StaticBody3D
var _leaf_collision: CollisionShape3D
var _lock_mesh: MeshInstance3D
var _hinge_meshes: Array[MeshInstance3D] = []
var _swing_tween: Tween


## `at_rest_open` builds it already broken, from the record, without replaying
## the fight: an empty frame and the leaf lying where doors lie.
func build(id: String, size := Vector2(1.2, 2.3), tint := Color("b8b4a6")) -> void:
	door_id = id
	width = size.x
	height = size.y
	colour = tint
	var record := WorldHistory.subject(door_id)
	if record.is_empty():
		WorldHistory.register_subject(door_id, {
			"kind": "door", "state": "intact", "condition": 1.0,
			"lock": 1.0, "hinges": [1.0, 1.0], "panels": [], "broken_by": "",
		})
		record = WorldHistory.subject(door_id)
	_build_frame()
	if str(record.get("state", "intact")) == "broken":
		broken = true
		state = "broken"
		_build_wreck_at_rest()
		return
	_build_leaf(record.get("panels", []) as Array)
	lock_hp = LOCK_HP * float(record.get("lock", 1.0))
	var hinges: Array = record.get("hinges", [1.0, 1.0])
	hinge_hp = [HINGE_HP * float(hinges[0]), HINGE_HP * float(hinges[1])]
	state = str(record.get("state", "intact"))


## The one entry point. `global_point` is where the blow landed, `direction`
## which way it was travelling. Returns what happened, for the prompt and the
## test.
func hit(weapon: String, global_point: Vector3, direction: Vector3) -> Dictionary:
	if broken:
		return {"accepted": false, "reason": "broken"}
	var spec: Dictionary = WEAPONS.get(weapon, WEAPONS.body)
	noise.emit(global_point, float(spec.loudness))
	var local := _leaf.to_local(global_point)
	var push := direction.normalized() if direction.length_squared() > 0.001 else -global_transform.basis.z
	var result := {"accepted": true, "weapon": weapon, "part": "panel", "broke": ""}

	# The lock and hinges are small targets; a blow that lands on one goes in.
	var part := _part_at(local)
	if part != "":
		result.part = part
		_damage_part(part, float(spec.part), push, result)
	else:
		var index := _panel_at(local)
		if index >= 0:
			_damage_panel(index, float(spec.panel), push, float(spec.impulse), result)
			if float(spec.spread) > 0.0:
				for neighbour in _neighbours(index):
					_damage_panel(neighbour, float(spec.panel) * float(spec.spread), push, float(spec.impulse) * 0.5, result)
	_dent(push, weapon)

	# What the door can no longer do.
	if hinge_hp[0] <= 0.0 and hinge_hp[1] <= 0.0:
		_fall(push, weapon)
		result.broke = "hinges"
	elif _panels_gone() >= PANELS_TO_COLLAPSE:
		_collapse(push, weapon)
		result.broke = "panels"
	elif lock_hp <= 0.0 and weapon in ["body", "axe", "restraint"] and state == "unlocked":
		_swing_open(push, weapon)
		result.broke = "lock"
	elif weapon == "body" and condition() < BURST_CONDITION:
		_fall(push, weapon)
		result.broke = "burst"
	elif lock_hp <= 0.0 and state != "unlocked":
		state = "unlocked"
		_crack_open()
	elif hinge_hp[0] <= 0.0 or hinge_hp[1] <= 0.0:
		state = "hanging"
		_hang(hinge_hp[0] <= 0.0)
	elif _panels_gone() > 0:
		state = "holed"
	elif state == "intact":
		state = "damaged"
	result["state"] = state
	result["condition"] = condition()
	_save()
	damaged.emit(weapon, str(result.part), result)
	return result


## 1.0 whole, 0.0 nothing left holding the opening shut.
func condition() -> float:
	var total := 0.0
	for panel in panels:
		total += maxf(0.0, float(panel.hp)) / PANEL_HP
	var panel_share := total / float(maxi(1, panels.size()))
	var fixings := (maxf(0.0, lock_hp) / LOCK_HP + maxf(0.0, hinge_hp[0]) / HINGE_HP + maxf(0.0, hinge_hp[1]) / HINGE_HP) / 3.0
	return clampf(panel_share * 0.65 + fixings * 0.35, 0.0, 1.0)


func passable() -> bool:
	return broken


## Someone with the right hand opening it the ordinary way: 0 shut, 1 wide.
## Only while it is whole; a broken door has nothing to swing.
func set_ajar(amount: float) -> void:
	if broken or _pivot == null or state == "unlocked" or state == "hanging":
		return
	_pivot.rotation.y = deg_to_rad(-85.0) * clampf(amount, 0.0, 1.0)


## Where on the door a crosshair is, as the body it would hit, for the owner's
## raycast. Everything that can take a blow carries this meta.
static func door_of(collider: Object) -> BreakableDoor:
	if collider is Node and (collider as Node).has_meta("breakable_door"):
		return (collider as Node).get_meta("breakable_door") as BreakableDoor
	return null


# --- Building.

func _build_frame() -> void:
	var trim := Color("2b2a27")
	_box(self, Vector3(-width * 0.5 - 0.06, height * 0.5, 0), Vector3(0.12, height, 0.2), trim, "paint")
	_box(self, Vector3(width * 0.5 + 0.06, height * 0.5, 0), Vector3(0.12, height, 0.2), trim, "paint")
	_box(self, Vector3(0, height + 0.06, 0), Vector3(width + 0.24, 0.12, 0.2), trim, "paint")


func _build_leaf(saved_panels: Array) -> void:
	_pivot = Node3D.new()
	_pivot.name = "HingeSide"
	_pivot.position = Vector3(-width * 0.5, 0, 0)
	add_child(_pivot)
	_leaf = StaticBody3D.new()
	_leaf.name = "Leaf"
	_leaf.position = Vector3(width * 0.5, height * 0.5, 0)
	_leaf.set_meta("breakable_door", self)
	_pivot.add_child(_leaf)
	_leaf_collision = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, thickness)
	_leaf_collision.shape = shape
	_leaf.add_child(_leaf_collision)
	var cell := Vector2(width / COLS, height / ROWS)
	panels.clear()
	for row in ROWS:
		for col in COLS:
			var index := row * COLS + col
			var hp := PANEL_HP
			if index < saved_panels.size():
				hp = float(saved_panels[index]) * PANEL_HP
			var at := Vector3(-width * 0.5 + cell.x * (col + 0.5), -height * 0.5 + cell.y * (row + 0.5), 0)
			var mesh := _box(_leaf, at, Vector3(cell.x - 0.02, cell.y - 0.02, thickness), colour.darkened(0.04 * float((row + col) % 2)), "paint")
			mesh.name = "Panel_%d" % index
			panels.append({"node": mesh, "hp": hp, "rest": at, "col": col, "row": row})
			if hp <= 0.0:
				mesh.visible = false
	_lock_mesh = _box(_leaf, _lock_at(), Vector3(0.1, 0.2, thickness + 0.06), Color("3a3d3f"), "paint")
	_lock_mesh.name = "Lock"
	var light := OmniLight3D.new()
	light.name = "LockLight"
	light.light_color = Color("c8281a")
	light.light_energy = 0.7
	light.omni_range = 0.9
	light.position = Vector3(0, 0.05, thickness)
	_lock_mesh.add_child(light)
	_hinge_meshes.clear()
	for index in 2:
		var hinge := _box(_leaf, _hinge_at(index), Vector3(0.05, 0.16, thickness + 0.04), Color("5a5650"), "paint")
		hinge.name = "Hinge_%d" % index
		_hinge_meshes.append(hinge)


func _build_wreck_at_rest() -> void:
	# The leaf has already been through this; it lies flat inside the room.
	var slab := StaticBody3D.new()
	slab.name = "FallenLeaf"
	slab.position = Vector3(0.1, thickness * 0.5, -1.2)
	slab.rotation = Vector3(PI * 0.5, 0.35, 0)
	add_child(slab)
	_box(slab, Vector3.ZERO, Vector3(width, height, thickness), colour.darkened(0.2), "paint")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, thickness)
	collision.shape = shape
	slab.add_child(collision)


func _lock_at() -> Vector3:
	return Vector3(width * 0.5 - 0.13, -0.05, 0)


func _hinge_at(index: int) -> Vector3:
	return Vector3(-width * 0.5 + 0.03, (-0.3 if index == 0 else 0.3) * height, 0)


# --- Taking damage.

func _part_at(local: Vector3) -> String:
	var flat := Vector2(local.x, local.y)
	if lock_hp > 0.0 and flat.distance_to(Vector2(_lock_at().x, _lock_at().y)) <= PART_RADIUS:
		return "lock"
	for index in 2:
		var at := _hinge_at(index)
		if hinge_hp[index] > 0.0 and flat.distance_to(Vector2(at.x, at.y)) <= PART_RADIUS:
			return "hinge_%d" % index
	return ""


func _panel_at(local: Vector3) -> int:
	var cell := Vector2(width / COLS, height / ROWS)
	var col := clampi(int(floor((local.x + width * 0.5) / cell.x)), 0, COLS - 1)
	var row := clampi(int(floor((local.y + height * 0.5) / cell.y)), 0, ROWS - 1)
	var index := row * COLS + col
	if float(panels[index].hp) > 0.0:
		return index
	# The blow went through a hole. The nearest panel still there takes it.
	var best := -1
	var best_distance := INF
	for other in panels.size():
		if float(panels[other].hp) <= 0.0:
			continue
		var distance := Vector2(local.x, local.y).distance_to(Vector2(panels[other].rest.x, panels[other].rest.y))
		if distance < best_distance:
			best_distance = distance
			best = other
	return best


func _neighbours(index: int) -> Array[int]:
	var out: Array[int] = []
	var row := index / COLS
	var col := index % COLS
	for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var c: int = col + offset.x
		var r: int = row + offset.y
		if c >= 0 and c < COLS and r >= 0 and r < ROWS:
			out.append(r * COLS + c)
	return out


func _damage_panel(index: int, amount: float, push: Vector3, impulse: float, result: Dictionary) -> void:
	var panel: Dictionary = panels[index]
	if float(panel.hp) <= 0.0:
		return
	panel.hp = float(panel.hp) - amount
	var mesh := panel.node as MeshInstance3D
	var wear := clampf(1.0 - float(panel.hp) / PANEL_HP, 0.0, 1.0)
	# Dented toward where the blow was going, and darker where it split.
	mesh.position = (panel.rest as Vector3) + _leaf.global_transform.basis.inverse() * push * wear * 0.05
	mesh.rotation = Vector3(wear * 0.08 * (1.0 if index % 2 else -1.0), 0, wear * 0.06)
	var material := (mesh.mesh as BoxMesh).material as StandardMaterial3D
	if material != null:
		material.albedo_color = colour.lerp(Color("2a2420"), wear * 0.7)
	if float(panel.hp) <= 0.0:
		mesh.visible = false
		for shard in 2:
			_spawn_fragment(mesh.global_transform, Vector3(width / COLS * 0.5, height / ROWS * 0.5, thickness), push, impulse, "panel")
		result["panels_broken"] = int(result.get("panels_broken", 0)) + 1


func _damage_part(part: String, amount: float, push: Vector3, result: Dictionary) -> void:
	if part == "lock":
		lock_hp -= amount
		if lock_hp <= 0.0 and _lock_mesh.visible:
			_lock_mesh.visible = false
			_spawn_fragment(_lock_mesh.global_transform, Vector3(0.1, 0.2, 0.08), push, 3.0, "lock")
			result["part_broken"] = "lock"
		return
	var index := int(part.trim_prefix("hinge_"))
	hinge_hp[index] -= amount
	if hinge_hp[index] <= 0.0 and _hinge_meshes[index].visible:
		_hinge_meshes[index].visible = false
		_spawn_fragment(_hinge_meshes[index].global_transform, Vector3(0.05, 0.16, 0.08), push, 3.0, "hinge")
		result["part_broken"] = part


func _dent(push: Vector3, weapon: String) -> void:
	if _leaf == null or broken:
		return
	var shove := 0.012 if weapon == "body" else 0.005
	_leaf.position += _pivot.global_transform.basis.inverse() * push * shove
	_leaf.position.z = clampf(_leaf.position.z, -0.06, 0.06)


func _panels_gone() -> int:
	var gone := 0
	for panel in panels:
		if float(panel.hp) <= 0.0:
			gone += 1
	return gone


# --- Break states.

## The lock is gone. The leaf jumps in its frame and stands a hand's width
## open; the next blow puts it into the wall.
func _crack_open() -> void:
	_pivot.rotation.y = deg_to_rad(-7.0)


func _swing_open(push: Vector3, weapon: String) -> void:
	broken = true
	state = "broken"
	_leaf_collision.set_deferred("disabled", true)
	var way := -1.0 if push.dot(global_transform.basis.z) < 0.0 else 1.0
	_swing_tween = create_tween()
	_swing_tween.tween_property(_pivot, "rotation:y", way * deg_to_rad(104.0), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_swing_tween.tween_property(_pivot, "rotation:y", way * deg_to_rad(92.0), 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_finish("swung_open_" + weapon)


## One hinge gone: the leaf drops at that corner and hangs.
func _hang(top_gone: bool) -> void:
	_pivot.rotation.z = deg_to_rad(-5.0 if top_gone else 4.0)
	_pivot.rotation.y = deg_to_rad(-3.0)


## Both hinges gone, or a shoulder into a failing door: the leaf comes out of
## the frame as one heavy body.
func _fall(push: Vector3, weapon: String) -> void:
	broken = true
	state = "broken"
	var body := RigidBody3D.new()
	body.name = "%s_Leaf" % door_id
	body.mass = 38.0
	# Debris lands on the world but not on other debris: pieces spawn inside
	# each other at the moment of breaking, and letting them collide there is
	# how a door leaf gets launched across the room by its own hinges.
	body.collision_layer = 1 << 3
	body.collision_mask = 1
	get_parent().add_child(body)
	body.global_transform = _leaf.global_transform
	for child in _leaf.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).visible:
			child.reparent(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, thickness)
	collision.shape = shape
	body.add_child(collision)
	_leaf.queue_free()
	_leaf = null
	# Velocities, not impulses: an impulse on the frame a body enters the
	# world is applied before its mass is, which threw a 38 kg door like a
	# 1 kg one (measured at 70 m/s).
	body.linear_velocity = push.normalized() * 1.9 + Vector3.UP * 0.3
	body.angular_velocity = global_transform.basis.x * signf(push.dot(-global_transform.basis.z)) * -1.4 + Vector3(0, randf_range(-0.3, 0.3), 0)
	leaf_body_fallen = body
	WORLD_DEBRIS.register(body, {"kind": "door_leaf", "part": "leaf", "door_id": door_id}, LEAF_POOL, 8)
	_finish("knocked_down_" + weapon)


## Too many panels gone: what is left of the leaf comes apart in the frame.
func _collapse(push: Vector3, weapon: String) -> void:
	broken = true
	state = "broken"
	for panel in panels:
		if float(panel.hp) > 0.0:
			var mesh := panel.node as MeshInstance3D
			mesh.visible = false
			_spawn_fragment(mesh.global_transform, Vector3(width / COLS * 0.9, height / ROWS * 0.9, thickness), push, 3.0, "panel")
	if _lock_mesh.visible:
		_lock_mesh.visible = false
		_spawn_fragment(_lock_mesh.global_transform, Vector3(0.1, 0.2, 0.08), push, 2.0, "lock")
	_leaf_collision.set_deferred("disabled", true)
	_finish("broken_through_" + weapon)


func _finish(method: String) -> void:
	WorldHistory.update_subject(door_id, {"state": "broken", "broken_by": method, "condition": condition()}, "door_broken")
	broke_open.emit(method)


func _spawn_fragment(from: Transform3D, size: Vector3, push: Vector3, impulse: float, part: String) -> void:
	var budget := BREAKABLE_PROP.fragment_budget()
	var body := RigidBody3D.new()
	body.name = "%s_%s_%02d" % [door_id, part, fragments.size()]
	body.mass = 0.8 + size.x * size.y * 6.0
	body.collision_layer = 1 << 3
	body.collision_mask = 1
	var shard := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size.max(Vector3(0.04, 0.04, 0.03))
	mesh.material = WorldLook.surface(colour.darkened(0.25) if part == "panel" else Color("3a3d3f"), "paint", fragments.size() + 71)
	shard.mesh = mesh
	body.add_child(shard)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	body.add_child(collision)
	get_parent().add_child(body)
	body.global_transform = from
	body.global_position += Vector3(randf_range(-0.06, 0.06), randf_range(-0.06, 0.06), 0) + push.normalized() * 0.06
	var spray := (push.normalized() + Vector3(randf_range(-0.4, 0.4), randf_range(0.1, 0.6), randf_range(-0.4, 0.4))).normalized()
	body.linear_velocity = spray * impulse / body.mass
	body.angular_velocity = Vector3(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
	fragments.append(body)
	WORLD_DEBRIS.register(body, {"kind": "door_" + part, "part": part, "door_id": door_id}, FRAGMENT_POOL, budget)


func _save() -> void:
	var saved: Array = []
	for panel in panels:
		saved.append(maxf(0.0, float(panel.hp)) / PANEL_HP)
	WorldHistory.update_subject(door_id, {
		"state": state if not broken else "broken",
		"condition": condition(),
		"lock": maxf(0.0, lock_hp) / LOCK_HP,
		"hinges": [maxf(0.0, hinge_hp[0]) / HINGE_HP, maxf(0.0, hinge_hp[1]) / HINGE_HP],
		"panels": saved,
	}, "door_damaged")


func _box(parent: Node, at: Vector3, size: Vector3, tint: Color, kind: String) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = WorldLook.surface(tint, kind, int(at.x * 37.0 + at.y * 11.0) + 70)
	mesh_instance.mesh = box
	mesh_instance.position = at
	parent.add_child(mesh_instance)
	return mesh_instance
