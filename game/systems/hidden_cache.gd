class_name HiddenCache
extends RefCounted

## Greg, 26 September (question boxes): hidden things in the first 30 minutes
## are stashes and secret doors, five to eight of them, found in K or J and
## opened with E. Stashes hold meds and ammo. Plain eyes get a faint hint: a
## hairline seam around the panel, easy to miss, fair once you know.
##
## A scene places them, keeps the returned records in an Array, and on E calls
## `open_near(records, player_position)`. Placing one registers it with the
## scene's SignalSight, whose `hidden_seen` marks it found.

const REACH := 1.9
const SIGHT_AUDIO := preload("res://systems/sight_audio.gd")
## Only a shade darker than the wall: a hairline you catch, not a drawn box.
const SEAM := Color("4a403a")
const GUN_LABEL := "CELL OUTZ BREACH NINE"
const MEDS := {"label": "FIELD DRESSING", "kind": "meds", "mass": 0.2, "perishes": false, "age": 0.0, "heals": 20}
const ROUNDS := 4


## A panel flush on a wall: `at` is the centre of the wall face, `normal`
## points out of the wall into the room.
static func place_stash(host: Node3D, sight: Node, id: String, at: Vector3, normal: Vector3) -> Dictionary:
	var size := Vector2(0.62, 0.5)
	var across := Vector3.UP.cross(normal).normalized()
	var root := Node3D.new()
	root.name = "Stash_%s" % id
	host.add_child(root)
	root.global_position = at + normal * 0.025
	root.look_at(root.global_position - normal, Vector3.UP)  # +Z faces the room
	# The hatch: the wall's own surface, hinged on its left edge.
	var hinge := Node3D.new()
	hinge.position = Vector3(-size.x * 0.5, 0, 0)
	root.add_child(hinge)
	var hatch := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size.x, size.y, 0.05)
	box.material = LabSurface.material("wall")
	hatch.mesh = box
	hatch.position = Vector3(size.x * 0.5, 0, 0)
	hinge.add_child(hatch)
	_seam(root, size, 0.03)
	# Behind it: a dark recess with the goods in it.
	var recess := MeshInstance3D.new()
	var back := BoxMesh.new()
	back.size = Vector3(size.x - 0.04, size.y - 0.04, 0.01)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("050404")
	back.material = dark
	recess.mesh = back
	recess.position = Vector3(0, 0, -0.03)
	root.add_child(recess)
	var goods := Node3D.new()
	goods.visible = false
	root.add_child(goods)
	_goods(goods)
	var record := {"id": id, "kind": "stash", "at": at, "found": false, "opened": false, "hinge": hinge, "goods": goods}
	_register(sight, id, at + normal * 0.03, size, across)
	return record


## A door-sized panel that stands in a real opening: solid until opened.
## `at` is the centre of the doorway at floor level, `normal` points out of
## the wall toward the player.
static func place_door(host: Node3D, sight: Node, id: String, at: Vector3, normal: Vector3, size := Vector2(1.2, 2.1)) -> Dictionary:
	var across := Vector3.UP.cross(normal).normalized()
	var body := StaticBody3D.new()
	body.name = "SecretDoor_%s" % id
	host.add_child(body)
	body.global_position = at + Vector3.UP * size.y * 0.5
	body.look_at(body.global_position - normal, Vector3.UP)  # +Z faces the room
	var panel := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size.x, size.y, 0.3)
	box.material = LabSurface.material("wall")
	panel.mesh = box
	body.add_child(panel)
	var shape := CollisionShape3D.new()
	var solid := BoxShape3D.new()
	solid.size = Vector3(size.x, size.y, 0.3)
	shape.shape = solid
	body.add_child(shape)
	_seam(body, size, 0.16)
	var record := {"id": id, "kind": "door", "at": at, "found": false, "opened": false, "body": body, "size": size}
	_register(sight, id, at + Vector3.UP * size.y * 0.5 + normal * 0.16, size, across)
	return record


