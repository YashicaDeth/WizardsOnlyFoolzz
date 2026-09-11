extends SubViewport

## One body part, turning in place, at whatever scale it happens to be.
##
## `subject_icon.gd` does this for heads; this does it for anything — an organ,
## a bone, a limb, a piece of hardware someone had installed. It is the 3D half
## of Tier 1c, whose one hard rule is that a part must appear to *leave* the
## diagram rather than open a window. That rule is why this is a live viewport
## rather than a sprite sheet: the thing you are looking at has to be the same
## object at the end of the animation as it was at the start of it.
##
## Meshes come from `BodyMesh` and from the same `ORGAN_LAYOUT` table the rig
## builds real organs from, so what you inspect is what is actually inside the
## person — not an illustration of what should be.

const ORGAN_TINTS := {
	"brain": "9c8a86", "heart": "6d100e", "left_lung": "8a4d4a", "right_lung": "8a4d4a",
	"liver": "5a2015", "gut": "8d7a52", "spine": "cfc2a4",
}
const ORGAN_SIZES := {
	"brain": 0.072, "heart": 0.060, "left_lung": 0.076, "right_lung": 0.076,
	"liver": 0.070, "gut": 0.088, "spine": 0.042,
}
const BONE := Color("cfc2a4")
const FLESH := Color("9a6c5c")
const STEEL := Color("7d8894")

var elapsed := 0.0
var spin_speed := 0.7
var condition := 1.0
var view_rotation := Vector2.ZERO
var zoom := 1.0

var _pivot: Node3D
var _spec := ""
var _base_fit := 1.0
var _ruptured := false


func _ready() -> void:
	size = Vector2i(240, 240)
	own_world_3d = true
	# A black specimen well is intentional and lets Forward+ keep real SSS.
	# Transparent subviewports disable subsurface scattering in Godot, which made
	# a correctly configured wet material silently render like lacquered plastic.
	transparent_bg = false
	render_target_update_mode = SubViewport.UPDATE_ALWAYS

	_pivot = Node3D.new()
	add_child(_pivot)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.5
	camera.position = Vector3(0, 0, 1.4)
	add_child(camera)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-28, 38, 0)
	key.light_energy = 1.7
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(10, -142, 0)
	rim.light_energy = 1.1
	rim.light_color = Color("f06428")
	add_child(rim)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(48, 150, 0)
	fill.light_energy = 0.45
	fill.light_color = Color("29b7a8")
	add_child(fill)

	set_process(true)


## `part` is {kind, id, zone}. `state` carries the real condition so a ruptured
## organ and a healthy one do not look the same.
func show_part(part: Dictionary, state: float) -> void:
	condition = clampf(state, 0.0, 1.0)
	_ruptured = bool(part.get("ruptured", false)) or (str(part.get("kind", "")) == "organ" and condition <= 0.05)
	var key := "%s:%s:%s:%s" % [str(part.get("kind", "")), str(part.get("id", "")), str(part.get("zone", "")), str(_ruptured)]
	if key == _spec:
		_apply_condition()
		return
	_spec = key
	# `queue_free` is deferred, so the outgoing part was still a child when
	# `_fit()` measured the new one - a heart switched in after a torso got
	# scaled to fit the torso and rendered at a third of its proper size.
	for child in _pivot.get_children():
		_pivot.remove_child(child)
		child.queue_free()
	match str(part.get("kind", "")):
		"organ":
			_build_organ(str(part.id))
		"bone":
			_build_bone(str(part.get("zone", "torso")))
		"limb":
			_build_limb(str(part.get("zone", "torso")))
		"implant":
			_build_implant(str(part.get("id", "")))
	_apply_condition()
	_fit()


