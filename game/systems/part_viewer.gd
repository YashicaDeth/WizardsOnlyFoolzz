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

var _pivot: Node3D
var _spec := ""


func _ready() -> void:
	size = Vector2i(240, 240)
	own_world_3d = true
	transparent_bg = true
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
	var key := "%s:%s:%s" % [str(part.get("kind", "")), str(part.get("id", "")), str(part.get("zone", ""))]
	condition = clampf(state, 0.0, 1.0)
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
	var organ := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = float(ORGAN_SIZES.get(organ_id, 0.07))
	mesh.height = mesh.radius * 2.0
	organ.mesh = mesh
	organ.material_override = _material(Color(str(ORGAN_TINTS.get(organ_id, "7a1a16"))), false)
	_pivot.add_child(organ)
	# Lungs get a bronchial stub and the heart gets its vessels, because a bare
	# sphere reads as a placeholder no matter what colour it is.
	if organ_id.ends_with("lung"):
		var stub := MeshInstance3D.new()
		var tube := CylinderMesh.new()
		tube.top_radius = 0.012
		tube.bottom_radius = 0.016
		tube.height = 0.07
		stub.mesh = tube
		stub.position = Vector3(0.0, 0.075, 0.0)
		stub.rotation_degrees = Vector3(0, 0, 18 if organ_id.begins_with("left") else -18)
		stub.material_override = _material(Color("6f3b39"), false)
		_pivot.add_child(stub)
	elif organ_id == "heart":
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
			_pivot.add_child(vessel)


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
	_pivot.add_child(piece)
	return piece


func _material(tint: Color, hard: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.42 if hard else 0.78
	material.metallic = 0.35 if hard else 0.0
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
		var base: Color = material.albedo_color
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
		var corner := (box.position + box.size).abs()
		var here := maxf(maxf(corner.x, corner.y), corner.z) + piece.position.length()
		extent = maxf(extent, here)
	if extent <= 0.0:
		return
	var scale_factor := 0.22 / extent
	_pivot.scale = Vector3.ONE * scale_factor


func _process(delta: float) -> void:
	elapsed += delta
	_pivot.rotation.y = elapsed * spin_speed
	_pivot.rotation.x = sin(elapsed * 0.6) * 0.11