## The faint hint: four hairlines round the panel, darker than the wall.
static func _seam(parent: Node3D, size: Vector2, depth: float) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = SEAM
	material.roughness = 1.0
	var line := 0.005
	for spec in [[Vector3(size.x, line, 0.01), Vector3(0, size.y * 0.5, depth)], [Vector3(size.x, line, 0.01), Vector3(0, -size.y * 0.5, depth)],
			[Vector3(line, size.y, 0.01), Vector3(size.x * 0.5, 0, depth)], [Vector3(line, size.y, 0.01), Vector3(-size.x * 0.5, 0, depth)]]:
		var hairline := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = spec[0]
		box.material = material
		hairline.mesh = box
		hairline.position = spec[1]
		hairline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(hairline)


## A white dressing tin and a small ammo box, seen once the hatch swings.
static func _goods(parent: Node3D) -> void:
	for spec in [[Vector3(0.18, 0.12, 0.08), Vector3(-0.12, -0.12, -0.02), Color("d8d2c4")], [Vector3(0.16, 0.1, 0.1), Vector3(0.14, -0.13, -0.02), Color("3a4a2a")]]:
		var item := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = spec[0]
		var material := StandardMaterial3D.new()
		material.albedo_color = spec[2]
		box.material = material
		item.mesh = box
		item.position = spec[1]
		parent.add_child(item)


static func _register(sight: Node, id: String, centre: Vector3, size: Vector2, across: Vector3) -> void:
	if sight == null:
		return
	var hidden: Array = sight.get("hidden")
	hidden.append({"id": id, "at": centre, "size": size, "across": across})
	sight.set("hidden", hidden)


## SignalSight saw it: from now on E opens it.
static func mark_found(records: Array, id: String) -> bool:
	for record: Dictionary in records:
		if str(record.id) == id and not bool(record.found):
			record["found"] = true
			return true
	return false


static func nearest(records: Array, position: Vector3, only_found := true) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := REACH
	for record: Dictionary in records:
		if bool(record.opened) or (only_found and not bool(record.found)):
			continue
		var at: Vector3 = record.at
		var flat := Vector2(at.x - position.x, at.z - position.z).length()
		if flat <= best_distance:
			best_distance = flat
			best = record
	return best


## Opens the nearest found stash or door in reach. Returns what it did:
## "" (nothing), "stash" or "door". Also hides the thing from the modes.
static func open_near(records: Array, position: Vector3, sight: Node = null) -> String:
	var record := nearest(records, position)
	if record.is_empty():
		return ""
	record["opened"] = true
	if sight != null:
		for thing: Dictionary in sight.get("hidden"):
			if str(thing.get("id", "")) == str(record.id):
				thing["gone"] = true
	# Hatches creak; a secret door grinds and sheds plaster.
	SIGHT_AUDIO.play_at(sight, "creak" if str(record.kind) == "stash" else "crumble", record.at)
	if str(record.kind) == "stash":
		(record.hinge as Node3D).rotation.y = -1.9
		(record.goods as Node3D).visible = true
		var given := give_stash()
		WorldHistory.record_event("hidden_stash_opened", {"id": str(record.id), "meds": 1, "rounds": ROUNDS, "rounds_to": given})
		return "stash"
	var body := record.body as StaticBody3D
	if body != null and is_instance_valid(body):
		body.queue_free()
	WorldHistory.record_event("secret_door_opened", {"id": str(record.id)})
	return "door"


## Meds and ammo into the inventory. Rounds go into the gun if you carry one,
## otherwise they are carried loose. Returns where the rounds went.
static func give_stash() -> String:
	var items: Array = (WorldHistory.subject("inventory").get("items", []) as Array).duplicate(true)
	items.append(MEDS.duplicate())
	var into := "loose"
	for entry in items:
		if entry is Dictionary and str((entry as Dictionary).get("label", "")) == GUN_LABEL:
			entry["rounds"] = int(entry.get("rounds", 0)) + ROUNDS
			into = "gun"
			break
	if into == "loose":
		var loose := {"label": "LOOSE ROUNDS", "kind": "ammo", "mass": 0.1, "perishes": false, "age": 0.0, "rounds": ROUNDS}
		var merged := false
		for entry in items:
			if entry is Dictionary and str((entry as Dictionary).get("label", "")) == "LOOSE ROUNDS":
				entry["rounds"] = int(entry.get("rounds", 0)) + ROUNDS
				merged = true
				break
		if not merged:
			items.append(loose)
	WorldHistory.update_subject("inventory", {"items": items}, "carry_changed")
	return into
