extends Node3D

## A tiny synthetic level for `curiosity_bot_test`: a walled 48 x 48 m floor
## with a few interior walls, a player moved by the game's own input actions
## and `yaw`, like `old_drains.gd`. Optional fixtures:
##   - `repeat_beacon`: E within reach records the same event every time.
##   - `story_beacon`: E within reach records a NEW event type each time.
##   - `glue_at`: inside this radius the player cannot move at all.

const HALF := 24.0

var player: CharacterBody3D
var yaw := 0.0
var pitch := 0.0
var world_interactables: Array = []
var repeat_beacon: Node3D
var story_beacon: Node3D
var story_count := 0
var start_at := Vector3(-18, 1, -18)
var glue_at := Vector3.INF
var with_beacons := false


func _ready() -> void:
	_slab(Vector3(HALF * 2.0, 1.0, HALF * 2.0), Vector3(0, -0.5, 0))
	for side in [-1.0, 1.0]:
		_slab(Vector3(HALF * 2.0, 3.0, 1.0), Vector3(0, 1.5, side * HALF))
		_slab(Vector3(1.0, 3.0, HALF * 2.0), Vector3(side * HALF, 1.5, 0))
	# Interior walls make a random walk bounce; they do not stop a searcher.
	_slab(Vector3(20.0, 3.0, 1.0), Vector3(-6, 1.5, -6))
	_slab(Vector3(1.0, 3.0, 18.0), Vector3(8, 1.5, 6))
	_slab(Vector3(14.0, 3.0, 1.0), Vector3(-10, 1.5, 12))
	player = CharacterBody3D.new()
	player.position = start_at
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = 0.9
	player.add_child(collider)
	add_child(player)
	if with_beacons:
		repeat_beacon = _beacon("RepeatBeacon", start_at + Vector3(3, 0, 0))
		world_interactables.append({"node": repeat_beacon, "prompt": "[E] RING THE BELL", "reach": 2.6})
		story_beacon = _beacon("StoryBeacon", start_at + Vector3(0, 0, 9))
		world_interactables.append({"node": story_beacon, "prompt": "[E] ASK THE STRANGER", "reach": 2.6})


func _slab(size: Vector3, at: Vector3) -> void:
	var slab := StaticBody3D.new()
	slab.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	slab.add_child(shape)
	add_child(slab)


func _beacon(label: String, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = Vector3(at.x, 1.0, at.z)
	add_child(node)
	return node


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if repeat_beacon != null and _flat(repeat_beacon.global_position) <= 2.6:
			WorldHistory.record_event("arena_bell_rung", {})
		if story_beacon != null and _flat(story_beacon.global_position) <= 2.6 and story_count < 6:
			story_count += 1
			WorldHistory.record_event("arena_stranger_says_%d" % story_count, {})


func _physics_process(delta: float) -> void:
	var input := Vector3(Input.get_axis("move_left", "move_right"), 0.0, Input.get_axis("move_forward", "move_back"))
	var direction := (Basis(Vector3.UP, yaw) * input).normalized()
	var pace := 4.0 * (1.5 if Input.is_action_pressed("sprint") else 1.0)
	if glue_at != Vector3.INF and _flat(glue_at) < 3.0:
		pace = 0.0
	player.velocity.x = move_toward(player.velocity.x, direction.x * pace, 20.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, direction.z * pace, 20.0 * delta)
	player.velocity.y = -2.0 if player.is_on_floor() else player.velocity.y - 18.0 * delta
	player.move_and_slide()
	player.rotation.y = yaw


func _flat(at: Vector3) -> float:
	var difference := at - player.global_position
	difference.y = 0.0
	return difference.length()
