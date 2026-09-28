extends Node

## The doctor's door: every weapon Greg named gets through it, each the way it
## would, the pieces are real and stay, and a broken door is still broken the
## next time the room is built.

const DOOR := preload("res://systems/breakable_door.gd")
const WORLD_DEBRIS := preload("res://systems/world_debris.gd")

var failures: Array[String] = []
var noises: Array[float] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	floor.add_child(shape)
	add_child(floor)

	await _gun_then_shoulder()
	await _gun_at_hinges()
	await _axe()
	await _restraint()
	await _shoulder_only()
	_persistence()
	print("BREAKABLE_DOOR_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)


func _door(id: String) -> BreakableDoor:
	var door := DOOR.new()
	add_child(door)
	door.build(id)
	door.noise.connect(func(_at: Vector3, loudness: float) -> void: noises.append(loudness))
	return door


## Door plane is XY at z = 0; blows travel -z, into the room behind it.
func _lock(door: BreakableDoor) -> Vector3:
	return door.global_position + Vector3(door.width * 0.5 - 0.13, door.height * 0.5 - 0.05, 0.0)


func _hinge(door: BreakableDoor, index: int) -> Vector3:
	return door.global_position + Vector3(-door.width * 0.5 + 0.03, door.height * 0.5 + (-0.3 if index == 0 else 0.3) * door.height, 0.0)


func _centre(door: BreakableDoor) -> Vector3:
	return door.global_position + Vector3(-0.2, door.height * 0.5 + 0.1, 0.0)


const IN := Vector3(0, 0, -1)


func _gun_then_shoulder() -> void:
	var door := _door("door_gun_lock")
	door.position = Vector3(0, 0, 0)
	var first := door.hit("gun", _lock(door), IN)
	check(str(first.part) == "lock" and not door.broken, "a round into the lock damages the lock, not the panel")
	door.hit("gun", _lock(door), IN)
	check(door.lock_hp <= 0.0 and door.state == "unlocked", "two rounds take the lock out (%s)" % door.state)
	check(not door.broken, "and an unlocked door is not yet an open one")
	var shoulder := door.hit("body", _centre(door), IN)
	check(door.broken and str(shoulder.broke) == "lock", "a shoulder puts the unlocked door into the wall")
	await get_tree().process_frame
	await get_tree().process_frame
	check(door._leaf_collision.disabled, "and it stops blocking the way")
	check(str(WorldHistory.subject("door_gun_lock").get("broken_by", "")) == "swung_open_body", "the world records how it was opened")
	check(door.fragments.size() >= 1 and not WORLD_DEBRIS.identify(door.fragments[0]).is_empty(), "the shot-out lock is a real, identified piece")
	door.queue_free()


func _gun_at_hinges() -> void:
	var door := _door("door_gun_hinges")
	door.position = Vector3(4, 0, 0)
	for index in 2:
		door.hit("gun", _hinge(door, index), IN)
		if index == 0:
			door.hit("gun", _hinge(door, 0), IN)
			check(door.state == "hanging", "one hinge gone and it hangs off the other")
		else:
			door.hit("gun", _hinge(door, 1), IN)
	check(door.broken and door.leaf_body_fallen != null, "both hinges gone and the leaf comes out of the frame")
	var leaf := door.leaf_body_fallen
	var start := leaf.global_position
	for _frame in 50:
		await get_tree().physics_frame
	var moved := leaf.global_position.distance_to(start)
	check(moved > 0.3 and moved < 4.0, "and it falls as a physical body, not a launched one (moved %.2fm)" % moved)
	check(leaf.global_position.y > -0.2, "and comes to rest on the floor, not through it")
	check(str(WORLD_DEBRIS.identify(leaf).get("kind", "")) == "door_leaf", "the fallen leaf is identified debris you can find later")
	door.queue_free()


func _axe() -> void:
	var door := _door("door_axe")
	door.position = Vector3(8, 0, 0)
	var swings := 0
	while not door.broken and swings < 20:
		swings += 1
		# Chop down the middle, the way somebody would.
		var at := door.global_position + Vector3(-0.2 + 0.4 * float(swings % 2), 0.3 + 0.45 * float(swings % 4), 0)
		door.hit("axe", at, IN)
	check(door.broken, "an axe gets through (%d swings)" % swings)
	check(swings <= 7, "and it is the best tool for it")
	check(door.fragments.size() >= 6, "panels come out as pieces (%d)" % door.fragments.size())
	for _frame in 60:
		await get_tree().physics_frame
	var furthest := 0.0
	for piece in door.fragments:
		if is_instance_valid(piece):
			furthest = maxf(furthest, piece.global_position.distance_to(door.global_position))
	check(furthest < 6.0, "the pieces land near the door rather than across the room (%.2fm)" % furthest)
	door.queue_free()


func _restraint() -> void:
	var door := _door("door_restraint")
	door.position = Vector3(12, 0, 0)
	noises.clear()
	var blows := 0
	while not door.broken and blows < 80:
		blows += 1
		var at := door.global_position + Vector3(-0.25 + 0.5 * float(blows % 2), 0.35 + 0.5 * float(blows % 4), 0)
		door.hit("restraint", at, IN)
	check(door.broken, "the restraint gets there too (%d blows)" % blows)
	check(blows > 10, "but slowly")
	check(noises.size() == blows and noises.min() >= 0.7, "and every blow is loud")
	door.queue_free()


func _shoulder_only() -> void:
	var door := _door("door_shoulder")
	door.position = Vector3(16, 0, 0)
	var charges := 0
	while not door.broken and charges < 40:
		charges += 1
		door.hit("body", _centre(door) + Vector3(0.3 * float(charges % 2), 0.4 * float(charges % 3) - 0.4, 0), IN)
	check(door.broken, "a shoulder alone breaks it eventually (%d charges)" % charges)
	check(charges > 4, "and it takes a while")
	door.queue_free()


func _persistence() -> void:
	var again := DOOR.new()
	add_child(again)
	again.build("door_axe")
	check(again.broken and again.passable(), "a door broken before is still broken when the room is built again")
	check(again._leaf == null, "with no leaf standing in the frame")
	var fresh := DOOR.new()
	add_child(fresh)
	fresh.build("door_never_touched")
	check(not fresh.broken and fresh.condition() > 0.99, "and one nobody touched is whole")
