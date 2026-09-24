class_name DroppedHandheld
extends RigidBody3D

## C1.7. The Black Mirror after it leaves the HUD: the same identified object
## expressed as colliding world geometry, not a marker or a replacement pickup.

var payload: Dictionary = {}


func configure(device_payload: Dictionary) -> void:
	payload = device_payload.duplicate(true)
	_build()


func _build() -> void:
	if get_node_or_null("Case") != null:
		return
	mass = 0.42
	linear_damp = 1.2
	angular_damp = 0.9
	contact_monitor = true
	max_contacts_reported = 4

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.18, 0.035, 0.34)
	collision.shape = shape
	add_child(collision)

	var condition := clampf(float(payload.get("condition", 1.0)), 0.0, 1.0)
	var case := MeshInstance3D.new()
	case.name = "Case"
	var case_mesh := BoxMesh.new()
	case_mesh.size = Vector3(0.18, 0.035, 0.34)
	case_mesh.material = _material(Color("17130f").lerp(Color("3d291f"), 1.0 - condition), 0.15, 0.72)
	case.mesh = case_mesh
	add_child(case)

	var screen := MeshInstance3D.new()
	screen.name = "MirrorGlass"
	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(0.154, 0.008, 0.278)
	var charge := clampf(float(payload.get("battery", 0.0)), 0.0, 1.0)
	screen_mesh.material = _material(Color("07120f"), 0.3 + charge * 0.8, 0.28)
	screen.mesh = screen_mesh
	screen.position.y = 0.021
	add_child(screen)

	# The lashed replacement cell on the rear makes either face recognisable.
	var battery := MeshInstance3D.new()
	battery.name = "LashBattery"
	var battery_mesh := BoxMesh.new()
	battery_mesh.size = Vector3(0.105, 0.028, 0.16)
	battery_mesh.material = _material(Color("4c4431"), 0.0, 0.82)
	battery.mesh = battery_mesh
	battery.position = Vector3(0.0, -0.03, 0.035)
	add_child(battery)

	for x in [-0.048, 0.048]:
		var lashing := MeshInstance3D.new()
		var lash_mesh := BoxMesh.new()
		lash_mesh.size = Vector3(0.012, 0.035, 0.205)
		lash_mesh.material = _material(Color("8b4829"), 0.0, 0.9)
		lashing.mesh = lash_mesh
		lashing.position = Vector3(x, -0.047, 0.035)
		add_child(lashing)

	var identity := Label3D.new()
	identity.name = "Serial"
	identity.text = "MK-II // %06d" % int(payload.get("serial", 0))
	identity.font_size = 18
	identity.modulate = Color("d49b57")
	identity.outline_modulate = Color(0, 0, 0, 0.9)
	identity.outline_size = 4
	identity.position = Vector3(0.0, 0.029, 0.08)
	identity.rotation_degrees = Vector3(-90, 0, 0)
	identity.pixel_size = 0.0012
	add_child(identity)


func _material(color: Color, emission: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.42
	material.roughness = roughness
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color.lightened(0.28)
		material.emission_energy_multiplier = emission
	return material
