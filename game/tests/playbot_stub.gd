extends Node3D

## A room for `playbot_bridge_test`: floor, a player body that walks on the
## real move_* actions, the scene `yaw` the real scenes expose, the shared
## HUD/Objective + HUD/Prompt labels, a counter for E presses, and one wall
## with nothing drawn on it.

var player: CharacterBody3D
var yaw := 0.0
var pitch := 0.0
var health := 87
var interacts := 0


func _ready() -> void:
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = BoxMesh.new()
	(floor_mesh.mesh as BoxMesh).size = box.size
	floor_body.add_child(floor_mesh)
	add_child(floor_body)

	var wall := StaticBody3D.new()
	wall.name = "BareWall"
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(6, 4, 0.5)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	wall.position = Vector3(0, 2, -6)
	add_child(wall)

	player = CharacterBody3D.new()
	var body_shape := CollisionShape3D.new()
	body_shape.shape = CapsuleShape3D.new()
	player.add_child(body_shape)
	player.position = Vector3(0, 1, 0)
	add_child(player)

	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	var objective := Label.new()
	objective.name = "Objective"
	objective.text = "OBJECTIVE\nREACH THE WALL"
	hud.add_child(objective)
	var prompt := Label.new()
	prompt.name = "Prompt"
	prompt.text = "[E] KNOCK"
	hud.add_child(prompt)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_E:
		interacts += 1
		$HUD/Prompt.text = "KNOCKED %d" % interacts


func _physics_process(delta: float) -> void:
	player.rotation.y = yaw
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (player.transform.basis * Vector3(input.x, 0, input.y)).normalized()
	player.velocity.x = direction.x * 4.0
	player.velocity.z = direction.z * 4.0
	player.velocity.y -= 9.8 * delta
	player.move_and_slide()