func _build_organ(organ_id: String) -> void:
	if organ_id == "spine":
		# A single sphere is a lie for a spine, and the rig already stacks real
		# vertebrae for it, so this does the same rather than inventing a shape.
		for index in 7:
			var vertebra := MeshInstance3D.new()
			vertebra.mesh = BodyMesh.vertebra()
			vertebra.position = Vector3(0, 0.14 - float(index) * 0.045, 0)
			vertebra.material_override = _material(BONE, true)
			_pivot.add_child(vertebra)
		return
	var tint := Color(str(ORGAN_TINTS.get(organ_id, "7a1a16")))
	# These are deliberately authored composite silhouettes. Each organ has a
	# recognisable outline before colour: lobed lungs, pear heart, wedge liver,
	# coiled bowel and two-hemisphere brain. No generic sphere stands in for all.
	if organ_id.ends_with("lung"):
		var side := -1.0 if organ_id.begins_with("left") else 1.0
		_ellipsoid("UpperLobe", Vector3(side * 0.018, 0.045, 0.0), Vector3(0.72, 1.20, 0.58), tint)
		_ellipsoid("LowerLobe", Vector3(-side * 0.010, -0.050, 0.0), Vector3(0.92, 1.05, 0.66), tint.darkened(0.05), Vector3(0, 0, side * -0.16))
		_ellipsoid("MedialLobe", Vector3(side * 0.030, -0.005, 0.038), Vector3(0.48, 0.78, 0.38), tint.lightened(0.04))
		var stub := MeshInstance3D.new()
		var tube := CylinderMesh.new()
		tube.top_radius = 0.012
		tube.bottom_radius = 0.016
		tube.height = 0.07
		stub.mesh = tube
		stub.position = Vector3(0.0, 0.075, 0.0)
		stub.rotation_degrees = Vector3(0, 0, 18 if organ_id.begins_with("left") else -18)
		stub.material_override = _material(Color("6f3b39"), false)
		stub.name = "Bronchus"
		_pivot.add_child(stub)
	elif organ_id == "heart":
		_ellipsoid("LeftVentricle", Vector3(-0.025, 0.005, 0.0), Vector3(0.82, 1.10, 0.72), tint, Vector3(0, 0, -0.20))
		_ellipsoid("RightVentricle", Vector3(0.030, 0.018, 0.005), Vector3(0.72, 0.96, 0.68), tint.darkened(0.08), Vector3(0, 0, 0.22))
		_ellipsoid("Apex", Vector3(-0.006, -0.066, 0.0), Vector3(0.45, 0.78, 0.48), tint.darkened(0.12))
		for offset in [Vector3(0.03, 0.06, 0.0), Vector3(-0.032, 0.055, 0.01)]:
			var vessel := MeshInstance3D.new()
			var tube := CylinderMesh.new()
			tube.top_radius = 0.010
			tube.bottom_radius = 0.014
			tube.height = 0.055
			vessel.mesh = tube
			vessel.position = offset
			vessel.rotation_degrees = Vector3(12, 0, 22 if offset.x > 0.0 else -20)
			vessel.material_override = _material(Color("4d0b0a"), false)
			vessel.name = "Vessel"
			_pivot.add_child(vessel)
	elif organ_id == "liver":
		var wedge := CylinderMesh.new()
		wedge.radial_segments = 3
		wedge.top_radius = 0.075
		wedge.bottom_radius = 0.115
		wedge.height = 0.055
		var liver := _piece(wedge, Vector3.ZERO, tint, false)
		liver.name = "LiverWedge"
		liver.scale = Vector3(1.35, 0.72, 0.76)
		liver.rotation_degrees = Vector3(78, 8, -12)
		_ellipsoid("LiverLobe", Vector3(0.050, -0.018, 0.012), Vector3(0.72, 0.36, 0.48), tint.darkened(0.06))
	elif organ_id == "gut":
		for index in 5:
			var coil := TorusMesh.new()
			coil.inner_radius = 0.020
			coil.outer_radius = 0.058 + float(index % 2) * 0.007
			coil.rings = 12
			coil.ring_segments = 7
			var loop := _piece(coil, Vector3(float(index % 2) * 0.058 - 0.028, 0.085 - float(index) * 0.043, 0.0), tint.lightened(float(index) * 0.015), false)
			loop.name = "GutCoil%d" % index
			loop.rotation_degrees = Vector3(72, 0, -8 + index * 5)
	elif organ_id == "brain":
		for side in [-1.0, 1.0]:
			_ellipsoid("Hemisphere", Vector3(side * 0.038, 0.012, 0.0), Vector3(0.78, 0.92, 0.72), tint, Vector3(0, 0, side * 0.08))
			for lobe_index in 3:
				_ellipsoid("BrainLobe", Vector3(side * (0.034 + lobe_index * 0.008), 0.052 - lobe_index * 0.045, 0.045), Vector3(0.34, 0.30, 0.22), tint.lightened(0.05))
	else:
		_ellipsoid("Organ", Vector3.ZERO, Vector3.ONE, tint)
	if _ruptured:
		_add_rupture(organ_id)


