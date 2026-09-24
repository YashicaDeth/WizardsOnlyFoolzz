class_name ServiceRingRelay
extends StaticBody3D

## A CellOutz surveillance relay in one of the colosseum's three real tunnel
## chambers. It is a physical target for the same rounds and vehicle impacts
## already used by the derby, and a live scanning light until disabled.

signal relay_disabled(index: int, cause: String)

const MAX_HITS := 3
const SCAN_RANGE := 34.0
const SCAN_DOT := 0.82

var relay_index := 0
var hits := 0
var disabled := false
var clock := 0.0
var head: Node3D
var lens: MeshInstance3D
var lamp: SpotLight3D
var status_glow: OmniLight3D
var _lens_material: StandardMaterial3D
var _status_materials: Array[StandardMaterial3D] = []


func build(index: int) -> void:
	relay_index = index
	name = "ServiceRingRelay_%02d" % index
	set_meta("service_ring_relay", true)
	set_meta("service_ring_relay_index", index)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 4.5, 2.2)
	collision.shape = shape
	collision.position.y = 2.25
	add_child(collision)

	var pedestal := MeshInstance3D.new()
	var pedestal_mesh := CylinderMesh.new()
	pedestal_mesh.top_radius = 0.84
	pedestal_mesh.bottom_radius = 1.05
	pedestal_mesh.height = 3.7
	pedestal_mesh.radial_segments = 8
	pedestal_mesh.material = WorldLook.surface(Color("241a16"), "rust", 6200 + index)
	pedestal.mesh = pedestal_mesh
	pedestal.position.y = 1.85
	add_child(pedestal)

	# Three collars make it read as a relay built to turn, not a generic pillar.
	for collar_index in 3:
		var collar := MeshInstance3D.new()
		var collar_mesh := TorusMesh.new()
		collar_mesh.inner_radius = 0.78
		collar_mesh.outer_radius = 1.08
		collar_mesh.rings = 12
		collar_mesh.ring_segments = 8
		var collar_material := WorldLook.emissive(Color("8f1f18") if collar_index == 1 else Color("5b211c"), 1.35 if collar_index == 1 else 0.45)
		collar_mesh.material = collar_material
		_status_materials.append(collar_material)
		collar.mesh = collar_mesh
		collar.position.y = 0.75 + float(collar_index) * 1.25
		add_child(collar)

	head = Node3D.new()
	head.name = "ScannerHead"
	head.position.y = 4.2
	add_child(head)
	var hood := MeshInstance3D.new()
	var hood_mesh := BoxMesh.new()
	hood_mesh.size = Vector3(2.7, 1.25, 1.55)
	hood_mesh.material = WorldLook.surface(Color("321d18"), "metal", 6300 + index)
	hood.mesh = hood_mesh
	head.add_child(hood)

	lens = MeshInstance3D.new()
	var lens_mesh := CylinderMesh.new()
	lens_mesh.top_radius = 0.48
	lens_mesh.bottom_radius = 0.62
	lens_mesh.height = 0.28
	lens_mesh.radial_segments = 12
	_lens_material = WorldLook.emissive(Color("db251d"), 3.2)
	lens_mesh.material = _lens_material
	lens.mesh = lens_mesh
	lens.rotation_degrees.x = 90.0
	lens.position.z = -0.88
	head.add_child(lens)
	var aperture := MeshInstance3D.new()
	var aperture_mesh := TorusMesh.new()
	aperture_mesh.inner_radius = 0.58
	aperture_mesh.outer_radius = 0.78
	aperture_mesh.rings = 16
	aperture_mesh.ring_segments = 8
	var aperture_material := WorldLook.emissive(Color("ad271e"), 1.6)
	aperture_mesh.material = aperture_material
	_status_materials.append(aperture_material)
	aperture.mesh = aperture_mesh
	aperture.rotation_degrees.x = 90.0
	aperture.position.z = -0.93
	head.add_child(aperture)

	lamp = SpotLight3D.new()
	lamp.name = "SurveillanceCone"
	lamp.position.z = -0.9
	lamp.light_color = Color("e32d22")
	lamp.light_energy = 4.0
	lamp.spot_range = SCAN_RANGE
	lamp.spot_angle = 19.0
	lamp.spot_angle_attenuation = 1.6
	lamp.shadow_enabled = false
	head.add_child(lamp)

	# Enough local spill to reveal the machine's silhouette against the dark
	# masonry. The long cone remains the threat; this short glow only makes its
	# source readable from the cab and dies with the hardware.
	status_glow = OmniLight3D.new()
	status_glow.position.y = 4.1
	status_glow.light_color = Color("c93928")
	status_glow.light_energy = 1.7
	status_glow.omni_range = 7.0
	status_glow.shadow_enabled = false
	add_child(status_glow)


func take_hit(cause: String = "shot", force: float = 1.0) -> Dictionary:
	if disabled or force <= 0.0:
		return state()
	hits = mini(MAX_HITS, hits + maxi(1, roundi(force)))
	if hits >= MAX_HITS:
		disabled = true
		lamp.visible = false
		status_glow.visible = false
		_lens_material.emission = Color("263116")
		_lens_material.albedo_color = Color("18200e")
		for material in _status_materials:
			material.emission = Color("18200e")
			material.albedo_color = Color("11150c")
			material.emission_energy_multiplier = 0.2
		head.rotation_degrees.z = 13.0 if relay_index % 2 == 0 else -11.0
		collision_layer = 1
		relay_disabled.emit(relay_index, cause)
	else:
		var remaining := 1.0 - float(hits) / float(MAX_HITS)
		_lens_material.emission_energy_multiplier = 1.0 + remaining * 2.2
		_lens_material.albedo_color = Color("6d1914").lerp(Color("d93626"), remaining)
	return state()


func restore_disabled() -> void:
	if disabled:
		return
	hits = MAX_HITS
	disabled = true
	lamp.visible = false
	status_glow.visible = false
	_lens_material.emission = Color("263116")
	_lens_material.albedo_color = Color("18200e")
	for material in _status_materials:
		material.emission = Color("18200e")
		material.albedo_color = Color("11150c")
		material.emission_energy_multiplier = 0.2
	head.rotation_degrees.z = 13.0 if relay_index % 2 == 0 else -11.0


func advance_scan(delta: float, target: Vector3) -> float:
	if disabled:
		return 0.0
	clock += maxf(delta, 0.0)
	var angle := clock * (0.72 + float(relay_index) * 0.08) + float(relay_index) * TAU / 3.0
	var heading := Vector3(cos(angle), 0.0, sin(angle)).normalized()
	if head != null and is_instance_valid(head):
		head.global_basis = Basis.looking_at(heading, Vector3.UP)
	var delta_target := target - global_position
	delta_target.y = 0.0
	var distance := delta_target.length()
	if distance <= 0.01 or distance > SCAN_RANGE:
		return 0.0
	var alignment := heading.dot(delta_target / distance)
	if alignment < SCAN_DOT:
		return 0.0
	return clampf(inverse_lerp(SCAN_DOT, 1.0, alignment) * inverse_lerp(SCAN_RANGE, 4.0, distance), 0.0, 1.0)


func state() -> Dictionary:
	return {
		"index": relay_index,
		"hits": hits,
		"max_hits": MAX_HITS,
		"disabled": disabled,
	}
