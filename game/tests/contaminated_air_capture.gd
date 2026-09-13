extends Node3D

## Visual rig for W1.2. capture_scene.tscn can load any packed scene and
## screenshot it, but this system is not wired into a real scene yet (that is
## bone_yard_hunt.gd, owned by another lane) — so this stands the haze up
## against a floor and a sun on its own, at a forced-high severity, so the
## look can actually be inspected rather than just unit-tested.

const CONTAMINATED_AIR := preload("res://systems/contaminated_air.gd")


func _ready() -> void:
	# Worst-case severity, so the capture shows what "gets worse" looks like
	# at its ceiling rather than the barely-there day-one haze.
	WorldHistory.world_minute = 30.0 * WorldClock.MINUTES_PER_DAY

	var env := WorldEnvironment.new()
	env.environment = WorldLook.environment("ashbloom")
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -25, 0)
	sun.light_color = Color("c89572")
	sun.light_energy = 1.4
	add_child(sun)

	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	floor_mesh.mesh = plane
	floor_mesh.material_override = WorldLook.surface(Color("100e0d"), "dirt", 1)
	add_child(floor_mesh)

	var air := CONTAMINATED_AIR.new()
	add_child(air)
	# One manual step so the emitters are already live and oriented on the
	# wind by the time the settle frames in capture_scene.gd render.
	air._process(0.1)

	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 1.7, 14)
	camera.look_at(Vector3(0, 1.5, 0), Vector3.UP)
	camera.current = true