func _ellipsoid(piece_name: String, at: Vector3, shape: Vector3, tint: Color, rotation := Vector3.ZERO) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.072
	mesh.height = 0.144
	mesh.radial_segments = 16
	mesh.rings = 8
	var piece := _piece(mesh, at, tint, false)
	piece.name = piece_name
	piece.scale = shape
	piece.rotation = rotation
	return piece


## A rupture changes silhouette: a dark cavity bites through the front and wet
## flaps pull away from it. It is not merely the healthy mesh tinted darker.
func _add_rupture(organ_id: String) -> void:
	var cavity_mesh := SphereMesh.new()
	cavity_mesh.radius = 0.040
	cavity_mesh.height = 0.050
	var cavity := _piece(cavity_mesh, Vector3(0.018, -0.005, 0.060), Color("130204"), false)
	cavity.name = "RuptureCavity"
	cavity.scale = Vector3(1.0, 0.72, 0.28)
	for index in 4:
		var flap_mesh := PrismMesh.new()
		flap_mesh.size = Vector3(0.035, 0.012, 0.052)
		var angle := TAU * float(index) / 4.0
		var flap := _piece(flap_mesh, Vector3(cos(angle) * 0.045, sin(angle) * 0.032, 0.073), Color(str(ORGAN_TINTS.get(organ_id, "6d100e"))).darkened(0.18), false)
		flap.name = "TornFlap%d" % index
		flap.rotation = Vector3(sin(angle) * 0.45, cos(angle) * 0.32, angle)


func _build_bone(zone_id: String) -> void:
	match zone_id:
		"head":
			_piece(BodyMesh.skull(0.28), Vector3.ZERO, BONE, true)
		"torso":
			for index in 7:
				_piece(BodyMesh.vertebra(), Vector3(0, 0.28 - float(index) * 0.09, -0.07), BONE, true)
			for index in 5:
				var rib := _piece(BodyMesh.arc_tube(0.148, 0.098, 0.011, PI * 0.12, PI * 0.88), Vector3(0, 0.20 - float(index) * 0.052, -0.012), BONE, true)
				rib.rotation.x = 0.14
		_:
			_piece(BodyMesh.long_bone(0.58, 0.019), Vector3.ZERO, BONE, true)


func _build_limb(zone_id: String) -> void:
	var mesh: Mesh
	match zone_id:
		"head":
			mesh = BodyMesh.head(0.28)
		"torso":
			mesh = BodyMesh.torso(0.66)
		"left_leg", "right_leg":
			mesh = BodyMesh.leg(0.84)
		_:
			mesh = BodyMesh.arm(0.62)
	_piece(mesh, Vector3.ZERO, FLESH, false)


