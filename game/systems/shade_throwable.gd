class_name ShadeThrowable
extends CharacterBody3D

## A small physical lab throwable. It travels through collision instead of
## applying a distant scripted hit, and resolves flesh through BaselineHuman.

signal impacted(target: Object, report: Dictionary)

const GRAVITY := 12.0
const LIFE := 4.0
const DAMAGE := 12.0
const IMPULSE := 7.0

var age := 0.0


func _ready() -> void:
	var mesh := MeshInstance3D.new()
	var stone := SphereMesh.new()
	stone.radius = 0.09
	stone.height = 0.18
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("25252b")
	material.metallic = 0.35
	material.roughness = 0.7
	stone.material = material
	mesh.mesh = stone
	add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.09
	collision.shape = shape
	add_child(collision)


func launch(origin: Vector3, direction: Vector3, speed: float) -> void:
	global_position = origin
	velocity = direction.normalized() * speed


func _physics_process(delta: float) -> void:
	age += delta
	if age >= LIFE:
		queue_free()
		return
	velocity.y -= GRAVITY * delta
	var collision := move_and_collide(velocity * delta)
	if collision == null:
		return
	var collider := collision.get_collider()
	var report: Dictionary = {"hit": true, "body": false}
	var rig := MeleeDriver.rig_of(collider)
	if rig != null and rig is BaselineHuman:
		var along := velocity.normalized()
		report = (rig as BaselineHuman).hit_at(collision.get_position(), DAMAGE, IMPULSE, "blunt", along)
		report["hit"] = true
		report["body"] = true
	impacted.emit(collider, report)
	queue_free()