## No authored mesh exists for hardware yet, so it is assembled from primitives
## with enough secondary form to stop reading as a box — which is the same note
## `ROADMAP.md` already has open against the world geometry.
func _build_implant(implant_id: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(implant_id) & 0x7fffffff
	var core := BoxMesh.new()
	core.size = Vector3(0.12, 0.20, 0.10)
	_piece(core, Vector3.ZERO, STEEL, true)
	for index in rng.randi_range(3, 5):
		var ring := CylinderMesh.new()
		ring.top_radius = 0.035 + rng.randf() * 0.02
		ring.bottom_radius = ring.top_radius
		ring.height = 0.018
		var at := Vector3(rng.randf_range(-0.05, 0.05), 0.09 - float(index) * 0.045, 0.05)
		var piece := _piece(ring, at, STEEL.darkened(0.2), true)
		piece.rotation_degrees = Vector3(90, 0, rng.randf_range(-14, 14))
	for index in 2:
		var pin := CylinderMesh.new()
		pin.top_radius = 0.008
		pin.bottom_radius = 0.008
		pin.height = 0.16
		var pin_piece := _piece(pin, Vector3(0.055 if index == 0 else -0.055, 0.0, -0.03), Color("caa96a"), true)
		pin_piece.rotation_degrees = Vector3(0, 0, 6.0 if index == 0 else -6.0)


func _piece(mesh: Mesh, at: Vector3, tint: Color, metallic: bool) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.position = at
	piece.material_override = _material(tint, metallic)
	piece.set_meta("base_color", tint)
	_pivot.add_child(piece)
	return piece


func _material(tint: Color, hard: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.42 if hard else 0.18
	material.metallic = 0.35 if hard else 0.0
	material.metallic_specular = 0.62 if hard else 0.86
	if not hard:
		material.clearcoat_enabled = true
		material.clearcoat_roughness = 0.12
		material.subsurf_scatter_enabled = true
		material.subsurf_scatter_strength = 0.32
	return material


## Condition reads on the part itself rather than only in the caption: a failing
## organ darkens toward necrosis and a ruined one is nearly black.
func _apply_condition() -> void:
	for child in _pivot.get_children():
		var piece := child as MeshInstance3D
		if piece == null:
			continue
		var material := piece.material_override as StandardMaterial3D
		if material == null:
			continue
		var base: Color = piece.get_meta("base_color", material.albedo_color)
		material.albedo_color = base.lerp(Color("221114"), (1.0 - condition) * 0.72)
		material.emission_enabled = condition < 0.35
		material.emission = Color("6d100e") * (1.0 - condition) * 0.4


## Every part is a different real size - a brain is 7cm and a leg is 84cm - so
## the pivot is scaled to a constant framing rather than the camera being moved.
## Without this the small organs render as dots.
func _fit() -> void:
	var extent := 0.0
	for child in _pivot.get_children():
		var piece := child as MeshInstance3D
		if piece == null or piece.mesh == null:
			continue
		var box := piece.mesh.get_aabb()
		var corner := (box.position + box.size).abs() * piece.scale.abs()
		var here := maxf(maxf(corner.x, corner.y), corner.z) + piece.position.length()
		extent = maxf(extent, here)
	if extent <= 0.0:
		return
	_base_fit = 0.22 / extent
	_apply_zoom()


func rotate_by(pixel_delta: Vector2) -> void:
	view_rotation.x += pixel_delta.x * 0.010
	view_rotation.y = clampf(view_rotation.y + pixel_delta.y * 0.010, -1.15, 1.15)


func zoom_by(factor: float) -> void:
	zoom = clampf(zoom * factor, 0.62, 1.85)
	_apply_zoom()


func _apply_zoom() -> void:
	_pivot.scale = Vector3.ONE * _base_fit * zoom


func view_state() -> Dictionary:
	return {"rotation": view_rotation, "zoom": zoom, "ruptured": _ruptured, "pieces": _pivot.get_child_count()}


func _process(delta: float) -> void:
	elapsed += delta
	_pivot.rotation.y = elapsed * spin_speed + view_rotation.x
	_pivot.rotation.x = sin(elapsed * 0.6) * 0.11 + view_rotation.y
